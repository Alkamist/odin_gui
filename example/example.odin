package main

import "core:fmt"
import "core:mem"
import "core:math/rand"
import "../../gui"
import "../widgets"

window: Window
buttons: [8]widgets.Button
slider: widgets.Slider

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

    init_window(&window,
        position = {50, 50},
        size = {400, 300},
        background_color = {0.2, 0.2, 0.2, 1},
    )
    defer destroy_window(&window)

    for &button, i in buttons {
        widgets.init_button(&button, &window.root,
            position = {f32(i * 20), f32(i * 20)},
            size = {32 + rand.float32() * 100, 32 + rand.float32() * 100},
            event_proc = proc(widget, subject: ^gui.Widget, event: any) {
                button := cast(^widgets.Button)widget
                widgets.button_event_proc(button, subject, event)

                switch subject {
                case nil:
                    switch e in event {
                    case gui.Mouse_Move_Event:
                        if gui.mouse_down(.Right) {
                            gui.set_position(button.position + e.delta)
                            gui.redraw()
                        }
                    }

                case widget:
                    switch e in event {
                    case gui.Mouse_Move_Event:
                        if button.is_down {
                            gui.set_position(button.position + e.delta)
                            gui.redraw()
                        }
                    case widgets.Button_Click_Event:
                        fmt.println("Clicked")
                    }
                }
            },
        )
    }
    defer for &button in buttons {
        widgets.destroy_button(&button)
    }

    widgets.init_slider(&slider, &window.root,
        position = {100, 100},
        event_proc = proc(widget, subject: ^gui.Widget, event: any) {
            slider := cast(^widgets.Slider)widget
            widgets.slider_event_proc(widget, subject, event)
            switch subject {
            case widget:
                switch e in event {
                case widgets.Slider_Value_Change_Event:
                    fmt.println(e.value)
                }
            }
        },
    )
    defer widgets.destroy_slider(&slider)

    open_window(&window)
    for window_is_open(&window) {
        update()
    }
}











// import "core:fmt"
// import "core:mem"
// import "core:math/rand"
// import "../../gui"
// import "../widgets"

// SAMPLE_TEXT :: `
// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean vestibulum sit amet ex eu laoreet. Maecenas at hendrerit nisl. Morbi eget est nec nibh feugiat rhoncus in id mi. Curabitur tempus felis arcu, ut sagittis purus scelerisque sit amet. Suspendisse gravida ultricies auctor. Nullam et suscipit urna, sed mollis mauris. Suspendisse faucibus, turpis ut molestie lobortis, urna nibh tempor urna, ut hendrerit erat eros in justo. Sed pulvinar, augue vel facilisis faucibus, erat est volutpat arcu, quis pulvinar ex ipsum nec elit. Fusce vulputate tellus consectetur, ultrices velit nec, ultrices metus. Etiam posuere, leo eget imperdiet pellentesque, mauris est lobortis est, et aliquet dolor erat vitae nibh. Pellentesque eu mattis metus. Aliquam fermentum nisi a neque molestie sagittis. Phasellus porta nisl sit amet libero auctor porta. Duis metus tellus, dapibus id dignissim ut, accumsan ac odio. Sed sit amet rutrum quam. Praesent sagittis blandit sem, eu molestie elit blandit eget.

// Sed ullamcorper mauris vel libero sagittis elementum. Etiam aliquam ac urna id hendrerit. Maecenas consequat, quam sed lacinia mollis, mi nulla iaculis dolor, ac laoreet risus ex et erat. Proin consequat ante lorem, eu dapibus tortor semper id. Ut ut erat sit amet turpis faucibus aliquet ut ut orci. Quisque ut tortor id purus tincidunt aliquam. Praesent bibendum pretium odio a finibus. Aliquam placerat condimentum augue quis ullamcorper. Quisque volutpat elementum risus, a lobortis purus finibus sed. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nulla eget ex pellentesque, aliquet metus ut, dignissim nisl.

// Nulla facilisi. Donec nulla justo, pharetra sit amet magna a, condimentum consequat augue. Duis eleifend porttitor quam quis sodales. In augue odio, posuere efficitur purus id, eleifend tempor odio. Fusce condimentum sit amet tellus eget lobortis. Nullam accumsan felis nulla, dapibus ullamcorper purus luctus sit amet. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras at elit ac est pharetra maximus. Maecenas commodo semper sapien, eleifend ornare felis iaculis eget. Aenean vehicula ipsum lacinia suscipit laoreet. Etiam vitae ipsum convallis, vestibulum augue id, commodo nunc. Donec mollis, urna a congue interdum, magna nunc fermentum dolor, at efficitur sem augue non erat.

