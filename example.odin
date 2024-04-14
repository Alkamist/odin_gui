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

running := true

window: Window

ayy_lmao := false

box_select: Box_Select

editable_text_line: Editable_Text_Line

some_text: strings.Builder

update :: proc() {
    if window_update(&window) {
        if box, ok := box_select_update(&box_select, .Right); ok {
            fmt.println(box)
        }

        if button_update(&ayy_lmao, {{50, 50}, {100, 50}}, {0.5, 0, 0, 1}).clicked {
            fmt.println("Hello")
        }

        editable_text_line_update(&editable_text_line, &some_text, {{200, 200}, {100, 100}}, default_font)

        // track_manager(get_id("Track Manager"))
    }

    if key_pressed(.Comma) {
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
    defer window_destroy(&window)

    strings.builder_init(&some_text)
    defer strings.builder_destroy(&some_text)

    editable_text_line_init(&editable_text_line)
    defer editable_text_line_destroy(&editable_text_line)

    for running {
        gui_update()
    }
}