package os_window

import "base:runtime"
import "base:intrinsics"
import "core:c"
import "core:sync"
import win32 "core:sys/windows"
import gl "vendor:OpenGL"

foreign import user32 "system:User32.lib"
@(default_calling_convention="system")
foreign user32 {
    GetDesktopWindow :: proc() -> win32.HWND ---
    SetFocus :: proc(hWnd: win32.HWND) -> win32.HWND ---
    GetFocus :: proc() -> win32.HWND ---
    OpenClipboard :: proc(hWndNewOwner: win32.HWND) -> win32.BOOL ---
    CloseClipboard :: proc() -> win32.BOOL ---
    GetClipboardData :: proc(uFormat: win32.UINT) -> win32.HANDLE ---
    SetClipboardData :: proc(uFormat: win32.UINT, hMem: win32.HANDLE) -> win32.HANDLE ---
    EmptyClipboard :: proc() -> win32.BOOL ---
    MapWindowPoints :: proc(hWndFrom: win32.HWND, hWndTo: win32.HWND, lpPoints: win32.LPPOINT, cPoints: win32.UINT) -> c.int ---
}

foreign import kernel32 "system:Kernel32.lib"
@(default_calling_convention="system")
foreign kernel32 {
    GlobalLock :: proc(hMem: win32.HGLOBAL) -> win32.LPVOID ---
    GlobalUnlock :: proc(hMem: win32.HGLOBAL) -> win32.BOOL ---
    GlobalFree :: proc(hMem: win32.HGLOBAL) -> win32.HGLOBAL ---
}

LOBYTE :: #force_inline proc "contextless" (#any_int w: int) -> win32.BYTE {
    return cast(win32.BYTE)(cast(win32.DWORD_PTR)(w)) & 0xff
}

CF_UNICODETEXT :: 13
DWMWA_USE_IMMERSIVE_DARK_MODE :: 20

WIN32_WINDOW_CLASS :: "GUI_WINDOW_CLASS"

_open_window_count: int
_open_gl_is_loaded: bool

Window :: struct {
    using _base: Window_Base,
    _hdc: win32.HDC,
    _hglrc: win32.HGLRC,
    _high_surrogate: win32.WCHAR,
    _size_move_timer_id: win32.UINT_PTR,
    _odin_context: runtime.Context,
    _mouse_cursor_style: win32.HCURSOR,
    _is_hovered: bool,
    _last_x: int,
    _last_y: int,
    _last_width: int,
    _last_height: int,
}

poll_events :: proc() {
    msg: win32.MSG
    for win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) != win32.FALSE {
        win32.TranslateMessage(&msg)
        win32.DispatchMessageW(&msg)
    }
}

poll_key_state :: proc(key: Keyboard_Key) -> bool {
    return int(win32.GetKeyState(_keyboard_key_to_win32_vk(key))) & (1 << 16) != 0
}

clipboard :: proc(window: ^Window, allocator := context.allocator) -> string {
    tries := 0
    for !OpenClipboard(cast(win32.HWND)window.handle) {
        win32.Sleep(1)
        tries += 1
        if tries == 3 do return ""
    }
    defer CloseClipboard()

    object := cast(win32.HGLOBAL)GetClipboardData(CF_UNICODETEXT)
    if object == nil {
        return ""
    }

    buffer := GlobalLock(object)
    if buffer == nil {
        return ""
    }
    defer GlobalUnlock(object)

    str, err := win32.wstring_to_utf8(cast(win32.wstring)buffer, -1, context.allocator)
    if err != nil {
        return ""
    }

    return str
}

