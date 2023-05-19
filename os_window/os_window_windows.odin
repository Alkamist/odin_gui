package os_window

import "core:time"
import "core:fmt"
import "core:runtime"
import "core:strings"
import win32 "core:sys/windows"
import gl "vendor:OpenGL"

LOBYTE :: #force_inline proc "contextless" (#any_int w: int) -> win32.BYTE {
    return cast(win32.BYTE)(cast(win32.DWORD_PTR)(w)) & 0xff
}

foreign import user32 "system:User32.lib"
@(default_calling_convention="stdcall")
foreign user32 {
    GetDesktopWindow :: proc() -> win32.HWND ---
    SetParent :: proc(hWndChild, hWndNewParent: win32.HWND) ---
}

foreign import kernel32 "system:Kernel32.lib"
@(default_calling_convention="stdcall")
foreign kernel32 {
    LoadLibraryA :: proc(lpLibFileName: win32.LPCSTR) -> win32.HMODULE ---
}

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

window_count := 0
window_class_name := win32.utf8_to_utf16("Odin_Os_Window")

Window :: struct {
    user_ptr: rawptr,
    on_close: proc(window: ^Window),
    on_move: proc(window: ^Window, x, y: int),
    on_resize: proc(window: ^Window, width, height: int),
    on_mouse_move: proc(window: ^Window, x, y: int),
    on_mouse_press: proc(window: ^Window, button: Mouse_Button, x, y: int),
    on_mouse_release: proc(window: ^Window, button: Mouse_Button, x, y: int),
    on_mouse_wheel: proc(window: ^Window, x, y: f64),
    on_mouse_enter: proc(window: ^Window, x, y: int),
    on_mouse_exit: proc(window: ^Window, x, y: int),
    on_key_press: proc(window: ^Window, key: Keyboard_Key),
    on_key_release: proc(window: ^Window, key: Keyboard_Key),
    on_rune: proc(window: ^Window, r: rune),
    on_dpi_change: proc(window: ^Window, dpi: f64),
    _cursor_x: int,
    _cursor_y: int,
    _is_open: bool,
    _is_decorated: bool,
    _is_hovered: bool,
    _child_status: Child_Status,
    _hwnd: win32.HWND,
    _hdc: win32.HDC,
    _hglrc: win32.HGLRC,
}

