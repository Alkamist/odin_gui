package main

import "core:fmt"
import "core:time"
import "core:runtime"
import "gui"
import nvg "vendor:nanovg"

on_frame :: proc(window: ^gui.Window) {
    gui.begin_frame(window)

    gui.begin_clip_region(window, {{100, 100}, {100, 100}})

    gui.begin_offset(window, {300, 300})

    gui.begin_path(window)
    gui.rounded_rect(window, {50, 50}, {200, 200}, 50)
    gui.fill_path(window, {1, 0, 0, 1})

    gui.end_offset(window)

    gui.begin_path(window)
    gui.rounded_rect(window, {75, 75}, {200, 200}, 50)
    gui.fill_path(window, {0, 1, 0, 1})

    gui.end_clip_region(window)

    gui.end_frame(window)
}

main :: proc() {
    gui.init(.Parent)
    defer gui.deinit()

    window, err := gui.create_window("Hello")
    if err != .None {
        return
    }
    defer gui.free_window(window)

    gui.set_window_on_frame_proc(window, on_frame)
    gui.show_window(window)

    for !gui.window_should_close(window) {
        gui.poll()
    }
}