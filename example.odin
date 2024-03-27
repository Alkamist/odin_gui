package main

import "core:fmt"
import "core:mem"
import "core:runtime"

consola_13 := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

Test_Window :: struct {
    using window: Window,
    button: Button,
    text: Editable_Text_Line,
}

window0: Test_Window
window1: Test_Window

test_window_init :: proc(window: ^Test_Window, allocator := context.allocator) -> runtime.Allocator_Error {
    window_init(window) or_return
    window.update = test_window_update
    button_init(&window.button)
    editable_text_line_init(&window.text, consola_13) or_return
    editable_text_line_input_string(&window.text, "Hello World.")
    return nil
}

test_window_destroy :: proc(window: ^Test_Window) {
    editable_text_line_destroy(&window.text)
    window_destroy(window)
}

test_window_update :: proc() {
    window := cast(^Test_Window)current_window()

    // if window.button.is_down && screen_mouse_moved() {
    //     window_set_position(window_position() + screen_mouse_delta())
    // }

    {
        scoped_offset({50, 50})

        path := temp_path()
        path_rectangle(&path, {{50, 50}, {200, 200}})
        fill_path(path, {0.4, 0, 0, 1})

        scoped_clip({{50, 50}, {200, 200}})
        // window.text.position = mouse_position()
        window.text.position = {100, 100}
        editable_text_line_update(&window.text)
        editable_text_line_draw(&window.text)
    }

    // fill_text("Hello world.", {150, 150}, consola_13, {0, 1, 0, 1})

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

    test_window_init(&window0)
    defer test_window_destroy(&window0)
    window0.position = {100, 100}
    window0.background_color = {0, 0.2, 0.2, 1}
    window_open(&window0)

    test_window_init(&window1)
    defer test_window_destroy(&window1)
    window1.position = {600, 100}
    window1.background_color = {0.2, 0.2, 0, 1}
    window_open(&window1)

    for window_is_open(&window0) {
        poll_events()
        free_all(context.temp_allocator)
    }
}