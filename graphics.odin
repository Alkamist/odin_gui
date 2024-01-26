package gui

import wnd "window"

Paint :: wnd.Paint
Path_Winding :: wnd.Path_Winding
Font :: wnd.Font
Glyph :: wnd.Glyph

solid_paint :: wnd.solid_paint
quantize :: wnd.quantize

begin_path :: proc(window := _current_window) {
    wnd.begin_path(&window.backend)
}

close_path :: proc(window := _current_window) {
    wnd.close_path(&window.backend)
}

path_move_to :: proc(position: Vec2, window := _current_window) {
    wnd.path_move_to(&window.backend, position)
}

path_line_to :: proc(position: Vec2, window := _current_window) {
    wnd.path_line_to(&window.backend, position)
}

path_arc_to :: proc(p0, p1: Vec2, radius: f32, window := _current_window) {
    wnd.path_arc_to(&window.backend, p0, p1, radius)
}

path_circle :: proc(center: Vec2, radius: f32, winding: Path_Winding = .Positive, window := _current_window) {
    wnd.path_circle(&window.backend, center, radius, winding)
}

path_rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive, window := _current_window) {
    wnd.path_rect(&window.backend, position, size, winding)
}

path_rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive, window := _current_window) {
    wnd.path_rounded_rect_varying(&window.backend, position, size, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius, winding)
}

path_rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive, window := _current_window) {
    wnd.path_rounded_rect(&window.backend, position, size, radius, winding)
}

fill_path_paint :: proc(paint: Paint, window := _current_window) {
    wnd.fill_path_paint(&window.backend, paint)
}

fill_path :: proc(color: Color, window := _current_window) {
    wnd.fill_path(&window.backend, color)
}

stroke_path_paint :: proc(paint: Paint, width := f32(1), window := _current_window) {
    wnd.stroke_path_paint(&window.backend, paint, width)
}

stroke_path :: proc(color: Color, width := f32(1), window := _current_window) {
    wnd.stroke_path(&window.backend, color, width)
}

translate_path :: proc(amount: Vec2, window := _current_window) {
    wnd.translate_path(&window.backend, amount)
}