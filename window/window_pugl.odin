package window

import "core:c"
import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:intrinsics"
import utf8 "core:unicode/utf8"
import "pugl"

@(thread_local) _odin_context: runtime.Context
@(thread_local) _world: ^pugl.World
@(thread_local) _window_count: int

Window :: struct {
    is_open: bool,
    title: string,
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    is_resizable: bool,
    double_buffer: bool,
    child_kind: Child_Kind,
    parent_handle: Native_Handle,

    last_visibility: bool,
    last_position: Vec2,
    last_size: Vec2,
    last_mouse_position: Vec2,

    user_data: rawptr,
    event_proc: proc(^Window, Event),

    close_requested: bool,

    timer_id: uintptr,
    view: ^pugl.View,
}

gl_set_proc_address :: pugl.gl_set_proc_address

update :: proc() {
    _odin_context = context
    if _world == nil {
        return
    }
    pugl.Update(_world, 0)
}

init :: proc(window: ^Window, position: Vec2, size: Vec2) {
    window.last_position = position
    window.last_size = size
    window.dark_mode = true
    window.last_visibility = true
    window.is_resizable = true
    window.double_buffer = true
    window.child_kind = .None
}

destroy :: proc(window: ^Window) {
    _force_close(window)
}

open :: proc(window: ^Window, temp_allocator := context.temp_allocator) -> (ok: bool) {
    if window.is_open {
        return true
    }

    if _window_count == 0 {
        when ODIN_BUILD_MODE == .Dynamic {
            world_type := pugl.WorldType.MODULE
        } else {
            world_type := pugl.WorldType.PROGRAM
        }
        _world = pugl.NewWorld(world_type, {})

        world_id := fmt.tprint("WindowThread", _generate_id())
        world_id_cstring, err := strings.clone_to_cstring(world_id, temp_allocator)
        if err != nil {
            return false
        }

        pugl.SetWorldString(_world, .CLASS_NAME, strings.clone_to_cstring(world_id, temp_allocator))
    }

    if window.parent_handle != nil && window.child_kind == .None {
        window.child_kind = .Embedded
    }

    view := pugl.NewView(_world)

    title_cstring, err := strings.clone_to_cstring(window.title, temp_allocator)
    if err != nil {
        return false
    }

    pugl.SetViewString(view, .WINDOW_TITLE, title_cstring)
    pugl.SetSizeHint(view, .DEFAULT_SIZE, u16(window.last_size.x), u16(window.last_size.y))

    if min_size, ok := window.min_size.?; ok {
        pugl.SetSizeHint(view, .MIN_SIZE, u16(min_size.x), u16(min_size.y))
    }

    if max_size, ok := window.max_size.?; ok {
        pugl.SetSizeHint(view, .MAX_SIZE, u16(max_size.x), u16(max_size.y))
    }

    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .STENCIL_BITS, 8)

    pugl.SetViewHint(view, .DARK_FRAME, window.dark_mode ? 1 : 0)
    pugl.SetViewHint(view, .RESIZABLE, window.is_resizable ? 1 : 0)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, window.double_buffer ? 1 : 0)
    pugl.SetViewHint(view, .SWAP_INTERVAL, i32(window.swap_interval))
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    #partial switch window.child_kind {
    case .Embedded:
        pugl.SetParentWindow(view, cast(uintptr)window.parent_handle)
    case .Transient:
        pugl.SetTransientParent(view, cast(uintptr)window.parent_handle)
    }

    pugl.SetHandle(view, window)
    pugl.SetEventFunc(view, _on_event)

    status := pugl.Realize(view)
    if status != .SUCCESS {
        pugl.FreeView(view)
        fmt.eprintln(pugl.Strerror(status))
        return false
    }

    pugl.SetPosition(view, c.int(window.last_position.x), c.int(window.last_position.y))

    if window.last_visibility {
        pugl.Show(view, .RAISE)
    }

    window.view = view
    window.is_open = true

    _window_count += 1

    pugl.EnterContext(view)
    send_event(window, Open_Event{})

    return true
}

