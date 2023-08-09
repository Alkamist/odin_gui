package gui

import "rect"

Widget :: struct {}

Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_hover_request: ^Widget,
}

Interaction_Tracker :: struct {
    detected_hover: bool,
    detected_mouse_over: bool,
}

current_layer :: proc() -> ^Layer {
    return &_current_window.layer_stack[len(_current_window.layer_stack) - 1]
}

current_z_index :: proc() -> int {
    return current_layer().z_index
}

current_offset :: proc() -> Vec2 {
    return _current_window.offset_stack[len(_current_window.offset_stack) - 1]
}

current_clip :: proc() -> Rect {
    return _current_window.clip_stack[len(_current_window.clip_stack) - 1]
}

is_hovered :: proc(widget: ^Widget) -> bool {
    return _current_window.hover == widget
}

mouse_is_over :: proc(widget: ^Widget) -> bool {
    return _current_window.mouse_over == widget
}

request_hover :: proc(widget: ^Widget) {
    current_layer().final_hover_request = widget
    if _current_window.hover == widget {
        _current_window.interaction_tracker_stack[len(_current_window.interaction_tracker_stack) - 1].detected_hover = true
    }
    if _current_window.mouse_over == widget {
        _current_window.interaction_tracker_stack[len(_current_window.interaction_tracker_stack) - 1].detected_mouse_over = true
    }
}

capture_hover :: proc(widget: ^Widget) {
    if _current_window.hover_capture == nil {
        _current_window.hover_capture = widget
    }
}

release_hover :: proc(widget: ^Widget) {
    if _current_window.hover_capture == widget {
        _current_window.hover_capture = nil
    }
}

begin_interaction_tracker :: proc() {
    append(&_current_window.interaction_tracker_stack, Interaction_Tracker{})
}

end_interaction_tracker :: proc() -> Interaction_Tracker {
    result := pop(&_current_window.interaction_tracker_stack)
    if result.detected_hover {
        _current_window.interaction_tracker_stack[len(_current_window.interaction_tracker_stack) - 1].detected_hover = true
    }
    if result.detected_mouse_over {
        _current_window.interaction_tracker_stack[len(_current_window.interaction_tracker_stack) - 1].detected_mouse_over = true
    }
    return result
}

begin_offset :: proc(offset: Vec2, global := false) {
    if global {
        append(&_current_window.offset_stack, offset)
    } else {
        append(&_current_window.offset_stack, current_offset() + offset)
    }
}

end_offset :: proc() -> Vec2 {
    return pop(&_current_window.offset_stack)
}

begin_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    r := Rect{position = position, size = size}

    if !global {
        r.position += current_offset()
    }

    if intersect {
        r = rect.intersect(r, _current_window.clip_stack[len(_current_window.clip_stack) - 1])
    }

    append(&_current_window.clip_stack, r)
    append(&current_layer().draw_commands, Clip_Command{
        position = r.position,
        size = r.size,
    })
}

end_clip :: proc() -> Rect {
    result := pop(&_current_window.clip_stack)

    if len(_current_window.clip_stack) == 0 {
        return result
    }

    clip_rect := _current_window.clip_stack[len(_current_window.clip_stack) - 1]
    append(&current_layer().draw_commands, Clip_Command{
        position = clip_rect.position,
        size = clip_rect.size,
    })

    return result
}

begin_z_index :: proc(z_index: int, global := false) {
    if global {
        append(&_current_window.layer_stack, Layer{z_index = z_index})
    } else {
        append(&_current_window.layer_stack, Layer{z_index = current_z_index() + z_index})
    }
}

end_z_index :: proc() -> int {
    layer := pop(&_current_window.layer_stack)
    append(&_current_window.layers, layer)
    return layer.z_index
}

mouse_hit_test :: proc(position, size: Vec2) -> bool {
    m := mouse_position()
    return m.x >= position.x && m.x <= position.x + size.x &&
           m.y >= position.y && m.y <= position.y + size.y &&
           rect.contains(current_clip(), m)
}