set_clipboard :: proc(window: ^Window, str: string) {
    character_count := win32.MultiByteToWideChar(win32.CP_UTF8, 0, raw_data(str), -1, nil, 0)
    if character_count == 0 {
        return
    }

    object := cast(win32.HGLOBAL)win32.GlobalAlloc(win32.GMEM_MOVEABLE, uint(character_count * size_of(win32.WCHAR)))
    if object == nil {
        return
    }

    buffer := GlobalLock(object)
    if buffer == nil {
        GlobalFree(object)
        return
    }

    win32.MultiByteToWideChar(win32.CP_UTF8, 0, raw_data(str), -1, cast(win32.LPWSTR)buffer, character_count)
    GlobalUnlock(object)

    tries := 0
    for !OpenClipboard(cast(win32.HWND)window.handle) {
        win32.Sleep(1)
        tries += 1
        if tries == 3 {
            GlobalFree(object)
            return
        }
    }

    EmptyClipboard()
    SetClipboardData(CF_UNICODETEXT, cast(win32.HANDLE)object)
    CloseClipboard()
}

swap_buffers :: proc(window: ^Window) {
    win32.SwapBuffers(window._hdc)
}

open :: proc(
    window: ^Window,
    title: string,
    x, y, width, height: int,
    parent_handle: rawptr = nil,
    child_kind := Child_Kind.Transient,
) {
    window._odin_context = context

    hInstance := cast(win32.HANDLE)_get_dll_handle()

    if sync.atomic_load(&_open_window_count) <= 0 {
        sync.atomic_store(&_open_window_count, 0)
        window_class: win32.WNDCLASSW
        window_class.lpfnWndProc = window_proc
        window_class.lpszClassName = intrinsics.constant_utf16_cstring(WIN32_WINDOW_CLASS)
        window_class.hInstance = hInstance
        // window_class.hCursor = win32.LoadCursorA(nil, win32.IDC_ARROW)
        window_class.style = win32.CS_DBLCLKS | win32.CS_OWNDC
        win32.RegisterClassW(&window_class)
    }

    hwndParent: win32.HWND
    style: win32.UINT
    if parent_handle != nil {
        hwndParent = cast(win32.HWND)parent_handle
        switch child_kind {
        case .Transient:
            style = win32.WS_OVERLAPPEDWINDOW | win32.WS_CLIPCHILDREN | win32.WS_CLIPSIBLINGS
        case .Embedded:
            style = win32.WS_CHILDWINDOW | win32.WS_CLIPCHILDREN | win32.WS_CLIPSIBLINGS
        }
    } else {
        hwndParent = GetDesktopWindow()
        style = win32.WS_OVERLAPPEDWINDOW | win32.WS_CLIPCHILDREN | win32.WS_CLIPSIBLINGS
    }

    window.parent_handle = parent_handle
    window.child_kind = child_kind

    window.handle = win32.CreateWindowW(
        intrinsics.constant_utf16_cstring(WIN32_WINDOW_CLASS),
        win32.utf8_to_wstring(title),
        style,
        0, 0, 400, 300,
        hwndParent,
        nil, hInstance, nil,
    )
    win32.SetWindowLongPtrW(cast(win32.HWND)window.handle, win32.GWLP_USERDATA, win32.LONG_PTR(cast(uintptr)window))

    set_position(window, x, y)
    set_size(window, width, height)

    use_dark_mode: win32.BOOL = win32.TRUE
    win32.DwmSetWindowAttribute(cast(win32.HWND)window.handle, DWMWA_USE_IMMERSIVE_DARK_MODE, &use_dark_mode, size_of(use_dark_mode))

    _create_opengl_context(window)

    sync.atomic_add(&_open_window_count, 1)
}

close :: proc(window: ^Window) {
    win32.wglMakeCurrent(window._hdc, window._hglrc)
    win32.wglDeleteContext(window._hglrc)
    win32.ReleaseDC(cast(win32.HWND)window.handle, window._hdc)

    style := win32.GetWindowLongPtrW(cast(win32.HWND)window.handle, win32.GWL_STYLE)
    if win32.UINT(style) & win32.WS_CHILDWINDOW == 0 {
        win32.DestroyWindow(cast(win32.HWND)window.handle)
    }

    sync.atomic_sub(&_open_window_count, 1)
    if sync.atomic_load(&_open_window_count) <= 0 {
        win32.UnregisterClassW(intrinsics.constant_utf16_cstring(WIN32_WINDOW_CLASS), nil)
    }
}

