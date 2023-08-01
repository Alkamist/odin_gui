package gui

import "core:slice"
import "core:strings"
import backend "window"

Cursor_Style :: backend.Cursor_Style
Mouse_Button :: backend.Mouse_Button
Keyboard_Key :: backend.Keyboard_Key

mouse_position :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.mouse_position
}

global_mouse_position :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.global_mouse_position
}

mouse_delta :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.global_mouse_position - w.previous_global_mouse_position
}

mouse_down :: proc(button: Mouse_Button, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.mouse_down_states[button]
}

key_down :: proc(key: Keyboard_Key, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.key_down_states[key]
}

mouse_wheel :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.mouse_wheel_state
}

mouse_moved :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return mouse_delta(w) != {0, 0}
}

mouse_wheel_moved :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.mouse_presses[:], button)
}

mouse_released :: proc(button: Mouse_Button, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.mouse_releases[:], button)
}

any_mouse_pressed :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.mouse_presses) > 0
}

any_mouse_released :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.key_presses[:], key)
}

key_released :: proc(key: Keyboard_Key, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.key_releases[:], key)
}

any_key_pressed :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.key_presses) > 0
}

any_key_released :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.key_releases) > 0
}

key_presses :: proc(w := ctx.current_window) -> []Keyboard_Key {
    if w == nil { return nil }
    return w.key_presses[:]
}

key_releases :: proc(w := ctx.current_window) -> []Keyboard_Key {
    if w == nil { return nil }
    return w.key_releases[:]
}

text_input :: proc(w := ctx.current_window) -> string {
    if w == nil { return "" }
    return strings.to_string(w.text_input)
}