package gui

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

input_window_move :: proc(window: ^Window, position: Vec2) {
    window.position = position
}

input_window_size :: proc(window: ^Window, size: Vec2) {
    window.size = size
}

input_mouse_move :: proc(position: Vec2) {
    ctx.global_mouse_position = position
}

input_mouse_press :: proc(button: Mouse_Button) {
    ctx.mouse_down[button] = true

    tick_available := false
    previous_mouse_repeat_tick := ctx.mouse_repeat_tick
    ctx.mouse_repeat_tick, tick_available = tick_now()

    if tick_available {
        delta := time.tick_diff(previous_mouse_repeat_tick, ctx.mouse_repeat_tick)
        if delta <= ctx.mouse_repeat_duration {
            ctx.mouse_repeat_count += 1
        } else {
            ctx.mouse_repeat_count = 1
        }

        // This is just a simple x, y comparison, not true distance.
        movement := ctx.global_mouse_position - ctx.mouse_repeat_start_position
        if abs(movement.x) > ctx.mouse_repeat_movement_tolerance ||
           abs(movement.y) > ctx.mouse_repeat_movement_tolerance {
            ctx.mouse_repeat_count = 1
        }
    }

    if ctx.mouse_repeat_count == 1 {
        ctx.mouse_repeat_start_position = ctx.global_mouse_position
    }

    append(&ctx.mouse_presses, button)
}

input_mouse_release :: proc(button: Mouse_Button) {
    ctx.mouse_down[button] = false
    append(&ctx.mouse_releases, button)
}

input_mouse_scroll :: proc(amount: Vec2) {
    ctx.mouse_wheel = amount
}

input_key_press :: proc(key: Keyboard_Key) {
    already_down := ctx.key_down[key]
    ctx.key_down[key] = true
    if !already_down {
        append(&ctx.key_presses, key)
    }
    append(&ctx.key_repeats, key)
}

input_key_release :: proc(key: Keyboard_Key) {
    ctx.key_down[key] = false
    append(&ctx.key_releases, key)
}

input_text :: proc(text: rune) {
    strings.write_rune(&ctx.text_input, text)
}



tick :: proc() -> time.Tick {
    return ctx.tick
}

delta_time_duration :: proc() -> time.Duration {
    return time.tick_diff(ctx.previous_tick, ctx.tick)
}

delta_time :: proc() -> f32 {
    return f32(time.duration_seconds(time.tick_diff(ctx.previous_tick, ctx.tick)))
}

mouse_position :: proc() -> (res: Vec2) {
    res = ctx.global_mouse_position - offset()
    if window := current_window(); window != nil {
        res -= window.position
    }
    return
}

window_mouse_position :: proc() -> (res: Vec2) {
    res = ctx.global_mouse_position
    if window := current_window(); window != nil {
        res -= window.position
    }
    return
}

global_mouse_position :: proc() -> Vec2 {
    return ctx.global_mouse_position
}

mouse_delta :: proc() -> Vec2 {
    return ctx.global_mouse_position - ctx.previous_global_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return ctx.mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return ctx.key_down[key]
}

mouse_wheel :: proc() -> Vec2 {
    return ctx.mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return ctx.mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(ctx.mouse_presses[:], button)
}

mouse_repeat_count :: proc() -> int {
    return ctx.mouse_repeat_count
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(ctx.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(ctx.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(ctx.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    return slice.contains(ctx.key_presses[:], key) ||
           repeating && slice.contains(ctx.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(ctx.key_releases[:], key)
}

any_key_pressed :: proc(repeating := false) -> bool {
    if repeating {
        return len(ctx.key_repeats) > 0
    } else {
        return len(ctx.key_presses) > 0
    }
}

any_key_released :: proc() -> bool {
    return len(ctx.key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return ctx.key_repeats[:]
    } else {
        return ctx.key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return ctx.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(ctx.text_input)
}