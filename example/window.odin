package main

import "core:fmt"
import wnd "../window"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "../../gui"

open_gl_is_loaded: bool

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

    #partial switch e in event {
    case wnd.Open_Event:
        wnd.activate_context(backend_window)
        if !open_gl_is_loaded {
            gl.load_up_to(3, 3, wnd.gl_set_proc_address)
            open_gl_is_loaded = true
        }
        window.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
        gui.input_open(&window.root)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Close_Event:
        wnd.activate_context(backend_window)
        gui.input_close(&window.root)
        nvg_gl.Destroy(window.nvg_ctx)

    case wnd.Display_Event:
        wnd.activate_context(backend_window)

        size := wnd.size(backend_window)
        c := window.background_color

        gl.Viewport(0, 0, i32(size.x), i32(size.y))
        gl.ClearColor(c.r, c.g, c.b, c.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        nvg.BeginFrame(window.nvg_ctx, size.x, size.y, wnd.content_scale(backend_window))

        commands: [dynamic]gui.Draw_Command
        defer delete(commands)

        gui.collect_draw_commands(&commands, &window.root)

        for command in commands {
            render_draw_command(window, command)
        }

        nvg.EndFrame(window.nvg_ctx)

    case wnd.Update_Event:
        gui.input_update(&window.root)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Resize_Event:
        gui.input_resize(&window.root, e.size)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Mouse_Enter_Event:
        gui.input_mouse_enter(&window.root, e.position)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Mouse_Exit_Event:
        gui.input_mouse_exit(&window.root, e.position)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Mouse_Move_Event:
        gui.input_mouse_move(&window.root, e.position)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Mouse_Scroll_Event:
        gui.input_mouse_scroll(&window.root, e.position, e.amount)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Mouse_Press_Event:
        gui.input_mouse_press(&window.root, e.position, cast(gui.Mouse_Button)e.button)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Mouse_Release_Event:
        gui.input_mouse_release(&window.root, e.position, cast(gui.Mouse_Button)e.button)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Key_Press_Event:
        gui.input_key_press(&window.root, cast(gui.Keyboard_Key)e.key)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Key_Release_Event:
        gui.input_key_release(&window.root, cast(gui.Keyboard_Key)e.key)
        redisplay_window_if_necessary(window, &window.root)

    case wnd.Text_Event:
        gui.input_text(&window.root, e.text)
        redisplay_window_if_necessary(window, &window.root)
    }
}

redisplay_window_if_necessary :: proc(window: ^Window, root: ^gui.Root) {
    if root.needs_redisplay {
        wnd.display(&window.backend_window)
        root.needs_redisplay = false
    }
}

render_draw_command :: proc(window: ^Window, command: gui.Draw_Command) {
    ctx := window.nvg_ctx
    switch c in command {
    case gui.Draw_Rect_Command:
        nvg.BeginPath(ctx)
        nvg.Rect(ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        nvg.FillColor(ctx, c.color)
        nvg.Fill(ctx)
    case gui.Clip_Drawing_Command:
        nvg.Scissor(ctx, c.position.x, c.position.y, c.size.x, c.size.y)
    }
}