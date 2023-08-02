package gui

import "core:fmt"
import "core:math"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

Vec2 :: [2]f32
Color :: [4]f32
Paint :: nvg.Paint

Path_Winding :: enum {
    Positive,
    Negative,
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

pixel_align :: proc{
    pixel_align_f32,
    pixel_align_vec2,
}

pixel_align_f32 :: proc(value: f32) -> f32 {
    scale := window_content_scale(ctx.current_window)
    return math.round(value * scale) / scale
}

pixel_align_vec2 :: proc(position: Vec2) -> Vec2 {
    return {pixel_align_f32(position.x), pixel_align_f32(position.y)}
}

begin_path :: proc() {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Begin_Path_Command{})
}

close_path :: proc() {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Close_Path_Command{})
}

move_to :: proc(position: Vec2) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Move_To_Command{
        position + w.current_offset,
    })
}

line_to :: proc(position: Vec2) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Line_To_Command{
        position + w.current_offset,
    })
}

arc_to :: proc(p0, p1: Vec2, radius: f32) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    offset := w.current_offset
    append(&layer.draw_commands, Arc_To_Command{
        p0 + offset,
        p1 + offset,
        radius,
    })
}

rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Rect_Command{
        position + w.current_offset,
        size,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Rounded_Rect_Command{
        position + w.current_offset,
        size,
        top_left_radius, top_right_radius,
        bottom_right_radius, bottom_left_radius,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    rounded_rect_varying(position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(paint: Paint) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Fill_Path_Command{paint})
}

fill_path :: proc(color: Color) {
    fill_path_paint(solid_paint(color))
}

fill_text_line :: proc(text: string, position: Vec2, color := Color{1, 1, 1, 1}, font := ctx.default_font, font_size := f32(13)) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    layer := w.current_layer
    append(&layer.draw_commands, Fill_Text_Command{
      font = font,
      font_size = font_size,
      position = pixel_align(w.current_offset + position),
      text = text,
      color = color,
    })
}


// begin_path :: proc() {
//     nvg.BeginPath(ctx.current_window.nvg_ctx)
// }

// close_path :: proc() {
//     nvg.ClosePath(ctx.current_window.nvg_ctx)
// }

// move_to :: proc(position: Vec2) {
//     nvg.MoveTo(ctx.current_window.nvg_ctx, position.x, position.y)
// }

// line_to :: proc(position: Vec2) {
//     nvg.LineTo(ctx.current_window.nvg_ctx, position.x, position.y)
// }

// arc_to :: proc(p0, p1: Vec2, radius: f32) {
//     nvg.ArcTo(ctx.current_window.nvg_ctx, p0.x, p0.y, p1.x, p1.y, radius)
// }

// rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
//     w := ctx.current_window
//     nvg.Rect(w.nvg_ctx, position.x, position.y, size.x, size.y)
//     nvg.PathWinding(w.nvg_ctx, _path_winding_to_nvg_winding(winding))
// }

// rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
//     w := ctx.current_window
//     nvg.RoundedRectVarying(w.nvg_ctx,
//         position.x, position.y, size.x, size.y,
//         top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius,
//     )
//     nvg.PathWinding(w.nvg_ctx, _path_winding_to_nvg_winding(winding))
// }

// rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
//     rounded_rect_varying(position, size, radius, radius, radius, radius, winding)
// }

// fill_path_paint :: proc(paint: Paint) {
//     w := ctx.current_window
//     nvg.FillPaint(w.nvg_ctx, paint)
//     nvg.Fill(w.nvg_ctx)
// }

// fill_path :: proc(color: Color) {
//     fill_path_paint(solid_paint(color))
// }

// fill_text_line :: proc(text: string, position: Vec2, color := Color{1, 1, 1, 1}, font := ctx.default_font, font_size: f32 = 13.0) {
//     if len(text) == 0 {
//         return
//     }
//     w := ctx.current_window
//     _set_font(w, font)
//     _set_font_size(w, font_size)
//     nvg.FillColor(w.nvg_ctx, color)
//     nvg.Text(w.nvg_ctx, position.x, position.y, text)
// }



@(private)
_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
}