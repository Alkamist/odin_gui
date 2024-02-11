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
@(thread_local) _odin_context: runtime.Context
@(thread_local) _world: ^pugl.World
@(thread_local) _window_count: int

Font :: struct {
    name: string,
    size: int,
}

load_font_from_data :: proc(font: ^Font, data: []byte, font_size: int) -> (ok: bool) {
    if len(data) <= 0 do return false
    ctx := gui.current_context(Context)
    if nvg.CreateFontMem(ctx.nvg_ctx, font.name, data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
        return false
    }
    font.size = font_size
    return true
}

font_destroy :: proc(font: ^Font) {}

Vec2 :: gui.Vec2
Rect :: gui.Rect
Color :: gui.Color

Native_Handle :: rawptr

Child_Kind :: enum {
    None,
    Embedded,
    Transient,
}

Context :: struct {
    using gui_ctx: gui.Context,
    background_color: gui.Color,

    title: string,
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    is_resizable: bool,
    double_buffer: bool,
    child_kind: Child_Kind,
    parent_handle: Native_Handle,

    timer_id: uintptr,
    view: ^pugl.View,

    nvg_ctx: ^nvg.Context,
}

update :: proc() {
    _odin_context = context
    if _world == nil {
        return
    }
    pugl.Update(_world, 0)
}

init :: proc(
    ctx: ^Context,
    position: gui.Vec2,
    size: gui.Vec2,
    temp_allocator := context.temp_allocator,
) -> runtime.Allocator_Error {
    gui.init(ctx, position, size, temp_allocator) or_return
    ctx.dark_mode = true
    ctx.is_visible = true
    ctx.is_resizable = true
    ctx.double_buffer = true
    ctx.child_kind = .None
    ctx.tick_now = _tick_now
    ctx.set_mouse_cursor_style = _set_mouse_cursor_style
    ctx.get_clipboard = _get_clipboard
    ctx.set_clipboard = _set_clipboard
    ctx.measure_text = _measure_text
    ctx.font_metrics = _font_metrics
    ctx.render_draw_command = _render_draw_command
    return nil
}

destroy :: proc(ctx: ^Context) {
    gui.destroy(ctx)
    if ctx.is_open {
        close(ctx)
    }
}

