package widgets

import "../../gui"

Button :: struct {
    using widget: gui.Widget,
    color: Color,
    mouse_button: gui.Mouse_Button,
    is_down: bool,
}

Button_Pressed_Event :: struct {}
Button_Released_Event :: struct {}
Button_Clicked_Event :: struct {}

create_button :: proc(
    position := Vec2{0, 0},
    size := Vec2{96, 32},
    color := Color{0.5, 0.5, 0.5, 1},
    mouse_button := gui.Mouse_Button.Left,
) -> ^Button {
    button := gui.create_widget(Button)
    button.event_proc = button_event_proc
    button.position = position
    button.size = size
    button.color = color
    button.mouse_button = mouse_button
    return button
}

destroy_button :: proc(button: ^Button) {
    gui.destroy_widget(button)
}

button_event_proc :: proc(widget: ^gui.Widget, event: any) -> bool {
    button := cast(^Button)widget

    switch e in event {
    case gui.Mouse_Pressed_Event:
        if e.button == button.mouse_button {
            button.is_down = true
            gui.capture_hover()
            gui.send_event(button, Button_Pressed_Event{})
        }

    case gui.Mouse_Released_Event:
        if e.button == button.mouse_button {
            gui.release_hover()
            if button.is_down && gui.current_mouse_hit() == button {
                button.is_down = false
                gui.send_event(button, Button_Clicked_Event{})
            }
            button.is_down = false
            gui.send_event(button, Button_Released_Event{})
        }

    case gui.Draw_Event:
        gui.begin_path()
        gui.path_rect(button.position, button.size)
        gui.fill_path(button.color)
    }

    return false
}