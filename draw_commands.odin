package gui

import "rect"

Draw_Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
    color: Color,
}

Clip_Drawing_Command :: struct {
    position: Vec2,
    size: Vec2,
}

Draw_Command :: union {
    Draw_Rect_Command,
    Clip_Drawing_Command,
}

draw_rect :: proc(position, size: Vec2, color: Color, widget := _current_widget) {
    append(&widget.draw_commands, Draw_Rect_Command{position, size, color})
}

clip_drawing :: proc(position, size: Vec2, widget := _current_widget) {
    append(&widget.draw_commands, Clip_Drawing_Command{position, size})
}

redraw :: proc(widget := _current_widget) {
    clear(&widget.draw_commands)
    clip_drawing({0, 0}, widget.size, widget)
    send_event(widget, Draw_Event{})
    widget.root.needs_redisplay = true
}

collect_draw_commands :: proc(commands: ^[dynamic]Draw_Command, widget: ^Widget) {
    if widget.is_hidden {
        return
    }

    _update_cached_global_helpers(widget)
    global_position := widget.cached_global_position
    global_clip_rect := widget.cached_global_clip_rect

    for command in widget.draw_commands {
        switch c in command {

        case Draw_Rect_Command:
            append(commands, Draw_Rect_Command{
                c.position + global_position,
                c.size,
                c.color,
            })

        case Clip_Drawing_Command:
            intersected_clip_rect := rect.intersection(global_clip_rect, {global_position + c.position, c.size})
            append(commands, Clip_Drawing_Command{
                intersected_clip_rect.position,
                intersected_clip_rect.size,
            })
        }
    }

    for child in widget.children {
        collect_draw_commands(commands, child)
    }
}