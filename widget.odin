package gui

import "core:mem"
import "rect"

@(thread_local) _current_widget: ^Widget

Vec2 :: [2]f32
Rect :: rect.Rect
Color :: [4]f32

Widget :: struct {
    root: ^Root,
    parent: ^Widget,
    children: [dynamic]^Widget,
    position: Vec2,
    size: Vec2,
    is_hidden: bool,
    clip_children: bool,
    event_proc: proc(widget, subject: ^Widget, event: any),
    draw_commands: [dynamic]Draw_Command,

    // For rendering and hit detection
    cached_global_position: Vec2,
    cached_global_clip_rect: Maybe(Rect),
}

init_widget :: proc(
    widget, parent: ^Widget,
    position := Vec2{0, 0},
    size := Vec2{0, 0},
    visibility := true,
    clip_children := false,
    event_proc: proc(^Widget, ^Widget, any) = nil,
    allocator := context.allocator,
) -> (res: ^Widget, err: mem.Allocator_Error) #optional_allocator_error {
    for child in widget.children {
        _set_root(child, nil)
    }
    widget.children = make([dynamic]^Widget, allocator) or_return
    widget.draw_commands = make([dynamic]Draw_Command, allocator) or_return
    widget.event_proc = event_proc
    widget.clip_children = clip_children
    _set_parent(widget, parent)
    set_position(position, widget)
    set_size(size, widget)
    if visibility {
        show(widget)
    } else {
        hide(widget)
    }
    return widget, nil
}

destroy_widget :: proc(widget: ^Widget) {
    delete(widget.children)
    delete(widget.draw_commands)
}

send_event :: proc(widget: ^Widget, event: any) {
    send_event_subject(widget, widget, event)
}

send_global_event :: proc(widget: ^Widget, event: any) {
    send_event_subject(widget, nil, event)
}

send_event_subject :: proc(widget, subject: ^Widget, event: any) {
    assert(widget != nil)

    previous_widget := _current_widget
    _current_widget = widget

    if widget.event_proc != nil {
        widget->event_proc(subject, event)
    }

    for child in widget.children {
        send_event_subject(child, subject, event)
    }

    _current_widget = previous_widget
}

set_position :: proc(position: Vec2, widget := _current_widget) {
    assert(widget != nil)
    previous_position := widget.position
    if position != previous_position {
        widget.position = position
        send_event(widget, Move_Event{
            position = widget.position,
            delta = widget.position - previous_position,
        })
    }
}

set_size :: proc(size: Vec2, widget := _current_widget) {
    assert(widget != nil)
    size := _vec2_abs(size)
    previous_size := widget.size
    if size != previous_size {
        widget.size = size
        send_event(widget, Resize_Event{
            size = widget.size,
            delta = widget.size - previous_size,
        })
    }
}

show :: proc(widget := _current_widget) {
    assert(widget != nil)
    if widget.is_hidden {
        widget.is_hidden = false
        send_event(widget, Show_Event{})
    }
}

hide :: proc(widget := _current_widget) {
    assert(widget != nil)
    if !widget.is_hidden {
        widget.is_hidden = true
        send_event(widget, Hide_Event{})
    }
}

global_mouse_position :: proc(widget := _current_widget) -> Vec2 {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.input.mouse.position
}

mouse_position :: proc(widget := _current_widget) -> Vec2 {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.input.mouse.position - widget.position
}

mouse_down :: proc(button: Mouse_Button, widget := _current_widget) -> bool {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.input.mouse.button_down[button]
}

key_down :: proc(key: Keyboard_Key, widget := _current_widget) -> bool {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.input.keyboard.key_down[key]
}

get_clipboard :: proc(widget := _current_widget) -> (data: string, ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    assert(widget.root.backend.get_clipboard != nil)
    return widget.root.backend->get_clipboard()
}

set_clipboard :: proc(data: string, widget := _current_widget) -> (ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    assert(widget.root.backend.set_clipboard != nil)
    return widget.root.backend->set_clipboard(data)
}

current_focus :: proc(widget := _current_widget) -> ^Widget {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.focus
}

current_mouse_hit :: proc(widget := _current_widget) -> ^Widget {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.mouse_hit
}

current_hover :: proc(widget := _current_widget) -> ^Widget {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.hover
}

capture_hover :: proc(widget := _current_widget) {
    assert(widget != nil)
    assert(widget.root != nil)
    widget.root.hover_captured = true
}

release_hover :: proc(widget := _current_widget) {
    assert(widget != nil)
    assert(widget.root != nil)
    widget.root.hover_captured = false
}

set_focus :: proc(focus: ^Widget, widget := _current_widget) {
    assert(widget != nil)
    assert(widget.root != nil)
    widget.root.focus = focus
}

release_focus :: proc(widget := _current_widget) {
    assert(widget != nil)
    assert(widget.root != nil)
    widget.root.focus = nil
}

hit_test :: proc(position: Vec2, widget := _current_widget) -> ^Widget {
    assert(widget != nil)
    return _recursive_hit_test(widget.root, position)
}



_recursive_update :: proc(widget: ^Widget) {
    send_event(widget, Update_Event{})
    for child in widget.children {
        _recursive_update(child)
    }
}

_set_root :: proc(widget: ^Widget, root: ^Root) {
    widget.root = root
    for child in widget.children {
        _set_root(child, root)
    }
}

_set_parent :: proc(widget, parent: ^Widget) {
    // Remove from children of previous parent.
    if previous_parent := widget.parent; previous_parent != nil {
        for i in 0 ..< len(previous_parent.children) {
            if previous_parent.children[i] == widget {
                unordered_remove(&previous_parent.children, i)
                break
            }
        }
    }

    widget.parent = parent

    if widget.parent != nil {
        _set_root(widget, parent.root)
        append(&widget.parent.children, widget)
    } else {
        _set_root(widget, nil)
    }
}

_vec2_abs :: proc(v: Vec2) -> Vec2 {
    return {abs(v.x), abs(v.y)}
}

_recursive_hit_test :: proc(widget: ^Widget, position: Vec2) -> ^Widget {
    assert(widget != nil)

    if widget.is_hidden {
        return nil
    }

    _update_cached_global_helpers(widget)

    #reverse for child in widget.children {
        hit := _recursive_hit_test(child, position)
        if hit != nil {
            return hit
        }
    }

    hit_box := Rect{widget.cached_global_position, widget.size}
    if clip_rect, ok := widget.cached_global_clip_rect.?; ok {
        hit_box = rect.intersection(hit_box, clip_rect)
    }

    if rect.contains(hit_box, position, include_borders = false) {
        return widget
    }

    return nil
}

_update_cached_global_helpers :: proc(widget: ^Widget) {
    if widget.parent != nil {
        widget.cached_global_position = widget.parent.cached_global_position + widget.position
        if widget.clip_children {
            if parent_clip_rect, ok := widget.parent.cached_global_clip_rect.?; ok {
                widget.cached_global_clip_rect = rect.intersection(
                    parent_clip_rect,
                    {widget.cached_global_position, widget.size},
                )
            } else {
                widget.cached_global_clip_rect = Rect{widget.cached_global_position, widget.size}
            }
        } else {
            widget.cached_global_clip_rect = widget.parent.cached_global_clip_rect
        }
    } else {
        widget.cached_global_position = widget.position
        if widget.clip_children {
            widget.cached_global_clip_rect = Rect{widget.position, widget.size}
        } else {
            widget.cached_global_clip_rect = nil
        }
    }
}