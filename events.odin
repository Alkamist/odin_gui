package gui

import "window"

Mouse_Button :: window.Mouse_Button
Keyboard_Key :: window.Keyboard_Key

Draw_Event :: window.Draw_Event
Update_Event :: window.Update_Event
Window_Opened_Event :: window.Opened_Event
Window_Closed_Event :: window.Closed_Event
Window_Gained_Focus_Event :: window.Gained_Focus_Event
Window_Lost_Focus_Event :: window.Lost_Focus_Event
Window_Shown_Event :: window.Shown_Event
Window_Hidden_Event :: window.Hidden_Event
Window_Moved_Event :: window.Moved_Event
Window_Resized_Event :: window.Resized_Event
Window_Mouse_Entered_Event :: window.Mouse_Entered_Event
Window_Mouse_Exited_Event :: window.Mouse_Exited_Event
Window_Mouse_Moved_Event :: window.Mouse_Moved_Event
Window_Mouse_Scrolled_Event :: window.Mouse_Scrolled_Event
Window_Mouse_Pressed_Event :: window.Mouse_Pressed_Event
Window_Mouse_Released_Event :: window.Mouse_Released_Event
Window_Key_Pressed_Event :: window.Key_Pressed_Event
Window_Key_Released_Event :: window.Key_Released_Event
Window_Text_Event :: window.Text_Event

Mouse_Entered_Event :: struct {
    position: Vec2,
}

Mouse_Exited_Event :: struct {
    position: Vec2,
}

Mouse_Moved_Event :: struct {
    position: Vec2,
    delta: Vec2,
}

Mouse_Scrolled_Event :: struct {
    position: Vec2,
    amount: Vec2,
}

Mouse_Pressed_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
}

Mouse_Released_Event :: struct {
    position: Vec2,
    button: Mouse_Button,
}

Key_Pressed_Event :: struct {
    key: Keyboard_Key,
}

Key_Released_Event :: struct {
    key: Keyboard_Key,
}

Text_Event :: struct {
    text: rune,
}