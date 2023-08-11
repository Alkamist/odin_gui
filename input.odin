package gui

import "core:time"
import "core:slice"
import "core:strings"
import backend "window"

Cursor_Style :: backend.Cursor_Style
Mouse_Button :: backend.Mouse_Button
Keyboard_Key :: backend.Keyboard_Key

delta_time_duration :: proc() -> time.Duration {
    window := _current_window
    return time.tick_diff(window.previous_tick, window.tick)
}

delta_time :: proc() -> f32 {
    window := _current_window
    return f32(time.duration_seconds(time.tick_diff(window.previous_tick, window.tick)))
}

mouse_position :: proc() -> Vec2 {
    return _current_window.global_mouse_position - get_offset()
}

global_mouse_position :: proc() -> Vec2 {
    return _current_window.global_mouse_position
}

root_mouse_position :: proc() -> Vec2 {
    return _current_window.root_mouse_position
}

mouse_delta :: proc() -> Vec2 {
    window := _current_window
    return window.root_mouse_position - window.previous_root_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return _current_window.mouse_down_states[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return _current_window.key_down_states[key]
}

mouse_wheel :: proc() -> Vec2 {
    return _current_window.mouse_wheel_state
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return _current_window.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button, ) -> bool {
    return slice.contains(_current_window.mouse_presses[:], button)
}

mouse_released :: proc(button: Mouse_Button, ) -> bool {
    return slice.contains(_current_window.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(_current_window.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(_current_window.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, ) -> bool {
    return slice.contains(_current_window.key_presses[:], key)
}

key_released :: proc(key: Keyboard_Key, ) -> bool {
    return slice.contains(_current_window.key_releases[:], key)
}

any_key_pressed :: proc() -> bool {
    return len(_current_window.key_presses) > 0
}

any_key_released :: proc() -> bool {
    return len(_current_window.key_releases) > 0
}

key_presses :: proc() -> []Keyboard_Key {
    return _current_window.key_presses[:]
}

key_releases :: proc() -> []Keyboard_Key {
    return _current_window.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(_current_window.text_input)
}