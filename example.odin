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
		gui.begin_offset({100, 100})

		gui.begin_path()
		gui.rect({50, 50}, {100, 100})
		gui.fill_path({1, 0, 0, 1})

		gui.end_offset()

		if gui.window_closed() {
			should_quit = true
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