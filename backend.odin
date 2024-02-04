package gui

import "core:time"
import "rect"

Tick :: time.Tick
Duration :: time.Duration

Backend :: struct {
    user_data: rawptr,
    get_tick: proc(backend: ^Backend) -> (tick: Tick, ok: bool),
    set_cursor_style: proc(backend: ^Backend, style: Cursor_Style) -> (ok: bool),
    get_clipboard: proc(backend: ^Backend) -> (data: string, ok: bool),
    set_clipboard: proc(backend: ^Backend, data: string) -> (ok: bool),
    measure_text: proc(backend: ^Backend, glyphs: ^[dynamic]Text_Glyph, text: string, font: Font) -> (ok: bool),
    font_metrics: proc(backend: ^Backend, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(backend: ^Backend, command: Draw_Command),
}

redraw :: proc(widget := _current_widget) {
    assert(widget != nil)
    assert(widget.root != nil)
    clear(&widget.draw_commands)
    clip_drawing({0, 0}, widget.size, widget)
    send_event(widget, Draw_Event{})
    widget.root.needs_redisplay = true
}

get_tick :: proc(widget := _current_widget) -> (tick: Tick, ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.get_tick == nil do return {}, false
    return widget.root.backend->get_tick()
}

set_cursor_style :: proc(style: Cursor_Style, widget := _current_widget) -> (ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.set_cursor_style == nil do return false
    return widget.root.backend->set_cursor_style(style)
}

get_clipboard :: proc(widget := _current_widget) -> (data: string, ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.get_clipboard == nil do return "", false
    return widget.root.backend->get_clipboard()
}

set_clipboard :: proc(data: string, widget := _current_widget) -> (ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.set_clipboard == nil do return false
    return widget.root.backend->set_clipboard(data)
}

measure_text :: proc(glyphs: ^[dynamic]Text_Glyph, text: string, font: Font, widget := _current_widget) -> (ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.measure_text == nil do return false
    return widget.root.backend->measure_text(glyphs, text, font)
}

font_metrics :: proc(font: Font, widget := _current_widget) -> (metrics: Font_Metrics, ok: bool) {
    assert(widget != nil)
    assert(widget.root != nil)
    if widget.root.backend.font_metrics == nil do return {}, false
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
            if global_clip_rect, ok := widget.cached_global_clip_rect.?; ok {
                intersected_clip_rect := rect.intersection(global_clip_rect, {global_position + c.position, c.size})
                _render_draw_command(widget, Clip_Drawing_Command{
                    intersected_clip_rect.position,
                    intersected_clip_rect.size,
                })
            } else {
                _render_draw_command(widget, Clip_Drawing_Command{global_position + c.position, c.size})
            }
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