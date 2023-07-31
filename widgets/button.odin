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

init_button :: proc(button: ^Button, position := Vec2{0, 0}, size := Vec2{96, 32}) {
    button.id = gui.generate_id(ctx)
    button.position = position
    button.size = size
}

draw_button :: proc(ctx: ^Context, button: ^Button) {
    draw_frame :: proc(ctx: ^Context, button: ^Button, color: Color) {
        gui.begin_path(ctx)
        gui.rounded_rect(ctx, button.position, button.size, 3)
        gui.fill_path(ctx, color)
    }

    gui.begin_path(ctx)
    gui.rounded_rect(ctx, button.position, button.size, 3)
    gui.fill_path(ctx, rgb(31, 32, 34))

    if button.is_down {
        gui.begin_path(ctx)
        gui.rounded_rect(ctx, button.position, button.size, 3)
        gui.fill_path(ctx, rgba(0, 0, 0, 8))

    } else if gui.is_hovered(ctx, button.id) {
        gui.begin_path(ctx)
        gui.rounded_rect(ctx, button.position, button.size, 3)
        gui.fill_path(ctx, rgba(255, 255, 255, 8))
    }
}

update_button_ex :: proc(ctx: ^Context, button: ^Button, hover, press, release: bool) {
    id := button.id

    button.pressed = false
    button.released = false
    button.clicked = false

    if gui.is_hovered(ctx, id) && !button.is_down && press {
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        button.is_down = false
        button.released = true

        if gui.mouse_is_over(ctx, id) {
            button.clicked = true
        }
    }

    if button.pressed {
        gui.capture_hover(ctx, id)
    }

    if button.released {
        gui.release_hover(ctx, id)
    }

    if hover {
        gui.request_hover(ctx, id)
    }
}

update_button :: proc(ctx: ^Context, button: ^Button, mouse_button := Mouse_Button.Left) {
    update_button_ex(ctx, button,
        hover = gui.mouse_hit_test(ctx, button.position, button.size),
        press = gui.mouse_pressed(ctx, mouse_button),
        release = gui.mouse_released(ctx, mouse_button),
    )
}