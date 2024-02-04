package gui

import "core:mem"

Root :: struct {
    using widget: Widget,
    input: Input_State,
    content_scale: Vec2,
    focus: ^Widget,
    mouse_hit: ^Widget,
    hover: ^Widget,
    previous_hover: ^Widget,
    hover_captured: bool,
    needs_redisplay: bool,
    backend: Backend,
}

init_root :: proc(
    root: ^Root,
    size: Vec2,
    content_scale := Vec2{1, 1},
    allocator := context.allocator,
) -> (res: ^Root, err: mem.Allocator_Error) #optional_allocator_error {
    init_widget(root, nil, position = {0, 0}, size = size, allocator = allocator) or_return
    root.root = root
    root.input = {}
    root.content_scale = content_scale
    root.focus = nil
    root.mouse_hit = nil
    root.hover = nil
    root.previous_hover = nil
    root.hover_captured = false
    root.needs_redisplay = false
    root.event_proc = nil
    return root, nil
}

destroy_root :: proc(root: ^Root) {
    destroy_widget(root)
}