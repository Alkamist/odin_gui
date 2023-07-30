package window

import "core:c"
import "core:fmt"
import "core:strings"
import "core:runtime"
import utf8 "core:unicode/utf8"
import "pugl"

@(thread_local) _world: ^pugl.World
@(thread_local) _update_proc: proc()

gl_set_proc_address :: pugl.gl_set_proc_address

Native_Handle :: rawptr

Child_Kind :: enum {
    None,
    Embedded,
    Transient,
}

Window :: struct {
    user_data: rawptr,

    on_move: proc(window: ^Window, position: Vec2),
    on_resize: proc(window: ^Window, size: Vec2),
    on_mouse_move: proc(window: ^Window, position: Vec2),
    on_mouse_enter: proc(window: ^Window),
    on_mouse_exit: proc(window: ^Window),
    on_mouse_wheel: proc(window: ^Window, amount: Vec2),
    on_mouse_press: proc(window: ^Window, button: Mouse_Button),
    on_mouse_release: proc(window: ^Window, button: Mouse_Button),
    on_key_press: proc(window: ^Window, key: Keyboard_Key),
    on_key_release: proc(window: ^Window, key: Keyboard_Key),
    on_rune: proc(window: ^Window, r: rune),

    is_open: bool,
    close_requested: bool,
    last_position: Vec2,
    last_size: Vec2,
    timer_id: uintptr,

    title: string,
    size: Vec2,
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    resizable: bool,
    double_buffer: bool,
    child_kind: Child_Kind,
    parent_handle: rawptr,

    view: ^pugl.View,

    odin_context: runtime.Context,
}

startup :: proc(id: string) {
    when ODIN_BUILD_MODE == .Dynamic {
        world_type := pugl.WorldType.MODULE
    } else {
        world_type := pugl.WorldType.PROGRAM
    }

    _world = pugl.NewWorld(world_type, {})

    id_cstring := strings.clone_to_cstring(id)
    defer delete(id_cstring)

    pugl.SetWorldString(_world, .CLASS_NAME, id_cstring)
}

shutdown :: proc() {
    pugl.FreeWorld(_world)
}

update :: proc() {
    if _update_proc != nil {
        _update_proc()
    }
    pugl.Update(_world, 0)
}

open :: proc(window: ^Window) -> Window_Error {
    if window.is_open {
        return nil
    }

    window.odin_context = context

    if window.parent_handle != nil {
        if window.child_kind == .None {
            window.child_kind = .Embedded
        }
    }

    view := pugl.NewView(_world)

    title_cstring := strings.clone_to_cstring(window.title)
    defer delete(title_cstring)

    pugl.SetViewString(view, .WINDOW_TITLE, title_cstring)
    pugl.SetSizeHint(view, .DEFAULT_SIZE, u16(window.size.x), u16(window.size.y))

    if min_size, ok := window.min_size.?; ok {
        pugl.SetSizeHint(view, .MIN_SIZE, u16(min_size.x), u16(min_size.y))
    }
    if max_size, ok := window.max_size.?; ok {
        pugl.SetSizeHint(view, .MAX_SIZE, u16(max_size.x), u16(max_size.y))
    }

    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .DARK_FRAME, window.dark_mode ? 1 : 0)
    pugl.SetViewHint(view, .RESIZABLE, window.resizable ? 1 : 0)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, window.double_buffer ? 1 : 0)
    pugl.SetViewHint(view, .SWAP_INTERVAL, i32(window.swap_interval))
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    #partial switch window.child_kind {
    case .Embedded:
        pugl.SetPosition(view, 0, 0)
        pugl.SetParentWindow(view, cast(uintptr)window.parent_handle)
    case .Transient:
        pugl.SetTransientParent(view, cast(uintptr)window.parent_handle)
    }

    pugl.SetEventFunc(view, _on_event)

    status := pugl.Realize(view)

    if status != .SUCCESS {
        pugl.FreeView(view)
        fmt.eprintln(pugl.Strerror(status))
        return .Failed_To_Open
    }

    window.view = view
    window.is_open = true
    window.close_requested = false
    pugl.SetHandle(view, window)

    return nil
}

close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }
    pugl.Unrealize(window.view)
    pugl.FreeView(window.view)
    window.is_open = false
}

parent_handle :: proc(window: ^Window) -> Native_Handle {
    return window.parent_handle
}

native_handle :: proc(window: ^Window) -> Native_Handle {
    return cast(rawptr)pugl.GetNativeView(window.view)
}

activate_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

deactivate_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

request_close :: proc(window: ^Window) {
    window.close_requested = true
}

close_requested :: proc(window: ^Window) -> bool {
    return window.close_requested
}

show :: proc(window: ^Window) {
    pugl.Show(window.view, .RAISE)
}

hide :: proc(window: ^Window) {
    pugl.Hide(window.view)
}

is_visible :: proc(window: ^Window) -> bool {
    return pugl.GetVisible(window.view)
}

