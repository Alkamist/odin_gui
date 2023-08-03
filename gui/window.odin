package gui

import "core:fmt"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import backend "window"

Window_Child_Kind :: backend.Child_Kind
Native_Window_Handle :: backend.Native_Handle

Window_Parameters :: struct {
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    resizable: bool,
    double_buffer: bool,
    background_color: Color,
    child_kind: Window_Child_Kind,
    parent_handle: Native_Window_Handle,
}

default_window_parameters := Window_Parameters{
    min_size = nil,
    max_size = nil,
    swap_interval = 1,
    dark_mode = true,
    resizable = true,
    double_buffer = true,
    background_color = {0, 0, 0, 1},
    child_kind = .None,
    parent_handle = nil,
}

Window :: struct {
    id: string,

    initial_size: Vec2,
    mouse_position: Vec2,
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

    background_color: Color,

    is_hovered: bool,
    open_pending: bool,
    reload_pending: bool,

    pending_position: Maybe(Vec2),
    pending_size: Maybe(Vec2),
    pending_visibility: Maybe(bool),

    parameters: Window_Parameters,
    previous_parameters: Window_Parameters,

    nvg_ctx: ^nvg.Context,
    current_font: ^Font,
    current_font_size: f32,

    hover: Id,
    mouse_over: Id,
    hover_capture: Id,

    current_layer: ^Layer,
    current_offset: Vec2,

    offset_stack: [dynamic]Vec2,
    clip_region_stack: [dynamic]Region,
    // interaction_tracker_stack: [dynamic]Interaction_Tracker,
    layer_stack: [dynamic]Layer,

    highest_z_index: int,
    layers: [dynamic]Layer,

    child_windows: map[string]^Window,
    loaded_fonts: [dynamic]^Font,

    backend_window: backend.Window,
}

current_window :: proc() -> ^Window {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    return w
}

set_window_background_color :: proc(color: Color, w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.background_color = color
}

window_position :: proc(w := ctx.current_window) -> Vec2 {
    assert(w != nil, "No window currently exists.")
    return backend.position(&w.backend_window)
}

set_window_position :: proc(position: Vec2, w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.pending_position = position
}

window_size :: proc(w := ctx.current_window) -> Vec2 {
    assert(w != nil, "No window currently exists.")
    return backend.size(&w.backend_window)
}

set_window_size :: proc(size: Vec2, w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.pending_size = size
}

window_content_scale :: proc(w := ctx.current_window) -> f32 {
    assert(w != nil, "No window currently exists.")
    return backend.content_scale(&w.backend_window)
}

open_window :: proc(w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.open_pending = true
}

reload_window :: proc(w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    backend_window := &w.backend_window
    w.reload_pending = true
    w.initial_size = backend.size(backend_window)
    w.pending_position = backend.position(backend_window)
    w.pending_visibility = backend.is_visible(backend_window)
}

close_window :: proc(w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.backend_window.close_requested = true
}

show_window :: proc(w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.pending_visibility = true
}

hide_window :: proc(w := ctx.current_window) {
    assert(w != nil, "No window currently exists.")
    w.pending_visibility = false
}

window_is_visible :: proc(w := ctx.current_window) -> bool {
    assert(w != nil, "No window currently exists.")
    return backend.is_visible(&w.backend_window)
}

window_closed :: proc(w := ctx.current_window) -> bool {
    assert(w != nil, "No window currently exists.")
    return w.backend_window.close_requested
}

window_is_hovered :: proc(w := ctx.current_window) -> bool {
    assert(w != nil, "No window currently exists.")
    return w.is_hovered
}