// Maecenas fringilla tortor sed nibh sagittis, vel auctor orci dapibus. Nam posuere mollis lectus, et pharetra sapien malesuada a. Sed bibendum, metus ullamcorper mattis gravida, purus diam condimentum lacus, eu eleifend quam neque vitae libero. Suspendisse congue tincidunt velit posuere feugiat. Morbi sodales, nisl sit amet hendrerit tempus, justo dolor feugiat lacus, sed semper ipsum mi at sem. Phasellus lacus justo, porttitor volutpat urna a, egestas posuere orci. Nullam ut justo sapien. Ut dictum lorem et nunc posuere porttitor. Vivamus efficitur, diam at molestie maximus, ex nunc hendrerit libero, nec finibus tellus nulla eget ligula. Curabitur sodales purus sed odio luctus faucibus.

// Vestibulum vehicula libero sit amet sapien tristique, et aliquet dui mollis. Fusce vel porta odio. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nunc posuere lorem feugiat sem tristique, eu consectetur leo dapibus. Donec nec volutpat magna. Fusce pellentesque lacus ac pretium sodales. Duis eleifend lacus ut rhoncus faucibus. Fusce sed magna felis. Donec iaculis consequat lectus vitae rutrum. Nullam at velit id libero tempus elementum eu vel magna. Donec pellentesque faucibus leo at ornare. Donec aliquet volutpat turpis, eget euismod tellus placerat fermentum. Aenean laoreet porta nunc et semper. Vestibulum laoreet tempor tempor. Aliquam ac ullamcorper purus.`

// consola := Font{"Consola", 13}

// window: Window
// grid: gui.Widget
// buttons: [8]widgets.Button
// slider: widgets.Slider
// text: widgets.Text

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
//         }
//     }

//     init_window(&window,
//         position = {50, 50},
//         size = {400, 300},
//         background_color = {0.2, 0.2, 0.2, 1},
//     )
//     defer destroy_window(&window)

//     gui.init_widget(&grid,
//         size = {400, 300},
//         event_proc = proc(widget, subject: ^gui.Widget, event: any) {
//             switch subject {
//             case nil:
//                 switch e in event {
//                 case gui.Open_Event:
//                     gui.layout_grid(widget.children[:],
//                         shape = {3, 3},
//                         size = widget.size,
//                         spacing = {5, 5},
//                         padding = {10, 10},
//                     )
//                     gui.redraw()
//                 }

//             case widget.parent:
//                 switch e in event {
//                 case gui.Resize_Event:
//                     gui.set_size(widget.parent.size)
//                     gui.layout_grid(widget.children[:],
//                         shape = {3, 3},
//                         size = widget.size,
//                         spacing = {5, 5},
//                         padding = {10, 10},
//                     )
//                     gui.redraw()
//                 }

//             case widget:
//                 switch e in event {
//                 case gui.Mouse_Scroll_Event:
//                     consola.size += e.amount.y
//                     gui.redraw()

//                 case gui.Draw_Event:
//                     gui.draw_rect({0, 0}, widget.size, {0.4, 0, 0, 1})
//                 }
//             }
//         },
//     )
//     defer gui.destroy_widget(&grid)

//     for &button, i in buttons {
//         widgets.init_button(&button,
//             position = {f32(i * 20), f32(i * 20)},
//             size = {32 + rand.float32() * 100, 32 + rand.float32() * 100},
//             event_proc = proc(widget, subject: ^gui.Widget, event: any) {
//                 button := cast(^widgets.Button)widget
//                 widgets.button_event_proc(button, subject, event)

//                 switch subject {
//                 case nil:
//                     switch e in event {
//                     case gui.Mouse_Move_Event:
//                         if gui.mouse_down(.Right) {
//                             gui.set_position(button.position + e.delta)
//                             gui.redraw()
//                         }
//                     }

//                 case widget:
//                     switch e in event {
//                     case gui.Show_Event:
//                         fmt.println("Shown")
//                     case gui.Hide_Event:
//                         fmt.println("Hidden")
//                     case gui.Mouse_Move_Event:
//                         if button.is_down {
//                             gui.set_position(button.position + e.delta)
//                             gui.redraw()
//                         }
//                     case widgets.Button_Click_Event:
//                         fmt.println("Clicked")
//                     }
//                 }
//             },
//         )
//         gui.add_children(&grid, {&button})
//     }
//     defer for &button, i in buttons {
//         widgets.destroy_button(&button)
//     }

//     widgets.init_slider(&slider,
//         position = {100, 100},
//         // event_proc = proc(widget, subject: ^gui.Widget, event: any) {
//         //     slider := cast(^widgets.Slider)widget

//         //     switch subject {
//         //     case widget:
//         //         switch e in event {
//         //         case widgets.Slider_Value_Change_Event:
//         //             consola.size = slider.value * 64
//         //             gui.redraw(&grid)
//         //         }
//         //     }

//         //     widgets.slider_event_proc(widget, subject, event)
//         // },
//     )
//     defer widgets.destroy_slider(&slider)

//     widgets.init_text(&text, {50, 50}, {100, 100}, SAMPLE_TEXT, font = &consola)
//     defer widgets.destroy_text(&text)

//     gui.add_children(&window.root, {&grid})

//     open_window(&window)
//     for window_is_open(&window) {
//         update()
//     }
// }