package window

import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:intrinsics"
import utf8 "core:unicode/utf8"
import "pugl"

gl_set_proc_address :: pugl.gl_set_proc_address

Window :: struct {
    user_data: rawptr,

    on_frame: proc(window: ^Window),
    on_move: proc(window: ^Window, position: [2]f32),
    on_resize: proc(window: ^Window, size: [2]f32),
    on_mouse_move: proc(window: ^Window, position: [2]f32),
    on_mouse_enter: proc(window: ^Window),
    on_mouse_exit: proc(window: ^Window),
    on_mouse_wheel: proc(window: ^Window, amount: [2]f32),
    on_mouse_press: proc(window: ^Window, button: Mouse_Button),
    on_mouse_release: proc(window: ^Window, button: Mouse_Button),
    on_key_press: proc(window: ^Window, key: Keyboard_Key),
    on_key_release: proc(window: ^Window, key: Keyboard_Key),
    on_rune: proc(window: ^Window, r: rune),

    close_requested: bool,
    is_visible: bool,
    position: [2]f32,
    size: [2]f32,
    content_scale: f32,

    view: ^pugl.View,
    world: ^pugl.World,

    odin_context: runtime.Context,
}

create :: proc(
    title := "",
    size := [2]f32{400, 300},
    min_size: Maybe([2]f32) = nil,
    max_size: Maybe([2]f32) = nil,
    swap_interval := 1,
    dark_mode := true,
    resizable := true,
    double_buffer := true,
) -> (^Window, Window_Error) {
    window := new(Window)
    window.odin_context = context

    window_class_name := fmt.aprintln("WindowClass")
    window_class_name_cstring := strings.clone_to_cstring(window_class_name)
    defer {
        delete(window_class_name)
        delete(window_class_name_cstring)
    }

    when ODIN_BUILD_MODE == .Dynamic {
        world_type := pugl.WorldType.MODULE
    } else {
        world_type := pugl.WorldType.PROGRAM
    }
    world := pugl.NewWorld(world_type, {})
    pugl.SetWorldString(world, .CLASS_NAME, window_class_name_cstring)

    view := pugl.NewView(world)

    title_cstring := strings.clone_to_cstring(title)
    defer delete(title_cstring)

    pugl.SetViewString(view, .WINDOW_TITLE, title_cstring)
    pugl.SetSizeHint(view, .DEFAULT_SIZE, u16(size.x), u16(size.y))

    if min_size, ok := min_size.?; ok {
        pugl.SetSizeHint(view, .MIN_SIZE, u16(min_size.x), u16(min_size.y))
    }
    if max_size, ok := max_size.?; ok {
        pugl.SetSizeHint(view, .MAX_SIZE, u16(max_size.x), u16(max_size.y))
    }

    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .DARK_FRAME, dark_mode ? 1 : 0)
    pugl.SetViewHint(view, .RESIZABLE, resizable ? 1 : 0)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, double_buffer ? 1 : 0)
    pugl.SetViewHint(view, .SWAP_INTERVAL, i32(swap_interval))
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    pugl.SetEventFunc(view, _on_event)

    if pugl.Realize(view) != .SUCCESS {
        pugl.FreeView(view)
        pugl.FreeWorld(world)
        free(window)
        return nil, .Failed_To_Open
    }

    window.view = view
    window.world = world
    window.size = size
    window.content_scale = f32(pugl.GetScaleFactor(view))

    pugl.SetHandle(view, window)

    return window, nil
}

destroy :: proc(window: ^Window) {
    pugl.Unrealize(window.view)
    pugl.FreeView(window.view)
    pugl.FreeWorld(window.world)
    free(window)
}

update :: proc(window: ^Window) {
    pugl.Update(window.world, 0)
}

activate_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

deactivate_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

close :: proc(window: ^Window) {
    window.close_requested = true
}

close_requested :: proc(window: ^Window) -> bool {
    return window.close_requested
}

show :: proc(window: ^Window) {
    pugl.Show(window.view, .RAISE)
    window.is_visible = true
}

hide :: proc(window: ^Window) {
    pugl.Hide(window.view)
    window.is_visible = false
}

is_visible :: proc(window: ^Window) -> bool {
    return window.is_visible
}

size :: proc(window: ^Window) -> [2]f32 {
    return window.size
}

content_scale :: proc(window: ^Window) -> f32 {
    return window.content_scale
}

set_on_frame :: proc(window: ^Window, on_frame: proc(^Window)) {
    window.on_frame = on_frame
}

_get_window_class_id :: proc "contextless" () -> u64 {
    @(static) last_id: u64
    return 1 + intrinsics.atomic_add(&last_id, 1)
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    #partial switch event.type {

    case .EXPOSE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context

        window.content_scale = f32(pugl.GetScaleFactor(view))
        if window.on_frame != nil {
            window->on_frame()
        }

    case .UPDATE:
        pugl.PostRedisplay(view)

    case .CONFIGURE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := event.configure

        position := [2]f32{f32(event.x), f32(event.y)}
        size := [2]f32{f32(event.width), f32(event.height)}

        if window.on_move != nil && position != window.position {
            window->on_move(position)
        }

        if window.on_resize != nil && size != window.size {
            window->on_resize(size)
        }

        window.position = position
        window.size = size

    case .MOTION:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := event.motion
        if window.on_mouse_move != nil {
            window->on_mouse_move({f32(event.x), f32(event.y)})
        }

    case .POINTER_IN:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        if window.on_mouse_enter != nil {
            window->on_mouse_enter()
        }

    case .POINTER_OUT:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        if window.on_mouse_exit != nil {
            window->on_mouse_exit()
        }

    case .SCROLL:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.scroll
        if window.on_mouse_wheel != nil {
            window->on_mouse_wheel({f32(event.dx), f32(event.dy)})
        }

    case .BUTTON_PRESS:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.button
        if window.on_mouse_press != nil {
            window->on_mouse_press(_pugl_button_to_mouse_button(event.button))
        }

    case .BUTTON_RELEASE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.button
        if window.on_mouse_release != nil {
            window->on_mouse_release(_pugl_button_to_mouse_button(event.button))
        }

    case .KEY_PRESS:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.key
        if window.on_key_press != nil {
            window->on_key_press(_pugl_key_event_to_keyboard_key(event))
        }

    case .KEY_RELEASE:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.key
        if window.on_key_release != nil {
            window->on_key_release(_pugl_key_event_to_keyboard_key(event))
        }

    case .TEXT:
        window := cast(^Window)pugl.GetHandle(view)
        context = window.odin_context
        event := &event.text
        if window.on_rune != nil {
            r, len := utf8.decode_rune(event.string[:4])
            window->on_rune(r)
        }

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