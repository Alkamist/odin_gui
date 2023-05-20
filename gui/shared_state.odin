package gui

import "core:slice"
import "core:strings"
import vg "../vector_graphics"

Mouse_Button :: enum {
    Unknown,
    Left, Middle, Right,
    Extra_1, Extra_2, Extra_3,
    Extra_4, Extra_5,
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
    Escape, Backslash, Semicolon, Quote,
    Comma, Period, Slash, Scroll_Lock,
    Pause, Insert, End, Page_Up, Delete,
    Home, Page_Down, Left_Arrow, Right_Arrow,
    Down_Arrow, Up_Arrow, Num_Lock, Pad_Divide,
    Pad_Multiply, Pad_Subtract, Pad_Add, Pad_Enter,
    Pad_Period, Print_Screen,
}

Shared_State :: struct {
    vg_ctx: ^vg.Context,
    hovers: [dynamic]^Widget,
    time: f32,
    time_previous: f32,
    mouse_capture: ^Widget,
    mouse_position: [2]f32,
    mouse_position_previous: [2]f32,
    mouse_wheel: [2]f32,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,
}

shared_state_create :: proc() -> ^Shared_State {
    state := new(Shared_State)
    reserve(&state.hovers, 16)
    reserve(&state.mouse_presses, 16)
    reserve(&state.mouse_releases, 16)
    reserve(&state.key_presses, 16)
    reserve(&state.key_releases, 16)
    strings.builder_init_none(&state.text_input)
    state.vg_ctx = vg.create()
    return state
}

shared_state_destroy :: proc(state: ^Shared_State) {
    delete(state.hovers)
    delete(state.mouse_presses)
    delete(state.mouse_releases)
    delete(state.key_presses)
    delete(state.key_releases)
    strings.builder_destroy(&state.text_input)
    vg.destroy(state.vg_ctx)
    free(state)
}

shared_state_update :: proc(state: ^Shared_State) {
    clear(&state.hovers)
    clear(&state.mouse_presses)
    clear(&state.mouse_releases)
    clear(&state.key_presses)
    clear(&state.key_releases)
    strings.builder_reset(&state.text_input)
    state.mouse_position_previous = state.mouse_position
    state.time_previous = state.time
}