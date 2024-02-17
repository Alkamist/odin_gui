package backend_glfw

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:time"
import "core:strings"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "vendor:glfw"
import "../../../gui"

OPENGL_VERSION_MAJOR :: 3
OPENGL_VERSION_MINOR :: 3

@(thread_local) _open_gl_is_loaded: bool
@(thread_local) _odin_context: runtime.Context

Vec2 :: gui.Vec2
Rect :: gui.Rect
Color :: gui.Color

Font :: struct {
    name: string,
    size: int,
    data: []byte,
}

Window :: struct {
    using gui_window: gui.Window,
    background_color: gui.Color,

    title: string,
    is_resizable: bool,

    glfw_window: glfw.WindowHandle,

    nvg_ctx: ^nvg.Context,
}

Context :: gui.Context

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

cursors: Glfw_Cursors

init :: proc() {
    if !glfw.Init() {
		fmt.eprintln("Failed to initialize GLFW")
		return
	}
    cursors.arrow = glfw.CreateStandardCursor(glfw.ARROW_CURSOR)
    cursors.ibeam = glfw.CreateStandardCursor(glfw.IBEAM_CURSOR)
    cursors.crosshair = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
    cursors.pointing_hand = glfw.CreateStandardCursor(glfw.HAND_CURSOR)
    cursors.resize_left_right = glfw.CreateStandardCursor(glfw.HRESIZE_CURSOR)
    cursors.resize_top_bottom = glfw.CreateStandardCursor(glfw.VRESIZE_CURSOR)
    cursors.resize_top_left_bottom_right = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
    cursors.resize_top_right_bottom_left = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
}

shutdown :: proc() {
    glfw.DestroyCursor(cursors.arrow)
    glfw.DestroyCursor(cursors.ibeam)
    glfw.DestroyCursor(cursors.crosshair)
    glfw.DestroyCursor(cursors.pointing_hand)
    glfw.DestroyCursor(cursors.resize_left_right)
    glfw.DestroyCursor(cursors.resize_top_bottom)
    glfw.DestroyCursor(cursors.resize_top_left_bottom_right)
    glfw.DestroyCursor(cursors.resize_top_right_bottom_left)
    glfw.Terminate()
}

poll_events :: proc() {
    _odin_context = context
    glfw.PollEvents()
}

setup_vtable :: proc(ctx: ^Context) {
    ctx.backend.tick_now = _tick_now
    ctx.backend.set_mouse_cursor_style = _set_mouse_cursor_style
    ctx.backend.get_clipboard = _get_clipboard
    ctx.backend.set_clipboard = _set_clipboard

    ctx.backend.init_window = _init_window
    ctx.backend.destroy_window = _destroy_window
    ctx.backend.open_window = _open_window
    ctx.backend.close_window = _close_window
    ctx.backend.show_window = _show_window
    ctx.backend.hide_window = _hide_window
    ctx.backend.set_window_position = _set_window_position
    ctx.backend.set_window_size = _set_window_size
    ctx.backend.activate_window_context = _activate_window_context
    ctx.backend.window_begin_frame = _window_begin_frame
    ctx.backend.window_end_frame = _window_end_frame

    ctx.backend.load_font = _load_font
    ctx.backend.measure_text = _measure_text
    ctx.backend.font_metrics = _font_metrics
    ctx.backend.render_draw_command = _render_draw_command
}

_init_window :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    window.is_resizable = true
}

_destroy_window :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    if window.is_open {
        _close_window(window)
    }
    glfw.DestroyWindow(window.glfw_window)
}

