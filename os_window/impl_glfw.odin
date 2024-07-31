//+build linux, darwin
package os_window

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:sync"
import "core:strings"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "vendor:glfw"

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

@(thread_local) _key_states: [Keyboard_Key]bool

_open_window_count: int
_open_gl_is_loaded: bool

Window :: struct {
    using _base: Window_Base,
    _glfw_window: glfw.WindowHandle,
    _odin_context: runtime.Context,
}

Glfw_Cursors :: struct {
    arrow: glfw.CursorHandle,
    ibeam: glfw.CursorHandle,
    crosshair: glfw.CursorHandle,
    pointing_hand: glfw.CursorHandle,
    resize_left_right: glfw.CursorHandle,
    resize_top_bottom: glfw.CursorHandle,

    // These aren't there by default so placeholders for now.
    resize_top_left_bottom_right: glfw.CursorHandle,
    resize_top_right_bottom_left: glfw.CursorHandle,
}
_cursors: Glfw_Cursors

poll_events :: proc() {
    glfw.PollEvents()
}

poll_key_state :: proc(key: Keyboard_Key) -> bool {
    return _key_states[key]
}

clipboard :: proc(window: ^Window, allocator := context.allocator) -> string {
    return glfw.GetClipboardString(window._glfw_window)
}

set_clipboard :: proc(window: ^Window, str: string) {
    data_cstring := strings.clone_to_cstring(str, context.temp_allocator)
    glfw.SetClipboardString(window._glfw_window, data_cstring)
}

swap_buffers :: proc(window: ^Window) {
    glfw.SwapBuffers(window._glfw_window)
}

open :: proc(
    window: ^Window,
    title: string,
    x, y, width, height: int,
    parent_handle: rawptr = nil,
    child_kind := Child_Kind.Transient,
) {
    window._odin_context = context

    if sync.atomic_load(&_open_window_count) <= 0 {
        sync.atomic_store(&_open_window_count, 0)
        if !glfw.Init() {
            fmt.eprintln("Failed to initialize GLFW")
            return
        }
        _cursors.arrow = glfw.CreateStandardCursor(glfw.ARROW_CURSOR)
        _cursors.ibeam = glfw.CreateStandardCursor(glfw.IBEAM_CURSOR)
        _cursors.crosshair = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
        _cursors.pointing_hand = glfw.CreateStandardCursor(glfw.HAND_CURSOR)
        _cursors.resize_left_right = glfw.CreateStandardCursor(glfw.HRESIZE_CURSOR)
        _cursors.resize_top_bottom = glfw.CreateStandardCursor(glfw.VRESIZE_CURSOR)
        _cursors.resize_top_left_bottom_right = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
        _cursors.resize_top_right_bottom_left = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
    }

    glfw.WindowHint(glfw.RESIZABLE, true)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, OPENGL_VERSION_MAJOR)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, OPENGL_VERSION_MINOR)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window._glfw_window = glfw.CreateWindow(
        c.int(width), c.int(height),
        strings.clone_to_cstring(title, context.temp_allocator),
        nil, nil,
    )
    glfw.SetWindowPos(window._glfw_window, c.int(x), c.int(y))

    glfw.SetWindowUserPointer(window._glfw_window, window)
    glfw.SetWindowFocusCallback(window._glfw_window, _glfw_on_focus)
    glfw.SetWindowPosCallback(window._glfw_window, _glfw_on_move)
    glfw.SetWindowSizeCallback(window._glfw_window, _glfw_on_resize)
    glfw.SetCursorEnterCallback(window._glfw_window, _glfw_on_mouse_enter_exit)
    glfw.SetKeyCallback(window._glfw_window, _glfw_on_keyboard_key)
    glfw.SetMouseButtonCallback(window._glfw_window, _glfw_on_mouse_button)
    glfw.SetCursorPosCallback(window._glfw_window, _glfw_on_mouse_move)
    glfw.SetScrollCallback(window._glfw_window, _glfw_on_mouse_scroll)
    glfw.SetCharCallback(window._glfw_window, _glfw_on_text_input)
    glfw.SetWindowCloseCallback(window._glfw_window, _glfw_on_close)

    glfw.MakeContextCurrent(window._glfw_window)

    open_gl_is_loaded := sync.atomic_load(&_open_gl_is_loaded)
    if !open_gl_is_loaded {
        gl.load_up_to(3, 3, glfw.gl_set_proc_address)
        sync.atomic_store(&_open_gl_is_loaded, true)
    }

    sync.atomic_add(&_open_window_count, 1)
}

