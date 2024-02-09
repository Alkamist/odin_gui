package widgets

import "../../gui"

Button_Base :: struct {
    id: gui.Id,
    position: Vec2,
    size: Vec2,
    down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

button_base_init :: proc(button: ^Button_Base) {
    button.id = gui.get_id()
}

button_base_update :: proc(button: ^Button_Base, press, release: bool) {
    button.pressed = false
    button.released = false
    button.clicked = false

    if gui.hit_test(button.position, button.size, gui.mouse_position()) {
        gui.request_mouse_hover(button.id)
    }

    if !button.down && press && gui.mouse_hover() == button.id {
        gui.capture_mouse_hover()
        button.down = true
        button.pressed = true
    }

    if button.down && release {
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
    using base: Button_Base,
    mouse_button: gui.Mouse_Button,
    color: Color,
}

button_init :: proc(button: ^Button) {
    button_base_init(button)
    button.size = {96, 32}
    button.mouse_button = .Left
    button.color = {0.5, 0.5, 0.5, 1}
}

button_update :: proc(button: ^Button) {
    button_base_update(button,
        press = gui.mouse_pressed(button.mouse_button),
        release = gui.mouse_released(button.mouse_button),
    )
}

button_draw :: proc(button: ^Button) {
    gui.draw_rect(button.position, button.size, button.color)
    if button.down {
        gui.draw_rect(button.position, button.size, {0, 0, 0, 0.2})
    } else if gui.mouse_hover() == button.id {
        gui.draw_rect(button.position, button.size, {1, 1, 1, 0.05})
    }
}