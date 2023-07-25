package gui

import "core:time"
import "core:slice"
import "core:strings"

input_content_scale :: proc(window: ^Window, scale: f32) {
    window.content_scale = scale
}

input_size :: proc(window: ^Window, size: [2]f32) {
    window.size = size
}

input_mouse_move :: proc(window: ^Window, position: [2]f32) {
    window.global_mouse_position = position
}

input_mouse_enter :: proc(window: ^Window, position: [2]f32) {
    window.is_hovered = true
}

input_mouse_exit :: proc(window: ^Window) {
    window.is_hovered = false
}

input_mouse_wheel :: proc(window: ^Window, amount: [2]f32) {
    window.mouse_wheel_state = amount
}

input_mouse_press :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down_states[button] = true
    append(&window.mouse_presses, button)
}

input_mouse_release :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down_states[button] = false
    append(&window.mouse_releases, button)
}

input_key_press :: proc(window: ^Window, key: Keyboard_Key) {
    window.key_down_states[key] = true
    append(&window.key_presses, key)
}

input_key_release :: proc(window: ^Window, key: Keyboard_Key) {
    window.key_down_states[key] = false
    append(&window.key_releases, key)
}

input_text :: proc(window: ^Window, text: string) {
    strings.write_string(&window.text_input, text)
}

is_hovered :: proc(window: ^Window) -> bool {
    return window.is_hovered
}

mouse_delta :: proc(window: ^Window) -> Vec2 {
    return window.global_mouse_position - window.previous_global_mouse_position
}

delta_time :: proc(window: ^Window) -> time.Duration {
    return time.tick_diff(window.tick, window.previous_tick)
}

mouse_down :: proc(window: ^Window, button: Mouse_Button) -> bool {
    return window.mouse_down_states[button]
}

key_down :: proc(window: ^Window, key: Keyboard_Key) -> bool {
    return window.key_down_states[key]
}

mouse_wheel :: proc(window: ^Window) -> Vec2 {
    return window.mouse_wheel_state
}

mouse_moved :: proc(window: ^Window) -> bool {
    return mouse_delta(window) != {0, 0}
}

mouse_wheel_moved :: proc(window: ^Window) -> bool {
    return window.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(window: ^Window, button: Mouse_Button) -> bool {
    return slice.contains(window.mouse_presses[:], button)
}

mouse_released :: proc(window: ^Window, button: Mouse_Button) -> bool {
    return slice.contains(window.mouse_releases[:], button)
}

any_mouse_pressed :: proc(window: ^Window) -> bool {
    return len(window.mouse_presses) > 0
}

any_mouse_released :: proc(window: ^Window) -> bool {
    return len(window.mouse_releases) > 0
}

key_pressed :: proc(window: ^Window, key: Keyboard_Key) -> bool {
    return slice.contains(window.key_presses[:], key)
}

key_released :: proc(window: ^Window, key: Keyboard_Key) -> bool {
    return slice.contains(window.key_releases[:], key)
}

any_key_pressed :: proc(window: ^Window) -> bool {
    return len(window.key_presses) > 0
}

any_key_released :: proc(window: ^Window) -> bool {
    return len(window.key_releases) > 0
}