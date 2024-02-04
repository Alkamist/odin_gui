package gui

import "core:time"

Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
    Scroll,
}

Mouse_Button :: enum {
    Unknown,
    Left, Middle, Right,
    Extra_1, Extra_2,
}

Keyboard_Key :: enum {
    Unknown,
    A, B, C, D, E, F, G, H, I,
    J, K, L, M, N, O, P, Q, R,
    S, T, U, V, W, X, Y, Z,
    Key_1, Key_2, Key_3, Key_4, Key_5,
    Key_6, Key_7, Key_8, Key_9, Key_0,
    Pad_1, Pad_2, Pad_3, Pad_4, Pad_5,
    Pad_6, Pad_7, Pad_8, Pad_9, Pad_0,
    F1, F2, F3, F4, F5, F6, F7,
    F8, F9, F10, F11, F12,
    Backtick, Minus, Equal, Backspace,
    Tab, Caps_Lock, Enter, Left_Shift,
    Right_Shift, Left_Control, Right_Control,
    Left_Alt, Right_Alt, Left_Meta, Right_Meta,
    Left_Bracket, Right_Bracket, Space,
    Escape, Backslash, Semicolon, Apostrophe,
    Comma, Period, Slash, Scroll_Lock,
    Pause, Insert, End, Page_Up, Delete,
    Home, Page_Down, Left_Arrow, Right_Arrow,
    Down_Arrow, Up_Arrow, Num_Lock, Pad_Divide,
    Pad_Multiply, Pad_Subtract, Pad_Add, Pad_Enter,
    Pad_Decimal, Print_Screen,
}

Mouse_State :: struct {
    position: Vec2,
    button_down: [Mouse_Button]bool,
}

Keyboard_State :: struct {
    key_down: [Keyboard_Key]bool,
}

Input_State :: struct {
    mouse: Mouse_State,
    keyboard: Keyboard_State,
}

input_open :: proc(root: ^Root) {
    send_global_event(root, Open_Event{})
}

input_close :: proc(root: ^Root) {
    send_global_event(root, Close_Event{})
}

input_update :: proc(root: ^Root) {
    send_global_event(root, Update_Event{})
    _recursive_update(root, Update_Event{})
}

input_resize :: proc(root: ^Root, size: Vec2) {
    if size == root.size {
        return
    }
    send_global_event(root, Resize_Event{
        size,
        size - root.size,
    })
    set_size(size, root)
}

input_mouse_enter :: proc(root: ^Root, position: Vec2) {
    send_global_event(root, Mouse_Enter_Event{
        position = position,
    })
}

input_mouse_exit :: proc(root: ^Root, position: Vec2) {
    send_global_event(root, Mouse_Exit_Event{
        position = position,
    })
}

input_mouse_move :: proc(root: ^Root, position: Vec2) {
    previous_mouse_position := root.input.mouse.position
    if position == previous_mouse_position {
        return
    }
    root.input.mouse.position = position
    send_global_event(root, Mouse_Move_Event{
        position = position,
        delta = position - previous_mouse_position,
    })
    _update_root_hover(root)
}

input_mouse_press :: proc(root: ^Root, position: Vec2, button: Mouse_Button) {
    root.input.mouse.button_down[button] = true

    tick_available := false
    previous_mouse_repeat_tick := root.mouse_repeat_tick
    root.mouse_repeat_tick, tick_available = get_tick(root)

    if tick_available {
        delta := time.tick_diff(previous_mouse_repeat_tick, root.mouse_repeat_tick)
        if delta <= root.mouse_repeat_duration {
            root.mouse_repeat_press_count += 1
        } else {
            root.mouse_repeat_press_count = 1
        }

        // This is just a simple x, y comparison, not true distance.
        movement := root.input.mouse.position - root.mouse_repeat_start_position
        if abs(movement.x) > root.mouse_repeat_movement_tolerance ||
           abs(movement.y) > root.mouse_repeat_movement_tolerance {
            root.mouse_repeat_press_count = 1
        }
    }

    if root.mouse_repeat_press_count == 1 {
        root.mouse_repeat_start_position = root.input.mouse.position
    }

    send_global_event(root, Mouse_Press_Event{
        position = position,
        button = button,
    })
    if root.hover != nil {
        send_event(root.hover, Mouse_Press_Event{
            position = mouse_position(root.hover),
            button = button,
        })
    }

    send_global_event(root, Mouse_Repeat_Event{
        position = position,
        button = button,
        press_count = root.mouse_repeat_press_count,
    })
    if root.hover != nil {
        send_event(root.hover, Mouse_Repeat_Event{
            position = mouse_position(root.hover),
            button = button,
            press_count = root.mouse_repeat_press_count,
        })
    }
}

