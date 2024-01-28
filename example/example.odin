package main

import "core:fmt"
import "core:mem"
import "../../gui"
import "../widgets"

window: Window
button1: widgets.Button
button2: widgets.Button
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

    widgets.init_button(&button1,
        position = {50, 50},
        event_proc = proc(widget: ^gui.Widget, event: any) {
            button := cast(^widgets.Button)widget
            switch e in event {
            case gui.Mouse_Move_Event:
                if button.is_down {
                    gui.set_position(button, button.position + e.delta)
                    gui.redraw()
                }
            case widgets.Button_Click_Event:
                fmt.println("Clicked 1")
            }
            widgets.button_event_proc(button, event)
        },
    )
    defer widgets.destroy_button(&button1)

    widgets.init_button(&button2,
        position = {50, 50},
        event_proc = proc(widget: ^gui.Widget, event: any) {
            button := cast(^widgets.Button)widget
            switch e in event {
            case gui.Mouse_Move_Event:
                if button.is_down {
                    gui.set_position(button, button.position + e.delta)
                    gui.redraw()
                }
            case widgets.Button_Click_Event:
                fmt.println("Clicked 2")
            }
            widgets.button_event_proc(button, event)
        },
    )
    defer widgets.destroy_button(&button2)

    widgets.init_slider(&slider,
        position = {50, 50},
    )
    defer widgets.destroy_slider(&slider)

    gui.add_children(&window.root, {&button1})
    gui.add_children(&button1, {&button2})
    gui.add_children(&button2, {&slider})

    gui.open(&window.root)
    for window_is_open(&window) {
        update()
    }
}