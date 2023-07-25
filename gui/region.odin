package gui

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