close :: proc(window: ^Window) {
    glfw.DestroyWindow(window._glfw_window)
    window._glfw_window = nil

    sync.atomic_sub(&_open_window_count, 1)
    if sync.atomic_load(&_open_window_count) <= 0 {
        glfw.DestroyCursor(_cursors.arrow)
        glfw.DestroyCursor(_cursors.ibeam)
        glfw.DestroyCursor(_cursors.crosshair)
        glfw.DestroyCursor(_cursors.pointing_hand)
        glfw.DestroyCursor(_cursors.resize_left_right)
        glfw.DestroyCursor(_cursors.resize_top_bottom)
        glfw.DestroyCursor(_cursors.resize_top_left_bottom_right)
        glfw.DestroyCursor(_cursors.resize_top_right_bottom_left)
        glfw.Terminate()
    }
}

set_focus :: proc(window: ^Window) {
    glfw.FocusWindow(window._glfw_window)
}

set_focus_native :: proc(native_handle: rawptr) {
}

show :: proc(window: ^Window) {
    glfw.ShowWindow(window._glfw_window)
}

hide :: proc(window: ^Window) {
    glfw.HideWindow(window._glfw_window)
}

activate_context :: proc(window: ^Window) {
    glfw.MakeContextCurrent(window._glfw_window)
}

set_mouse_cursor_style :: proc(window: ^Window, style: Mouse_Cursor_Style) {
    glfw.SetCursor(window._glfw_window, _cursor_style_to_glfw_cursor(style))
}

mouse_cursor_position :: proc(window: ^Window) -> (x, y: int) {
    x_, y_ := glfw.GetCursorPos(window._glfw_window)
    x = int(x_)
    y = int(y_)
    return
}

position :: proc(window: ^Window) -> (x, y: int) {
    x_, y_ := glfw.GetWindowPos(window._glfw_window)
    x = int(x_)
    y = int(y_)
    return
}

set_position :: proc(window: ^Window, x, y: int) {
    glfw.SetWindowPos(window._glfw_window, c.int(x), c.int(y))
}

size :: proc(window: ^Window) -> (width, height: int) {
    width_, height_ := glfw.GetWindowSize(window._glfw_window)
    width = int(width_)
    height = int(height_)
    return
}

set_size :: proc(window: ^Window, width, height: int) {
    glfw.SetWindowSize(window._glfw_window, c.int(width), c.int(height))
}

dpi :: proc(window: ^Window) -> f64 {
    x_scale, y_scale := glfw.GetWindowContentScale(window._glfw_window)
    return 96.0 * f64(x_scale)
}

_glfw_on_focus :: proc "c" (window: glfw.WindowHandle, focused: c.int) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    if focused > 0 {
        window.event_proc(window, Event_Gain_Focus{})
    } else {
        window.event_proc(window, Event_Lose_Focus{})
    }
}

_glfw_on_move :: proc "c" (window: glfw.WindowHandle, xpos, ypos: c.int) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    window.event_proc(window, Event_Move{
        x = int(xpos),
        y = int(ypos),
    })
}

_glfw_on_resize :: proc "c" (window: glfw.WindowHandle, width, height: c.int) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    window.event_proc(window, Event_Resize{
        width = int(width),
        height = int(height),
    })
}

_glfw_on_mouse_enter_exit :: proc "c" (window: glfw.WindowHandle, entered: c.int) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    if entered > 0 {
        window.event_proc(window, Event_Mouse_Enter{})
    } else {
        window.event_proc(window, Event_Mouse_Exit{})
    }
}

_glfw_on_keyboard_key :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    if action == glfw.PRESS || action == glfw.REPEAT {
        kbd_key := _glfw_key_to_keyboard_key(key)
        window.event_proc(window, Event_Key_Press{
            kbd_key,
        })
        _key_states[kbd_key] = true
    } else if action == glfw.RELEASE {
        kbd_key := _glfw_key_to_keyboard_key(key)
        window.event_proc(window, Event_Key_Release{
            kbd_key,
        })
        _key_states[kbd_key] = false
    }
}

