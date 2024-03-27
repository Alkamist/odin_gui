package main

import "core:math"

Rectangle :: struct {
    using position: Vector2,
    size: Vector2,
}

rectangle_trim_left :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, min_amount, rectangle.size.x), min_amount)
    rectangle.position.x += amount
    rectangle.size.x -= amount
    return {
        {rectangle.position.x - amount, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_peek_trim_left :: proc(rectangle: Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, min_amount, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_trim_right :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    rectangle.size.x -= amount
    return {
        {rectangle.position.x + rectangle.size.x, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_peek_trim_right :: proc(rectangle: Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x + rectangle.size.x - amount, rectangle.position.y},
        {amount, rectangle.size.y},
    }
}

rectangle_trim_top :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    rectangle.position.y += amount
    rectangle.size.y -= amount
    return {
        {rectangle.position.x, rectangle.position.y - amount},
        {rectangle.size.x, amount},
    }
}

rectangle_peek_trim_top :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x, rectangle.position.y},
        {rectangle.size.x, amount},
    }
}

rectangle_trim_bottom :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    rectangle.size.y -= amount
    return {
        {rectangle.position.x, rectangle.position.y + rectangle.size.y},
        {rectangle.size.x, amount},
    }
}

rectangle_peek_trim_bottom :: proc(rectangle: ^Rectangle, amount: f32, min_amount: f32 = 0) -> Rectangle {
    amount := max(clamp(amount, 0, rectangle.size.x), min_amount)
    return {
        {rectangle.position.x, rectangle.position.y + rectangle.size.y - amount},
        {rectangle.size.x, amount},
    }
}

rectangle_expanded :: proc(rectangle: Rectangle, amount: Vector2) -> Rectangle {
    return {
        position = {
            min(rectangle.position.x + rectangle.size.x * 0.5, rectangle.position.x - amount.x),
            min(rectangle.position.y + rectangle.size.y * 0.5, rectangle.position.y - amount.y),
        },
        size = {
            max(0, rectangle.size.x + amount.x * 2),
            max(0, rectangle.size.y + amount.y * 2),
        },
    }
}

rectangle_expand :: proc(rectangle: ^Rectangle, amount: Vector2) {
    rectangle^ = rectangle_expanded(rectangle^, amount)
}

rectangle_padded :: proc(rectangle: Rectangle, amount: Vector2) -> Rectangle {
    return rectangle_expanded(rectangle, -amount)
}

rectangle_pad :: proc(rectangle: ^Rectangle, amount: Vector2) {
    rectangle^ = rectangle_padded(rectangle^, amount)
}

rectangle_snapped :: proc(rectangle: Rectangle, increment: Vector2) -> Rectangle {
    return {
        {
            math.round(rectangle.position.x / increment.x) * increment.x,
            math.round(rectangle.position.y / increment.y) * increment.y,
        },
        {
            math.round(rectangle.size.x / increment.x) * increment.x,
            math.round(rectangle.size.y / increment.y) * increment.y,
        },
    }
}

rectangle_snap :: proc(rectangle: ^Rectangle, increment: Vector2) {
    rectangle^ = rectangle_snapped(rectangle^, increment)
}

rectangle_intersection :: proc(a, b: Rectangle) -> Rectangle {
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

rectangle_intersects :: proc(a, b: Rectangle, include_borders := false) -> bool {
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

rectangle_encloses :: proc{
    rectangle_encloses_rect,
    rectangle_encloses_vector2,
}

rectangle_encloses_rect :: proc(a, b: Rectangle, include_borders := false) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0 && b.size.x >= 0 && b.size.y >= 0)
    if include_borders {
        return b.position.x >= a.position.x &&
               b.position.y >= a.position.y &&
               b.position.x + b.size.x <= a.position.x + a.size.x &&
               b.position.y + b.size.y <= a.position.y + a.size.y
    } else {
        return b.position.x > a.position.x &&
               b.position.y > a.position.y &&
               b.position.x + b.size.x < a.position.x + a.size.x &&
               b.position.y + b.size.y < a.position.y + a.size.y
    }
}

rectangle_encloses_vector2 :: proc(a: Rectangle, b: Vector2, include_borders := false) -> bool {
    assert(a.size.x >= 0 && a.size.y >= 0)
    if include_borders {
        return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
               b.y >= a.position.y && b.y <= a.position.y + a.size.y
    } else {
        return b.x > a.position.x && b.x < a.position.x + a.size.x &&
               b.y > a.position.y && b.y < a.position.y + a.size.y
    }
}

rectangle_hit_test :: proc(a: Rectangle, b: Vector2) -> bool {
    return rectangle_encloses_vector2(a, b, include_borders = false) &&
           rectangle_encloses_vector2(clip_rectangle(), b, include_borders = false)
}