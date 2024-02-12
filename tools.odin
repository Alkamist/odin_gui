package gui

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "rects"

Id :: u64

Vec2 :: [2]f32
Rect :: rects.Rect

Tick :: time.Tick
Duration :: time.Duration

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
    return ctx.temp_allocator
}

z_index :: proc() -> int {
    return _current_layer().z_index
}

offset :: proc() -> Vec2 {
    if len(ctx.offset_stack) <= 0 do return {0, 0}
    return ctx.offset_stack[len(ctx.offset_stack) - 1]
}

clip_rect :: proc() -> Rect {
    clip := ctx.clip_rect_stack[len(ctx.clip_rect_stack) - 1]
    clip.position -= offset()
    return clip
}

mouse_hover :: proc() -> Id {
    return ctx.mouse_hover
}

mouse_hover_entered :: proc() -> Id {
    if ctx.mouse_hover != ctx.previous_mouse_hover {
        return ctx.mouse_hover
    } else {
        return 0
    }
}

mouse_hover_exited :: proc() -> Id {
    if ctx.mouse_hover != ctx.previous_mouse_hover {
        return ctx.previous_mouse_hover
    } else {
        return 0
    }
}

mouse_hit :: proc() -> Id {
    return ctx.mouse_hit
}

request_mouse_hover :: proc(id: Id) {
    _current_layer().final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    ctx.mouse_hover_capture = _current_layer().final_mouse_hover_request
}

release_mouse_hover :: proc() {
    ctx.mouse_hover_capture = 0
}

keyboard_focus :: proc() -> Id {
    return ctx.keyboard_focus
}

set_keyboard_focus :: proc(id: Id) {
    ctx.keyboard_focus = id
}

release_keyboard_focus :: proc() {
    ctx.keyboard_focus = 0
}

begin_offset :: proc(offset: Vec2, global := false) {
    if global {
        append(&ctx.offset_stack, offset)
    } else {
        append(&ctx.offset_stack, _offset() + offset)
    }
}

end_offset :: proc() {
    if len(ctx.offset_stack) <= 0 do return
    pop(&ctx.offset_stack)
}

@(deferred_none=end_offset)
scoped_offset :: proc(offset: Vec2, global := false) {
    begin_offset(offset, global = global)
}

begin_clip :: proc(rect: Rect, global := false, intersect := true) {
    rect := rect

    if !global {
        rect.position += offset()
    }

    if intersect {
        rect = rects.intersection(rect, ctx.clip_rect_stack[len(ctx.clip_rect_stack) - 1])
    }

    append(&ctx.clip_rect_stack, rect)
    append(&_current_layer().draw_commands, Clip_Drawing_Command{rect})
}

end_clip :: proc() {
    if len(ctx.clip_rect_stack) <= 0 do return
    pop(&ctx.clip_rect_stack)

    if len(ctx.clip_rect_stack) == 0 {
        return
    }

    clip_rect := ctx.clip_rect_stack[len(ctx.clip_rect_stack) - 1]
    append(&_current_layer().draw_commands, Clip_Drawing_Command{clip_rect})
}

@(deferred_none=end_clip)
scoped_clip :: proc(rect: Rect, global := false, intersect := true) {
    begin_clip(rect, global = global, intersect = intersect)
}

begin_z_index :: proc(z_index: int, global := false) {
    layer: Layer
    layer.draw_commands = make([dynamic]Draw_Command, ctx.temp_allocator)
    if global do layer.z_index = z_index
    else do layer.z_index = _z_index() + z_index
    append(&ctx.layer_stack, layer)
}

end_z_index :: proc() {
    if len(ctx.layer_stack) <= 0 do return
    layer := pop(&ctx.layer_stack)
    append(&ctx.layers, layer)
}

@(deferred_none=end_z_index)
scoped_z_index :: proc(z_index: int, global := false) {
    begin_z_index(z_index, global = global)
}

hit_test :: proc(rect: Rect, target: Vec2) -> bool {
    return rects.encloses(rect, target, include_borders = false) &&
           rects.encloses(clip_rect(), target, include_borders = false)
}

mouse_hit_test :: proc(rect: Rect) -> bool {
    return hit_test(rect, mouse_position())
}




_z_index :: z_index
_offset :: offset

_current_layer :: proc() -> ^Layer {
    return &ctx.layer_stack[len(ctx.layer_stack) - 1]
}