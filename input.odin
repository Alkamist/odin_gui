package gui

import "core:time"
import "core:slice"
import "core:strings"

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

//==============================================================
//==============================================================

input_open :: proc(window: ^Window) {
    window.is_open = true
}

input_close :: proc(window: ^Window) {
    window.is_open = false
}

input_move :: proc(window: ^Window, position: Vec2) {
    window.position = position
}

input_resize :: proc(window: ^Window, size: Vec2) {
    window.size = size
}

input_mouse_enter :: proc(window: ^Window) {
    window.client_area_hovered = true
}

input_mouse_exit :: proc(window: ^Window) {
    window.client_area_hovered = false
}

input_mouse_move :: proc(window: ^Window, position: Vec2) {
    window.global_mouse_position = position
}

input_mouse_press :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = true

    tick_available := false
    previous_mouse_repeat_tick := window.mouse_repeat_tick
    window.mouse_repeat_tick, tick_available = _tick_now(window)

    if tick_available {
        delta := time.tick_diff(previous_mouse_repeat_tick, window.mouse_repeat_tick)
        if delta <= window.mouse_repeat_duration {
            window.mouse_repeat_count += 1
        } else {
            window.mouse_repeat_count = 1
        }

        // This is just a simple x, y comparison, not true distance.
        movement := window.global_mouse_position - window.mouse_repeat_start_position
        if abs(movement.x) > window.mouse_repeat_movement_tolerance ||
           abs(movement.y) > window.mouse_repeat_movement_tolerance {
            window.mouse_repeat_count = 1
        }
    }

    if window.mouse_repeat_count == 1 {
        window.mouse_repeat_start_position = window.global_mouse_position
    }

    append(&window.mouse_presses, button)
}

input_mouse_release :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = false
    append(&window.mouse_releases, button)
}

input_mouse_scroll :: proc(window: ^Window, amount: Vec2) {
    window.mouse_wheel = amount
}

input_key_press :: proc(window: ^Window, key: Keyboard_Key) {
    already_down := window.key_down[key]
    window.key_down[key] = true
    if !already_down {
        append(&window.key_presses, key)
    }
    append(&window.key_repeats, key)
}

input_key_release :: proc(window: ^Window, key: Keyboard_Key) {
    window.key_down[key] = false
    append(&window.key_releases, key)
}

input_text :: proc(window: ^Window, text: rune) {
    strings.write_rune(&window.text_input, text)
}

input_content_scale :: proc(window: ^Window, scale: Vec2) {
    window.content_scale = scale
}

//==============================================================
//==============================================================

tick :: proc() -> time.Tick {
    return _current_window.tick
}

delta_time_duration :: proc() -> time.Duration {
    return time.tick_diff(_current_window.previous_tick, _current_window.tick)
}

delta_time :: proc() -> f32 {
    return f32(time.duration_seconds(time.tick_diff(_current_window.previous_tick, _current_window.tick)))
}

mouse_position :: proc() -> Vec2 {
    return _current_window.global_mouse_position - position_offset()
}

global_mouse_position :: proc() -> Vec2 {
    return _current_window.global_mouse_position
}

mouse_delta :: proc() -> Vec2 {
    return _current_window.global_mouse_position - _current_window.previous_global_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return _current_window.mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return _current_window.key_down[key]
}

mouse_wheel :: proc() -> Vec2 {
    return _current_window.mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return _current_window.mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(_current_window.mouse_presses[:], button)
}

mouse_repeat_count :: proc() -> int {
    return _current_window.mouse_repeat_count
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(_current_window.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(_current_window.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(_current_window.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    return slice.contains(_current_window.key_presses[:], key) ||
           repeating && slice.contains(_current_window.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(_current_window.key_releases[:], key)
}

any_key_pressed :: proc() -> bool {
    return len(_current_window.key_presses) > 0
}

any_key_released :: proc() -> bool {
    return len(_current_window.key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return _current_window.key_repeats[:]
    } else {
        return _current_window.key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return _current_window.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(_current_window.text_input)
}

content_scale :: proc() -> Vec2 {
    return _current_window.content_scale
}

pixel_size :: proc() -> Vec2 {
    return 1.0 / _current_window.content_scale
}