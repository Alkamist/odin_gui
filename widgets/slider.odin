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
}

Slider_Grab_Event :: struct {}
Slider_Release_Event :: struct {}

Slider_Value_Change_Event :: struct {
    value: f32,
    delta: f32,
}

init_slider :: proc(
    slider: ^Slider,
    position := Vec2{0, 0},
    size := Vec2{300, 24},
    value: f32 = 0,
    min_value: f32 = 0,
    max_value: f32 = 1,
    handle_length: f32 = 16,
    mouse_button := gui.Mouse_Button.Left,
    event_proc: proc(^gui.Widget, ^gui.Widget, any) = slider_event_proc,
) {
    gui.init_widget(
        slider,
        position = position,
        size = size,
        event_proc = event_proc,
    )
    slider.precision_key = .Left_Shift
    slider.handle_length = handle_length
    slider.min_value = min_value
    slider.max_value = max_value
    slider.mouse_button = mouse_button
    set_slider_value(slider, value)
}

destroy_slider :: proc(slider: ^Slider) {
    gui.destroy_widget(slider)
}

set_slider_value :: proc(slider: ^Slider, value: f32) {
    previous_value := slider.value
    slider.value = clamp(value, slider.min_value, slider.max_value)
    if slider.value != previous_value {
        gui.send_event(slider, Slider_Value_Change_Event{
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

slider_event_proc :: proc(widget, subject: ^gui.Widget, event: any) {
    slider := cast(^Slider)widget

    switch subject {
    case nil:
        switch e in event {
        case gui.Open_Event: gui.redraw()
        case gui.Resize_Event: gui.redraw()

        case gui.Key_Press_Event:
            if slider.is_grabbed && e.key == slider.precision_key {
                slider.value_when_grabbed = slider.value
                slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
            }

        case gui.Key_Release_Event:
            if slider.is_grabbed && e.key == slider.precision_key {
                slider.value_when_grabbed = slider.value
                slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
            }
        }

    case widget:
        switch e in event {
        case gui.Mouse_Enter_Event: gui.redraw()
        case gui.Mouse_Exit_Event: gui.redraw()

        case gui.Mouse_Press_Event:
            if e.button == slider.mouse_button {
                slider.is_grabbed = true
                slider.value_when_grabbed = slider.value
                slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
                gui.capture_hover()
                gui.send_event(slider, Slider_Grab_Event{})
                gui.redraw()
            }

        case gui.Mouse_Release_Event:
            if e.button == slider.mouse_button {
                slider.is_grabbed = false
                gui.release_hover()
                gui.send_event(slider, Slider_Release_Event{})
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
            } else if gui.current_hover() == slider {
                gui.draw_rect(handle_position, handle_size, {1, 1, 1, 0.05})
            }
        }
    }
}