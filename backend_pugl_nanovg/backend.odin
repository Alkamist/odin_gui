package backend_pugl

import "base:runtime"
import "base:intrinsics"
import "core:c"
import "core:fmt"
import "core:time"
import "core:strings"
import utf8 "core:unicode/utf8"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "pugl"
import "../../gui"

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

@(thread_local) _open_gl_is_loaded: bool
@(thread_local) _world: ^pugl.World

Font :: struct {
    name: string,
    size: int,
}

load_font_from_data :: proc(font: ^Font, data: []byte, font_size: int) -> (ok: bool) {
    if len(data) <= 0 do return false
    ctx := gui.current_window(Window)
    if nvg.CreateFontMem(ctx.nvg_ctx, font.name, data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
        return false
    }
    font.size = font_size
    return true
}

Vec2 :: gui.Vec2
Rect :: gui.Rect
Color :: gui.Color

Native_Handle :: rawptr

Child_Kind :: enum {
    None,
    Embedded,
    Transient,
}

Window :: struct {
    using gui_window: gui.Window,
    background_color: gui.Color,

    title: string,
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    is_visible: bool,
    is_resizable: bool,
    double_buffer: bool,
    child_kind: Child_Kind,
    parent_handle: Native_Handle,

    timer_id: uintptr,
    view: ^pugl.View,

    nvg_ctx: ^nvg.Context,
}

init :: proc() {
    // gui.ctx.window_vtable.poll_events = _poll_events
    gui.ctx.window_vtable.init = _window_init
    gui.ctx.window_vtable.open = _window_open
    gui.ctx.window_vtable.close = _window_close
    gui.ctx.window_vtable.begin_frame = _window_begin_frame
    gui.ctx.window_vtable.end_frame = _window_end_frame
    gui.ctx.backend_vtable.update = _update
    gui.ctx.backend_vtable.tick_now = _tick_now
    gui.ctx.backend_vtable.set_mouse_cursor_style = _set_mouse_cursor_style
    gui.ctx.backend_vtable.get_clipboard = _get_clipboard
    gui.ctx.backend_vtable.set_clipboard = _set_clipboard
    gui.ctx.backend_vtable.measure_text = _measure_text
    gui.ctx.backend_vtable.font_metrics = _font_metrics
    gui.ctx.backend_vtable.render_draw_command = _render_draw_command

    when ODIN_BUILD_MODE == .Dynamic {
        world_type := pugl.WorldType.MODULE
    } else {
        world_type := pugl.WorldType.PROGRAM
    }
    _world = pugl.NewWorld(world_type, {})

    _generate_world_id :: proc "contextless" () -> u64 {
        @(static) id: u64
        return 1 + intrinsics.atomic_add(&id, 1)
    }

    world_id := fmt.aprint("WindowThread", _generate_world_id(), gui.temp_allocator())
    world_id_cstring, err := strings.clone_to_cstring(world_id, gui.temp_allocator())
    if err != nil do return

    pugl.SetWorldString(_world, .CLASS_NAME, strings.clone_to_cstring(world_id, gui.temp_allocator()))
}

shutdown :: proc() {
    pugl.FreeWorld(_world)
    _world = nil
}

_update :: proc() {
    if _world == nil do return
    pugl.Update(_world, 0)
}

_window_init :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    window.dark_mode = true
    window.is_visible = true
    window.is_resizable = true
    window.double_buffer = true
    window.child_kind = .None
}

_window_open :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window

    if window.parent_handle != nil && window.child_kind == .None {
        window.child_kind = .Embedded
    }

    view := pugl.NewView(_world)

    title_cstring, err := strings.clone_to_cstring(window.title, gui.temp_allocator())
    if err != nil do return

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
    pugl.SetEventFunc(view, _on_event)

    status := pugl.Realize(view)
    if status != .SUCCESS {
        pugl.FreeView(view)
        fmt.eprintln(pugl.Strerror(status))
        return
    }

    pugl.SetPosition(view, c.int(window.position.x), c.int(window.position.y))

    if window.is_visible {
        pugl.Show(view, .RAISE)
    }

    window.view = view

    pugl.EnterContext(view)

    if !_open_gl_is_loaded {
        gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, pugl.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

    return true
}

_window_close :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window
    view := window.view

    pugl.EnterContext(view)

    nvg_gl.Destroy(window.nvg_ctx)
    window.nvg_ctx = nil

    pugl.Unrealize(view)
    pugl.FreeView(view)

    window.view = nil

    return true
}

_window_begin_frame :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    pugl.EnterContext(window.view)

    size := window.size
    window.content_scale = f32(pugl.GetScaleFactor(window.view))

    c := window.background_color
    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.ClearColor(c.r, c.g, c.b, c.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    nvg.BeginFrame(window.nvg_ctx, size.x, size.y, window.content_scale.x)
}

_window_end_frame :: proc(window: ^gui.Window) {
    window := cast(^Window)window

    nvg.EndFrame(window.nvg_ctx)

    pugl.LeaveContext(window.view)
}

