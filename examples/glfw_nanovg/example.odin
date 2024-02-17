package example_glfw_nanovg

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../../gui"
import "../../../gui/widgets"
import backend "../../backends/glfw_nanovg"
import nvg "vendor:nanovg"

running := true
ctx: backend.Context

consola_13 := backend.Font{"consola_13", 13, #load("consola.ttf")}

window1: backend.Window
window2: backend.Window

text_move_button: widgets.Button
text: widgets.Editable_Text_Line

move_window_button: widgets.Button

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

    backend.init()
    defer backend.shutdown()

    backend.context_init(&ctx)
    defer backend.context_destroy(&ctx)
    ctx.update = update

    backend.window_init(&window1, {{50, 50}, {400, 300}})
    defer backend.window_destroy(&window1)
    window1.should_open = true
    window1.background_color = {0.1, 0.1, 0.1, 1}

    backend.window_init(&window2, {{500, 50}, {400, 300}})
    defer backend.window_destroy(&window2)
    window2.should_open = true
    window2.background_color = {0.1, 0.1, 0.1, 1}

    widgets.init(&text_move_button)
    text_move_button.position = {50, 50}
    text_move_button.size = {400, 32}

    widgets.init(&move_window_button)
    move_window_button.position = {200, 200}

    widgets.init(&text)
    defer widgets.destroy(&text)
    text.font = &consola_13
    widgets.input_string(&text, "Type here: ")

    for running {
        backend.poll_events()
        backend.context_update(&ctx)
    }
}

update :: proc() {
    if gui.window_update(&window1) {
        if text_move_button.is_down && gui.mouse_moved() {
            text_move_button.position += gui.mouse_delta()
        }

        widgets.update(&text_move_button)
        widgets.draw(&text_move_button)

        {
            gui.scoped_offset(text_move_button.position + {0, text_move_button.size.y})

            text_box := gui.Rect{{0, 0}, {text_move_button.size.x, 300}}
            gui.scoped_clip(text_box)
            gui.draw_rect(text_box, {0.2, 0, 0, 1})

            widgets.update(&text)
            widgets.draw(&text)
        }

        if gui.window_update(&window2) {
            gui.draw_rect({{50, 50}, {200, 200}}, {0.5, 0, 0, 1})
            gui.draw_custom(proc() {
                nvg_ctx := window2.nvg_ctx
                nvg.BeginPath(nvg_ctx)
                nvg.Rect(nvg_ctx, 70, 50, 200, 200)
                nvg.FillColor(nvg_ctx, {0, 0.5, 0, 1})
                nvg.Fill(nvg_ctx)
            })
            gui.draw_text("Hello window 2.", {50, 50}, &consola_13, {1, 1, 1, 1})

            if move_window_button.is_down && gui.mouse_moved() {
                window2.position += gui.mouse_delta()
            }

            widgets.update(&move_window_button)
            widgets.draw(&move_window_button)
        }
    }

    if !window1.is_open && !window2.is_open {
        running = false
    }
}