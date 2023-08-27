package widgets

import "../../gui"

@(thread_local) _default_font: ^Font

Vec2 :: gui.Vec2
Rect :: gui.Rect
Color :: gui.Color
Mouse_Button :: gui.Mouse_Button
Keyboard_Key :: gui.Keyboard_Key

set_default_font :: proc(font: ^Font) {
    _default_font = font
}

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

fill_rect :: proc(position, size: Vec2, color: Color) {
    gui.begin_path()
    gui.path_rect(position, size)
    gui.fill_path(color)
}

outline_rect :: proc(position, size: Vec2, color: Color) {
    pixel := gui.pixel_distance()
    gui.begin_path()
    gui.path_rect(position + pixel * 0.5, size - pixel)
    gui.stroke_path(color, 1)
}

fill_circle :: proc(center: Vec2, radius: f32, color: Color) {
    gui.begin_path()
    gui.path_circle(center, radius)
    gui.fill_path(color)
}