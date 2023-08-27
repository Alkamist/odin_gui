package gui

import "core:fmt"
import "core:math"
import "core:slice"
import nvg "vendor:nanovg"

Paint :: nvg.Paint

Path_Winding :: enum {
    Positive,
    Negative,
}

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

solid_paint :: proc(color: Color) -> Paint {
    paint: Paint
    nvg.TransformIdentity(&paint.xform)
    paint.radius = 0.0
    paint.feather = 1.0
    paint.innerColor = color
    paint.outerColor = color
    return paint
}

quantize :: proc{
    quantize_f32,
    quantize_vec2,
}

quantize_f32 :: proc(value, distance: f32) -> f32 {
    return math.round(value / distance) * distance
}

quantize_vec2 :: proc(vec: Vec2, distance: f32) -> Vec2 {
    return {
        math.round(vec.x / distance) * distance,
        math.round(vec.y / distance) * distance,
    }
}

pixel_distance :: proc(window := _current_window) -> f32 {
    return 1.0 / window.cached_content_scale
}

pixel_align :: proc{
    pixel_align_f32,
    pixel_align_vec2,
}

pixel_align_f32 :: proc(value: f32, window := _current_window) -> f32 {
    return quantize_f32(value, pixel_distance(window))
}

pixel_align_vec2 :: proc(vec: Vec2, window := _current_window) -> Vec2 {
    pixel_distance := pixel_distance(window)
    return {
        quantize_f32(vec.x, pixel_distance),
        quantize_f32(vec.y, pixel_distance),
    }
}

begin_path :: proc() {
    append(&get_layer().draw_commands, Begin_Path_Command{})
}

close_path :: proc() {
    append(&get_layer().draw_commands, Close_Path_Command{})
}

path_move_to :: proc(position: Vec2) {
    append(&get_layer().draw_commands, Move_To_Command{
        position + get_offset(),
    })
}

path_line_to :: proc(position: Vec2) {
    append(&get_layer().draw_commands, Line_To_Command{
        position + get_offset(),
    })
}

path_arc_to :: proc(p0, p1: Vec2, radius: f32) {
    offset := get_offset()
    append(&get_layer().draw_commands, Arc_To_Command{
        p0 + offset,
        p1 + offset,
        radius,
    })
}

path_circle :: proc(center: Vec2, radius: f32) {
    append(&get_layer().draw_commands, Circle_Command{
        center + get_offset(),
        radius,
    })
}

path_rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
    layer := get_layer()
    pixel := pixel_distance()
    size := Vec2{
        max(pixel, size.x),
        max(pixel, size.y),
    }

    append(&layer.draw_commands, Rect_Command{
        position + get_offset(),
        size,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

path_rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    layer := get_layer()
    pixel := pixel_distance()
    size := Vec2{
        max(pixel, size.x),
        max(pixel, size.y),
    }

    append(&layer.draw_commands, Rounded_Rect_Command{
        position + get_offset(),
        size,
        top_left_radius, top_right_radius,
        bottom_right_radius, bottom_left_radius,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

path_rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    path_rounded_rect_varying(position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(paint: Paint) {
    append(&get_layer().draw_commands, Fill_Path_Command{paint})
}

fill_path :: proc(color: Color) {
    fill_path_paint(solid_paint(color))
}

stroke_path_paint :: proc(paint: Paint, width := f32(1)) {
    append(&get_layer().draw_commands, Stroke_Path_Command{paint, width})
}

stroke_path :: proc(color: Color, width := f32(1)) {
    append(&get_layer().draw_commands, Stroke_Path_Command{solid_paint(color), width})
}

fill_text_raw :: proc(
    text: string,
    position: Vec2,
    color: Color,
    font: ^Font,
    font_size: f32,
) {
    append(&get_layer().draw_commands, Fill_Text_Command{
        font = font,
        font_size = font_size,
        position = pixel_align(position + get_offset()),
        text = text,
        color = color,
    })
}
text_metrics :: proc(font: ^Font, font_size: f32) -> (ascender, descender, line_height: f32) {
    window := _current_window
    _set_font(window, font)
    _set_font_size(window, font_size)
    return nvg.TextMetrics(window.nvg_ctx)
}

measure_glyphs :: proc(
    glyphs: ^[dynamic]Glyph,
    text: string,
    font: ^Font,
    font_size: f32,
) {
    clear(glyphs)

    if len(text) == 0 {
        return
    }

    _set_font(_current_window, font)
    _set_font_size(_current_window, font_size)

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), _arena_allocator)
    defer delete(nvg_positions)

    // This will change when nanovg is fixed.
    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(_current_window.nvg_ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        glyphs[i] = Glyph{
            rune_position = nvg_positions[i].str,
            left = nvg_positions[i].minx,
            right = nvg_positions[i].maxx,
            draw_offset_x = nvg_positions[i].x - nvg_positions[i].minx,
        }
    }
}



_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
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