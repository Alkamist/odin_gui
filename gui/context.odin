package gui

import "core:fmt"
import "core:time"
import gl "vendor:OpenGL"
import backend "window"

@(thread_local) ctx: Context

Context :: struct {
    on_update: proc(),

    current_window: ^Window,
    dummy_window: backend.Window,
    top_level_windows: map[string]^Window,
    window_stack: [dynamic]^Window,

    default_font: ^Font,

    last_id: Id,

    tick: time.Tick,
    previous_tick: time.Tick,

    host_handle: Native_Window_Handle,
}

generate_id :: proc() -> Id {
    ctx.last_id += 1
    return ctx.last_id
}

delta_time :: proc() -> time.Duration {
    return time.tick_diff(ctx.previous_tick, ctx.tick)
}

update :: backend.update

startup :: proc(app_id: string, default_font: ^Font, on_update: proc()) {
    backend.startup(app_id)

    err := backend.open(&ctx.dummy_window,
        title = "",
        size = {400, 300},
        min_size = nil,
        max_size = nil,
        swap_interval = 0,
        dark_mode = true,
        resizable = true,
        double_buffer = true,
        child_kind = .None,
        parent_handle = nil,
    )
    if err != nil {
        fmt.eprintln("Failed to create gui context.")
        return
    }

    ctx.default_font = default_font
    ctx.dummy_window.user_data = &ctx

    ctx.tick = time.tick_now()
    ctx.previous_tick = ctx.tick

    backend.activate_context(&ctx.dummy_window)
    gl.load_up_to(3, 3, backend.gl_set_proc_address)
    backend.deactivate_context(&ctx.dummy_window)

    ctx.on_update = on_update

    backend._update_proc = proc() {
        ctx.previous_tick = ctx.tick
        ctx.tick = time.tick_now()
        ctx.on_update()
    }
}

shutdown :: proc() {
    backend.close(&ctx.dummy_window)

    // Clean up windows.
    for key in ctx.top_level_windows {
        w := ctx.top_level_windows[key]
        _close_window(w)
        _destroy_window(w)
    }

    backend.shutdown()

    delete(ctx.top_level_windows)
    delete(ctx.window_stack)
}