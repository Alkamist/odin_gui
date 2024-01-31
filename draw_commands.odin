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

// Draw_Text_Command :: struct {}

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