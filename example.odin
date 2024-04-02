package main

import "core:fmt"
import "core:mem"

// default_font := Font{
//     name = "consola_13",
//     size = 13,
//     data = #load("consola.ttf"),
// }

running := true

window1 := get_id()
window2 := get_id()

update :: proc() {
    if window(window1, {{100, 200}, {400, 300}}, "Window 1") {
        fill_rectangle({{50, 50}, {50, 50}}, {1, 0, 0, 1})

        {
            container({{50, 50}, {200, 200}})
            fill_rectangle({{50, 50}, {50, 50}}, {0, 0, 1, 1})
        }

        if key_pressed(.A) {
            fmt.println("Yee")
        }

        if window(window2, {{600, 200}, {400, 300}}, "Window 2") {
            fill_rectangle({{50, 50}, {50, 50}}, {0, 1, 0, 1})
        }
    }

    if key_pressed(.D) {
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

    for running {
        gui_update()
    }
}