open :: proc(ctx: ^Context) {
    if _window_count == 0 {
        when ODIN_BUILD_MODE == .Dynamic {
            world_type := pugl.WorldType.MODULE
        } else {
            world_type := pugl.WorldType.PROGRAM
        }
        _world = pugl.NewWorld(world_type, {})

        world_id := fmt.aprint("WindowThread", _generate_id(), ctx.temp_allocator)
        world_id_cstring, err := strings.clone_to_cstring(world_id, ctx.temp_allocator)
        if err != nil do return

        pugl.SetWorldString(_world, .CLASS_NAME, strings.clone_to_cstring(world_id, ctx.temp_allocator))
    }

    if ctx.parent_handle != nil && ctx.child_kind == .None {
        ctx.child_kind = .Embedded
    }

    view := pugl.NewView(_world)

    title_cstring, err := strings.clone_to_cstring(ctx.title, ctx.temp_allocator)
    if err != nil do return

    pugl.SetViewString(view, .WINDOW_TITLE, title_cstring)
    pugl.SetSizeHint(view, .DEFAULT_SIZE, u16(ctx.size.x), u16(ctx.size.y))

    if min_size, ok := ctx.min_size.?; ok {
        pugl.SetSizeHint(view, .MIN_SIZE, u16(min_size.x), u16(min_size.y))
    }

    if max_size, ok := ctx.max_size.?; ok {
        pugl.SetSizeHint(view, .MAX_SIZE, u16(max_size.x), u16(max_size.y))
    }

    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .STENCIL_BITS, 8)

    pugl.SetViewHint(view, .DARK_FRAME, ctx.dark_mode ? 1 : 0)
    pugl.SetViewHint(view, .RESIZABLE, ctx.is_resizable ? 1 : 0)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, ctx.double_buffer ? 1 : 0)
    pugl.SetViewHint(view, .SWAP_INTERVAL, i32(ctx.swap_interval))
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    pugl.SetViewHint(view, .CONTEXT_VERSION_MAJOR, OPENGL_VERSION_MAJOR)
    pugl.SetViewHint(view, .CONTEXT_VERSION_MINOR, OPENGL_VERSION_MINOR)

    #partial switch ctx.child_kind {
    case .Embedded:
        pugl.SetParentWindow(view, cast(uintptr)ctx.parent_handle)
    case .Transient:
        pugl.SetTransientParent(view, cast(uintptr)ctx.parent_handle)
    }

    pugl.SetHandle(view, ctx)
    pugl.SetEventFunc(view, _on_event)

    status := pugl.Realize(view)
    if status != .SUCCESS {
        pugl.FreeView(view)
        fmt.eprintln(pugl.Strerror(status))
        return
    }

    pugl.SetPosition(view, c.int(ctx.position.x), c.int(ctx.position.y))

    if ctx.is_visible {
        pugl.Show(view, .RAISE)
    }

    ctx.view = view
    ctx.is_open = true

    _window_count += 1

    pugl.EnterContext(view)

    if !_open_gl_is_loaded {
        gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, pugl.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

close :: proc(ctx: ^Context) {
    view := ctx.view

    pugl.EnterContext(view)

    nvg_gl.Destroy(ctx.nvg_ctx)
    ctx.nvg_ctx = nil

    pugl.Unrealize(view)
    pugl.FreeView(view)

    ctx.view = nil
    ctx.is_open = false

    _window_count -= 1

    if _window_count == 0 {
        pugl.FreeWorld(_world)
        _world = nil
    }
}



_tick_now :: proc(ctx: ^gui.Context) -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_set_mouse_cursor_style :: proc(ctx: ^gui.Context, style: gui.Mouse_Cursor_Style) -> (ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx
    pugl.SetCursor(ctx.view, _cursor_style_to_pugl_cursor(style))
    return true
}

_measure_text :: proc(
    ctx: ^gui.Context,
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) -> (ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    nvg_ctx := ctx.nvg_ctx
    assert(ctx != nil)

    font := cast(^Font)font

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), ctx.temp_allocator)

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

_font_metrics :: proc(ctx: ^gui.Context, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    nvg_ctx := ctx.nvg_ctx
    assert(ctx != nil)

    font := cast(^Font)font

    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)

    return metrics, true
}

_get_clipboard :: proc(ctx: ^gui.Context) -> (data: string, ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(ctx.view, 0, &length)
    if clipboard_cstring == nil {
        return "", false
    }

    return string(clipboard_cstring), true
}

_set_clipboard :: proc(ctx: ^gui.Context, data: string)-> (ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    data_cstring, err := strings.clone_to_cstring(data, ctx.temp_allocator)
    if err != nil do return false
    if pugl.SetClipboard(ctx.view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1) != .SUCCESS {
        return false
    }

    return true
}

_render_draw_command :: proc(ctx: ^gui.Context, command: gui.Draw_Command) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    nvg_ctx := ctx.nvg_ctx

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

