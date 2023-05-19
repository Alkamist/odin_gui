package gui

import "core:slice"
import "core:strings"
import vg "vector_graphics"

Root :: struct {
    using widget: Widget,
    ctx: ^vg.Context,
    just_created: bool,
    hovers: [dynamic]^Widget,
    time: f64,
    previous_time: f64,
    mouse_capture: ^Widget,
    mouse_delta: [2]f64,
    mouse_wheel: [2]f64,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,
    cursor_style: Cursor_Style,
    previous_cursor_style: Cursor_Style,
    background_color: Color,
    previous_background_color: Color,
}

root_create :: proc() -> (res: Root) {
    reserve(&res.children, 16)
    reserve(&res.hovers, 16)
    reserve(&res.mouse_presses, 16)
    reserve(&res.mouse_releases, 16)
    reserve(&res.key_presses, 16)
    reserve(&res.key_releases, 16)
    strings.builder_init_none(&res.text_input)
    return
}

// root_destroy :: proc(root: ^Root) {
//     destroy_children(root)
//     delete(root.hovers)
//     delete(root.mouse_presses)
//     delete(root.mouse_releases)
//     delete(root.key_presses)
//     delete(root.key_releases)
//     strings.builder_destroy(&root.text_input)
// }

delta_time :: proc(root: ^Root) -> f64 {
    return root.time - root.previous_time
}
background_color_changed :: proc(root: ^Root) -> bool {
    return root.background_color != root.previous_background_color
}
cursor_style_changed :: proc(root: ^Root) -> bool {
    return root.cursor_style != root.previous_cursor_style
}
mouse_down :: proc(root: ^Root, button: Mouse_Button) -> bool {
    return root.mouse_down_states[button]
}
key_down :: proc(root: ^Root, key: Keyboard_Key) -> bool {
    return root.key_down_states[key]
}
mouse_moved :: proc(root: ^Root) -> bool {
    return root.mouse_delta != {0, 0}
}
mouse_wheel_moved :: proc(root: ^Root) -> bool {
    return root.mouse_wheel != {0, 0}
}
mouse_pressed :: proc(root: ^Root, button: Mouse_Button) -> bool {
    return slice.contains(root.mouse_presses[:], button)
}
mouse_released :: proc(root: ^Root, button: Mouse_Button) -> bool {
    return slice.contains(root.mouse_releases[:], button)
}
any_mouse_pressed :: proc(root: ^Root) -> bool {
    return len(root.mouse_presses) > 0
}
any_mouse_released :: proc(root: ^Root) -> bool {
    return len(root.mouse_releases) > 0
}
key_pressed :: proc(root: ^Root, key: Keyboard_Key) -> bool {
    return slice.contains(root.key_presses[:], key)
}
key_released :: proc(root: ^Root, key: Keyboard_Key) -> bool {
    return slice.contains(root.key_releases[:], key)
}
any_key_pressed :: proc(root: ^Root) -> bool {
    return len(root.key_presses) > 0
}
any_key_released :: proc(root: ^Root) -> bool {
    return len(root.key_releases) > 0
}