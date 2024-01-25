package gui

Rect :: struct {
    position: Vec2,
    size: Vec2,
}

trim_left :: proc(rect: ^Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, min_amount, rect.size.x), min_amount)
    rect.position.x += amount
    rect.size.x -= amount
    return {
        {rect.position.x - amount, rect.position.y},
        {amount, rect.size.y},
    }
}

peek_trim_left :: proc(rect: Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, min_amount, rect.size.x), min_amount)
    return {
        {rect.position.x, rect.position.y},
        {amount, rect.size.y},
    }
}

trim_right :: proc(rect: ^Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, 0, rect.size.x), min_amount)
    rect.size.x -= amount
    return {
        {rect.position.x + rect.size.x, rect.position.y},
        {amount, rect.size.y},
    }
}

peek_trim_right :: proc(rect: Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, 0, rect.size.x), min_amount)
    return {
        {rect.position.x + rect.size.x - amount, rect.position.y},
        {amount, rect.size.y},
    }
}

trim_top :: proc(rect: ^Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, 0, rect.size.x), min_amount)
    rect.position.y += amount
    rect.size.y -= amount
    return {
        {rect.position.x, rect.position.y - amount},
        {rect.size.x, amount},
    }
}

peek_trim_top :: proc(rect: ^Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, 0, rect.size.x), min_amount)
    return {
        {rect.position.x, rect.position.y},
        {rect.size.x, amount},
    }
}

trim_bottom :: proc(rect: ^Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, 0, rect.size.x), min_amount)
    rect.size.y -= amount
    return {
        {rect.position.x, rect.position.y + rect.size.y},
        {rect.size.x, amount},
    }
}

peek_trim_bottom :: proc(rect: ^Rect, amount: f32, min_amount: f32 = 0) -> Rect {
    amount := max(clamp(amount, 0, rect.size.x), min_amount)
    return {
        {rect.position.x, rect.position.y + rect.size.y - amount},
        {rect.size.x, amount},
    }
}

expanded :: proc(rect: Rect, amount: Vec2) -> Rect {
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

expand :: proc(rect: ^Rect, amount: Vec2) {
    rect^ = expanded(rect^, amount)
}

padded :: proc(rect: Rect, amount: Vec2) -> Rect {
    return expanded(rect, -amount)
}

pad :: proc(rect: ^Rect, amount: Vec2) {
    rect^ = padded(rect^, amount)
}

intersection :: proc(a, b: Rect) -> Rect {
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

rect_contains_rect :: proc(a, b: Rect) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)
    return b.position.x >= a.position.x &&
           b.position.y >= a.position.y &&
           b.position.x + b.size.x <= a.position.x + a.size.x &&
           b.position.y + b.size.y <= a.position.y + a.size.y
}

rect_contains_vec2 :: proc(a: Rect, b: Vec2) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0)
    return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
           b.y >= a.position.y && b.y <= a.position.y + a.size.y
}