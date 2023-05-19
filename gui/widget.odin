package gui

import "core:strings"

Color :: [4]f64

Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Pointing_Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
}

Mouse_Button :: enum {
    Unknown,
    Left, Middle, Right,
    Extra_1, Extra_2, Extra_3,
    Extra_4, Extra_5,
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
    Escape, Backslash, Semicolon, Quote,
    Comma, Period, Slash, Scroll_Lock,
    Pause, Insert, End, Page_Up, Delete,
    Home, Page_Down, Left_Arrow, Right_Arrow,
    Down_Arrow, Up_Arrow, Num_Lock, Pad_Divide,
    Pad_Multiply, Pad_Subtract, Pad_Add, Pad_Enter,
    Pad_Period, Print_Screen,
}

Widget :: struct {
    root: ^Root,
    parent: ^Widget,
    children: [dynamic]^Widget,
    destroy: proc(widget: ^Widget),
    update: proc(widget: ^Widget),
    draw: proc(widget: ^Widget),
    dont_draw: bool,
    clip_drawing: bool,
    clip_input: bool,
    eat_input: bool,
    is_hovered: bool,
    was_hovered: bool,
    position: [2]f64,
    previous_position: [2]f64,
    size: [2]f64,
    previous_size: [2]f64,
    mouse_position: [2]f64,
}

moved :: proc(widget: ^Widget) -> bool {
    return widget.position != widget.previous_position
}
resized :: proc(widget: ^Widget) -> bool {
    return widget.size != widget.previous_size
}
mouse_entered :: proc(widget: ^Widget) -> bool {
    return widget.is_hovered && !widget.was_hovered
}
mouse_exited :: proc(widget: ^Widget) -> bool {
    return widget.was_hovered && !widget.is_hovered
}

add_widget :: proc(parent: ^Widget, $T: typeid) -> ^T {
    widget := new(T)
    widget.parent = parent
    widget.root = parent.root
    widget.eat_input = true
    widget.clip_input = true
    widget.clip_drawing = true
    // widget.update = proc(widget: ^Widget) { update_children(widget) }
    // widget.draw = proc(widget: ^Widget) { draw_children(widget) }

    append(&parent.children, widget)
    return widget
}

destroy_children :: proc(parent: ^Widget) {
    for child in parent.children {
        destroy_children(child)
        if child.destroy != nil {
            child->destroy()
        }
    }
}

update_children :: proc(parent: ^Widget) {
    ctx := parent.root.ctx
    for child in parent.children {
        child.previous_position = child.position
        child.previous_size = child.size
        child.was_hovered = child.is_hovered
        // vg.save_state()
        // vg.translate(child.position)
        // if child.clip_drawing {
        //     vg.clip([0, 0], child.size)
        // }
        for hover in child.root.hovers {
            if hover == child {
                child.is_hovered = true
                break
            }
        }
        child.mouse_position = parent.mouse_position - child.position
        if child.update != nil {
            child->update()
        }
        // vg.restore_state()
    }
}