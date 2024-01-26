package gui

import "window"

Mouse_Button :: window.Mouse_Button
Keyboard_Key :: window.Keyboard_Key

Draw_Event :: window.Draw_Event
Update_Event :: window.Update_Event
Window_Open_Event :: window.Open_Event
Window_Close_Event :: window.Close_Event
Window_Gain_Focus_Event :: window.Gain_Focus_Event
Window_Lose_Focus_Event :: window.Lose_Focus_Event
Window_Show_Event :: window.Show_Event
Window_Hide_Event :: window.Hide_Event
Window_Move_Event :: window.Move_Event
Window_Resize_Event :: window.Resize_Event
Window_Mouse_Enter_Event :: window.Mouse_Enter_Event
Window_Mouse_Exit_Event :: window.Mouse_Exit_Event
Window_Mouse_Move_Event :: window.Mouse_Move_Event
Window_Mouse_Scroll_Event :: window.Mouse_Scroll_Event
Window_Mouse_Press_Event :: window.Mouse_Press_Event
Window_Mouse_Release_Event :: window.Mouse_Release_Event
Window_Key_Press_Event :: window.Key_Press_Event
Window_Key_Release_Event :: window.Key_Release_Event
Window_Text_Event :: window.Text_Event

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