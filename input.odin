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

input_window_move :: proc(window: ^Window, position: Vector2) {
    window.actual_rectangle.position = position
    window.position = position
}

input_window_size :: proc(window: ^Window, size: Vector2) {
    window.actual_rectangle.size = size
    window.size = size
}

input_window_mouse_enter :: proc(window: ^Window) {
    window.is_mouse_hovered = true
}

input_window_mouse_exit :: proc(window: ^Window) {
    window.is_mouse_hovered = false
}

input_window_content_scale :: proc(window: ^Window, content_scale: Vector2) {
    window.content_scale = content_scale
}

input_mouse_move :: proc(ctx: ^Gui_Context, screen_position: Vector2) {
    ctx.screen_mouse_position = screen_position
}

input_mouse_press :: proc(ctx: ^Gui_Context, button: Mouse_Button) {
    ctx.mouse_down[button] = true
    previous_mouse_repeat_tick := ctx.mouse_repeat_ticks[button]

    ctx.mouse_repeat_ticks[button] = time.tick_now()

    delta := time.tick_diff(previous_mouse_repeat_tick, ctx.mouse_repeat_ticks[button])
    if delta <= 300 * time.Millisecond {
        ctx.mouse_repeat_counts[button] += 1
    } else {
        ctx.mouse_repeat_counts[button] = 1
    }

    TOLERANCE :: 3
    movement := ctx.screen_mouse_position - ctx.mouse_repeat_start_position
    if abs(movement.x) > TOLERANCE || abs(movement.y) > TOLERANCE {
        ctx.mouse_repeat_counts[button] = 1
    }

    if ctx.mouse_repeat_counts[button] == 1 {
        ctx.mouse_repeat_start_position = ctx.screen_mouse_position
    }

    append(&ctx.mouse_presses, button)
}

input_mouse_release :: proc(ctx: ^Gui_Context, button: Mouse_Button) {
    ctx.mouse_down[button] = false
    append(&ctx.mouse_releases, button)
}

input_mouse_scroll :: proc(ctx: ^Gui_Context, amount: Vector2) {
    ctx.mouse_wheel = amount
}

input_key_press :: proc(ctx: ^Gui_Context, key: Keyboard_Key) {
    already_down := ctx.key_down[key]
    ctx.key_down[key] = true
    if !already_down {
        append(&ctx.key_presses, key)
    }
    append(&ctx.key_repeats, key)
}

input_key_release :: proc(ctx: ^Gui_Context, key: Keyboard_Key) {
    ctx.key_down[key] = false
    append(&ctx.key_releases, key)
}

input_text :: proc(ctx: ^Gui_Context, text: rune) {
    strings.write_rune(&ctx.text_input, text)
}

mouse_position :: proc() -> (res: Vector2) {
    ctx := gui_context()
    res = ctx.screen_mouse_position - global_offset()
    if window := current_window(); window != nil {
        res -= window.position
    }
    return
}

global_mouse_position :: proc() -> (res: Vector2) {
    ctx := gui_context()
    res = ctx.screen_mouse_position
    if window := current_window(); window != nil {
        res -= window.position
    }
    return
}

screen_mouse_position :: proc() -> Vector2 {
    ctx := gui_context()
    return ctx.screen_mouse_position
}

mouse_delta :: proc() -> Vector2 {
    ctx := gui_context()
    return ctx.screen_mouse_position - ctx.previous_screen_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return gui_context().mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return gui_context().key_down[key]
}

mouse_wheel :: proc() -> Vector2 {
    return gui_context().mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return gui_context().mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(gui_context().mouse_presses[:], button)
}

mouse_repeat_count :: proc(button: Mouse_Button) -> int {
    return gui_context().mouse_repeat_counts[button]
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(gui_context().mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(gui_context().mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(gui_context().mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    ctx := gui_context()
    return slice.contains(ctx.key_presses[:], key) ||
           repeating && slice.contains(ctx.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(gui_context().key_releases[:], key)
}

any_key_pressed :: proc(repeating := false) -> bool {
    if repeating {
        return len(gui_context().key_repeats) > 0
    } else {
        return len(gui_context().key_presses) > 0
    }
}

any_key_released :: proc() -> bool {
    return len(gui_context().key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return gui_context().key_repeats[:]
    } else {
        return gui_context().key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return gui_context().key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(gui_context().text_input)
}