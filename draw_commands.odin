package gui

Draw_Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
    color: Color,
}

Draw_Command :: union {
    Draw_Rect_Command,
}

draw_rect :: proc(position, size: Vec2, color: Color, widget := _current_widget) {
    append(&widget.draw_commands, Draw_Rect_Command{position, size, color})
}