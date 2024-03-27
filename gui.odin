package main

import "base:runtime"
import "base:intrinsics"
import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import "core:slice"
import "core:strings"
import text_edit "core:text/edit"
import utf8 "core:unicode/utf8"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "pugl"

@(thread_local) _current_window: ^Window
@(thread_local) _window_count: int
@(thread_local) _open_gl_is_loaded: bool
@(thread_local) _pugl_world: ^pugl.World
@(thread_local) _gui_odin_context: runtime.Context

PI :: math.PI

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

Vector2 :: [2]f32
Color :: [4]f32

//==========================================================================
// Window
//==========================================================================

Window_Child_Kind :: enum {
    None,
    Embedded,
    Transient,
}

Window :: struct {
    update: proc(),

    background_color: Color,

    title: string,
    position: Vector2,
    size: Vector2,
    min_size: Maybe(Vector2),
    max_size: Maybe(Vector2),
    swap_interval: int,
    is_visible: bool,
    dark_mode: bool,
    is_resizable: bool,
    double_buffer: bool,
    child_kind: Window_Child_Kind,
    parent_handle: rawptr,

    close_pending: bool,
    close_button_pressed: bool,
    was_open: bool,

    timer_id: uintptr,
    view: ^pugl.View,

    nvg_ctx: ^nvg.Context,

    global_mouse_position: Vector2,
    previous_global_mouse_position: Vector2,

    screen_mouse_position: Vector2,
    previous_screen_mouse_position: Vector2,

    mouse_repeat_ticks: [Mouse_Button]time.Tick,
    mouse_repeat_counts: [Mouse_Button]int,
    mouse_repeat_start_position: Vector2,

    mouse_down: [Mouse_Button]bool,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,

    mouse_wheel: Vector2,

    key_down: [Keyboard_Key]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_repeats: [dynamic]Keyboard_Key,

    text_input: strings.Builder,

    keyboard_focus: Gui_Id,
    mouse_hit: Gui_Id,
    mouse_hover: Gui_Id,
    previous_mouse_hover: Gui_Id,
    mouse_hover_capture: Gui_Id,
    final_mouse_hover_request: Gui_Id,

    loaded_fonts: map[string]struct{},

    local_offset_stack: [dynamic]Vector2,
    global_offset_stack: [dynamic]Vector2,
    global_clip_rect_stack: [dynamic]Rectangle,
}

poll_events :: proc() {
    _gui_odin_context = context
    if _pugl_world == nil do return
    pugl.Update(_pugl_world, 0)
}

current_window :: proc {
    _current_window_base,
    _current_window_typeid,
}

window_init :: proc(window: ^Window, allocator := context.allocator) -> runtime.Allocator_Error {
    window.loaded_fonts = make(map[string]struct{}, allocator = allocator) or_return
    _reset_window_input(window)
    window.size = {400, 300}
    window.swap_interval = 0
    window.dark_mode = true
    window.is_visible = true
    window.is_resizable = true
    window.double_buffer = true
    window.child_kind = .None
    return nil
}

window_destroy :: proc(window: ^Window) {
    _force_close_window(window)
    delete(window.loaded_fonts)
}

window_open :: proc(window: ^Window) {
    if window_is_open(window) do return

    if _window_count == 0 {
        when ODIN_BUILD_MODE == .Dynamic {
            world_type := pugl.WorldType.MODULE
        } else {
            world_type := pugl.WorldType.PROGRAM
        }
        _pugl_world = pugl.NewWorld(world_type, {})

        _generate_world_id :: proc "contextless" () -> u64 {
            @(static) id: u64
            return 1 + intrinsics.atomic_add(&id, 1)
        }

        world_id := fmt.aprint("WindowThread", _generate_world_id(), context.temp_allocator)
        world_id_cstring := strings.clone_to_cstring(world_id, context.temp_allocator)

        pugl.SetWorldString(_pugl_world, .CLASS_NAME, world_id_cstring)
    }

    _window_count += 1

    if window.parent_handle != nil && window.child_kind == .None {
        window.child_kind = .Embedded
    }

    view := pugl.NewView(_pugl_world)

    title_cstring, err := strings.clone_to_cstring(window.title, context.temp_allocator)
    if err != nil {
        return
    }

    pugl.SetViewString(view, .WINDOW_TITLE, title_cstring)
    pugl.SetSizeHint(view, .DEFAULT_SIZE, u16(window.size.x), u16(window.size.y))

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

    pugl.SetViewHint(view, .CONTEXT_VERSION_MAJOR, OPENGL_VERSION_MAJOR)
    pugl.SetViewHint(view, .CONTEXT_VERSION_MINOR, OPENGL_VERSION_MINOR)

    #partial switch window.child_kind {
    case .Embedded:
        pugl.SetParentWindow(view, cast(uintptr)window.parent_handle)
    case .Transient:
        pugl.SetTransientParent(view, cast(uintptr)window.parent_handle)
    }

    pugl.SetHandle(view, window)
    pugl.SetEventFunc(view, _pugl_event_proc)

    status := pugl.Realize(view)
    if status != .SUCCESS {
        pugl.FreeView(view)
        fmt.eprintln(pugl.Strerror(status))
        return
    }

    window.view = view

    pugl.SetPosition(view, c.int(window.position.x), c.int(window.position.y))

    if window.is_visible {
        pugl.Show(view, .RAISE)
    }

    pugl.EnterContext(view)

    if !_open_gl_is_loaded {
        gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, pugl.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

window_enter_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

window_is_open :: proc(window := _current_window) -> bool {
    return window.view != nil
}

window_opened :: proc(window := _current_window) -> bool {
    return window_is_open(window) && !window.was_open
}

window_close :: proc(window := _current_window) {
    window.close_pending = true
}

window_close_button_pressed :: proc(window := _current_window) -> bool {
    return window.close_button_pressed
}

window_background_color :: proc(window := _current_window) -> Color {
    return window.background_color
}

window_set_background_color :: proc(color: Color, window := _current_window) {
    window.background_color = color
}

window_is_visible :: proc(window := _current_window) -> bool {
    if window.view != nil {
        return pugl.GetVisible(window.view)
    } else {
        return window.is_visible
    }
}

window_set_visibility :: proc(visibility: bool, window := _current_window) {
    if window.view != nil {
        if visibility {
            pugl.Show(window.view, .RAISE)
        } else {
            pugl.Hide(window.view)
        }
    }
    window.is_visible = visibility
}

window_position :: proc(window := _current_window) -> Vector2 {
    if window.view != nil {
        frame := pugl.GetFrame(window.view)
        return {f32(frame.x), f32(frame.y)}
    } else {
        return window.position
    }
}

window_set_position :: proc(position: Vector2, window := _current_window) {
    if window.view != nil {
        pugl.SetPosition(window.view, c.int(position.x), c.int(position.y))
        pugl.EnterContext(window.view)
    } else {
        window.position = position
    }
}

window_size :: proc(window := _current_window) -> Vector2 {
    if window.view != nil {
        frame := pugl.GetFrame(window.view)
        return {f32(frame.width), f32(frame.height)}
    } else {
        return window.size
    }
}

window_set_size :: proc(size: Vector2, window := _current_window) {
    if window.view != nil {
        pugl.SetSize(window.view, c.uint(size.x), c.uint(size.y))
        pugl.EnterContext(window.view)
    } else {
        window.size = size
    }
}

window_content_scale :: proc(window := _current_window) -> Vector2 {
    value := f32(pugl.GetScaleFactor(window.view))
    return {value, value}
}

pixel_size :: proc() -> Vector2 {
    return 1.0 / window_content_scale()
}

pixel_snapped :: proc(position: Vector2) -> Vector2 {
    pixel := pixel_size()
    return {
        math.round(position.x / pixel.x) * pixel.x,
        math.round(position.y / pixel.y) * pixel.y,
    }
}

_current_window_base :: proc() -> ^Window {
    return _current_window
}

_current_window_typeid :: proc($T: typeid) -> ^T {
    return cast(^T)_current_window
}

_force_close_window :: proc(window: ^Window) {
    if !window_is_open(window) do return

    pugl.EnterContext(window.view)

    nvg_gl.Destroy(window.nvg_ctx)
    window.nvg_ctx = nil

    pugl.Unrealize(window.view)
    pugl.FreeView(window.view)

    window.view = nil

    _window_count -= 1
    if _window_count == 0 {
        pugl.FreeWorld(_pugl_world)
        _pugl_world = nil
    }
}

_update_window :: proc(window: ^Window) {
    window.local_offset_stack = make([dynamic]Vector2, context.temp_allocator)
    window.global_offset_stack = make([dynamic]Vector2, context.temp_allocator)
    window.global_clip_rect_stack = make([dynamic]Rectangle, context.temp_allocator)

    pugl.EnterContext(window.view)

    size := window.size
    gl.Viewport(0, 0, i32(size.x), i32(size.y))

    bg := window.background_color
    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    scale := window_content_scale(window)
    nvg.BeginFrame(window.nvg_ctx, size.x, size.y, scale.x)

    if window.update != nil {
        window.update()
    }

    nvg.EndFrame(window.nvg_ctx)

    pugl.PostRedisplay(window.view)

    window.previous_mouse_hover = window.mouse_hover
    window.mouse_hover = 0
    window.mouse_hit = 0

    mouse_hover_request := window.final_mouse_hover_request
    if mouse_hover_request != 0 {
        window.mouse_hover = mouse_hover_request
        window.mouse_hit = mouse_hover_request
    }

    if window.mouse_hover_capture != 0 {
        window.mouse_hover = window.mouse_hover_capture
    }

    window.final_mouse_hover_request = 0

    _reset_window_input(window)
    window.was_open = window_is_open(window)

    if window.close_pending {
        _force_close_window(window)
        window.close_pending = false
    }
}

_pugl_event_proc :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    window := cast(^Window)pugl.GetHandle(view)
    window.view = view
    context = _gui_odin_context
    _current_window = window

    #partial switch event.type {
    case .UPDATE:
        _update_window(window)

    case .LOOP_ENTER:
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        event := event.timer
        if window.timer_id == event.id {
            poll_events()
        }

    case .CONFIGURE:
        event := event.configure
        last_size := window.size
        window.position = Vector2{f32(event.x), f32(event.y)}
        window.size = Vector2{f32(event.width), f32(event.height)}
        if window.size != last_size {
            _update_window(window)
        }

    case .POINTER_IN:
        _update_window(window)

    case .POINTER_OUT:
        _update_window(window)

    case .MOTION:
        event := event.motion
        _input_mouse_move(window, {f32(event.x), f32(event.y)})
        _update_window(window)

    case .SCROLL:
        event := &event.scroll
        _input_mouse_scroll(window, {f32(event.dx), f32(event.dy)})
        _update_window(window)

    case .BUTTON_PRESS:
        event := &event.button
        _input_mouse_press(window, _pugl_button_to_mouse_button(event.button))
        _update_window(window)

    case .BUTTON_RELEASE:
        event := &event.button
        _input_mouse_release(window, _pugl_button_to_mouse_button(event.button))
        _update_window(window)

    case .KEY_PRESS:
        event := &event.key
        _input_key_press(window, _pugl_key_event_to_keyboard_key(event))
        _update_window(window)

    case .KEY_RELEASE:
        event := &event.key
        _input_key_release(window, _pugl_key_event_to_keyboard_key(event))
        _update_window(window)

    case .TEXT:
        event := &event.text

        // Filter out unnecessary characters.
        skip := false
        switch event.character {
        case 0..<32, 127: skip = true
        }

        if !skip {
            r, len := utf8.decode_rune(event.string[:4])
            _input_text(window, r)
            _update_window(window)
        }

    case .CLOSE:
        window.close_button_pressed = true
        _update_window(window)
        window.close_button_pressed = false
    }

    return .SUCCESS
}

