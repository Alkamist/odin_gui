package main

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

@(thread_local) _open_gl_is_loaded: bool
@(thread_local) _pugl_world: ^pugl.World
@(thread_local) _pugl_odin_context: runtime.Context

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

Window_Native_Handle :: rawptr

Window_Child_Kind :: enum {
    None,
    Embedded,
    Transient,
}

Window :: struct {
    using base: Window_Base,

    title: string,
    swap_interval: int,
    dark_mode: bool,
    is_visible: bool,
    is_resizable: bool,
    double_buffer: bool,
    child_kind: Window_Child_Kind,
    parent_handle: Window_Native_Handle,
    min_size: Maybe(Vector2),
    max_size: Maybe(Vector2),
    background_color: Color,

    timer_id: uintptr,
    view: ^pugl.View,

    nvg_ctx: ^nvg.Context,
}

backend_startup :: proc() {
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

backend_shutdown :: proc() {
    pugl.FreeWorld(_pugl_world)
    _pugl_world = nil
}

backend_poll_events :: proc() {
    _pugl_odin_context = context
    if _pugl_world == nil do return
    pugl.Update(_pugl_world, 0)
}

backend_window_init :: proc(window: ^Window, rectangle: Rectangle) {
    window.rectangle = rectangle
    window.should_open = true
    window.dark_mode = true
    window.is_visible = true
    window.is_resizable = true
    window.double_buffer = true
}

backend_window_destroy :: proc(window: ^Window) {
}

backend_window_begin_frame :: proc(window: ^Window) {
    if !window.is_open do return

    pugl.EnterContext(window.view)

    size := window.size
    window.content_scale = f32(pugl.GetScaleFactor(window.view))

    bg := window.background_color
    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    nvg.BeginFrame(window.nvg_ctx, size.x, size.y, window.content_scale.x)
}

backend_window_end_frame :: proc(window: ^Window) {
    if !window.is_open do return
    nvg.EndFrame(window.nvg_ctx)
}

backend_window_open :: proc(window: ^Window) {
    if window.parent_handle != nil && window.child_kind == .None {
        window.child_kind = .Embedded
    }

    view := pugl.NewView(_pugl_world)

    title_cstring := strings.clone_to_cstring(window.title, context.temp_allocator)

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
}

backend_window_close :: proc(window: ^Window) {
    nvg_gl.Destroy(window.nvg_ctx)
    window.nvg_ctx = nil

    pugl.Unrealize(window.view)
    pugl.FreeView(window.view)

    window.view = nil
}

backend_activate_gl_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

// backend_window_native_handle :: proc(window: ^Window) -> Window_Native_Handle {
//     return cast(rawptr)pugl.GetNativeView(window.view)
// }

// backend_show_window :: proc(window: ^Window) {
//     pugl.Show(window.view, .RAISE)
// }

// backend_hide_window :: proc(window: ^Window) {
//     pugl.Hide(window.view)
// }

// backend_set_window_position :: proc(window: ^Window, position: Vector2) {
//     pugl.SetPosition(window.view, i32(position.x), i32(position.y))
//     pugl.EnterContext(window.view)
// }

// backend_set_window_size :: proc(window: ^Window, size: Vector2) {
//     pugl.SetSize(window.view, c.uint(size.x), c.uint(size.y))
//     pugl.EnterContext(window.view)
// }

backend_set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) {
    pugl.SetCursor(current_window().view, _cursor_style_to_pugl_cursor(style))
}

backend_clipboard :: proc() -> string {
    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(current_window().view, 0, &length)
    if clipboard_cstring == nil {
        return ""
    }
    return string(clipboard_cstring)
}

backend_set_clipboard :: proc(data: string) {
    data_cstring := strings.clone_to_cstring(data, context.temp_allocator)
    pugl.SetClipboard(current_window().view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1)
}

backend_load_font :: proc(window: ^Window, font: Font) {
    if len(font.data) <= 0 do return
    if nvg.CreateFontMem(window.nvg_ctx, font.name, font.data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
    }
}

backend_measure_glyphs :: proc(window: ^Window, str: string, font: Font, glyphs: ^[dynamic]Text_Glyph) {
    nvg_ctx := window.nvg_ctx

    clear(glyphs)

    if len(str) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(str), context.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, str, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        glyphs[i] = Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }
}

