package gui

import "base:runtime"
import "base:intrinsics"
import "rect"

Id :: u64

Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_mouse_hover_request: Id,
}

get_id :: proc "contextless" () -> u64 {
    @(static) id: u64
    return 1 + intrinsics.atomic_add(&id, 1)
}

temp_allocator :: proc() -> runtime.Allocator {
    return _current_window.temp_allocator
}

z_index :: proc() -> int {
    return _current_layer().z_index
}

position_offset :: proc() -> Vec2 {
    return _current_window.position_offset_stack[len(_current_window.position_offset_stack) - 1]
}

clip_rect :: proc() -> Rect {
    clip := _current_window.clip_rect_stack[len(_current_window.clip_rect_stack) - 1]
    clip.position -= position_offset()
    return clip
}

mouse_hover :: proc() -> Id {
    return _current_window.mouse_hover
}

mouse_hover_entered :: proc() -> Id {
    if _current_window.mouse_hover != _current_window.previous_mouse_hover {
        return _current_window.mouse_hover
    } else {
        return 0
    }
}

mouse_hover_exited :: proc() -> Id {
    if _current_window.mouse_hover != _current_window.previous_mouse_hover {
        return _current_window.previous_mouse_hover
    } else {
        return 0
    }
}

mouse_hit :: proc() -> Id {
    return _current_window.mouse_hit
}

request_mouse_hover :: proc(id: Id) {
    _current_layer().final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    _current_window.mouse_hover_captured = true
}

release_mouse_hover :: proc() {
    _current_window.mouse_hover_captured = false
}

set_keyboard_focus :: proc(id: Id) {
    _current_window.keyboard_focus = id
}

release_keyboard_focus :: proc() {
    _current_window.keyboard_focus = 0
}

begin_position_offset :: proc(offset: Vec2, global := false) {
    if global {
        append(&_current_window.position_offset_stack, offset)
    } else {
        append(&_current_window.position_offset_stack, position_offset() + offset)
    }
}

end_position_offset :: proc() {
    pop(&_current_window.position_offset_stack)
}

@(deferred_none=end_position_offset)
scoped_position_offset :: proc(offset: Vec2, global := false) {
    begin_position_offset(offset, global = global)
}

begin_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    r := Rect{position = position, size = size}

    if !global {
        r.position += position_offset()
    }

    if intersect {
        r = rect.intersection(r, _current_window.clip_rect_stack[len(_current_window.clip_rect_stack) - 1])
    }

    append(&_current_window.clip_rect_stack, r)
    append(&_current_layer().draw_commands, Clip_Drawing_Command{
        position = r.position,
        size = r.size,
    })
}

end_clip :: proc() {
    pop(&_current_window.clip_rect_stack)

    if len(_current_window.clip_rect_stack) == 0 {
        return
    }

    clip_rect := _current_window.clip_rect_stack[len(_current_window.clip_rect_stack) - 1]
    append(&_current_layer().draw_commands, Clip_Drawing_Command{
        position = clip_rect.position,
        size = clip_rect.size,
    })
}

@(deferred_none=end_clip)
scoped_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    begin_clip(position, size, global = global, intersect = intersect)
}

begin_z_index :: proc(z_index: int, global := false) {
    layer: Layer
    layer.draw_commands = make([dynamic]Draw_Command, _current_window.temp_allocator)
    if global do layer.z_index = z_index
    else do layer.z_index = _z_index() + z_index
    append(&_current_window.layer_stack, layer)
}

end_z_index :: proc() {
    layer := pop(&_current_window.layer_stack)
    append(&_current_window.layers, layer)
}

@(deferred_none=end_z_index)
scoped_z_index :: proc(z_index: int, global := false) {
    begin_z_index(z_index, global = global)
}

hit_test :: proc(position, size, target: Vec2) -> bool {
    return rect.contains({position, size}, target, include_borders = false) &&
           rect.contains(clip_rect(), target, include_borders = false)
}



_z_index :: z_index

_current_layer :: proc() -> ^Layer {
    return &_current_window.layer_stack[len(_current_window.layer_stack) - 1]
}