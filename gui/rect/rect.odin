package rect

Vec2 :: [2]f32

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

contains :: proc(a: Rect, b: Vec2) -> bool {
    return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
           b.y >= a.position.y && b.y <= a.position.y + a.size.y
}