//==========================================================================
// Input
//==========================================================================

Mouse_Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
    Scroll,
}

Mouse_Button :: enum {
    Unknown,
    Left, Middle, Right,
    Extra_1, Extra_2,
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
    Escape, Backslash, Semicolon, Apostrophe,
    Comma, Period, Slash, Scroll_Lock,
    Pause, Insert, End, Page_Up, Delete,
    Home, Page_Down, Left_Arrow, Right_Arrow,
    Down_Arrow, Up_Arrow, Num_Lock, Pad_Divide,
    Pad_Multiply, Pad_Subtract, Pad_Add, Pad_Enter,
    Pad_Decimal, Print_Screen,
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) {
    pugl.SetCursor(_current_window.view, _cursor_style_to_pugl_cursor(style))
}

get_clipboard :: proc() -> string {
    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(_current_window.view, 0, &length)
    if clipboard_cstring == nil {
        return ""
    }
    return string(clipboard_cstring)
}

set_clipboard :: proc(data: string) {
    data_cstring, err := strings.clone_to_cstring(data, context.temp_allocator)
    if err != nil do return
    pugl.SetClipboard(_current_window.view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1)
}

mouse_position :: proc() -> (res: Vector2) {
    return _current_window.global_mouse_position - global_offset()
}

mouse_delta :: proc() -> Vector2 {
    return _current_window.global_mouse_position - _current_window.previous_global_mouse_position
}

global_mouse_position :: proc() -> (res: Vector2) {
    return _current_window.global_mouse_position
}

screen_mouse_position :: proc() -> Vector2 {
    return _current_window.screen_mouse_position
}

screen_mouse_delta :: proc() -> Vector2 {
    return _current_window.screen_mouse_position - _current_window.previous_screen_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return _current_window.mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return _current_window.key_down[key]
}

