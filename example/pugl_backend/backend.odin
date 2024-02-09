package pugl_backend

import "core:fmt"
import "core:time"
import "core:runtime"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import wnd "../../window"
import "../../../gui"

open_gl_is_loaded: bool

Font :: struct {
    name: string,
    size: f32,
}

update :: wnd.update

Context :: struct {
    using ctx: gui.Context,
    background_color: gui.Color,
    nvg_ctx: ^nvg.Context,
    backend_window: wnd.Window,
}

init :: proc(
    ctx: ^Context,
    position: gui.Vec2,
    size: gui.Vec2,
    temp_allocator := context.temp_allocator,
) -> runtime.Allocator_Error{
    wnd.init(&ctx.backend_window, position, size)
    ctx.backend_window.user_data = ctx
    ctx.backend_window.event_proc = _event_proc
    gui.init(ctx, position, size, temp_allocator) or_return
    ctx.tick_now = _backend_tick_now
    ctx.set_cursor_style = _backend_set_cursor_style
    ctx.get_clipboard = _backend_get_clipboard
    ctx.set_clipboard = _backend_set_clipboard
    ctx.measure_text = _backend_measure_text
    ctx.font_metrics = _backend_font_metrics
    ctx.render_draw_command = _backend_render_draw_command
    return nil
}

destroy :: proc(ctx: ^Context) {
    gui.destroy(ctx)
    wnd.destroy(&ctx.backend_window)
}

open :: proc(ctx: ^Context) {
    wnd.open(&ctx.backend_window, ctx.temp_allocator)
}

close :: proc(ctx: ^Context) {
    wnd.close(&ctx.backend_window)
}

is_open :: proc(ctx: ^Context) -> bool {
    return wnd.is_open(&ctx.backend_window)
}



_event_proc :: proc(backend_window: ^wnd.Window, event: wnd.Event) {
    ctx := cast(^Context)backend_window.user_data

    #partial switch e in event {
    case wnd.Open_Event:
        wnd.activate_context(backend_window)
        if !open_gl_is_loaded {
            gl.load_up_to(3, 3, wnd.gl_set_proc_address)
            open_gl_is_loaded = true
        }
        ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

        _load_font(ctx, "Consola", #load("../consola.ttf"))

        gui.input_open(ctx)
        _update_content_scale(ctx)

        wnd.display(backend_window)

    case wnd.Close_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_close(ctx)
        nvg_gl.Destroy(ctx.nvg_ctx)

    case wnd.Display_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)

        size := wnd.size(backend_window)
        c := ctx.background_color

        gl.Viewport(0, 0, i32(size.x), i32(size.y))
        gl.ClearColor(c.r, c.g, c.b, c.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, wnd.content_scale(backend_window))

        gui.update(ctx)

        nvg.EndFrame(ctx.nvg_ctx)

    case wnd.Update_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        wnd.display(backend_window)

    case wnd.Move_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_move(ctx, e.position)
        wnd.display(backend_window)

    case wnd.Resize_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_resize(ctx, e.size)
        wnd.display(backend_window)

    case wnd.Mouse_Enter_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_mouse_enter(ctx)
        wnd.display(backend_window)

    case wnd.Mouse_Exit_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_mouse_exit(ctx)
        wnd.display(backend_window)

    case wnd.Mouse_Move_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_mouse_move(ctx, e.position)
        wnd.display(backend_window)

    case wnd.Mouse_Scroll_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_mouse_scroll(ctx, e.amount)
        wnd.display(backend_window)

    case wnd.Mouse_Press_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_mouse_press(ctx, cast(gui.Mouse_Button)e.button)
        wnd.display(backend_window)

    case wnd.Mouse_Release_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_mouse_release(ctx, cast(gui.Mouse_Button)e.button)
        wnd.display(backend_window)

    case wnd.Key_Press_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_key_press(ctx, cast(gui.Keyboard_Key)e.key)
        wnd.display(backend_window)

    case wnd.Key_Release_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_key_release(ctx, cast(gui.Keyboard_Key)e.key)
        wnd.display(backend_window)

    case wnd.Text_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(ctx)
        gui.input_text(ctx, e.text)
        wnd.display(backend_window)
    }
}

_update_content_scale :: proc(ctx: ^Context) {
    scale := wnd.content_scale(&ctx.backend_window)
    gui.input_content_scale(ctx, {scale, scale})
}

_load_font :: proc(ctx: ^Context, name: string, font_data: []byte) {
    if nvg.CreateFontMem(ctx.nvg_ctx, name, font_data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", name)
        return
    }
}

_backend_tick_now :: proc(ctx: ^gui.Context) -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_backend_set_cursor_style :: proc(ctx: ^gui.Context, style: gui.Cursor_Style) -> (ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx
    wnd.set_cursor_style(&ctx.backend_window, cast(wnd.Cursor_Style)style)
    return true
}

_backend_measure_text :: proc(
    ctx: ^gui.Context,
    text: string,
    font: gui.Font,
    glyphs: ^[dynamic]gui.Text_Glyph,
    rune_index_to_glyph_index: ^map[int]int,
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
    nvg.FontSize(nvg_ctx, font.size)

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), ctx.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        if rune_index_to_glyph_index != nil {
            rune_index_to_glyph_index[nvg_positions[i].str] = i
        }
        glyphs[i] = gui.Text_Glyph{
            rune_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }

    return true
}

_backend_font_metrics :: proc(ctx: ^gui.Context, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    nvg_ctx := ctx.nvg_ctx
    assert(ctx != nil)

    font := cast(^Font)font

    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, font.size)

    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)

    return metrics, true
}

_backend_get_clipboard :: proc(ctx: ^gui.Context) -> (data: string, ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx
    return wnd.get_clipboard(&ctx.backend_window)
}

_backend_set_clipboard :: proc(ctx: ^gui.Context, data: string)-> (ok: bool) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx
    return wnd.set_clipboard(&ctx.backend_window, data, ctx.temp_allocator)
}

_backend_render_draw_command :: proc(ctx: ^gui.Context, command: gui.Draw_Command) {
    assert(ctx != nil)
    ctx := cast(^Context)ctx

    nvg_ctx := ctx.nvg_ctx

    switch c in command {
    case gui.Draw_Rect_Command:
        nvg.BeginPath(nvg_ctx)
        nvg.Rect(nvg_ctx, c.position.x, c.position.y, max(0, c.size.x), max(0, c.size.y))
        nvg.FillColor(nvg_ctx, c.color)
        nvg.Fill(nvg_ctx)

    case gui.Draw_Text_Command:
        font := cast(^Font)c.font
        nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
        nvg.FontFace(nvg_ctx, font.name)
        nvg.FontSize(nvg_ctx, font.size)
        nvg.FillColor(nvg_ctx, c.color)
        nvg.Text(nvg_ctx, c.position.x, c.position.y, c.text)

    case gui.Clip_Drawing_Command:
        nvg.Scissor(nvg_ctx, c.position.x, c.position.y, max(0, c.size.x), max(0, c.size.y))
    }
}