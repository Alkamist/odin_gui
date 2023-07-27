package widgets

import "../gui"

Id :: gui.Id
Context :: gui.Context
Vec2 :: gui.Vec2
Color :: gui.Color
Mouse_Button :: gui.Mouse_Button
Keyboard_Key :: gui.Keyboard_Key

rgb :: proc(r, g, b: u8) -> Color {
    return {
        f32(r) / 255,
        f32(g) / 255,
        f32(b) / 255,
        1.0,
    }
}

rgba :: proc(r, g, b, a: u8) -> Color {
    return {
        f32(r) / 255,
        f32(g) / 255,
        f32(b) / 255,
        f32(a) / 255,
    }
}