set_focus :: proc(window: ^Window) {
    SetFocus(cast(win32.HWND)window.handle)
}

set_focus_native :: proc(native_handle: rawptr) {
    SetFocus(cast(win32.HWND)native_handle)
}

show :: proc(window: ^Window) {
    win32.ShowWindow(cast(win32.HWND)window.handle, win32.SW_SHOW)
}

hide :: proc(window: ^Window) {
    win32.ShowWindow(cast(win32.HWND)window.handle, win32.SW_HIDE)
}

activate_context :: proc(window: ^Window) {
    win32.wglMakeCurrent(window._hdc, window._hglrc)
}

set_mouse_cursor_style :: proc(window: ^Window, style: Mouse_Cursor_Style) {
    window._mouse_cursor_style = win32.LoadCursorA(nil, _mouse_cursor_style_to_win32(style))
}

mouse_cursor_position :: proc(window: ^Window) -> (x, y: int) {
    pos: win32.POINT
    if win32.GetCursorPos(&pos) {
        win32.ScreenToClient(cast(win32.HWND)window.handle, &pos)
        x = int(pos.x)
        y = int(pos.y)
    }
    return
}

position :: proc(window: ^Window) -> (x, y: int) {
    pos: win32.POINT
    win32.ClientToScreen(cast(win32.HWND)window.handle, &pos)
    x = int(pos.x)
    y = int(pos.y)
    return
}

set_position :: proc(window: ^Window, x, y: int) {
    hwnd := cast(win32.HWND)window.handle
    rect := win32.RECT{i32(x), i32(y), i32(x), i32(y)}
    win32.AdjustWindowRectExForDpi(&rect, _window_flags(window), win32.FALSE, _window_ex_flags(window), win32.GetDpiForWindow(hwnd))
    win32.SetWindowPos(
        hwnd, nil,
        rect.left, rect.top,
        0, 0,
        win32.SWP_NOACTIVATE | win32.SWP_NOZORDER | win32.SWP_NOSIZE,
    )
}

size :: proc(window: ^Window) -> (width, height: int) {
    area: win32.RECT
    win32.GetClientRect(cast(win32.HWND)window.handle, &area)
    width = int(area.right)
    height = int(area.bottom)
    return
}

set_size :: proc(window: ^Window, width, height: int) {
    hwnd := cast(win32.HWND)window.handle
    rect := win32.RECT{0, 0, i32(width), i32(height)}
    win32.AdjustWindowRectExForDpi(&rect, _window_flags(window), win32.FALSE, _window_ex_flags(window), win32.GetDpiForWindow(hwnd))
    win32.SetWindowPos(
        hwnd, win32.HWND_TOP,
        0, 0, rect.right - rect.left, rect.bottom - rect.top,
        win32.SWP_NOACTIVATE | win32.SWP_NOOWNERZORDER | win32.SWP_NOMOVE | win32.SWP_NOZORDER,
    )
}

dpi :: proc(window: ^Window) -> f64 {
    return f64(win32.GetDpiForWindow(cast(win32.HWND)window.handle))
}

