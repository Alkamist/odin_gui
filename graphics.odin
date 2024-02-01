package gui

import "rect"

Font :: rawptr

Font_Metrics :: struct {
    ascender: f32,
    descender: f32,
    line_height: f32,
}

Draw_Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
    color: Color,
}

Draw_Text_Command :: struct {
    text: string,
    position: Vec2,
    font: Font,
    color: Color,
}

Clip_Drawing_Command :: struct {
    position: Vec2,
    size: Vec2,
}

Draw_Command :: union {
    Draw_Rect_Command,
    Draw_Text_Command,
    Clip_Drawing_Command,
}

draw_rect :: proc(position, size: Vec2, color: Color, widget := _current_widget) {
    assert(widget != nil)
    append(&widget.draw_commands, Draw_Rect_Command{position, size, color})
}

draw_text :: proc(text: string, position: Vec2, font: Font, color: Color, widget := _current_widget) {
    assert(widget != nil)
    append(&widget.draw_commands, Draw_Text_Command{text, position, font, color})
}

clip_drawing :: proc(position, size: Vec2, widget := _current_widget) {
    assert(widget != nil)
    append(&widget.draw_commands, Clip_Drawing_Command{position, size})
}