_open_window :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window

    glfw.WindowHint(glfw.RESIZABLE, b32(window.is_resizable))
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, OPENGL_VERSION_MAJOR)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, OPENGL_VERSION_MINOR)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    title_cstring := strings.clone_to_cstring(window.title, gui.arena_allocator())

    window.glfw_window = glfw.CreateWindow(
        c.int(window.size.x), c.int(window.size.y),
        title_cstring,
        nil, nil,
    )
    glfw.SetWindowPos(window.glfw_window, c.int(window.position.x), c.int(window.position.y))

    glfw.SetWindowUserPointer(window.glfw_window, window)
    glfw.SetWindowPosCallback(window.glfw_window, _on_window_move)
    glfw.SetWindowSizeCallback(window.glfw_window, _on_window_resize)
    glfw.SetWindowContentScaleCallback(window.glfw_window, _on_window_content_scale_change)
    glfw.SetCursorEnterCallback(window.glfw_window, _on_window_mouse_enter_exit)
    glfw.SetKeyCallback(window.glfw_window, _on_keyboard_key)
    glfw.SetMouseButtonCallback(window.glfw_window, _on_mouse_button)
    glfw.SetCursorPosCallback(window.glfw_window, _on_mouse_move)
    glfw.SetScrollCallback(window.glfw_window, _on_mouse_scroll)
    glfw.SetCharCallback(window.glfw_window, _on_text_input)
    glfw.SetWindowCloseCallback(window.glfw_window, _on_close)

    glfw.MakeContextCurrent(window.glfw_window)

    if !_open_gl_is_loaded {
        gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, glfw.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

    return true
}

_close_window :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window

    nvg_gl.Destroy(window.nvg_ctx)
    window.nvg_ctx = nil

    glfw.DestroyWindow(window.glfw_window)
    window.glfw_window = nil

    return true
}

_show_window :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window
    glfw.ShowWindow(window.glfw_window)
    return true
}

_hide_window :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window
    glfw.HideWindow(window.glfw_window)
    return true
}

_set_window_position :: proc(window: ^gui.Window, position: Vec2) -> (ok: bool)  {
    window := cast(^Window)window
    glfw.SetWindowPos(window.glfw_window, c.int(position.x), c.int(position.y))
    return true
}

_set_window_size :: proc(window: ^gui.Window, size: Vec2) -> (ok: bool) {
    window := cast(^Window)window
    glfw.SetWindowSize(window.glfw_window, c.int(size.x), c.int(size.y))
    return true
}

_activate_window_context :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    glfw.MakeContextCurrent(window.glfw_window)
}

_window_begin_frame :: proc(window: ^gui.Window) {
    window := cast(^Window)window

    size := window.actual_rect.size

    c := window.background_color
    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.ClearColor(c.r, c.g, c.b, c.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    nvg.BeginFrame(window.nvg_ctx, size.x, size.y, window.content_scale.x)
}

_window_end_frame :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    nvg.EndFrame(window.nvg_ctx)
    glfw.SwapBuffers(window.glfw_window)
}

_load_font :: proc(window: ^gui.Window, font: gui.Font) -> (ok: bool) {
    font := cast(^Font)font
    if len(font.data) <= 0 do return false
    window := cast(^Window)window
    if nvg.CreateFontMem(window.nvg_ctx, font.name, font.data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
        return false
    }
    return true
}

_tick_now :: proc() -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_set_mouse_cursor_style :: proc(style: gui.Mouse_Cursor_Style) -> (ok: bool) {
    window := cast(^Window)gui.current_window()
    glfw.SetCursor(window.glfw_window, _cursor_style_to_glfw_cursor(style))
    return true
}

_get_clipboard :: proc() -> (data: string, ok: bool) {
    window := cast(^Window)gui.current_window()
    if window == nil do return "", false
    return glfw.GetClipboardString(window.glfw_window), true
}

_set_clipboard :: proc(data: string)-> (ok: bool) {
    window := cast(^Window)gui.current_window()
    if window == nil do return false
    data_cstring, err := strings.clone_to_cstring(data, gui.arena_allocator())
    if err != nil do return false
    glfw.SetClipboardString(window.glfw_window, data_cstring)
    return true
}

_measure_text :: proc(
    window: ^gui.Window,
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) -> (ok: bool) {
    window := cast(^Window)window
    nvg_ctx := window.nvg_ctx

    font := cast(^Font)font

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), gui.arena_allocator())

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

_font_metrics :: proc(window: ^gui.Window, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    window := cast(^Window)window
    nvg_ctx := window.nvg_ctx

    font := cast(^Font)font

    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)

    return metrics, true
}

