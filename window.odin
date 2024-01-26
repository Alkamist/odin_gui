package gui

import wnd "window"

@(thread_local) _current_window: ^Window

Vec2 :: wnd.Vec2

Window_Child_Kind :: wnd.Child_Kind
Native_Window_Handle :: wnd.Native_Handle

Window :: struct {
    backend: wnd.Window,
    root: Widget,
    focus: ^Widget,
    mouse_hit: ^Widget,
    hover: ^Widget,
    previous_hover: ^Widget,
    hover_captured: bool,
}

update :: wnd.update

// You must provide a stable pointer.
init_window :: proc(
    window: ^Window,
    title := "",
    position := Vec2{0, 0},
    size := Vec2{400, 300},
    min_size: Maybe(Vec2) = nil,
    max_size: Maybe(Vec2) = nil,
    swap_interval := 1,
    dark_mode := true,
    is_visible := true,
    is_resizable := true,
    double_buffer := true,
    child_kind := Window_Child_Kind.None,
    parent_handle: Native_Window_Handle = nil,
) {
    init_widget(&window.root, size = size)
    wnd.init(
        &window.backend,
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
    )
    window.backend.user_data = window
    window.backend.event_proc = _window_event_proc
    _current_window = window
}

destroy_window :: proc(window: ^Window) {
    destroy_widget(&window.root)
    wnd.destroy(&window.backend)
}

current_window :: proc() -> ^Window {
    return _current_window
}

open_window :: proc(window := _current_window) {
    wnd.open(&window.backend)
}

close_window :: proc(window := _current_window) {
    wnd.close(&window.backend)
}

redraw :: proc(window := _current_window) {
    wnd.redraw(&window.backend)
}

native_window_handle :: proc(window := _current_window) -> Native_Window_Handle {
    return wnd.native_handle(&window.backend)
}

activate_window_context :: proc(window := _current_window) {
    wnd.activate_context(&window.backend)
}

deactivate_window_context :: proc(window := _current_window) {
    wnd.deactivate_context(&window.backend)
}

window_is_open :: proc(window := _current_window) -> bool {
    return wnd.is_open(&window.backend)
}

window_is_visible :: proc(window := _current_window) -> bool {
    return wnd.is_visible(&window.backend)
}

set_window_visibility :: proc(visibility: bool, window := _current_window) {
    wnd.set_visibility(&window.backend, visibility)
}

window_position :: proc(window := _current_window) -> Vec2 {
    return wnd.position(&window.backend)
}

set_window_position :: proc(position: Vec2, window := _current_window) {
    wnd.set_position(&window.backend, position)
}

window_size :: proc(window := _current_window) -> Vec2 {
    return wnd.size(&window.backend)
}

set_window_size :: proc(size: Vec2, window := _current_window) {
    wnd.set_size(&window.backend, size)
}

content_scale :: proc(window := _current_window) -> f32 {
    return wnd.content_scale(&window.backend)
}

global_mouse_position :: proc(window := _current_window) -> Vec2 {
    return wnd.mouse_position(&window.backend)
}

// set_cursor_style :: proc(style: Cursor_Style, window: ^Window) {}

get_clipboard :: proc(window := _current_window) -> string {
    return wnd.get_clipboard(&window.backend)
}

set_clipboard :: proc(data: string, window: ^Window) {
    wnd.set_clipboard(&window.backend, data)
}



_window_event_proc :: proc(window: ^wnd.Window, event: any) -> bool {
    window := cast(^Window)window.user_data
    _current_window = window

    switch e in event {
    case Window_Resized_Event:
        window.root.size = e.size

    case Window_Mouse_Moved_Event:
        window.previous_hover = window.hover

        window.mouse_hit = _hit_test_from_root(&window.root, e.position)

        if !window.hover_captured {
            window.hover = window.mouse_hit
        }

        if window.hover != window.previous_hover {
            if window.previous_hover != nil {
                send_event(window.previous_hover, Mouse_Exited_Event{
                    position = e.position,
                })
            }
            if window.hover != nil {
                send_event(window.hover, Mouse_Entered_Event{
                    position = e.position,
                })
            }
        }

        if window.hover != nil {
            send_event(window.hover, Mouse_Moved_Event{
                position = e.position,
                delta = e.delta,
            })
        }

    case Window_Mouse_Pressed_Event:
        if window.hover != nil {
            send_event(window.hover, Mouse_Pressed_Event{
                position = e.position,
                button = e.button,
            })
        }

    case Window_Mouse_Released_Event:
        if window.hover != nil {
            send_event(window.hover, Mouse_Released_Event{
                position = e.position,
                button = e.button,
            })
        }

    case Window_Mouse_Scrolled_Event:
        if window.hover != nil {
            send_event(window.hover, Mouse_Scrolled_Event{
                position = e.position,
                amount = e.amount,
            })
        }

    case Window_Key_Pressed_Event:
        if window.focus != nil {
            send_event(window.focus, Key_Pressed_Event{
                key = e.key,
            })
        }

    case Window_Key_Released_Event:
        if window.focus != nil {
            send_event(window.focus, Key_Released_Event{
                key = e.key,
            })
        }

    case Window_Text_Event:
        if window.focus != nil {
            send_event(window.focus, Text_Event{
                text = e.text,
            })
        }
    }

    return send_event_recursively(&window.root, event)
}