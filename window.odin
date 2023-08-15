package gui

import "core:time"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import backend "window"
import "rect"

@(thread_local) _current_window: ^Window

Rect :: rect.Rect
Vec2 :: [2]f32

Native_Window_Handle :: backend.Native_Handle
Window_Child_Kind :: backend.Child_Kind

Window :: struct {
    user_data: rawptr,

    on_frame: proc(),
    on_close: proc(),

    background_color: Color,

    tick: time.Tick,
    previous_tick: time.Tick,
    client_area_hovered: bool,
    global_mouse_position: Vec2,
    root_mouse_position: Vec2,
    previous_root_mouse_position: Vec2,
    mouse_wheel_state: Vec2,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,

    hover: ^Widget,
    mouse_over: ^Widget,
    hover_capture: ^Widget,

    highest_z_index: int,

    offset_stack: [dynamic]Vec2,
    clip_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    interaction_tracker_stack: [dynamic]Interaction_Tracker,
    layers: [dynamic]Layer,

    current_font: ^Font,
    current_font_size: f32,
    nvg_ctx: ^nvg.Context,

    open_multiple_frames: bool,
    cached_content_scale: f32,

    loaded_fonts: [dynamic]^Font,

    using backend_window: backend.Window,
}

update :: backend.update

init_window :: proc(
    title := "",
    position := Vec2{0, 0},
    size := Vec2{400, 300},
    min_size: Maybe(Vec2) = nil,
    max_size: Maybe(Vec2) = nil,
    background_color := Color{0, 0, 0, 1},
    swap_interval := 1,
    dark_mode := true,
    is_visible := true,
    is_resizable := true,
    double_buffer := true,
    child_kind := Window_Child_Kind.None,
    parent_handle: Native_Window_Handle = nil,
    user_data: rawptr = nil,
    on_frame: proc() = nil,
) -> Window {
    return {
        backend_window = backend.init(
            title = title,
            position = position,
            size = size,
            min_size = min_size,
            max_size = max_size,
            swap_interval = swap_interval,
            dark_mode = dark_mode,
            is_visible = is_visible,
            is_resizable = is_resizable,
            double_buffer = double_buffer,
            child_kind = child_kind,
            parent_handle = parent_handle,
        ),
        background_color = background_color,
        user_data = user_data,
        on_frame = on_frame,
    }
}

activate_window_context :: proc(window: ^Window) {
    backend.activate_context(&window.backend_window)
}

deactivate_window_context :: proc(window: ^Window) {
    backend.deactivate_context(&window.backend_window)
}

native_window_handle :: proc(window: ^Window) -> Native_Window_Handle {
    return backend.native_handle(&window.backend_window)
}

set_window_parent :: proc(window: ^Window, parent: Native_Window_Handle) {
    window.backend_window.parent_handle = parent
}

set_window_child_kind :: proc(window: ^Window, child_kind: Window_Child_Kind) {
    window.backend_window.child_kind = child_kind
}

close_window :: proc(window := _current_window) {
    backend.close(&window.backend_window)
    window.open_multiple_frames = false
}

window_is_open :: proc(window := _current_window) -> bool {
    return backend.is_open(&window.backend_window)
}

window_is_visible :: proc(window := _current_window) -> bool {
    return backend.is_visible(&window.backend_window)
}

set_window_visibility :: proc(visibility: bool, window := _current_window) {
    backend.set_visibility(&window.backend_window, visibility)
}

window_position :: proc(window := _current_window) -> Vec2 {
    return backend.position(&window.backend_window)
}

set_window_position :: proc(position: Vec2, window := _current_window) {
    backend.set_position(&window.backend_window, position)
}

window_size :: proc(window := _current_window) -> Vec2 {
    return backend.size(&window.backend_window)
}

set_window_size :: proc(size: Vec2, window := _current_window) {
    backend.set_size(&window.backend_window, size)
}

window_content_scale :: proc(window := _current_window) -> f32 {
    return backend.content_scale(&window.backend_window)
}

destroy_window :: proc(window: ^Window) {
    delete(window.mouse_presses)
    delete(window.mouse_releases)
    delete(window.key_presses)
    delete(window.key_releases)
    delete(window.offset_stack)
    delete(window.clip_stack)
    delete(window.layer_stack)
    delete(window.interaction_tracker_stack)
    delete(window.layers)
    delete(window.loaded_fonts)
    backend.destroy(&window.backend_window)
}

