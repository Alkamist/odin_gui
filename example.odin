package main

import "core:mem"
import "core:fmt"
import "core:time"
import "core:math"
import "gui"
import "widgets"

should_quit := false

performance := widgets.create_performance()

button1 := widgets.create_button({50, 50}, {96, 32})
button2 := widgets.create_button({100, 100}, {32, 96})

position := gui.Vec2{0, 50}
t := f32(0)

main_loop :: proc() {
    widgets.update_performance(performance)

    if gui.window("Window 1") {
        widgets.update_button(button1)
        widgets.draw_button(button1)

        if button1.clicked {
            fmt.println("Button 1 Clicked")
        }

        if gui.window_closed() {
            should_quit = true
        }

        widgets.draw_performance(performance)
    }
    if gui.window("Window 2") {
        widgets.update_button(button2)
        widgets.draw_button(button2)

        if button2.clicked {
            fmt.println("Button 2 Clicked")
        }

        if gui.window_closed() {
            should_quit = true
        }

        widgets.draw_performance(performance)
    }
    if gui.window("Window 3") {
        if gui.window_closed() {
            should_quit = true
        }

        gui.set_window_background_color({0, 0.05, 0, 1})

        dt := f32(time.duration_seconds(gui.delta_time()))
        t += dt
        position.x = 100.0 + 100.0 * math.sin(t * 10.0)

        if gui.window_closed() {
            should_quit = true
        }

        gui.fill_text_line("Hello World", position)

        widgets.draw_performance(performance)
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
        }
    }

    consola := gui.create_font("Consola", #load("consola.ttf"))
    defer gui.destroy_font(consola)

    gui.startup("DemoApp", consola, main_loop)
    defer gui.shutdown()

    for !should_quit {
        gui.update()
    }
}