package gui

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

begin_path :: proc() {
    nvg.BeginPath(ctx.current_window.nvg_ctx)
}

close_path :: proc() {
    nvg.ClosePath(ctx.current_window.nvg_ctx)
}

move_to :: proc(position: Vec2) {
    nvg.MoveTo(ctx.current_window.nvg_ctx, position.x, position.y)
}

line_to :: proc(position: Vec2) {
    nvg.LineTo(ctx.current_window.nvg_ctx, position.x, position.y)
}

arc_to :: proc(p0, p1: Vec2, radius: f32) {
    nvg.ArcTo(ctx.current_window.nvg_ctx, p0.x, p0.y, p1.x, p1.y, radius)
}

rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
    w := ctx.current_window
    nvg.Rect(w.nvg_ctx, position.x, position.y, size.x, size.y)
    nvg.PathWinding(w.nvg_ctx, _path_winding_to_nvg_winding(winding))
}

rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    w := ctx.current_window
    nvg.RoundedRectVarying(w.nvg_ctx,
        position.x, position.y, size.x, size.y,
        top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius,
    )
    nvg.PathWinding(w.nvg_ctx, _path_winding_to_nvg_winding(winding))
}

rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    rounded_rect_varying(position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(paint: Paint) {
    w := ctx.current_window
    nvg.FillPaint(w.nvg_ctx, paint)
    nvg.Fill(w.nvg_ctx)
}

fill_path :: proc(color: Color) {
    fill_path_paint(solid_paint(color))
}

fill_text_line :: proc(text: string, position: Vec2, color := Color{1, 1, 1, 1}, font := ctx.default_font, font_size: f32 = 13.0) {
    if len(text) == 0 {
        return
    }
    w := ctx.current_window
    _set_font(w, font)
    _set_font_size(w, font_size)
    nvg.FillColor(w.nvg_ctx, color)
    nvg.Text(w.nvg_ctx, position.x, position.y, text)
}



_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
}