package main

import "core:mem"
import "core:fmt"
import "gui"
import "gui/widgets"

App :: struct {
    button: ^widgets.Button,
}

on_frame :: proc(window: ^gui.Window) {
    app := cast(^App)window.user_data

    gui.begin_path()
    gui.rounded_rect({50, 50}, {100, 100}, 5)
    gui.fill_path({1, 0, 0, 1})

    widgets.update_button(app.button)
    widgets.draw_button(app.button)

    if app.button.clicked {
        fmt.println("Button clicked.")
    }

    gui.fill_text_line("Some text.", {0, 0})
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

    consola := gui.create_font("Consola", #load("consola.ttf"))
    defer gui.destroy_font(consola)

    app := new(App)
    defer free(app)

    app.button = widgets.create_button(position = {100, 100})
    defer widgets.destroy_button(app.button)

    window := gui.create_window(
        title = "Hello",
        position = {200, 200},
        background_color = {0.05, 0.05, 0.05, 1},
        default_font = consola,
        user_data = app,
    )
    defer gui.destroy_window(window)

    window.on_frame = on_frame

    gui.open_window(window)

    for gui.window_is_open(window) {
        gui.update()
    }
}