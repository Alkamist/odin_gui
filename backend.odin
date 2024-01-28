package gui

Backend :: struct {
    user_data: rawptr,
    open: proc(^Backend),
    close: proc(^Backend),
    redisplay: proc(^Backend),
    render_draw_command: proc(^Backend, Draw_Command),
}

open :: proc(widget := _current_widget) {
    if widget.root.backend.open != nil {
        widget.root.backend->open()
    }
}

close :: proc(widget := _current_widget) {
    if widget.root.backend.close != nil {
        widget.root.backend->close()
    }
}

redraw :: proc(widget := _current_widget) {
    clear(&widget.draw_commands)
    send_event(widget, Draw_Event{})
    if widget.root.backend.redisplay != nil {
        widget.root.backend->redisplay()
    }
}

render_draw_commands :: proc(widget: ^Widget, offset: Vec2) {
    for command in widget.draw_commands {
        switch &c in command {
        case Draw_Rect_Command:
            c.position += offset
            _render_draw_command(widget, c)
        }
    }
    for child in widget.children {
        render_draw_commands(child, offset + child.position)
    }
}



_render_draw_command :: proc(widget: ^Widget, command: Draw_Command) {
    if widget.root.backend.render_draw_command != nil {
        widget.root.backend->render_draw_command(command)
    }
}