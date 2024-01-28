package gui

import "core:fmt"
import "rect"

Backend :: struct {
    user_data: rawptr,
    redisplay: proc(^Backend),
    render_draw_command: proc(^Backend, Draw_Command),
}

redraw :: proc(widget := _current_widget) {
    clear(&widget.draw_commands)
    clip_drawing({0, 0}, widget.size, widget)
    send_event(widget, Draw_Event{})
    if widget.root.backend.redisplay != nil {
        widget.root.backend->redisplay()
    }
}

render_draw_commands :: proc(widget: ^Widget) {
    _update_cached_global_helpers(widget)
    global_position := widget.cached_global_position
    global_clip_rect := widget.cached_global_clip_rect

    for command in widget.draw_commands {
        switch c in command {

        case Draw_Rect_Command:
            _render_draw_command(widget, Draw_Rect_Command{
                c.position + global_position,
                c.size,
                c.color,
            })

        case Clip_Drawing_Command:
            intersected_clip_rect := rect.intersection(global_clip_rect, {global_position + c.position, c.size})
            _render_draw_command(widget, Clip_Drawing_Command{
                intersected_clip_rect.position,
                intersected_clip_rect.size,
            })
        }
    }

    for child in widget.children {
        render_draw_commands(child)
    }
}

_render_draw_command :: proc(widget: ^Widget, command: Draw_Command) {
    if widget.root.backend.render_draw_command != nil {
        widget.root.backend->render_draw_command(command)
    }
}