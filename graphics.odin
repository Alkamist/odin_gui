package gui

import "rect"

Font :: rawptr

Font_Metrics :: struct {
    ascender: f32,
    descender: f32,
    line_height: f32,
}

Text_Glyph :: struct {
    rune_index: int,
    position: f32,
    width: f32,
    kerning: f32,
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

content_scale :: proc(widget := _current_widget) -> Vec2 {
    assert(widget != nil)
    assert(widget.root != nil)
    return widget.root.content_scale
}

pixel_size :: proc(widget := _current_widget) -> Vec2 {
    assert(widget != nil)
    assert(widget.root != nil)
    return 1.0 / widget.root.content_scale
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