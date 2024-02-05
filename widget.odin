package gui

Widget :: struct {
    window: ^Window,
    position: Vec2,
    size: Vec2,
    is_hidden: bool,
    event_proc: proc(widget: ^Widget, event: Event),
    cached_mouse_position: Vec2,
}

set_window :: proc(widget: ^Widget, window: ^Window) {
    previous_window := widget.window
    if window != previous_window {
        if previous_window != nil {
            _remove_widget_from_window(previous_window, widget)
        }
        widget.window = window
        if window != nil {
            append(&window.widgets, widget)
        }
    }
}

send_event :: proc(widget: ^Widget, event: Event) {
    if widget.event_proc == nil do return
    previous_window := _current_window
    _current_window = widget.window
    widget->event_proc(event)
    _current_window = previous_window
}

set_position :: proc(widget: ^Widget, position: Vec2) {
    previous_position := widget.position
    if position != previous_position {
        widget.position = position
        send_event(widget, Move_Event{
            position = widget.position,
            delta = widget.position - previous_position,
        })
        update_mouse_hover(widget.window)
    }
}

set_size :: proc(widget: ^Widget, size: Vec2) {
    size := Vec2{abs(size.x), abs(size.y)}
    previous_size := widget.size
    if size != previous_size {
        widget.size = size
        send_event(widget, Resize_Event{
            size = widget.size,
            delta = widget.size - previous_size,
        })
        update_mouse_hover(widget.window)
    }
}

show :: proc(widget: ^Widget) {
    if widget.is_hidden {
        widget.is_hidden = false
        send_event(widget, Show_Event{})
    }
}

hide :: proc(widget: ^Widget) {
    if !widget.is_hidden {
        widget.is_hidden = true
        send_event(widget, Hide_Event{})
    }
}