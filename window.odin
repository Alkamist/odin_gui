package main

import "base:runtime"
import "base:intrinsics"
import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import "core:strings"
import utf8 "core:unicode/utf8"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "pugl"

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

@(thread_local) _current_window: ^Window
@(thread_local) _window_count: int
@(thread_local) _open_gl_is_loaded: bool
@(thread_local) _pugl_world: ^pugl.World
@(thread_local) _pugl_odin_context: runtime.Context

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

current_window :: proc() -> ^Window {
    return _current_window
}

poll_events :: proc() {
    _pugl_odin_context = context
    if _pugl_world == nil do return
    pugl.Update(_pugl_world, 0)
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
    context = _pugl_odin_context
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

_set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) {
    pugl.SetCursor(current_window().view, _cursor_style_to_pugl_cursor(style))
}

_get_clipboard :: proc() -> string {
    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(current_window().view, 0, &length)
    if clipboard_cstring == nil {
        return ""
    }
    return string(clipboard_cstring)
}

_set_clipboard :: proc(data: string) {
    data_cstring, err := strings.clone_to_cstring(data, context.temp_allocator)
    if err != nil do return
    pugl.SetClipboard(current_window().view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1)
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