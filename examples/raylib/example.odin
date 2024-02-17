package example_raylib

import "base:runtime"
import "core:fmt"
import "core:mem"
import "../../../gui"
import "../../../gui/widgets"

import backend "../../backends/raylib"
import rl "vendor:raylib"

running := true

ctx: backend.Context

window: backend.Window

consola_13 := backend.Font{
    size = 13,
    data = #load("consola.ttf"),
}

button: widgets.Button
slider: widgets.Slider
text: widgets.Editable_Text_Line

move_button: widgets.Button

controlling_camera: bool
camera_button: widgets.Button
camera := rl.Camera3D{
    position = {10, 10, 10},
    target = {0, 0, 0},
    up = {0, 1, 0},
    fovy = 45,
    projection = .PERSPECTIVE,
}

cube: rl.Vector3

scene_texture: rl.RenderTexture2D

VIEW_WIDTH :: 600
VIEW_HEIGHT :: 500

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

    backend.context_init(&ctx)
    defer backend.context_destroy(&ctx)
    ctx.update = update

    backend.window_init(&window, {{300, 100}, {1280, 800}})
    defer backend.window_destroy(&window)
    window.background_color = {0.2, 0.2, 0.2, 1}

    widgets.init(&button)
    button.position = {20, 20}
    button.size = {VIEW_WIDTH, 32}

    widgets.init(&slider)
    slider.position = {0, button.size.y + 10}
    slider.size = {VIEW_WIDTH, 24}
    slider.value = 0.5

    widgets.init(&camera_button)
    camera_button.position = {0, slider.position.y + slider.size.y + 10}
    camera_button.size = {VIEW_WIDTH, VIEW_HEIGHT}

    widgets.init(&text)
    defer widgets.destroy(&text)
    text.font = &consola_13
    widgets.input_string(&text, "Hello world. Type here: ")

    widgets.init(&move_button)
    move_button.position = {700, 100}

    for running {
        backend.context_update(&ctx)
    }
}

update :: proc() {
    if gui.window_update(&window) {
        if gui.window_opened(&window) {
            scene_texture = rl.LoadRenderTexture(VIEW_WIDTH, VIEW_HEIGHT)
            rl.SetExitKey(.KEY_NULL)
        }

        widgets.update(&move_button)
        widgets.draw(&move_button)

        if move_button.is_down {
            window.position += gui.mouse_delta()
        }

        if button.is_down && gui.mouse_moved() {
            button.position += gui.mouse_delta()
        }
        widgets.update(&button)
        widgets.draw(&button)

        gui.scoped_offset(button.position)

        widgets.update(&slider)
        widgets.draw(&slider)

        widgets.update(&camera_button)

        cube.y = (slider.value - 0.5) * 10

        if !controlling_camera && camera_button.pressed {
            controlling_camera = true
            rl.DisableCursor()
        }

        if controlling_camera && gui.key_pressed(.Escape) {
            controlling_camera = false
            rl.EnableCursor()
        }

        if controlling_camera {
            rl.UpdateCamera(&camera, .FREE)
        }

        gui.draw_custom(proc() {
            rl.BeginTextureMode(scene_texture)

            rl.ClearBackground({0, 0, 0, 255})
            rl.BeginMode3D(camera)
            rl.DrawCube(cube, 2, 2, 2, rl.RED)
            rl.DrawCubeWires(cube, 2, 2, 2, rl.MAROON)
            rl.DrawGrid(10, 1)
            rl.EndMode3D()

            rl.EndTextureMode()

            rl.DrawTextureRec(
                scene_texture.texture,
                {0, 0, f32(scene_texture.texture.width), -f32(scene_texture.texture.height)},
                gui.offset() + {0, slider.position.y + slider.size.y + 10},
                rl.WHITE,
            )
        })

        {
            text_box := gui.Rect{
                {0, camera_button.y + camera_button.size.y + 10},
                {VIEW_WIDTH, 100},
            }

            gui.scoped_clip(text_box)
            gui.draw_rect(text_box, {0.2, 0, 0, 1})

            alignment := gui.Vec2{slider.value, slider.value}
            text.position = text_box.position + (text_box.size - text.size - {widgets.CARET_WIDTH, 0}) * alignment

            widgets.update(&text)
            widgets.draw(&text)
        }
    }

    if !window.is_open {
        running = false
    }
}