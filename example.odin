package main

import "core:mem"
import "core:fmt"
import "gui"
import "widgets"

Data :: struct {
	button: widgets.Button,
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

    ctx, err := gui.create("Hello")
    if err != nil {
        fmt.eprintln("Failed to create gui.")
        return
    }
    defer gui.destroy(ctx)

	data := new(Data)
	defer free(data)

	widgets.init_button(ctx, &data.button)
	ctx.user_data = data

    gui.set_background_color(ctx, {0.05, 0.05, 0.05, 1})
    gui.set_on_frame(ctx, on_frame)
    gui.show(ctx)

	for !gui.close_requested(ctx) {
		gui.update(ctx)
	}
}

on_frame :: proc(ctx: ^gui.Context) {
    gui.begin_frame(ctx)

	data := cast(^Data)ctx.user_data

	gui.begin_offset(ctx, {100, 100})

	widgets.update_button(ctx, &data.button)
	widgets.draw_button(ctx, &data.button)

    gui.begin_path(ctx)
    gui.rounded_rect(ctx, {50, 50}, {200, 200}, 20)
    gui.fill_path(ctx, {1, 0, 0, 1})

	gui.end_offset(ctx)

    gui.end_frame(ctx)
}