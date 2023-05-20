package gui

import vg "../vector_graphics"

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
    button.just_clicked = false
    button.was_down = button.is_down

    is_hovered := is_hovered(button)

    if is_hovered && mouse_pressed(button, button.mouse_button) {
        button.is_down = true
        capture_mouse(button)
    }

    if button.is_down && mouse_released(button, button.mouse_button) {
        button.is_down = false
        release_mouse_capture(button)
        if is_hovered {
            button.just_clicked = true
        }
    }

    update_children(button)
}

button_draw :: proc(button: ^Button) {
    ctx := get_vg_ctx(button)

    vg.set_color(ctx, {0.3, 0.3, 0.3, 1})
    vg.rect(ctx, {0, 0}, button.size)

    draw_children(button)

    if button.is_down {
        vg.set_color(ctx, {0, 0, 0, 0.05})
        vg.rect(ctx, {0, 0}, button.size)
    } else if is_hovered(button) {
        vg.set_color(ctx, {1, 1, 1, 0.1})
        vg.rect(ctx, {0, 0}, button.size)
    }
}

add_button :: proc(parent: ^Widget, mb := Mouse_Button.Left) -> ^Button {
    button := add_widget(parent, Button)
    button.size = {96, 32}
    button.mouse_button = mb
    button.update = proc(widget: ^Widget) { button_update(cast(^Button)widget) }
    button.draw = proc(widget: ^Widget) { button_draw(cast(^Button)widget) }
    button.consume_input = true
    button.clip_input = true
    button.clip_drawing = true
    return button
}