open_window :: proc(window: ^Window) -> bool {
    if !backend.open(&window.backend_window) {
        return false
    }

    clear(&window.loaded_fonts)

    backend_window := &window.backend_window
    backend_window.backend_data = window

    activate_window_context(window)
    window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

    backend_window.backend_callbacks.on_close = proc(window: ^backend.Window) {
        window := cast(^Window)(window.backend_data)
        if window.on_close != nil {
            window.on_close()
        }
        nvg_gl.Destroy(window.nvg_ctx)
    }
    backend_window.backend_callbacks.on_mouse_move = proc(window: ^backend.Window, position, root_position: Vec2) {
        window := cast(^Window)(window.backend_data)
        window.global_mouse_position = position
        window.root_mouse_position = root_position
    }
    backend_window.backend_callbacks.on_mouse_enter = proc(window: ^backend.Window) {
        window := cast(^Window)(window.backend_data)
        window.client_area_hovered = true
    }
    backend_window.backend_callbacks.on_mouse_exit = proc(window: ^backend.Window) {
        window := cast(^Window)(window.backend_data)
        window.client_area_hovered = false
    }
    backend_window.backend_callbacks.on_mouse_wheel = proc(window: ^backend.Window, amount: Vec2) {
        window := cast(^Window)(window.backend_data)
        window.mouse_wheel_state = amount
    }
    backend_window.backend_callbacks.on_mouse_press = proc(window: ^backend.Window, button: Mouse_Button) {
        window := cast(^Window)(window.backend_data)
        window.mouse_down_states[button] = true
        append(&window.mouse_presses, button)
    }
    backend_window.backend_callbacks.on_mouse_release = proc(window: ^backend.Window, button: Mouse_Button) {
        window := cast(^Window)(window.backend_data)
        window.mouse_down_states[button] = false
        append(&window.mouse_releases, button)
    }
    backend_window.backend_callbacks.on_key_press = proc(window: ^backend.Window, key: Keyboard_Key) {
        window := cast(^Window)(window.backend_data)
        window.key_down_states[key] = true
        append(&window.key_presses, key)
    }
    backend_window.backend_callbacks.on_key_release = proc(window: ^backend.Window, key: Keyboard_Key) {
        window := cast(^Window)(window.backend_data)
        window.key_down_states[key] = false
        append(&window.key_releases, key)
    }
    backend_window.backend_callbacks.on_rune = proc(window: ^backend.Window, r: rune) {
        window := cast(^Window)(window.backend_data)
        strings.write_rune(&window.text_input, r)
    }
    backend_window.backend_callbacks.on_draw = proc(window: ^backend.Window) {
        window := cast(^Window)(window.backend_data)
        _begin_frame(window)
        if window.on_frame != nil {
            window.on_frame()
        }
        _end_frame(window)
    }

    return true
}



@(private)
_begin_frame :: proc(window: ^Window) {
    _current_window = window

    bg := window.background_color
    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    size := window_size(window)
    gl.Viewport(0, 0, i32(size.x), i32(size.y))

    content_scale := window_content_scale(window)
    window.cached_content_scale = content_scale

    nvg.BeginFrame(window.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(window.nvg_ctx, .LEFT, .TOP)

    window.current_font_size = 16.0

    window.tick = time.tick_now()
    if !window.open_multiple_frames {
        window.previous_tick = window.tick
    }

    begin_z_index(0, global = true)
    begin_offset({0, 0}, global = true)
    begin_clip({0, 0}, size, global = true, intersect = false)
    append(&window.interaction_tracker_stack, Interaction_Tracker{})
}

@(private)
_end_frame :: proc(window: ^Window) {
    pop(&window.interaction_tracker_stack)
    end_clip()
    end_offset()
    end_z_index()

    nvg.EndFrame(window.nvg_ctx)

    assert(len(window.offset_stack) == 0, "Mismatch in begin_offset and end_offset calls.")
    assert(len(window.layer_stack) == 0, "Mismatch in begin_z_index and end_z_index calls.")
    assert(len(window.clip_stack) == 0, "Mismatch in begin_clip and end_clip calls.")
    assert(len(window.interaction_tracker_stack) == 0, "Mismatch in begin_interaction_tracker and end_interaction_tracker calls.")

    // The layers are in reverse order because they were added in end_z_index.
    // Stable sort preserves the order of layers with the same z index, so they
    // must first be reversed and then sorted to keep that ordering in tact.
    slice.reverse(window.layers[:])
    slice.stable_sort_by(window.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    window.hover = nil
    window.mouse_over = nil
    highest_z_index := min(int)

    for layer in window.layers {
        if layer.z_index > highest_z_index {
            highest_z_index = layer.z_index
        }
        _render_draw_commands(window, layer.draw_commands[:])

        hover_request := layer.final_hover_request
        if hover_request != nil {
            window.hover = hover_request
            window.mouse_over = hover_request
        }

        delete(layer.draw_commands)
    }

    if window.hover_capture != nil {
        window.hover = window.hover_capture
    }

    window.highest_z_index = highest_z_index

    clear(&window.layers)
    clear(&window.mouse_presses)
    clear(&window.mouse_releases)
    clear(&window.key_presses)
    clear(&window.key_releases)
    strings.builder_reset(&window.text_input)
    window.mouse_wheel_state = {0, 0}
    window.previous_root_mouse_position = window.root_mouse_position
    window.previous_tick = window.tick

    window.open_multiple_frames = true
}