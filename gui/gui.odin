package gui

import "core:time"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import gl "vendor:OpenGL"
import "color"

Vec2 :: [2]f32
Color :: color.Color

Font :: int
Id :: u64

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

generate_id :: proc "contextless" () -> Id {
    @(static) last_id: Id
    return 1 + intrinsics.atomic_add(&last_id, 1)
}

Interaction_Tracker :: struct {
    detected_hover: bool,
    detected_mouse_over: bool,
}

Context :: struct {
    on_frame: proc(ctx: ^Context),
    background_color: [4]f32,
    highest_z_index: int,

    window_is_open: bool,
    window_is_hovered: bool,
    tick: time.Tick,
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

    hover: Id,
    mouse_over: Id,
    hover_capture: Id,

    offset_stack: [dynamic]Vec2,
    clip_region_stack: [dynamic]Region,
    interaction_tracker_stack: [dynamic]Interaction_Tracker,
    layer_stack: [dynamic]Layer,

    layers: [dynamic]Layer,

    gfx: Vector_Graphics,
    window: Window,

    last_id: Id,

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
    delete(ctx.clip_region_stack)
    delete(ctx.interaction_tracker_stack)
    delete(ctx.layers)
    delete(ctx.layer_stack)
    free(ctx)
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
    append(&ctx.interaction_tracker_stack, Interaction_Tracker{})
    ctx.tick = time.tick_now()
}

end_frame :: proc(ctx: ^Context) {
    pop(&ctx.interaction_tracker_stack)
    end_clip_region(ctx)
    end_offset(ctx)
    end_z_index(ctx)

    assert(len(ctx.offset_stack) == 0, "Mismatch in begin_offset and end_offset calls.")
    assert(len(ctx.clip_region_stack) == 0, "Mismatch in begin_clip_region and end_clip_region calls.")
    assert(len(ctx.interaction_tracker_stack) == 0, "Mismatch in begin_interaction_tracker and end_interaction_tracker calls.")
    assert(len(ctx.layer_stack) == 0, "Mismatch in begin_z_index and end_z_index calls.")

    // The layers are in reverse order because they were added in end_z_index.
    // Sort preserves the order of layers with the same z index, so they
    // must first be reversed and then sorted to keep that ordering in tact.
    slice.reverse(ctx.layers[:])
    slice.stable_sort_by(ctx.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    ctx.hover = 0
    ctx.mouse_over = 0
    highest_z_index := min(int)

    for layer in ctx.layers {
        if layer.z_index > highest_z_index {
            highest_z_index = layer.z_index
        }
        render_draw_commands(ctx, layer.draw_commands[:])

        hover_request := layer.final_hover_request
        if hover_request != 0 {
            ctx.hover = hover_request
            ctx.mouse_over = hover_request
        }

        delete(layer.draw_commands)
    }

    if ctx.hover_capture != 0 {
        ctx.hover = ctx.hover_capture
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

begin_interaction_tracker :: proc(ctx: ^Context) {
    append(&ctx.interaction_tracker_stack, Interaction_Tracker{})
}

end_interaction_tracker :: proc(ctx: ^Context) -> Interaction_Tracker {
    tracker := pop(&ctx.interaction_tracker_stack)

    if tracker.detected_hover {
        ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_hover = true
    }

    if tracker.detected_mouse_over {
        ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_mouse_over = true
    }

    return tracker
}

is_hovered :: proc(ctx: ^Context, id: Id) -> bool {
    return ctx.hover == id
}

mouse_is_over :: proc(ctx: ^Context, id: Id) -> bool {
    return ctx.mouse_over == id
}

request_hover :: proc(ctx: ^Context, id: Id) {
    current_layer(ctx).final_hover_request = id

    if ctx.hover == id {
        ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_hover = true
    }

    if ctx.mouse_over == id {
        ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_mouse_over = true
    }
}

capture_hover :: proc(ctx: ^Context, id: Id) {
    if ctx.hover_capture == 0 {
        ctx.hover_capture = id
    }
}

release_hover :: proc(ctx: ^Context, id: Id) {
    if ctx.hover_capture == id {
        ctx.hover_capture = 0
    }
}

mouse_hit_test :: proc(ctx: ^Context, position, size: Vec2) -> bool {
    m := mouse_position(ctx)
    return window_is_hovered(ctx) &&
           m.x >= position.x && m.x <= position.x + size.x &&
           m.y >= position.y && m.y <= position.y + size.y &&
           region_contains_position(current_clip_region(ctx), m)
}