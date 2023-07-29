package main

// import "core:mem"
// import "core:fmt"
// import "core:thread"
// import gl "vendor:OpenGL"
// import "window"

// window_proc :: proc(t: ^thread.Thread) {
// 	w, err := window.create("Parent Window")
// 	if err != nil {
// 		return
// 	}
// 	defer window.destroy(w)

// 	window.activate_context(w)
//     gl.load_up_to(3, 3, window.gl_set_proc_address)
//     window.deactivate_context(w)

// 	window.set_on_frame(w, proc(w: ^window.Window) {
// 		gl.ClearColor(1, 0, 0, 1)
// 		gl.Clear(gl.COLOR_BUFFER_BIT)
// 	})

// 	window.show(w)

// 	w2, err2 := window.create(
// 		title = "Child Window",
// 		parent_handle = window.native_handle(w),
// 		child_kind = .Transient,
// 	)
// 	if err2 != nil {
// 		return
// 	}
// 	defer window.destroy(w2)

// 	window.set_on_frame(w2, proc(w2: ^window.Window) {
// 		gl.ClearColor(0, 1, 0, 1)
// 		gl.Clear(gl.COLOR_BUFFER_BIT)
// 	})

// 	window.show(w2)

// 	for !window.close_requested(w) {
// 		window.update(w)
// 		window.update(w2)
// 	}
// }

// main :: proc() {
// 	when ODIN_DEBUG {
// 		track: mem.Tracking_Allocator
// 		mem.tracking_allocator_init(&track, context.allocator)
// 		context.allocator = mem.tracking_allocator(&track)

// 		defer {
// 			if len(track.allocation_map) > 0 {
// 				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
// 				for _, entry in track.allocation_map {
// 					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
// 				}
// 			}
// 			if len(track.bad_free_array) > 0 {
// 				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
// 				for entry in track.bad_free_array {
// 					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
// 				}
// 			}
// 			mem.tracking_allocator_destroy(&track)
// 		}
// 	}

// 	t := thread.create(window_proc)
// 	t.init_context = context
// 	thread.start(t)

// 	t2 := thread.create(window_proc)
// 	t2.init_context = context
// 	thread.start(t2)

// 	for {
// 		if thread.is_done(t) && thread.is_done(t2) {
// 			break
// 		}
// 	}

// 	thread.destroy(t)
// 	thread.destroy(t2)
// }