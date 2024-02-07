package gui

import "base:runtime"
import "core:time"
import "rect"

@(thread_local) _current_window: ^Window

Vec2 :: [2]f32
Rect :: rect.Rect

Tick :: time.Tick
Duration :: time.Duration

Cursor_Style :: enum {
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

Mouse_State :: struct {
    position: Vec2,
    button_down: [Mouse_Button]bool,
    hit: ^Widget,
    hover: ^Widget,
    hover_captured: bool,
    repeat_duration: Duration,
    repeat_movement_tolerance: f32,
    repeat_start_position: Vec2,
    repeat_press_count: int,
    repeat_tick: Tick,
}

Keyboard_State :: struct {
    key_down: [Keyboard_Key]bool,
    focus: ^Widget,
}

Backend :: struct {
    user_data: rawptr,
    get_tick: proc(backend: ^Backend) -> (tick: Tick, ok: bool),
    set_cursor_style: proc(backend: ^Backend, style: Cursor_Style) -> (ok: bool),
    get_clipboard: proc(backend: ^Backend) -> (data: string, ok: bool),
    set_clipboard: proc(backend: ^Backend, data: string) -> (ok: bool),
    measure_text: proc(backend: ^Backend, glyphs: ^[dynamic]Text_Glyph, text: string, font: Font) -> (ok: bool),
    font_metrics: proc(backend: ^Backend, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(backend: ^Backend, command: Draw_Command),
}

Window :: struct {
    root: Widget,
    position: Vec2,
    size: Vec2,
    content_scale: Vec2,
    needs_redisplay: bool,
    mouse: Mouse_State,
    keyboard: Keyboard_State,
    backend: Backend,

    current_cached_global_position: Vec2,
}

init_window :: proc(
    window: ^Window,
    position: Vec2,
    size: Vec2,
    allocator := context.allocator,
) -> (res: ^Window, err: runtime.Allocator_Error) #optional_allocator_error {
    init_widget(&window.root, allocator) or_return
    window.root.window = window
    window.root.size = size
    window.position = position
    window.size = size
    window.mouse.repeat_duration = 300 * time.Millisecond
    window.mouse.repeat_movement_tolerance = 3
    window.content_scale = Vec2{1, 1}
    window.needs_redisplay = true
    return window, nil
}

destroy_window :: proc(window: ^Window) {
    destroy_widget(&window.root)
}

input_open :: proc(window: ^Window) {
    _send_window_event(window, Window_Open_Event{})
}

input_close :: proc(window: ^Window) {
    _send_window_event(window, Window_Close_Event{})
}

input_draw :: proc(window: ^Window) {
    window.current_cached_global_position = window.root.position
    _send_window_event(window, Window_Draw_Event{})
    _send_event_recursively(&window.root, true, Draw_Event{})
}

input_update :: proc(window: ^Window) {
    _send_window_event(window, Window_Update_Event{})
    _send_event_recursively(&window.root, true, Update_Event{})
}

input_move :: proc(window: ^Window, position: Vec2) {
    if position == window.position do return
    previous_position := window.position
    window.position = position
    _send_window_event(window, Window_Move_Event{
        position = position,
        delta = position - previous_position,
    })
}

input_resize :: proc(window: ^Window, size: Vec2) {
    if size == window.size do return
    previous_size := window.size
    window.size = size
    _send_window_event(window, Window_Resize_Event{
        size = size,
        delta = size - previous_size,
    })
    set_size(&window.root, size)
}

input_mouse_enter :: proc(window: ^Window, position: Vec2) {
    _send_window_event(window, Window_Mouse_Enter_Event{
        position = position,
    })
}

input_mouse_exit :: proc(window: ^Window, position: Vec2) {
    _send_window_event(window, Window_Mouse_Exit_Event{
        position = position,
    })
}

input_mouse_move :: proc(window: ^Window, position: Vec2) {
    previous_mouse_position := window.mouse.position
    if position == previous_mouse_position do return
    window.mouse.position = position
    _send_window_event(window, Window_Mouse_Move_Event{
        position = position,
        delta = position - previous_mouse_position,
    })
    update_mouse_hover(window)
}

input_mouse_press :: proc(window: ^Window, position: Vec2, button: Mouse_Button) {
    window.mouse.button_down[button] = true

    tick_available := false
    previous_mouse_repeat_tick := window.mouse.repeat_tick
    window.mouse.repeat_tick, tick_available = get_tick(window)

    if tick_available {
        delta := time.tick_diff(previous_mouse_repeat_tick, window.mouse.repeat_tick)
        if delta <= window.mouse.repeat_duration {
            window.mouse.repeat_press_count += 1
        } else {
            window.mouse.repeat_press_count = 1
        }

        // This is just a simple x, y comparison, not true distance.
        movement := window.mouse.position - window.mouse.repeat_start_position
        if abs(movement.x) > window.mouse.repeat_movement_tolerance ||
           abs(movement.y) > window.mouse.repeat_movement_tolerance {
            window.mouse.repeat_press_count = 1
        }
    }

    if window.mouse.repeat_press_count == 1 {
        window.mouse.repeat_start_position = window.mouse.position
    }

    _send_window_event(window, Window_Mouse_Press_Event{
        position = position,
        button = button,
    })
    _send_window_event(window, Window_Mouse_Repeat_Event{
        position = position,
        button = button,
        press_count = window.mouse.repeat_press_count,
    })

    if window.mouse.hover != nil {
        mp := mouse_position(window.mouse.hover)
        _send_event(window.mouse.hover, true, Mouse_Press_Event{
            position = mp,
            button = button,
        })
        _send_event(window.mouse.hover, true, Mouse_Repeat_Event{
            position = mp,
            button = button,
            press_count = window.mouse.repeat_press_count,
        })
    }
}

input_mouse_release :: proc(window: ^Window, position: Vec2, button: Mouse_Button) {
    window.mouse.button_down[button] = false

    _send_window_event(window, Window_Mouse_Release_Event{
        position = position,
        button = button,
    })

    if window.mouse.hover != nil {
        _send_event(window.mouse.hover, true, Mouse_Release_Event{
            position = mouse_position(window.mouse.hover),
            button = button,
        })
    }

    update_mouse_hover(window)
}

input_mouse_scroll :: proc(window: ^Window, position: Vec2, amount: Vec2) {
    _send_window_event(window, Window_Mouse_Scroll_Event{
        position = position,
        amount = amount,
    })

    if window.mouse.hover != nil {
        _send_event(window.mouse.hover, true, Mouse_Scroll_Event{
            position = mouse_position(window.mouse.hover),
            amount = amount,
        })
    }
}

input_key_press :: proc(window: ^Window, key: Keyboard_Key) {
    already_down := window.keyboard.key_down[key]
    window.keyboard.key_down[key] = true

    if !already_down {
        _send_window_event(window, Window_Key_Press_Event{
            key = key,
        })
        if window.keyboard.focus != nil {
            _send_event(window.keyboard.focus, true, Key_Press_Event{
                key = key,
            })
        }
    }

    _send_window_event(window, Window_Key_Repeat_Event{
        key = key,
    })
    if window.keyboard.focus != nil {
        _send_event(window.keyboard.focus, true, Key_Repeat_Event{
            key = key,
        })
    }
}

input_key_release :: proc(window: ^Window, key: Keyboard_Key) {
    window.keyboard.key_down[key] = false

    _send_window_event(window, Window_Key_Release_Event{
        key = key,
    })

    if window.keyboard.focus != nil {
        _send_event(window.keyboard.focus, true, Key_Release_Event{
            key = key,
        })
    }
}

input_text :: proc(window: ^Window, text: rune) {
    _send_window_event(window, Window_Text_Event{
        text = text,
    })

    if window.keyboard.focus != nil {
        _send_event(window.keyboard.focus, true, Text_Event{
            text = text,
        })
    }
}

input_content_scale :: proc(window: ^Window, scale: Vec2) {
    previous_content_scale := window.content_scale
    if scale == previous_content_scale do return
    window.content_scale = scale
    _send_window_event(window, Window_Content_Scale_Event{
        scale = scale,
        delta = scale - previous_content_scale,
    })
}

redraw :: proc(window := _current_window) {
    assert(window != nil)
    window.needs_redisplay = true
}

get_tick :: proc(window := _current_window) -> (tick: Tick, ok: bool) {
    assert(window != nil)
    if window.backend.get_tick == nil do return {}, false
    return window.backend->get_tick()
}

set_cursor_style :: proc(style: Cursor_Style, window := _current_window) -> (ok: bool) {
    assert(window != nil)
    if window.backend.set_cursor_style == nil do return false
    return window.backend->set_cursor_style(style)
}

get_clipboard :: proc(window := _current_window) -> (data: string, ok: bool) {
    assert(window != nil)
    if window.backend.get_clipboard == nil do return "", false
    return window.backend->get_clipboard()
}

set_clipboard :: proc(data: string, window := _current_window) -> (ok: bool) {
    assert(window != nil)
    if window.backend.set_clipboard == nil do return false
    return window.backend->set_clipboard(data)
}

measure_text :: proc(glyphs: ^[dynamic]Text_Glyph, text: string, font: Font, window := _current_window) -> (ok: bool) {
    assert(window != nil)
    if window.backend.measure_text == nil do return false
    return window.backend->measure_text(glyphs, text, font)
}

font_metrics :: proc(font: Font, window := _current_window) -> (metrics: Font_Metrics, ok: bool) {
    assert(window != nil)
    if window.backend.font_metrics == nil do return {}, false
    return window.backend->font_metrics(font)
}

hit_test :: proc(position: Vec2, window := _current_window) -> ^Widget {
    assert(window != nil)
    return _hit_test_recursively(&window.root, position)
}

global_mouse_position :: proc(window := _current_window) -> Vec2 {
    assert(window != nil)
    return window.mouse.position
}

mouse_down :: proc(button: Mouse_Button, window := _current_window) -> bool {
    assert(window != nil)
    return window.mouse.button_down[button]
}

mouse_hit :: proc(window := _current_window) -> ^Widget {
    assert(window != nil)
    return window.mouse.hit
}

mouse_hover :: proc(window := _current_window) -> ^Widget {
    assert(window != nil)
    return window.mouse.hover
}

capture_mouse_hover :: proc(window := _current_window) {
    assert(window != nil)
    window.mouse.hover_captured = true
}

release_mouse_hover :: proc(window := _current_window) {
    assert(window != nil)
    window.mouse.hover_captured = false
}

update_mouse_hover :: proc(window := _current_window) {
    assert(window != nil)

    previous_hover := window.mouse.hover
    window.mouse.hit = hit_test(window.mouse.position, window)

    if !window.mouse.hover_captured {
        window.mouse.hover = window.mouse.hit
    }

    if window.mouse.hover != nil {
        previous_mouse_position := window.mouse.hover.cached_mouse_position
        mp := mouse_position(window.mouse.hover)
        if mp != previous_mouse_position {
            window.mouse.hover.cached_mouse_position = mp
            _send_event(window.mouse.hover, true, Mouse_Move_Event{
                position = mp,
                delta = mp - previous_mouse_position,
            })
        }
    }

    if window.mouse.hover != previous_hover {
        if previous_hover != nil {
            _send_event(previous_hover, false, Mouse_Exit_Event{
                position = mouse_position(previous_hover),
            })
        }
        if window.mouse.hover != nil {
            _send_event(window.mouse.hover, true, Mouse_Enter_Event{
                position = mouse_position(window.mouse.hover),
            })
        }
    }
}

key_down :: proc(key: Keyboard_Key, window := _current_window) -> bool {
    assert(window != nil)
    return window.keyboard.key_down[key]
}

keyboard_focus :: proc(window := _current_window) -> ^Widget {
    assert(window != nil)
    return window.keyboard.focus
}

set_keyboard_focus :: proc(focus: ^Widget, window := _current_window) {
    assert(window != nil)
    window.keyboard.focus = focus
}

release_keyboard_focus :: proc(window := _current_window) {
    assert(window != nil)
    window.keyboard.focus = nil
}



_send_window_event :: proc(window: ^Window, event: Event) {
    _send_event_recursively(&window.root, false, event)
}