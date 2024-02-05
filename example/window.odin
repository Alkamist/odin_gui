package main

import "core:fmt"
import "core:time"
import "core:runtime"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import wnd "../window"
import "../../gui"

open_gl_is_loaded: bool

Font :: struct {
    name: string,
    size: f32,
}

Vec2 :: gui.Vec2
Color :: gui.Color
update :: wnd.update

Window :: struct {
    using window: gui.Window,
    background_color: gui.Color,
    nvg_ctx: ^nvg.Context,
    backend_window: wnd.Window,
}

init_window :: proc(
    window: ^Window,
    position := Vec2{0, 0},
    size := Vec2{400, 300},
    background_color := Color{0, 0, 0, 1},
    allocator := context.allocator,
) {
    wnd.init(&window.backend_window,
        position = position,
        size = size,
        user_data = window,
        event_proc = _window_event_proc,
    )
    gui.init_window(window, position, size, allocator)
    window.background_color = background_color
    window.backend.user_data = window
    window.backend.get_tick = _backend_get_tick
    window.backend.set_cursor_style = _backend_set_cursor_style
    window.backend.get_clipboard = _backend_get_clipboard
    window.backend.set_clipboard = _backend_set_clipboard
    window.backend.measure_text = _backend_measure_text
    window.backend.font_metrics = _backend_font_metrics
    window.backend.render_draw_command = _backend_render_draw_command
}

destroy_window :: proc(window: ^Window) {
    gui.destroy_window(window)
    wnd.destroy(&window.backend_window)
}

open_window :: proc(window: ^Window) {
    wnd.open(&window.backend_window)
}

close_window :: proc(window: ^Window) {
    wnd.close(&window.backend_window)
}

window_is_open :: proc(window: ^Window) -> bool {
    return wnd.is_open(&window.backend_window)
}



_window_event_proc :: proc(backend_window: ^wnd.Window, event: wnd.Event) {
    window := cast(^Window)backend_window.user_data

    #partial switch e in event {
    case wnd.Open_Event:
        wnd.activate_context(backend_window)
        if !open_gl_is_loaded {
            gl.load_up_to(3, 3, wnd.gl_set_proc_address)
            open_gl_is_loaded = true
        }
        window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

        _load_font(window, "Consola", #load("consola.ttf"))

        gui.input_window_open(window)
        _update_content_scale(window)

        _redisplay_if_necessary(window)

    case wnd.Close_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_close(window)
        nvg_gl.Destroy(window.nvg_ctx)

    case wnd.Display_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)

        size := wnd.size(backend_window)
        c := window.background_color

        gl.Viewport(0, 0, i32(size.x), i32(size.y))
        gl.ClearColor(c.r, c.g, c.b, c.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        nvg.BeginFrame(window.nvg_ctx, size.x, size.y, wnd.content_scale(backend_window))

        gui.input_window_draw(window)

        nvg.EndFrame(window.nvg_ctx)

    case wnd.Update_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_update(window)
        _redisplay_if_necessary(window)

    case wnd.Move_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_move(window, e.position)
        _redisplay_if_necessary(window)

    case wnd.Resize_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_resize(window, e.size)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Enter_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_mouse_enter(window, e.position)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Exit_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_mouse_exit(window, e.position)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Move_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_mouse_move(window, e.position)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Scroll_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_mouse_scroll(window, e.position, e.amount)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Press_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_mouse_press(window, e.position, cast(gui.Mouse_Button)e.button)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Release_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_mouse_release(window, e.position, cast(gui.Mouse_Button)e.button)
        _redisplay_if_necessary(window)

    case wnd.Key_Press_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_key_press(window, cast(gui.Keyboard_Key)e.key)
        _redisplay_if_necessary(window)

    case wnd.Key_Release_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_key_release(window, cast(gui.Keyboard_Key)e.key)
        _redisplay_if_necessary(window)

    case wnd.Text_Event:
        wnd.activate_context(backend_window)
        _update_content_scale(window)
        gui.input_window_text(window, e.text)
        _redisplay_if_necessary(window)
    }
}

