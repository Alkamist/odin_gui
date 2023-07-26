package main

import "core:fmt"
import "core:mem"
import state "state_context"

Foo :: struct {
    a, b, c: int,
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

    ctx := state.context_make()
    defer state.context_destroy(&ctx)

    foo := state.get_state(&ctx, "Foo", Foo{1, 2, 3})
    foo2 := state.get_state(&ctx, "Foo2", Foo{4, 5, 6})

    state.begin_namespace(&ctx, "NamespaceTest")

    foo3 := state.get_state(&ctx, "Foo", Foo{7, 8, 9})
    foo4 := state.get_state(&ctx, "Foo2", Foo{10, 11, 12})

    state.begin_namespace(&ctx, "NamespaceTest2")

    foo5 := state.get_state(&ctx, "Foo", Foo{13, 14, 15})
    foo6 := state.get_state(&ctx, "Foo2", Foo{16, 17, 18})

    state.end_namespace(&ctx)
    state.end_namespace(&ctx)

    foo4.c = 999999

    fmt.println(foo)
    fmt.println(foo2)
    fmt.println(foo3)
    fmt.println(foo4)
    fmt.println(foo5)
    fmt.println(foo6)
}

// package main

// import "core:fmt"
// import "core:time"
// import "core:runtime"
// import "gui"
// import "gui/color"
// import "gui/widgets"
// import nvg "vendor:nanovg"

// button := widgets.init_button()
// button2 := widgets.init_button(position = {100, 100})

// on_frame :: proc(ctx: ^gui.Context) {
//     gui.begin_frame(ctx)

//     // button := widgets.get_button("Button1")
//     widgets.update_button(ctx, &button)
//     widgets.draw_button(ctx, &button)

//     gui.end_frame(ctx)
// }

// on_frame2 :: proc(ctx: ^gui.Context) {
//     gui.begin_frame(ctx)

//     widgets.update_button(ctx, &button2)
//     widgets.draw_button(ctx, &button2)

//     gui.end_frame(ctx)
// }

// main :: proc() {
//     gui.startup()
//     defer gui.shutdown()

//     ctx := gui.create_context("Hello")
//     defer gui.destroy_context(ctx)

//     gui.set_background_color(ctx, color.rgb(49, 51, 56))
//     gui.set_frame_proc(ctx, on_frame)
//     gui.show(ctx)

//     ctx2 := gui.create_context("Hello 2")
//     defer gui.destroy_context(ctx2)

//     gui.set_background_color(ctx2, color.rgb(150, 51, 56))
//     gui.set_frame_proc(ctx2, on_frame2)
//     gui.show(ctx2)

//     for gui.window_is_open(ctx) {
//         gui.update()
//     }
// }