create :: proc(parent_handle: win32.HWND = nil) -> ^Window {
    window := new(Window)

    hinstance := cast(win32.HINSTANCE)win32.GetModuleHandleW(nil)

    if window_count == 0 {
        window_class := win32.WNDCLASSEXW{
            cbSize = size_of(win32.WNDCLASSEXW),
            style = win32.CS_OWNDC,
            lpfnWndProc = _window_proc,
            hInstance = hinstance,
            hCursor = win32.LoadCursorA(nil, win32.IDC_ARROW),
            lpszClassName = &window_class_name[0],
        }
        win32.RegisterClassExW(&window_class)
    }

    window_style := win32.WS_OVERLAPPEDWINDOW
    if parent_handle != nil {
        window._child_status = .Floating
        window_style |= win32.WS_POPUP
    }

    window._hwnd = win32.CreateWindowExW(
        0,
        &window_class_name[0],
        nil,
        window_style,
        win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
        GetDesktopWindow(),
        nil,
        hinstance,
        window,
    )
    if window._hwnd == nil {
        fmt.eprintln("Failed to create window.")
    }
    window._is_open = true
    window._is_decorated = true
    window._cursor_x, window._cursor_y = cursor_position(window)

    win32.SetProcessDpiAwarenessContext(win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

    _init_opengl_context(window)

    window_count += 1
    return window
}

destroy :: proc(window: ^Window) {
    if window._is_open {
        window._is_open = false
        win32.DestroyWindow(window._hwnd)
    }
}

poll_events :: proc(window: ^Window) {
    if window._child_status == .None {
        msg: win32.MSG
        for win32.PeekMessageW(&msg, window._hwnd, 0, 0, win32.PM_REMOVE) != win32.FALSE {
            win32.TranslateMessage(&msg)
            win32.DispatchMessageW(&msg)
        }
    }
}

swap_buffers :: proc(window: ^Window) {
    win32.SwapBuffers(window._hdc)
}

make_context_current :: proc(window: ^Window) {
    win32.wglMakeCurrent(window._hdc, window._hglrc)
}

set_cursor_style :: proc(window: ^Window, style: Cursor_Style) {
    win32.SetCursor(win32.LoadCursorA(nil, _to_win32_mouse_cursor_style(style)))
}

cursor_position :: proc(window: ^Window) -> (x, y: int) {
    pos: win32.POINT
    if win32.GetCursorPos(&pos) {
        win32.ScreenToClient(window._hwnd, &pos)
        x = int(pos.x)
        y = int(pos.y)
    }
    return
}

position :: proc(window: ^Window) -> (x, y: int) {
    pos: win32.POINT
    win32.ClientToScreen(window._hwnd, &pos)
    x = int(pos.x)
    y = int(pos.y)
    return
}

set_position :: proc(window: ^Window, x, y: int) {
    win32.SetWindowPos(
        window._hwnd, nil,
        i32(x), i32(y),
        0, 0,
        win32.SWP_NOACTIVATE | win32.SWP_NOZORDER | win32.SWP_NOSIZE,
    )
}

size :: proc(window: ^Window) -> (width, height: int) {
    area: win32.RECT
    win32.GetClientRect(window._hwnd, &area)
    width = int(area.right)
    height = int(area.bottom)
    return
}

set_size :: proc(window: ^Window, width, height: int) {
    win32.SetWindowPos(
        window._hwnd, nil,
        0, 0,
        i32(width), i32(height),
        win32.SWP_NOACTIVATE | win32.SWP_NOOWNERZORDER | win32.SWP_NOMOVE | win32.SWP_NOZORDER,
    )
}

dpi :: proc(window: ^Window) -> f64 {
    return f64(win32.GetDpiForWindow(window._hwnd))
}

set_decorated :: proc(window: ^Window, decorated: bool) {
    window._is_decorated = decorated
}

embed_inside_window :: proc(window: ^Window, parent: win32.HWND) {
    if window._child_status != .Embedded {
        win32.SetWindowLongPtrW(window._hwnd, win32.GWL_STYLE, int(win32.WS_CHILDWINDOW | win32.WS_CLIPSIBLINGS))
        window._child_status = .Embedded
        set_decorated(window, false)
        x, y := position(window)
        width, height := size(window)
        win32.SetWindowPos(
            window._hwnd,
            win32.HWND_TOPMOST,
            i32(x), i32(y),
            i32(width), i32(height),
            win32.SWP_SHOWWINDOW,
        )
    }
    SetParent(window._hwnd, parent)
}

show :: proc(window: ^Window) {
    win32.ShowWindow(window._hwnd, win32.SW_SHOW)
}

hide :: proc(window: ^Window) {
    win32.ShowWindow(window._hwnd, win32.SW_HIDE)
}

is_open :: proc(window: ^Window) -> bool {
    return window._is_open
}

_window_proc :: proc "stdcall" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
    context = runtime.default_context()

    if msg == win32.WM_CREATE {
        lpcs := transmute(^win32.CREATESTRUCTW)lparam
        win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, transmute(win32.LONG_PTR)lpcs.lpCreateParams)
    }

    window := transmute(^Window)win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA)
    if window == nil || hwnd != window._hwnd {
        return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
    }

    switch msg {

    case win32.WM_MOVE:
        if window.on_move != nil {
            window.on_move(
                window,
                int(win32.GET_X_LPARAM(lparam)),
                int(win32.GET_Y_LPARAM(lparam)),
            )
        }

    case win32.WM_SIZE:
        if window.on_resize != nil {
            window.on_resize(
                window,
                int(win32.LOWORD(cast(win32.DWORD)lparam)),
                int(win32.HIWORD(cast(win32.DWORD)lparam)),
            )
        }

    case win32.WM_CLOSE:
        if window.on_close != nil {
            window.on_close(window)
        }
        destroy(window)

    case win32.WM_DESTROY:
        if window_count > 0 {
            window_count -= 1
            if window_count == 0 {
                win32.UnregisterClassW(&window_class_name[0], nil)
            }
        }
        free(window)

    case win32.WM_DPICHANGED:
        if window.on_dpi_change != nil {
            window.on_dpi_change(window, f64(win32.GetDpiForWindow(window._hwnd)))
        }

    case win32.WM_MOUSEMOVE:
        window._cursor_x = int(win32.GET_X_LPARAM(lparam))
        window._cursor_y = int(win32.GET_Y_LPARAM(lparam))

        if !window._is_hovered {
            tme: win32.TRACKMOUSEEVENT
            tme.cbSize = size_of(tme)
            tme.dwFlags = win32.TME_LEAVE
            tme.hwndTrack = window._hwnd
            win32.TrackMouseEvent(&tme)
            window._is_hovered = true
            if window.on_mouse_enter != nil {
                window.on_mouse_enter(window, window._cursor_x, window._cursor_y)
            }
        }
        if window.on_mouse_move != nil {
            window.on_mouse_move(window, window._cursor_x, window._cursor_y)
        }

    case win32.WM_MOUSELEAVE:
        window._is_hovered = false
        if window.on_mouse_exit != nil {
            window.on_mouse_exit(window,  window._cursor_x, window._cursor_y)
        }

    case win32.WM_MOUSEWHEEL:
        if window.on_mouse_wheel != nil {
            window.on_mouse_wheel(
                window,
                0,
                f64(win32.GET_WHEEL_DELTA_WPARAM(wparam)) / win32.WHEEL_DELTA,
            )
        }

    case win32.WM_MOUSEHWHEEL:
        if window.on_mouse_wheel != nil {
            window.on_mouse_wheel(
                window,
                f64(win32.GET_WHEEL_DELTA_WPARAM(wparam)) / win32.WHEEL_DELTA,
                0,
            )
        }

    case win32.WM_LBUTTONDOWN, win32.WM_LBUTTONDBLCLK,
         win32.WM_MBUTTONDOWN, win32.WM_MBUTTONDBLCLK,
         win32.WM_RBUTTONDOWN, win32.WM_RBUTTONDBLCLK,
         win32.WM_XBUTTONDOWN, win32.WM_XBUTTONDBLCLK:
        window._cursor_x = int(win32.GET_X_LPARAM(lparam))
        window._cursor_y = int(win32.GET_Y_LPARAM(lparam))
        win32.SetCapture(window._hwnd)
        if window.on_mouse_press != nil {
            window.on_mouse_press(window, _to_mouse_button(msg, wparam), window._cursor_x, window._cursor_y)
        }

    case win32.WM_LBUTTONUP, win32.WM_MBUTTONUP, win32.WM_RBUTTONUP, win32.WM_XBUTTONUP:
        window._cursor_x = int(win32.GET_X_LPARAM(lparam))
        window._cursor_y = int(win32.GET_Y_LPARAM(lparam))
        win32.ReleaseCapture()
        if window.on_mouse_release != nil {
            window.on_mouse_release(window, _to_mouse_button(msg, wparam), window._cursor_x, window._cursor_y)
        }

    case win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN:
        if window.on_key_press != nil {
            window.on_key_press(window, _to_keyboard_key(wparam, lparam))
        }

    case win32.WM_KEYUP, win32.WM_SYSKEYUP:
        if window.on_key_release != nil {
            window.on_key_release(window, _to_keyboard_key(wparam, lparam))
        }

    case win32.WM_CHAR, win32.WM_SYSCHAR:
        if wparam > 0 && wparam < 0x10000 {
            if window.on_rune != nil {
                window.on_rune(window, cast(rune)wparam)
            }
        }

    case win32.WM_NCCALCSIZE:
        if !window._is_decorated {
            return 0
        }
    }

    return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
}