_update_content_scale :: proc(window: ^Window) {
    scale := wnd.content_scale(&window.backend_window)
    gui.input_window_content_scale(window, {scale, scale})
}

_load_font :: proc(window: ^Window, name: string, font_data: []byte) {
    if nvg.CreateFontMem(window.nvg_ctx, name, font_data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", name)
        return
    }
}

_redisplay_if_necessary :: proc(window: ^Window) {
    if window.needs_redisplay {
        wnd.display(&window.backend_window)
        window.needs_redisplay = false
    }
}

_backend_get_tick :: proc(backend: ^gui.Backend) -> (tick: gui.Tick, ok: bool) {
    return time.tick_now(), true
}

_backend_set_cursor_style :: proc(backend: ^gui.Backend, style: gui.Cursor_Style) -> (ok: bool) {
    window := cast(^Window)backend.user_data
    assert(window != nil)
    wnd.set_cursor_style(&window.backend_window, cast(wnd.Cursor_Style)style)
    return true
}

_backend_measure_text :: proc(backend: ^gui.Backend, glyphs: ^[dynamic]gui.Text_Glyph, text: string, font: gui.Font) -> (ok: bool) {
    window := cast(^Window)backend.user_data
    assert(window != nil)

    ctx := window.nvg_ctx
    assert(ctx != nil)

    font := cast(^Font)font

    clear(glyphs)

    if len(text) == 0 {
        return
    }

    nvg.TextAlign(ctx, .LEFT, .TOP)
    nvg.FontFace(ctx, font.name)
    nvg.FontSize(ctx, font.size)

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text), context.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(ctx, 0, 0, text, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        glyphs[i] = gui.Text_Glyph{
            rune_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }

    return true
}

_backend_font_metrics :: proc(backend: ^gui.Backend, font: gui.Font) -> (metrics: gui.Font_Metrics, ok: bool) {
    window := cast(^Window)backend.user_data
    assert(window != nil)

    ctx := window.nvg_ctx
    assert(ctx != nil)

    font := cast(^Font)font

    nvg.FontFace(ctx, font.name)
    nvg.FontSize(ctx, font.size)

    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(window.nvg_ctx)

    return metrics, true
}

_backend_get_clipboard :: proc(backend: ^gui.Backend) -> (data: string, ok: bool) {
    window := cast(^Window)backend.user_data
    assert(window != nil)
    return wnd.get_clipboard(&window.backend_window)
}

_backend_set_clipboard :: proc(backend: ^gui.Backend, data: string)-> (ok: bool) {
    window := cast(^Window)backend.user_data
    assert(window != nil)
    return wnd.set_clipboard(&window.backend_window, data)
}

_backend_render_draw_command :: proc(backend: ^gui.Backend, command: gui.Draw_Command) {
    window := cast(^Window)backend.user_data
    ctx := window.nvg_ctx

    switch c in command {
    case gui.Draw_Rect_Command:
        nvg.BeginPath(ctx)
        nvg.Rect(ctx, c.position.x, c.position.y, max(0, c.size.x), max(0, c.size.y))
        nvg.FillColor(ctx, c.color)
        nvg.Fill(ctx)

    case gui.Draw_Text_Command:
        font := cast(^Font)c.font
        nvg.TextAlign(ctx, .LEFT, .TOP)
        nvg.FontFace(ctx, font.name)
        nvg.FontSize(ctx, font.size)
        nvg.FillColor(ctx, c.color)
        nvg.Text(ctx, c.position.x, c.position.y, c.text)

    case gui.Clip_Drawing_Command:
        nvg.Scissor(ctx, c.position.x, c.position.y, max(0, c.size.x), max(0, c.size.y))
    }
}