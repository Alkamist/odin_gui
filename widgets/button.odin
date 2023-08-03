package widgets

import "../gui"

Button :: struct {
    id: Id,
    position: Vec2,
    size: Vec2,
    is_down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

create_button :: proc(position := Vec2{0, 0}, size := Vec2{96, 32}) -> ^Button {
    button := new(Button)
    button.id = gui.generate_id()
    button.position = position
    button.size = size
    return button
}

destroy_button :: proc(button: ^Button) {
    free(button)
}

draw_button :: proc(button: ^Button) {
    draw_frame :: proc(button: ^Button, color: Color) {
        gui.begin_path()
        gui.rounded_rect(button.position, button.size, 3)
        gui.fill_path(color)
    }

    gui.begin_path()
    gui.rounded_rect(button.position, button.size, 3)
    gui.fill_path(rgb(31, 32, 34))

    if button.is_down {
        gui.begin_path()
        gui.rounded_rect(button.position, button.size, 3)
        gui.fill_path(rgba(0, 0, 0, 8))

    } else if gui.is_hovered(button.id) {
        gui.begin_path()
        gui.rounded_rect(button.position, button.size, 3)
        gui.fill_path(rgba(255, 255, 255, 8))
    }
}

update_button_ex :: proc(button: ^Button, hover, press, release: bool) {
    id := button.id

    button.pressed = false
    button.released = false
    button.clicked = false

    if gui.is_hovered(id) && !button.is_down && press {
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        button.is_down = false
        button.released = true

        if gui.mouse_is_over(id) {
            button.clicked = true
        }
    }

    if button.pressed {
        gui.capture_hover(id)
    }

    if button.released {
        gui.release_hover(id)
    }

    if hover {
        gui.request_hover(id)
    }
}

update_button :: proc(button: ^Button, mouse_button := Mouse_Button.Left) {
    update_button_ex(button,
        hover = gui.mouse_hit_test(button.position, button.size),
        press = gui.mouse_pressed(mouse_button),
        release = gui.mouse_released(mouse_button),
    )
}