mouse_wheel :: proc() -> Vector2 {
    return _current_window.mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

screen_mouse_moved :: proc() -> bool {
    return screen_mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return _current_window.mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(_current_window.mouse_presses[:], button)
}

mouse_repeat_count :: proc(button: Mouse_Button) -> int {
    return _current_window.mouse_repeat_counts[button]
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(_current_window.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(_current_window.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(_current_window.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    return slice.contains(_current_window.key_presses[:], key) ||
           repeating && slice.contains(_current_window.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(_current_window.key_releases[:], key)
}

any_key_pressed :: proc(repeating := false) -> bool {
    if repeating {
        return len(_current_window.key_repeats) > 0
    } else {
        return len(_current_window.key_presses) > 0
    }
}

any_key_released :: proc() -> bool {
    return len(_current_window.key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return _current_window.key_repeats[:]
    } else {
        return _current_window.key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return _current_window.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(_current_window.text_input)
}

_input_mouse_move :: proc(window: ^Window, position: Vector2) {
    window.global_mouse_position = position
    window.screen_mouse_position = position + window_position(window)
}

_input_mouse_press :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = true
    previous_mouse_repeat_tick := window.mouse_repeat_ticks[button]

    window.mouse_repeat_ticks[button] = time.tick_now()

    delta := time.tick_diff(previous_mouse_repeat_tick, window.mouse_repeat_ticks[button])
    if delta <= 300 * time.Millisecond {
        window.mouse_repeat_counts[button] += 1
    } else {
        window.mouse_repeat_counts[button] = 1
    }

    TOLERANCE :: 3
    movement := mouse_position() - window.mouse_repeat_start_position
    if abs(movement.x) > TOLERANCE || abs(movement.y) > TOLERANCE {
        window.mouse_repeat_counts[button] = 1
    }

    if window.mouse_repeat_counts[button] == 1 {
        window.mouse_repeat_start_position = mouse_position()
    }

    append(&window.mouse_presses, button)
}

_input_mouse_release :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = false
    append(&window.mouse_releases, button)
}

_input_mouse_scroll :: proc(window: ^Window, amount: Vector2) {
    window.mouse_wheel = amount
}

_input_key_press :: proc(window: ^Window, key: Keyboard_Key) {
    already_down := window.key_down[key]
    window.key_down[key] = true
    if !already_down {
        append(&window.key_presses, key)
    }
    append(&window.key_repeats, key)
}

_input_key_release :: proc(window: ^Window, key: Keyboard_Key) {
    window.key_down[key] = false
    append(&window.key_releases, key)
}

_input_text :: proc(window: ^Window, text: rune) {
    strings.write_rune(&window.text_input, text)
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

_cursor_style_to_pugl_cursor :: proc(style: Mouse_Cursor_Style) -> pugl.Cursor {
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

_reset_window_input :: proc(window: ^Window) {
    window.previous_global_mouse_position = window.global_mouse_position
    window.previous_screen_mouse_position = window.screen_mouse_position
    window.mouse_presses = make([dynamic]Mouse_Button, context.temp_allocator)
    window.mouse_releases = make([dynamic]Mouse_Button, context.temp_allocator)
    window.key_presses = make([dynamic]Keyboard_Key, context.temp_allocator)
    window.key_releases = make([dynamic]Keyboard_Key, context.temp_allocator)
    window.key_repeats = make([dynamic]Keyboard_Key, context.temp_allocator)
    strings.builder_init(&window.text_input, context.temp_allocator)
}

//==========================================================================
// Text
//==========================================================================

Font :: struct {
    name: string,
    size: int,
    data: []byte,
}

Font_Metrics :: struct {
    ascender: f32,
    descender: f32,
    line_height: f32,
}

Text_Glyph :: struct {
    byte_index: int,
    position: f32,
    width: f32,
    kerning: f32,
}

fill_text :: proc(text: string, position: Vector2, font: Font, color: Color) {
    window := current_window()
    nvg_ctx := window.nvg_ctx
    _load_font(window, font)
    position := pixel_snapped(position)
    nvg.Save(nvg_ctx)
    offset := global_offset()
    nvg.Translate(nvg_ctx, offset.x, offset.y)
    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    nvg.FillColor(nvg_ctx, color)
    nvg.Text(nvg_ctx, position.x, position.y, text)
    nvg.Restore(nvg_ctx)
}

measure_text :: proc(
    text: string,
    font: Font,
    glyphs: ^[dynamic]Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) {
    window := current_window()
    nvg_ctx := window.nvg_ctx

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    _load_font(window, font)

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), context.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        if byte_index_to_rune_index != nil {
            byte_index_to_rune_index[nvg_positions[i].str] = i
        }
        glyphs[i] = Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics) {
    window := current_window()
    nvg_ctx := window.nvg_ctx
    _load_font(window, font)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)
    pixel_height := pixel_size().y
    metrics.line_height = math.ceil(metrics.line_height / pixel_height) * pixel_height
    return
}

_load_font :: proc(window: ^Window, font: Font) {
    if len(font.data) <= 0 do return
    if font.name not_in window.loaded_fonts {
        if nvg.CreateFontMem(window.nvg_ctx, font.name, font.data, false) == -1 {
            fmt.eprintf("Failed to load font: %v\n", font.name)
        } else {
            window.loaded_fonts[font.name] = {}
        }
    }
}

//==========================================================================
// Paths
//==========================================================================

KAPPA :: 0.5522847493

Sub_Path :: struct {
    is_closed: bool,
    points: [dynamic]Vector2,
}

Path :: struct {
    sub_paths: [dynamic]Sub_Path,
    allocator: runtime.Allocator,
}

temp_path :: proc() -> (res: Path) {
    path_init(&res, context.temp_allocator)
    return
}

fill_path :: proc(path: Path, color: Color) {
    nvg_ctx := current_window().nvg_ctx

    nvg.Save(nvg_ctx)

    offset := global_offset()
    nvg.Translate(nvg_ctx, offset.x, offset.y)

    nvg.BeginPath(nvg_ctx)

    for sub_path in path.sub_paths {
        nvg.MoveTo(nvg_ctx, sub_path.points[0].x, sub_path.points[0].y)

        for i := 1; i < len(sub_path.points); i += 3 {
            c1 := sub_path.points[i]
            c2 := sub_path.points[i + 1]
            point := sub_path.points[i + 2]
            nvg.BezierTo(nvg_ctx,
                c1.x, c1.y,
                c2.x, c2.y,
                point.x, point.y,
            )
        }

        if sub_path.is_closed {
            nvg.ClosePath(nvg_ctx)
        }
    }

    nvg.FillColor(nvg_ctx, color)
    nvg.Fill(nvg_ctx)

    nvg.Restore(nvg_ctx)
}

path_init :: proc(path: ^Path, allocator := context.allocator) -> runtime.Allocator_Error {
    path.sub_paths = make([dynamic]Sub_Path, allocator = allocator) or_return
    path.allocator = allocator
    return nil
}

path_destroy :: proc(path: ^Path) {
    for sub_path in path.sub_paths {
        delete(sub_path.points)
    }
    delete(path.sub_paths)
}

// Closes the current sub-path.
path_close :: proc(path: ^Path) {
    path.sub_paths[len(path.sub_paths) - 1].is_closed = true
}

// Translates all points in the path by the given amount.
path_translate :: proc(path: ^Path, amount: Vector2) {
    for &sub_path in path.sub_paths {
        for &point in sub_path.points {
            point += amount
        }
    }
}

// Starts a new sub-path with the specified point as the first point.
path_move_to :: proc(path: ^Path, point: Vector2) {
    sub_path: Sub_Path
    sub_path.points = make([dynamic]Vector2, allocator = path.allocator)
    append(&sub_path.points, point)
    append(&path.sub_paths, sub_path)
}

// Adds a line segment from the last point in the path to the specified point.
path_line_to :: proc(path: ^Path, point: Vector2) {
    if len(path.sub_paths) <= 0 do return
    sub_path := &path.sub_paths[len(path.sub_paths) - 1]
    append(&sub_path.points, _sub_path_previous_point(sub_path), point, point)
}

// Adds a cubic bezier segment from the last point in the path via two control points to the specified point.
path_bezier_to :: proc(path: ^Path, control_start, control_end, point: Vector2) {
    if len(path.sub_paths) <= 0 do return
    sub_path := &path.sub_paths[len(path.sub_paths) - 1]
    append(&sub_path.points, control_start, control_end, point)
}

// Adds a quadratic bezier segment from the last point in the path via a control point to the specified point.
path_quad_to :: proc(path: ^Path, control, point: Vector2) {
    previous := _path_previous_point(path)
    path_bezier_to(path,
        previous + 2 / 3 * (control - previous),
        point + 2 / 3 * (control - point),
        point,
    )
}

// Adds a circlular arc shaped sub-path. Angles are in radians.
path_arc :: proc(
    path: ^Path,
    center: Vector2,
    radius: f32,
    start_angle, end_angle: f32,
    counterclockwise := false,
) {
    _path_arc(path, center.x, center.y, radius, start_angle, end_angle, counterclockwise)
}

// Adds an arc segment at the corner defined by the last path point, and two control points.
path_arc_to :: proc(path: ^Path, control1: Vector2, control2: Vector2, radius: f32) {
    _path_arc_to(path, control1.x, control1.y, control2.x, control2.y, radius)
}

// Adds a new rectangle shaped sub-path.
path_rectangle :: proc(path: ^Path, rectangle: Rectangle) {
    _path_rectangle(path, rectangle.x, rectangle.y, rectangle.size.x, rectangle.size.y)
}

// Adds a new rounded rectangle shaped sub-path.
path_rounded_rectangle :: proc(
    path: ^Path,
    rectangle: Rectangle,
    radius: f32,
) {
    path_rounded_rectangle_varying(path, rectangle, radius, radius, radius, radius)
}

// Adds a new rounded rectangle shaped sub-path with varying radii for each corner.
path_rounded_rectangle_varying :: proc(
    path: ^Path,
    rectangle: Rectangle,
    radius_top_left: f32,
    radius_top_right: f32,
    radius_bottom_right: f32,
    radius_bottom_left: f32,
) {
    _path_rounded_rect_varying(path,
        rectangle.x, rectangle.y,
        rectangle.size.x, rectangle.size.y,
        radius_top_left,
        radius_top_right,
        radius_bottom_right,
        radius_bottom_left,
    )
}

// Adds an ellipse shaped sub-path.
path_ellipse :: proc(path: ^Path, center, radius: Vector2) {
    _path_ellipse(path, center.x, center.y, radius.x, radius.y)
}

// Adds a circle shaped sub-path.
path_circle :: proc(path: ^Path, center: Vector2, radius: f32) {
    _path_circle(path, center.x, center.y, radius)
}

path_hit_test :: proc(path: ^Path, point: Vector2, tolerance: f32 = 0.25) -> bool {
    for &sub_path in path.sub_paths {
        if sub_path_hit_test(&sub_path, point, tolerance) {
            return true
        }
    }
    return false
}

sub_path_hit_test :: proc(sub_path: ^Sub_Path, point: Vector2, tolerance: f32) -> bool {
    if len(sub_path.points) <= 0 do return false

    crossings := 0

    downward_ray_end := point + {0, 1e6}

    for i := 1; i < len(sub_path.points); i += 3 {
        p1 := sub_path.points[i - 1]
        c1 := sub_path.points[i]
        c2 := sub_path.points[i + 1]
        p2 := sub_path.points[i + 2]

        if _, ok := bezier_and_line_segment_collision(p1, c1, c2, p2, point, downward_ray_end, 0, tolerance); ok {
            crossings += 1
        }
    }

    start_point := sub_path.points[0]
    final_point := sub_path.points[len(sub_path.points) - 1]

    if _, ok := line_segment_collision(point, downward_ray_end, start_point, final_point); ok {
        crossings += 1
    }

    return crossings > 0 && crossings % 2 != 0
}

line_segment_collision :: proc(a0, a1, b0, b1: Vector2) -> (collision: Vector2, ok: bool) {
    div := (b1.y - b0.y) * (a1.x - a0.x) - (b1.x - b0.x) * (a1.y - a0.y)

    if abs(div) >= math.F32_EPSILON {
        ok = true

        xi := ((b0.x - b1.x) * (a0.x * a1.y - a0.y * a1.x) - (a0.x - a1.x) * (b0.x * b1.y - b0.y * b1.x)) / div
        yi := ((b0.y - b1.y) * (a0.x * a1.y - a0.y * a1.x) - (a0.y - a1.y) * (b0.x * b1.y - b0.y * b1.x)) / div

        if (abs(a0.x - a1.x) > math.F32_EPSILON && (xi < min(a0.x, a1.x) || xi > max(a0.x, a1.x))) ||
           (abs(b0.x - b1.x) > math.F32_EPSILON && (xi < min(b0.x, b1.x) || xi > max(b0.x, b1.x))) ||
           (abs(a0.y - a1.y) > math.F32_EPSILON && (yi < min(a0.y, a1.y) || yi > max(a0.y, a1.y))) ||
           (abs(b0.y - b1.y) > math.F32_EPSILON && (yi < min(b0.y, b1.y) || yi > max(b0.y, b1.y))) {
            ok = false
        }

        if ok && collision != 0 {
            collision.x = xi
            collision.y = yi
        }
    }

    return
}

bezier_and_line_segment_collision :: proc(
    start: Vector2,
    control_start: Vector2,
    control_finish: Vector2,
    finish: Vector2,
    segment_start: Vector2,
    segment_finish: Vector2,
    level: int,
    tolerance: f32,
) -> (collision: Vector2, ok: bool) {
    if level > 10 {
        return
    }

    x12 := (start.x + control_start.x) * 0.5
    y12 := (start.y + control_start.y) * 0.5
    x23 := (control_start.x + control_finish.x) * 0.5
    y23 := (control_start.y + control_finish.y) * 0.5
    x34 := (control_finish.x + finish.x) * 0.5
    y34 := (control_finish.y + finish.y) * 0.5
    x123 := (x12 + x23) * 0.5
    y123 := (y12 + y23) * 0.5

    dx := finish.x - start.x
    dy := finish.y - start.y
    d2 := abs(((control_start.x - finish.x) * dy - (control_start.y - finish.y) * dx))
    d3 := abs(((control_finish.x - finish.x) * dy - (control_finish.y - finish.y) * dx))

    if (d2 + d3) * (d2 + d3) < tolerance * (dx * dx + dy * dy) {
        return line_segment_collision(segment_start, segment_finish, {start.x, start.y}, {finish.x, finish.y})
    }

    x234 := (x23 + x34) * 0.5
    y234 := (y23 + y34) * 0.5
    x1234 := (x123 + x234) * 0.5
    y1234 := (y123 + y234) * 0.5

    if collision, ok := bezier_and_line_segment_collision(start, {x12, y12}, {x123, y123}, {x1234, y1234}, segment_start, segment_finish, level + 1, tolerance); ok {
        return collision, ok
    }
    if collision, ok := bezier_and_line_segment_collision({x1234, y1234}, {x234, y234}, {x34, y34}, finish, segment_start, segment_finish, level + 1, tolerance); ok {
        return collision, ok
    }

    return {}, false
}

_sub_path_previous_point :: #force_inline proc(sub_path: ^Sub_Path) -> Vector2 {
    return sub_path.points[len(sub_path.points) - 1]
}

_path_previous_point :: #force_inline proc(path: ^Path) -> Vector2 {
    if len(path.sub_paths) <= 0 do return {0, 0}
    return _sub_path_previous_point(&path.sub_paths[len(path.sub_paths) - 1])
}

_path_close :: path_close

_path_move_to :: proc(path: ^Path, x, y: f32) {
    path_move_to(path, {x, y})
}

_path_line_to :: proc(path: ^Path, x, y: f32) {
    path_line_to(path, {x, y})
}

_path_bezier_to :: proc(path: ^Path, c1x, c1y, c2x, c2y, x, y: f32) {
    path_bezier_to(path, {c1x, c1y}, {c2x, c2y}, {x, y})
}

_path_quad_to :: proc(path: ^Path, cx, cy, x, y: f32) {
    path_quad_to(path, {cx, cy}, {x, y})
}

_path_arc :: proc(path: ^Path, cx, cy, r, a0, a1: f32, counterclockwise: bool) {
    use_move_to := len(path.sub_paths) <= 0 || path.sub_paths[len(path.sub_paths) - 1].is_closed

    // Clamp angles
    da := a1 - a0
    if !counterclockwise {
        if abs(da) >= math.PI*2 {
            da = math.PI*2
        } else {
            for da < 0.0 {
                da += math.PI*2
            }
        }
    } else {
        if abs(da) >= math.PI*2 {
            da = -math.PI*2
        } else {
            for da > 0.0 {
                da -= math.PI*2
            }
        }
    }

    // Split arc into max 90 degree segments.
    ndivs := max(1, min((int)(abs(da) / (math.PI*0.5) + 0.5), 5))
    hda := (da / f32(ndivs)) / 2.0
    kappa := abs(4.0 / 3.0 * (1.0 - math.cos(hda)) / math.sin(hda))

    if counterclockwise {
        kappa = -kappa
    }

    px, py, ptanx, ptany: f32
    for i in 0..=ndivs {
        a := a0 + da * f32(i) / f32(ndivs)
        dx := math.cos(a)
        dy := math.sin(a)
        x := cx + dx*r
        y := cy + dy*r
        tanx := -dy*r*kappa
        tany := dx*r*kappa

        if i == 0 {
            if use_move_to {
                _path_move_to(path, x, y)
            } else {
                _path_line_to(path, x, y)
            }
        } else {
            _path_bezier_to(path,
                px + ptanx, py + ptany,
                x - tanx, y - tany,
                x, y,
            )
        }

        px = x
        py = y
        ptanx = tanx
        ptany = tany
    }
}

_path_arc_to :: proc(
    path: ^Path,
    x1, y1: f32,
    x2, y2: f32,
    radius: f32,
) {
    if len(path.sub_paths) <= 0 do return

    previous := _path_previous_point(path)

    x0 := previous.x
    y0 := previous.y

    __ptEquals :: proc(x0, y0, x1, y1: f32) -> bool {
        return x0 == x1 && y0 == y1
    }

    __distPtSeg :: proc(x, y, px, py, qx, qy: f32) -> f32 {
        pqx := qx - px
        pqy := qy - py
        dx := x - px
        dy := y - py
        d := pqx * pqx + pqy * pqy
        t := pqx * dx + pqy * dy

        if d > 0 {
            t /= d
        }
        t = clamp(t, 0, 1)

        dx = px + t * pqx - x
        dy = py + t * pqy - y
        return dx * dx + dy * dy
    }

    // Handle degenerate cases.
    if __ptEquals(x0,y0, x1,y1) ||
       __ptEquals(x1,y1, x2,y2) ||
       __distPtSeg(x1,y1, x0,y0, x2,y2) <= 0 ||
        radius <= 0 {
        _path_line_to(path, x1, y1)
        return
    }

    __normalize :: proc(x, y: ^f32) -> f32 {
        d := math.sqrt(x^ * x^ + y^ * y^)
        if d > 1e-6 {
            id := 1.0 / d
            x^ *= id
            y^ *= id
        }
        return d
    }

    // Calculate tangential circle to lines (x0,y0)-(x1,y1) and (x1,y1)-(x2,y2).
    dx0 := x0-x1
    dy0 := y0-y1
    dx1 := x2-x1
    dy1 := y2-y1
    __normalize(&dx0,&dy0)
    __normalize(&dx1,&dy1)
    a := math.acos(dx0*dx1 + dy0*dy1)
    d := radius / math.tan(a / 2.0)

    if d > 10000 {
        _path_line_to(path, x1, y1)
        return
    }

    a0, a1, cx, cy: f32
    counterclockwise: bool

    __cross :: proc(dx0, dy0, dx1, dy1: f32) -> f32 {
        return dx1*dy0 - dx0*dy1
    }

    if __cross(dx0,dy0, dx1,dy1) > 0.0 {
        cx = x1 + dx0*d + dy0*radius
        cy = y1 + dy0*d + -dx0*radius
        a0 = math.atan2(dx0, -dy0)
        a1 = math.atan2(-dx1, dy1)
        counterclockwise = false
    } else {
        cx = x1 + dx0*d + -dy0*radius
        cy = y1 + dy0*d + dx0*radius
        a0 = math.atan2(-dx0, dy0)
        a1 = math.atan2(dx1, -dy1)
        counterclockwise = true
    }

    _path_arc(path, cx, cy, radius, a0, a1, counterclockwise)
}

_path_rectangle :: proc(path: ^Path, x, y, w, h: f32) {
    _path_move_to(path, x, y)
    _path_line_to(path, x, y + h)
    _path_line_to(path, x + w, y + h)
    _path_line_to(path, x + w, y)
    _path_close(path)
}

_path_rounded_rect_varying :: proc(
    path: ^Path,
    x, y: f32,
    w, h: f32,
    radius_top_left: f32,
    radius_top_right: f32,
    radius_bottom_right: f32,
    radius_bottom_left: f32,
) {
    if radius_top_left < 0.1 && radius_top_right < 0.1 && radius_bottom_right < 0.1 && radius_bottom_left < 0.1 {
        _path_rectangle(path, x, y, w, h)
    } else {
        halfw := abs(w) * 0.5
        halfh := abs(h) * 0.5
        rxBL := min(radius_bottom_left, halfw) * math.sign(w)
        ryBL := min(radius_bottom_left, halfh) * math.sign(h)
        rxBR := min(radius_bottom_right, halfw) * math.sign(w)
        ryBR := min(radius_bottom_right, halfh) * math.sign(h)
        rxTR := min(radius_top_right, halfw) * math.sign(w)
        ryTR := min(radius_top_right, halfh) * math.sign(h)
        rxTL := min(radius_top_left, halfw) * math.sign(w)
        ryTL := min(radius_top_left, halfh) * math.sign(h)
        _path_move_to(path, x, y + ryTL)
        _path_line_to(path, x, y + h - ryBL)
        _path_bezier_to(path, x, y + h - ryBL*(1 - KAPPA), x + rxBL*(1 - KAPPA), y + h, x + rxBL, y + h)
        _path_line_to(path, x + w - rxBR, y + h)
        _path_bezier_to(path, x + w - rxBR*(1 - KAPPA), y + h, x + w, y + h - ryBR*(1 - KAPPA), x + w, y + h - ryBR)
        _path_line_to(path, x + w, y + ryTR)
        _path_bezier_to(path, x + w, y + ryTR*(1 - KAPPA), x + w - rxTR*(1 - KAPPA), y, x + w - rxTR, y)
        _path_line_to(path, x + rxTL, y)
        _path_bezier_to(path, x + rxTL*(1 - KAPPA), y, x, y + ryTL*(1 - KAPPA), x, y + ryTL)
        _path_close(path)
    }
}

_path_ellipse :: proc(path: ^Path, cx, cy, rx, ry: f32) {
    _path_move_to(path, cx-rx, cy)
    _path_bezier_to(path, cx-rx, cy+ry*KAPPA, cx-rx*KAPPA, cy+ry, cx, cy+ry)
    _path_bezier_to(path, cx+rx*KAPPA, cy+ry, cx+rx, cy+ry*KAPPA, cx+rx, cy)
    _path_bezier_to(path, cx+rx, cy-ry*KAPPA, cx+rx*KAPPA, cy-ry, cx, cy-ry)
    _path_bezier_to(path, cx-rx*KAPPA, cy-ry, cx-rx, cy-ry*KAPPA, cx-rx, cy)
    _path_close(path)
}

_path_circle :: #force_inline proc(path: ^Path, cx, cy: f32, radius: f32) {
    _path_ellipse(path, cx, cy, radius, radius)
}

//==========================================================================
// Rectangle
//==========================================================================

Rectangle :: struct {
    using position: Vector2,
    size: Vector2,
}

rectangle_trim_left :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, min_amount, rectangle.size.x), min_amount)
    rectangle.position.x += amount
    rectangle.size.x -= amount
    return {
        {rectangle.position.x - amount, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_peek_trim_left :: proc(rectangle: Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, min_amount, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_trim_right :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    rectangle.size.x -= amount
    return {
        {rectangle.position.x + rectangle.size.x, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_peek_trim_right :: proc(rectangle: Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x + rectangle.size.x - amount, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_trim_top :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    rectangle.position.y += amount
    rectangle.size.y -= amount
    return {
        {rectangle.position.x, rectangle.position.y - amount},
        {rectangle.size.x, amount},
    }
}

rectangle_peek_trim_top :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x, rectangle.position.y},
        {rectangle.size.x, amount},
    }
}

rectangle_trim_bottom :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    rectangle.size.y -= amount
    return {
        {rectangle.position.x, rectangle.position.y + rectangle.size.y},
        {rectangle.size.x, amount},
    }
}

rectangle_peek_trim_bottom :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x, rectangle.position.y + rectangle.size.y - amount},
        {rectangle.size.x, amount},
    }
}

