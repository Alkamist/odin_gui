package gui

Event :: union {
    Window_Update_Event,
    Window_Draw_Event,
    Window_Open_Event,
    Window_Close_Event,
    Window_Show_Event,
    Window_Hide_Event,
    Window_Move_Event,
    Window_Resize_Event,
    Window_Mouse_Enter_Event,
    Window_Mouse_Exit_Event,
    Window_Mouse_Move_Event,
    Window_Mouse_Scroll_Event,
    Window_Mouse_Press_Event,
    Window_Mouse_Repeat_Event,
    Window_Mouse_Release_Event,
    Window_Key_Press_Event,
    Window_Key_Repeat_Event,
    Window_Key_Release_Event,
    Window_Text_Event,
    Window_Content_Scale_Event,

    Update_Event,
    Draw_Event,
    Show_Event,
    Hide_Event,
    Move_Event,
    Resize_Event,
    Mouse_Enter_Event,
    Mouse_Exit_Event,
    Mouse_Move_Event,
    Mouse_Scroll_Event,
    Mouse_Press_Event,
    Mouse_Repeat_Event,
    Mouse_Release_Event,
    Key_Press_Event,
    Key_Repeat_Event,
    Key_Release_Event,
    Text_Event,
}


//============================================================================
// Window Events
//============================================================================


Window_Update_Event :: struct {}
Window_Draw_Event :: struct {}
Window_Open_Event :: struct {}
Window_Close_Event :: struct {}
Window_Show_Event :: struct {}
Window_Hide_Event :: struct {}

Window_Move_Event :: struct {
    position: Vec2,
    delta: Vec2,
}

Window_Resize_Event :: struct {
    size: Vec2,
    delta: Vec2,
}

Window_Mouse_Enter_Event :: struct {
    position: Vec2,
}

Window_Mouse_Exit_Event :: struct {
    position: Vec2,
}

Window_Mouse_Move_Event :: struct {
    position: Vec2,
    delta: Vec2,
}

Window_Mouse_Scroll_Event :: struct {
    position: Vec2,
    amount: Vec2,
}

Window_Mouse_Press_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
}

Window_Mouse_Repeat_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
    press_count: int,
}

Window_Mouse_Release_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
}

Window_Key_Press_Event :: struct {
    key: Keyboard_Key,
}

Window_Key_Repeat_Event :: struct {
    key: Keyboard_Key,
}

Window_Key_Release_Event :: struct {
    key: Keyboard_Key,
}

Window_Text_Event :: struct {
    text: rune,
}

Window_Content_Scale_Event :: struct {
    scale: Vec2,
    delta: Vec2,
}


//============================================================================
// Widget Events
//============================================================================


Update_Event :: struct {}
Draw_Event :: struct {}
Show_Event :: struct {}
Hide_Event :: struct {}

Move_Event :: struct {
    global_position: Vec2,
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

Mouse_Repeat_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
    press_count: int,
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