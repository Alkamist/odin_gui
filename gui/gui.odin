package gui

import "core:fmt"
import "core:time"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import gl "vendor:OpenGL"
import "window"

@(thread_local) ctx: ^Context

Font :: int
Vec2 :: [2]f32
Color :: [4]f32

Cursor_Style :: window.Cursor_Style
Mouse_Button :: window.Mouse_Button
Keyboard_Key :: window.Keyboard_Key

Path_Winding :: enum {
    Positive,
    Negative,
}

Window :: struct {
    using window: ^window.Window,
    is_hovered: bool,
    tick: time.Tick,
    previous_tick: time.Tick,
    mouse_position: Vec2,
    previous_mouse_position: Vec2,
    mouse_wheel_state: Vec2,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,
}

Context :: struct {
    update_proc: proc(),

    nvg_ctx: ^nvg.Context,
    font: Font,
    font_size: f32,

    dummy_window: ^window.Window,
    current_window: ^Window,
    windows: map[string]^Window,
    window_stack: [dynamic]^Window,
}

startup :: proc(on_update: proc()) {
    dummy_window, err := window.create()
    if err != nil {
        fmt.eprintln("Failed to create gui context.")
        return
    }

    ctx = new(Context)
    ctx.dummy_window = dummy_window
    dummy_window.user_data = ctx

    window.activate_context(dummy_window)
    gl.load_up_to(3, 3, window.gl_set_proc_address)
    ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
    window.deactivate_context(dummy_window)

    ctx.update_proc = on_update

    window.set_on_update(dummy_window, proc(dummy_window: ^window.Window) {
        ctx := cast(^Context)dummy_window.user_data
        ctx.update_proc()
    })
}

shutdown :: proc() {
    dummy_window := ctx.dummy_window
    window.activate_context(dummy_window)
    nvg_gl.Destroy(ctx.nvg_ctx)
    window.deactivate_context(dummy_window)
    window.destroy(dummy_window)

    // Clean up windows.
    for key in ctx.windows {
        w := ctx.windows[key]
        if w.window != nil {
            window.destroy(w)
        }
        delete(w.mouse_presses)
        delete(w.mouse_releases)
        delete(w.key_presses)
        delete(w.key_releases)
        strings.builder_destroy(&w.text_input)
        free(w)
    }

    delete(ctx.windows)
    delete(ctx.window_stack)

    free(ctx)
}

update :: proc() {
    window.update(ctx.dummy_window)
}

@(private)
setup_window_callbacks :: proc(w: ^Window) {
    window.set_on_mouse_move(w, proc(_w: ^window.Window, position: [2]f32) {
        w := cast(^Window)_w.user_data
        w.mouse_position = position
    })
    window.set_on_mouse_enter(w, proc(_w: ^window.Window) {
        w := cast(^Window)_w.user_data
        w.is_hovered = true
    })
    window.set_on_mouse_exit(w, proc(_w: ^window.Window) {
        w := cast(^Window)_w.user_data
        w.is_hovered = false
    })
    window.set_on_mouse_wheel(w, proc(_w: ^window.Window, amount: [2]f32) {
        w := cast(^Window)_w.user_data
        w.mouse_wheel_state = amount
    })
    window.set_on_mouse_press(w, proc(_w: ^window.Window, button: Mouse_Button) {
        w := cast(^Window)_w.user_data
        w.mouse_down_states[button] = true
        append(&w.mouse_presses, button)
    })
    window.set_on_mouse_release(w, proc(_w: ^window.Window, button: Mouse_Button) {
        w := cast(^Window)_w.user_data
        w.mouse_down_states[button] = false
        append(&w.mouse_releases, button)
    })
    window.set_on_key_press(w, proc(_w: ^window.Window, key: Keyboard_Key) {
        w := cast(^Window)_w.user_data
        w.key_down_states[key] = true
        append(&w.key_presses, key)
    })
    window.set_on_key_release(w, proc(_w: ^window.Window, key: Keyboard_Key) {
        w := cast(^Window)_w.user_data
        w.key_down_states[key] = false
        append(&w.key_releases, key)
    })
    window.set_on_rune(w, proc(_w: ^window.Window, r: rune) {
        w := cast(^Window)_w.user_data
        strings.write_rune(&w.text_input, r)
    })
}

