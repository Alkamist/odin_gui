package gui

import "base:runtime"
import "core:time"

Root :: struct {
    using widget: Widget,
    input: Input_State,
    content_scale: Vec2,
    focus: ^Widget,
    mouse_hit: ^Widget,
    hover: ^Widget,
    hover_captured: bool,
    needs_redisplay: bool,

    // For logic involving repeated mouse clicks.
    mouse_repeat_duration: Duration,
    mouse_repeat_movement_tolerance: f32,
    mouse_repeat_start_position: Vec2,
    mouse_repeat_press_count: int,
    mouse_repeat_tick: Tick,

    backend: Backend,
}

init_root :: proc(
    root: ^Root,
    size: Vec2,
    mouse_repeat_duration := 300 * time.Millisecond,
    mouse_repeat_movement_tolerance := f32(3),
    allocator := context.allocator,
) -> (res: ^Root, err: runtime.Allocator_Error) #optional_allocator_error {
    init_widget(root, nil, position = {0, 0}, size = size, allocator = allocator) or_return
    root.root = root
    root.mouse_repeat_duration = mouse_repeat_duration
    root.mouse_repeat_movement_tolerance = mouse_repeat_movement_tolerance
    root.input = {}
    root.content_scale = Vec2{1, 1}
    root.focus = nil
    root.mouse_hit = nil
    root.hover = nil
    root.hover_captured = false
    root.needs_redisplay = false
    root.event_proc = nil
    return root, nil
}

destroy_root :: proc(root: ^Root) {
    destroy_widget(root)
}