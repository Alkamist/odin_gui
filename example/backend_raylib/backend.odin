package backend_raylib

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:time"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import "../../../gui"

@(thread_local) _ctx: ^Context

Font :: struct {
    rl_font: rl.Font,
    glyph_indices: map[rune]int,
}

font_destroy :: proc(font: ^Font) {
    delete(font.glyph_indices)
}

Context :: struct {
    using ctx: gui.Context,
    background_color: gui.Color,
}

update :: proc() {
    if _ctx == nil do return
    if rl.WindowShouldClose() {
        gui.input_close(_ctx)
        return
    }

    gui.input_move(_ctx, rl.GetWindowPosition())
    gui.input_resize(_ctx, {f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())})

    gui.input_mouse_move(_ctx, rl.GetMousePosition())

    for button in gui.Mouse_Button {
        rl_button := _to_rl_mouse_button(button)
        if rl.IsMouseButtonDown(rl_button) {
            gui.input_mouse_press(_ctx, button)
        } else if rl.IsMouseButtonReleased(rl_button) {
            gui.input_mouse_release(_ctx, button)
        }
    }

    gui.input_mouse_scroll(_ctx, rl.GetMouseWheelMoveV())

    for key in gui.Keyboard_Key {
        rl_key := _to_rl_key(key)
        if rl.IsKeyPressed(rl_key) || rl.IsKeyPressedRepeat(rl_key) {
            gui.input_key_press(_ctx, key)
        } else if rl.IsKeyReleased(rl_key) {
            gui.input_key_release(_ctx, key)
        }
    }

    ch := rl.GetCharPressed()
    for ch != 0 {
        gui.input_text(_ctx, ch)
        ch = rl.GetCharPressed()
    }

    rl.BeginDrawing()

    rl.ClearBackground(_to_rl_color(_ctx.background_color))
    gui.update(_ctx)

    rl.EndDrawing()
}

init :: proc(
    ctx: ^Context,
    position: gui.Vec2,
    size: gui.Vec2,
    temp_allocator := context.temp_allocator,
) -> runtime.Allocator_Error{
    if _ctx != nil do return nil
    gui.init(ctx, position, size, temp_allocator) or_return
    _ctx = ctx
    ctx.tick_now = _tick_now
    ctx.set_cursor_style = _set_cursor_style
    ctx.get_clipboard = _get_clipboard
    ctx.set_clipboard = _set_clipboard
    ctx.measure_text = _measure_text
    ctx.font_metrics = _font_metrics
    ctx.render_draw_command = _render_draw_command
    return nil
}

destroy :: proc(ctx: ^Context) {
    if ctx != _ctx do return
    gui.destroy(ctx)
    rl.CloseWindow()
}

open :: proc(ctx: ^Context) {
    if ctx != _ctx do return
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(i32(ctx.size.x), i32(ctx.size.y), "Raylib Window")
    rl.SetTargetFPS(240)
    gui.input_open(ctx)
    gui.input_mouse_enter(ctx)
}

close :: proc(ctx: ^Context) {
    if ctx != _ctx do return
    gui.input_mouse_exit(ctx)
    gui.input_close(ctx)
    rl.CloseWindow()
}

is_open :: proc(ctx: ^Context) -> bool {
    if ctx != _ctx do return false
    return ctx.is_open
}

load_font_from_data :: proc(font: ^Font, data: []byte, font_size: int) -> (ok: bool) {
    if len(data) <= 0 do return

    CODEPOINT_COUNT :: 95

    font.rl_font = rl.LoadFontFromMemory(".ttf", raw_data(data), i32(len(data)), i32(font_size), nil, CODEPOINT_COUNT)

    for i in 0 ..< CODEPOINT_COUNT {
        font.glyph_indices[font.rl_font.chars[i].value] = i
    }

    ok = true
    return
}



_tick_now :: proc(ctx: ^gui.Context) -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_set_cursor_style :: proc(ctx: ^gui.Context, style: gui.Cursor_Style) -> (ok: bool) {
    rl.SetMouseCursor(_to_rl_mouse_cursor(style))
    return true
}

_get_clipboard :: proc(ctx: ^gui.Context) -> (data: string, ok: bool) {
    cstr := rl.GetClipboardText()
    if cstr == nil do return "", false
    return string(cstr), true
}

_set_clipboard :: proc(ctx: ^gui.Context, data: string)-> (ok: bool) {
    cstr := strings.clone_to_cstring(data, gui.temp_allocator())
    rl.SetClipboardText(cstr)
    return true
}

_measure_text :: proc(
    ctx: ^gui.Context,
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    rune_index_to_glyph_index: ^map[int]int,
) -> (ok: bool) {
    assert(font != nil)
    font := cast(^Font)font

    resize(glyphs, len(text))
    if rune_index_to_glyph_index != nil {
        clear(rune_index_to_glyph_index)
    }

    x := f32(0)
    rune_index := 0

    for r, i in text {
        rl_glyph := font.rl_font.chars[font.glyph_indices[r]]
        width := f32(rl_glyph.advanceX)

        if rune_index_to_glyph_index != nil {
            rune_index_to_glyph_index[rune_index] = i
        }

        glyphs[i] = gui.Text_Glyph{
            rune_index = rune_index,
            position = x,
            width = width,
            kerning = -f32(rl_glyph.offsetX),
        }

        x += width
        rune_index += utf8.rune_size(r)
    }

    return true
}

_font_metrics :: proc(ctx: ^gui.Context, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    assert(font != nil)
    font := cast(^Font)font
    metrics.line_height = f32(font.rl_font.baseSize)
    return metrics, true
}

_render_draw_command :: proc(ctx: ^gui.Context, command: gui.Draw_Command) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    switch c in command {
    case gui.Draw_Rect_Command:
        rl.DrawRectangleV(c.position, c.size, _to_rl_color(c.color))

    case gui.Draw_Text_Command:
        font := cast(^rl.Font)c.font
        text, err := strings.clone_to_cstring(c.text, gui.temp_allocator())
        if err == nil {
            rl.DrawTextEx(font^, text, c.position, f32(font.baseSize), 0, _to_rl_color(c.color))
        }

    case gui.Clip_Drawing_Command:
        rl.EndScissorMode()
		rl.BeginScissorMode(i32(c.position.x), i32(c.position.y), i32(c.size.x), i32(c.size.y))
    }
}

_to_rl_mouse_cursor :: proc(cursor: gui.Cursor_Style) -> rl.MouseCursor {
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