_glfw_on_mouse_button :: proc "c" (window: glfw.WindowHandle, button, action, mods: c.int) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    if action == glfw.PRESS {
        window.event_proc(window, Event_Mouse_Press{
            _glfw_button_to_mouse_button(button),
        })
    } else if action == glfw.RELEASE {
        window.event_proc(window, Event_Mouse_Release{
            _glfw_button_to_mouse_button(button),
        })
    }
}

_glfw_on_mouse_move :: proc "c" (window: glfw.WindowHandle, xpos,  ypos: f64) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    window.event_proc(window, Event_Mouse_Move{
        x = int(xpos),
        y = int(ypos),
    })
}

_glfw_on_mouse_scroll :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    window.event_proc(window, Event_Mouse_Scroll{
        x = int(xoffset),
        y = int(yoffset),
    })
}

_glfw_on_text_input :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    window.event_proc(window, Event_Rune_Input{
        r = codepoint,
    })
}

_glfw_on_close :: proc "c" (window: glfw.WindowHandle) {
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    context = window._odin_context
    window.event_proc(window, Event_Close_Button_Pressed{})
}

_glfw_button_to_mouse_button :: proc(glfw_button: c.int) -> Mouse_Button {
    switch glfw_button {
    case glfw.MOUSE_BUTTON_1: return .Left
    case glfw.MOUSE_BUTTON_2: return .Right
    case glfw.MOUSE_BUTTON_3: return .Middle
    case glfw.MOUSE_BUTTON_4: return .Extra_1
    case glfw.MOUSE_BUTTON_5: return .Extra_2
    }
    return .Unknown
}

