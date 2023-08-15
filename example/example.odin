package main

import "core:mem"
import "core:fmt"
import "../../gui"
import "../../gui/widgets"

Vec2 :: gui.Vec2
Color :: gui.Color

consola := gui.Font{"Consola", #load("consola.ttf")}

window1: gui.Window

text := widgets.DEFAULT_TEXT

on_frame :: proc() {
    text.data = "Hello world."
    text.font = &consola
    widgets.update_text(&text)

    gui.begin_path()
    gui.path_rect(text.position, text.size)
    gui.fill_path({1, 0, 0, 1})

    widgets.draw_text(&text)

    text.position += {20, 20} * gui.delta_time()
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

    gui.init_window(
        &window1,
        title = "Window 1",
        position = {200, 200},
        background_color = {0.05, 0.05, 0.05, 1},
        default_font = &consola,
        on_frame = on_frame,
    )
    defer gui.destroy_window(&window1)

    gui.open_window(&window1)

    for gui.window_is_open(&window1) {
        gui.update()
    }

    widgets.destroy_text(&text)
}