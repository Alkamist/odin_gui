package widgets

import "base:runtime"
import "../../gui"

Button_State :: struct {
    id: gui.Id,
    position: Vec2,
    size: Vec2,
    mouse_button: gui.Mouse_Button,
    down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

init_button_state :: proc(button: ^Button_State) {
    button.id = gui.get_id()
    button.mouse_button = .Left
}

update_button_state :: proc(button: ^Button_State) {
    button.pressed = false
    button.released = false
    button.clicked = false

    if gui.hit_test(button.position, button.size, gui.mouse_position()) {
        gui.request_mouse_hover(button.id)
    }

    if !button.down && gui.mouse_pressed(button.mouse_button) && gui.mouse_hover() == button.id {
        gui.capture_mouse_hover()
        button.down = true
        button.pressed = true
    }

    if button.down && gui.mouse_released(button.mouse_button) {
        gui.release_mouse_hover()
        button.down = false
        button.released = true
        if gui.mouse_hit() == button.id {
            button.down = false
            button.clicked = true
        }
    }
}

Button :: struct {
    using state: Button_State,
    color: Color,
}

init_button :: proc(button: ^Button) {
    init_button_state(button)
    button.size = {96, 32}
    button.color = {0.5, 0.5, 0.5, 1}
}

update_button :: proc(button: ^Button) {
    update_button_state(button)

    gui.draw_rect(button.position, button.size, button.color)
    if button.down {
        gui.draw_rect(button.position, button.size, {0, 0, 0, 0.2})
    } else if gui.mouse_hover() == button.id {
        gui.draw_rect(button.position, button.size, {1, 1, 1, 0.05})
    }
}