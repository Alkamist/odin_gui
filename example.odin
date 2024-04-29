package main

import "core:fmt"
import "core:mem"

running := true

init :: proc() {
    window_init(&track_manager_window, {{100, 100}, {400, 300}})
    track_manager_window.should_open = true
    track_manager_window.background_color = {0.2, 0.2, 0.2, 1}
    track_manager_init(&track_manager)
}

shutdown :: proc() {
    track_manager_destroy(&track_manager)
    window_destroy(&track_manager_window)
}

update :: proc() {
    if window_update(&track_manager_window) {
        track_manager_update(&track_manager)
    }
    if !track_manager_window.is_open {
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

    gui_startup()
    defer gui_shutdown()

    for running {
        gui_update()
    }
}