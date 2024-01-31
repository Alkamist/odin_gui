package gui

import "rect"

Font :: rawptr

Draw_Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
    color: Color,
}

Draw_Text_Command :: struct {
    text: string,
    position: Vec2,
    color: Color,
    font: Font,
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
    append(&widget.draw_commands, Draw_Rect_Command{position, size, color})
}

draw_text :: proc(text: string, position: Vec2, color: Color, font: Font, widget := _current_widget) {
    append(&widget.draw_commands, Draw_Text_Command{text, position, color, font})
}

clip_drawing :: proc(position, size: Vec2, widget := _current_widget) {
    append(&widget.draw_commands, Clip_Drawing_Command{position, size})
}