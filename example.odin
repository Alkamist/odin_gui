package main

import "core:fmt"
import "core:mem"

default_font := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

running := true

window: Window
track_manager: Track_Manager

update :: proc() {
    if window_update(&window) {
        track_manager_update(&track_manager)
        track_manager_draw(&track_manager)
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
    window.background_color = {0.2, 0.2, 0.2, 1}
    defer window_destroy(&window)

    track_manager_init(&track_manager)
    defer track_manager_destroy(&track_manager)

    for i in 0 ..< 5 {
        group := new(Track_Group)
        track_group_init(group)
        group.position = {0, f32(i) * 50}
        text_input_string(&group.name, "Ayy LMao!@")
        append(&track_manager.groups, group)
    }

    for running {
        gui_update()
    }
}