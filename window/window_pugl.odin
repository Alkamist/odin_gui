package window

import "core:c"
import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:intrinsics"
import utf8 "core:unicode/utf8"
import gl "vendor:OpenGL"
import "pugl"

_open_gl_is_loaded: bool
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

    close_requested: bool,

    backend_data: rawptr,
    backend_callbacks: Backend_Callbacks,
    timer_id: uintptr,
    view: ^pugl.View,
}

make_window :: proc(
    title := "",
    position := Vec2{0, 0},
    size := Vec2{400, 300},
    min_size: Maybe(Vec2) = nil,
    max_size: Maybe(Vec2) = nil,
    swap_interval := 1,
    dark_mode := true,
    is_visible := true,
    is_resizable := true,
    double_buffer := true,
    child_kind := Child_Kind.None,
    parent_handle: Native_Handle = nil,
) -> Window {
    return {
        title = title,
        last_position = position,
        last_size = size,
        min_size = min_size,
        max_size = max_size,
        swap_interval = swap_interval,
        dark_mode = dark_mode,
        last_visibility = is_visible,
        is_resizable = is_resizable,
        double_buffer = double_buffer,
        child_kind = child_kind,
        parent_handle = parent_handle,
    }
}

update :: proc() {
    _odin_context = context
    if _world == nil {
        return
    }
    pugl.Update(_world, 0)
}

destroy :: proc(window: ^Window) {
    close(window)
}

open :: proc(window: ^Window) -> bool {
    if window.is_open {
        return false
    }

    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)

    if _window_count == 0 {
        when ODIN_BUILD_MODE == .Dynamic {
            world_type := pugl.WorldType.MODULE
        } else {
            world_type := pugl.WorldType.PROGRAM
        }
        _world = pugl.NewWorld(world_type, {})

        world_id := fmt.tprint("WindowThread", _generate_id())
        pugl.SetWorldString(_world, .CLASS_NAME, strings.clone_to_cstring(world_id, context.temp_allocator))
    }

    if window.parent_handle != nil && window.child_kind == .None {
        window.child_kind = .Embedded
    }

    view := pugl.NewView(_world)

    pugl.SetViewString(view, .WINDOW_TITLE, strings.clone_to_cstring(window.title, context.temp_allocator))
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
    if !_open_gl_is_loaded {
        gl.load_up_to(3, 3, pugl.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    return true
}

// It is not safe for a window to close itself this way.
close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }

    view := window.view

    pugl.EnterContext(view)

    window.last_visibility = pugl.GetVisible(view)

    if window.backend_callbacks.on_close != nil {
        window.backend_callbacks.on_close(window)
    }

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

// Ask the window to close itself. This is safe for a window to do itself.
request_close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }
    event := pugl.EventType.CLOSE
    pugl.SendEvent(window.view, cast(^pugl.Event)(&event))
    window.close_requested = true
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

set_cursor_style :: proc(window: ^Window, style: Cursor_Style) {
    pugl.SetCursor(window.view, _cursor_style_to_pugl_cursor(style))
}

get_clipboard :: proc(window: ^Window) -> string {
    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(window.view, 0, &length)
    return string(clipboard_cstring)
}

set_clipboard :: proc(window: ^Window, data: string) {
    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)
    data_cstring := strings.clone_to_cstring(data, context.temp_allocator)
    pugl.SetClipboard(window.view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1)
}



