package main

import "core:unicode/utf8"
import "core:fmt"
import gl "vendor:OpenGL"
import wnd "os_window"
// import "gui"
import vg "vector_graphics"

main :: proc() {
    window := wnd.create()
    defer wnd.destroy(window)

    wnd.show(window)
    wnd.make_context_current(window)

    gl.load_up_to(3, 3, wnd.gl_set_proc_address)

    ctx := vg.create()
    defer vg.destroy(ctx)

    for wnd.is_open(window) {
        wnd.poll_events(window)

        width, height := wnd.size(window)

        vg.begin_frame(ctx, {width, height})

        gl.ClearColor(0.1, 0.1, 0.1, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        vg.save(ctx)
        vg.restore(ctx)

        vg.set_color(ctx, {0.3, 0.3, 0.3, 1})
        vg.rect(ctx, {0, 0}, {600, 600})

        vg.set_color(ctx, {1, 0, 0, 1})
        vg.translate(ctx, {100, 50})
        vg.text(ctx, "abcdefg12345", {100, 100})

        vg.end_frame(ctx)

        wnd.swap_buffers(window)
    }
}