window_proc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) -> win32.LRESULT {
    window := cast(^Window)(cast(uintptr)(win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA)))
    if window == nil || window.event_proc == nil {
        return win32.DefWindowProcW(hwnd, msg, wParam, lParam)
    }

    context = window._odin_context

    switch msg {
    case win32.WM_ENTERSIZEMOVE, win32.WM_ENTERMENULOOP:
        window._size_move_timer_id = win32.SetTimer(cast(win32.HWND)window.handle, 1, win32.USER_TIMER_MINIMUM, nil)

    case win32.WM_EXITSIZEMOVE, win32.WM_EXITMENULOOP:
        win32.KillTimer(cast(win32.HWND)window.handle, window._size_move_timer_id)

    case win32.WM_TIMER:
        if wParam == window._size_move_timer_id {
            window.event_proc(window, Event_Loop_Timer{})
        }

    case win32.WM_CLOSE:
        window.event_proc(window, Event_Close_Button_Pressed{})
        return 0

    case win32.WM_SETFOCUS:
        window.event_proc(window, Event_Gain_Focus{})
        return 0

    case win32.WM_KILLFOCUS:
        window.event_proc(window, Event_Lose_Focus{})
        return 0

    case win32.WM_MOVE:
        x := int(win32.GET_X_LPARAM(lParam))
        y := int(win32.GET_Y_LPARAM(lParam))
        if x != window._last_x || y != window._last_y {
            window.event_proc(window, Event_Move{
                x = x,
                y = y,
            })
            window._last_x = x
            window._last_y = y
        }
        return 0

    case win32.WM_SIZE:
        width := int(win32.LOWORD(cast(win32.DWORD)lParam))
        height := int(win32.HIWORD(cast(win32.DWORD)lParam))
        if width != window._last_width || height != window._last_height {
            window.event_proc(window, Event_Resize{
                width = width,
                height = height,
            })
            window._last_width = width
            window._last_height = height
        }
        return 0

    case win32.WM_SETCURSOR:
        if win32.LOWORD(win32.DWORD(lParam)) == win32.HTCLIENT {
            win32.SetCursor(window._mouse_cursor_style)
            return 1
        }

    case win32.WM_MOUSEMOVE:
        if !window._is_hovered {
            tme: win32.TRACKMOUSEEVENT
            tme.cbSize = size_of(tme)
            tme.dwFlags = win32.TME_LEAVE
            tme.hwndTrack = cast(win32.HWND)window.handle
            win32.TrackMouseEvent(&tme)
            window._is_hovered = true
            window.event_proc(window, Event_Mouse_Enter{})
        }
        window.event_proc(window, Event_Mouse_Move{
            x = int(win32.GET_X_LPARAM(lParam)),
            y = int(win32.GET_Y_LPARAM(lParam)),
        })
        return 0

    case win32.WM_MOUSELEAVE:
        window._is_hovered = false
        window.event_proc(window, Event_Mouse_Exit{})
        return 0

    case win32.WM_MOUSEWHEEL:
        window.event_proc(window, Event_Mouse_Scroll{
            x = 0,
            y = int(win32.GET_WHEEL_DELTA_WPARAM(wParam)) / win32.WHEEL_DELTA,
        })
        return 0

    case win32.WM_MOUSEHWHEEL:
        window.event_proc(window, Event_Mouse_Scroll{
            x = int(win32.GET_WHEEL_DELTA_WPARAM(wParam)) / win32.WHEEL_DELTA,
            y = 0,
        })
        return 0

    case win32.WM_LBUTTONDOWN, win32.WM_LBUTTONDBLCLK,
         win32.WM_MBUTTONDOWN, win32.WM_MBUTTONDBLCLK,
         win32.WM_RBUTTONDOWN, win32.WM_RBUTTONDBLCLK,
         win32.WM_XBUTTONDOWN, win32.WM_XBUTTONDBLCLK:
        win32.SetCapture(cast(win32.HWND)window.handle)
        window.event_proc(window, Event_Mouse_Press{
            _win32_to_mouse_button(msg, wParam),
        })
        return 0

    case win32.WM_LBUTTONUP, win32.WM_MBUTTONUP, win32.WM_RBUTTONUP, win32.WM_XBUTTONUP:
        win32.ReleaseCapture()
        window.event_proc(window, Event_Mouse_Release{
            _win32_to_mouse_button(msg, wParam),
        })
        return 0

    case win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN:
        window.event_proc(window, Event_Key_Press{
            _win32_to_keyboard_key(wParam, lParam),
        })
        return 0

    case win32.WM_KEYUP, win32.WM_SYSKEYUP:
        window.event_proc(window, Event_Key_Release{
            _win32_to_keyboard_key(wParam, lParam),
        })
        return 0

    case win32.WM_CHAR, win32.WM_SYSCHAR:
        if wParam >= 0xd800 && wParam <= 0xdbff {
            window._high_surrogate = win32.WCHAR(wParam)
        } else {
            codepoint := 0

            if wParam >= 0xdc00 && wParam <= 0xdfff {
                if window._high_surrogate != 0 {
                    codepoint += int(window._high_surrogate) - 0xd800 << 10
                    codepoint += int(wParam - 0xdc00)
                    codepoint += 0x10000
                }
            } else {
                codepoint = int(wParam)
            }

            window._high_surrogate = 0

            window.event_proc(window, Event_Rune_Input{
                r = cast(rune)codepoint,
            })
        }

        if msg != win32.WM_SYSCHAR {
            return 0
        }
    }

    return win32.DefWindowProcW(hwnd, msg, wParam, lParam)
}

