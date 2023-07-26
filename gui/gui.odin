package gui

import "core:time"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"

Vec2 :: [2]f32
Color :: [4]f32

Font :: int

Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Pointing_Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
}

startup :: proc() {
    startup_window_manager()
}

shutdown :: proc() {
    shutdown_window_manager()
}

update :: proc() {
    update_window_manager()
}

Context :: struct {
    on_frame: proc(ctx: ^Context),
    background_color: [4]f32,
    should_close: bool,
    highest_z_index: int,

    tick: time.Tick,
    is_hovered: bool,
    content_scale: f32,
    size: Vec2,
    global_mouse_position: Vec2,
    mouse_wheel_state: Vec2,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,

    offset_stack: [dynamic]Vec2,
    clip_region_stack: [dynamic]Region,
    layer_stack: [dynamic]Layer,

    layers: [dynamic]Layer,

    gfx: Vector_Graphics,
    window: Window,

    previous_global_mouse_position: Vec2,
    previous_tick: time.Tick,
}

create_context :: proc(title: string) -> ^Context {
    ctx := new(Context)
    ctx.content_scale = 1.0
    init_window(ctx, title)
    init_vector_graphics(ctx)
    return ctx
}

destroy_context :: proc(ctx: ^Context) {
    destroy_vector_graphics(ctx)
    destroy_window(ctx)
    delete(ctx.offset_stack)
    delete(ctx.layers)
    delete(ctx.layer_stack)
    free(ctx)
}

close :: proc(ctx: ^Context) {
    ctx.should_close = true
}

should_close :: proc(ctx: ^Context) -> bool {
    return ctx.should_close
}

set_background_color :: proc(ctx: ^Context, color: Color) {
    ctx.background_color = color
}

set_frame_proc :: proc(ctx: ^Context, on_frame: proc(ctx: ^Context)) {
    ctx.on_frame = on_frame
}

begin_frame :: proc(ctx: ^Context) {
    gl.Viewport(0, 0, i32(ctx.size.x), i32(ctx.size.y))
    vector_graphics_begin_frame(ctx, ctx.size, ctx.content_scale)
    begin_z_index(ctx, 0, global = true)
    begin_offset(ctx, 0, global = true)
    begin_clip_region(ctx, {{0, 0}, ctx.size}, global = true, intersect = false)
    ctx.tick = time.tick_now()
}

end_frame :: proc(ctx: ^Context) {
    end_clip_region(ctx)
    end_offset(ctx)
    end_z_index(ctx)

    assert(len(ctx.offset_stack) == 0, "Mismatch in begin_offset and end_offset calls.")
    assert(len(ctx.clip_region_stack) == 0, "Mismatch in begin_clip_region and end_clip_region calls.")
    assert(len(ctx.layer_stack) == 0, "Mismatch in begin_z_index and end_z_index calls.")

    // The layers are in reverse order because they were added in end_z_index.
    // Sort preserves the order of layers with the same z index, so they
    // must first be reversed and then sorted to keep that ordering in tact.
    slice.reverse(ctx.layers[:])
    slice.stable_sort_by(ctx.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    highest_z_index := min(int)

    for layer in ctx.layers {
        if layer.z_index > highest_z_index {
            highest_z_index = layer.z_index
        }
        render_draw_commands(ctx, layer.draw_commands[:])
        delete(layer.draw_commands)
    }

    ctx.highest_z_index = highest_z_index

    clear(&ctx.layers)
    clear(&ctx.mouse_presses)
    clear(&ctx.mouse_releases)
    clear(&ctx.key_presses)
    clear(&ctx.key_releases)
    strings.builder_reset(&ctx.text_input)
    ctx.mouse_wheel_state = {0, 0}
    ctx.previous_global_mouse_position = ctx.global_mouse_position
    ctx.previous_tick = ctx.tick

    vector_graphics_end_frame(ctx)
}

current_offset :: proc(ctx: ^Context) -> Vec2 {
    return ctx.offset_stack[len(ctx.offset_stack) - 1]
}

begin_offset :: proc(ctx: ^Context, offset: Vec2, global := false) {
    if global {
        append(&ctx.offset_stack, offset)
    } else {
        append(&ctx.offset_stack, current_offset(ctx) + offset)
    }
}

end_offset :: proc(ctx: ^Context) -> Vec2 {
    return pop(&ctx.offset_stack)
}

current_clip_region :: proc(ctx: ^Context, global := false) -> Region {
    region := ctx.clip_region_stack[len(ctx.clip_region_stack) - 1]
    if !global {
        region.position -= current_offset(ctx)
    }
    return region
}

begin_clip_region :: proc(ctx: ^Context, region: Region, global := false, intersect := true) {
    region := region

    // Make it global
    if !global {
        region.position += current_offset(ctx)
    }

    // Intersect with global
    if intersect {
        region = intersect_region(region, current_clip_region(ctx, global = true))
    }

    append(&ctx.clip_region_stack, region)

    append(&current_layer(ctx).draw_commands, Clip_Command{
        region.position,
        region.size,
    })
}

end_clip_region :: proc(ctx: ^Context) -> Region {
    result := pop(&ctx.clip_region_stack)

    if len(ctx.clip_region_stack) == 0 {
        return result
    }

    region := current_clip_region(ctx)
    append(&current_layer(ctx).draw_commands, Clip_Command{
        region.position,
        region.size,
    })

    return result
}

current_z_index :: proc(ctx: ^Context) -> int {
    return current_layer(ctx).z_index
}

begin_z_index :: proc(ctx: ^Context, z_index: int, global := false) {
    if global {
        append(&ctx.layer_stack, Layer{z_index = z_index})
    } else {
        append(&ctx.layer_stack, Layer{z_index = current_z_index(ctx) + z_index})
    }
}

end_z_index :: proc(ctx: ^Context) -> int {
    layer := pop(&ctx.layer_stack)
    append(&ctx.layers, layer)
    return layer.z_index
}