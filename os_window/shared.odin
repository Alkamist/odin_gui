package oswindow

Window_Base :: struct {
    event_proc: proc(^Window, Event),
    handle: rawptr,
    parent_handle: rawptr,
    child_kind: Child_Kind,
}

Mouse_Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
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

Child_Kind :: enum {
    Transient,
    Embedded,
}

Event :: union {
    Event_Close_Button_Pressed,
    Event_Gain_Focus,
    Event_Lose_Focus,
    Event_Loop_Timer,
    Event_Move,
    Event_Resize,
    Event_Mouse_Enter,
    Event_Mouse_Exit,
    Event_Mouse_Move,
    Event_Mouse_Press,
    Event_Mouse_Release,
    Event_Mouse_Scroll,
    Event_Key_Press,
    Event_Key_Release,
    Event_Rune_Input,
}

Event_Close_Button_Pressed :: struct {}
Event_Gain_Focus :: struct {}
Event_Lose_Focus :: struct {}

Event_Loop_Timer :: struct {}

Event_Move :: struct {
    x, y: int,
}

Event_Resize :: struct {
    width, height: int,
}

Event_Mouse_Enter :: struct {}
Event_Mouse_Exit :: struct {}

Event_Mouse_Move :: struct {
    x, y: int,
}

Event_Mouse_Press :: struct {
    button: Mouse_Button,
}

Event_Mouse_Release :: struct {
    button: Mouse_Button,
}

Event_Mouse_Scroll :: struct {
    x, y: int,
}

Event_Key_Press :: struct {
    key: Keyboard_Key,
}

Event_Key_Release :: struct {
    key: Keyboard_Key,
}

Event_Rune_Input :: struct {
    r: rune,
}