_create_opengl_context :: proc(window: ^Window) {
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

    hwnd := cast(win32.HWND)window.handle

    window._hdc = win32.GetDC(hwnd)

    pfmt := win32.ChoosePixelFormat(window._hdc, &pfd)
    win32.SetPixelFormat(window._hdc, pfmt, &pfd)

    window._hglrc = win32.wglCreateContext(window._hdc)
    win32.wglMakeCurrent(window._hdc, window._hglrc)

    open_gl_is_loaded := sync.atomic_load(&_open_gl_is_loaded)
    if !open_gl_is_loaded {
        gl.load_up_to(3, 3, gl_set_proc_address)
        sync.atomic_store(&_open_gl_is_loaded, true)
    }
}

gl_set_proc_address :: proc(p: rawptr, name: cstring) {
    fn := win32.wglGetProcAddress(name)
    if fn == nil {
        m := win32.LoadLibraryW(intrinsics.constant_utf16_cstring("opengl32.dll"))
        fn = win32.GetProcAddress(m, name)
    }
    (^rawptr)(p)^ = fn
}

_get_dll_handle :: proc "system" () -> win32.HMODULE {
    info: win32.MEMORY_BASIC_INFORMATION
    len := win32.VirtualQueryEx(win32.GetCurrentProcess(), cast(rawptr)_get_dll_handle, &info, size_of(info))
    return len > 0 ? cast(win32.HMODULE)info.AllocationBase : nil
}

_window_flags :: proc(window: ^Window) -> win32.UINT {
    common_flags := win32.WS_CLIPCHILDREN | win32.WS_CLIPSIBLINGS
    if window.parent_handle != nil && window.child_kind == .Embedded {
        return common_flags | win32.WS_CHILD
    }

    is_fullscreen := false
    if is_fullscreen {
        return common_flags | win32.WS_POPUPWINDOW
    }

    is_dialog := false
    type_flags: win32.UINT
    if is_dialog {
        type_flags = win32.WS_DLGFRAME | win32.WS_OVERLAPPED | win32.WS_CAPTION | win32.WS_SYSMENU
    } else {
        type_flags = win32.WS_POPUPWINDOW | win32.WS_CAPTION | win32.WS_MINIMIZEBOX
    }

    is_resizable := true
    size_flags := is_resizable ? (win32.WS_SIZEBOX | win32.WS_MAXIMIZEBOX) : 0

    return common_flags | type_flags | size_flags
}

_window_ex_flags :: proc(window: ^Window) -> win32.UINT {
    return win32.WS_EX_NOINHERITLAYOUT | (window.parent_handle != nil ? 0 : win32.WS_EX_APPWINDOW)
}

_mouse_cursor_style_to_win32 :: proc(style: Mouse_Cursor_Style) -> win32.LPCSTR {
    switch style {
    case .Arrow: return win32.IDC_ARROW
    case .I_Beam: return win32.IDC_IBEAM
    case .Crosshair: return win32.IDC_CROSS
    case .Hand: return win32.IDC_HAND
    case .Resize_Left_Right: return win32.IDC_SIZEWE
    case .Resize_Top_Bottom: return win32.IDC_SIZENS
    case .Resize_Top_Left_Bottom_Right: return win32.IDC_SIZENWSE
    case .Resize_Top_Right_Bottom_Left: return win32.IDC_SIZENESW
    }
    return nil
}

