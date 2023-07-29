package main

import "core:mem"
import "core:fmt"
import "core:thread"
import "gui"

should_quit := false
consola: ^gui.Font

main_loop :: proc() {
	if gui.begin_window("Window 1", background_color = {0.05, 0, 0, 1}) {
		gui.fill_text_line("Hello World 1", gui.mouse_position())

		if gui.window_will_close() {
			should_quit = true
		}

		gui.end_window()
	}
	if gui.begin_window("Window 2", background_color = {0, 0.05, 0, 1}) {
		gui.fill_text_line("Hello World 2", gui.mouse_position())

		if gui.window_will_close() {
			should_quit = true
		}

		gui.end_window()
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

	consola = gui.create_font("Consola", #load("consola.ttf"))
	defer gui.destroy_font(consola)

	gui.startup("DemoApp", consola, main_loop)
	defer gui.shutdown()

	for !should_quit {
		gui.update()
	}
}