_to_win32_mouse_cursor_style :: proc(style: Cursor_Style) -> win32.LPCSTR {
    switch style {
    case .Arrow: return win32.IDC_ARROW
    case .I_Beam: return win32.IDC_IBEAM
    case .Crosshair: return win32.IDC_CROSS
    case .Pointing_Hand: return win32.IDC_HAND
    case .Resize_Left_Right: return win32.IDC_SIZEWE
    case .Resize_Top_Bottom: return win32.IDC_SIZENS
    case .Resize_Top_Left_Bottom_Right: return win32.IDC_SIZENWSE
    case .Resize_Top_Right_Bottom_Left: return win32.IDC_SIZENESW
    }
    return nil
}

_to_mouse_button :: proc(msg: win32.UINT, wparam: win32.WPARAM) -> Mouse_Button {
    switch msg {
    case win32.WM_LBUTTONDOWN, win32.WM_LBUTTONUP, win32.WM_LBUTTONDBLCLK:
        return .Left
    case win32.WM_MBUTTONDOWN, win32.WM_MBUTTONUP, win32.WM_MBUTTONDBLCLK:
        return .Middle
    case win32.WM_RBUTTONDOWN, win32.WM_RBUTTONUP, win32.WM_RBUTTONDBLCLK:
        return .Right
    case win32.WM_XBUTTONDOWN, win32.WM_XBUTTONUP, win32.WM_XBUTTONDBLCLK:
        if win32.HIWORD(cast(win32.DWORD)wparam) == 1 {
            return .Extra_1
        } else {
            return .Extra_2
        }
    }
    return .Unknown
}

