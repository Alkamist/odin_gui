package gui

import "window"

Widget :: struct {
    parent: ^Widget,
    children: [dynamic]^Widget,
    position: Vec2,
    size: Vec2,
    event_proc: proc(^Widget, any) -> bool,
}

init_widget :: proc(
    widget: ^Widget,
    position := Vec2{0, 0},
    size := Vec2{0, 0},
    event_proc: proc(^Widget, any) -> bool = nil,
) {
    widget.parent = nil
    clear(&widget.children)
    set_position(widget, position)
    set_size(widget, size)
    widget.event_proc = event_proc
}

destroy_widget :: proc(widget: ^Widget) {
    delete(widget.children)
}

is_root :: proc(widget: ^Widget) -> bool {
    return widget.parent == nil
}

add_children :: proc(widget: ^Widget, children: []^Widget) {
    append(&widget.children, ..children)
    for child in children {
        if child.parent != nil {
            remove_child(child.parent, child)
        }
        child.parent = widget
    }
}

remove_child :: proc(widget: ^Widget, child: ^Widget) {
    for i in 0 ..< len(widget.children) {
        if widget.children[i] == child {
            unordered_remove(&widget.children, i)
            break
        }
    }
    child.parent = nil
}

set_position :: proc(widget: ^Widget, position: Vec2) {
    previous_position := widget.position
    widget.position = position
    if widget.position != previous_position {
        send_event(widget, Move_Event{
            position = widget.position,
            delta = widget.position - previous_position,
        })
    }
}

set_size :: proc(widget: ^Widget, size: Vec2) {
    previous_size := widget.size
    widget.size = size
    if widget.size != previous_size {
        send_event(widget, Resize_Event{
            size = widget.size,
            delta = widget.size - previous_size,
        })
    }
}

send_event :: proc(widget: ^Widget, event: any) -> (was_consumed: bool) {
    if widget.event_proc != nil {
        return widget->event_proc(event)
    }
    return false
}

send_event_recursively :: proc(widget: ^Widget, event: any) -> (was_consumed: bool) {
    if send_event(widget, event) {
        return true
    }
    switch e in event {
    case Draw_Event:
        translate_path(widget.position)
        defer translate_path(-widget.position)
        for child in widget.children {
            if send_event_recursively(child, event) {
                return true
            }
        }
    case:
        for child in widget.children {
            if send_event_recursively(child, event) {
                return true
            }
        }
    }
    return false
}

global_position :: proc(widget: ^Widget) -> Vec2 {
    if is_root(widget) {
        return widget.position
    }
    return global_position(widget.parent) + widget.position
}

bounds :: proc(widget: ^Widget) -> Rect {
    return Rect{widget.position, widget.size}
}

global_bounds :: proc(widget: ^Widget) -> Rect {
    return Rect{global_position(widget), widget.size}
}

widget_contains_vec2 :: proc(widget: ^Widget, point: Vec2) -> bool {
    return contains(bounds(widget), point)
}

hit_test :: proc(position: Vec2) -> ^Widget {
    return _hit_test_from_root(&_current_window.root, position)
}

current_focus :: proc() -> ^Widget {
    return _current_window.focus
}

current_mouse_hit :: proc() -> ^Widget {
    return _current_window.mouse_hit
}

current_hover :: proc() -> ^Widget {
    return _current_window.hover
}

capture_hover :: proc() {
    _current_window.hover_captured = true
}

release_hover :: proc() {
    _current_window.hover_captured = false
}

set_focus :: proc(widget: ^Widget) {
    _current_window.focus = widget
}

release_focus :: proc() {
    _current_window.focus = nil
}



_hit_test_from_root :: proc(widget: ^Widget, position: Vec2) -> ^Widget {
    #reverse for child in widget.children {
        hit := _hit_test_from_root(child, position - widget.position)
        if hit != nil {
            return hit
        }
    }
    if widget_contains_vec2(widget, position) {
        return widget
    }
    return nil
}