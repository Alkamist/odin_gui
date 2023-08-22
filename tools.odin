package gui

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

get_user_data :: proc($T: typeid) -> ^T {
    return cast(^T)_current_window.user_data
}

get_layer :: proc() -> ^Layer {
    return &_current_window.layer_stack[len(_current_window.layer_stack) - 1]
}

get_z_index :: proc() -> int {
    return get_layer().z_index
}

get_offset :: proc() -> Vec2 {
    return _current_window.offset_stack[len(_current_window.offset_stack) - 1]
}

get_clip :: proc() -> Rect {
    clip := _current_window.clip_stack[len(_current_window.clip_stack) - 1]
    clip.position -= get_offset()
    return clip
}

get_hover :: proc() -> ^Widget {
    return _current_window.hover
}

is_hovered :: proc(widget: ^Widget) -> bool {
    return _current_window.hover == widget
}

mouse_is_over :: proc(widget: ^Widget) -> bool {
    return _current_window.mouse_over == widget
}

request_hover :: proc(widget: ^Widget) {
    get_layer().final_hover_request = widget
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

end_interaction_tracker :: proc() {
    tracker := pop(&_current_window.interaction_tracker_stack)
    if tracker.detected_hover {
        _current_window.interaction_tracker_stack[len(_current_window.interaction_tracker_stack) - 1].detected_hover = true
    }
    if tracker.detected_mouse_over {
        _current_window.interaction_tracker_stack[len(_current_window.interaction_tracker_stack) - 1].detected_mouse_over = true
    }
}

@(deferred_none=end_interaction_tracker)
interaction_tracker :: proc() {
    begin_interaction_tracker()
}

begin_offset :: proc(offset: Vec2, global := false) {
    if global {
        append(&_current_window.offset_stack, offset)
    } else {
        append(&_current_window.offset_stack, get_offset() + offset)
    }
}

end_offset :: proc() {
    pop(&_current_window.offset_stack)
}

@(deferred_none=end_offset)
offset :: proc(offset: Vec2, global := false) {
    begin_offset(offset, global = global)
}

begin_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    r := Rect{position = position, size = size}

    if !global {
        r.position += get_offset()
    }

    if intersect {
        r = _rect_intersect(r, _current_window.clip_stack[len(_current_window.clip_stack) - 1])
    }

    append(&_current_window.clip_stack, r)
    append(&get_layer().draw_commands, Clip_Command{
        position = r.position,
        size = r.size,
    })
}

end_clip :: proc() {
    pop(&_current_window.clip_stack)

    if len(_current_window.clip_stack) == 0 {
        return
    }

    clip_rect := _current_window.clip_stack[len(_current_window.clip_stack) - 1]
    append(&get_layer().draw_commands, Clip_Command{
        position = clip_rect.position,
        size = clip_rect.size,
    })
}

@(deferred_none=end_clip)
clip :: proc(position, size: Vec2, global := false, intersect := true) {
    begin_clip(position, size, global = global, intersect = intersect)
}

begin_z_index :: proc(z_index: int, global := false) {
    layer: Layer
    layer.draw_commands = make([dynamic]Draw_Command, _current_window.frame_allocator)
    if global do layer.z_index = z_index
    else do layer.z_index = get_z_index() + z_index
    append(&_current_window.layer_stack, layer)
}

end_z_index :: proc() {
    layer := pop(&_current_window.layer_stack)
    append(&_current_window.layers, layer)
}

@(deferred_none=end_z_index)
z_index :: proc(z_index: int, global := false) {
    begin_z_index(z_index, global = global)
}

mouse_hit_test :: proc(position, size: Vec2) -> bool {
    m := mouse_position()
    return m.x >= position.x && m.x <= position.x + size.x &&
           m.y >= position.y && m.y <= position.y + size.y &&
           contains(get_clip(), m)
}