rectangle_expanded :: proc(rectangle: Rectangle, amount: Vector2) -> Rectangle {
    return {
        position = {
            min(rectangle.position.x + rectangle.size.x * 0.5, rectangle.position.x - amount.x),
            min(rectangle.position.y + rectangle.size.y * 0.5, rectangle.position.y - amount.y),
        },
        size = {
            max(0, rectangle.size.x + amount.x * 2),
            max(0, rectangle.size.y + amount.y * 2),
        },
    }
}

rectangle_expand :: proc(rectangle: ^Rectangle, amount: Vector2) {
    rectangle^ = rectangle_expanded(rectangle^, amount)
}

rectangle_padded :: proc(rectangle: Rectangle, amount: Vector2) -> Rectangle {
    return rectangle_expanded(rectangle, -amount)
}

rectangle_pad :: proc(rectangle: ^Rectangle, amount: Vector2) {
    rectangle^ = rectangle_padded(rectangle^, amount)
}

rectangle_snapped :: proc(rectangle: Rectangle, increment: Vector2) -> Rectangle {
    return {
        {
            math.round(rectangle.position.x / increment.x) * increment.x,
            math.round(rectangle.position.y / increment.y) * increment.y,
        },
        {
            math.round(rectangle.size.x / increment.x) * increment.x,
            math.round(rectangle.size.y / increment.y) * increment.y,
        },
    }
}

