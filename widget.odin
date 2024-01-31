package gui

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
    event_proc: proc(^Widget, any),
    draw_commands: [dynamic]Draw_Command,

    // For rendering and hit detection
    cached_global_position: Vec2,
    cached_global_clip_rect: Rect,
}

init_widget :: proc(
    widget: ^Widget,
    position := Vec2{0, 0},
    size := Vec2{0, 0},
    visibility := true,
    clip_children := false,
    event_proc: proc(^Widget, any) = nil,
) {
    widget.root = nil
    widget.parent = nil
    widget.clip_children = clip_children
    clear(&widget.children)
    set_position(position, widget)
    set_size(size, widget)
    if visibility {
        show(widget)
    } else {
        hide(widget)
    }
    widget.event_proc = event_proc
}

destroy_widget :: proc(widget: ^Widget) {
    delete(widget.children)
    delete(widget.draw_commands)
}

send_event :: proc(widget: ^Widget, event: any) {
    previous_widget := _current_widget
    _current_widget = widget
    if widget.event_proc != nil {
        widget->event_proc(event)
    }
    _current_widget = previous_widget
}

send_event_recursively :: proc(widget: ^Widget, event: any) {
    send_event(widget, event)
    for child in widget.children {
        send_event_recursively(child, event)
    }
}

add_children :: proc(widget: ^Widget, children: []^Widget) {
    append(&widget.children, ..children)
    for child in children {
        if child.parent != nil {
            remove_child(child.parent, child)
        }
        child.root = widget.root
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
    child.root = nil
    child.parent = nil
}

set_position :: proc(position: Vec2, widget := _current_widget) {
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
    if widget.is_hidden {
        widget.is_hidden = false
        send_event_recursively(widget, Show_Event{})
    }
}

hide :: proc(widget := _current_widget) {
    if !widget.is_hidden {
        widget.is_hidden = true
        send_event_recursively(widget, Hide_Event{})
    }
}

global_mouse_position :: proc(widget := _current_widget) -> Vec2 {
    return widget.root.input.mouse.position
}

mouse_position :: proc(widget := _current_widget) -> Vec2 {
    return widget.root.input.mouse.position - widget.position
}

mouse_down :: proc(button: Mouse_Button, widget := _current_widget) -> bool {
    return widget.root.input.mouse.button_down[button]
}

key_down :: proc(key: Keyboard_Key, widget := _current_widget) -> bool {
    return widget.root.input.keyboard.key_down[key]
}

current_focus :: proc(widget := _current_widget) -> ^Widget {
    return widget.root.focus
}

current_mouse_hit :: proc(widget := _current_widget) -> ^Widget {
    return widget.root.mouse_hit
}

current_hover :: proc(widget := _current_widget) -> ^Widget {
    return widget.root.hover
}

capture_hover :: proc(widget := _current_widget) {
    widget.root.hover_captured = true
}

release_hover :: proc(widget := _current_widget) {
    widget.root.hover_captured = false
}

set_focus :: proc(focus: ^Widget, widget := _current_widget) {
    widget.root.focus = focus
}

release_focus :: proc(widget := _current_widget) {
    widget.root.focus = nil
}

hit_test :: proc(position: Vec2, widget := _current_widget) -> ^Widget {
    return _recursive_hit_test(widget.root, position)
}



_vec2_abs :: proc(v: Vec2) -> Vec2 {
    return {abs(v.x), abs(v.y)}
}

_recursive_hit_test :: proc(widget: ^Widget, position: Vec2) -> ^Widget {
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

    hit_box := rect.intersection(
        widget.cached_global_clip_rect,
        {widget.cached_global_position, widget.size},
    )

    if rect.contains(hit_box, position, include_borders = false) {
        return widget
    }

    return nil
}

_update_cached_global_helpers :: proc(widget: ^Widget) {
    if widget.parent != nil {
        widget.cached_global_position = widget.parent.cached_global_position + widget.position
        if widget.clip_children {
            widget.cached_global_clip_rect = rect.intersection(
                widget.parent.cached_global_clip_rect,
                {widget.cached_global_position, widget.size},
            )
        } else {
            widget.cached_global_clip_rect = widget.parent.cached_global_clip_rect
        }
    } else {
        widget.cached_global_position = widget.position
        widget.cached_global_clip_rect = {widget.position, widget.size}
    }
}