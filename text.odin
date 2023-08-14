package gui

import "core:fmt"
import "core:slice"
import nvg "vendor:nanovg"

Font :: struct {
    name: string,
    data: []byte,
}

Glyph :: struct {
    rune_position: int,
    left: f32,
    right: f32,
    draw_offset_x: f32,
}

Text_Metrics :: struct {
    ascender: f32,
    descender: f32,
    x_height: f32,
    line_height: f32,
}

text_metrics :: proc(
    font := _current_window.default_font,
    font_size := _current_window.default_font_size,
) -> Text_Metrics {
    window := _current_window

    _set_font(window, font)
    _set_font_size(window, font_size)

    nvg_ascender, nvg_descender, line_height := nvg.TextMetrics(window.nvg_ctx)

    // These seem to be wrong, but contain the right information.
    corrected_nvg_ascender := -nvg_descender
    corrected_nvg_descender := line_height - nvg_ascender

    x_height := line_height - corrected_nvg_ascender - corrected_nvg_descender

    real_ascender := line_height * 0.5 - x_height
    real_descender := line_height - real_ascender - x_height

    return {
        ascender = real_ascender,
        descender = real_descender,
        x_height = x_height,
        line_height = line_height,
    }
}

measure_text :: proc(
    text: string,
    font := _current_window.default_font,
    font_size := _current_window.default_font_size,
) -> (width, advance: f32) {
    window := _current_window

    _set_font(window, font)
    _set_font_size(window, font_size)

    bounds: [4]f32
    advance = nvg.TextBounds(window.nvg_ctx, 0, 0, text, &bounds)

    return bounds[2] - bounds[0], advance
}

measure_glyphs :: proc(
    text: string,
    font := _current_window.default_font,
    font_size := _current_window.default_font_size,
) -> [dynamic]Glyph {
    result: [dynamic]Glyph

    if len(text) == 0 {
        return result
    }

    window := _current_window
    _set_font(window, font)
    _set_font_size(window, font_size)

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text))
    defer delete(nvg_positions)

    // This will change when nanovg is fixed.
    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(window.nvg_ctx, 0, 0, text, &temp_slice)

    resize(&result, position_count)

    for i in 0 ..< position_count {
        result[i] = Glyph{
            rune_position = nvg_positions[i].str,
            left = nvg_positions[i].minx,
            right = nvg_positions[i].maxx,
            draw_offset_x = nvg_positions[i].x - nvg_positions[i].minx,
        }
    }

    return result
}



@(private)
_set_font :: proc(w: ^Window, font: ^Font) {
    if !slice.contains(w.loaded_fonts[:], font) {
        id := nvg.CreateFontMem(w.nvg_ctx, font.name, font.data, false)
        if id == -1 {
            fmt.eprintf("Failed to load font: %v\n", font.name)
            return
        }
        append(&w.loaded_fonts, font)
    }
    if font == w.current_font {
        return
    }
    nvg.FontFace(w.nvg_ctx, font.name)
    w.current_font = font
}

@(private)
_set_font_size :: proc(w: ^Window, font_size: f32) {
    if font_size == w.current_font_size {
        return
    }
    nvg.FontSize(w.nvg_ctx, font_size)
    w.current_font_size = font_size
}