// Asks the window to close itself when it gets the chance.
close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }
    event := pugl.EventType.CLOSE
    pugl.SendEvent(window.view, cast(^pugl.Event)(&event))
    window.close_requested = true
}

display :: proc(window: ^Window) {
    pugl.PostRedisplay(window.view)
}

native_handle :: proc(window: ^Window) -> Native_Handle {
    return cast(rawptr)pugl.GetNativeView(window.view)
}

activate_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

deactivate_context :: proc(window: ^Window) {
    pugl.LeaveContext(window.view)
}

is_open :: proc(window: ^Window) -> bool {
    return window.is_open
}

is_visible :: proc(window: ^Window) -> bool {
    if window.view != nil {
        return pugl.GetVisible(window.view)
    } else {
        return window.last_visibility
    }
}

set_visibility :: proc(window: ^Window, visibility: bool) {
    if window.view != nil {
        if visibility {
            pugl.Show(window.view, .RAISE)
        } else {
            pugl.Hide(window.view)
        }
    }
    window.last_visibility = visibility
}

position :: proc(window: ^Window) -> Vec2 {
    if window.view != nil {
        frame := pugl.GetFrame(window.view)
        return {f32(frame.x), f32(frame.y)}
    } else {
        return window.last_position
    }
}

set_position :: proc(window: ^Window, position: Vec2) {
    if window.view != nil {
        pugl.SetPosition(window.view, c.int(position.x), c.int(position.y))
    } else {
        window.last_position = position
    }
}

size :: proc(window: ^Window) -> Vec2 {
    if window.view != nil {
        frame := pugl.GetFrame(window.view)
        return {f32(frame.width), f32(frame.height)}
    } else {
        return window.last_size
    }
}

set_size :: proc(window: ^Window, size: Vec2) {
    if window.view != nil {
        pugl.SetSize(window.view, c.uint(size.x), c.uint(size.y))
    } else {
        window.last_size = size
    }
}

content_scale :: proc(window: ^Window) -> f32 {
    return f32(pugl.GetScaleFactor(window.view))
}

mouse_position :: proc(window: ^Window) -> Vec2 {
    return window.last_mouse_position
}

set_cursor_style :: proc(window: ^Window, style: Cursor_Style) {
    pugl.SetCursor(window.view, _cursor_style_to_pugl_cursor(style))
}

get_clipboard :: proc(window: ^Window) -> (data: string, ok: bool) {
    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(window.view, 0, &length)
    if clipboard_cstring == nil {
        return "", false
    }
    return string(clipboard_cstring), true
}

set_clipboard :: proc(window: ^Window, data: string, temp_allocator := context.temp_allocator) -> (ok: bool) {
    data_cstring, err := strings.clone_to_cstring(data, temp_allocator)
    if err != nil do return false
    if pugl.SetClipboard(window.view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1) != .SUCCESS {
        return false
    }
    return true
}


//====================================================================================
// Private
//====================================================================================


_generate_id :: proc "contextless" () -> u64 {
    @(static) id: u64
    return 1 + intrinsics.atomic_add(&id, 1)
}

