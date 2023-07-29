package gui

import "core:fmt"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "window"

// Font :: int
// Color :: [4]f32
// Paint :: nvg.Paint

// Path_Winding :: enum {
//     Positive,
//     Negative,
// }

// Cursor_Style :: window.Cursor_Style
// Mouse_Button :: window.Mouse_Button
// Keyboard_Key :: window.Keyboard_Key
// Context_Error :: window.Window_Error

// Window :: struct {
//     using window: window.Window,
//     nvg_ctx: ^nvg.Context,
//     font: Font,
//     font_size: f32,
// }

// solid_paint :: proc(color: Color) -> Paint {
//     paint: Paint
//     nvg.TransformIdentity(&paint.xform)
//     paint.radius = 0.0
//     paint.feather = 1.0
//     paint.innerColor = color
//     paint.outerColor = color
//     return paint
// }

// begin_path :: proc(w: ^Window) {
//     nvg.BeginPath(w.nvg_ctx)
// }

// close_path :: proc(w: ^Window) {
//     nvg.ClosePath(w.nvg_ctx)
// }

// move_to :: proc(w: ^Window, position: Vec2) {
//     nvg.MoveTo(w.nvg_ctx, position.x, position.y)
// }

// line_to :: proc(w: ^Window, position: Vec2) {
//     nvg.LineTo(w.nvg_ctx, position.x, position.y)
// }

// arc_to :: proc(w: ^Window, p0, p1: Vec2, radius: f32) {
//     nvg.ArcTo(w.nvg_ctx, p0.x, p0.y, p1.x, p1.y, radius)
// }

// rect :: proc(w: ^Window, position, size: Vec2, winding: Path_Winding = .Positive) {
//     nvg.Rect(w.nvg_ctx, position.x, position.y, size.x, size.y)
//     nvg.Winding(_path_winding_to_nvg_winding(winding))
// }

// rounded_rect_varying :: proc(w: ^Window, position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
//     nvg.RoundedRectVarying(w.nvg_ctx,
//         position.x, position.y, size.x, size.y,
//         top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius,
//     )
//     nvg.Winding(_path_winding_to_nvg_winding(winding))
// }

// rounded_rect :: proc(w: ^Window, position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
//     rounded_rect_varying(w, position, size, radius, radius, radius, radius, winding)
// }

// fill_path_paint :: proc(w: ^Window, paint: Paint) {
//     nvg.FillPaint(w.nvg_ctx, paint)
//     nvg.Fill(w.nvg_ctx)
// }

// fill_path :: proc(w: ^Window, color: Color) {
//     fill_path_paint(w, solid_paint(color))
// }

// fill_text_line :: proc(w: ^Window, text: string, position: Vec2, color := Color{1, 1, 1, 1}, font: Font = 0, font_size: f32 = 13.0) {
//     if len(text) == 0 {
//         return
//     }
//     _set_font(w, font)
//     _set_font_size(w, font_size)
//     nvg.FillColor(w.nvg_ctx, color)
//     nvg.Text(w.nvg_ctx, position.x, position.y, text)
// }

// load_font_data :: proc(w: ^Window, data: []byte) -> Font {
//     font := nvg.CreateFontMem(w.nvg_ctx, "", data, false)
//     if font == -1 {
//         fmt.eprintln("Failed to load font.")
//     }
//     return font
// }

// text_metrics :: proc(w: ^Window, font: Font, font_size: f32) -> (ascender, descender, line_height: f32) {
//     _set_font(w, font)
//     _set_font_size(w, font_size)
//     return nvg.TextMetrics(w.nvg_ctx)
// }

// _set_font :: proc(w: ^Window, font: Font) {
//     if font == w.font {
//         return
//     }
//     nvg.FontFaceId(w.nvg_ctx, font)
//     w.font = font
// }

// _set_font_size :: proc(w: ^Window, font_size: f32) {
//     if font_size == w.font_size {
//         return
//     }
//     nvg.FontSize(w.nvg_ctx, font_size)
//     w.font_size = font_size
// }

// _path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
//     switch winding {
//     case .Negative: return .CW
//     case .Positive: return .CCW
//     }
//     return .CW
// }