_win32_to_mouse_button :: proc(msg: win32.UINT, wParam: win32.WPARAM) -> Mouse_Button {
    switch msg {
    case win32.WM_LBUTTONDOWN, win32.WM_LBUTTONUP, win32.WM_LBUTTONDBLCLK:
        return .Left
    case win32.WM_MBUTTONDOWN, win32.WM_MBUTTONUP, win32.WM_MBUTTONDBLCLK:
        return .Middle
    case win32.WM_RBUTTONDOWN, win32.WM_RBUTTONUP, win32.WM_RBUTTONDBLCLK:
        return .Right
    case win32.WM_XBUTTONDOWN, win32.WM_XBUTTONUP, win32.WM_XBUTTONDBLCLK:
        if win32.HIWORD(cast(win32.DWORD)wParam) == 1 {
            return .Extra_1
        } else {
            return .Extra_2
        }
    }
    return .Unknown
}

_win32_to_keyboard_key :: proc(wParam: win32.WPARAM, lParam: win32.LPARAM) -> Keyboard_Key {
    scan_code := LOBYTE(win32.HIWORD(cast(win32.DWORD)lParam))
    is_right := (win32.HIWORD(cast(win32.DWORD)lParam) & win32.KF_EXTENDED) == win32.KF_EXTENDED
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
        return _win32_vk_to_keyboard_key(c.int(wParam))
    }
}

