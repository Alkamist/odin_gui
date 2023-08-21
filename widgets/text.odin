package widgets

import "../../gui"

Font :: gui.Font
Glyph :: gui.Glyph

Text :: struct {
    font: ^Font,
    data: string,
    position: Vec2,
    color: Color,
    font_size: f32,

    glyphs: [dynamic]Glyph,
    size: Vec2,
    ascender: f32,
    descender: f32,
    x_height: f32,
}

make_text :: proc(
    font: ^Font,
    data := "",
    position := Vec2{0, 0},
    color := Color{1, 1, 1, 1},
    font_size := f32(13),
) -> Text {
    return {
        font = font,
        font_size = font_size,
        data = data,
        position = position,
        color = color,
    }
}

destroy_text :: proc(text: ^Text) {
    delete(text.glyphs)
}

update_text :: proc(text: ^Text) {
    if text.font == nil || text.font_size <= 0 {
        return
    }

    ascender, descender, line_height := gui.text_metrics(text.font, text.font_size)
    text.ascender = ascender
    text.descender = descender
    text.x_height = ascender + descender

    text.size.y = line_height

    if len(text.data) == 0 {
        return
    }

    gui.measure_glyphs(&text.glyphs, text.data, text.font, text.font_size)

    if len(text.glyphs) > 0 {
        text.size.x = text.glyphs[len(text.glyphs) - 1].right - text.glyphs[0].left
    }
}

draw_text :: proc(text: ^Text) {
    if text.font == nil || text.font_size <= 0 || len(text.data) == 0 || len(text.glyphs) == 0 {
        return
    }

    offset := Vec2{
        text.glyphs[0].draw_offset_x,
        text.size.y * 0.5 - text.x_height,
    }

    gui.fill_text_raw(
        text.data,
        text.position + offset,
        color = text.color,
        font = text.font,
        font_size = text.font_size,
    )
}