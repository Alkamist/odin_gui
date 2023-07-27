package main

import "core:mem"
import "core:fmt"
import "gui"

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

    ctx, err := gui.create("Hello")
    if err != nil {
        fmt.eprintln("Failed to create gui.")
        return
    }
    defer gui.destroy(ctx)

    gui.set_background_color(ctx, {0.05, 0.05, 0.05, 1})
    gui.set_on_frame(ctx, on_frame)
    gui.show(ctx)

	ctx2, err2 := gui.create("Hello 2")
    if err2 != nil {
        fmt.eprintln("Failed to create gui.")
        return
    }
    defer gui.destroy(ctx2)

    gui.set_background_color(ctx2, {0.05, 0.05, 0.05, 1})
    gui.set_on_frame(ctx2, on_frame2)
    gui.show(ctx2)

	for {
		gui.update(ctx)
		gui.update(ctx2)
        if gui.close_requested(ctx) || gui.close_requested(ctx2) {
            break
        }
	}
}

on_frame :: proc(ctx: ^gui.Context) {
    gui.begin_frame(ctx)

	gui.begin_offset(ctx, {100, 100})

    gui.begin_path(ctx)
    gui.rounded_rect(ctx, {50, 50}, {200, 200}, 20)
    gui.fill_path(ctx, {1, 0, 0, 1})

	gui.end_offset(ctx)

    gui.end_frame(ctx)
}

on_frame2 :: proc(ctx: ^gui.Context) {
    gui.begin_frame(ctx)

    gui.begin_path(ctx)
    gui.rounded_rect(ctx, {50, 50}, {200, 200}, 20)
    gui.fill_path(ctx, {1, 1, 0, 1})

    gui.end_frame(ctx)
}