package widgets

import "base:runtime"
import "../../gui"
import "../rects"

// This is a simple text line that measures itself and
// updates its rect accordingly. It is aware of the
// current clip rect and will only draw the portion
// of the string that is visible on screen for optimization.
// The text does not own its string.

Text_Line :: struct {
    using rect: Rect,
    str: string,
    color: Color,
    font: gui.Font,
    glyphs: [dynamic]gui.Text_Glyph,
    byte_index_to_rune_index: map[int]int,
    needs_remeasure: bool, // Set this to true to ask the text to remeasure
}

text_line_init :: proc(text: ^Text_Line, allocator := context.allocator) -> runtime.Allocator_Error {
    text.glyphs = make([dynamic]gui.Text_Glyph, allocator = allocator)
    text.byte_index_to_rune_index = make(map[int]int, allocator = allocator)
    text.size = {96, 32}
    text.color = {1, 1, 1, 1}
    text.needs_remeasure = true
    return nil
}

text_line_destroy :: proc(text: ^Text_Line) {
    delete(text.glyphs)
    delete(text.byte_index_to_rune_index)
}

text_line_update :: proc(text: ^Text_Line) {
    assert(text.font != nil, "text_line_update called with nil font.")

    if text.needs_remeasure {
        gui.measure_text(text.str, text.font, &text.glyphs, &text.byte_index_to_rune_index)
        text.needs_remeasure = false
    }

    text.size.y = line_height(text.font)
    if len(text.glyphs) <= 0 {
        text.size.x = 0
    } else {
        left := text.glyphs[0]
        right := text.glyphs[len(text.glyphs) - 1]
        text.size.x = right.position + right.width - left.position
    }
}

text_line_draw :: proc(text: ^Text_Line) {
    assert(text.font != nil, "text_line_draw called with nil font.")

    str, x_compensation := visible_string(text)
    position := text.position
    position.x += x_compensation
    gui.fill_text(str, position, text.font, text.color)
}

visible_string :: proc(text: ^Text_Line) -> (str: string, x_compensation: f32) {
    glyph_count := len(text.glyphs)
    if glyph_count <= 0 do return "", 0

    left, right_exclusive := visible_glyph_range(text)
    if right_exclusive - left <= 0 do return "", 0

    left_byte_index := text.glyphs[left].byte_index
    byte_count := len(text.str)
    if left_byte_index >= byte_count do return "", 0

    x_compensation = text.glyphs[left].position

    if right_exclusive >= glyph_count {
        str = text.str[left_byte_index:]
    } else {
        right_byte_index := text.glyphs[right_exclusive].byte_index
        if right_byte_index < byte_count {
            str = text.str[left_byte_index:right_byte_index]
        } else {
            str = text.str[left_byte_index:]
        }
    }

    return
}

byte_index_to_rune_index :: proc(text: ^Text_Line, byte_index: int) -> (rune_index: int, out_of_bounds: bool) {
    if byte_index >= len(text.str) {
        return 0, true
    } else {
        return text.byte_index_to_rune_index[byte_index], false
    }
}

visible_glyph_range :: proc(text: ^Text_Line) -> (left, right_exclusive: int) {
    clip_rect := gui.clip_rect()
    if clip_rect.size.x <= 0 || clip_rect.size.y <= 0 {
        return 0, 0
    }

    position := text.position
    height := text.size.y
    left_set := false

    for glyph, i in text.glyphs {
        glyph_rect := Rect{position + {glyph.position, 0}, {glyph.width, height}}
        glyph_visible := rects.intersects(clip_rect, glyph_rect, include_borders = false)

        if !left_set {
            if glyph_visible {
                left = i
                left_set = true
            }
        } else {
            if !glyph_visible {
                right_exclusive = max(0, i)
                return
            }
        }
    }

    if left_set {
        right_exclusive = len(text.glyphs)
    }

    return
}