package gui

Root :: struct {
    using widget: Widget,
    input: Input_State,
    focus: ^Widget,
    mouse_hit: ^Widget,
    hover: ^Widget,
    previous_hover: ^Widget,
    hover_captured: bool,
    needs_redisplay: bool,
}

init_root :: proc(root: ^Root, size: Vec2) {
    init_widget(root)
    root.root = root
    root.size = size
    root.input = {}
    root.focus = nil
    root.mouse_hit = nil
    root.hover = nil
    root.previous_hover = nil
    root.hover_captured = false
    root.needs_redisplay = false
    root.event_proc = nil
}

destroy_root :: proc(root: ^Root) {
    destroy_widget(root)
}