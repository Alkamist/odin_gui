package widgets

import "core:math"
import "../../gui"
import "../rects"

Vec2 :: gui.Vec2
Rect :: gui.Rect
Color :: gui.Color

line_height :: proc(font: gui.Font) -> f32 {
    pixel_height := gui.pixel_size().y
    metrics, _ := gui.font_metrics(font)
    return math.ceil(metrics.line_height / pixel_height) * pixel_height
}