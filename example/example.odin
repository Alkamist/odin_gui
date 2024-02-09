package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../gui"
import "../widgets"
import backend "pugl_backend"

consola := backend.Font{"Consola", 13}

ctx: backend.Context
text: widgets.Text_Line
slider: widgets.Slider

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

    backend.init(&ctx, {50, 50}, {400, 300})
    defer backend.destroy(&ctx)
    ctx.background_color = {0.2, 0.2, 0.2, 1}

    ctx.update = proc(ctx: ^gui.Context) {
        // gui.scoped_clip(gui.mouse_position() - {25, 25}, {50, 50})
        // gui.draw_rect(gui.mouse_position() - {25, 25}, {50, 50}, {0, 0.4, 0, 1})

        gui.draw_rect(text.position, text.size, {0.2, 0, 0, 1})

        text.alignment = {slider.value, slider.value}
        widgets.update(&text)
        widgets.draw(&text)

        widgets.update(&slider)
        widgets.draw(&slider)
    }

    widgets.init(&text)
    defer widgets.destroy(&text)
    text.font = &consola
    text.position = {100, 100}
    text.size = {200, 200}
    widgets.input_string(&text, "Hello world.")

    widgets.init(&slider)

    backend.open(&ctx)
    for backend.is_open(&ctx) {
        backend.update()
    }
}