// It is not safe for a window to close itself this way.
_force_close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }

    view := window.view

    pugl.EnterContext(view)

    window.last_visibility = pugl.GetVisible(view)

    send_event(window, Close_Event{})

    pugl.Unrealize(view)
    pugl.FreeView(view)

    window.view = nil
    window.is_open = false

    _window_count -= 1

    if _window_count == 0 {
        pugl.FreeWorld(_world)
        _world = nil
    }
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    window := cast(^Window)pugl.GetHandle(view)
    context = _odin_context

    #partial switch event.type {
    case .EXPOSE:
        send_event(window, Display_Event{})

    case .UPDATE:
        is_visible := pugl.GetVisible(view)
        if is_visible != window.last_visibility {
            if is_visible {
                send_event(window, Show_Event{})
            } else {
                send_event(window, Hide_Event{})
            }
            window.last_visibility = is_visible
        }

        send_event(window, Update_Event{})

    case .LOOP_ENTER:
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        event := event.timer
        if window.timer_id == event.id {
            update()
        }

    case .CONFIGURE:
        event := event.configure

        position := Vec2{f32(event.x), f32(event.y)}
        size := Vec2{f32(event.width), f32(event.height)}

        if position != window.last_position {
            send_event(window, Move_Event{
                position = position,
                delta = position - window.last_position,
            })
        }

        if size != window.last_size {
            send_event(window, Resize_Event{
                size = size,
                delta = size - window.last_size,
            })
        }

        window.last_position = position
        window.last_size = size

    case .MOTION:
        event := event.motion

        position := Vec2{f32(event.x), f32(event.y)}

        send_event(window, Mouse_Move_Event{
            position = position,
            delta = position - window.last_mouse_position,
        })

        window.last_mouse_position = position

    case .POINTER_IN:
        event := event.crossing
        send_event(window, Mouse_Enter_Event{
            position = Vec2{f32(event.x), f32(event.y)},
        })

    case .POINTER_OUT:
        event := event.crossing
        send_event(window, Mouse_Exit_Event{
            position = Vec2{f32(event.x), f32(event.y)},
        })

    case .FOCUS_IN:
        send_event(window, Gain_Focus_Event{})

    case .FOCUS_OUT:
        send_event(window, Lose_Focus_Event{})

    case .SCROLL:
        event := &event.scroll
        send_event(window, Mouse_Scroll_Event{
            position = window.last_mouse_position,
            amount = {f32(event.dx), f32(event.dy)},
        })

    case .BUTTON_PRESS:
        event := &event.button
        send_event(window, Mouse_Press_Event{
            position = window.last_mouse_position,
            button = _pugl_button_to_mouse_button(event.button),
        })

    case .BUTTON_RELEASE:
        event := &event.button
        send_event(window, Mouse_Release_Event{
            position = window.last_mouse_position,
            button = _pugl_button_to_mouse_button(event.button),
        })

    case .KEY_PRESS:
        event := &event.key
        send_event(window, Key_Press_Event{
            key = _pugl_key_event_to_keyboard_key(event),
        })

    case .KEY_RELEASE:
        event := &event.key
        send_event(window, Key_Release_Event{
            key = _pugl_key_event_to_keyboard_key(event),
        })

    case .TEXT:
        event := &event.text

        // Filter out unnecessary characters.
        skip := false
        switch event.character {
        case 0..<32: skip = true
        }

        if !skip {
            r, len := utf8.decode_rune(event.string[:4])
            send_event(window, Text_Event{
                text = r,
            })
        }

    case .CLOSE:
        _force_close(window)
        window.close_requested = false
    }

    return .SUCCESS
}

