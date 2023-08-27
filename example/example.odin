package main

import "core:mem"
import "core:fmt"
import "../../gui"
import "../../gui/widgets"

Vec2 :: gui.Vec2
Color :: gui.Color

consola := gui.Font{"Consola", #load("consola.ttf")}

window1: gui.Window

is_editable: bool

// on_frame :: proc() {
//     text.position = {100, 100}

//     if gui.mouse_pressed(.Right) {
//         is_editable = !is_editable
//     }

//     widgets.update_text(&text)
//     if is_editable {
//         widgets.edit_text(&text)
//     }

//     // gui.begin_path()
//     // gui.path_rect(text.position, text.size)
//     // gui.fill_path({1, 0, 0, 1})

//     widgets.draw_text(&text)

//     // text.position += {20, 20} * gui.delta_time()
// }

text: widgets.Text

on_frame :: proc() {
    // layout := gui.Rect{{0, 0}, gui.window_position(gui.current_window())}

    // top_bar := gui.trim_top(&layout, 32)

    text.position = {100, 100}

    widgets.update_text(&text)
    widgets.edit_text(&text)
    widgets.draw_text(&text, show_selection = true)

    // tool_bar := gui.claim_space(&layout, .Top, 32)

    // gui.outline_rect(gui.claim_space(&tool_bar, .Left, 100).rect, {1, 1, 1, 0.5})
    // gui.outline_rect(gui.claim_space(&tool_bar, .Left, 100).rect, {1, 1, 1, 0.5})
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

    if gui.init() != nil {
        fmt.eprintln("Failed to initialize gui.")
        return
    }

    widgets.set_default_font(&consola)

    text = widgets.make_text("Hello world.")
    defer widgets.destroy_text(&text)

    window1 = gui.make_window(
        title = "Window 1",
        position = {200, 200},
        background_color = {0.05, 0.05, 0.05, 1},
        on_frame = on_frame,
    )
    defer gui.destroy_window(&window1)

    gui.open_window(&window1)

    for gui.window_is_open(&window1) {
        gui.update()
        free_all(context.temp_allocator)
    }
}