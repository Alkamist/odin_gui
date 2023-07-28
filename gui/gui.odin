package gui

import "core:time"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import gl "vendor:OpenGL"
import wnd "../window"

Id :: u64
Vec2 :: [2]f32

Cursor_Style :: wnd.Cursor_Style
Mouse_Button :: wnd.Mouse_Button
Keyboard_Key :: wnd.Keyboard_Key
Context_Error :: wnd.Window_Error

Interaction_Tracker :: struct {
    detected_hover: bool,
    detected_mouse_over: bool,
}

Context :: struct {
    user_data: rawptr,
    on_frame: proc(ctx: ^Context),

    tick: time.Tick,
    previous_tick: time.Tick,
    background_color: Color,
    window_is_hovered: bool,
    global_mouse_position: Vec2,
    previous_global_mouse_position: Vec2,
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

    highest_z_index: int,

    offset_stack: [dynamic]Vec2,
    clip_region_stack: [dynamic]Region,
    interaction_tracker_stack: [dynamic]Interaction_Tracker,
    layer_stack: [dynamic]Layer,

    layers: [dynamic]Layer,

    font: Font,
    font_size: f32,

    last_id: Id,

    window: ^wnd.Window,
    nvg_ctx: ^nvg.Context,
}

create :: proc(
    title := "",
    size := Vec2{400, 300},
    min_size: Maybe(Vec2) = nil,
    max_size: Maybe(Vec2) = nil,
    swap_interval := 1,
    dark_mode := true,
    resizable := true,
    double_buffer := true,
) -> (^Context, Context_Error) {
    ctx := new(Context)
    window, err := wnd.create(
        title,
        size,
        min_size,
        max_size,
        swap_interval,
        dark_mode,
        resizable,
        double_buffer,
    )
    if err != nil {
        free(ctx)
        return nil, err
    }

    ctx.window = window
    window.user_data = ctx

    wnd.activate_context(window)
    gl.load_up_to(3, 3, wnd.gl_set_proc_address)
    ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
    wnd.deactivate_context(window)

    wnd.set_on_mouse_move(ctx.window, proc(window: ^wnd.Window, position: [2]f32) {
        ctx := cast(^Context)window.user_data
        ctx.global_mouse_position = position
    })
    wnd.set_on_mouse_enter(ctx.window, proc(window: ^wnd.Window) {
        ctx := cast(^Context)window.user_data
        ctx.window_is_hovered = true
    })
    wnd.set_on_mouse_exit(ctx.window, proc(window: ^wnd.Window) {
        ctx := cast(^Context)window.user_data
        ctx.window_is_hovered = false
    })
    wnd.set_on_mouse_wheel(ctx.window, proc(window: ^wnd.Window, amount: [2]f32) {
        ctx := cast(^Context)window.user_data
        ctx.mouse_wheel_state = amount
    })
    wnd.set_on_mouse_press(ctx.window, proc(window: ^wnd.Window, button: Mouse_Button) {
        ctx := cast(^Context)window.user_data
        ctx.mouse_down_states[button] = true
        append(&ctx.mouse_presses, button)
    })
    wnd.set_on_mouse_release(ctx.window, proc(window: ^wnd.Window, button: Mouse_Button) {
        ctx := cast(^Context)window.user_data
        ctx.mouse_down_states[button] = false
        append(&ctx.mouse_releases, button)
    })
    wnd.set_on_key_press(ctx.window, proc(window: ^wnd.Window, key: Keyboard_Key) {
        ctx := cast(^Context)window.user_data
        ctx.key_down_states[key] = true
        append(&ctx.key_presses, key)
    })
    wnd.set_on_key_release(ctx.window, proc(window: ^wnd.Window, key: Keyboard_Key) {
        ctx := cast(^Context)window.user_data
        ctx.key_down_states[key] = false
        append(&ctx.key_releases, key)
    })
    wnd.set_on_rune(ctx.window, proc(window: ^wnd.Window, r: rune) {
        ctx := cast(^Context)window.user_data
        strings.write_rune(&ctx.text_input, r)
    })

    return ctx, nil
}

destroy :: proc(ctx: ^Context) {
    wnd.activate_context(ctx.window)
    nvg_gl.Destroy(ctx.nvg_ctx)
    wnd.deactivate_context(ctx.window)

    wnd.destroy(ctx.window)

    delete(ctx.mouse_presses)
    delete(ctx.mouse_releases)
    delete(ctx.key_presses)
    delete(ctx.key_releases)
    strings.builder_destroy(&ctx.text_input)

    delete(ctx.offset_stack)
    delete(ctx.clip_region_stack)
    delete(ctx.interaction_tracker_stack)
    delete(ctx.layers)
    delete(ctx.layer_stack)

    free(ctx)
}

