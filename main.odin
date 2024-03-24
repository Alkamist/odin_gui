package main

import "core:fmt"
import "core:mem"




// Clipping





Test_Window :: struct {
    using window: Window,
    button: Button,
}

window0: Test_Window
window1: Test_Window

test_window_open :: proc() {
    window := current_window(Test_Window)
    window_set_background_color({0.2, 0.2, 0.2, 1})
    button_init(&window.button)
    fmt.println("Opened")
}

test_window_close :: proc() {
    fmt.println("Closed")
}

test_window_update :: proc() {
    window := current_window(Test_Window)

    if window.button.is_down && raw_mouse_moved() {
        window_set_position(window_position() + raw_mouse_delta())
    }

    button_update(&window.button)
    button_draw(&window.button)

    if window_close_button_pressed() {
        window_close()
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

    window_init(&window0)
    defer window_destroy(&window0)
    window0.position = {100, 100}
    window0.open = test_window_open
    window0.close = test_window_close
    window0.update = test_window_update
    window_open(&window0)

    window_init(&window1)
    defer window_destroy(&window1)
    window1.position = {600, 100}
    window1.open = test_window_open
    window1.close = test_window_close
    window1.update = test_window_update
    window_open(&window1)

    for window_is_open(&window0) {
        poll_events()
        free_all(context.temp_allocator)
    }
}