rectangle_snap :: proc(rectangle: ^Rectangle, increment: Vector2) {
    rectangle^ = rectangle_snapped(rectangle^, increment)
}

rectangle_intersection :: proc(a, b: Rectangle) -> Rectangle {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)

    x1 := max(a.position.x, b.position.x)
    y1 := max(a.position.y, b.position.y)
    x2 := min(a.position.x + a.size.x, b.position.x + b.size.x)
    y2 := min(a.position.y + a.size.y, b.position.y + b.size.y)

    if x2 < x1 {
        x2 = x1
    }
    if y2 < y1 {
        y2 = y1
    }

    return {{x1, y1}, {x2 - x1, y2 - y1}}
}

rectangle_intersects :: proc(a, b: Rectangle, include_borders := false) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)

    if include_borders {
        if a.position.x > b.position.x + b.size.x {
            return false
        }
        if a.position.x + a.size.x < b.position.x {
            return false
        }
        if a.position.y > b.position.y + b.size.y {
            return false
        }
        if a.position.y + a.size.y < b.position.y {
            return false
        }
    } else {
        if a.position.x >= b.position.x + b.size.x {
            return false
        }
        if a.position.x + a.size.x <= b.position.x {
            return false
        }
        if a.position.y >= b.position.y + b.size.y {
            return false
        }
        if a.position.y + a.size.y <= b.position.y {
            return false
        }
    }

    return true
}