_render_draw_command :: proc(window: ^gui.Window, command: gui.Draw_Command) {
    window := cast(^Window)window
    nvg_ctx := window.nvg_ctx

    switch c in command {
    case gui.Draw_Custom_Command:
        if c.custom != nil {
            nvg.Save(nvg_ctx)
            c.custom()
            nvg.Restore(nvg_ctx)
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
        rect := gui.pixel_snapped(c.global_clip_rect)
        nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))
    }
}

_on_window_move :: proc "c" (window: glfw.WindowHandle, xpos, ypos: c.int) {
    context = _odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    gui.input_window_move(window, {f32(xpos), f32(ypos)})
}

_on_window_resize :: proc "c" (window: glfw.WindowHandle, width, height: c.int) {
    context = _odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)

    was_set_by_user := window.size != window.actual_rect.size

    gui.input_window_size(window, {f32(width), f32(height)})

    // Update the context while avoiding recursion.
    if !was_set_by_user {
        gui.context_update(gui.current_context())
    }
}

_on_window_content_scale_change :: proc "c" (window: glfw.WindowHandle, xscale, yscale: f32) {
    context = _odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    gui.input_window_content_scale(window, {xscale, yscale})
}

_on_window_mouse_enter_exit :: proc "c" (window: glfw.WindowHandle, entered: c.int) {
    context = _odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    if entered > 0 {
        gui.input_window_mouse_enter(window)
    } else {
        gui.input_window_mouse_exit(window)
    }
}

_on_keyboard_key :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
    context = _odin_context
    ctx := gui.current_context()
    if action == glfw.PRESS {
        gui.input_key_press(ctx, _to_keyboard_key(key))
    } else if action == glfw.RELEASE {
        gui.input_key_release(ctx, _to_keyboard_key(key))
    }
}

_on_mouse_button :: proc "c" (window: glfw.WindowHandle, button, action, mods: c.int) {
    context = _odin_context
    ctx := gui.current_context()
    if action == glfw.PRESS {
        gui.input_mouse_press(ctx, _to_mouse_button(button))
    } else if action == glfw.RELEASE {
        gui.input_mouse_release(ctx, _to_mouse_button(button))
    }
}

_on_mouse_move :: proc "c" (window: glfw.WindowHandle, xpos,  ypos: f64) {
    context = _odin_context
    ctx := gui.current_context()
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    gui.input_mouse_move(ctx, window.actual_rect.position + {f32(xpos),  f32(ypos)})
}

_on_mouse_scroll :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
    context = _odin_context
    ctx := gui.current_context()
    gui.input_mouse_scroll(ctx, {f32(xoffset),  f32(yoffset)})
}

_on_text_input :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
    context = _odin_context
    ctx := gui.current_context()
    gui.input_text(ctx, codepoint)
}

_on_close :: proc "c" (window: glfw.WindowHandle) {
    context = _odin_context
    window := cast(^Window)glfw.GetWindowUserPointer(window)
    window.should_close = true
}

_to_mouse_button :: proc(glfw_button: c.int) -> gui.Mouse_Button {
    switch glfw_button {
    case glfw.MOUSE_BUTTON_1: return .Left
    case glfw.MOUSE_BUTTON_2: return .Right
    case glfw.MOUSE_BUTTON_3: return .Middle
    case glfw.MOUSE_BUTTON_4: return .Extra_1
    case glfw.MOUSE_BUTTON_5: return .Extra_2
    }
    return .Unknown
}

_to_keyboard_key :: proc(glfw_key: c.int) -> gui.Keyboard_Key {
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

_cursor_style_to_glfw_cursor :: proc(style: gui.Mouse_Cursor_Style) -> glfw.CursorHandle {
    #partial switch style {
    case .Arrow: return cursors.arrow
    case .I_Beam: return cursors.ibeam
    case .Crosshair: return cursors.crosshair
    case .Hand: return cursors.pointing_hand
    case .Resize_Left_Right: return cursors.resize_left_right
    case .Resize_Top_Bottom: return cursors.resize_top_bottom
    case .Resize_Top_Left_Bottom_Right: return cursors.resize_top_left_bottom_right
    case .Resize_Top_Right_Bottom_Left: return cursors.resize_top_right_bottom_left
    }
    return cursors.arrow
}