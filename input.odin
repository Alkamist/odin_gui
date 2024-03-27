package main

import "core:time"
import "core:slice"
import "core:strings"

Mouse_Cursor_Style :: enum {
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

set_mouse_cursor_style :: _set_mouse_cursor_style
get_clipboard :: _get_clipboard
set_clipboard :: _set_clipboard

mouse_position :: proc() -> (res: Vector2) {
    return current_window().global_mouse_position - global_offset()
}

mouse_delta :: proc() -> Vector2 {
    window := current_window()
    return window.global_mouse_position - window.previous_global_mouse_position
}

global_mouse_position :: proc() -> (res: Vector2) {
    return current_window().global_mouse_position
}

screen_mouse_position :: proc() -> Vector2 {
    return current_window().screen_mouse_position
}

screen_mouse_delta :: proc() -> Vector2 {
    window := current_window()
    return window.screen_mouse_position - window.previous_screen_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return current_window().mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return current_window().key_down[key]
}

mouse_wheel :: proc() -> Vector2 {
    return current_window().mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

screen_mouse_moved :: proc() -> bool {
    return screen_mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return current_window().mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(current_window().mouse_presses[:], button)
}

mouse_repeat_count :: proc(button: Mouse_Button) -> int {
    return current_window().mouse_repeat_counts[button]
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(current_window().mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(current_window().mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(current_window().mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    window := current_window()
    return slice.contains(window.key_presses[:], key) ||
           repeating && slice.contains(window.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(current_window().key_releases[:], key)
}

any_key_pressed :: proc(repeating := false) -> bool {
    if repeating {
        return len(current_window().key_repeats) > 0
    } else {
        return len(current_window().key_presses) > 0
    }
}

any_key_released :: proc() -> bool {
    return len(current_window().key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return current_window().key_repeats[:]
    } else {
        return current_window().key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return current_window().key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(current_window().text_input)
}

_input_mouse_move :: proc(window: ^Window, position: Vector2) {
    window.global_mouse_position = position
    window.screen_mouse_position = position + window_position(window)
}

_input_mouse_press :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = true
    previous_mouse_repeat_tick := window.mouse_repeat_ticks[button]

    window.mouse_repeat_ticks[button] = time.tick_now()

    delta := time.tick_diff(previous_mouse_repeat_tick, window.mouse_repeat_ticks[button])
    if delta <= 300 * time.Millisecond {
        window.mouse_repeat_counts[button] += 1
    } else {
        window.mouse_repeat_counts[button] = 1
    }

    TOLERANCE :: 3
    movement := mouse_position() - window.mouse_repeat_start_position
    if abs(movement.x) > TOLERANCE || abs(movement.y) > TOLERANCE {
        window.mouse_repeat_counts[button] = 1
    }

    if window.mouse_repeat_counts[button] == 1 {
        window.mouse_repeat_start_position = mouse_position()
    }

    append(&window.mouse_presses, button)
}

_input_mouse_release :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = false
    append(&window.mouse_releases, button)
}

_input_mouse_scroll :: proc(window: ^Window, amount: Vector2) {
    window.mouse_wheel = amount
}

_input_key_press :: proc(window: ^Window, key: Keyboard_Key) {
    already_down := window.key_down[key]
    window.key_down[key] = true
    if !already_down {
        append(&window.key_presses, key)
    }
    append(&window.key_repeats, key)
}

_input_key_release :: proc(window: ^Window, key: Keyboard_Key) {
    window.key_down[key] = false
    append(&window.key_releases, key)
}

_input_text :: proc(window: ^Window, text: rune) {
    strings.write_rune(&window.text_input, text)
}