_keyboard_key_to_win32_vk :: proc(key: Keyboard_Key) -> c.int {
    #partial switch key {
    case .A: return win32.VK_A
    case .B: return win32.VK_B
    case .C: return win32.VK_C
    case .D: return win32.VK_D
    case .E: return win32.VK_E
    case .F: return win32.VK_F
    case .G: return win32.VK_G
    case .H: return win32.VK_H
    case .I: return win32.VK_I
    case .J: return win32.VK_J
    case .K: return win32.VK_K
    case .L: return win32.VK_L
    case .M: return win32.VK_M
    case .N: return win32.VK_N
    case .O: return win32.VK_O
    case .P: return win32.VK_P
    case .Q: return win32.VK_Q
    case .R: return win32.VK_R
    case .S: return win32.VK_S
    case .T: return win32.VK_T
    case .U: return win32.VK_U
    case .V: return win32.VK_V
    case .W: return win32.VK_W
    case .X: return win32.VK_X
    case .Y: return win32.VK_Y
    case .Z: return win32.VK_Z
    case .Key_1: return win32.VK_1
    case .Key_2: return win32.VK_2
    case .Key_3: return win32.VK_3
    case .Key_4: return win32.VK_4
    case .Key_5: return win32.VK_5
    case .Key_6: return win32.VK_6
    case .Key_7: return win32.VK_7
    case .Key_8: return win32.VK_8
    case .Key_9: return win32.VK_9
    case .Key_0: return win32.VK_0
    case .Pad_1: return win32.VK_NUMPAD1
    case .Pad_2: return win32.VK_NUMPAD2
    case .Pad_3: return win32.VK_NUMPAD3
    case .Pad_4: return win32.VK_NUMPAD4
    case .Pad_5: return win32.VK_NUMPAD5
    case .Pad_6: return win32.VK_NUMPAD6
    case .Pad_7: return win32.VK_NUMPAD7
    case .Pad_8: return win32.VK_NUMPAD8
    case .Pad_9: return win32.VK_NUMPAD9
    case .Pad_0: return win32.VK_NUMPAD0
    case .F1: return win32.VK_F1
    case .F2: return win32.VK_F2
    case .F3: return win32.VK_F3
    case .F4: return win32.VK_F4
    case .F5: return win32.VK_F5
    case .F6: return win32.VK_F6
    case .F7: return win32.VK_F7
    case .F8: return win32.VK_F8
    case .F9: return win32.VK_F9
    case .F10: return win32.VK_F10
    case .F11: return win32.VK_F11
    case .F12: return win32.VK_F12
    case .Backtick: return win32.VK_OEM_3
    case .Minus: return win32.VK_OEM_MINUS
    case .Equal: return win32.VK_OEM_PLUS
    case .Backspace: return win32.VK_BACK
    case .Tab: return win32.VK_TAB
    case .Caps_Lock: return win32.VK_CAPITAL
    case .Enter: return win32.VK_RETURN
    case .Left_Shift: return win32.VK_LSHIFT
    case .Right_Shift: return win32.VK_RSHIFT
    case .Left_Control: return win32.VK_LCONTROL
    case .Right_Control: return win32.VK_RCONTROL
    case .Left_Alt: return win32.VK_LMENU
    case .Right_Alt: return win32.VK_RMENU
    case .Left_Meta: return win32.VK_LWIN
    case .Right_Meta: return win32.VK_RWIN
    case .Left_Bracket: return win32.VK_OEM_4
    case .Right_Bracket: return win32.VK_OEM_6
    case .Space: return win32.VK_SPACE
    case .Escape: return win32.VK_ESCAPE
    case .Backslash: return win32.VK_OEM_5
    case .Semicolon: return win32.VK_OEM_1
    case .Apostrophe: return win32.VK_OEM_7
    case .Comma: return win32.VK_OEM_COMMA
    case .Period: return win32.VK_OEM_PERIOD
    case .Slash: return win32.VK_OEM_2
    case .Scroll_Lock: return win32.VK_SCROLL
    case .Pause: return win32.VK_PAUSE
    case .Insert: return win32.VK_INSERT
    case .End: return win32.VK_END
    case .Page_Up: return win32.VK_PRIOR
    case .Delete: return win32.VK_DELETE
    case .Home: return win32.VK_HOME
    case .Page_Down: return win32.VK_NEXT
    case .Left_Arrow: return win32.VK_LEFT
    case .Right_Arrow: return win32.VK_RIGHT
    case .Down_Arrow: return win32.VK_DOWN
    case .Up_Arrow: return win32.VK_UP
    case .Num_Lock: return win32.VK_NUMLOCK
    case .Pad_Divide: return win32.VK_DIVIDE
    case .Pad_Multiply: return win32.VK_MULTIPLY
    case .Pad_Subtract: return win32.VK_SUBTRACT
    case .Pad_Add: return win32.VK_ADD
    case .Pad_Enter: return win32.VK_RETURN
    case .Pad_Decimal: return win32.VK_DECIMAL
    case .Print_Screen: return win32.VK_PRINT
    }
    return 0
}

