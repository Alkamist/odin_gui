package gui

layout_grid :: proc(
    widgets: []^Widget,
    layout: [2]int,
    size: Vec2,
    spacing := Vec2{0, 0},
    padding := Vec2{0, 0},
) {
    child_count := len(widgets)
    if child_count == 0 {
        return
    }

    layout_f32 := Vec2{f32(layout.x), f32(layout.y)}
    child_size := (size - spacing * (layout_f32 - 1) - padding * 2) / layout_f32

    i := 0
    position := padding

    for y in 0..<layout.y {
        position.x = padding.x
        for x in 0..<layout.x {
            if i >= child_count {
                return
            }
            child := widgets[i]
            set_position(child, position)
            set_size(child, child_size)
            position.x += child_size.x + spacing.x
            i += 1
        }
        position.y += child_size.y + spacing.y
    }
}