_generate_id :: proc "contextless" () -> u64 {
    @(static) id: u64
    return 1 + intrinsics.atomic_add(&id, 1)
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    #partial switch event.type {

    case .EXPOSE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        if window.backend_callbacks.on_draw != nil {
            window.backend_callbacks.on_draw(window)
        }

    case .UPDATE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context

        is_visible := pugl.GetVisible(view)
        if is_visible != window.last_visibility {
            if is_visible {
                if window.backend_callbacks.on_show != nil {
                    window.backend_callbacks.on_show(window)
                }
            } else {
                if window.backend_callbacks.on_hide != nil {
                    window.backend_callbacks.on_hide(window)
                }
            }
            window.last_visibility = is_visible
        }

        pugl.EnterContext(view)
        if window.backend_callbacks.on_update != nil {
            window.backend_callbacks.on_update(window)
        }

        pugl.PostRedisplay(view)

    case .LOOP_ENTER:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := event.timer
        if window.timer_id == event.id {
            update()
        }

    case .CONFIGURE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := event.configure

        position := Vec2{f32(event.x), f32(event.y)}
        size := Vec2{f32(event.width), f32(event.height)}

        if window.backend_callbacks.on_move != nil && position != window.last_position {
            window.backend_callbacks.on_move(window, position)
        }

        if window.backend_callbacks.on_resize != nil && size != window.last_size {
            window.backend_callbacks.on_resize(window, size)
        }

        window.last_position = position
        window.last_size = size

        pugl.PostRedisplay(view)

    case .MOTION:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := event.motion
        if window.backend_callbacks.on_mouse_move != nil {
            window.backend_callbacks.on_mouse_move(
                window,
                {f32(event.x), f32(event.y)},
                {f32(event.xRoot), f32(event.yRoot)},
            )
        }

        pugl.PostRedisplay(view)

    case .POINTER_IN:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        if window.backend_callbacks.on_mouse_enter != nil {
            window.backend_callbacks.on_mouse_enter(window)
        }

        pugl.PostRedisplay(view)

    case .POINTER_OUT:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        if window.backend_callbacks.on_mouse_exit != nil {
            window.backend_callbacks.on_mouse_exit(window)
        }

        pugl.PostRedisplay(view)

    case .FOCUS_IN:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        if window.backend_callbacks.on_gain_focus != nil {
            window.backend_callbacks.on_gain_focus(window)
        }

        pugl.PostRedisplay(view)

    case .FOCUS_OUT:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        if window.backend_callbacks.on_lose_focus != nil {
            window.backend_callbacks.on_lose_focus(window)
        }

        pugl.PostRedisplay(view)

    case .SCROLL:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := &event.scroll
        if window.backend_callbacks.on_mouse_wheel != nil {
            window.backend_callbacks.on_mouse_wheel(window, {f32(event.dx), f32(event.dy)})
        }

        pugl.PostRedisplay(view)

    case .BUTTON_PRESS:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := &event.button
        if window.backend_callbacks.on_mouse_press != nil {
            window.backend_callbacks.on_mouse_press(window, _pugl_button_to_mouse_button(event.button))
        }

        pugl.PostRedisplay(view)

    case .BUTTON_RELEASE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := &event.button
        if window.backend_callbacks.on_mouse_release != nil {
            window.backend_callbacks.on_mouse_release(window, _pugl_button_to_mouse_button(event.button))
        }

        pugl.PostRedisplay(view)

    case .KEY_PRESS:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := &event.key
        if window.backend_callbacks.on_key_press != nil {
            window.backend_callbacks.on_key_press(window, _pugl_key_event_to_keyboard_key(event))
        }

        pugl.PostRedisplay(view)

    case .KEY_RELEASE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := &event.key
        if window.backend_callbacks.on_key_release != nil {
            window.backend_callbacks.on_key_release(window, _pugl_key_event_to_keyboard_key(event))
        }

        pugl.PostRedisplay(view)

    case .TEXT:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        event := &event.text

        // Filter out backspace and enter.
        skip := event.character == 8 || event.character == 13

        if !skip && window.backend_callbacks.on_rune != nil {
            r, len := utf8.decode_rune(event.string[:4])
            window.backend_callbacks.on_rune(window, r)
        }

        pugl.PostRedisplay(view)

    case .CLOSE:
        window := cast(^Window)pugl.GetHandle(view)
        context = _odin_context
        close(window)
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