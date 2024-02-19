package backend_raylib

import "base:runtime"
import "core:c"
import "core:math"
import "core:time"
import "core:strings"
import rl "vendor:raylib"
import "../../../gui"

Vec2 :: gui.Vec2
Rect :: gui.Rect
Color :: gui.Color

Font :: struct {
    size: int,
    data: []byte,
    rune_to_glyph_index: map[rune]int,
    rl_font: rl.Font,
}

Window :: struct {
    using gui_window: gui.Window,
    title: string,
    is_resizable: bool,
    background_color: gui.Color,
    target_fps: int,
}

Context :: struct {
    using gui_ctx: gui.Context,
}

_context_vtable := gui.Context_VTable{
    tick_now = _tick_now,
    set_mouse_cursor_style = _set_mouse_cursor_style,
    get_clipboard = _get_clipboard,
    set_clipboard = _set_clipboard,
}

_window_vtable := gui.Window_VTable{
    init = _init_window,
    destroy = _destroy_window,
    open = _open_window,
    close = _close_window,
    show = _show_window,
    hide = _hide_window,
    set_position = _set_window_position,
    set_size = _set_window_size,
    activate_context = nil,
    begin_frame = _window_begin_frame,
    end_frame = _window_end_frame,
    load_font = _load_font,
    measure_text = _measure_text,
    font_metrics = _font_metrics,
    render_draw_command = _render_draw_command,
}

context_vtable :: proc() -> ^gui.Context_VTable {
    return &_context_vtable
}

window_vtable :: proc() -> ^gui.Window_VTable {
    return &_window_vtable
}

_init_window :: proc(window: ^gui.Window) {
    window := cast(^Window)window
    window.title = "Raylib Window"
    window.is_resizable = true
    window.background_color = {0, 0, 0, 0}
    window.target_fps = 240
    window.should_open = true
}

_destroy_window :: proc(window: ^gui.Window) {
    window := cast(^Window)window

    for font in window.loaded_fonts {
        font := cast(^Font)font
        delete(font.rune_to_glyph_index)
    }
    if window.is_open {
        rl.CloseWindow()
    }
}

_open_window :: proc(window: ^gui.Window) -> (ok: bool) {
    window := cast(^Window)window

    if window.is_resizable {
        rl.SetConfigFlags({.WINDOW_RESIZABLE})
    }

    title_cstring := strings.clone_to_cstring(window.title, gui.arena_allocator())
    rl.InitWindow(c.int(window.size.x), c.int(window.size.y), title_cstring)

    rl.SetWindowPosition(c.int(window.position.x), c.int(window.position.y))
    rl.SetTargetFPS(c.int(window.target_fps))

    gui.input_window_mouse_enter(window)

    return true
}

_close_window :: proc(window: ^gui.Window) -> (ok: bool) {
    gui.input_window_mouse_exit(window)
    rl.CloseWindow()
    return true
}

_show_window :: proc(window: ^gui.Window) -> (ok: bool) {
    rl.SetWindowOpacity(1)
    return true
}

_hide_window :: proc(window: ^gui.Window) -> (ok: bool) {
    rl.SetWindowOpacity(0)
    return true
}

_set_window_position :: proc(window: ^gui.Window, position: Vec2) -> (ok: bool)  {
    rl.SetWindowPosition(c.int(position.x), c.int(position.y))
    return true
}

_set_window_size :: proc(window: ^gui.Window, size: Vec2) -> (ok: bool) {
    rl.SetWindowSize(c.int(size.x), c.int(size.y))
    return true
}

_window_begin_frame :: proc(window: ^gui.Window) {
    window := cast(^Window)window

    ctx := gui.current_context()

    if rl.WindowShouldClose() {
        window.is_open = false
        return
    }

    gui.input_window_content_scale(window, rl.GetWindowScaleDPI())

    gui.input_mouse_move(ctx, rl.GetMousePosition() + window.actual_rect.position)

    gui.input_window_move(window, rl.GetWindowPosition())
    gui.input_window_size(window, {f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())})

    for button in gui.Mouse_Button {
        rl_button := _to_rl_mouse_button(button)
        if rl.IsMouseButtonPressed(rl_button) {
            gui.input_mouse_press(ctx, button)
        } else if rl.IsMouseButtonReleased(rl_button) {
            gui.input_mouse_release(ctx, button)
        }
    }

    gui.input_mouse_scroll(ctx, rl.GetMouseWheelMoveV())

    for key in gui.Keyboard_Key {
        rl_key := _to_rl_key(key)
        if rl.IsKeyPressed(rl_key) || rl.IsKeyPressedRepeat(rl_key) {
            gui.input_key_press(ctx, key)
        } else if rl.IsKeyReleased(rl_key) {
            gui.input_key_release(ctx, key)
        }
    }

    ch := rl.GetCharPressed()
    for ch != 0 {
        gui.input_text(ctx, ch)
        ch = rl.GetCharPressed()
    }

    rl.BeginDrawing()

    rl.ClearBackground(_to_rl_color(window.background_color))
    rl.BeginScissorMode(0, 0, c.int(window.actual_rect.size.x), c.int(window.actual_rect.size.y))
}

