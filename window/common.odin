package window

Vec2 :: [2]f32
Color :: [4]f32

Native_Handle :: rawptr

Child_Kind :: enum {
    None,
    Embedded,
    Transient,
}

Cursor_Style :: enum {
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

Draw_Event :: struct {}
Update_Event :: struct {}
Open_Event :: struct {}
Close_Event :: struct {}
Gain_Focus_Event :: struct {}
Lose_Focus_Event :: struct {}
Show_Event :: struct {}
Hide_Event :: struct {}

Move_Event :: struct {
    position: Vec2,
    delta: Vec2,
}

Resize_Event :: struct {
    size: Vec2,
    delta: Vec2,
}

Mouse_Enter_Event :: struct {
    position: Vec2,
}

Mouse_Exit_Event :: struct {
    position: Vec2,
}

Mouse_Move_Event :: struct {
    position: Vec2,
    delta: Vec2,
}

Mouse_Scroll_Event :: struct {
    position: Vec2,
    amount: Vec2,
}

Mouse_Press_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
}

Mouse_Release_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
}

Key_Press_Event :: struct {
    key: Keyboard_Key,
}

Key_Release_Event :: struct {
    key: Keyboard_Key,
}

Text_Event :: struct {
    text: rune,
}

send_event :: proc(window: ^Window, event: $T) -> (was_consumed: bool) {
    if window.event_proc != nil {
        return window->event_proc(event)
    }
    return false
}