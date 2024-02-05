package gui

Widget :: struct {
    window: ^Window,
    position: Vec2,
    position_offset: Vec2,
    size: Vec2,
    is_hidden: bool,
    event_proc: proc(widget: ^Widget, event: Event),

    cached_mouse_position: Vec2,
}

global_position :: proc(widget: ^Widget) -> Vec2 {
    return widget.position + widget.position_offset
}

mouse_position :: proc(widget: ^Widget) -> Vec2 {
    assert(widget.window != nil)
    return widget.window.mouse.position - (widget.position + widget.position_offset)
}

set_window :: proc(widget: ^Widget, window: ^Window) {
    previous_window := widget.window
    if window == previous_window do return
    if previous_window != nil {
        _remove_widget_from_window(previous_window, widget)
    }
    widget.window = window
    if window != nil {
        append(&window.widgets, widget)
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
    if position == previous_position do return
    widget.position = position
    send_event(widget, Move_Event{
        global_position = global_position(widget),
        delta = widget.position - previous_position,
    })
    update_mouse_hover(widget.window)
}

set_position_offset :: proc(widget: ^Widget, position_offset: Vec2) {
    previous_positio_offset := widget.position_offset
    if position_offset == previous_positio_offset do return
    widget.position_offset = position_offset
    send_event(widget, Move_Event{
        global_position = global_position(widget),
        delta = widget.position_offset - previous_positio_offset,
    })
    update_mouse_hover(widget.window)
}

set_size :: proc(widget: ^Widget, size: Vec2) {
    size := Vec2{abs(size.x), abs(size.y)}
    previous_size := widget.size
    if size == previous_size do return
    widget.size = size
    send_event(widget, Resize_Event{
        size = widget.size,
        delta = widget.size - previous_size,
    })
    update_mouse_hover(widget.window)
}

show :: proc(widget: ^Widget) {
    if !widget.is_hidden do return
    widget.is_hidden = false
    send_event(widget, Show_Event{})
}

hide :: proc(widget: ^Widget) {
    if widget.is_hidden do return
    widget.is_hidden = true
    send_event(widget, Hide_Event{})
}