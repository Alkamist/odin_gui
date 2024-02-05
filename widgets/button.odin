package widgets

import "base:runtime"
import "../../gui"

Button :: struct {
    using widget: gui.Widget,
    color: Color,
    mouse_button: gui.Mouse_Button,
    is_down: bool,
    response_proc: proc(button: ^Button, event: Button_Event),
}

Button_Event :: union {
    Button_Press_Event,
    Button_Release_Event,
    Button_Click_Event,
}

Button_Press_Event :: struct {}
Button_Release_Event :: struct {}
Button_Click_Event :: struct {}

init_button :: proc(button: ^Button) -> ^Button {
    button.position = Vec2{0, 0}
    button.size = Vec2{96, 32}
    button.color = Color{0.5, 0.5, 0.5, 1}
    button.mouse_button = gui.Mouse_Button.Left
    button.event_proc = button_event_proc
    return button
}

button_event_proc :: proc(widget: ^gui.Widget, event: gui.Event) {
    button := cast(^Button)widget

    #partial switch e in event {
    case gui.Resize_Event, gui.Mouse_Enter_Event, gui.Mouse_Exit_Event:
        gui.redraw()

    case gui.Mouse_Press_Event:
        if e.button == button.mouse_button {
            button.is_down = true
            gui.capture_mouse_hover()
            _button_response(button, Button_Press_Event{})
        }
        gui.redraw()

    case gui.Mouse_Release_Event:
        if e.button == button.mouse_button {
            gui.release_mouse_hover()
            if button.is_down && gui.mouse_hit() == button {
                button.is_down = false
                _button_response(button, Button_Click_Event{})
            }
            button.is_down = false
            _button_response(button, Button_Release_Event{})
        }
        gui.redraw()

    case gui.Draw_Event:
        gui.draw_rect({0, 0}, button.size, {0.4, 0.4, 0.4, 1})
        if button.is_down {
            gui.draw_rect({0, 0}, button.size, {0, 0, 0, 0.2})
        } else if gui.mouse_hover() == button {
            gui.draw_rect({0, 0}, button.size, {1, 1, 1, 0.05})
        }
    }
}



_button_response :: proc(button: ^Button, event: Button_Event) {
    if button.response_proc == nil do return
    button->response_proc(event)
}