_glfw_key_to_keyboard_key :: proc(glfw_key: c.int) -> Keyboard_Key {
    switch glfw_key {
    case glfw.KEY_SPACE: return .Space
    case glfw.KEY_APOSTROPHE: return .Apostrophe
    case glfw.KEY_COMMA: return .Comma
    case glfw.KEY_MINUS: return .Minus
    case glfw.KEY_PERIOD: return .Period
    case glfw.KEY_SLASH: return .Slash
    case glfw.KEY_0: return .Key_0
    case glfw.KEY_1: return .Key_1
    case glfw.KEY_2: return .Key_2
    case glfw.KEY_3: return .Key_3
    case glfw.KEY_4: return .Key_4
    case glfw.KEY_5: return .Key_5
    case glfw.KEY_6: return .Key_6
    case glfw.KEY_7: return .Key_7
    case glfw.KEY_8: return .Key_8
    case glfw.KEY_9: return .Key_9
    case glfw.KEY_SEMICOLON: return .Semicolon
    case glfw.KEY_EQUAL: return .Equal
    case glfw.KEY_A: return .A
    case glfw.KEY_B: return .B
    case glfw.KEY_C: return .C
    case glfw.KEY_D: return .D
    case glfw.KEY_E: return .E
    case glfw.KEY_F: return .F
    case glfw.KEY_G: return .G
    case glfw.KEY_H: return .H
    case glfw.KEY_I: return .I
    case glfw.KEY_J: return .J
    case glfw.KEY_K: return .K
    case glfw.KEY_L: return .L
    case glfw.KEY_M: return .M
    case glfw.KEY_N: return .N
    case glfw.KEY_O: return .O
    case glfw.KEY_P: return .P
    case glfw.KEY_Q: return .Q
    case glfw.KEY_R: return .R
    case glfw.KEY_S: return .S
    case glfw.KEY_T: return .T
    case glfw.KEY_U: return .U
    case glfw.KEY_V: return .V
    case glfw.KEY_W: return .W
    case glfw.KEY_X: return .X
    case glfw.KEY_Y: return .Y
    case glfw.KEY_Z: return .Z
    case glfw.KEY_LEFT_BRACKET: return .Left_Bracket
    case glfw.KEY_BACKSLASH: return .Backslash
    case glfw.KEY_RIGHT_BRACKET: return .Right_Bracket
    case glfw.KEY_GRAVE_ACCENT: return .Backtick
    // case glfw.KEY_WORLD_1: return .World1
    // case glfw.KEY_WORLD_2: return .World2
    case glfw.KEY_ESCAPE: return .Escape
    case glfw.KEY_ENTER: return .Enter
    case glfw.KEY_TAB: return .Tab
    case glfw.KEY_BACKSPACE: return .Backspace
    case glfw.KEY_INSERT: return .Insert
    case glfw.KEY_DELETE: return .Delete
    case glfw.KEY_RIGHT: return .Right_Arrow
    case glfw.KEY_LEFT: return .Left_Arrow
    case glfw.KEY_DOWN: return .Down_Arrow
    case glfw.KEY_UP: return .Up_Arrow
    case glfw.KEY_PAGE_UP: return .Page_Up
    case glfw.KEY_PAGE_DOWN: return .Page_Down
    case glfw.KEY_HOME: return .Home
    case glfw.KEY_END: return .End
    case glfw.KEY_CAPS_LOCK: return .Caps_Lock
    case glfw.KEY_SCROLL_LOCK: return .Scroll_Lock
    case glfw.KEY_NUM_LOCK: return .Num_Lock
    case glfw.KEY_PRINT_SCREEN: return .Print_Screen
    case glfw.KEY_PAUSE: return .Pause
    case glfw.KEY_F1: return .F1
    case glfw.KEY_F2: return .F2
    case glfw.KEY_F3: return .F3
    case glfw.KEY_F4: return .F4
    case glfw.KEY_F5: return .F5
    case glfw.KEY_F6: return .F6
    case glfw.KEY_F7: return .F7
    case glfw.KEY_F8: return .F8
    case glfw.KEY_F9: return .F9
    case glfw.KEY_F10: return .F10
    case glfw.KEY_F11: return .F11
    case glfw.KEY_F12: return .F12
    // case glfw.KEY_F13: return .F13
    // case glfw.KEY_F14: return .F14
    // case glfw.KEY_F15: return .F15
    // case glfw.KEY_F16: return .F16
    // case glfw.KEY_F17: return .F17
    // case glfw.KEY_F18: return .F18
    // case glfw.KEY_F19: return .F19
    // case glfw.KEY_F20: return .F20
    // case glfw.KEY_F21: return .F21
    // case glfw.KEY_F22: return .F22
    // case glfw.KEY_F23: return .F23
    // case glfw.KEY_F24: return .F24
    // case glfw.KEY_F25: return .F25
    case glfw.KEY_KP_0: return .Pad_0
    case glfw.KEY_KP_1: return .Pad_1
    case glfw.KEY_KP_2: return .Pad_2
    case glfw.KEY_KP_3: return .Pad_3
    case glfw.KEY_KP_4: return .Pad_4
    case glfw.KEY_KP_5: return .Pad_5
    case glfw.KEY_KP_6: return .Pad_6
    case glfw.KEY_KP_7: return .Pad_7
    case glfw.KEY_KP_8: return .Pad_8
    case glfw.KEY_KP_9: return .Pad_9
    case glfw.KEY_KP_DECIMAL: return .Pad_Decimal
    case glfw.KEY_KP_DIVIDE: return .Pad_Divide
    case glfw.KEY_KP_MULTIPLY: return .Pad_Multiply
    case glfw.KEY_KP_SUBTRACT: return .Pad_Subtract
    case glfw.KEY_KP_ADD: return .Pad_Add
    case glfw.KEY_KP_ENTER: return .Pad_Enter
    // case glfw.KEY_KP_EQUAL: return .Pad_Equal
    case glfw.KEY_LEFT_SHIFT: return .Left_Shift
    case glfw.KEY_LEFT_CONTROL: return .Left_Control
    case glfw.KEY_LEFT_ALT: return .Left_Alt
    case glfw.KEY_LEFT_SUPER: return .Left_Meta
    case glfw.KEY_RIGHT_SHIFT: return .Right_Shift
    case glfw.KEY_RIGHT_CONTROL: return .Right_Control
    case glfw.KEY_RIGHT_ALT: return .Right_Alt
    case glfw.KEY_RIGHT_SUPER: return .Right_Meta
    // case glfw.KEY_MENU: return .Menu
    }
    return .Unknown
}

_cursor_style_to_glfw_cursor :: proc(style: Mouse_Cursor_Style) -> glfw.CursorHandle {
    #partial switch style {
    case .Arrow: return _cursors.arrow
    case .I_Beam: return _cursors.ibeam
    case .Crosshair: return _cursors.crosshair
    case .Hand: return _cursors.pointing_hand
    case .Resize_Left_Right: return _cursors.resize_left_right
    case .Resize_Top_Bottom: return _cursors.resize_top_bottom
    case .Resize_Top_Left_Bottom_Right: return _cursors.resize_top_left_bottom_right
    case .Resize_Top_Right_Bottom_Left: return _cursors.resize_top_right_bottom_left
    }
    return _cursors.arrow
}