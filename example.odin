package main

import "core:fmt"
import "core:mem"
import "core:time"
import "core:strings"



// Figure out the clipping/input situation




default_font := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

running := true

window1: Window
// window2: Window

text: strings.Builder

update :: proc() {
    if window_update(&window1) {
        if box, ok := box_select(1, .Right); ok {
            fmt.println(box)
        }

        // if button(2, {{50, 50}, {100, 50}}, {0.3, 0.3, 0.3, 1}).clicked {
        //     fmt.println("Yee")
        // }

        editable_text_line(3, &text, {{50, 50}, {100, 100}}, default_font)
    }

    // if key_pressed(.D) {
    //     running = false
    // }
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

    window_init(&window1, {{100, 100}, {400, 300}})
    window1.background_color = {0.2, 0.2, 0.2, 1}
    defer window_destroy(&window1)

    strings.builder_init(&text)

    for running {
        gui_update()
    }
}














// package main

// import "core:fmt"
// import "core:mem"
// import "core:time"

// // default_font := Font{
// //     name = "consola_13",
// //     size = 13,
// //     data = #load("consola.ttf"),
// // }

// running := true

// window1: Window
// window2: Window

// // button1: Button
// // button2: Button

// // container1: Container
// // container2: Container

// update :: proc() {
//     if window_update(&window1) {
//         // scoped_clip({{58, 58}, {70, 70}})

//         // button1.position = {50, 50}
//         // button2.position = {65, 65}

//         // button_update(&button1)
//         // button_draw(&button1)

//         // button_update(&button2)
//         // button_draw(&button2)

//         // container1.position = {50, 50}
//         // container1.size = {100, 100}
//         // if container_update(&container1) {
//         //     fill_rectangle({{0, 0}, current_container().size}, {1, 0, 0, 1})

//         //     container2.position = {25, 25}
//         //     container2.size = {100, 100}
//         //     if container_update(&container2) {
//         //         fill_rectangle({{0, 0}, current_container().size}, {0, 1, 0, 1})
//         //     }
//         // }

//         fmt.println(cast(rawptr)window1.mouse_hovered_container)


//         // container1.position = {50, 50}
//         // container1.size = {100, 100}

//         // container2.position = {50, 50}
//         // container2.size = {100, 100}

//         // if container_update(&container1) {
//         //     fill_rectangle({{0, 0}, current_container().size}, {1, 0, 0, 1})
//         //     if container_update(&container2) {
//         //         fill_rectangle({{0, 0}, current_container().size}, {0, 1, 0, 1})
//         //     }
//         // }

//         // if key_pressed(.A) {
//         //     container1.is_open = !container1.is_open
//         // }

//         // if window_update(&window2) {
//         //     fill_rectangle({{0, 0}, current_container().size}, {0, 1, 0, 1})
//         // }
//     }

//     if key_pressed(.D) {
//         running = false
//     }
// }

// main :: proc() {
//     when ODIN_DEBUG {
//         track: mem.Tracking_Allocator
//         mem.tracking_allocator_init(&track, context.allocator)
//         context.allocator = mem.tracking_allocator(&track)

//         defer {
//             if len(track.allocation_map) > 0 {
//                 fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
//                 for _, entry in track.allocation_map {
//                     fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
//                 }
//             }
//             if len(track.bad_free_array) > 0 {
//                 fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
//                 for entry in track.bad_free_array {
//                     fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
//                 }
//             }
//             mem.tracking_allocator_destroy(&track)
//             fmt.println("Success")
//         }
//     }

//     gui_startup(update)
//     defer gui_shutdown()

//     window_init(&window1, {{100, 100}, {400, 300}})
//     defer window_destroy(&window1)

//     window_init(&window2, {{600, 100}, {400, 300}})
//     defer window_destroy(&window2)

//     // button_init(&button1)
//     // button_init(&button2)

//     container_init(&container1)
//     container_init(&container2)

//     for running {
//         gui_update()
//     }
// }