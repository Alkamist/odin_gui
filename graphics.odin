package gui

Color :: [4]f32
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

Draw_Command :: union {
    Draw_Rect_Command,
    Draw_Text_Command,
    Clip_Drawing_Command,
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

draw_rect :: proc(position, size: Vec2, color: Color) {
    append(&get_layer().draw_commands, Draw_Rect_Command{get_offset() + position, size, color})
}

draw_text :: proc(text: string, position: Vec2, font: Font, color: Color) {
    append(&get_layer().draw_commands, Draw_Text_Command{text, get_offset() + position, font, color})
}

clip_drawing :: proc(position, size: Vec2) {
    append(&get_layer().draw_commands, Clip_Drawing_Command{get_offset() + position, size})
}