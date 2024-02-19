package backend_nanovg

import "core:fmt"
import nvg "vendor:nanovg"
import "../../../gui"

Font :: struct {
    name: string,
    size: int,
    data: []byte,
}

load_font :: proc(nvg_ctx: ^nvg.Context, font: gui.Font) -> (ok: bool) {
    font := cast(^Font)font
    if len(font.data) <= 0 do return false
    if nvg.CreateFontMem(nvg_ctx, font.name, font.data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
        return false
    }
    return true
}

measure_text :: proc(
    nvg_ctx: ^nvg.Context,
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) -> (ok: bool) {
    font := cast(^Font)font

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), gui.arena_allocator())

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        if byte_index_to_rune_index != nil {
            byte_index_to_rune_index[nvg_positions[i].str] = i
        }
        glyphs[i] = gui.Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }

    return true
}

font_metrics :: proc(nvg_ctx: ^nvg.Context, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    font := cast(^Font)font

    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)

    return metrics, true
}

render_draw_command :: proc(nvg_ctx: ^nvg.Context, command: gui.Draw_Command) {
    switch cmd in command {
    case gui.Draw_Custom_Command:
        if cmd.custom != nil {
            nvg.Save(nvg_ctx)
            cmd.custom()
            nvg.Restore(nvg_ctx)
        }

    case gui.Fill_Path_Command:
        nvg.Save(nvg_ctx)

        nvg.BeginPath(nvg_ctx)

        for sub_path in cmd.path.sub_paths {
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

        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Fill(nvg_ctx)

        nvg.Restore(nvg_ctx)

    case gui.Fill_Text_Command:
        font := cast(^Font)cmd.font
        position := gui.pixel_snapped(cmd.position)
        nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
        nvg.FontFace(nvg_ctx, font.name)
        nvg.FontSize(nvg_ctx, f32(font.size))
        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Text(nvg_ctx, position.x, position.y, cmd.text)

    case gui.Clip_Drawing_Command:
        rect := gui.pixel_snapped(cmd.global_clip_rect)
        nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))
    }
}