rectangle_encloses :: proc{
    rectangle_encloses_rect,
    rectangle_encloses_vector2,
}

rectangle_encloses_rect :: proc(a, b: Rectangle, include_borders := false) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)
    if include_borders {
        return b.position.x >= a.position.x &&
               b.position.y >= a.position.y &&
               b.position.x + b.size.x <= a.position.x + a.size.x &&
               b.position.y + b.size.y <= a.position.y + a.size.y
    } else {
        return b.position.x > a.position.x &&
               b.position.y > a.position.y &&
               b.position.x + b.size.x < a.position.x + a.size.x &&
               b.position.y + b.size.y < a.position.y + a.size.y
    }
}

rectangle_encloses_vector2 :: proc(a: Rectangle, b: Vector2, include_borders := false) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0)
    if include_borders {
        return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
               b.y >= a.position.y && b.y <= a.position.y + a.size.y
    } else {
        return b.x > a.position.x && b.x < a.position.x + a.size.x &&
               b.y > a.position.y && b.y < a.position.y + a.size.y
    }
}

rectangle_hit_test :: proc(a: Rectangle, b: Vector2) -> bool {
    return rectangle_encloses_vector2(a, b, include_borders = false) &&
           rectangle_encloses_vector2(clip_rectangle(), b, include_borders = false)
}

//==========================================================================
// Tools
//==========================================================================

Gui_Id :: u64

get_gui_id :: proc "contextless" () -> Gui_Id {
    @(static) id: Gui_Id
    return 1 + intrinsics.atomic_add(&id, 1)
}

mouse_hover :: proc() -> Gui_Id {
    return _current_window.mouse_hover
}

mouse_hover_entered :: proc() -> Gui_Id {
    if _current_window.mouse_hover != _current_window.previous_mouse_hover {
        return _current_window.mouse_hover
    } else {
        return 0
    }
}

mouse_hover_exited :: proc() -> Gui_Id {
    if _current_window.mouse_hover != _current_window.previous_mouse_hover {
        return _current_window.previous_mouse_hover
    } else {
        return 0
    }
}

mouse_hit :: proc() -> Gui_Id {
    return _current_window.mouse_hit
}

request_mouse_hover :: proc(id: Gui_Id) {
    _current_window.final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    _current_window.mouse_hover_capture = _current_window.final_mouse_hover_request
}

release_mouse_hover :: proc() {
    _current_window.mouse_hover_capture = 0
}

keyboard_focus :: proc() -> Gui_Id {
    return _current_window.keyboard_focus
}

set_keyboard_focus :: proc(id: Gui_Id) {
    _current_window.keyboard_focus = id
}

release_keyboard_focus :: proc() {
    _current_window.keyboard_focus = 0
}

// Local coordinates
offset :: proc() -> Vector2 {
    window := current_window()
    if len(window.local_offset_stack) <= 0 do return {0, 0}
    return window.local_offset_stack[len(window.local_offset_stack) - 1]
}

// Global coordinates
global_offset :: proc() -> Vector2 {
    window := current_window()
    if len(window.global_offset_stack) <= 0 do return {0, 0}
    return window.global_offset_stack[len(window.global_offset_stack) - 1]
}

// Set in local coordinates
begin_offset :: proc(offset: Vector2) {
    window := current_window()
    append(&window.local_offset_stack, offset)
    append(&window.global_offset_stack, global_offset() + offset)
}

end_offset :: proc() {
    window := current_window()
    if len(window.local_offset_stack) <= 0 ||
       len(window.global_offset_stack) <= 0 {
        return
    }
    pop(&window.local_offset_stack)
    pop(&window.global_offset_stack)
}

@(deferred_none=end_offset)
scoped_offset :: proc(offset: Vector2) {
    begin_offset(offset)
}

// Local coordinates
clip_rectangle :: proc() -> Rectangle {
    window := current_window()
    if len(window.global_clip_rect_stack) <= 0 do return {-global_offset(), window.size}
    global_rect := window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1]
    global_rect.position -= global_offset()
    return global_rect
}

// Global coordinates
global_clip_rectangle :: proc() -> Rectangle {
    window := current_window()
    if len(window.global_clip_rect_stack) <= 0 do return {{0, 0}, window.size}
    return window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1]
}

// Set in local coordinates
begin_clip :: proc(rectangle: Rectangle, intersect := true) {
    window := current_window()

    offset := global_offset()
    global_rect := Rectangle{offset + rectangle.position, rectangle.size}

    if intersect && len(window.global_clip_rect_stack) > 0 {
        global_rect = rectangle_intersection(global_rect, window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1])
    }

    append(&window.global_clip_rect_stack, global_rect)
    nvg.Scissor(window.nvg_ctx, global_rect.x, global_rect.y, global_rect.size.x, global_rect.size.y)
}

end_clip :: proc() {
    window := current_window()

    if len(window.global_clip_rect_stack) <= 0 {
        return
    }

    pop(&window.global_clip_rect_stack)

    if len(window.global_clip_rect_stack) <= 0 {
        return
    }

    global_rect := window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1]
    nvg.Scissor(window.nvg_ctx, global_rect.x, global_rect.y, global_rect.size.x, global_rect.size.y)
}

@(deferred_none=end_clip)
scoped_clip :: proc(rectangle: Rectangle, intersect := true) {
    begin_clip(rectangle, intersect = intersect)
}

//==========================================================================
// Button
//==========================================================================

