package widgets

import "../../gui"

Vec2 :: gui.Vec2
Color :: gui.Color

fill_rounded_rect :: proc(position, size: Vec2, rounding: f32, color: Color) {
    gui.begin_path()
    gui.path_rounded_rect(position, size, rounding)
    gui.fill_path(color)
}

outline_rounded_rect :: proc(position, size: Vec2, rounding: f32, color: Color) {
    pixel := gui.pixel_distance()
    gui.begin_path()
    gui.path_rounded_rect(position + pixel * 0.5, size - pixel, rounding)
    gui.stroke_path(color, 1)
}

drop_shadow :: proc(position, size: Vec2, corner_radius, feather, intensity: f32) {
    gui.begin_path()
    gui.path_rect(position - {feather, feather}, size + feather * 2.0)
    gui.path_rounded_rect(position, size, corner_radius, .Negative)
    gui.fill_path_paint(gui.box_gradient(
        {position.x, position.y + 2},
        size,
        corner_radius * 2.0,
        feather,
        {0, 0, 0, intensity},
        {0, 0, 0, 0},
    ))
}