_win32_vk_to_keyboard_key :: proc(vk: c.int) -> Keyboard_Key {
    switch vk {
    case win32.VK_A: return .A
    case win32.VK_B: return .B
    case win32.VK_C: return .C
    case win32.VK_D: return .D
    case win32.VK_E: return .E
    case win32.VK_F: return .F
    case win32.VK_G: return .G
    case win32.VK_H: return .H
    case win32.VK_I: return .I
    case win32.VK_J: return .J
    case win32.VK_K: return .K
    case win32.VK_L: return .L
    case win32.VK_M: return .M
    case win32.VK_N: return .N
    case win32.VK_O: return .O
    case win32.VK_P: return .P
    case win32.VK_Q: return .Q
    case win32.VK_R: return .R
    case win32.VK_S: return .S
    case win32.VK_T: return .T
    case win32.VK_U: return .U
    case win32.VK_V: return .V
    case win32.VK_W: return .W
    case win32.VK_X: return .X
    case win32.VK_Y: return .Y
    case win32.VK_Z: return .Z
    case win32.VK_1: return .Key_1
    case win32.VK_2: return .Key_2
    case win32.VK_3: return .Key_3
    case win32.VK_4: return .Key_4
    case win32.VK_5: return .Key_5
    case win32.VK_6: return .Key_6
    case win32.VK_7: return .Key_7
    case win32.VK_8: return .Key_8
    case win32.VK_9: return .Key_9
    case win32.VK_0: return .Key_0
    case win32.VK_NUMPAD1: return .Pad_1
    case win32.VK_NUMPAD2: return .Pad_2
    case win32.VK_NUMPAD3: return .Pad_3
    case win32.VK_NUMPAD4: return .Pad_4
    case win32.VK_NUMPAD5: return .Pad_5
    case win32.VK_NUMPAD6: return .Pad_6
    case win32.VK_NUMPAD7: return .Pad_7
    case win32.VK_NUMPAD8: return .Pad_8
    case win32.VK_NUMPAD9: return .Pad_9
    case win32.VK_NUMPAD0: return .Pad_0
    case win32.VK_F1: return .F1
    case win32.VK_F2: return .F2
    case win32.VK_F3: return .F3
    case win32.VK_F4: return .F4
    case win32.VK_F5: return .F5
    case win32.VK_F6: return .F6
    case win32.VK_F7: return .F7
    case win32.VK_F8: return .F8
    case win32.VK_F9: return .F9
    case win32.VK_F10: return .F10
    case win32.VK_F11: return .F11
    case win32.VK_F12: return .F12
    case win32.VK_OEM_3: return .Backtick
    case win32.VK_OEM_MINUS: return .Minus
    case win32.VK_OEM_PLUS: return .Equal
    case win32.VK_BACK: return .Backspace
    case win32.VK_TAB: return .Tab
    case win32.VK_CAPITAL: return .Caps_Lock
    case win32.VK_RETURN: return .Enter
    case win32.VK_LSHIFT: return .Left_Shift
    case win32.VK_RSHIFT: return .Right_Shift
    case win32.VK_LCONTROL: return .Left_Control
    case win32.VK_RCONTROL: return .Right_Control
    case win32.VK_LMENU: return .Left_Alt
    case win32.VK_RMENU: return .Right_Alt
    case win32.VK_LWIN: return .Left_Meta
    case win32.VK_RWIN: return .Right_Meta
    case win32.VK_OEM_4: return .Left_Bracket
    case win32.VK_OEM_6: return .Right_Bracket
    case win32.VK_SPACE: return .Space
    case win32.VK_ESCAPE: return .Escape
    case win32.VK_OEM_5: return .Backslash
    case win32.VK_OEM_1: return .Semicolon
    case win32.VK_OEM_7: return .Apostrophe
    case win32.VK_OEM_COMMA: return .Comma
    case win32.VK_OEM_PERIOD: return .Period
    case win32.VK_OEM_2: return .Slash
    case win32.VK_SCROLL: return .Scroll_Lock
    case win32.VK_PAUSE: return .Pause
    case win32.VK_INSERT: return .Insert
    case win32.VK_END: return .End
    case win32.VK_PRIOR: return .Page_Up
    case win32.VK_DELETE: return .Delete
    case win32.VK_HOME: return .Home
    case win32.VK_NEXT: return .Page_Down
    case win32.VK_LEFT: return .Left_Arrow
    case win32.VK_RIGHT: return .Right_Arrow
    case win32.VK_DOWN: return .Down_Arrow
    case win32.VK_UP: return .Up_Arrow
    case win32.VK_NUMLOCK: return .Num_Lock
    case win32.VK_DIVIDE: return .Pad_Divide
    case win32.VK_MULTIPLY: return .Pad_Multiply
    case win32.VK_SUBTRACT: return .Pad_Subtract
    case win32.VK_ADD: return .Pad_Add
    case win32.VK_DECIMAL: return .Pad_Decimal
    case win32.VK_PRINT: return .Print_Screen
    }
    return .Unknown
}