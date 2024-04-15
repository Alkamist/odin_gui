package main

import "core:fmt"
import "core:mem"
import "core:time"
import "core:strings"

import "core:slice"
import "core:hash/xxhash"

default_font := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}





// Think about destroying state when it is not reached in control flow.
// You would probably have to use destructor functions.





track_manager: Track_Manager

update :: proc() {
    if key_pressed(.Comma) {
        gui_stop()
    }

    if window({{100, 100}, {400, 300}}) {
        track_manager_update(&track_manager)
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
            fmt.println("Success")
        }
    }

    gui_startup(update)
    defer gui_shutdown()

    track_manager.font = default_font
    track_manager_create_new_group(&track_manager, {50, 50})
    track_manager_create_new_group(&track_manager, {50, 100})
    track_manager_create_new_group(&track_manager, {50, 150})
    track_manager_create_new_group(&track_manager, {50, 200})

    for gui_is_running() {
        gui_update()
    }
}


// stuff :: proc(offset: Vector2, loc := #caller_location) {
//     scoped_id_space(loc)
//     scoped_offset(offset)

//     // if button({{0, 0}, {16, 16}}, {0.6, 0.3, 0.3, 1}).clicked {
//     //     fmt.println("Ayy Lmao 1")
//     // }

//     // if button({{50, 0}, {16, 16}}, {0.6, 0.3, 0.3, 1}).clicked {
//     //     fmt.println("Ayy Lmao 2")
//     // }

//     // if button({{100, 0}, {16, 16}}, {0.6, 0.3, 0.3, 1}).clicked {
//     //     fmt.println("Ayy Lmao 3")
//     // }

//     for i in 0 ..< 3 {
//         scoped_iteration(i)
//         for j in 0 ..< 3 {
//             scoped_iteration(j)
//             index := i * 3 + j
//             if button({{f32(index) * 50, 0}, {16, 16}}, {0.6, 0.3, 0.3, 1}).clicked {
//                 fmt.printfln("Ayy Lmao %v", index)
//             }
//         }
//     }
// }

// if box, ok := box_select(.Right); ok {
//     fmt.println(box)
// }

// editable_text_line("Ayy Lmao", {{50, 50}, {100, 100}}, default_font)

// stuff({50, 150})
// stuff({50, 200})