Button_Base :: struct {
    id: Gui_Id,
    using rectangle: Rectangle,
    is_down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

button_base_init :: proc(button: ^Button_Base) {
    button.id = get_gui_id()
}

button_base_update :: proc(button: ^Button_Base, press, release: bool) {
    button.pressed = false
    button.released = false
    button.clicked = false

    if rectangle_hit_test(button, mouse_position()) {
        request_mouse_hover(button.id)
    }

    if !button.is_down && press && mouse_hover() == button.id {
        capture_mouse_hover()
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        release_mouse_hover()
        button.is_down = false
        button.released = true
        if mouse_hit() == button.id {
            button.is_down = false
            button.clicked = true
        }
    }
}

Button :: struct {
    using base: Button_Base,
    mouse_button: Mouse_Button,
    color: Color,
}

button_init :: proc(button: ^Button) {
    button_base_init(button)
    button.size = {96, 32}
    button.mouse_button = .Left
    button.color = {0.5, 0.5, 0.5, 1}
}

button_update :: proc(button: ^Button) {
    button_base_update(button,
        press = mouse_pressed(button.mouse_button),
        release = mouse_released(button.mouse_button),
    )
}

button_draw :: proc(button: ^Button) {
    path := temp_path()
    path_rectangle(&path, button)

    fill_path(path, button.color)
    if button.is_down {
        fill_path(path, {0, 0, 0, 0.2})
    } else if mouse_hover() == button.id {
        fill_path(path, {1, 1, 1, 0.05})
    }
}

//==========================================================================
// Text Line
//
// This is a simple text line that measures itself and
// updates its rectangle accordingly. It is aware of the
// current clip rectangle and will only draw the portion
// of the string that is visible on screen for optimization.
// The text does not own its string.
//==========================================================================

Text_Line :: struct {
    using rectangle: Rectangle,
    str: string,
    color: Color,
    font: Font,
    glyphs: [dynamic]Text_Glyph,
    byte_index_to_rune_index: map[int]int,
    needs_remeasure: bool, // Set this to true to ask the text to remeasure
}

text_line_init :: proc(text: ^Text_Line, font: Font, allocator := context.allocator) -> runtime.Allocator_Error {
    text.glyphs = make([dynamic]Text_Glyph, allocator = allocator)
    text.byte_index_to_rune_index = make(map[int]int, allocator = allocator)
    text.font = font
    text.color = {1, 1, 1, 1}
    text.needs_remeasure = true
    return nil
}

text_line_destroy :: proc(text: ^Text_Line) {
    delete(text.glyphs)
    delete(text.byte_index_to_rune_index)
}

text_line_update :: proc(text: ^Text_Line) {
    if text.needs_remeasure {
        measure_text(text.str, text.font, &text.glyphs, &text.byte_index_to_rune_index)
        text.needs_remeasure = false
    }

    text.size.y = font_metrics(text.font).line_height
    if len(text.glyphs) <= 0 {
        text.size.x = 0
    } else {
        left := text.glyphs[0]
        right := text.glyphs[len(text.glyphs) - 1]
        text.size.x = right.position + right.width - left.position
    }
}

text_line_draw :: proc(text: ^Text_Line) {
    str, x_compensation := text_line_visible_string(text)
    position := text.position
    position.x += x_compensation
    fill_text(str, position, text.font, text.color)
}

text_line_visible_string :: proc(text: ^Text_Line) -> (str: string, x_compensation: f32) {
    glyph_count := len(text.glyphs)
    if glyph_count <= 0 do return "", 0

    left, right_exclusive := text_line_visible_glyph_range(text)
    if right_exclusive - left <= 0 do return "", 0

    left_byte_index := text.glyphs[left].byte_index
    byte_count := len(text.str)
    if left_byte_index >= byte_count do return "", 0

    x_compensation = text.glyphs[left].position

    if right_exclusive >= glyph_count {
        str = text.str[left_byte_index:]
    } else {
        right_byte_index := text.glyphs[right_exclusive].byte_index
        if right_byte_index < byte_count {
            str = text.str[left_byte_index:right_byte_index]
        } else {
            str = text.str[left_byte_index:]
        }
    }

    return
}

text_line_byte_index_to_rune_index :: proc(text: ^Text_Line, byte_index: int) -> (rune_index: int, out_of_bounds: bool) {
    if byte_index >= len(text.str) {
        return 0, true
    } else {
        return text.byte_index_to_rune_index[byte_index], false
    }
}

text_line_visible_glyph_range :: proc(text: ^Text_Line) -> (left, right_exclusive: int) {
    clip_rect := clip_rectangle()
    if clip_rect.size.x <= 0 || clip_rect.size.y <= 0 {
        return 0, 0
    }

    position := text.position
    height := text.size.y
    left_set := false

    for glyph, i in text.glyphs {
        glyph_rect := Rectangle{position + {glyph.position, 0}, {glyph.width, height}}
        glyph_visible := rectangle_intersects(clip_rect, glyph_rect, include_borders = false)

        if !left_set {
            if glyph_visible {
                left = i
                left_set = true
            }
        } else {
            if !glyph_visible {
                right_exclusive = max(0, i)
                return
            }
        }
    }

    if left_set {
        right_exclusive = len(text.glyphs)
    }

    return
}

//==========================================================================
// Editable Text Line
//
// This is an editable extension of Text_Line.
// It owns a strings.Builder and will update the string
// of its Text_Line to reference that when editing occurs.
// It will not behave properly if you set the Text_Line str
// directly.
//==========================================================================

POSITIONAL_SELECTION_HORIZONTAL_BIAS :: 3 // Bias positional selection to the right a little for feel.
CARET_WIDTH :: 2

Text_Edit_Command :: text_edit.Command

Editable_Text_Line :: struct {
    using text_line: Text_Line,
    id: Gui_Id,
    builder: strings.Builder,
    caret_color: Color,
    focused_selection_color: Color,
    unfocused_selection_color: Color,
    is_editable: bool,
    drag_selecting: bool,
    edit_state: text_edit.State,
}

editable_text_line_init :: proc(text: ^Editable_Text_Line, font: Font, allocator := context.allocator) -> runtime.Allocator_Error {
    text_line_init(text, font) or_return
    strings.builder_init(&text.builder, allocator = allocator) or_return
    text_edit.init(&text.edit_state, allocator, allocator)
    text_edit.setup_once(&text.edit_state, &text.builder)
    text.edit_state.selection = {0, 0}
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        data = get_clipboard()
        return _quick_remove_line_ends_UNSAFE(data), true
    }
    text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
        set_clipboard(data)
        return true
    }
    text.id = get_gui_id()
    text.caret_color = Color{0.7, .9, 1, 1}
    text.focused_selection_color = Color{0, .4, 0.8, 0.8}
    text.unfocused_selection_color = Color{0, .4, 0.8, 0.65}
    text.is_editable = true
    return nil
}

editable_text_line_destroy :: proc(text: ^Editable_Text_Line) {
    strings.builder_destroy(&text.builder)
    text_edit.destroy(&text.edit_state)
    text_line_destroy(text)
}

editable_text_line_update :: proc(text: ^Editable_Text_Line) {
    text_line_update(text)

    // Update the undo state timeout manually.
    text.edit_state.current_time = time.tick_now()
    if text.edit_state.undo_timeout <= 0 {
        text.edit_state.undo_timeout = text_edit.DEFAULT_UNDO_TIMEOUT
    }

    editable_text_line_edit_with_keyboard(text)
    editable_text_line_edit_with_mouse(text)
}

editable_text_line_draw :: proc(text: ^Editable_Text_Line) {
    is_focus := keyboard_focus() == text.id

    if text.is_editable {
        if selection, exists := editable_text_line_selection_rectangle(text); exists {
            color := text.focused_selection_color if is_focus else text.unfocused_selection_color
            selection_path := temp_path()
            path_rectangle(&selection_path, selection)
            fill_path(selection_path, color)
        }
    }

    text_line_draw(text)

    if text.is_editable && is_focus {
        caret_path := temp_path()
        path_rectangle(&caret_path, editable_text_line_caret_rectangle(text))
        fill_path(caret_path, text.caret_color)
    }
}

editable_text_line_input_string :: proc(text: ^Editable_Text_Line, str: string) {
    text_edit.input_text(&text.edit_state, _quick_remove_line_ends_UNSAFE(str))
    _editable_text_line_update_str(text)
}

editable_text_line_input_runes :: proc(text: ^Editable_Text_Line, runes: []rune) {
    str := utf8.runes_to_string(runes, context.temp_allocator)
    editable_text_line_input_string(text, str)
}

editable_text_line_input_rune :: proc(text: ^Editable_Text_Line, r: rune) {
    if r == '\n' || r == '\r' do return
    text_edit.input_rune(&text.edit_state, r)
    _editable_text_line_update_str(text)
}

editable_text_line_insert_string :: proc(text: ^Editable_Text_Line, at: int, str: string) {
    text_edit.insert(&text.edit_state, at, _quick_remove_line_ends_UNSAFE(str))
    _editable_text_line_update_str(text)
}

editable_text_line_remove_text_range :: proc(text: ^Editable_Text_Line, lo, hi: int) {
    text_edit.remove(&text.edit_state, lo, hi)
    _editable_text_line_update_str(text)
}

editable_text_line_has_selection :: proc(text: ^Editable_Text_Line) -> bool {
    return text_edit.has_selection(&text.edit_state)
}

editable_text_line_sorted_selection :: proc(text: ^Editable_Text_Line) -> (lo, hi: int) {
    return text_edit.sorted_selection(&text.edit_state)
}

editable_text_line_delete_selection :: proc(text: ^Editable_Text_Line) {
    text_edit.selection_delete(&text.edit_state)
    _editable_text_line_update_str(text)
}

editable_text_line_edit :: proc(text: ^Editable_Text_Line, command: Text_Edit_Command) {
    #partial switch command {
    case .New_Line:
        return
    case .Line_Start, .Line_End:
        _editable_text_line_update_edit_state_line_start_and_end(text)
    }

    text_edit.perform_command(&text.edit_state, command)

    #partial switch command {
    case .Backspace, .Delete,
            .Delete_Word_Left, .Delete_Word_Right,
            .Paste, .Cut, .Undo, .Redo:
        _editable_text_line_update_str(text)
    }
}

editable_text_line_start_drag_selection :: proc(text: ^Editable_Text_Line, position: Vector2, only_head := false) {
    set_keyboard_focus(text.id)
    index := editable_text_line_byte_index_at_x(text, position.x)
    text.drag_selecting = true
    text.edit_state.selection[0] = index
    if !only_head do text.edit_state.selection[1] = index
}

editable_text_line_move_drag_selection :: proc(text: ^Editable_Text_Line, position: Vector2) {
    if !text.drag_selecting do return
    text.edit_state.selection[0] = editable_text_line_byte_index_at_x(text, position.x)
}

