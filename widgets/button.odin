package widgets

import "../../gui"
import "../paths"

Button_Base :: struct {
    id: gui.Id,
    using rect: Rect,
    is_down: bool,
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

    if gui.mouse_hit_test(button) {
        gui.request_mouse_hover(button.id)
    }

    if !button.is_down && press && gui.mouse_hover() == button.id {
        gui.capture_mouse_hover()
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        gui.release_mouse_hover()
        button.is_down = false
        button.released = true
        if gui.mouse_hit() == button.id {
            button.is_down = false
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
    path := gui.temp_path()
    paths.rect(&path, button)

    gui.fill_path(path, button.color)
    if button.is_down {
        gui.fill_path(path, {0, 0, 0, 0.2})
    } else if gui.mouse_hover() == button.id {
        gui.fill_path(path, {1, 1, 1, 0.05})
    }
}