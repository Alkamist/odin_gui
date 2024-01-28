package widgets

import "../../gui"

Button :: struct {
    using widget: gui.Widget,
    color: Color,
    mouse_button: gui.Mouse_Button,
    is_down: bool,
}

Button_Press_Event :: struct {}
Button_Release_Event :: struct {}
Button_Click_Event :: struct {}

init_button :: proc(
    button: ^Button,
    position := Vec2{0, 0},
    size := Vec2{96, 32},
    color := Color{0.5, 0.5, 0.5, 1},
    mouse_button := gui.Mouse_Button.Left,
    event_proc: proc(^gui.Widget, any) = button_event_proc,
) {
    gui.init_widget(
        button,
        position = position,
        size = size,
        event_proc = event_proc,
    )
    button.color = color
    button.mouse_button = mouse_button
}

destroy_button :: proc(button: ^Button) {
    gui.destroy_widget(button)
}

button_event_proc :: proc(widget: ^gui.Widget, event: any) {
    button := cast(^Button)widget

    switch e in event {
    case gui.Open_Event:
        gui.redraw()

    case gui.Mouse_Enter_Event:
        gui.redraw()

    case gui.Mouse_Exit_Event:
        gui.redraw()

    case gui.Mouse_Press_Event:
        if e.button == button.mouse_button {
            button.is_down = true
            gui.capture_hover()
            gui.send_event(button, Button_Press_Event{})
        }
        gui.redraw()

    case gui.Mouse_Release_Event:
        if e.button == button.mouse_button {
            gui.release_hover()
            if button.is_down && gui.current_mouse_hit() == button {
                button.is_down = false
                gui.send_event(button, Button_Click_Event{})
            }
            button.is_down = false
            gui.send_event(button, Button_Release_Event{})
        }
        gui.redraw()

    case gui.Draw_Event:
        gui.draw_rect({0, 0}, button.size, {0.4, 0.4, 0.4, 1})
        if button.is_down {
            gui.draw_rect({0, 0}, button.size, {0, 0, 0, 0.2})
        } else if gui.current_hover() == button {
            gui.draw_rect({0, 0}, button.size, {1, 1, 1, 0.05})
        }
    }
}