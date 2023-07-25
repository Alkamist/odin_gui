package gui

import "core:fmt"
import "core:strings"
import "core:slice"
import gl "vendor:OpenGL"
import "pugl"

world: ^pugl.World

init :: proc(kind: Program_Kind) {
    world_type: pugl.WorldType = ---
    switch kind {
    case .Parent: world_type = .PROGRAM
    case .Child: world_type = .MODULE
    }
    world = pugl.NewWorld(world_type, {})
    pugl.SetWorldString(world, .CLASS_NAME, "GuiClass")
}

deinit :: proc() {
    pugl.FreeWorld(world)
}

poll :: proc() {
    pugl.Update(world, 0.0)
}

begin_frame :: proc(window: ^Window) {
    frame := pugl.GetFrame(window.view)
    gl.Viewport(0, 0, i32(frame.width), i32(frame.height))
    _vg_begin_frame(
        window.vg_ctx,
        {f32(frame.width), f32(frame.height)},
        f32(pugl.GetScaleFactor(window.view)),
    )

    begin_z_index(window, 0, global = true)
    begin_offset(window, 0, global = true)
    begin_clip_region(window, {{0, 0}, {f32(frame.width), f32(frame.height)}}, global = true, intersect = false)
}

end_frame :: proc(window: ^Window) {
    end_clip_region(window)
    end_offset(window)
    end_z_index(window)

    assert(len(window.offset_stack) == 0, "Mismatch in begin_offset and end_offset calls.")
    assert(len(window.clip_region_stack) == 0, "Mismatch in begin_clip_region and end_clip_region calls.")
    assert(len(window.layer_stack) == 0, "Mismatch in begin_z_index and end_z_index calls.")

    // The layers are in reverse order because they were added in end_z_index.
    // Sort preserves the order of layers with the same z index, so they
    // must first be reversed and then sorted to keep that ordering in tact.
    slice.reverse(window.layers[:])
    slice.stable_sort_by(window.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    highest_z_index := min(int)

    for layer in window.layers {
        if layer.z_index > highest_z_index {
            highest_z_index = layer.z_index
        }
        render_draw_commands(window, layer.draw_commands[:])
        delete(layer.draw_commands)
    }

    window.highest_z_index = highest_z_index

    clear(&window.layers)
    clear(&window.mouse_presses)
    clear(&window.mouse_releases)
    clear(&window.key_presses)
    clear(&window.key_releases)
    strings.builder_reset(&window.text_input)
    window.mouse_wheel_state = {0, 0}
    window.previous_global_mouse_position = window.global_mouse_position
    window.previous_tick = window.tick

    _vg_end_frame(window.vg_ctx)
}

current_offset :: proc(window: ^Window) -> Vec2 {
    return window.offset_stack[len(window.offset_stack) - 1]
}

begin_offset :: proc(window: ^Window, offset: Vec2, global := false) {
    if global {
        append(&window.offset_stack, offset)
    } else {
        append(&window.offset_stack, current_offset(window) + offset)
    }
}

end_offset :: proc(window: ^Window) -> Vec2 {
    return pop(&window.offset_stack)
}

current_clip_region :: proc(window: ^Window, global := false) -> Region {
    region := window.clip_region_stack[len(window.clip_region_stack) - 1]
    if !global {
        region.position -= current_offset(window)
    }
    return region
}

begin_clip_region :: proc(window: ^Window, region: Region, global := false, intersect := true) {
    region := region

    // Make it global
    if !global {
        region.position += current_offset(window)
    }

    // Intersect with global
    if intersect {
        region = intersect_region(region, current_clip_region(window, global = true))
    }

    append(&window.clip_region_stack, region)

    append(&_current_layer(window).draw_commands, Clip_Command{
        region.position,
        region.size,
    })
}

end_clip_region :: proc(window: ^Window) -> Region {
    result := pop(&window.clip_region_stack)

    if len(window.clip_region_stack) == 0 {
        return result
    }

    region := current_clip_region(window)
    append(&_current_layer(window).draw_commands, Clip_Command{
        region.position,
        region.size,
    })

    return result
}

current_z_index :: proc(window: ^Window) -> int {
    return _current_layer(window).z_index
}

begin_z_index :: proc(window: ^Window, z_index: int, global := false) {
    if global {
        append(&window.layer_stack, Layer{z_index = z_index})
    } else {
        append(&window.layer_stack, Layer{z_index = current_z_index(window) + z_index})
    }
}

end_z_index :: proc(window: ^Window) -> int {
    layer := pop(&window.layer_stack)
    append(&window.layers, layer)
    return layer.z_index
}