package gui

import "core:math"
import "rects"

Color :: [4]f32
Font :: rawptr

Font_Metrics :: struct {
    ascender: f32,
    descender: f32,
    line_height: f32,
}

Text_Glyph :: struct {
    byte_index: int,
    position: f32,
    width: f32,
    kerning: f32,
}

Draw_Command :: union {
    Draw_Custom_Command,
    Draw_Rect_Command,
    Draw_Text_Command,
    Clip_Drawing_Command,
}

Draw_Custom_Command :: struct {
    custom: proc(),
    global_offset: Vec2,
    global_clip_rect: Rect,
}

Draw_Rect_Command :: struct {
    rect: Rect,
    color: Color,
}

Draw_Text_Command :: struct {
    text: string,
    position: Vec2,
    font: Font,
    color: Color,
}

Clip_Drawing_Command :: struct {
    global_clip_rect: Rect,
}

pixel_size :: proc() -> Vec2 {
    return 1.0 / current_window().content_scale
}

pixel_snapped :: proc{
    vec2_pixel_snapped,
    rect_pixel_snapped,
}

vec2_pixel_snapped :: proc(position: Vec2) -> Vec2 {
    pixel := pixel_size()
    return {
        math.round(position.x / pixel.x) * pixel.x,
        math.round(position.y / pixel.y) * pixel.y,
    }
}

rect_pixel_snapped :: proc(rect: Rect) -> Rect {
    return rects.snapped(rect, pixel_size())
}

draw_custom :: proc(custom: proc()) {
    ctx := current_context()
    _process_draw_command(Draw_Custom_Command{custom, global_offset(), global_clip_rect()})
}

draw_rect :: proc(rect: Rect, color: Color) {
    if rect.size.x <= 0 || rect.size.y <= 0 do return
    rect := rect
    rect.position += global_offset()
    _process_draw_command(Draw_Rect_Command{rect, color})
}

draw_text :: proc(text: string, position: Vec2, font: Font, color: Color) {
    window := current_window()
    window_load_font(window, font)
    _process_draw_command(Draw_Text_Command{text, global_offset() + position, font, color})
}

clip_drawing :: proc(rect: Rect) {
    rect := rect
    rect.position += global_offset()
    _process_draw_command(Clip_Drawing_Command{rect})
}



_process_draw_command :: proc(command: Draw_Command) {
    window := current_window()
    if window.is_rendering_draw_commands {
        ctx := current_context()
        if ctx.backend.render_draw_command != nil {
            ctx.backend.render_draw_command(window, command)
        }
    } else {
        append(&_current_layer().draw_commands, command)
    }
}