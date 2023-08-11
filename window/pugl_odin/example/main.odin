package main

import "core:fmt"
import "core:runtime"
import gl "vendor:OpenGL"
import pugl "../../pugl_odin"

should_close := false

on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    context = runtime.default_context()

    #partial switch event.type {

    case .EXPOSE:
        gl.ClearColor(0.05, 0.05, 0.05, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

    case .CLOSE:
        should_close = true

    }

    return .SUCCESS
}

main :: proc() {
    world := pugl.NewWorld(.PROGRAM, {})
    view := pugl.NewView(world)

    // pugl.SetWorldHandle(world, &app)
    pugl.SetWorldString(world, .CLASS_NAME, "DemoWorld")

    pugl.SetViewString(view, .WINDOW_TITLE, "DemoWindow")
    pugl.SetSizeHint(view, .DEFAULT_SIZE, 512, 512)
    pugl.SetSizeHint(view, .MIN_SIZE, 128, 128)
    pugl.SetSizeHint(view, .MAX_SIZE, 1024, 1024)
    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .RESIZABLE, 1)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, 1)
    pugl.SetViewHint(view, .SWAP_INTERVAL, 1)
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    pugl.SetEventFunc(view, on_event)

    status := pugl.Realize(view)

    if status != .SUCCESS {
        fmt.eprintf("Failed to create window (%s)\n", pugl.Strerror(status))
        return
    }

    pugl.Show(view, .RAISE)

    gl.load_up_to(3, 3, pugl.gl_set_proc_address)

    for !should_close {
        pugl.Update(world, 0.0)
    }

    pugl.FreeView(view)
    pugl.FreeWorld(world)
}