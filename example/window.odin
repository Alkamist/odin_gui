package main

import "core:fmt"
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
    root: gui.Root,
    background_color: gui.Color,
    nvg_ctx: ^nvg.Context,
    backend_window: wnd.Window,
}

init_window :: proc(
    window: ^Window,
    position := Vec2{0, 0},
    size := Vec2{400, 300},
    background_color := Color{0, 0, 0, 1},
) {
    wnd.init(&window.backend_window,
        position = position,
        size = size,
        user_data = window,
        event_proc = _window_event_proc,
    )
    gui.init_root(&window.root, size)
    window.background_color = background_color
    window.root.backend.user_data = window
    window.root.backend.get_clipboard = _backend_get_clipboard
    window.root.backend.set_clipboard = _backend_set_clipboard
    window.root.backend.measure_text = _backend_measure_text
    window.root.backend.font_metrics = _backend_font_metrics
    window.root.backend.render_draw_command = _backend_render_draw_command
}

destroy_window :: proc(window: ^Window) {
    gui.destroy_root(&window.root)
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
    root := &window.root

    #partial switch e in event {
    case wnd.Open_Event:
        wnd.activate_context(backend_window)
        if !open_gl_is_loaded {
            gl.load_up_to(3, 3, wnd.gl_set_proc_address)
            open_gl_is_loaded = true
        }
        window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

        _load_font(window, "Consola", #load("consola.ttf"))

        gui.input_open(root)

        _redisplay_if_necessary(window)

    case wnd.Close_Event:
        wnd.activate_context(backend_window)
        gui.input_close(root)
        nvg_gl.Destroy(window.nvg_ctx)

    case wnd.Display_Event:
        wnd.activate_context(backend_window)

        size := wnd.size(backend_window)
        c := window.background_color

        gl.Viewport(0, 0, i32(size.x), i32(size.y))
        gl.ClearColor(c.r, c.g, c.b, c.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        nvg.BeginFrame(window.nvg_ctx, size.x, size.y, wnd.content_scale(backend_window))

        gui.render_draw_commands(root)

        nvg.EndFrame(window.nvg_ctx)

    case wnd.Update_Event:
        wnd.activate_context(backend_window)
        gui.input_update(root)
        _redisplay_if_necessary(window)

    case wnd.Resize_Event:
        wnd.activate_context(backend_window)
        gui.input_resize(root, e.size)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Enter_Event:
        wnd.activate_context(backend_window)
        gui.input_mouse_enter(root, e.position)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Exit_Event:
        wnd.activate_context(backend_window)
        gui.input_mouse_exit(root, e.position)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Move_Event:
        wnd.activate_context(backend_window)
        gui.input_mouse_move(root, e.position)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Scroll_Event:
        wnd.activate_context(backend_window)
        gui.input_mouse_scroll(root, e.position, e.amount)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Press_Event:
        wnd.activate_context(backend_window)
        gui.input_mouse_press(root, e.position, cast(gui.Mouse_Button)e.button)
        _redisplay_if_necessary(window)

    case wnd.Mouse_Release_Event:
        wnd.activate_context(backend_window)
        gui.input_mouse_release(root, e.position, cast(gui.Mouse_Button)e.button)
        _redisplay_if_necessary(window)

    case wnd.Key_Press_Event:
        wnd.activate_context(backend_window)
        gui.input_key_press(root, cast(gui.Keyboard_Key)e.key)
        _redisplay_if_necessary(window)

    case wnd.Key_Release_Event:
        wnd.activate_context(backend_window)
        gui.input_key_release(root, cast(gui.Keyboard_Key)e.key)
        _redisplay_if_necessary(window)

    case wnd.Text_Event:
        wnd.activate_context(backend_window)
        gui.input_text(root, e.text)
        _redisplay_if_necessary(window)
    }
}

_load_font :: proc(window: ^Window, name: string, font_data: []byte) {
    if nvg.CreateFontMem(window.nvg_ctx, name, font_data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", name)
        return
    }
}

_redisplay_if_necessary :: proc(window: ^Window) {
    if window.root.needs_redisplay {
        wnd.display(&window.backend_window)
        window.root.needs_redisplay = false
    }
}

_backend_measure_text :: proc(backend: ^gui.Backend, glyphs: ^[dynamic]gui.Text_Glyph, text: string, font: gui.Font) {
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

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(text))
    defer delete(nvg_positions)

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
}

_backend_font_metrics :: proc(backend: ^gui.Backend, font: gui.Font) -> gui.Font_Metrics {
    window := cast(^Window)backend.user_data
    assert(window != nil)

    ctx := window.nvg_ctx
    assert(ctx != nil)

    font := cast(^Font)font

    nvg.FontFace(ctx, font.name)
    nvg.FontSize(ctx, font.size)

    metrics: gui.Font_Metrics
    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(window.nvg_ctx)

    return metrics
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