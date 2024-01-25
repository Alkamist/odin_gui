package gui

import "window"

Color :: window.Color

rgb :: proc(r, g, b: u8) -> Color {
    return {
        f32(r) / 255,
        f32(g) / 255,
        f32(b) / 255,
        1.0,
    }
}

rgba :: proc(r, g, b, a: u8) -> Color {
    return {
        f32(r) / 255,
        f32(g) / 255,
        f32(b) / 255,
        f32(a) / 255,
    }
}

lerp :: proc(a, b: Color, weight: f32) -> Color {
    color := a
    color.r += (weight * (b.r - color.r))
    color.g += (weight * (b.g - color.g))
    color.b += (weight * (b.b - color.b))
    color.a += (weight * (b.a - color.a))
    return color
}

darken :: proc(c: Color, amount: f32) -> Color {
    color := c
    color.r *= 1.0 - amount
    color.g *= 1.0 - amount
    color.b *= 1.0 - amount
    return color
}

lighten :: proc(c: Color, amount: f32) -> Color {
    color := c
    color.r += (1.0 - color.r) * amount
    color.g += (1.0 - color.g) * amount
    color.b += (1.0 - color.b) * amount
    return color
}