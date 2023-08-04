package main

import "core:mem"
import "core:fmt"
import "core:time"
import "core:math"
import "core:thread"
import "gui"
import "gui/widgets"

App :: struct {
    should_quit: bool,
    button: ^widgets.Button,
}

create_app :: proc() -> ^App {
    app := new(App)
    app.button = widgets.create_button(position = {75, 75})
    return app
}

destroy_app :: proc(app: ^App) {
    widgets.destroy_button(app.button)
    free(app)
}

app_main :: proc() {
    app := gui.get_user_data(App)

    if gui.window("Window") {
        gui.begin_path()
        gui.rounded_rect({50, 50}, {100, 100}, 5)
        gui.fill_path({1, 0, 0, 1})

        widgets.update_button(app.button)
        widgets.draw_button(app.button)

        if app.button.clicked {
            fmt.println("Clicked")
        }

        if gui.window_closed() {
            app.should_quit = true
        }
    }
}

window_proc :: proc(t: ^thread.Thread) {
    app := create_app()
    defer destroy_app(app)

    gui.set_user_data(app)

    consola := gui.create_font("Consola", #load("consola.ttf"))
    defer gui.destroy_font(consola)

    app_name := fmt.aprint("DemoApp", t.user_index)
    defer delete(app_name)

    gui.startup(app_name, consola, app_main)
    defer gui.shutdown()

    for !app.should_quit {
        gui.update()
    }
}

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    t0 := thread.create(window_proc)
    t0.init_context = context
    t0.user_index = 0
    thread.start(t0)
    defer thread.destroy(t0)

    t1 := thread.create(window_proc)
    t1.init_context = context
    t1.user_index = 1
    thread.start(t1)
    defer thread.destroy(t1)

    for !(thread.is_done(t0) && thread.is_done(t1)) {
    }
}