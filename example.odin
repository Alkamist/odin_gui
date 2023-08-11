package main

import "core:mem"
import "core:fmt"
import "gui"

consola := gui.Font{"Consola", #load("consola.ttf")}

State :: struct {
    text_speed: f32,
    text_x: f32,
}

window1 := gui.make_window(
    title = "Window 1",
    position = {200, 200},
    background_color = {0.05, 0.05, 0.05, 1},
    default_font = &consola,
    on_frame = on_frame,
    user_data = &state1,
)

state1 := State{
    text_speed = 1200.0,
    text_x = 0.0,
}

window2 := gui.make_window(
    title = "Window 2",
    position = {600, 200},
    background_color = {0.05, 0.05, 0.05, 1},
    default_font = &consola,
    on_frame = on_frame,
    user_data = &state2,
)

state2 := State{
    text_speed = 1200.0,
    text_x = 0.0,
}

on_frame :: proc() {
    state := gui.get_user_data(State)

    dt := gui.delta_time()

    gui.begin_path()
    gui.rounded_rect({50, 50}, {100, 100}, 5)
    gui.fill_path({1, 0, 0, 1})

    state.text_x += state.text_speed * dt

    size := gui.window_size()

    if state.text_x > size.x {
        state.text_speed = -1200.0
    }
    if state.text_x < 0 {
        state.text_speed = 1200.0
    }

    gui.fill_text_line("Some text.", {state.text_x, 0})
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

    gui.open_window(&window1)

    window2.backend_window.parent_handle = gui.native_window_handle(&window1)
    window2.backend_window.child_kind = .Transient

    gui.open_window(&window2)

    for gui.window_is_open(&window1) && gui.window_is_open(&window2) {
        gui.update()
    }

    gui.destroy_window(&window1)
    gui.destroy_window(&window2)
}