package gui

Update_Event :: struct {}
Draw_Event :: struct {}
Open_Event :: struct {}
Close_Event :: struct {}
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

Key_Repeat_Event :: struct {
    key: Keyboard_Key,
}

Key_Release_Event :: struct {
    key: Keyboard_Key,
}

Text_Event :: struct {
    text: rune,
}

Content_Scale_Event :: struct {
    scale: Vec2,
    delta: Vec2,
}