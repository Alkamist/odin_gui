package main

import "core:mem"
import "core:fmt"
import "core:thread"
import "gui"

import nvg "vendor:nanovg"

should_quit := false

main_loop :: proc() {
	nvg_ctx := gui.ctx.nvg_ctx
	if gui.begin_window("Window 1", background_color = {0.05, 0, 0, 1}) {
		nvg.BeginPath(nvg_ctx)
		nvg.Rect(nvg_ctx, 50, 50, 200, 200)
		nvg.FillColor(nvg_ctx, {1, 0, 0, 1})
		nvg.Fill(nvg_ctx)

		if gui.mouse_pressed(.Left) {
			fmt.println("Pressed")
		}

		if gui.window_will_close() {
			fmt.println("Closed")
			should_quit = true
		}

		gui.end_window()
	}
	if gui.begin_window("Window 2", background_color = {0, 0.05, 0, 1}) {
		nvg.BeginPath(nvg_ctx)
		nvg.Rect(nvg_ctx, 50, 50, 200, 200)
		nvg.FillColor(nvg_ctx, {1, 0, 0, 1})
		nvg.Fill(nvg_ctx)

		if gui.mouse_pressed(.Left) {
			fmt.println("Pressed")
		}

		if gui.window_will_close() {
			fmt.println("Closed")
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

	gui.startup(main_loop)
	defer gui.shutdown()

	for !should_quit {
		gui.update()
	}
}