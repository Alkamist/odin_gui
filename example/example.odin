package main

import "core:mem"
import "core:fmt"
import "../../gui"

Vec2 :: gui.Vec2
Color :: gui.Color

consola := gui.Font{"Consola", #load("consola.ttf")}

window1: gui.Window

position := gui.Vec2{0, 0}

draw_cross :: proc(position, size: Vec2, thickness: f32, color: Color) {
    if size.x <= 0 || size.y <= 0 {
        return
    }

    pixel := gui.pixel_distance()
    position := gui.pixel_align(position)
    size := gui.quantize(size, pixel * 2.0) + pixel

    half_size := size * 0.5

    gui.begin_path()

    gui.path_move_to(position + {0, half_size.y})
    gui.path_line_to(position + {size.x, half_size.y})

    gui.path_move_to(position + {half_size.x, 0})
    gui.path_line_to(position + {half_size.x, size.y})

    gui.stroke_path(color, thickness)
}

thickness := f32(10)

on_frame :: proc() {
    dt := gui.delta_time()

    if gui.mouse_wheel_moved() {
        thickness += gui.mouse_wheel().y
    }
    thickness = clamp(thickness, 0, 80)

    draw_cross(
        position = position,
        size = {thickness, thickness},
        thickness = 1,
        color = {1, 1, 1, 1},
    )

    // gui.fill_text_line("Hello World.", {0, 0})

    position += {0.5, 0.5} * dt
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

    gui.open_window(&window1)

    for gui.window_is_open(&window1) {
        gui.update()
    }

    gui.destroy_window(&window1)
}