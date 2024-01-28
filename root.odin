package gui

Root :: struct {
    using widget: Widget,
    input: Input_State,
    focus: ^Widget,
    mouse_hit: ^Widget,
    hover: ^Widget,
    previous_hover: ^Widget,
    hover_captured: bool,
    backend: Backend,
}

init_root :: proc(root: ^Root, size: Vec2) {
    init_widget(root)
    root.root = root
    root.size = size
    root.input = {}
    root.focus = nil
    root.mouse_hit = nil
    root.hover = nil
    root.previous_hover = nil
    root.hover_captured = false
    root.event_proc = root_event_proc
}

destroy_root :: proc(root: ^Root) {
    destroy_widget(root)
}

root_event_proc :: proc(widget: ^Widget, event: any) {
    root := cast(^Root)widget

    switch e in event {
    case Open_Event, Close_Event, Update_Event:
        for child in widget.children {
            send_event_recursively(child, event)
        }

    case Resize_Event:
        root.size = e.size

    case Mouse_Move_Event:
        root.input.mouse.position = e.position
        root.previous_hover = root.hover

        root.mouse_hit = _recursive_hit_test(root, e.position)

        if !root.hover_captured {
            root.hover = root.mouse_hit
        }

        if root.hover != root.previous_hover {
            if root.previous_hover != nil {
                send_event(root.previous_hover, Mouse_Exit_Event{
                    position = e.position,
                })
            }
            if root.hover != nil {
                send_event(root.hover, Mouse_Enter_Event{
                    position = e.position,
                })
            }
        }

        if root.hover != nil && root.hover != root {
            send_event(root.hover, Mouse_Move_Event{
                position = e.position,
                delta = e.delta,
            })
        }

    case Mouse_Press_Event:
        root.input.mouse.button_down[e.button] = true
        if root.hover != nil && root.hover != root {
            send_event(root.hover, Mouse_Press_Event{
                position = e.position,
                button = e.button,
            })
        }

    case Mouse_Release_Event:
        root.input.mouse.button_down[e.button] = false
        if root.hover != nil && root.hover != root {
            send_event(root.hover, Mouse_Release_Event{
                position = e.position,
                button = e.button,
            })
        }

    case Mouse_Scroll_Event:
        if root.hover != nil && root.hover != root {
            send_event(root.hover, Mouse_Scroll_Event{
                position = e.position,
                amount = e.amount,
            })
        }

    case Key_Press_Event:
        root.input.keyboard.key_down[e.key] = true
        if root.focus != nil {
            send_event(root.focus, Key_Press_Event{
                key = e.key,
            })
        }

    case Key_Release_Event:
        root.input.keyboard.key_down[e.key] = false
        if root.focus != nil {
            send_event(root.focus, Key_Release_Event{
                key = e.key,
            })
        }

    case Text_Event:
        if root.focus != nil {
            send_event(root.focus, Text_Event{
                text = e.text,
            })
        }
    }
}