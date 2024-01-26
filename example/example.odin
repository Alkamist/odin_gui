package main

import "core:fmt"
import "core:mem"
import "../../gui"
import "../widgets"

main_window: gui.Window
test_button: widgets.Button
test_button2: widgets.Button
test_slider: widgets.Slider

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

    gui.init_window(&main_window,
        position = {50, 50},
        background_color = gui.rgb(71, 75, 82),
    )
    defer gui.destroy_window(&main_window)

    widgets.init_button(&test_button,
        position = {50, 50},
        size = {120, 32},
        color = gui.rgb(70, 74, 81),
        event_proc = proc(widget: ^gui.Widget, event: any) -> bool {
            button := cast(^widgets.Button)widget
            switch e in event {
            case widgets.Button_Click_Event:
                fmt.println("Clicked 1")
            case gui.Mouse_Move_Event:
                if button.is_down {
                    button.position += e.delta
                    gui.redraw()
                }
            }
            return widgets.button_event_proc(widget, event)
        },
    )
    defer widgets.destroy_button(&test_button)

    widgets.init_button(&test_button2,
        position = {50, 50},
        size = {120, 32},
        color = gui.rgb(70, 74, 81),
        event_proc = proc(widget: ^gui.Widget, event: any) -> bool {
            button := cast(^widgets.Button)widget
            switch e in event {
            case widgets.Button_Click_Event:
                fmt.println("Clicked 2")
            case gui.Mouse_Move_Event:
                if button.is_down {
                    button.position += e.delta
                    gui.redraw()
                }
            }
            return widgets.button_event_proc(widget, event)
        },
    )
    defer widgets.destroy_button(&test_button2)

    widgets.init_slider(&test_slider,
        position = {10, 200},
        event_proc = proc(widget: ^gui.Widget, event: any) -> bool {
            slider := cast(^widgets.Slider)widget
            switch e in event {
            case widgets.Slider_Value_Change_Event:
                gui.set_position(&test_button2, test_button2.position + {e.delta * 200.0, 0})
            }
            return widgets.slider_event_proc(widget, event)
        },
    )
    defer widgets.destroy_slider(&test_slider)

    gui.add_children(&test_button, {&test_button2})
    gui.add_children(&main_window.root, {&test_button, &test_slider})

    gui.open_window(&main_window)
    for gui.window_is_open(&main_window) {
        gui.update()
    }
}