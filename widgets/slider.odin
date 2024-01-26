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
    event_proc: proc(^gui.Widget, any) -> bool = slider_event_proc,
) {
    gui.init_widget(
        slider,
        position = position,
        size = size,
        event_proc = event_proc,
    )
    slider.handle_length = handle_length
    slider.min_value = min_value
    slider.max_value = max_value
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
        slider.position.x + (slider.size.x - slider.handle_length) * (slider.value - slider.min_value) / (slider.max_value - slider.min_value),
        slider.position.y,
    }
}

slider_handle_size :: proc(slider: ^Slider) -> Vec2 {
    return {slider.handle_length, slider.size.y}
}

slider_event_proc :: proc(widget: ^gui.Widget, event: any) -> bool {
    slider := cast(^Slider)widget

    switch e in event {
    case gui.Mouse_Enter_Event:
        gui.redraw()

    case gui.Mouse_Exit_Event:
        gui.redraw()

    case gui.Mouse_Press_Event:
        slider.is_grabbed = true
        slider.value_when_grabbed = slider.value
        slider.global_mouse_position_when_grabbed = gui.global_mouse_position()
        gui.capture_hover()
        gui.send_event(slider, Slider_Grab_Event{})
        gui.redraw()

    case gui.Mouse_Release_Event:
        slider.is_grabbed = false
        gui.release_hover()
        gui.send_event(slider, Slider_Release_Event{})
        gui.redraw()

    case gui.Mouse_Move_Event:
        if slider.is_grabbed {
            sensitivity :: 1.0
            global_mouse_position := gui.global_mouse_position()
            grab_delta := global_mouse_position.x - slider.global_mouse_position_when_grabbed.x
            set_slider_value(
                slider,
                slider.value_when_grabbed + sensitivity * grab_delta * (slider.max_value - slider.min_value) / (slider.size.x - slider.handle_length),
            )
            gui.redraw()
        }

    case gui.Draw_Event:
        gui.begin_path()
        gui.path_rounded_rect(slider.position, slider.size, 3)
        gui.fill_path(gui.rgb(31, 32, 34))

        handle_position := slider_handle_position(slider)
        handle_size := slider_handle_size(slider)

        gui.begin_path()
        gui.path_rounded_rect(handle_position, handle_size, 3)
        gui.fill_path(gui.lighten(gui.rgb(49, 51, 56), 0.3))
    }

    return false
}