editable_text_line_end_drag_selection :: proc(text: ^Editable_Text_Line) {
    if !text.drag_selecting do return
    text.drag_selecting = false
}

editable_text_line_edit_with_mouse :: proc(text: ^Editable_Text_Line) {
    if !text.is_editable do return

    if rectangle_hit_test(clip_rectangle(), mouse_position()) {
        request_mouse_hover(text.id)
    }

    if mouse_hover_entered() == text.id {
        set_mouse_cursor_style(.I_Beam)
    }

    if mouse_hover_exited() == text.id {
        set_mouse_cursor_style(.Arrow)
    }

    is_hover := mouse_hover() == text.id
    left_or_middle_pressed := mouse_pressed(.Left) || mouse_pressed(.Middle)
    left_or_middle_released := mouse_released(.Left) || mouse_released(.Middle)

    if left_or_middle_pressed {
        if is_hover {
            set_keyboard_focus(text.id)
        } else {
            release_keyboard_focus()
        }
    }

    if left_or_middle_pressed && is_hover && !text.drag_selecting {
        capture_mouse_hover()

        switch mouse_repeat_count(.Left) {
        case 0, 1: // Single click
            shift := key_down(.Left_Shift) || key_down(.Right_Shift)
            editable_text_line_start_drag_selection(text, mouse_position(), only_head = shift)

        case 2: // Double click
            editable_text_line_edit(text, .Word_Right)
            editable_text_line_edit(text, .Word_Left)
            editable_text_line_edit(text, .Select_Word_Right)

        case 3: // Triple click
            editable_text_line_edit(text, .Line_Start)
            editable_text_line_edit(text, .Select_Line_End)

        case: // Quadruple click and beyond
            editable_text_line_edit(text, .Start)
            editable_text_line_edit(text, .Select_End)
        }
    }

    if text.drag_selecting {
        editable_text_line_move_drag_selection(text, mouse_position())
    }

    if text.drag_selecting && left_or_middle_released {
        editable_text_line_end_drag_selection(text)
        release_mouse_hover()
    }
}

editable_text_line_edit_with_keyboard :: proc(text: ^Editable_Text_Line) {
    if !text.is_editable do return
    if keyboard_focus() != text.id do return

    text_input := text_input()
    if len(text_input) > 0 {
        editable_text_line_input_string(text, text_input)
    }

    ctrl := key_down(.Left_Control) || key_down(.Right_Control)
    shift := key_down(.Left_Shift) || key_down(.Right_Shift)

    for key in key_presses(repeating = true) {
        #partial switch key {
        case .Escape: release_keyboard_focus()
        // case .Enter, .Pad_Enter: edit(text, .New_Line)
        case .A: if ctrl do editable_text_line_edit(text, .Select_All)
        case .C: if ctrl do editable_text_line_edit(text, .Copy)
        case .V: if ctrl do editable_text_line_edit(text, .Paste)
        case .X: if ctrl do editable_text_line_edit(text, .Cut)
        case .Y: if ctrl do editable_text_line_edit(text, .Redo)
        case .Z: if ctrl do editable_text_line_edit(text, .Undo)

        case .Home:
            switch {
            case ctrl && shift: editable_text_line_edit(text, .Select_Start)
            case shift: editable_text_line_edit(text, .Select_Line_Start)
            case ctrl: editable_text_line_edit(text, .Start)
            case: editable_text_line_edit(text, .Line_Start)
            }

        case .End:
            switch {
            case ctrl && shift: editable_text_line_edit(text, .Select_End)
            case shift: editable_text_line_edit(text, .Select_Line_End)
            case ctrl: editable_text_line_edit(text, .End)
            case: editable_text_line_edit(text, .Line_End)
            }

        case .Insert:
            switch {
            case ctrl: editable_text_line_edit(text, .Copy)
            case shift: editable_text_line_edit(text, .Paste)
            }

        case .Backspace:
            switch {
            case ctrl: editable_text_line_edit(text, .Delete_Word_Left)
            case: editable_text_line_edit(text, .Backspace)
            }

        case .Delete:
            switch {
            case ctrl: editable_text_line_edit(text, .Delete_Word_Right)
            case shift: editable_text_line_edit(text, .Cut)
            case: editable_text_line_edit(text, .Delete)
            }

        case .Left_Arrow:
            switch {
            case ctrl && shift: editable_text_line_edit(text, .Select_Word_Left)
            case shift: editable_text_line_edit(text, .Select_Left)
            case ctrl: editable_text_line_edit(text, .Word_Left)
            case: editable_text_line_edit(text, .Left)
            }

        case .Right_Arrow:
            switch {
            case ctrl && shift: editable_text_line_edit(text, .Select_Word_Right)
            case shift: editable_text_line_edit(text, .Select_Right)
            case ctrl: editable_text_line_edit(text, .Word_Right)
            case: editable_text_line_edit(text, .Right)
            }

        // case .Up_Arrow:
        //     switch {
        //     case shift: edit(text, .Select_Up)
        //     case: edit(text, .Up)
        //     }

        // case .Down_Arrow:
        //     switch {
        //     case shift: edit(text, .Select_Down)
        //     case: edit(text, .Down)
        //     }
        }
    }
}

editable_text_line_caret_rectangle :: proc(text: ^Editable_Text_Line) -> (rectangle: Rectangle) {
    glyph_count := len(text.glyphs)

    rectangle.position = text.position
    rectangle.size = {CARET_WIDTH, text.size.y}

    if glyph_count == 0 do return

    head := text.edit_state.selection[0]
    caret_rune_index, caret_oob := text_line_byte_index_to_rune_index(text, head)

    if caret_oob {
        rectangle.position.x += text.glyphs[glyph_count - 1].position + text.glyphs[glyph_count - 1].width
    } else {
        rectangle.position.x += text.glyphs[caret_rune_index].position
    }

    return
}

editable_text_line_selection_rectangle :: proc(text: ^Editable_Text_Line) -> (rectangle: Rectangle, exists: bool) {
    glyph_count := len(text.glyphs)

    if glyph_count == 0 do return

    height := font_metrics(text.font).line_height

    low, high := editable_text_line_sorted_selection(text)
    if high > low {
        left_rune_index, left_oob := text_line_byte_index_to_rune_index(text, low)
        if left_oob do left_rune_index = glyph_count - 1

        right_rune_index, right_oob := text_line_byte_index_to_rune_index(text, high)
        if right_oob {
            right_rune_index = glyph_count - 1
        } else {
            right_rune_index -= 1
        }

        left := text.glyphs[left_rune_index].position
        right := text.glyphs[right_rune_index].position + text.glyphs[right_rune_index].width

        rectangle.position = text.position + {left, 0}
        rectangle.size = {right - left, height}

        exists = true
    }

    return
}

editable_text_line_byte_index_at_x :: proc(text: ^Editable_Text_Line, x: f32) -> int {
    glyph_count := len(text.glyphs)
    if glyph_count == 0 do return 0

    x := x + POSITIONAL_SELECTION_HORIZONTAL_BIAS
    position := text.position

    // There's almost certainly a better way to do this.
    #reverse for glyph, i in text.glyphs {
        left := position.x + glyph.position
        right := position.x + glyph.position + glyph.width

        if i == glyph_count - 1 && x >= right {
            return len(text.builder.buf)
        }

        if x >= left && x < right {
            return glyph.byte_index
        }
    }

    return 0
}

_editable_text_line_update_str :: proc(text: ^Editable_Text_Line) {
    text.str = strings.to_string(text.builder)
    text.needs_remeasure = true
}

_editable_text_line_update_edit_state_line_start_and_end :: proc(text: ^Editable_Text_Line) {
    text.edit_state.line_start = 0
    text.edit_state.line_end = len(text.builder.buf)
}

_quick_remove_line_ends_UNSAFE :: proc(str: string) -> string {
    bytes := make([dynamic]byte, len(str), allocator = context.temp_allocator)
    copy_from_string(bytes[:], str)

    keep_position := 0

    for i in 0 ..< len(bytes) {
        should_keep := bytes[i] != '\n' && bytes[i] != '\r'
        if should_keep {
            if keep_position != i {
                bytes[keep_position] = bytes[i]
            }
            keep_position += 1
        }
    }

    resize(&bytes, keep_position)
    return string(bytes[:])
}