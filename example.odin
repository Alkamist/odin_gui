package main

import "core:fmt"
import "core:mem"

consola_13 := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

running := true

window: Window
window2: Window

text: Editable_Text_Line

update :: proc() {
    if window_update(&window) {
        text.position = {100, 100}
        widget_update(&text)
        widget_draw(&text)
    }

    if window_closed(&window) {
        running = false
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
            fmt.println("Success")
        }
    }

    gui_startup(update)
    defer gui_shutdown()

    window_init(&window, {{100, 100}, {400, 300}})
    window.should_open = true
    defer window_destroy(&window)

    window_init(&window2, {{600, 100}, {400, 300}})
    window2.should_open = true
    defer window_destroy(&window2)

    widget_init(&text, consola_13)
    defer widget_destroy(&text)
    text_input_string(&text, "Hello World.")

    for running {
        gui_update()
    }
}