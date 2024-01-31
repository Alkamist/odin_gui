package gui

Axis_Kind :: enum {
    Horizontal,
    Vertical,
}

layout_free_axis :: proc(
    widgets: []^Widget,
    axis: Axis_Kind,
    spacing := f32(0),
    offset := f32(0),
) -> (size: f32) {
    if len(widgets) == 0 {
        return 0
    }

    axis_int := int(axis)
    other_axis_int := 1 - axis_int

    p := offset

    for widget in widgets {
        position := widget.position
        position[axis_int] = p

        set_position(widget, position)

        p += widget.size[axis_int] + spacing
    }

    return p - offset - spacing
}

layout_grid_axis :: proc(
    widgets: []^Widget,
    axis: Axis_Kind,
    size: f32,
    spacing := f32(0),
    padding := f32(0),
    offset := f32(0),
) {
    widget_count := len(widgets)
    if widget_count == 0 {
        return
    }

    axis_int := int(axis)
    other_axis_int := 1 - axis_int

    widget_count_f32 := f32(widget_count)
    widget_size := (size - spacing * (widget_count_f32 - 1) - padding * 2) / widget_count_f32

    p := offset + padding

    for widget in widgets {
        position := widget.position
        position[axis_int] = p

        size := widget.size
        size[axis_int] = widget_size

        set_position(widget, position)
        set_size(widget, size)

        p += widget_size + spacing
    }
}

layout_flex_axis :: proc(
    widgets: []^Widget,
    axis: Axis_Kind,
    size: f32,
    alignment := f32(0),
    spread := f32(0),
    padding := f32(0),
    offset := f32(0),
) {
    widget_count := len(widgets)
    if widget_count == 0 {
        return
    }

    axis_int := int(axis)
    other_axis_int := 1 - axis_int

    size := size - padding * 2
    spacing_count_f32 := f32(widget_count - 1)

    total_size := f32(0)
    for widget in widgets {
        total_size += widget.size[axis_int]
    }
    spacing := spread * (size - total_size) / spacing_count_f32
    total_size += spacing * spacing_count_f32

    p := offset + padding + alignment * (size - total_size)

    for widget in widgets {
        position := widget.position
        position[axis_int] = p

        set_position(widget, position)

        p += widget.size[axis_int] + spacing
    }
}

layout_grid :: proc(
    widgets: []^Widget,
    shape: [2]int,
    size: Vec2,
    spacing := Vec2{0, 0},
    padding := Vec2{0, 0},
    offset := Vec2{0, 0},
) {
    child_count := len(widgets)
    if child_count == 0 {
        return
    }

    shape_f32 := Vec2{f32(shape.x), f32(shape.y)}
    child_size := (size - spacing * (shape_f32 - 1) - padding * 2) / shape_f32

    i := 0
    position := offset + padding

    for y in 0..<shape.y {
        position.x = offset.x + padding.x

        for x in 0..<shape.x {
            if i >= child_count {
                return
            }

            set_position(widgets[i], position)
            set_size(widgets[i], child_size)

            position.x += child_size.x + spacing.x
            i += 1
        }

        position.y += child_size.y + spacing.y
    }
}