_tick_now :: proc() -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_set_mouse_cursor_style :: proc(style: gui.Mouse_Cursor_Style) -> (ok: bool) {
    window := gui.current_window(Window)
    pugl.SetCursor(window.view, _cursor_style_to_pugl_cursor(style))
    return true
}

_get_clipboard :: proc() -> (data: string, ok: bool) {
    window := gui.current_window(Window)

    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(window.view, 0, &length)
    if clipboard_cstring == nil {
        return "", false
    }

    return string(clipboard_cstring), true
}

_set_clipboard :: proc(data: string)-> (ok: bool) {
    window := gui.current_window(Window)

    data_cstring, err := strings.clone_to_cstring(data, gui.temp_allocator())
    if err != nil do return false
    if pugl.SetClipboard(window.view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1) != .SUCCESS {
        return false
    }

    return true
}

_measure_text :: proc(
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) -> (ok: bool) {
    window := gui.current_window(Window)
    nvg_ctx := window.nvg_ctx

    font := cast(^Font)font

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), gui.temp_allocator())

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        if byte_index_to_rune_index != nil {
            byte_index_to_rune_index[nvg_positions[i].str] = i
        }
        glyphs[i] = gui.Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }

    return true
}

_font_metrics :: proc(font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    window := gui.current_window(Window)
    nvg_ctx := window.nvg_ctx

    font := cast(^Font)font

    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)

    return metrics, true
}

_render_draw_command :: proc(command: gui.Draw_Command) {
    window := gui.current_window(Window)
    nvg_ctx := window.nvg_ctx

    switch c in command {
    case gui.Draw_Custom_Command:
        if c.custom != nil {
            c.custom()
        }

    case gui.Draw_Rect_Command:
        rect := gui.pixel_snapped(c.rect)
        nvg.BeginPath(nvg_ctx)
        nvg.Rect(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))
        nvg.FillColor(nvg_ctx, c.color)
        nvg.Fill(nvg_ctx)

    case gui.Draw_Text_Command:
        font := cast(^Font)c.font
        position := gui.pixel_snapped(c.position)
        nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
        nvg.FontFace(nvg_ctx, font.name)
        nvg.FontSize(nvg_ctx, f32(font.size))
        nvg.FillColor(nvg_ctx, c.color)
        nvg.Text(nvg_ctx, position.x, position.y, c.text)

    case gui.Clip_Drawing_Command:
        rect := gui.pixel_snapped(c.rect)
        nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))
    }
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    window := cast(^Window)pugl.GetHandle(view)
    window.view = view
    context = gui.odin_context()

    #partial switch event.type {
    // case .EXPOSE:
    // case .POINTER_IN:
    // case .POINTER_OUT:
    // case .FOCUS_IN:
    // case .FOCUS_OUT:

    case .UPDATE:
        pugl.PostRedisplay(view)

    case .LOOP_ENTER:
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        event := event.timer
        if window.timer_id == event.id {
            gui.update()
        }

    case .CONFIGURE:
        event := event.configure
        gui.input_window_move(window, {f32(event.x), f32(event.y)})
        gui.input_window_size(window, {f32(event.width), f32(event.height)})
        if !gui.window_opened(window) && gui.window_resized(window) {
            gui.context_update()
        }

    case .MOTION:
        event := event.motion
        gui.input_mouse_move({f32(event.xRoot), f32(event.yRoot)})

    case .SCROLL:
        event := &event.scroll
        gui.input_mouse_scroll({f32(event.dx), f32(event.dy)})

    case .BUTTON_PRESS:
        event := &event.button
        gui.input_mouse_press(_pugl_button_to_mouse_button(event.button))

    case .BUTTON_RELEASE:
        event := &event.button
        gui.input_mouse_release(_pugl_button_to_mouse_button(event.button))

    case .KEY_PRESS:
        event := &event.key
        gui.input_key_press(_pugl_key_event_to_keyboard_key(event))

    case .KEY_RELEASE:
        event := &event.key
        gui.input_key_release(_pugl_key_event_to_keyboard_key(event))

    case .TEXT:
        event := &event.text

        // Filter out unnecessary characters.
        skip := false
        switch event.character {
        case 0..<32, 127: skip = true
        }

        if !skip {
            r, len := utf8.decode_rune(event.string[:4])
            gui.input_text(r)
        }

    case .CLOSE:
        window.is_open = false
    }

    return .SUCCESS
}

_pugl_key_event_to_keyboard_key :: proc(event: ^pugl.KeyEvent) -> gui.Keyboard_Key {
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

_pugl_button_to_mouse_button :: proc(button: u32) -> gui.Mouse_Button {
    switch button {
    case 0: return .Left
    case 1: return .Right
    case 2: return .Middle
    case 3: return .Extra_1
    case 4: return .Extra_2
    case: return .Unknown
    }
}

_cursor_style_to_pugl_cursor :: proc(style: gui.Mouse_Cursor_Style) -> pugl.Cursor {
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