update :: proc(ctx: ^Context) {
    wnd.update(ctx.window)
}

generate_id :: proc(ctx: ^Context) -> Id {
    ctx.last_id += 1
    return ctx.last_id
}

activate_gl_context :: proc(ctx: ^Context) {
    wnd.activate_context(ctx.window)
}

deactivate_gl_context :: proc(ctx: ^Context) {
    wnd.deactivate_context(ctx.window)
}

close :: proc(ctx: ^Context) {
    wnd.close(ctx.window)
}

close_requested :: proc(ctx: ^Context) -> bool {
    return wnd.close_requested(ctx.window)
}

show :: proc(ctx: ^Context) {
    wnd.show(ctx.window)
}

hide :: proc(ctx: ^Context) {
    wnd.hide(ctx.window)
}

position :: proc(ctx: ^Context) -> Vec2 {
    return wnd.position(ctx.window)
}

size :: proc(ctx: ^Context) -> Vec2 {
    return wnd.size(ctx.window)
}

content_scale :: proc(ctx: ^Context) -> f32 {
    return wnd.content_scale(ctx.window)
}

set_background_color :: proc(ctx: ^Context, color: Color) {
    ctx.background_color = color
}

set_on_frame :: proc(ctx: ^Context, on_frame: proc(^Context)) {
    ctx.on_frame = on_frame
    wnd.set_on_frame(ctx.window, proc(window: ^wnd.Window) {
        ctx := cast(^Context)window.user_data
        ctx->on_frame()
    })
}

window_is_hovered :: proc(ctx: ^Context) -> bool {
    return ctx.window_is_hovered
}

global_mouse_position :: proc(ctx: ^Context) -> Vec2 {
    return ctx.global_mouse_position
}

mouse_position :: proc(ctx: ^Context) -> Vec2 {
    return ctx.global_mouse_position - current_offset(ctx)
}

mouse_delta :: proc(ctx: ^Context) -> Vec2 {
    return ctx.global_mouse_position - ctx.previous_global_mouse_position
}

delta_time :: proc(ctx: ^Context) -> time.Duration {
    return time.tick_diff(ctx.previous_tick, ctx.tick)
}

mouse_down :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
    return ctx.mouse_down_states[button]
}

key_down :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
    return ctx.key_down_states[key]
}

mouse_wheel :: proc(ctx: ^Context) -> Vec2 {
    return ctx.mouse_wheel_state
}

mouse_moved :: proc(ctx: ^Context) -> bool {
    return mouse_delta(ctx) != {0, 0}
}

mouse_wheel_moved :: proc(ctx: ^Context) -> bool {
    return ctx.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
    return slice.contains(ctx.mouse_presses[:], button)
}

mouse_released :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
    return slice.contains(ctx.mouse_releases[:], button)
}

any_mouse_pressed :: proc(ctx: ^Context) -> bool {
    return len(ctx.mouse_presses) > 0
}

any_mouse_released :: proc(ctx: ^Context) -> bool {
    return len(ctx.mouse_releases) > 0
}

key_pressed :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
    return slice.contains(ctx.key_presses[:], key)
}

key_released :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
    return slice.contains(ctx.key_releases[:], key)
}

any_key_pressed :: proc(ctx: ^Context) -> bool {
    return len(ctx.key_presses) > 0
}

any_key_released :: proc(ctx: ^Context) -> bool {
    return len(ctx.key_releases) > 0
}

key_presses :: proc(ctx: ^Context) -> []Keyboard_Key {
    return ctx.key_presses[:]
}

key_releases :: proc(ctx: ^Context) -> []Keyboard_Key {
    return ctx.key_releases[:]
}

text_input :: proc(ctx: ^Context) -> string {
    return strings.to_string(ctx.text_input)
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

begin_frame :: proc(ctx: ^Context) {
    bg := ctx.background_color
    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    size := size(ctx)
    content_scale := content_scale(ctx)
    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(ctx.nvg_ctx, .LEFT, .TOP)
    ctx.font = 0
    ctx.font_size = 16.0

    begin_z_index(ctx, 0, global = true)
    begin_offset(ctx, 0, global = true)
    begin_clip_region(ctx, {{0, 0}, size}, global = true, intersect = false)
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
    // Stable sort preserves the order of layers with the same z index, so they
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
        _render_draw_commands(ctx, layer.draw_commands[:])

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

    nvg.EndFrame(ctx.nvg_ctx)
}