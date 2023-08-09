package gui

import "core:math"
import nvg "vendor:nanovg"
import "color"

Color :: color.Color
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

pixel_align_f32 :: proc(value: f32, window := _current_window) -> f32 {
    scale := window.cached_content_scale
    return math.round(value * scale) / scale
}

pixel_align_vec2 :: proc(position: Vec2) -> Vec2 {
    return {pixel_align_f32(position.x), pixel_align_f32(position.y)}
}

begin_path :: proc() {
    append(&current_layer().draw_commands, Begin_Path_Command{})
}

close_path :: proc() {
    append(&current_layer().draw_commands, Close_Path_Command{})
}

move_to :: proc(position: Vec2) {
    append(&current_layer().draw_commands, Move_To_Command{
        position + current_offset(),
    })
}

line_to :: proc(position: Vec2) {
    append(&current_layer().draw_commands, Line_To_Command{
        position + current_offset(),
    })
}

arc_to :: proc(p0, p1: Vec2, radius: f32) {
    offset := current_offset()
    append(&current_layer().draw_commands, Arc_To_Command{
        p0 + offset,
        p1 + offset,
        radius,
    })
}

rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
    layer := current_layer()
    append(&layer.draw_commands, Rect_Command{
        position + current_offset(),
        size,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    layer := current_layer()
    append(&layer.draw_commands, Rounded_Rect_Command{
        position + current_offset(),
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
    append(&current_layer().draw_commands, Fill_Path_Command{paint})
}

fill_path :: proc(color: Color) {
    fill_path_paint(solid_paint(color))
}

fill_text_line :: proc(
    text: string,
    position: Vec2,
    color := Color{1, 1, 1, 1},
    font := _current_window.default_font,
    font_size := f32(13),
) {
    append(&current_layer().draw_commands, Fill_Text_Command{
      font = font,
      font_size = font_size,
      position = pixel_align(current_offset() + position),
      text = text,
      color = color,
    })
}



@(private)
_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
}