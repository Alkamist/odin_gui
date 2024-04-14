package main

import "core:fmt"
import "core:mem"
import "core:time"
import "core:strings"

default_font := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

update :: proc() {
    if key_pressed(.Comma) {
        gui_stop()
    }

    text_id := get_id("Ayy Lmao")
    text, text_init := get_state(text_id, strings.Builder)
    if text_init {
        strings.builder_init(text)
        fmt.println("Text Initialized")
    }
    defer if state_destroyed() {
        strings.builder_destroy(text)
        free(text)
        fmt.println("Text Destroyed")
    }

    if window("Window 1", {{100, 100}, {400, 300}}) {
        // if box, ok := box_select("Box Select", .Right); ok {
        //     fmt.println(box)
        // }

        // if button("Button 1", {{150, 150}, {100, 50}}, {0.3, 0.3, 0.3, 1}).clicked {
        //     fmt.println("Yee 1")
        // }

        // if button("Button 2", {{0, 0}, {100, 50}}, {0.6, 0.3, 0.3, 1}).clicked {
        //     fmt.println("Yee 2")
        // }

        // editable_text_line(text, {{50, 50}, {100, 100}}, default_font)
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

    for gui_is_running() {
        gui_update()
    }
}