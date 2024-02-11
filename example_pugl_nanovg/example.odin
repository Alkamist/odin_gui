package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../gui"
import "../../gui/widgets"
import backend "../../gui/backend_pugl_nanovg"

consola_13: backend.Font

ctx1: Context
ctx2: Context

Context :: struct {
    using backend_ctx: backend.Context,
    button: widgets.Button,
    slider: widgets.Slider,
    text: widgets.Editable_Text_Line,
}

init :: proc(
    ctx: ^Context,
    position: gui.Vec2,
    size: gui.Vec2,
    temp_allocator := context.temp_allocator,
) -> runtime.Allocator_Error {
    backend.init(ctx, position, size, temp_allocator) or_return
    ctx.update = update

    widgets.init(&ctx.button)
    ctx.button.position = {20, 20}

    widgets.init(&ctx.slider)
    ctx.slider.position = {0, ctx.button.size.y + 10}
    ctx.slider.value = 0.5

    widgets.init(&ctx.text)
    ctx.text.position = {100, 100}
    ctx.text.font = &consola_13
    widgets.input_string(&ctx.text, "Hello world. Type here: ")

    return nil
}

destroy :: proc(ctx: ^Context) {
    widgets.destroy(&ctx.text)
    backend.destroy(ctx)
}

update :: proc(ctx: ^gui.Context) {
    ctx := cast(^Context)ctx

    if gui.opened() {
        backend.load_font_from_data(&consola_13, #load("consola.ttf"), 13)
    }

    if gui.key_pressed(.Pad_7) {
        ctx.is_open = false
    }

    if ctx.button.is_down && gui.mouse_moved() {
        ctx.button.position += gui.mouse_delta()
    }
    widgets.update(&ctx.button)
    widgets.draw(&ctx.button)

    gui.scoped_offset(ctx.button.position)

    widgets.update(&ctx.slider)
    widgets.draw(&ctx.slider)

    {
        gui.scoped_clip({ctx.text.position, {200, 200}})
        gui.draw_rect({ctx.text.position, {200, 200}}, {0.4, 0, 0, 1})
        widgets.update(&ctx.text)
        widgets.draw(&ctx.text)
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

    init(&ctx1, {200, 100}, {400, 300})
    defer destroy(&ctx1)
    ctx1.background_color = {0.2, 0, 0, 1}

    init(&ctx2, {700, 100}, {400, 300})
    defer destroy(&ctx2)
    ctx2.background_color = {0, 0.2, 0, 1}

    backend.open(&ctx1)
    backend.open(&ctx2)

    for ctx1.is_open || ctx2.is_open {
        backend.update()
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