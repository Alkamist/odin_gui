package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "vendor:glfw"

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

@(thread_local) _open_gl_is_loaded: bool
@(thread_local) _glfw_odin_context: runtime.Context

Window :: struct {
    using base: Window_Base,
    background_color: Color,

    title: string,
    is_resizable: bool,

    glfw_window: glfw.WindowHandle,

    nvg_ctx: ^nvg.Context,
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

backend_startup :: proc() {
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

backend_shutdown :: proc() {
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

backend_poll_events :: proc() {
    _glfw_odin_context = context
    glfw.PollEvents()
}

backend_window_init :: proc(window: ^Window, rectangle: Rectangle) {
    window.rectangle = rectangle
    window.is_resizable = true
}

backend_window_destroy :: proc(window: ^Window) {
    glfw.DestroyWindow(window.glfw_window)
}

backend_window_begin_frame :: proc(window: ^Window) {
    if !window.is_open do return

    glfw.MakeContextCurrent(window.glfw_window)

    size := window.size

    bg := window.background_color
    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    nvg.BeginFrame(window.nvg_ctx, size.x, size.y, window.content_scale.x)
}

backend_window_end_frame :: proc(window: ^Window) {
    if !window.is_open do return
    nvg.EndFrame(window.nvg_ctx)
    glfw.SwapBuffers(window.glfw_window)
}

backend_window_open :: proc(window: ^Window) {
    glfw.WindowHint(glfw.RESIZABLE, b32(window.is_resizable))
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, OPENGL_VERSION_MAJOR)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, OPENGL_VERSION_MINOR)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    title_cstring := strings.clone_to_cstring(window.title, context.temp_allocator)

    window.glfw_window = glfw.CreateWindow(
        c.int(window.size.x), c.int(window.size.y),
        title_cstring,
        nil, nil,
    )
    glfw.SetWindowPos(window.glfw_window, c.int(window.position.x), c.int(window.position.y))

    glfw.SetWindowUserPointer(window.glfw_window, window)
    glfw.SetWindowPosCallback(window.glfw_window, _glfw_on_move)
    glfw.SetWindowSizeCallback(window.glfw_window, _glfw_on_resize)
    glfw.SetWindowContentScaleCallback(window.glfw_window, _glfw_on_content_scale_change)
    glfw.SetCursorEnterCallback(window.glfw_window, _glfw_on_mouse_enter_exit)
    glfw.SetKeyCallback(window.glfw_window, _glfw_on_keyboard_key)
    glfw.SetMouseButtonCallback(window.glfw_window, _glfw_on_mouse_button)
    glfw.SetCursorPosCallback(window.glfw_window, _glfw_on_mouse_move)
    glfw.SetScrollCallback(window.glfw_window, _glfw_on_mouse_scroll)
    glfw.SetCharCallback(window.glfw_window, _glfw_on_text_input)
    glfw.SetWindowCloseCallback(window.glfw_window, _glfw_on_close)

    glfw.MakeContextCurrent(window.glfw_window)

    if !_open_gl_is_loaded {
        gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, glfw.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

backend_window_close :: proc(window: ^Window) {
    nvg_gl.Destroy(window.nvg_ctx)
    window.nvg_ctx = nil

    glfw.DestroyWindow(window.glfw_window)
    window.glfw_window = nil
}

backend_window_show :: proc(window: ^Window) {
    glfw.ShowWindow(window.glfw_window)
}

backend_window_hide :: proc(window: ^Window) {
    glfw.HideWindow(window.glfw_window)
}

backend_window_set_position :: proc(window: ^Window, position: Vector2) {
    glfw.SetWindowPos(window.glfw_window, c.int(position.x), c.int(position.y))
}

backend_window_set_size :: proc(window: ^Window, size: Vector2) {
    glfw.SetWindowSize(window.glfw_window, c.int(size.x), c.int(size.y))
}

backend_activate_gl_context :: proc(window: ^Window) {
    glfw.MakeContextCurrent(window.glfw_window)
}

backend_set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) {
    glfw.SetCursor(current_window().glfw_window, _cursor_style_to_glfw_cursor(style))
}

backend_clipboard :: proc() -> string {
    return glfw.GetClipboardString(current_window().glfw_window)
}

backend_set_clipboard :: proc(data: string) {
    data_cstring := strings.clone_to_cstring(data, context.temp_allocator)
    glfw.SetClipboardString(current_window().glfw_window, data_cstring)
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

_glfw_on_move :: proc "c" (window: glfw.WindowHandle, xpos, ypos: c.int) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    input_window_move(window, {f32(xpos), f32(ypos)})
}

_glfw_on_resize :: proc "c" (window: glfw.WindowHandle, width, height: c.int) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    size := Vector2{f32(width), f32(height)}
    refresh := size != window.actual_rectangle.size
    input_window_resize(window, size)
    if refresh {
        gui_update(false)
    }
}

_glfw_on_content_scale_change :: proc "c" (window: glfw.WindowHandle, xscale, yscale: f32) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    window.content_scale = {xscale, yscale}
}

_glfw_on_mouse_enter_exit :: proc "c" (window: glfw.WindowHandle, entered: c.int) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    if entered > 0 {
        input_mouse_enter(window)
    } else {
        input_mouse_exit(window)
    }
}

_glfw_on_keyboard_key :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    if action == glfw.PRESS {
        input_key_press(window, _glfw_key_to_keyboard_key(key))
    } else if action == glfw.RELEASE {
        input_key_release(window, _glfw_key_to_keyboard_key(key))
    }
}

_glfw_on_mouse_button :: proc "c" (window: glfw.WindowHandle, button, action, mods: c.int) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    if action == glfw.PRESS {
        input_mouse_press(window, _glfw_button_to_mouse_button(button))
    } else if action == glfw.RELEASE {
        input_mouse_release(window, _glfw_button_to_mouse_button(button))
    }
}

_glfw_on_mouse_move :: proc "c" (window: glfw.WindowHandle, xpos,  ypos: f64) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    input_mouse_move(window, {f32(xpos),  f32(ypos)})
}

_glfw_on_mouse_scroll :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    input_mouse_scroll(window, {f32(xoffset),  f32(yoffset)})
}

_glfw_on_text_input :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    input_rune(window, codepoint)
}

_glfw_on_close :: proc "c" (window: glfw.WindowHandle) {
    context = _glfw_odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    window.should_close = true
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