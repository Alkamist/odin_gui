package gui

Button :: struct {
    using widget: Widget,
    is_down: bool,
    was_down: bool,
    just_clicked: bool,
    mouse_button: Mouse_Button,
}

button_down :: proc(button: Button) -> bool {
    return button.is_down
}
button_pressed :: proc(button: Button) -> bool {
    return button.is_down && !button.was_down
}
button_released :: proc(button: Button) -> bool {
    return button.was_down && !button.is_down
}
button_clicked :: proc(button: Button) -> bool {
    return button.just_clicked
}

button_update :: proc(button: ^Button) {
    ctx := button.ctx

    button.just_clicked = false
    button.was_down = button.is_down

    if button.is_hovered && mouse_pressed(ctx, button.mouse_button) {
        button.is_down = true
        ctx.mouse_capture = button
    }

    if button.is_down && mouse_released(ctx, button.mouse_button) {
        button.is_down = false
        ctx.mouse_capture = nil
        if button.is_hovered {
            button.just_clicked = true
        }
    }

    update_children(button)
}

// button_draw :: proc(button: ^Button) {
//     vg := button.ctx.vg

//     vg.begin_path()
//     vg.rect([0, 0], button.size)
//     vg.set_fill_color(30, 30, 30, 255)
//     vg.fill()

//     button.drawChildren()

//     if button.is_down {
//         vg.begin_path()
//         vg.rect([0, 0], button.size)
//         vg.set_fill_color(0, 0, 0, 8)
//         vg.fill()
//     } else if button.is_hovered {
//         vg.begin_path()
//         vg.rect([0, 0], button.size)
//         vg.set_fill_color(255, 255, 255, 8)
//         vg.fill()
//     }
// }

add_button :: proc(parent: ^Widget, mb := Mouse_Button.Left) -> ^Button {
    button := add_widget(parent, Button)
    button.size = {96, 32}
    button.mouse_button = mb
    button.update = proc(widget: ^Widget) { button_update(cast(^Button)widget) }
    // button.draw = proc(widget: ^Widget) { button_draw(cast(^Button)widget) }
    button.eat_input = true
    button.clip_input = true
    button.clip_drawing = true
    return button
}