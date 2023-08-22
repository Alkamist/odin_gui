package widgets

import "../../gui"

@(thread_local) _default_font: ^Font

set_default_font :: proc(font: ^Font) {
    _default_font = font
}

Vec2 :: gui.Vec2
Color :: gui.Color
Mouse_Button :: gui.Mouse_Button
Keyboard_Key :: gui.Keyboard_Key