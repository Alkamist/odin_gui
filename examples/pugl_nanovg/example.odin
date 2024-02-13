package example_pugl_nanovg

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../../gui"
import "../../../gui/widgets"
import backend "../../backends/pugl_nanovg"
import nvg "vendor:nanovg"

consola_13 := backend.Font{"consola_13", 13, #load("consola.ttf")}

window1: backend.Window
window2: backend.Window

button1: widgets.Button
button2: widgets.Button

button3: widgets.Button
button4: widgets.Button

starting_velocity := gui.Vec2{1000, 0}
velocity := starting_velocity

position: gui.Vec2

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
            fmt.println(cast(^runtime.Default_Temp_Allocator)context.temp_allocator.data)
            fmt.println("Success")
            mem.tracking_allocator_destroy(&track)
        }
    }

    gui.init(update)
    defer gui.shutdown()

    backend.init()
    defer backend.shutdown()

    gui.window_init(&window1, {{50, 50}, {400, 300}})
    defer gui.window_destroy(&window1)

    gui.window_init(&window2, {{500, 50}, {400, 300}})
    defer gui.window_destroy(&window2)

    window1.background_color = {0.2, 0, 0, 1}
    window2.background_color = {0, 0.2, 0, 1}

    widgets.init(&button1)
    button1.position = {50, 50}

    widgets.init(&button2)
    button2.position = {75, 75}

    widgets.init(&button3)
    button3.position = {50, 50}

    widgets.init(&button4)
    button4.position = {75, 75}

    for window1.is_open || window2.is_open {
        gui.update()
    }
}

update :: proc() {
    position.x += velocity.x * gui.delta_time()
    if position.x > 200 {
        velocity.x = -starting_velocity.x
    }
    if position.x < 0 {
        velocity.x = starting_velocity.x
    }

    if gui.window_update(&window1) {
        widgets.update(&button1)
        widgets.draw(&button1)
        widgets.update(&button2)
        widgets.draw(&button2)

        gui.draw_rect({{200, 200}, {200, 200}}, {0.5, 0, 0, 1})
        gui.draw_custom(proc() {
            nvg_ctx := gui.current_window(backend.Window).nvg_ctx
            nvg.BeginPath(nvg_ctx)
            nvg.Rect(nvg_ctx, 250, 250, 200, 200)
            nvg.FillColor(nvg_ctx, {0, 0.5, 0, 1})
            nvg.Fill(nvg_ctx)
        })
        gui.draw_text("Hello window 1.", {250, 250}, &consola_13, {1, 1, 1, 1})
    }

    if gui.window_update(&window2) {
        widgets.update(&button3)
        widgets.draw(&button3)
        widgets.update(&button4)
        widgets.draw(&button4)

        gui.draw_text("Hello window 2.", {50, 50}, &consola_13, {1, 1, 1, 1})
    }
}