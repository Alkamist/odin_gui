package gui

import "rect"

Backend_Error :: enum {
    None,
    Text_Error,
}

Backend :: struct {
    user_data: rawptr,
    measure_text: proc(^Backend, string, Font) -> (f32, Backend_Error),
    font_metrics: proc(^Backend, Font) -> (Font_Metrics, Backend_Error),
    render_draw_command: proc(^Backend, Draw_Command),
}

redraw :: proc(widget := _current_widget) {
    assert(widget != nil)
    assert(widget.root != nil)
    clear(&widget.draw_commands)
    clip_drawing({0, 0}, widget.size, widget)
    send_event(widget, Draw_Event{})
    widget.root.needs_redisplay = true
}

measure_text :: proc(text: string, font: Font, widget := _current_widget) -> (f32, Backend_Error) {
    if widget == nil || widget.root == nil || widget.root.backend.measure_text == nil {
        return 0, .Text_Error
    }
    return widget.root.backend->measure_text(text, font)
}

font_metrics :: proc(font: Font, widget := _current_widget) -> (Font_Metrics, Backend_Error) {
    if widget == nil || widget.root == nil || widget.root.backend.font_metrics == nil {
        return {}, .Text_Error
    }
    return widget.root.backend->font_metrics(font)
}

render_draw_commands :: proc(widget: ^Widget) {
    if widget.is_hidden {
        return
    }

    _update_cached_global_helpers(widget)
    global_position := widget.cached_global_position

    for command in widget.draw_commands {
        switch c in command {

        case Draw_Rect_Command:
            _render_draw_command(widget, Draw_Rect_Command{
                c.position + global_position,
                c.size,
                c.color,
            })

        case Draw_Text_Command:
            _render_draw_command(widget, Draw_Text_Command{
                c.text,
                c.position + global_position,
                c.font,
                c.color,
            })

        case Clip_Drawing_Command:
            global_clip_rect, ok := widget.cached_global_clip_rect.?
            if !ok {
                break
            }
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
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.render_draw_command != nil {
        widget.root.backend->render_draw_command(command)
    }
}