package main

import "core:fmt"
import "core:mem"
import "../../gui"
import "../widgets"

main_window: ^gui.Window
test_button: ^widgets.Button
test_button2: ^widgets.Button

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

    main_window = gui.create_window(position = {50, 50})
    defer gui.destroy_window(main_window)

    test_button = widgets.create_button({50, 50}, {100, 100}, gui.rgb(255, 0, 0))
    defer widgets.destroy_button(test_button)

    test_button.event_proc = proc(widget: ^gui.Widget, event: any) -> bool {
        button := cast(^widgets.Button)widget
        switch e in event {
        case widgets.Button_Clicked_Event:
            fmt.println("Clicked 1")
        case gui.Mouse_Moved_Event:
            if button.is_down {
                button.position += e.delta
                gui.redraw()
            }
        }
        return widgets.button_event_proc(widget, event)
    }

    test_button2 = widgets.create_button({50, 50}, {100, 100}, gui.rgb(0, 255, 0))
    defer widgets.destroy_button(test_button2)

    test_button2.event_proc = proc(widget: ^gui.Widget, event: any) -> bool {
        button := cast(^widgets.Button)widget
        switch e in event {
        case widgets.Button_Clicked_Event:
            fmt.println("Clicked 2")
        case gui.Mouse_Moved_Event:
            if button.is_down {
                button.position += e.delta
                gui.redraw()
            }
        }
        return widgets.button_event_proc(widget, event)
    }

    gui.add_children(test_button, {test_button2})
    gui.add_children(main_window.root, {test_button})

    gui.open_window(main_window)
    for gui.window_is_open(main_window) {
        gui.update()
    }
}