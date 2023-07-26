package main

import "core:fmt"
import "core:time"
import "core:runtime"
import "gui"
import nvg "vendor:nanovg"

on_frame :: proc(ctx: ^gui.Context) {
    gui.begin_frame(ctx)

    gui.begin_clip_region(ctx, {{100, 100}, {100, 100}})

    gui.begin_offset(ctx, {300, 300})

    gui.begin_path(ctx)
    gui.rounded_rect(ctx, {50, 50}, {200, 200}, 50)
    gui.fill_path(ctx, {1, 0, 0, 1})

    gui.end_offset(ctx)

    gui.begin_path(ctx)
    gui.rounded_rect(ctx, {75, 75}, {200, 200}, 50)
    gui.fill_path(ctx, {0, 1, 0, 1})

    gui.end_clip_region(ctx)

    gui.end_frame(ctx)
}

main :: proc() {
    gui.startup()
    defer gui.shutdown()

    ctx := gui.create_context("Hello")
    defer gui.destroy_context(ctx)

    gui.set_background_color(ctx, {0.05, 0.05, 0.05, 1})

    gui.set_frame_proc(ctx, on_frame)
    gui.show(ctx)

    for !gui.should_close(ctx) {
        gui.update()
    }
}