begin_window :: proc(id: string, background_color := Color{0, 0, 0, 1}) -> bool {
    w, exists := ctx.windows[id]
    if !exists {
        _w, err := window.create(id)
        if err != nil {
            fmt.eprintf("Failed to open window: %v", id)
            return false
        }
        w = new(Window)
        w.window = _w
        _w.user_data = w
        ctx.windows[id] = w
        setup_window_callbacks(w)
        window.show(w)
    }

    if w.window == nil {
        return false
    }

    append(&ctx.window_stack, w)
    ctx.current_window = w

    window.update(w)
    window.activate_context(ctx.dummy_window)

    size := window.size(w)
    content_scale := window.content_scale(w)

    gl.ClearColor(background_color.r, background_color.g, background_color.b, background_color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    gl.Viewport(0, 0, i32(size.x), i32(size.y))

    nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(ctx.nvg_ctx, .LEFT, .TOP)
    ctx.font = 0
    ctx.font_size = 16.0

    return true
}

end_window :: proc() {
    assert(len(ctx.window_stack) > 0, "Mismatch in begin_window and end_window calls.")
    w := pop(&ctx.window_stack)

    clear(&w.mouse_presses)
    clear(&w.mouse_releases)
    clear(&w.key_presses)
    clear(&w.key_releases)
    strings.builder_reset(&w.text_input)
    w.mouse_wheel_state = {0, 0}
    w.previous_mouse_position = w.mouse_position
    w.previous_tick = w.tick

    window.deactivate_context(ctx.dummy_window)

    if window.close_requested(w) {
        window.destroy(w)
        w.window = nil
    }

    if len(ctx.window_stack) == 0 {
        ctx.current_window = nil
    } else {
        ctx.current_window = ctx.window_stack[len(ctx.window_stack) - 1]
    }

    nvg.EndFrame(ctx.nvg_ctx)
}

window_will_close :: proc() -> bool {
    return window.close_requested(ctx.current_window)
}

window_is_hovered :: proc() -> bool {
    return ctx.current_window.is_hovered
}

mouse_position :: proc() -> Vec2 {
    return ctx.current_window.mouse_position
}

mouse_delta :: proc() -> Vec2 {
    return ctx.current_window.mouse_position - ctx.current_window.previous_mouse_position
}

delta_time :: proc() -> time.Duration {
    return time.tick_diff(ctx.current_window.previous_tick, ctx.current_window.tick)
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return ctx.current_window.mouse_down_states[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return ctx.current_window.key_down_states[key]
}

mouse_wheel :: proc() -> Vec2 {
    return ctx.current_window.mouse_wheel_state
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return ctx.current_window.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(ctx.current_window.mouse_presses[:], button)
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(ctx.current_window.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(ctx.current_window.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(ctx.current_window.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(ctx.current_window.key_presses[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(ctx.current_window.key_releases[:], key)
}

any_key_pressed :: proc() -> bool {
    return len(ctx.current_window.key_presses) > 0
}

any_key_released :: proc() -> bool {
    return len(ctx.current_window.key_releases) > 0
}

key_presses :: proc() -> []Keyboard_Key {
    return ctx.current_window.key_presses[:]
}

key_releases :: proc() -> []Keyboard_Key {
    return ctx.current_window.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(ctx.current_window.text_input)
}











// create :: proc(
//     title := "",
//     size := Vec2{400, 300},
//     min_size: Maybe(Vec2) = nil,
//     max_size: Maybe(Vec2) = nil,
//     swap_interval := 1,
//     dark_mode := true,
//     resizable := true,
//     double_buffer := true,
// ) -> (^Context, Context_Error) {
//     ctx := new(Context)
//     w, err := window.create(
//         title,
//         size,
//         min_size,
//         max_size,
//         swap_interval,
//         dark_mode,
//         resizable,
//         double_buffer,
//     )
//     if err != nil {
//         free(ctx)
//         return nil, err
//     }

//     ctx.window = w
//     w.user_data = ctx

//     window.activate_context(w)
//     gl.load_up_to(3, 3, window.gl_set_proc_address)
//     ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
//     window.deactivate_context(w)

//     window.set_on_mouse_move(ctx.window, proc(w: ^window.Window, position: [2]f32) {
//         ctx := cast(^Context)w.user_data
//         ctx.global_mouse_position = position
//     })
//     window.set_on_mouse_enter(ctx.window, proc(w: ^window.Window) {
//         ctx := cast(^Context)w.user_data
//         ctx.window_is_hovered = true
//     })
//     window.set_on_mouse_exit(ctx.window, proc(w: ^window.Window) {
//         ctx := cast(^Context)w.user_data
//         ctx.window_is_hovered = false
//     })
//     window.set_on_mouse_wheel(ctx.window, proc(w: ^window.Window, amount: [2]f32) {
//         ctx := cast(^Context)w.user_data
//         ctx.mouse_wheel_state = amount
//     })
//     window.set_on_mouse_press(ctx.window, proc(w: ^window.Window, button: Mouse_Button) {
//         ctx := cast(^Context)w.user_data
//         ctx.mouse_down_states[button] = true
//         append(&ctx.mouse_presses, button)
//     })
//     window.set_on_mouse_release(ctx.window, proc(w: ^window.Window, button: Mouse_Button) {
//         ctx := cast(^Context)w.user_data
//         ctx.mouse_down_states[button] = false
//         append(&ctx.mouse_releases, button)
//     })
//     window.set_on_key_press(ctx.window, proc(w: ^window.Window, key: Keyboard_Key) {
//         ctx := cast(^Context)w.user_data
//         ctx.key_down_states[key] = true
//         append(&ctx.key_presses, key)
//     })
//     window.set_on_key_release(ctx.window, proc(w: ^window.Window, key: Keyboard_Key) {
//         ctx := cast(^Context)w.user_data
//         ctx.key_down_states[key] = false
//         append(&ctx.key_releases, key)
//     })
//     window.set_on_rune(ctx.window, proc(w: ^window.Window, r: rune) {
//         ctx := cast(^Context)w.user_data
//         strings.write_rune(&ctx.text_input, r)
//     })

//     return ctx, nil
// }

// destroy :: proc(ctx: ^Context) {
//     window.activate_context(ctx.window)
//     nvg_gl.Destroy(ctx.nvg_ctx)
//     window.deactivate_context(ctx.window)

//     window.destroy(ctx.window)

//     delete(ctx.mouse_presses)
//     delete(ctx.mouse_releases)
//     delete(ctx.key_presses)
//     delete(ctx.key_releases)
//     strings.builder_destroy(&ctx.text_input)

//     delete(ctx.offset_stack)
//     delete(ctx.clip_region_stack)
//     delete(ctx.interaction_tracker_stack)
//     delete(ctx.layers)
//     delete(ctx.layer_stack)

//     free(ctx)
// }

// update :: proc(ctx: ^Context) {
//     window.update(ctx.window)
// }

// activate_gl_context :: proc(ctx: ^Context) {
//     window.activate_context(ctx.window)
// }

// deactivate_gl_context :: proc(ctx: ^Context) {
//     window.deactivate_context(ctx.window)
// }

// close :: proc(ctx: ^Context) {
//     window.close(ctx.window)
// }

// close_requested :: proc(ctx: ^Context) -> bool {
//     return window.close_requested(ctx.window)
// }

// show :: proc(ctx: ^Context) {
//     window.show(ctx.window)
// }

// hide :: proc(ctx: ^Context) {
//     window.hide(ctx.window)
// }

// position :: proc(ctx: ^Context) -> Vec2 {
//     return window.position(ctx.window)
// }

// size :: proc(ctx: ^Context) -> Vec2 {
//     return window.size(ctx.window)
// }

// content_scale :: proc(ctx: ^Context) -> f32 {
//     return window.content_scale(ctx.window)
// }

// set_background_color :: proc(ctx: ^Context, color: Color) {
//     ctx.background_color = color
// }

// set_on_frame :: proc(ctx: ^Context, on_frame: proc(^Context)) {
//     ctx.on_frame = on_frame
//     window.set_on_frame(ctx.window, proc(window: ^window.Window) {
//         ctx := cast(^Context)window.user_data
//         ctx->on_frame()
//     })
// }

// window_is_hovered :: proc(ctx: ^Context) -> bool {
//     return ctx.window_is_hovered
// }

// global_mouse_position :: proc(ctx: ^Context) -> Vec2 {
//     return ctx.global_mouse_position
// }

// mouse_position :: proc(ctx: ^Context) -> Vec2 {
//     return ctx.global_mouse_position - current_offset(ctx)
// }

// mouse_delta :: proc(ctx: ^Context) -> Vec2 {
//     return ctx.global_mouse_position - ctx.previous_global_mouse_position
// }

// delta_time :: proc(ctx: ^Context) -> time.Duration {
//     return time.tick_diff(ctx.previous_tick, ctx.tick)
// }

// mouse_down :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
//     return ctx.mouse_down_states[button]
// }

// key_down :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
//     return ctx.key_down_states[key]
// }

// mouse_wheel :: proc(ctx: ^Context) -> Vec2 {
//     return ctx.mouse_wheel_state
// }

// mouse_moved :: proc(ctx: ^Context) -> bool {
//     return mouse_delta(ctx) != {0, 0}
// }

// mouse_wheel_moved :: proc(ctx: ^Context) -> bool {
//     return ctx.mouse_wheel_state != {0, 0}
// }

// mouse_pressed :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
//     return slice.contains(ctx.mouse_presses[:], button)
// }

// mouse_released :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
//     return slice.contains(ctx.mouse_releases[:], button)
// }

// any_mouse_pressed :: proc(ctx: ^Context) -> bool {
//     return len(ctx.mouse_presses) > 0
// }

// any_mouse_released :: proc(ctx: ^Context) -> bool {
//     return len(ctx.mouse_releases) > 0
// }

// key_pressed :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
//     return slice.contains(ctx.key_presses[:], key)
// }

// key_released :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
//     return slice.contains(ctx.key_releases[:], key)
// }

// any_key_pressed :: proc(ctx: ^Context) -> bool {
//     return len(ctx.key_presses) > 0
// }

// any_key_released :: proc(ctx: ^Context) -> bool {
//     return len(ctx.key_releases) > 0
// }

// key_presses :: proc(ctx: ^Context) -> []Keyboard_Key {
//     return ctx.key_presses[:]
// }

// key_releases :: proc(ctx: ^Context) -> []Keyboard_Key {
//     return ctx.key_releases[:]
// }

// text_input :: proc(ctx: ^Context) -> string {
//     return strings.to_string(ctx.text_input)
// }

// current_offset :: proc(ctx: ^Context) -> Vec2 {
//     return ctx.offset_stack[len(ctx.offset_stack) - 1]
// }

// begin_offset :: proc(ctx: ^Context, offset: Vec2, global := false) {
//     if global {
//         append(&ctx.offset_stack, offset)
//     } else {
//         append(&ctx.offset_stack, current_offset(ctx) + offset)
//     }
// }

// end_offset :: proc(ctx: ^Context) -> Vec2 {
//     return pop(&ctx.offset_stack)
// }

// current_clip_region :: proc(ctx: ^Context, global := false) -> Region {
//     region := ctx.clip_region_stack[len(ctx.clip_region_stack) - 1]
//     if !global {
//         region.position -= current_offset(ctx)
//     }
//     return region
// }

// begin_clip_region :: proc(ctx: ^Context, region: Region, global := false, intersect := true) {
//     region := region

//     // Make it global
//     if !global {
//         region.position += current_offset(ctx)
//     }

//     // Intersect with global
//     if intersect {
//         region = intersect_region(region, current_clip_region(ctx, global = true))
//     }

//     append(&ctx.clip_region_stack, region)
//     append(&current_layer(ctx).draw_commands, Clip_Command{
//         region.position,
//         region.size,
//     })
// }

// end_clip_region :: proc(ctx: ^Context) -> Region {
//     result := pop(&ctx.clip_region_stack)

//     if len(ctx.clip_region_stack) == 0 {
//         return result
//     }

//     region := current_clip_region(ctx)
//     append(&current_layer(ctx).draw_commands, Clip_Command{
//         region.position,
//         region.size,
//     })

//     return result
// }

// current_z_index :: proc(ctx: ^Context) -> int {
//     return current_layer(ctx).z_index
// }

// begin_z_index :: proc(ctx: ^Context, z_index: int, global := false) {
//     if global {
//         append(&ctx.layer_stack, Layer{z_index = z_index})
//     } else {
//         append(&ctx.layer_stack, Layer{z_index = current_z_index(ctx) + z_index})
//     }
// }

// end_z_index :: proc(ctx: ^Context) -> int {
//     layer := pop(&ctx.layer_stack)
//     append(&ctx.layers, layer)
//     return layer.z_index
// }

// begin_interaction_tracker :: proc(ctx: ^Context) {
//     append(&ctx.interaction_tracker_stack, Interaction_Tracker{})
// }

// end_interaction_tracker :: proc(ctx: ^Context) -> Interaction_Tracker {
//     tracker := pop(&ctx.interaction_tracker_stack)

//     if tracker.detected_hover {
//         ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_hover = true
//     }

//     if tracker.detected_mouse_over {
//         ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_mouse_over = true
//     }

//     return tracker
// }

// is_hovered :: proc(ctx: ^Context, id: Id) -> bool {
//     return ctx.hover == id
// }

// mouse_is_over :: proc(ctx: ^Context, id: Id) -> bool {
//     return ctx.mouse_over == id
// }

// request_hover :: proc(ctx: ^Context, id: Id) {
//     current_layer(ctx).final_hover_request = id

//     if ctx.hover == id {
//         ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_hover = true
//     }

//     if ctx.mouse_over == id {
//         ctx.interaction_tracker_stack[len(ctx.interaction_tracker_stack) - 1].detected_mouse_over = true
//     }
// }

// capture_hover :: proc(ctx: ^Context, id: Id) {
//     if ctx.hover_capture == 0 {
//         ctx.hover_capture = id
//     }
// }

// release_hover :: proc(ctx: ^Context, id: Id) {
//     if ctx.hover_capture == id {
//         ctx.hover_capture = 0
//     }
// }

// mouse_hit_test :: proc(ctx: ^Context, position, size: Vec2) -> bool {
//     m := mouse_position(ctx)
//     return window_is_hovered(ctx) &&
//            m.x >= position.x && m.x <= position.x + size.x &&
//            m.y >= position.y && m.y <= position.y + size.y &&
//            region_contains_position(current_clip_region(ctx), m)
// }

// begin_frame :: proc(ctx: ^Context) {
//     bg := ctx.background_color
//     gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
//     gl.Clear(gl.COLOR_BUFFER_BIT)

//     size := size(ctx)
//     content_scale := content_scale(ctx)
//     gl.Viewport(0, 0, i32(size.x), i32(size.y))
//     nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, content_scale)
//     nvg.TextAlign(ctx.nvg_ctx, .LEFT, .TOP)
//     ctx.font = 0
//     ctx.font_size = 16.0

//     begin_z_index(ctx, 0, global = true)
//     begin_offset(ctx, 0, global = true)
//     begin_clip_region(ctx, {{0, 0}, size}, global = true, intersect = false)
//     append(&ctx.interaction_tracker_stack, Interaction_Tracker{})

//     ctx.tick = time.tick_now()
// }

// end_frame :: proc(ctx: ^Context) {
//     pop(&ctx.interaction_tracker_stack)
//     end_clip_region(ctx)
//     end_offset(ctx)
//     end_z_index(ctx)

//     assert(len(ctx.offset_stack) == 0, "Mismatch in begin_offset and end_offset calls.")
//     assert(len(ctx.clip_region_stack) == 0, "Mismatch in begin_clip_region and end_clip_region calls.")
//     assert(len(ctx.interaction_tracker_stack) == 0, "Mismatch in begin_interaction_tracker and end_interaction_tracker calls.")
//     assert(len(ctx.layer_stack) == 0, "Mismatch in begin_z_index and end_z_index calls.")

//     // The layers are in reverse order because they were added in end_z_index.
//     // Stable sort preserves the order of layers with the same z index, so they
//     // must first be reversed and then sorted to keep that ordering in tact.
//     slice.reverse(ctx.layers[:])
//     slice.stable_sort_by(ctx.layers[:], proc(i, j: Layer) -> bool {
//         return i.z_index < j.z_index
//     })

//     ctx.hover = 0
//     ctx.mouse_over = 0
//     highest_z_index := min(int)

//     for layer in ctx.layers {
//         if layer.z_index > highest_z_index {
//             highest_z_index = layer.z_index
//         }
//         _render_draw_commands(ctx, layer.draw_commands[:])

//         hover_request := layer.final_hover_request
//         if hover_request != 0 {
//             ctx.hover = hover_request
//             ctx.mouse_over = hover_request
//         }

//         delete(layer.draw_commands)
//     }

//     if ctx.hover_capture != 0 {
//         ctx.hover = ctx.hover_capture
//     }

//     ctx.highest_z_index = highest_z_index

//     clear(&ctx.layers)
//     clear(&ctx.mouse_presses)
//     clear(&ctx.mouse_releases)
//     clear(&ctx.key_presses)
//     clear(&ctx.key_releases)
//     strings.builder_reset(&ctx.text_input)
//     ctx.mouse_wheel_state = {0, 0}
//     ctx.previous_global_mouse_position = ctx.global_mouse_position
//     ctx.previous_tick = ctx.tick

//     nvg.EndFrame(ctx.nvg_ctx)
// }