position :: proc(window: ^Window) -> Vec2 {
    frame := pugl.GetFrame(window.view)
    return {f32(frame.x), f32(frame.y)}
}

set_position :: proc(window: ^Window, position: Vec2) {
    pugl.SetPosition(window.view, c.int(position.x), c.int(position.y))
}

size :: proc(window: ^Window) -> Vec2 {
    frame := pugl.GetFrame(window.view)
    return {f32(frame.width), f32(frame.height)}
}

set_size :: proc(window: ^Window, size: Vec2) {
    pugl.SetSize(window.view, c.uint(size.x), c.uint(size.y))
}

content_scale :: proc(window: ^Window) -> f32 {
    return f32(pugl.GetScaleFactor(window.view))
}

child_kind :: proc(window: ^Window) -> Child_Kind {
    return window.child_kind
}

set_on_move :: proc(window: ^Window, on_move: proc(window: ^Window, position: Vec2)) {
    window.on_move = on_move
}

set_on_resize :: proc(window: ^Window, on_resize: proc(window: ^Window, size: Vec2)) {
    window.on_resize = on_resize
}

set_on_mouse_move :: proc(window: ^Window, on_mouse_move: proc(window: ^Window, position: Vec2)) {
    window.on_mouse_move = on_mouse_move
}

set_on_mouse_enter :: proc(window: ^Window, on_mouse_enter: proc(window: ^Window)) {
    window.on_mouse_enter = on_mouse_enter
}

set_on_mouse_exit :: proc(window: ^Window, on_mouse_exit: proc(window: ^Window)) {
    window.on_mouse_exit = on_mouse_exit
}

set_on_mouse_wheel :: proc(window: ^Window, on_mouse_wheel: proc(window: ^Window, amount: Vec2)) {
    window.on_mouse_wheel = on_mouse_wheel
}

set_on_mouse_press :: proc(window: ^Window, on_mouse_press: proc(window: ^Window, button: Mouse_Button)) {
    window.on_mouse_press = on_mouse_press
}

set_on_mouse_release :: proc(window: ^Window, on_mouse_release: proc(window: ^Window, button: Mouse_Button)) {
    window.on_mouse_release = on_mouse_release
}

set_on_key_press :: proc(window: ^Window, on_key_press: proc(window: ^Window, key: Keyboard_Key)) {
    window.on_key_press = on_key_press
}

set_on_key_release :: proc(window: ^Window, on_key_release: proc(window: ^Window, key: Keyboard_Key)) {
    window.on_key_release = on_key_release
}

set_on_rune :: proc(window: ^Window, on_rune: proc(window: ^Window, r: rune)) {
    window.on_rune = on_rune
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    #partial switch event.type {

    case .EXPOSE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context

    case .UPDATE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        pugl.PostRedisplay(view)

    case .LOOP_ENTER:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := event.timer
        if window.timer_id == event.id {
            update()
        }

    case .CONFIGURE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := event.configure

        position := Vec2{f32(event.x), f32(event.y)}
        size := Vec2{f32(event.width), f32(event.height)}

        if window.on_move != nil && position != window.last_position {
            window->on_move(position)
        }

        if window.on_resize != nil && size != window.last_size {
            window->on_resize(size)
        }

        window.last_position = position
        window.last_size = size

    case .MOTION:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := event.motion
        if window.on_mouse_move != nil {
            window->on_mouse_move({f32(event.x), f32(event.y)})
        }

        update()

    case .POINTER_IN:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        if window.on_mouse_enter != nil {
            window->on_mouse_enter()
        }

        update()

    case .POINTER_OUT:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        if window.on_mouse_exit != nil {
            window->on_mouse_exit()
        }

        update()

    case .SCROLL:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.scroll
        if window.on_mouse_wheel != nil {
            window->on_mouse_wheel({f32(event.dx), f32(event.dy)})
        }

        update()

    case .BUTTON_PRESS:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.button
        if window.on_mouse_press != nil {
            window->on_mouse_press(_pugl_button_to_mouse_button(event.button))
        }

        update()

    case .BUTTON_RELEASE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.button
        if window.on_mouse_release != nil {
            window->on_mouse_release(_pugl_button_to_mouse_button(event.button))
        }

        update()

    case .KEY_PRESS:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.key
        if window.on_key_press != nil {
            window->on_key_press(_pugl_key_event_to_keyboard_key(event))
        }

        update()

    case .KEY_RELEASE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.key
        if window.on_key_release != nil {
            window->on_key_release(_pugl_key_event_to_keyboard_key(event))
        }

        update()

    case .TEXT:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.text
        if window.on_rune != nil {
            r, len := utf8.decode_rune(event.string[:4])
            window->on_rune(r)
        }

        update()

    case .CLOSE:
        window := cast(^Window)pugl.GetHandle(view)
        window.close_requested = true

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