begin_window :: proc(id: string, parameters: Window_Parameters, size: Vec2) -> bool {
    window_map: ^map[string]^Window
    if ctx.current_window == nil {
        window_map = &ctx.top_level_windows
    } else {
        window_map = &ctx.current_window.child_windows
    }

    w, exists := window_map[id]
    if !exists {
        w = new(Window)
        w.id = id
        w.initial_size = size
        w.parameters = parameters
        w.previous_parameters = parameters
        w.open_pending = true
        window_map[id] = w
    }

    if !_sync_backend_window(w) {
        return false
    }

    backend.activate_context(&w.backend_window)

    append(&ctx.window_stack, w)
    ctx.current_window = w

    bg := w.background_color

    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    content_scale := backend.content_scale(&w.backend_window)
    size := backend.size(&w.backend_window)

    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    nvg.BeginFrame(w.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(w.nvg_ctx, .LEFT, .TOP)
    w.current_font = ctx.default_font
    w.current_font_size = 16.0

    begin_z_index(0, global = true)
    begin_clip({0, 0}, size, global = true, intersect = false)

    return true
}

end_window :: proc() {
    end_clip()
    end_z_index()

    assert(len(ctx.window_stack) > 0, "Mismatch in begin_window and end_window calls.")
    w := pop(&ctx.window_stack)

    assert(len(w.offset_stack) == 0, "Mismatch in begin_offset and end_offset calls.")
    assert(len(w.clip_region_stack) == 0, "Mismatch in begin_clip and end_clip calls.")
    // assert(len(w.interaction_tracker_stack) == 0, "Mismatch in begin_interaction_tracker and end_interaction_tracker calls.")
    assert(len(w.layer_stack) == 0, "Mismatch in begin_z_index and end_z_index calls.")

    // The layers are in reverse order because they were added in end_z_index.
    // Stable sort preserves the order of layers with the same z index, so they
    // must first be reversed and then sorted to keep that ordering in tact.
    slice.reverse(w.layers[:])
    slice.stable_sort_by(w.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    w.hover = 0
    w.mouse_over = 0
    highest_z_index := min(int)

    for layer in w.layers {
        if layer.z_index > highest_z_index {
            highest_z_index = layer.z_index
        }
        _render_draw_commands(w, layer.draw_commands[:])

        hover_request := layer.final_hover_request
        if hover_request != 0 {
            w.hover = hover_request
            w.mouse_over = hover_request
        }

        delete(layer.draw_commands)
    }

    if w.hover_capture != 0 {
        w.hover = w.hover_capture
    }

    w.highest_z_index = highest_z_index

    clear(&w.mouse_presses)
    clear(&w.mouse_releases)
    clear(&w.key_presses)
    clear(&w.key_releases)
    strings.builder_reset(&w.text_input)
    w.mouse_wheel_state = {0, 0}
    w.previous_global_mouse_position = w.global_mouse_position

    clear(&w.layers)

    backend.activate_context(&w.backend_window)
    nvg.EndFrame(w.nvg_ctx)

    if w.backend_window.close_requested {
        _close_window(w)
    } else {
        _sync_backend_window(w)
    }

    if len(ctx.window_stack) == 0 {
        ctx.current_window = nil
    } else {
        ctx.current_window = ctx.window_stack[len(ctx.window_stack) - 1]
        backend.activate_context(&ctx.current_window.backend_window)
    }
}

scoped_end_window :: proc(is_open: bool) {
    if is_open {
        end_window()
    }
}

@(deferred_out=scoped_end_window)
window_ex :: proc(id: string, parameters := default_window_parameters, initial_size: Vec2 = {400, 300}) -> bool {
    return begin_window(id, parameters, initial_size)
}

@(deferred_out=scoped_end_window)
window :: proc(id: string, child_kind: Window_Child_Kind = .None, initial_size: Vec2 = {400, 300}) -> bool {
    parameters := default_window_parameters
    parameters.child_kind = child_kind
    return begin_window(id, parameters, initial_size)
}



@(private)
_open_window :: proc(w: ^Window, initial_size: Vec2) -> bool {
    backend_window := &w.backend_window
    if backend.is_open(backend_window) {
        return true
    }

    parameters := &w.parameters

    if parameters.child_kind != .None {
        if ctx.current_window != nil {
            parameters.parent_handle = backend.native_handle(&ctx.current_window.backend_window)
        } else {
            parameters.parent_handle  = ctx.host_handle
        }
    }

    w.previous_parameters.parent_handle = parameters.parent_handle

    err := backend.open(backend_window,
        title = w.id,
        size = initial_size,
        min_size = parameters.min_size,
        max_size = parameters.max_size,
        swap_interval = parameters.swap_interval,
        dark_mode = parameters.dark_mode,
        resizable = parameters.resizable,
        double_buffer = parameters.double_buffer,
        child_kind = parameters.child_kind,
        parent_handle = parameters.parent_handle,
    )

    if err != nil {
        return false
    }

    backend_window.user_data = w

    backend.activate_context(backend_window)
    w.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

    _setup_window_callbacks(w)

    return true
}

@(private)
_close_window :: proc(w: ^Window) {
    backend_window := &w.backend_window
    if !backend.is_open(backend_window) {
        return
    }
    for _, child in w.child_windows {
        _close_window(child)
    }
    backend.activate_context(backend_window)
    nvg_gl.Destroy(w.nvg_ctx)
    w.nvg_ctx = nil
    backend.close(backend_window)
    clear(&w.loaded_fonts)
}

@(private)
_destroy_window :: proc(w: ^Window) {
    for _, child in w.child_windows {
        _destroy_window(child)
    }

    delete(w.mouse_presses)
    delete(w.mouse_releases)
    delete(w.key_presses)
    delete(w.key_releases)
    strings.builder_destroy(&w.text_input)
    delete(w.child_windows)
    delete(w.loaded_fonts)

    delete(w.offset_stack)
    delete(w.clip_region_stack)
    // delete(w.interaction_tracker_stack)
    delete(w.layer_stack)
    delete(w.layers)

    free(w)
}

@(private)
_sync_backend_window :: proc(w: ^Window) -> bool {
    if w.parameters != w.previous_parameters {
        reload_window(w)
    }
    w.previous_parameters = w.parameters

    if w.reload_pending {
        _close_window(w)
    }

    if w.open_pending || w.reload_pending {
        if !_open_window(w, w.initial_size) {
            fmt.eprintf("Failed to open window: %v\n", w.id)
            return false
        }
        if !w.reload_pending {
            backend.show(&w.backend_window)
        }
        w.open_pending = false
        w.reload_pending = false
    }

    if !backend.is_open(&w.backend_window) {
        return false
    }

    if position, ok := w.pending_position.?; ok {
        backend.set_position(&w.backend_window, position)
        w.pending_position = nil
    }

    if size, ok := w.pending_size.?; ok {
        backend.set_position(&w.backend_window, size)
        w.pending_size = nil
    }

    if is_visible, ok := w.pending_visibility.?; ok {
        if is_visible {
            backend.show(&w.backend_window)
        } else {
            backend.hide(&w.backend_window)
        }
        w.pending_visibility = nil
    }

    return true
}

@(private)
_setup_window_callbacks :: proc(w: ^Window) {
    backend.set_on_mouse_move(&w.backend_window, proc(backend_window: ^backend.Window, position, global_position: [2]f32) {
        w := cast(^Window)backend_window.user_data
        w.mouse_position = position
        w.global_mouse_position = global_position
    })
    backend.set_on_mouse_enter(&w.backend_window, proc(backend_window: ^backend.Window) {
        w := cast(^Window)backend_window.user_data
        w.is_hovered = true
    })
    backend.set_on_mouse_exit(&w.backend_window, proc(backend_window: ^backend.Window) {
        w := cast(^Window)backend_window.user_data
        w.is_hovered = false
    })
    backend.set_on_mouse_wheel(&w.backend_window, proc(backend_window: ^backend.Window, amount: [2]f32) {
        w := cast(^Window)backend_window.user_data
        w.mouse_wheel_state = amount
    })
    backend.set_on_mouse_press(&w.backend_window, proc(backend_window: ^backend.Window, button: Mouse_Button) {
        w := cast(^Window)backend_window.user_data
        w.mouse_down_states[button] = true
        append(&w.mouse_presses, button)
    })
    backend.set_on_mouse_release(&w.backend_window, proc(backend_window: ^backend.Window, button: Mouse_Button) {
        w := cast(^Window)backend_window.user_data
        w.mouse_down_states[button] = false
        append(&w.mouse_releases, button)
    })
    backend.set_on_key_press(&w.backend_window, proc(backend_window: ^backend.Window, key: Keyboard_Key) {
        w := cast(^Window)backend_window.user_data
        w.key_down_states[key] = true
        append(&w.key_presses, key)
    })
    backend.set_on_key_release(&w.backend_window, proc(backend_window: ^backend.Window, key: Keyboard_Key) {
        w := cast(^Window)backend_window.user_data
        w.key_down_states[key] = false
        append(&w.key_releases, key)
    })
    backend.set_on_rune(&w.backend_window, proc(backend_window: ^backend.Window, r: rune) {
        w := cast(^Window)backend_window.user_data
        strings.write_rune(&w.text_input, r)
    })
}