package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../gui"
import backend "../../gui/backend_pugl_nanovg"

import nvg "vendor:nanovg"

window1: backend.Window
window2: backend.Window

starting_velocity := gui.Vec2{1000, 0}
velocity := starting_velocity

position: gui.Vec2

update :: proc() {
    position.x += velocity.x * gui.delta_time()
    if position.x > 200 {
        velocity.x = -starting_velocity.x
    }
    if position.x < 0 {
        velocity.x = starting_velocity.x
    }

    if gui.window_update(&window1) {
        gui.draw_rect({{0, 0}, {100, 100}}, {0, 1, 0, 1})
        gui.draw_rect({gui.mouse_position(), {100, 100}}, {0, 1, 0, 1})
    }

    if gui.window_update(&window2) {
        gui.draw_rect({{0, 0}, {100, 100}}, {1, 0, 0, 1})
        gui.draw_rect({gui.mouse_position(), {100, 100}}, {1, 0, 0, 1})
        if gui.mouse_released(.Right) {
            window1.is_open = true
        }
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
            fmt.println(cast(^runtime.Default_Temp_Allocator)context.temp_allocator.data)
            fmt.println("Success")
            mem.tracking_allocator_destroy(&track)
        }
    }

    gui.init(update)
    defer gui.shutdown()

    backend.init()
    defer backend.shutdown()

    gui.window_init(&window1, {{50, 50}, {400, 300}})
    gui.window_init(&window2, {{500, 50}, {400, 300}})

    window1.is_open = false

    window1.background_color = {0.2, 0, 0, 1}
    window2.background_color = {0, 0.2, 0, 1}

    for window1.is_open || window2.is_open {
        gui.update()
    }
}



















// package main

// import "base:runtime"
// import "core:fmt"
// import "core:mem"
// import "gui"
// import "gui/widgets"

// // import backend "backend_pugl_nanovg"
// // import nvg "vendor:nanovg"

// import backend "backend_raylib"
// import rl "vendor:raylib"

// consola_13: backend.Font

// ctx: backend.Context

// button: widgets.Button
// slider: widgets.Slider
// text: widgets.Editable_Text_Line

// controlling_camera: bool
// camera_button: widgets.Button
// camera := rl.Camera3D{
//     position = {10, 10, 10},
//     target = {0, 0, 0},
//     up = {0, 1, 0},
//     fovy = 45,
//     projection = .PERSPECTIVE,
// }

// cube: rl.Vector3

// scene_texture: rl.RenderTexture2D

// VIEW_WIDTH :: 600
// VIEW_HEIGHT :: 500

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

//     backend.init(&ctx, {200, 100}, {1280, 800})
//     defer backend.destroy(&ctx)

//     ctx.update = update
//     ctx.background_color = {0.2, 0.2, 0.2, 1}

//     widgets.init(&button)
//     button.position = {20, 20}
//     button.size = {VIEW_WIDTH, 32}

//     widgets.init(&slider)
//     slider.position = {0, button.size.y + 10}
//     slider.size = {VIEW_WIDTH, 24}
//     slider.value = 0.5

//     widgets.init(&camera_button)
//     camera_button.position = {0, slider.position.y + slider.size.y + 10}
//     camera_button.size = {VIEW_WIDTH, VIEW_HEIGHT}

//     widgets.init(&text)
//     defer widgets.destroy(&text)
//     text.font = &consola_13
//     widgets.input_string(&text, "Hello world. Type here: ")

//     backend.open(&ctx)
//     for backend.is_open(&ctx) {
//         backend.update()
//     }

//     backend.font_destroy(&consola_13)
// }

// update :: proc(ctx: ^gui.Context) {
//     if gui.opened() {
//         backend.load_font_from_data(&consola_13, #load("consola.ttf"), 13)
//         scene_texture = rl.LoadRenderTexture(VIEW_WIDTH, VIEW_HEIGHT)
//         rl.SetExitKey(.KEY_NULL)
//     }

//     if button.is_down && gui.mouse_moved() {
//         button.position += gui.mouse_delta()
//     }
//     widgets.update(&button)
//     widgets.draw(&button)

//     gui.scoped_offset(button.position)

//     widgets.update(&slider)
//     widgets.draw(&slider)

//     widgets.update(&camera_button)

//     cube.y = (slider.value - 0.5) * 10

//     if !controlling_camera && camera_button.pressed {
//         controlling_camera = true
//         rl.DisableCursor()
//     }

//     if controlling_camera && gui.key_pressed(.Escape) {
//         controlling_camera = false
//         rl.EnableCursor()
//     }

//     if controlling_camera {
//         rl.UpdateCamera(&camera, .FREE)
//     }

//     gui.draw_custom(proc() {
//         rl.BeginTextureMode(scene_texture)

//         rl.ClearBackground({0, 0, 0, 255})
//         rl.BeginMode3D(camera)
//         rl.DrawCube(cube, 2, 2, 2, rl.RED)
//         rl.DrawCubeWires(cube, 2, 2, 2, rl.MAROON)
//         rl.DrawGrid(10, 1)
//         rl.EndMode3D()

//         rl.EndTextureMode()

//         rl.DrawTextureRec(
//             scene_texture.texture,
//             {0, 0, f32(scene_texture.texture.width), -f32(scene_texture.texture.height)},
//             gui.offset() + {0, slider.position.y + slider.size.y + 10},
//             rl.WHITE,
//         )
//     })

//     {
//         text_box := gui.Rect{
//             {0, camera_button.y + camera_button.size.y + 10},
//             {VIEW_WIDTH, 100},
//         }

//         gui.scoped_clip(text_box)
//         gui.draw_rect(text_box, {0.2, 0, 0, 1})

//         alignment := gui.Vec2{slider.value, slider.value}
//         text.position = text_box.position + (text_box.size - text.size - {widgets.CARET_WIDTH, 0}) * alignment

//         widgets.update(&text)
//         widgets.draw(&text)
//     }
// }