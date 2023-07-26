package main

import "core:fmt"
import "core:time"
import "core:runtime"
import "gui"
import "gui/color"
import "gui/widgets"
import nvg "vendor:nanovg"

button := widgets.init_button()
button2 := widgets.init_button(position = {100, 100})

on_frame :: proc(ctx: ^gui.Context) {
    gui.begin_frame(ctx)

    widgets.update_button(ctx, &button)
    widgets.draw_button(ctx, &button)

    gui.end_frame(ctx)
}

on_frame2 :: proc(ctx: ^gui.Context) {
    gui.begin_frame(ctx)

    widgets.update_button(ctx, &button2)
    widgets.draw_button(ctx, &button2)

    gui.end_frame(ctx)
}

main :: proc() {
    gui.startup()
    defer gui.shutdown()

    ctx := gui.create_context("Hello")
    defer gui.destroy_context(ctx)

    gui.set_background_color(ctx, color.rgb(49, 51, 56))
    gui.set_frame_proc(ctx, on_frame)
    gui.show(ctx)

    ctx2 := gui.create_context("Hello 2")
    defer gui.destroy_context(ctx2)

    gui.set_background_color(ctx2, color.rgb(150, 51, 56))
    gui.set_frame_proc(ctx2, on_frame2)
    gui.show(ctx2)

    for gui.window_is_open(ctx) {
        gui.update()
    }
}