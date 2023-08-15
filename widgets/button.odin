package widgets

import "../../gui"
import "../../gui/color"

Button :: struct {
    using widget: gui.Widget,
    position: Vec2,
    size: Vec2,
    is_down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

DEFAULT_BUTTON :: Button{
    position = {0, 0},
    size = {96, 32},
}

draw_button :: proc(button: ^Button) {
    position := button.position
    size := button.size

    gui.begin_path()
    gui.path_rounded_rect(position, size, 3)
    gui.fill_path(color.rgb(31, 32, 34))

    if button.is_down {
        gui.begin_path()
        gui.path_rounded_rect(position, size, 3)
        gui.fill_path(color.rgba(0, 0, 0, 8))

    } else if gui.is_hovered(button) {
        gui.begin_path()
        gui.path_rounded_rect(position, size, 3)
        gui.fill_path(color.rgba(255, 255, 255, 8))
    }
}

update_button_ex :: proc(button: ^Button, hover, press, release: bool) {
    button.pressed = false
    button.released = false
    button.clicked = false

    if gui.is_hovered(button) && !button.is_down && press {
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        button.is_down = false
        button.released = true

        if gui.mouse_is_over(button) {
            button.clicked = true
        }
    }

    if button.pressed {
        gui.capture_hover(button)
    }

    if button.released {
        gui.release_hover(button)
    }

    if hover {
        gui.request_hover(button)
    }
}

update_button :: proc(button: ^Button, mouse_button := Mouse_Button.Left) {
    update_button_ex(
        button,
        hover = gui.mouse_hit_test(button.position, button.size),
        press = gui.mouse_pressed(mouse_button),
        release = gui.mouse_released(mouse_button),
    )
}