_to_keyboard_key :: proc(wparam: win32.WPARAM, lparam: win32.LPARAM) -> Keyboard_Key {
    scan_code := LOBYTE(win32.HIWORD(cast(win32.DWORD)lparam))
    is_right := (win32.HIWORD(cast(win32.DWORD)lparam) & win32.KF_EXTENDED) == win32.KF_EXTENDED
    switch scan_code {
    case 42: return .Left_Shift
    case 54: return .Right_Shift
    case 29:
        if is_right {
            return .Right_Control
        } else {
            return .Left_Control
        }
    case 56:
        if is_right {
            return .Right_Alt
        } else {
            return .Left_Alt
        }
    case:
        switch wparam {
        case 8: return .Backspace
        case 9: return .Tab
        case 13: return .Enter
        case 19: return .Pause
        case 20: return .Caps_Lock
        case 27: return .Escape
        case 32: return .Space
        case 33: return .Page_Up
        case 34: return .Page_Down
        case 35: return .End
        case 36: return .Home
        case 37: return .Left_Arrow
        case 38: return .Up_Arrow
        case 39: return .Right_Arrow
        case 40: return .Down_Arrow
        case 45: return .Insert
        case 46: return .Delete
        case 48: return .Key_0
        case 49: return .Key_1
        case 50: return .Key_2
        case 51: return .Key_3
        case 52: return .Key_4
        case 53: return .Key_5
        case 54: return .Key_6
        case 55: return .Key_7
        case 56: return .Key_8
        case 57: return .Key_9
        case 65: return .A
        case 66: return .B
        case 67: return .C
        case 68: return .D
        case 69: return .E
        case 70: return .F
        case 71: return .G
        case 72: return .H
        case 73: return .I
        case 74: return .J
        case 75: return .K
        case 76: return .L
        case 77: return .M
        case 78: return .N
        case 79: return .O
        case 80: return .P
        case 81: return .Q
        case 82: return .R
        case 83: return .S
        case 84: return .T
        case 85: return .U
        case 86: return .V
        case 87: return .W
        case 88: return .X
        case 89: return .Y
        case 90: return .Z
        case 91: return .Left_Meta
        case 92: return .Right_Meta
        case 96: return .Pad_0
        case 97: return .Pad_1
        case 98: return .Pad_2
        case 99: return .Pad_3
        case 100: return .Pad_4
        case 101: return .Pad_5
        case 102: return .Pad_6
        case 103: return .Pad_7
        case 104: return .Pad_8
        case 105: return .Pad_9
        case 106: return .Pad_Multiply
        case 107: return .Pad_Add
        case 109: return .Pad_Subtract
        case 110: return .Pad_Period
        case 111: return .Pad_Divide
        case 112: return .F1
        case 113: return .F2
        case 114: return .F3
        case 115: return .F4
        case 116: return .F5
        case 117: return .F6
        case 118: return .F7
        case 119: return .F8
        case 120: return .F9
        case 121: return .F10
        case 122: return .F11
        case 123: return .F12
        case 144: return .Num_Lock
        case 145: return .Scroll_Lock
        case 186: return .Semicolon
        case 187: return .Equal
        case 188: return .Comma
        case 189: return .Minus
        case 190: return .Period
        case 191: return .Slash
        case 192: return .Backtick
        case 219: return .Left_Bracket
        case 220: return .Backslash
        case 221: return .Right_Bracket
        case 222: return .Quote
        case: return .Unknown
        }
    }
}

_init_opengl_context :: proc(window: ^Window) {
    pfd := win32.PIXELFORMATDESCRIPTOR{
        nSize = size_of(win32.PIXELFORMATDESCRIPTOR),
        nVersion = 1,
        dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_SUPPORT_COMPOSITION | win32.PFD_DOUBLEBUFFER,
        iPixelType = win32.PFD_TYPE_RGBA,
        cColorBits = 32,
        cRedBits = 0,
        cRedShift = 0,
        cGreenBits = 0,
        cGreenShift = 0,
        cBlueBits = 0,
        cBlueShift = 0,
        cAlphaBits = 0,
        cAlphaShift = 0,
        cAccumBits = 0,
        cAccumRedBits = 0,
        cAccumGreenBits = 0,
        cAccumBlueBits = 0,
        cAccumAlphaBits = 0,
        cDepthBits = 32,
        cStencilBits = 8,
        cAuxBuffers = 0,
        iLayerType = win32.PFD_MAIN_PLANE,
        bReserved = 0,
        dwLayerMask = 0,
        dwVisibleMask = 0,
        dwDamageMask = 0,
    }

    window._hdc = win32.GetDC(window._hwnd)
    pixel_format := win32.ChoosePixelFormat(window._hdc, &pfd)
    if pixel_format == 0 {
        fmt.eprintln("win32.ChoosePixelFormat failed.")
    }

    win32.SetPixelFormat(window._hdc, pixel_format, &pfd)

    window._hglrc = win32.wglCreateContext(window._hdc)
    if window._hglrc == nil {
        fmt.eprintln("win32.wglCreateContext failed.")
    }

    win32.wglMakeCurrent(window._hdc, window._hglrc)
    win32.ReleaseDC(window._hwnd, window._hdc)
}

_get_proc_address :: proc(name: cstring) -> rawptr {
    p := win32.wglGetProcAddress(name)
    if p != nil {
        return p
    }
    opengl_dll := LoadLibraryA("opengl32.dll")
    p = win32.GetProcAddress(opengl_dll, name)
    return p
}

gl_set_proc_address :: proc(p: rawptr, name: cstring) {
    (^rawptr)(p)^ = _get_proc_address(name)
}