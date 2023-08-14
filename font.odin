package gui

import "core:fmt"
import "core:slice"
import nvg "vendor:nanovg"

Font :: struct {
    name: string,
    data: []byte,
}

text_metrics :: proc(
    font := _current_window.default_font,
    font_size := f32(13),
) -> (ascender, descender, line_height: f32) {
    window := _current_window
    _set_font(window, font)
    _set_font_size(window, font_size)
    return nvg.TextMetrics(window.nvg_ctx)
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