_window_end_frame :: proc(window: ^gui.Window) {
    rl.EndScissorMode()
    rl.EndDrawing()
}

_load_font :: proc(window: ^gui.Window, font: gui.Font) -> (ok: bool) {
    font := cast(^Font)font

    if len(font.data) <= 0 do return

    CODEPOINT_COUNT :: 95

    font.rl_font = rl.LoadFontFromMemory(
        ".ttf",
        raw_data(font.data),
        c.int(len(font.data)),
        c.int(font.size),
        nil,
        CODEPOINT_COUNT,
    )

    for i in 0 ..< CODEPOINT_COUNT {
        font.rune_to_glyph_index[font.rl_font.chars[i].value] = i
    }

    ok = true
    return
}

_tick_now :: proc() -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_set_mouse_cursor_style :: proc(style: gui.Mouse_Cursor_Style) -> (ok: bool) {
    rl.SetMouseCursor(_to_rl_mouse_cursor(style))
    return true
}

_get_clipboard :: proc() -> (data: string, ok: bool) {
    cstr := rl.GetClipboardText()
    if cstr == nil do return "", false
    return string(cstr), true
}

_set_clipboard :: proc(data: string)-> (ok: bool) {
    cstr := strings.clone_to_cstring(data, gui.arena_allocator())
    rl.SetClipboardText(cstr)
    return true
}

_measure_text :: proc(
    window: ^gui.Window,
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    byte_index_to_rune_index: ^map[int]int,
) -> (ok: bool) {
    assert(font != nil)
    font := cast(^Font)font

    clear(glyphs)
    if byte_index_to_rune_index != nil {
        clear(byte_index_to_rune_index)
    }

    x := f32(0)
    rune_index := 0

    for r, byte_index in text {
        glyph_index := font.rune_to_glyph_index[r] or_else font.rune_to_glyph_index['?']

        rl_glyph := font.rl_font.chars[glyph_index]
        width := f32(rl_glyph.advanceX)

        if byte_index_to_rune_index != nil {
            byte_index_to_rune_index[byte_index] = rune_index
        }

        append(glyphs, gui.Text_Glyph{
            byte_index = byte_index,
            position = x,
            width = width,
            kerning = -f32(rl_glyph.offsetX),
        })

        x += width
        rune_index += 1
    }

    return true
}

_font_metrics :: proc(window: ^gui.Window, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    assert(font != nil)
    font := cast(^Font)font
    metrics.line_height = f32(font.rl_font.baseSize)
    return metrics, true
}

_render_draw_command :: proc(window: ^gui.Window, command: gui.Draw_Command) {
    switch cmd in command {
    case gui.Draw_Custom_Command:
        if cmd.custom != nil {
            cmd.custom()
        }

    case gui.Fill_Path_Command:
        color := _to_rl_color(cmd.color)
        for sub_path in cmd.path.sub_paths {
            for i := 1; i < len(sub_path.points); i += 3 {
                start_point := sub_path.points[i - 1]
                c1 := sub_path.points[i]
                c2 := sub_path.points[i + 1]
                end_point := sub_path.points[i + 2]
                // rl.DrawSplineSegmentBezierCubic(start_point, c1, c2, end_point, 3, color)
                rl.DrawLineV(start_point, end_point, color)
            }
        }

    case gui.Fill_Text_Command:
        font := cast(^Font)cmd.font
        text, err := strings.clone_to_cstring(cmd.text, gui.arena_allocator())
        if err == nil {
            rl.DrawTextEx(font.rl_font, text, gui.pixel_snapped(cmd.position), f32(font.rl_font.baseSize), 0, _to_rl_color(cmd.color))
        }

    case gui.Clip_Drawing_Command:
        rect := gui.pixel_snapped(cmd.global_clip_rect)
        rl.EndScissorMode()
		rl.BeginScissorMode(c.int(rect.position.x), c.int(rect.position.y), c.int(rect.size.x), c.int(rect.size.y))
    }
}

