package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../gui"
import "../widgets"
import backend "backend_raylib"

consola_13: backend.Font

ctx: backend.Context

button: widgets.Button
slider: widgets.Slider
text: widgets.Text_Line

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

    backend.init(&ctx, {50, 50}, {800, 600})
    defer backend.destroy(&ctx)

    ctx.update = update
    ctx.background_color = {0.2, 0.2, 0.2, 1}

    widgets.init(&button)
    button.position = {20, 20}
    button.size = {400, 32}

    widgets.init(&slider)
    slider.position = {0, button.size.y + 20}
    slider.size = {button.size.x, 24}

    widgets.init(&text)
    defer widgets.destroy(&text)
    text.position = {0, slider.position.y + slider.size.y + 20}
    text.size = {slider.size.x, 200}
    text.font = &consola_13
    widgets.input_string(&text, "ὐ")

    for r, i in "ὐa" {
        fmt.println(i)
    }

    backend.open(&ctx)
    for backend.is_open(&ctx) {
        backend.update()
    }

    backend.font_destroy(&consola_13)
}

update :: proc(ctx: ^gui.Context) {
    if gui.opened() {
        backend.load_font_from_data(&consola_13, #load("consola.ttf"), 13)
    }

    // gui.scoped_clip(gui.mouse_position() - {25, 25}, {50, 50})
    // gui.draw_rect(gui.mouse_position() - {25, 25}, {50, 50}, {0, 0.4, 0, 1}

    if button.is_down && gui.mouse_moved() {
        button.position += gui.mouse_delta()
    }
    widgets.update(&button)
    widgets.draw(&button)

    gui.scoped_position_offset(button.position)

    text.alignment = {slider.value, slider.value}
    widgets.update(&text)
    gui.draw_rect(text.position, text.size, {0.2, 0, 0, 1})
    widgets.draw(&text)

    widgets.update(&slider)
    widgets.draw(&slider)
}