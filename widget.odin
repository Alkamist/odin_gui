package gui

@(thread_local) _current_widget: ^Widget

Vec2 :: [2]f32
Color :: [4]f32

Widget :: struct {
    root: ^Root,
    parent: ^Widget,
    children: [dynamic]^Widget,
    position: Vec2,
    size: Vec2,
    event_proc: proc(^Widget, any),
    draw_commands: [dynamic]Draw_Command,
}

init_widget :: proc(
    widget: ^Widget,
    position := Vec2{0, 0},
    size := Vec2{0, 0},
    event_proc: proc(^Widget, any) = nil,
) {
    widget.root = nil
    widget.parent = nil
    clear(&widget.children)
    set_position(widget, position)
    set_size(widget, size)
    widget.event_proc = event_proc
}

destroy_widget :: proc(widget: ^Widget) {
    delete(widget.children)
    delete(widget.draw_commands)
}

send_event :: proc(widget: ^Widget, event: any) {
    _current_widget = widget
    if widget.event_proc != nil {
        widget->event_proc(event)
    }
    _current_widget = widget
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

set_position :: proc(widget: ^Widget, position: Vec2) {
    previous_position := widget.position
    if position != previous_position {
        widget.position = position
        send_event(widget, Move_Event{
            position = widget.position,
            delta = widget.position - previous_position,
        })
    }
}

set_size :: proc(widget: ^Widget, size: Vec2) {
    previous_size := widget.size
    if size != previous_size {
        widget.size = size
        send_event(widget, Resize_Event{
            size = widget.size,
            delta = widget.size - previous_size,
        })
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
    return recursive_hit_test(widget.root, position)
}

recursive_hit_test :: proc(widget: ^Widget, position: Vec2) -> ^Widget {
    #reverse for child in widget.children {
        hit := recursive_hit_test(child, position - widget.position)
        if hit != nil {
            return hit
        }
    }
    if widget_contains_vec2(widget, position) {
        return widget
    }
    return nil
}

widget_contains_vec2 :: proc(widget: ^Widget, point: Vec2) -> bool {
    assert(widget.size.x >= 0 && widget.size.y >= 0)
    return point.x >= widget.position.x && point.x <= widget.position.x + widget.size.x &&
           point.y >= widget.position.y && point.y <= widget.position.y + widget.size.y
}