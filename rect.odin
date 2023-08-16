package gui

Rect :: struct {
    position: Vec2,
    size: Vec2,
}

expand :: proc(rect: Rect, amount: Vec2) -> Rect {
    return {
        position = {
            min(rect.position.x + rect.size.x * 0.5, rect.position.x - amount.x),
            min(rect.position.y + rect.size.y * 0.5, rect.position.y - amount.y),
        },
        size = {
            max(0, rect.size.x + amount.x * 2),
            max(0, rect.size.y + amount.y * 2),
        },
    }
}

intersect :: proc(a, b: Rect) -> Rect {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)

    x1 := max(a.position.x, b.position.x)
    y1 := max(a.position.y, b.position.y)
    x2 := min(a.position.x + a.size.x, b.position.x + b.size.x)
    y2 := min(a.position.y + a.size.y, b.position.y + b.size.y)

    if x2 < x1 {
        x2 = x1
    }
    if y2 < y1 {
        y2 = y1
    }

    return {{x1, y1}, {x2 - x1, y2 - y1}}
}

intersects :: proc(a, b: Rect, include_borders := false) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)

    if include_borders {
        if a.position.x > b.position.x + b.size.x {
            return false
        }
        if a.position.x + a.size.x < b.position.x {
            return false
        }
        if a.position.y > b.position.y + b.size.y {
            return false
        }
        if a.position.y + a.size.y < b.position.y {
            return false
        }
    } else {
        if a.position.x >= b.position.x + b.size.x {
            return false
        }
        if a.position.x + a.size.x <= b.position.x {
            return false
        }
        if a.position.y >= b.position.y + b.size.y {
            return false
        }
        if a.position.y + a.size.y <= b.position.y {
            return false
        }
    }

    return true
}

contains :: proc{
    contains_rect,
    contains_vec2,
}

contains_rect :: proc(a, b: Rect) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)

    return b.position.x >= a.position.x &&
           b.position.y >= a.position.y &&
           b.position.x + b.size.x <= a.position.x + a.size.x &&
           b.position.y + b.size.y <= a.position.y + a.size.y
}

contains_vec2 :: proc(a: Rect, b: Vec2) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0)
    return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
           b.y >= a.position.y && b.y <= a.position.y + a.size.y
}

_rect_intersect :: intersect