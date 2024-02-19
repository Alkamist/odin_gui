package widgets

import "../../gui"
import "../paths"

Slider :: struct {
    id: gui.Id,
    using rect: Rect,
    held: bool,
    value: f32,
    min_value: f32,
    max_value: f32,
    handle_length: f32,
    value_when_grabbed: f32,
    global_mouse_position_when_grabbed: Vec2,
    mouse_button: gui.Mouse_Button,
    precision_key: gui.Keyboard_Key,
}

slider_init :: proc(slider: ^Slider) {
    slider.id = gui.get_id()
    slider.size = Vec2{300, 24}
    slider.max_value = 1
    slider.handle_length = 16
    slider.mouse_button = .Left
    slider.precision_key = .Left_Shift
}

handle_rect :: proc(slider: ^Slider) -> Rect {
    return {
        slider.position + {
            (slider.size.x - slider.handle_length) * (slider.value - slider.min_value) / (slider.max_value - slider.min_value),
            0,
        },
        {
            slider.handle_length,
            slider.size.y,
        },
    }
}

set_value :: proc(slider: ^Slider, value: f32) {
    slider.value = value
    _clamp_slider_value(slider)
}

set_min_value :: proc(slider: ^Slider, min_value: f32) {
    slider.min_value = min_value
    _clamp_slider_value(slider)
}

set_max_value :: proc(slider: ^Slider, max_value: f32) {
    slider.max_value = max_value
    _clamp_slider_value(slider)
}

slider_update :: proc(slider: ^Slider) {
    if gui.mouse_hit_test(slider) {
        gui.request_mouse_hover(slider.id)
    }

    if slider.held {
        if gui.key_pressed(slider.precision_key) ||
           gui.key_released(slider.precision_key) {
            _reset_grab_info(slider)
        }
    }

    if !slider.held && gui.mouse_hover() == slider.id && gui.mouse_pressed(slider.mouse_button) {
        slider.held = true
        _reset_grab_info(slider)
        gui.capture_mouse_hover()
    }

    if slider.held {
        sensitivity: f32 = gui.key_down(slider.precision_key) ? 0.15 : 1.0
        global_mouse_position := gui.global_mouse_position()
        grab_delta := global_mouse_position.x - slider.global_mouse_position_when_grabbed.x
        slider.value = slider.value_when_grabbed + sensitivity * grab_delta * (slider.max_value - slider.min_value) / (slider.size.x - slider.handle_length)

        if gui.mouse_released(slider.mouse_button) {
            slider.held = false
            gui.release_mouse_hover()
        }
    }

    _clamp_slider_value(slider)
}

slider_draw :: proc(slider: ^Slider) {
    slider_path := gui.temp_path()
    paths.rect(&slider_path, slider)

    gui.fill_path(slider_path, {0.05, 0.05, 0.05, 1})

    handle_path := gui.temp_path()
    paths.rect(&handle_path, handle_rect(slider))

    gui.fill_path(handle_path, {0.4, 0.4, 0.4, 1})
    if slider.held {
        gui.fill_path(handle_path, {0, 0, 0, 0.2})
    } else if gui.mouse_hover() == slider.id {
        gui.fill_path(handle_path, {1, 1, 1, 0.05})
    }
}



_reset_grab_info :: proc(slider: ^Slider) {
    slider.value_when_grabbed = slider.value
    slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
}

_clamp_slider_value :: proc(slider: ^Slider) {
    slider.value = clamp(slider.value, slider.min_value, slider.max_value)
}