_pugl_key_event_to_keyboard_key :: proc(event: ^pugl.KeyEvent) -> Keyboard_Key {
    #partial switch event.key {
    case .BACKSPACE: return .Backspace
    case .ENTER: return .Enter
    case .ESCAPE: return .Escape
    case .DELETE: return .Delete
    case .SPACE: return .Space
    case .F1: return .F1
    case .F2: return .F2
    case .F3: return .F3
    case .F4: return .F4
    case .F5: return .F5
    case .F6: return .F6
    case .F7: return .F7
    case .F8: return .F8
    case .F9: return .F9
    case .F10: return .F10
    case .F11: return .F11
    case .F12: return .F12
    case .PAGE_UP: return .Page_Up
    case .PAGE_DOWN: return .Page_Down
    case .END: return .End
    case .HOME: return .Home
    case .LEFT: return .Left_Arrow
    case .UP: return .Up_Arrow
    case .RIGHT: return .Right_Arrow
    case .DOWN: return .Down_Arrow
    case .PRINT_SCREEN: return .Print_Screen
    case .INSERT: return .Insert
    case .PAUSE: return .Pause
    case .NUM_LOCK: return .Num_Lock
    case .SCROLL_LOCK: return .Scroll_Lock
    case .CAPS_LOCK: return .Caps_Lock
    case .SHIFT_L: return .Left_Shift
    case .SHIFT_R: return .Right_Shift
    case .CTRL_L: return .Right_Control // Switched for some reason
    case .CTRL_R: return .Left_Control // Switched for some reason
    case .ALT_L: return .Right_Alt // Switched for some reason
    case .ALT_R: return .Left_Alt // Switched for some reason
    case .SUPER_L: return .Left_Meta
    case .SUPER_R: return .Right_Meta
    case .PAD_0: return .Pad_0
    case .PAD_1: return .Pad_1
    case .PAD_2: return .Pad_2
    case .PAD_3: return .Pad_3
    case .PAD_4: return .Pad_4
    case .PAD_5: return .Pad_5
    case .PAD_6: return .Pad_6
    case .PAD_7: return .Pad_7
    case .PAD_8: return .Pad_8
    case .PAD_9: return .Pad_9
    case .PAD_ENTER: return .Pad_Enter
    case .PAD_MULTIPLY: return .Pad_Multiply
    case .PAD_ADD: return .Pad_Add
    case .PAD_SUBTRACT: return .Pad_Subtract
    case .PAD_DECIMAL: return .Pad_Decimal
    case .PAD_DIVIDE: return .Pad_Divide
    case:
        switch int(event.key) {
        case 9: return .Tab
        case 96: return .Backtick
        case 49: return .Key_1
        case 50: return .Key_2
        case 51: return .Key_3
        case 52: return .Key_4
        case 53: return .Key_5
        case 54: return .Key_6
        case 55: return .Key_7
        case 56: return .Key_8
        case 57: return .Key_9
        case 48: return .Key_0
        case 45: return .Minus
        case 61: return .Equal
        case 113: return .Q
        case 119: return .W
        case 101: return .E
        case 114: return .R
        case 116: return .T
        case 121: return .Y
        case 117: return .U
        case 105: return .I
        case 111: return .O
        case 112: return .P
        case 91: return .Left_Bracket
        case 93: return .Right_Bracket
        case 92: return .Backslash
        case 97: return .A
        case 115: return .S
        case 100: return .D
        case 102: return .F
        case 103: return .G
        case 104: return .H
        case 106: return .J
        case 107: return .K
        case 108: return .L
        case 59: return .Semicolon
        case 39: return .Apostrophe
        case 122: return .Z
        case 120: return .X
        case 99: return .C
        case 118: return .V
        case 98: return .B
        case 110: return .N
        case 109: return .M
        case 44: return .Comma
        case 46: return .Period
        case 47: return .Slash
        case 57502: return .Pad_0
        case 57459: return .Pad_1
        case 57464: return .Pad_2
        case 57458: return .Pad_3
        case 57461: return .Pad_4
        case 57501: return .Pad_5
        case 57463: return .Pad_6
        case 57460: return .Pad_7
        case 57462: return .Pad_8
        case 57457: return .Pad_9
        case 57503: return .Pad_Decimal
        }
    }
    return .Unknown
}

_pugl_button_to_mouse_button :: proc(button: u32) -> Mouse_Button {
    switch button {
    case 0: return .Left
    case 1: return .Right
    case 2: return .Middle
    case 3: return .Extra_1
    case 4: return .Extra_2
    case: return .Unknown
    }
}

_cursor_style_to_pugl_cursor :: proc(style: Cursor_Style) -> pugl.Cursor {
    switch style {
    case .Arrow: return .ARROW
    case .I_Beam: return .CARET
    case .Crosshair: return .CROSSHAIR
    case .Hand: return .HAND
    case .Resize_Left_Right: return .LEFT_RIGHT
    case .Resize_Top_Bottom: return .UP_DOWN
    case .Resize_Top_Left_Bottom_Right: return .UP_LEFT_DOWN_RIGHT
    case .Resize_Top_Right_Bottom_Left: return .UP_RIGHT_DOWN_LEFT
    case .Scroll: return .ALL_SCROLL
    }
    return .ARROW
}