_to_rl_mouse_cursor :: proc(cursor: gui.Mouse_Cursor_Style) -> rl.MouseCursor {
    #partial switch cursor {
    case .Arrow: return .ARROW
    case .I_Beam: return .IBEAM
    case .Crosshair: return .CROSSHAIR
    case .Hand: return .POINTING_HAND
    case .Resize_Left_Right: return .RESIZE_EW
    case .Resize_Top_Bottom: return .RESIZE_NS
    case .Resize_Top_Left_Bottom_Right: return .RESIZE_NWSE
    case .Resize_Top_Right_Bottom_Left: return .RESIZE_NESW
    }
    return .DEFAULT
}

_to_rl_color :: proc(color: gui.Color) -> rl.Color {
    return {
        u8(math.round(color.r * 255)),
        u8(math.round(color.g * 255)),
        u8(math.round(color.b * 255)),
        u8(math.round(color.a * 255)),
    }
}

_to_rl_mouse_button :: proc(button: gui.Mouse_Button) -> rl.MouseButton {
    #partial switch button {
    case .Left: return .LEFT
    case .Middle: return .MIDDLE
    case .Right: return .RIGHT
    case .Extra_1: return .BACK
    case .Extra_2: return .FORWARD
    }
    return .EXTRA
}

_to_rl_key :: proc(button: gui.Keyboard_Key) -> rl.KeyboardKey {
    #partial switch button {
    case .A: return .A
    case .B: return .B
    case .C: return .C
    case .D: return .D
    case .E: return .E
    case .F: return .F
    case .G: return .G
    case .H: return .H
    case .I: return .I
    case .J: return .J
    case .K: return .K
    case .L: return .L
    case .M: return .M
    case .N: return .N
    case .O: return .O
    case .P: return .P
    case .Q: return .Q
    case .R: return .R
    case .S: return .S
    case .T: return .T
    case .U: return .U
    case .V: return .V
    case .W: return .W
    case .X: return .X
    case .Y: return .Y
    case .Z: return .Z
    case .Key_1: return .ONE
    case .Key_2: return .TWO
    case .Key_3: return .THREE
    case .Key_4: return .FOUR
    case .Key_5: return .FIVE
    case .Key_6: return .SIX
    case .Key_7: return .SEVEN
    case .Key_8: return .EIGHT
    case .Key_9: return .NINE
    case .Key_0: return .ZERO
    case .Pad_1: return .KP_1
    case .Pad_2: return .KP_2
    case .Pad_3: return .KP_3
    case .Pad_4: return .KP_4
    case .Pad_5: return .KP_5
    case .Pad_6: return .KP_6
    case .Pad_7: return .KP_7
    case .Pad_8: return .KP_8
    case .Pad_9: return .KP_9
    case .Pad_0: return .KP_0
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
    case .Backtick: return .GRAVE
    case .Minus: return .MINUS
    case .Equal: return .EQUAL
    case .Backspace: return .BACKSPACE
    case .Tab: return .TAB
    case .Caps_Lock: return .CAPS_LOCK
    case .Enter: return .ENTER
    case .Left_Shift: return .LEFT_SHIFT
    case .Right_Shift: return .RIGHT_SHIFT
    case .Left_Control: return .LEFT_CONTROL
    case .Right_Control: return .RIGHT_CONTROL
    case .Left_Alt: return .LEFT_ALT
    case .Right_Alt: return .RIGHT_ALT
    case .Left_Meta: return .LEFT_SUPER
    case .Right_Meta: return .RIGHT_SUPER
    case .Left_Bracket: return .LEFT_BRACKET
    case .Right_Bracket: return .RIGHT_BRACKET
    case .Space: return .SPACE
    case .Escape: return .ESCAPE
    case .Backslash: return .BACKSLASH
    case .Semicolon: return .SEMICOLON
    case .Apostrophe: return .APOSTROPHE
    case .Comma: return .COMMA
    case .Period: return .PERIOD
    case .Slash: return .SLASH
    case .Scroll_Lock: return .SCROLL_LOCK
    case .Pause: return .PAUSE
    case .Insert: return .INSERT
    case .End: return .END
    case .Page_Up: return .PAGE_UP
    case .Delete: return .DELETE
    case .Home: return .HOME
    case .Page_Down: return .PAGE_DOWN
    case .Left_Arrow: return .LEFT
    case .Right_Arrow: return .RIGHT
    case .Down_Arrow: return .DOWN
    case .Up_Arrow: return .UP
    case .Num_Lock: return .NUM_LOCK
    case .Pad_Divide: return .KP_DIVIDE
    case .Pad_Multiply: return .KP_MULTIPLY
    case .Pad_Subtract: return .KP_SUBTRACT
    case .Pad_Add: return .KP_ADD
    case .Pad_Enter: return .KP_ENTER
    case .Pad_Decimal: return .KP_DECIMAL
    case .Print_Screen: return .PRINT_SCREEN
    }
    return .KEY_NULL
}