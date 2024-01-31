package main

import "core:fmt"
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
        event_proc = window_event_proc,
    )
    gui.init_root(&window.root, size)
    window.background_color = background_color
    window.root.backend.user_data = window
    window.root.backend.redisplay = backend_redisplay
    window.root.backend.render_draw_command = backend_render_draw_command
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

window_event_proc :: proc(backend_window: ^wnd.Window, event: wnd.Event) {
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

        load_font(window, "Consola", #load("consola.ttf"))

        gui.input_open(root)

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
        gui.input_update(root)

    case wnd.Resize_Event:
        gui.input_resize(root, e.size)

    case wnd.Mouse_Enter_Event:
        gui.input_mouse_enter(root, e.position)

    case wnd.Mouse_Exit_Event:
        gui.input_mouse_exit(root, e.position)

    case wnd.Mouse_Move_Event:
        gui.input_mouse_move(root, e.position)

    case wnd.Mouse_Scroll_Event:
        gui.input_mouse_scroll(root, e.position, e.amount)

    case wnd.Mouse_Press_Event:
        gui.input_mouse_press(root, e.position, cast(gui.Mouse_Button)e.button)

    case wnd.Mouse_Release_Event:
        gui.input_mouse_release(root, e.position, cast(gui.Mouse_Button)e.button)

    case wnd.Key_Press_Event:
        gui.input_key_press(root, cast(gui.Keyboard_Key)e.key)

    case wnd.Key_Release_Event:
        gui.input_key_release(root, cast(gui.Keyboard_Key)e.key)

    case wnd.Text_Event:
        gui.input_text(root, e.text)
    }
}

load_font :: proc(window: ^Window, name: string, font_data: []byte) {
    if nvg.CreateFontMem(window.nvg_ctx, name, font_data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", name)
        return
    }
}

backend_redisplay :: proc(backend: ^gui.Backend) {
    window := cast(^Window)backend.user_data
    wnd.display(&window.backend_window)
}

backend_render_draw_command :: proc(backend: ^gui.Backend, command: gui.Draw_Command) {
    window := cast(^Window)backend.user_data
    ctx := window.nvg_ctx

    switch c in command {
    case gui.Draw_Rect_Command:
        nvg.BeginPath(ctx)
        nvg.Rect(ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        nvg.FillColor(ctx, c.color)
        nvg.Fill(ctx)

    case gui.Draw_Text_Command:
        font := cast(^Font)c.font
        nvg.FontFace(ctx, font.name)
        nvg.FontSize(ctx, font.size)
        nvg.FillColor(ctx, c.color)
        nvg.Text(ctx, c.position.x, c.position.y, c.text)

    case gui.Clip_Drawing_Command:
        nvg.Scissor(ctx, c.position.x, c.position.y, c.size.x, c.size.y)
    }
}