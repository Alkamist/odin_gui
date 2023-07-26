package gui

import "core:time"
import "core:slice"
import "core:strings"

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

input_content_scale :: proc(ctx: ^Context, scale: f32) {
    ctx.content_scale = scale
}

input_size :: proc(ctx: ^Context, size: [2]f32) {
    ctx.size = size
}

input_mouse_move :: proc(ctx: ^Context, position: [2]f32) {
    ctx.global_mouse_position = position
}

input_mouse_enter :: proc(ctx: ^Context) {
    ctx.is_hovered = true
}

input_mouse_exit :: proc(ctx: ^Context) {
    ctx.is_hovered = false
}

input_mouse_wheel :: proc(ctx: ^Context, amount: [2]f32) {
    ctx.mouse_wheel_state = amount
}

input_mouse_press :: proc(ctx: ^Context, button: Mouse_Button) {
    ctx.mouse_down_states[button] = true
    append(&ctx.mouse_presses, button)
}

input_mouse_release :: proc(ctx: ^Context, button: Mouse_Button) {
    ctx.mouse_down_states[button] = false
    append(&ctx.mouse_releases, button)
}

input_key_press :: proc(ctx: ^Context, key: Keyboard_Key) {
    ctx.key_down_states[key] = true
    append(&ctx.key_presses, key)
}

input_key_release :: proc(ctx: ^Context, key: Keyboard_Key) {
    ctx.key_down_states[key] = false
    append(&ctx.key_releases, key)
}

input_rune :: proc(ctx: ^Context, r: rune) {
    strings.write_rune(&ctx.text_input, r)
}

is_hovered :: proc(ctx: ^Context) -> bool {
    return ctx.is_hovered
}

mouse_delta :: proc(ctx: ^Context) -> Vec2 {
    return ctx.global_mouse_position - ctx.previous_global_mouse_position
}

delta_time :: proc(ctx: ^Context) -> time.Duration {
    return time.tick_diff(ctx.previous_tick, ctx.tick)
}

mouse_down :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
    return ctx.mouse_down_states[button]
}

key_down :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
    return ctx.key_down_states[key]
}

mouse_wheel :: proc(ctx: ^Context) -> Vec2 {
    return ctx.mouse_wheel_state
}

mouse_moved :: proc(ctx: ^Context) -> bool {
    return mouse_delta(ctx) != {0, 0}
}

mouse_wheel_moved :: proc(ctx: ^Context) -> bool {
    return ctx.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
    return slice.contains(ctx.mouse_presses[:], button)
}

mouse_released :: proc(ctx: ^Context, button: Mouse_Button) -> bool {
    return slice.contains(ctx.mouse_releases[:], button)
}

any_mouse_pressed :: proc(ctx: ^Context) -> bool {
    return len(ctx.mouse_presses) > 0
}

any_mouse_released :: proc(ctx: ^Context) -> bool {
    return len(ctx.mouse_releases) > 0
}

key_pressed :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
    return slice.contains(ctx.key_presses[:], key)
}

key_released :: proc(ctx: ^Context, key: Keyboard_Key) -> bool {
    return slice.contains(ctx.key_releases[:], key)
}

any_key_pressed :: proc(ctx: ^Context) -> bool {
    return len(ctx.key_presses) > 0
}

any_key_released :: proc(ctx: ^Context) -> bool {
    return len(ctx.key_releases) > 0
}

key_presses :: proc(ctx: ^Context) -> []Keyboard_Key {
    return ctx.key_presses[:]
}

key_releases :: proc(ctx: ^Context) -> []Keyboard_Key {
    return ctx.key_releases[:]
}

text_input :: proc(ctx: ^Context) -> string {
    return strings.to_string(ctx.text_input)
}