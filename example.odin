package main

import "core:fmt"
import "core:mem"
import "core:runtime"

consola_13 := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

window: Window

update :: proc() {
    if window_update(&window) {
        if key_pressed(.A, true) {
            fmt.println("Ayy")
        }
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
    window_open(&window)
    defer window_destroy(&window)

    for true {
        gui_update()
    }
}