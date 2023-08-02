package gui

Id :: u64

Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_hover_request: Id,
}

Region :: struct {
    position: Vec2,
    size: Vec2,
}

Interaction_Tracker :: struct {
    detected_hover: bool,
    detected_mouse_over: bool,
}



// expand_region :: proc(region: Region, amount: Vec2) -> Region {
//     return {
//         position = {
//             min(region.position.x + region.size.x * 0.5, region.position.x - amount.x),
//             min(region.position.y + region.size.y * 0.5, region.position.y - amount.y),
//         },
//         size = {
//             max(0, region.size.x + amount.x * 2),
//             max(0, region.size.y + amount.y * 2),
//         },
//     }
// }

// intersect_region :: proc(a, b: Region) -> Region {
//     x1 := max(a.position.x, b.position.x)
//     y1 := max(a.position.y, b.position.y)
//     x2 := min(a.position.x + a.size.x, b.position.x + b.size.x)
//     y2 := min(a.position.y + a.size.y, b.position.y + b.size.y)
//     if x2 < x1 { x2 = x1 }
//     if y2 < y1 { y2 = y1 }
//     return { {x1, y1}, {x2 - x1, y2 - y1} }
// }

// region_contains_position :: proc(a: Region, b: Vec2) -> bool {
//     return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
//            b.y >= a.position.y && b.y <= a.position.y + a.size.y
// }



current_z_index :: proc() -> int {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")
    return w.current_layer.z_index
}

begin_z_index :: proc(z_index: int, global := false) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")

    if global {
        append(&w.layer_stack, Layer{z_index = z_index})
    } else {
        append(&w.layer_stack, Layer{z_index = w.layer_stack[len(w.layer_stack) - 1].z_index + z_index})
    }

    w.current_layer = &w.layer_stack[len(w.layer_stack) - 1]
}

end_z_index :: proc() {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")

    append(&w.layers, pop(&w.layer_stack))

    if len(w.layer_stack) > 0 {
        w.current_layer = &w.layer_stack[len(w.layer_stack) - 1]
    } else {
        w.current_layer = nil
    }
}



current_offset :: proc() -> Vec2 {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")

    return w.current_offset
}

begin_offset :: proc(offset: Vec2, global := false) {
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")

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
    w := ctx.current_window
    assert(w != nil, "No window currently exists.")

    pop(&w.offset_stack)
    if len(w.offset_stack) > 0 {
        w.current_offset = w.offset_stack[len(w.offset_stack) - 1]
    } else {
        w.current_offset = {0, 0}
    }
}