_generate_id :: proc "contextless" () -> u64 {
    @(static) id: u64
    return 1 + intrinsics.atomic_add(&id, 1)
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    ctx := cast(^Context)pugl.GetHandle(view)
    ctx.view = view
    context = _odin_context

    #partial switch event.type {
    case .EXPOSE:
        if !ctx.is_visible {
            pugl.Hide(view)
            return .SUCCESS
        }

        size := ctx.size
        c := ctx.background_color
        gui.input_content_scale(ctx, f32(pugl.GetScaleFactor(view)))

        gl.Viewport(0, 0, i32(size.x), i32(size.y))
        gl.ClearColor(c.r, c.g, c.b, c.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, ctx.content_scale.x)

        gui.update(ctx)

        nvg.EndFrame(ctx.nvg_ctx)

        if !ctx.is_open {
            event := pugl.EventType.CLOSE
            pugl.SendEvent(view, cast(^pugl.Event)(&event))
        }

    case .UPDATE:
        pugl.PostRedisplay(view)

    case .LOOP_ENTER:
        pugl.StartTimer(view, ctx.timer_id, 0)

    case .LOOP_LEAVE:
        pugl.StopTimer(view, ctx.timer_id)

    case .TIMER:
        event := event.timer
        if ctx.timer_id == event.id {
            update()
        }

    case .CONFIGURE:
        event := event.configure
        gui.input_move(ctx, {f32(event.x), f32(event.y)})
        size := Vec2{f32(event.width), f32(event.height)}
        previous_size := ctx.size
        gui.input_resize(ctx, {f32(event.width), f32(event.height)})
        if size != previous_size {
            pugl.PostRedisplay(view)
        }

    case .MOTION:
        event := event.motion
        gui.input_mouse_move(ctx, {f32(event.x), f32(event.y)})
        pugl.PostRedisplay(view)

    case .POINTER_IN:
        gui.input_mouse_enter(ctx)
        pugl.PostRedisplay(view)

    case .POINTER_OUT:
        gui.input_mouse_exit(ctx)
        pugl.PostRedisplay(view)

    // case .FOCUS_IN:
    //     gui.input_gain_focus(ctx)

    // case .FOCUS_OUT:
    //     gui.input_lose_focus(ctx)

    case .SCROLL:
        event := &event.scroll
        gui.input_mouse_scroll(ctx, {f32(event.dx), f32(event.dy)})
        pugl.PostRedisplay(view)

    case .BUTTON_PRESS:
        event := &event.button
        gui.input_mouse_press(ctx, _pugl_button_to_mouse_button(event.button))
        pugl.PostRedisplay(view)

    case .BUTTON_RELEASE:
        event := &event.button
        gui.input_mouse_release(ctx, _pugl_button_to_mouse_button(event.button))
        pugl.PostRedisplay(view)

    case .KEY_PRESS:
        event := &event.key
        gui.input_key_press(ctx, _pugl_key_event_to_keyboard_key(event))
        pugl.PostRedisplay(view)

    case .KEY_RELEASE:
        event := &event.key
        gui.input_key_release(ctx, _pugl_key_event_to_keyboard_key(event))
        pugl.PostRedisplay(view)

    case .TEXT:
        event := &event.text

        // Filter out unnecessary characters.
        skip := false
        switch event.character {
        case 0..<32, 127: skip = true
        }

        if !skip {
            r, len := utf8.decode_rune(event.string[:4])
            gui.input_text(ctx, r)
            pugl.PostRedisplay(view)
        }

    case .CLOSE:
        close(ctx)
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



































// open_gl_is_loaded: bool

// Font :: struct {
//     name: string,
//     size: int,
// }

// load_font_from_data :: proc(font: ^Font, data: []byte, font_size: int) -> (ok: bool) {
//     if len(data) <= 0 do return false
//     ctx := gui.current_context(Context)
//     if nvg.CreateFontMem(ctx.nvg_ctx, font.name, data, false) == -1 {
//         fmt.eprintf("Failed to load font: %v\n", font.name)
//         return false
//     }
//     font.size = font_size
//     return true
// }

// font_destroy :: proc(font: ^Font) {}

// update :: wnd.update

// Context :: struct {
//     using ctx: gui.Context,
//     background_color: gui.Color,
//     nvg_ctx: ^nvg.Context,
//     backend_window: wnd.Context,
// }

// init :: proc(
//     ctx: ^Context,
//     position: gui.Vec2,
//     size: gui.Vec2,
//     temp_allocator := context.temp_allocator,
// ) -> runtime.Allocator_Error{
//     wnd.init(&ctx.backend_window, position, size)
//     ctx.backend_window.user_data = ctx
//     ctx.backend_window.event_proc = _event_proc
//     gui.init(ctx, position, size, temp_allocator) or_return
//     ctx.tick_now = _tick_now
//     ctx.set_mouse_cursor_style = _set_mouse_cursor_style
//     ctx.get_clipboard = _get_clipboard
//     ctx.set_clipboard = _set_clipboard
//     ctx.measure_text = _measure_text
//     ctx.font_metrics = _font_metrics
//     ctx.render_draw_command = _render_draw_command
//     return nil
// }

// destroy :: proc(ctx: ^Context) {
//     gui.destroy(ctx)
//     wnd.destroy(&ctx.backend_window)
// }

// open :: proc(ctx: ^Context) {
//     wnd.open(&ctx.backend_window, ctx.temp_allocator)
// }

// close :: proc(ctx: ^Context) {
//     wnd.close(&ctx.backend_window)
// }

// is_open :: proc(ctx: ^Context) -> bool {
//     return wnd.is_open(&ctx.backend_window)
// }



// _event_proc :: proc(backend_window: ^wnd.Context, event: wnd.Event) {
//     ctx := cast(^Context)backend_window.user_data

//     #partial switch e in event {
//     case wnd.Open_Event:
//         wnd.activate_context(backend_window)
//         if !open_gl_is_loaded {
//             gl.load_up_to(3, 3, wnd.gl_set_proc_address)
//             open_gl_is_loaded = true
//         }
//         ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

//         gui.input_open(ctx)
//         _update_content_scale(ctx)

//         wnd.display(backend_window)

//     case wnd.Close_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_close(ctx)
//         nvg_gl.Destroy(ctx.nvg_ctx)

//     case wnd.Display_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)

//         size := wnd.size(backend_window)
//         c := ctx.background_color

//         gl.Viewport(0, 0, i32(size.x), i32(size.y))
//         gl.ClearColor(c.r, c.g, c.b, c.a)
//         gl.Clear(gl.COLOR_BUFFER_BIT)

//         nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, wnd.content_scale(backend_window))

//         gui.update(ctx)

//         nvg.EndFrame(ctx.nvg_ctx)

//     case wnd.Update_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         wnd.display(backend_window)

//     case wnd.Move_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_move(ctx, e.position)
//         wnd.display(backend_window)

//     case wnd.Resize_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_resize(ctx, e.size)
//         wnd.display(backend_window)

//     case wnd.Mouse_Enter_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_mouse_enter(ctx)
//         wnd.display(backend_window)

//     case wnd.Mouse_Exit_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_mouse_exit(ctx)
//         wnd.display(backend_window)

//     case wnd.Mouse_Move_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_mouse_move(ctx, e.position)
//         wnd.display(backend_window)

//     case wnd.Mouse_Scroll_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_mouse_scroll(ctx, e.amount)
//         wnd.display(backend_window)

//     case wnd.Mouse_Press_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_mouse_press(ctx, cast(gui.Mouse_Button)e.button)
//         wnd.display(backend_window)

//     case wnd.Mouse_Release_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_mouse_release(ctx, cast(gui.Mouse_Button)e.button)
//         wnd.display(backend_window)

//     case wnd.Key_Press_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_key_press(ctx, cast(gui.Keyboard_Key)e.key)
//         wnd.display(backend_window)

//     case wnd.Key_Release_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_key_release(ctx, cast(gui.Keyboard_Key)e.key)
//         wnd.display(backend_window)

//     case wnd.Text_Event:
//         wnd.activate_context(backend_window)
//         _update_content_scale(ctx)
//         gui.input_text(ctx, e.text)
//         wnd.display(backend_window)
//     }
// }

// _update_content_scale :: proc(ctx: ^Context) {
//     scale := wnd.content_scale(&ctx.backend_window)
//     gui.input_content_scale(ctx, {scale, scale})
// }

// _tick_now :: proc(ctx: ^gui.Context) -> (tick: gui.Tick, ok: bool) {
//     return time.tick_now(), true
// }

// _set_mouse_cursor_style :: proc(ctx: ^gui.Context, style: gui.Mouse_Cursor_Style) -> (ok: bool) {
//     assert(ctx != nil)
//     ctx := cast(^Context)ctx
//     wnd.set_mouse_cursor_style(&ctx.backend_window, cast(wnd.Mouse_Cursor_Style)style)
//     return true
// }

// _measure_text :: proc(
//     ctx: ^gui.Context,
//     text: string,
//     font: gui.Font,
//     glyphs: ^[dynamic]gui.Text_Glyph,
//     byte_index_to_rune_index: ^map[int]int,
// ) -> (ok: bool) {
//     assert(ctx != nil)
//     ctx := cast(^Context)ctx

//     nvg_ctx := ctx.nvg_ctx
//     assert(ctx != nil)

//     font := cast(^Font)font

//     clear(glyphs)

//     if len(text) == 0 {
//         return
//     }

//     nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
//     nvg.FontFace(nvg_ctx, font.name)
//     nvg.FontSize(nvg_ctx, f32(font.size))

//     nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), ctx.temp_allocator)

//     temp_slice := nvg_positions[:]
//     position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, text, &temp_slice)

//     resize(glyphs, position_count)

//     for i in 0 ..< position_count {
//         if byte_index_to_rune_index != nil {
//             byte_index_to_rune_index[nvg_positions[i].str] = i
//         }
//         glyphs[i] = gui.Text_Glyph{
//             byte_index = nvg_positions[i].str,
//             position = nvg_positions[i].x,
//             width = nvg_positions[i].maxx - nvg_positions[i].minx,
//             kerning = (nvg_positions[i].x - nvg_positions[i].minx),
//         }
//     }

//     return true
// }

// _font_metrics :: proc(ctx: ^gui.Context, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
//     assert(ctx != nil)
//     ctx := cast(^Context)ctx

//     nvg_ctx := ctx.nvg_ctx
//     assert(ctx != nil)

//     font := cast(^Font)font

//     nvg.FontFace(nvg_ctx, font.name)
//     nvg.FontSize(nvg_ctx, f32(font.size))

//     metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)

//     return metrics, true
// }

// _get_clipboard :: proc(ctx: ^gui.Context) -> (data: string, ok: bool) {
//     assert(ctx != nil)
//     ctx := cast(^Context)ctx
//     return wnd.get_clipboard(&ctx.backend_window)
// }

// _set_clipboard :: proc(ctx: ^gui.Context, data: string)-> (ok: bool) {
//     assert(ctx != nil)
//     ctx := cast(^Context)ctx
//     return wnd.set_clipboard(&ctx.backend_window, data, ctx.temp_allocator)
// }

// _render_draw_command :: proc(ctx: ^gui.Context, command: gui.Draw_Command) {
//     assert(ctx != nil)
//     ctx := cast(^Context)ctx

//     nvg_ctx := ctx.nvg_ctx

//     switch c in command {
//     case gui.Draw_Custom_Command:
//         if c.custom != nil {
//             c.custom()
//         }

//     case gui.Draw_Rect_Command:
//         rect := gui.pixel_snapped(c.rect)
//         nvg.BeginPath(nvg_ctx)
//         nvg.Rect(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))
//         nvg.FillColor(nvg_ctx, c.color)
//         nvg.Fill(nvg_ctx)

//     case gui.Draw_Text_Command:
//         font := cast(^Font)c.font
//         position := gui.pixel_snapped(c.position)
//         nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
//         nvg.FontFace(nvg_ctx, font.name)
//         nvg.FontSize(nvg_ctx, f32(font.size))
//         nvg.FillColor(nvg_ctx, c.color)
//         nvg.Text(nvg_ctx, position.x, position.y, c.text)

//     case gui.Clip_Drawing_Command:
//         rect := gui.pixel_snapped(c.rect)
//         nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))
//     }
// }