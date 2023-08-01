package gui

import "core:fmt"
import "core:slice"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

Font :: struct {
    name: string,
    data: []byte,
}

create_font :: proc(name: string, data: []byte) -> ^Font {
    font := new(Font)
    font.name = name
    font.data = data
    return font
}

destroy_font :: proc(font: ^Font) {
    free(font)
}

text_metrics :: proc(w: ^Window, font: ^Font, font_size: f32) -> (ascender, descender, line_height: f32) {
    _set_font(w, font)
    _set_font_size(w, font_size)
    return nvg.TextMetrics(w.nvg_ctx)
}

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

_set_font_size :: proc(w: ^Window, font_size: f32) {
    if font_size == w.current_font_size {
        return
    }
    nvg.FontSize(w.nvg_ctx, font_size)
    w.current_font_size = font_size
}