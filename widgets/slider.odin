package widgets

import "../../gui"

Slider :: struct {
    using widget: gui.Widget,
    is_grabbed: bool,
    value: f32,
    min_value: f32,
    max_value: f32,
    handle_length: f32,
    value_when_grabbed: f32,
    global_mouse_position_when_grabbed: Vec2,
    mouse_button: gui.Mouse_Button,
    precision_key: gui.Keyboard_Key,
    response_proc: proc(slider: ^Slider, event: Slider_Event),
}

Slider_Event :: union {
    Slider_Grab_Event,
    Slider_Release_Event,
    Slider_Value_Change_Event,
}

Slider_Grab_Event :: struct {}
Slider_Release_Event :: struct {}
Slider_Value_Change_Event :: struct {
    value: f32,
    delta: f32,
}

init_slider :: proc(slider: ^Slider) -> ^Slider {
    slider.size = Vec2{300, 24}
    slider.max_value = 1
    slider.handle_length = 16
    slider.mouse_button = .Left
    slider.precision_key = .Left_Shift
    slider.event_proc = slider_event_proc
    return slider
}

set_slider_value :: proc(slider: ^Slider, value: f32) {
    previous_value := slider.value
    slider.value = clamp(value, slider.min_value, slider.max_value)
    if slider.value != previous_value {
        _slider_response(slider, Slider_Value_Change_Event{
            value = slider.value,
            delta = slider.value - previous_value,
        })
    }
}

set_slider_min_value :: proc(slider: ^Slider, min_value: f32) {
    slider.min_value = min_value
    slider.value = clamp(slider.value, slider.min_value, slider.max_value)
}

set_slider_max_value :: proc(slider: ^Slider, max_value: f32) {
    slider.max_value = max_value
    slider.value = clamp(slider.value, slider.min_value, slider.max_value)
}

slider_handle_position :: proc(slider: ^Slider) -> Vec2 {
    return {
        (slider.size.x - slider.handle_length) * (slider.value - slider.min_value) / (slider.max_value - slider.min_value),
        0,
    }
}

slider_handle_size :: proc(slider: ^Slider) -> Vec2 {
    return {slider.handle_length, slider.size.y}
}

slider_event_proc :: proc(widget: ^gui.Widget, event: gui.Event) {
    slider := cast(^Slider)widget

    #partial switch e in event {
    case gui.Window_Key_Press_Event:
        if slider.is_grabbed && e.key == slider.precision_key {
            slider.value_when_grabbed = slider.value
            slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
        }

    case gui.Window_Key_Release_Event:
        if slider.is_grabbed && e.key == slider.precision_key {
            slider.value_when_grabbed = slider.value
            slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
        }

    case gui.Mouse_Enter_Event: gui.redraw()
    case gui.Mouse_Exit_Event: gui.redraw()

    case gui.Mouse_Press_Event:
        if e.button == slider.mouse_button {
            slider.is_grabbed = true
            slider.value_when_grabbed = slider.value
            slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
            gui.capture_mouse_hover()
            _slider_response(slider, Slider_Grab_Event{})
            gui.redraw()
        }

    case gui.Mouse_Release_Event:
        if e.button == slider.mouse_button {
            slider.is_grabbed = false
            gui.release_mouse_hover()
            _slider_response(slider, Slider_Release_Event{})
            gui.redraw()
        }

    case gui.Mouse_Move_Event:
        if slider.is_grabbed {
            sensitivity: f32 = gui.key_down(slider.precision_key) ? 0.15 : 1.0
            global_mouse_position := gui.global_mouse_position()
            grab_delta := global_mouse_position.x - slider.global_mouse_position_when_grabbed.x
            set_slider_value(
                slider,
                slider.value_when_grabbed + sensitivity * grab_delta * (slider.max_value - slider.min_value) / (slider.size.x - slider.handle_length),
            )
            gui.redraw()
        }

    case gui.Draw_Event:
        gui.draw_rect({0, 0}, slider.size, {0.05, 0.05, 0.05, 1})

        handle_position := slider_handle_position(slider)
        handle_size := slider_handle_size(slider)

        gui.draw_rect(handle_position, handle_size, {0.4, 0.4, 0.4, 1})
        if slider.is_grabbed {
            gui.draw_rect(handle_position, handle_size, {0, 0, 0, 0.2})
        } else if gui.mouse_hover() == slider {
            gui.draw_rect(handle_position, handle_size, {1, 1, 1, 0.05})
        }
    }
}



_slider_response :: proc(slider: ^Slider, event: Slider_Event) {
    if slider.response_proc == nil do return
    slider->response_proc(event)
}