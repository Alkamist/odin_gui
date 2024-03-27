package main

import "core:fmt"
import "core:math"
import nvg "vendor:nanovg"

Font :: struct {
    name: string,
    size: int,
    data: []byte,
}

Font_Metrics :: struct {
    ascender: f32,
    descender: f32,
    line_height: f32,
}

Text_Glyph :: struct {
    byte_index: int,
    position: f32,
    width: f32,
    kerning: f32,
}

measure_text :: proc(
    text: string,
    font: Font,
    glyphs: ^[dynamic]Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) {
    window := current_window()
    nvg_ctx := window.nvg_ctx

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    _load_font(window, font)

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), context.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        if byte_index_to_rune_index != nil {
            byte_index_to_rune_index[nvg_positions[i].str] = i
        }
        glyphs[i] = Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics) {
    window := current_window()
    nvg_ctx := window.nvg_ctx
    _load_font(window, font)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)
    pixel_height := pixel_size().y
    metrics.line_height = math.ceil(metrics.line_height / pixel_height) * pixel_height
    return
}

fill_text :: proc(text: string, position: Vector2, font: Font, color: Color) {
    window := current_window()
    nvg_ctx := window.nvg_ctx
    _load_font(window, font)
    position := pixel_snapped(position)
    nvg.Save(nvg_ctx)
    offset := global_offset()
    nvg.Translate(nvg_ctx, offset.x, offset.y)
    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    nvg.FillColor(nvg_ctx, color)
    nvg.Text(nvg_ctx, position.x, position.y, text)
    nvg.Restore(nvg_ctx)
}

fill_path :: proc(path: Path, color: Color) {
    nvg_ctx := current_window().nvg_ctx

    nvg.Save(nvg_ctx)

    offset := global_offset()
    nvg.Translate(nvg_ctx, offset.x, offset.y)

    nvg.BeginPath(nvg_ctx)

    for sub_path in path.sub_paths {
        nvg.MoveTo(nvg_ctx, sub_path.points[0].x, sub_path.points[0].y)

        for i := 1; i < len(sub_path.points); i += 3 {
            c1 := sub_path.points[i]
            c2 := sub_path.points[i + 1]
            point := sub_path.points[i + 2]
            nvg.BezierTo(nvg_ctx,
                c1.x, c1.y,
                c2.x, c2.y,
                point.x, point.y,
            )
        }

        if sub_path.is_closed {
            nvg.ClosePath(nvg_ctx)
        }
    }

    nvg.FillColor(nvg_ctx, color)
    nvg.Fill(nvg_ctx)

    nvg.Restore(nvg_ctx)
}

set_visual_clip_rectangle :: proc(rectangle: Rectangle) {
    nvg.Scissor(_current_window.nvg_ctx, rectangle.x, rectangle.y, rectangle.size.x, rectangle.size.y)
}

_load_font :: proc(window: ^Window, font: Font) {
    if len(font.data) <= 0 do return
    if font.name not_in window.loaded_fonts {
        if nvg.CreateFontMem(window.nvg_ctx, font.name, font.data, false) == -1 {
            fmt.eprintf("Failed to load font: %v\n", font.name)
        } else {
            window.loaded_fonts[font.name] = {}
        }
    }
}