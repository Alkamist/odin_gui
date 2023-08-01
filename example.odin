package main

import "core:mem"
import "core:fmt"
import "core:math"
import "core:time"
import "core:thread"
import "gui"

should_quit := false

pos1: gui.Vec2
pos2: gui.Vec2

t := f32(0)
t2 := f32(0)

window_1: ^gui.Window
child_window: ^gui.Window

main_loop :: proc() {
	if gui.window("Window 1") {
		window_1 = gui.current_window()

		gui.set_window_background_color({0.05, 0, 0, 1})

		dt := f32(time.duration_seconds(gui.delta_time()))
		t += dt
		pos1.x = 100.0 + 100.0 * math.sin(t * 10.0)

		gui.fill_text_line("Window 1", pos1)

		if gui.window("Child Window", .Embedded) {
			child_window = gui.current_window()

			gui.set_window_background_color({0, 0, 0.3, 0})
			gui.fill_text_line("Child Window", pos1)

			if gui.mouse_down(.Left) && gui.mouse_moved() {
				gui.set_window_position(gui.window_position() + gui.mouse_delta())
			}
		}
	}
	if gui.window("Window 2") {
		if gui.window_closed() {
			should_quit = true
		}

		gui.set_window_background_color({0, 0.05, 0, 1})

		dt := f32(time.duration_seconds(gui.delta_time()))
		t2 += dt
		pos2.x = 100.0 + 100.0 * math.sin(t2 * 10.0)

		gui.fill_text_line("Window 2", pos2)

		if gui.mouse_pressed(.Left) {
			gui.open_window(window_1)
			gui.open_window(child_window)
		}
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