package main

import "base:intrinsics"
import "core:time"

Id :: u64
Vector2 :: [2]f32

Layer :: struct {
    local_z_index: int,
    global_z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_mouse_hover_request: Id,
}

gui_id :: proc "contextless" () -> Id {
    @(static) id: Id
    return 1 + intrinsics.atomic_add(&id, 1)
}

mouse_hover :: proc() -> Id {
    ctx := gui_context()
    return ctx.mouse_hover
}

mouse_hover_entered :: proc() -> Id {
    ctx := gui_context()
    if ctx.mouse_hover != ctx.previous_mouse_hover {
        return ctx.mouse_hover
    } else {
        return 0
    }
}

mouse_hover_exited :: proc() -> Id {
    ctx := gui_context()
    if ctx.mouse_hover != ctx.previous_mouse_hover {
        return ctx.previous_mouse_hover
    } else {
        return 0
    }
}

mouse_hit :: proc() -> Id {
    ctx := gui_context()
    return ctx.mouse_hit
}

request_mouse_hover :: proc(id: Id) {
    _current_layer(current_window()).final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    ctx := gui_context()
    ctx.mouse_hover_capture = _current_layer(current_window()).final_mouse_hover_request
}

release_mouse_hover :: proc() {
    ctx := gui_context()
    ctx.mouse_hover_capture = 0
}

keyboard_focus :: proc() -> Id {
    ctx := gui_context()
    return ctx.keyboard_focus
}

set_keyboard_focus :: proc(id: Id) {
    ctx := gui_context()
    ctx.keyboard_focus = id
}

release_keyboard_focus :: proc() {
    ctx := gui_context()
    ctx.keyboard_focus = 0
}

hit_test :: proc(rectangle: Rectangle, target: Vector2) -> bool {
    return rectangle_encloses(rectangle, target, include_borders = false) &&
           rectangle_encloses(clip_rectangle(), target, include_borders = false)
}

mouse_hit_test :: proc(rectangle: Rectangle) -> bool {
    return hit_test(rectangle, mouse_position())
}

// Local coordinates
offset :: proc() -> Vector2 {
    window := current_window()
    if len(window.local_offset_stack) <= 0 do return {0, 0}
    return window.local_offset_stack[len(window.local_offset_stack) - 1]
}

// Global coordinates
global_offset :: proc() -> Vector2 {
    window := current_window()
    if len(window.global_offset_stack) <= 0 do return {0, 0}
    return window.global_offset_stack[len(window.global_offset_stack) - 1]
}

// Set in local coordinates
begin_offset :: proc(offset: Vector2) {
    window := current_window()
    append(&window.local_offset_stack, offset)
    append(&window.global_offset_stack, global_offset() + offset)
}

end_offset :: proc() {
    window := current_window()
    if len(window.local_offset_stack) <= 0 ||
       len(window.global_offset_stack) <= 0 {
        return
    }
    pop(&window.local_offset_stack)
    pop(&window.global_offset_stack)
}

@(deferred_none=end_offset)
scoped_offset :: proc(offset: Vector2) {
    begin_offset(offset)
}

// Local coordinates
clip_rectangle :: proc() -> Rectangle {
    window := current_window()
    if len(window.global_clip_rectangle_stack) <= 0 do return {-global_offset(), window.size}
    global_rect := window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]
    global_rect.position -= global_offset()
    return global_rect
}

// Global coordinates
global_clip_rectangle :: proc() -> Rectangle {
    window := current_window()
    if len(window.global_clip_rectangle_stack) <= 0 do return {{0, 0}, window.size}
    return window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]
}

// Set in local coordinates
begin_clip :: proc(rectangle: Rectangle, intersect := true) {
    window := current_window()

    offset := global_offset()
    global_rect := Rectangle{offset + rectangle.position, rectangle.size}

    if intersect && len(window.global_clip_rectangle_stack) > 0 {
        global_rect = rectangle_intersection(global_rect, window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1])
    }

    append(&window.global_clip_rectangle_stack, global_rect)
    _process_draw_command(window, Clip_Drawing_Command{global_rect})
}

end_clip :: proc() {
    window := current_window()

    if len(window.global_clip_rectangle_stack) <= 0 {
        return
    }

    pop(&window.global_clip_rectangle_stack)

    if len(window.global_clip_rectangle_stack) <= 0 {
        return
    }

    global_rect := window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]

    _process_draw_command(window, Clip_Drawing_Command{global_rect})
}

@(deferred_none=end_clip)
scoped_clip :: proc(rectangle: Rectangle, intersect := true) {
    begin_clip(rectangle, intersect = intersect)
}

z_index :: proc() -> int {
    window := current_window()
    if len(window.layer_stack) <= 0 do return 0
    return _current_layer(window).local_z_index
}

global_z_index :: proc() -> int {
    window := current_window()
    if len(window.layer_stack) <= 0 do return 0
    return _current_layer(window).global_z_index
}

// Local z index
begin_z_index :: proc(z_index: int) {
    window := current_window()
    layer: Layer
    layer.draw_commands = make([dynamic]Draw_Command, arena_allocator())
    layer.local_z_index = z_index
    layer.global_z_index = global_z_index() + z_index
    append(&window.layer_stack, layer)
}

end_z_index :: proc() {
    window := current_window()
    if len(window.layer_stack) <= 0 do return
    layer := pop(&window.layer_stack)
    append(&window.layers, layer)
}

@(deferred_none=end_z_index)
scoped_z_index :: proc(z_index: int) {
    begin_z_index(z_index)
}

_current_layer :: proc(window: ^Window) -> ^Layer {
    return &window.layer_stack[len(window.layer_stack) - 1]
}