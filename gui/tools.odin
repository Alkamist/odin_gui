package gui

Id :: u64

Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_hover_request: Id,
}



is_hovered :: proc(id: Id) -> bool {
    w := current_window()
    return w.hover == id
}

mouse_is_over :: proc(id: Id) -> bool {
    w := current_window()
    return w.mouse_over == id
}

request_hover :: proc(id: Id) {
    w := current_window()
    w.current_layer.final_hover_request = id

    // if ctx.hover == id {
    //     w.interaction_tracker_stack[len(w.interaction_tracker_stack) - 1].detected_hover = true
    // }

    // if ctx.mouse_over == id {
    //     w.interaction_tracker_stack[len(w.interaction_tracker_stack) - 1].detected_mouse_over = true
    // }
}

capture_hover :: proc(id: Id) {
    w := current_window()
    if w.hover_capture == 0 {
        w.hover_capture = id
    }
}

release_hover :: proc(id: Id) {
    w := current_window()
    if w.hover_capture == id {
        w.hover_capture = 0
    }
}

mouse_hit_test :: proc(position, size: Vec2) -> bool {
    m := mouse_position()
    return window_is_hovered() &&
           m.x >= position.x && m.x <= position.x + size.x &&
           m.y >= position.y && m.y <= position.y + size.y &&
           region_contains_position(current_clip_region(), m)
}



current_z_index :: proc() -> int {
    w := current_window()
    return w.current_layer.z_index
}

begin_z_index :: proc(z_index: int, global := false) {
    w := current_window()

    if global {
        append(&w.layer_stack, Layer{z_index = z_index})
    } else {
        append(&w.layer_stack, Layer{z_index = w.layer_stack[len(w.layer_stack) - 1].z_index + z_index})
    }

    w.current_layer = &w.layer_stack[len(w.layer_stack) - 1]
}

end_z_index :: proc() {
    w := current_window()

    append(&w.layers, pop(&w.layer_stack))

    if len(w.layer_stack) > 0 {
        w.current_layer = &w.layer_stack[len(w.layer_stack) - 1]
    } else {
        w.current_layer = nil
    }
}

@(deferred_none=end_z_index)
z_index :: proc(z_index: int, global := false) {
    begin_z_index(z_index, global)
}



current_offset :: proc() -> Vec2 {
    w := current_window()
    return w.current_offset
}

begin_offset :: proc(offset: Vec2, global := false) {
    w := current_window()

    if global {
        w.current_offset = offset
        append(&w.offset_stack, offset)
    } else {
        w := ctx.current_window
        offset := w.current_offset + offset
        w.current_offset = offset
        append(&w.offset_stack, offset)
    }
}

end_offset :: proc() {
    w := current_window()

    pop(&w.offset_stack)
    if len(w.offset_stack) > 0 {
        w.current_offset = w.offset_stack[len(w.offset_stack) - 1]
    } else {
        w.current_offset = {0, 0}
    }
}

@(deferred_none=end_offset)
offset :: proc(offset: Vec2, global := false) {
    begin_offset(offset, global)
}



Region :: struct {
    position: Vec2,
    size: Vec2,
}

expand_region :: proc(region: Region, amount: Vec2) -> Region {
    return {
        position = {
            min(region.position.x + region.size.x * 0.5, region.position.x - amount.x),
            min(region.position.y + region.size.y * 0.5, region.position.y - amount.y),
        },
        size = {
            max(0, region.size.x + amount.x * 2),
            max(0, region.size.y + amount.y * 2),
        },
    }
}

intersect_region :: proc(a, b: Region) -> Region {
    x1 := max(a.position.x, b.position.x)
    y1 := max(a.position.y, b.position.y)
    x2 := min(a.position.x + a.size.x, b.position.x + b.size.x)
    y2 := min(a.position.y + a.size.y, b.position.y + b.size.y)
    if x2 < x1 { x2 = x1 }
    if y2 < y1 { y2 = y1 }
    return { {x1, y1}, {x2 - x1, y2 - y1} }
}

region_contains_position :: proc(a: Region, b: Vec2) -> bool {
    return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
           b.y >= a.position.y && b.y <= a.position.y + a.size.y
}

current_clip_region :: proc(global := false) -> Region {
    w := current_window()

    region := w.clip_region_stack[len(w.clip_region_stack) - 1]
    if !global {
        region.position -= w.current_offset
    }
    return region
}

begin_clip_region :: proc(region: Region, global := false, intersect := true) {
    w := current_window()
    region := region

    // Make it global
    if !global {
        region.position += w.current_offset
    }

    // Intersect with global
    if intersect {
        region = intersect_region(region, current_clip_region(global = true))
    }

    append(&w.clip_region_stack, region)
    append(&w.current_layer.draw_commands, Clip_Command{
        region.position,
        region.size,
    })
}

begin_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    begin_clip_region(Region{position, size}, global, intersect)
}

end_clip :: proc() {
    w := current_window()
    pop(&w.clip_region_stack)

    if len(w.clip_region_stack) == 0 {
        return
    }

    region := current_clip_region()
    append(&w.current_layer.draw_commands, Clip_Command{
        region.position,
        region.size,
    })
}

@(deferred_none=end_clip)
clip :: proc(position, size: Vec2, global := false, intersect := true) {
    begin_clip(position, size, global, intersect)
}



// Interaction_Tracker :: struct {
//     detected_hover: bool,
//     detected_mouse_over: bool,
// }

// begin_interaction_tracker :: proc() {
//     w := current_window()
//     append(&w.interaction_tracker_stack, Interaction_Tracker{})
// }

// end_interaction_tracker :: proc() {
//     w := current_window()
//     tracker := pop(&w.interaction_tracker_stack)

//     if tracker.detected_hover {
//         w.interaction_tracker_stack[len(w.interaction_tracker_stack) - 1].detected_hover = true
//     }

//     if tracker.detected_mouse_over {
//         w.interaction_tracker_stack[len(w.interaction_tracker_stack) - 1].detected_mouse_over = true
//     }
// }

// @(deferred_none=end_interaction_tracker)
// interaction_tracker :: proc() {
//     begin_interaction_tracker()
// }