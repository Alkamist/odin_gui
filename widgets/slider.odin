package widgets

import "../../gui"

Slider :: struct {
    position: Vec2,
    size: Vec2,
    value: f32,
    min_value: f32,
    max_value: f32,
    handle_length: f32,
    handle: Button,
    value_when_handle_grabbed: f32,
    global_mouse_position_when_handle_grabbed: Vec2,
}

init_slider :: proc(
    slider: ^Slider,
    position := Vec2{0, 0},
    size := Vec2{300, 24},
    value: f32 = 0,
    min_value: f32 = 0,
    max_value: f32 = 1,
    handle_length: f32 = 16,
) -> ^Slider {
    slider.position = position
    slider.size = size
    slider.value = clamp(value, min_value, max_value)
    slider.min_value = min_value
    slider.max_value = max_value
    slider.handle_length = handle_length
    return slider
}

draw_slider :: proc(slider: ^Slider) {
    gui.begin_path()
    gui.path_rounded_rect(slider.position, slider.size, 3)
    gui.fill_path(gui.rgb(31, 32, 34))

    handle := &slider.handle
    handle_position := handle.position
    handle_size := handle.size

    gui.begin_path()
    gui.path_rounded_rect(handle_position, handle_size, 3)
    gui.fill_path(gui.lighten(gui.rgb(49, 51, 56), 0.3))

    if handle.is_down {
        gui.begin_path()
        gui.path_rounded_rect(handle_position, handle_size, 3)
        gui.fill_path(gui.rgba(0, 0, 0, 8))

    } else if gui.is_hovered(handle) {
        gui.begin_path()
        gui.path_rounded_rect(handle_position, handle_size, 3)
        gui.fill_path(gui.rgba(255, 255, 255, 8))
    }
}

update_slider :: proc(slider: ^Slider) {
    position := slider.position
    size := slider.size
    handle_length := slider.handle_length
    min_value := slider.min_value
    max_value := max(slider.max_value, min_value)
    value := clamp(slider.value, min_value, max_value)
    global_mouse_position := gui.global_mouse_position()

    handle := &slider.handle
    handle.position.x = position.x + (size.x - handle_length) * (value - min_value) / (max_value - min_value)
    handle.position.y = position.y
    handle.size = {handle_length, size.y}

    update_button(handle)

    if handle.pressed || gui.key_pressed(.Left_Control) || gui.key_released(.Left_Control) {
        slider.value_when_handle_grabbed = value
        slider.global_mouse_position_when_handle_grabbed = global_mouse_position
    }

    sensitivity: f32 = gui.key_down(.Left_Control) ? 0.15 : 1.0

    if handle.is_down {
        grab_delta := global_mouse_position.x - slider.global_mouse_position_when_handle_grabbed.x
        value = slider.value_when_handle_grabbed + sensitivity * grab_delta * (max_value - min_value) / (size.x - handle_length)
        slider.value = clamp(value, min_value, max_value)
    }
}