input_mouse_release :: proc(root: ^Root, position: Vec2, button: Mouse_Button) {
    root.input.mouse.button_down[button] = false

    send_global_event(root, Mouse_Release_Event{
        position = position,
        button = button,
    })

    if root.hover != nil {
        send_event(root.hover, Mouse_Release_Event{
            position = mouse_position(root.hover),
            button = button,
        })
    }

    _update_root_hover(root)
}

input_mouse_scroll :: proc(root: ^Root, position: Vec2, amount: Vec2) {
    send_global_event(root, Mouse_Scroll_Event{
        position = position,
        amount = amount,
    })

    if root.hover != nil {
        send_event(root.hover, Mouse_Scroll_Event{
            position = position,
            amount = amount,
        })
    }
}

input_key_press :: proc(root: ^Root, key: Keyboard_Key) {
    already_down := root.input.keyboard.key_down[key]
    root.input.keyboard.key_down[key] = true

    if already_down {
        send_global_event(root, Key_Repeat_Event{
            key = key,
        })

        if root.focus != nil {
            send_event(root.focus, Key_Repeat_Event{
                key = key,
            })
        }
    } else {
        send_global_event(root, Key_Press_Event{
            key = key,
        })

        if root.focus != nil {
            send_event(root.focus, Key_Press_Event{
                key = key,
            })
        }
    }
}

input_key_release :: proc(root: ^Root, key: Keyboard_Key) {
    root.input.keyboard.key_down[key] = false

    send_global_event(root, Key_Release_Event{
        key = key,
    })

    if root.focus != nil {
        send_event(root.focus, Key_Release_Event{
            key = key,
        })
    }
}

input_text :: proc(root: ^Root, text: rune) {
    send_global_event(root, Text_Event{
        text = text,
    })

    if root.focus != nil {
        send_event(root.focus, Text_Event{
            text = text,
        })
    }
}

input_content_scale :: proc(root: ^Root, scale: Vec2) {
    previous_content_scale := root.content_scale
    if scale != previous_content_scale {
        root.content_scale = scale
        send_global_event(root, Content_Scale_Event{
            scale = scale,
            delta = scale - previous_content_scale,
        })
    }
}



_update_root_hover :: proc(root: ^Root) {
    previous_hover := root.hover
    root.mouse_hit = _recursive_hit_test(root, root.input.mouse.position)

    if !root.hover_captured {
        root.hover = root.mouse_hit
    }

    if root.hover != nil {
        previous_mouse_position := root.hover.cached_relative_mouse_position
        mp := mouse_position(root.hover)
        if mp != previous_mouse_position {
            root.hover.cached_relative_mouse_position = mp
            send_event(root.hover, Mouse_Move_Event{
                position = mp,
                delta = mp - previous_mouse_position,
            })
        }
    }

    if root.hover != previous_hover {
        if previous_hover != nil {
            send_event(previous_hover, Mouse_Exit_Event{
                position = mouse_position(previous_hover),
            })
        }
        if root.hover != nil {
            send_event(root.hover, Mouse_Enter_Event{
                position = mouse_position(root.hover),
            })
        }
    }
}