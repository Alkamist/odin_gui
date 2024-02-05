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

content_scale :: proc(window := _current_window) -> Vec2 {
    assert(window != nil)
    return window.content_scale
}

pixel_size :: proc(window := _current_window) -> Vec2 {
    assert(window != nil)
    return 1.0 / window.content_scale
}

draw_rect :: proc(position, size: Vec2, color: Color, window := _current_window) {
    assert(window != nil)
    window.backend->render_draw_command(Draw_Rect_Command{window.draw_offset + position, size, color})
}

draw_text :: proc(text: string, position: Vec2, font: Font, color: Color, window := _current_window) {
    assert(window != nil)
    window.backend->render_draw_command(Draw_Text_Command{text, window.draw_offset + position, font, color})
}

clip_drawing :: proc(position, size: Vec2, window := _current_window) {
    assert(window != nil)
    window.backend->render_draw_command(Clip_Drawing_Command{window.draw_offset + position, size})
}