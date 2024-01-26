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

init_button :: proc(
    button: ^Button,
    position := Vec2{0, 0},
    size := Vec2{96, 32},
    color := Color{0.5, 0.5, 0.5, 1},
    mouse_button := gui.Mouse_Button.Left,
    event_proc: proc(^gui.Widget, any) -> bool = button_event_proc,
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

button_event_proc :: proc(widget: ^gui.Widget, event: any) -> bool {
    button := cast(^Button)widget

    switch e in event {
    case gui.Mouse_Entered_Event:
        gui.redraw()

    case gui.Mouse_Exited_Event:
        gui.redraw()

    case gui.Mouse_Pressed_Event:
        if e.button == button.mouse_button {
            button.is_down = true
            gui.capture_hover()
            gui.send_event(button, Button_Pressed_Event{})
        }
        gui.redraw()

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
        gui.redraw()

    case gui.Draw_Event:
        pixel := gui.pixel_distance()

        // Shadow
        drop_shadow(button.position, button.size, 4, 2, 0.2)

        // Body
        fill_rounded_rect(button.position, button.size, 4, button.color)
        outline_rounded_rect(button.position, button.size, 4, {0, 0, 0, 0.4})
        outline_rounded_rect(button.position + pixel, button.size - pixel * 2.0, 4, {1, 1, 1, 0.1})

        // Gradient
        gui.begin_path()
        gui.path_rounded_rect(button.position, button.size, 4)
        gui.fill_path_paint(gui.linear_gradient(
            button.position + {0, button.size.y},
            button.position,
            {0, 0, 0, 0.2},
            {0, 0, 0, 0},
        ))

        // Hover and press highlights
        if button.is_down {
            fill_rounded_rect(button.position, button.size, 4, {0, 0, 0, 0.15})
        } else if gui.current_hover() == button {
            fill_rounded_rect(button.position, button.size, 4, {1, 1, 1, 0.025})
        }
    }

    return false
}