backend_font_metrics :: proc(window: ^Window, font: Font) -> (metrics: Font_Metrics) {
    nvg_ctx := window.nvg_ctx
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)
    return
}

backend_render_draw_command :: proc(window: ^Window, command: Draw_Command) {
    nvg_ctx := window.nvg_ctx

    switch cmd in command {
    case Fill_Path_Command:
        nvg.Save(nvg_ctx)

        nvg.Translate(nvg_ctx, cmd.position.x, cmd.position.y)
        nvg.BeginPath(nvg_ctx)

        for sub_path in cmd.path.sub_paths {
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
                if sub_path.is_hole {
                    nvg.PathWinding(nvg_ctx, .CW)
                }
            }
        }

        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Fill(nvg_ctx)

        nvg.Restore(nvg_ctx)

    case Fill_String_Command:
        nvg.Save(nvg_ctx)
        position := pixel_snapped(cmd.position)
        nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
        nvg.FontFace(nvg_ctx, cmd.font.name)
        nvg.FontSize(nvg_ctx, f32(cmd.font.size))
        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Text(nvg_ctx, position.x, position.y, cmd.text)
        nvg.Restore(nvg_ctx)

    case Set_Clip_Rectangle_Command:
        rect := pixel_snapped(cmd.global_clip_rectangle)
        nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))

    case Box_Shadow_Command:
        nvg.Save(nvg_ctx)
        rect := cmd.rectangle
        paint := nvg.BoxGradient(
            rect.x, rect.y,
            rect.size.x, rect.size.y,
            cmd.corner_radius,
            cmd.feather,
            cmd.inner_color,
            cmd.outer_color,
        )
        nvg.BeginPath(nvg_ctx)
        nvg.Rect(nvg_ctx,
            rect.x - cmd.feather, rect.y - cmd.feather,
            rect.size.x + cmd.feather * 2, rect.size.y + cmd.feather * 2,
        )
        nvg.FillPaint(nvg_ctx, paint)
        nvg.Fill(nvg_ctx)
        nvg.Restore(nvg_ctx)
    }
}

_pugl_event_proc :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    window := cast(^Window)pugl.GetHandle(view)
    window.view = view
    context = _pugl_odin_context
    ctx := gui_context()

    #partial switch event.type {
    case .UPDATE:
        pugl.PostRedisplay(view)

    case .LOOP_ENTER:
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        event := event.timer
        if window.timer_id == event.id {
            gui_update()
        }

    case .CONFIGURE:
        event := event.configure
        window.position = Vector2{f32(event.x), f32(event.y)}
        window.size = Vector2{f32(event.width), f32(event.height)}

    case .POINTER_IN:
        window.is_mouse_hovered = true

    case .POINTER_OUT:
        window.is_mouse_hovered = false

    case .FOCUS_IN:
        window.is_focused = true

    case .FOCUS_OUT:
        window.is_focused = false

    case .MOTION:
        event := event.motion
        input_mouse_move(ctx, {f32(event.xRoot), f32(event.yRoot)})
        context_update(ctx)
        pugl.PostRedisplay(view)

    case .SCROLL:
        event := &event.scroll
        input_mouse_scroll(ctx, {f32(event.dx), f32(event.dy)})
        context_update(ctx)
        pugl.PostRedisplay(view)

    case .BUTTON_PRESS:
        event := &event.button
        input_mouse_press(ctx, _pugl_button_to_mouse_button(event.button))
        context_update(ctx)
        pugl.PostRedisplay(view)

    case .BUTTON_RELEASE:
        event := &event.button
        input_mouse_release(ctx, _pugl_button_to_mouse_button(event.button))
        context_update(ctx)
        pugl.PostRedisplay(view)

    case .KEY_PRESS:
        event := &event.key
        input_key_press(ctx, _pugl_key_event_to_keyboard_key(event))
        context_update(ctx)
        pugl.PostRedisplay(view)

    case .KEY_RELEASE:
        event := &event.key
        input_key_release(ctx, _pugl_key_event_to_keyboard_key(event))
        context_update(ctx)
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
            input_rune(ctx, r)
            context_update(ctx)
            pugl.PostRedisplay(view)
        }

    case .CLOSE:
        window.should_close = true
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