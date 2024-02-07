package gui

import "base:runtime"
import "rect"

Widget :: struct {
    window: ^Window,
    parent: ^Widget,
    position: Vec2,
    size: Vec2,
    is_hidden: bool,
    clip_children: bool,
    children: [dynamic]^Widget,
    event_proc: proc(widget: ^Widget, event: Event),

    cached_mouse_position: Vec2,
}

init_widget :: proc(
    widget: ^Widget,
    allocator := context.allocator,
) -> (res: ^Widget, err: runtime.Allocator_Error) #optional_allocator_error {
    widget.children = make([dynamic]^Widget, allocator) or_return
    return widget, nil
}

destroy_widget :: proc(widget: ^Widget) {
    delete(widget.children)
}

set_parent :: proc(widget, parent: ^Widget) {
    previous_parent := widget.parent
    if parent == previous_parent do return
    if previous_parent != nil {
        _remove_children(previous_parent, {widget})
    }
    widget.parent = parent
    if parent != nil {
        widget.window = parent.window
        append(&parent.children, widget)
    } else {
        widget.window = nil
    }
}

global_position :: proc(widget: ^Widget) -> Vec2 {
    if widget.parent == nil {
        return {0, 0}
    } else {
        return global_position(widget.parent) + widget.position
    }
}

mouse_position :: proc(widget: ^Widget) -> Vec2 {
    assert(widget.window != nil)
    return widget.window.mouse.position - global_position(widget)
}

set_position :: proc(widget: ^Widget, position: Vec2) {
    previous_position := widget.position
    if position == previous_position do return
    widget.position = position
    _send_event(widget, false, Move_Event{
        position = widget.position,
        delta = widget.position - previous_position,
    })
    update_mouse_hover(widget.window)
}

set_size :: proc(widget: ^Widget, size: Vec2) {
    size := Vec2{abs(size.x), abs(size.y)}
    previous_size := widget.size
    if size == previous_size do return
    widget.size = size
    _send_event(widget, false, Resize_Event{
        size = widget.size,
        delta = widget.size - previous_size,
    })
    update_mouse_hover(widget.window)
}

show :: proc(widget: ^Widget) {
    if !widget.is_hidden do return
    widget.is_hidden = false
    _send_event(widget, false, Show_Event{})
}

hide :: proc(widget: ^Widget) {
    if widget.is_hidden do return
    widget.is_hidden = true
    _send_event(widget, false, Hide_Event{})
}



_remove_children :: proc(widget: ^Widget, children: []^Widget) {
    keep_position := 0
    for i in 0 ..< len(widget.children) {
        keep := true
        for child in children {
            if widget.children[i] == child {
                keep = false
                break
            }
        }
        if keep {
            if keep_position != i {
                widget.children[keep_position] = widget.children[i]
            }
            keep_position += 1
        }
    }
    resize(&widget.children, keep_position)
    widget.parent = nil
    widget.window = nil
}

_hit_test_recursively :: proc(widget: ^Widget, position: Vec2) -> ^Widget {
    if widget.is_hidden do return nil

    #reverse for child in widget.children {
        if hit := _hit_test_recursively(child, position - widget.position); hit != nil {
            return hit
        }
    }

    if rect.contains({widget.position, widget.size}, position, include_borders = true) {
        return widget
    }

    return nil
}

_send_event :: proc(widget: ^Widget, respect_visibility: bool, event: Event) {
    if respect_visibility && widget.is_hidden do return
    if widget.event_proc == nil do return

    previous_window := _current_window
    _current_window = widget.window
    assert(_current_window != nil)

    widget->event_proc(event)

    _current_window = previous_window
}

_send_event_recursively :: proc(widget: ^Widget, respect_visibility: bool, event: Event) {
    if respect_visibility && widget.is_hidden do return

    previous_window := _current_window
    _current_window = widget.window
    assert(_current_window != nil)

    if widget.event_proc != nil {
        widget->event_proc(event)
    }

    for child in widget.children {
        child.window = _current_window
        previous_draw_offset := _current_window.current_cached_global_position
        _current_window.current_cached_global_position += child.position
        _send_event_recursively(child, respect_visibility, event)
        _current_window.current_cached_global_position = previous_draw_offset
    }

    _current_window = previous_window
}