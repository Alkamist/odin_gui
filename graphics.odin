package gui

import "core:math"

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
    offset: Vec2,
    clip_rect: Rect,
}

Draw_Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
    color: Color,
}

Draw_Text_Command :: struct {
    text: string,
    position: Vec2,
    font: Font,
    color: Color,
}

Clip_Drawing_Command :: struct {
    position: Vec2,
    size: Vec2,
}

vec2_snap :: proc(position, increment: Vec2) -> Vec2 {
    return {
        math.round(position.x / increment.x) * increment.x,
        math.round(position.y / increment.y) * increment.y,
    }
}

pixel_size :: proc() -> Vec2 {
    return 1.0 / _current_ctx.content_scale
}

pixel_snap :: proc(position: Vec2) -> Vec2 {
    return vec2_snap(position, pixel_size())
}

draw_custom :: proc(custom: proc()) {
    _process_draw_command(Draw_Custom_Command{custom, offset(), clip_rect()})
}

draw_rect :: proc(position, size: Vec2, color: Color) {
    if size.x <= 0 || size.y <= 0 do return
    _process_draw_command(Draw_Rect_Command{offset() + position, size, color})
}

draw_text :: proc(text: string, position: Vec2, font: Font, color: Color) {
    _process_draw_command(Draw_Text_Command{text, offset() + position, font, color})
}

clip_drawing :: proc(position, size: Vec2) {
    _process_draw_command(Clip_Drawing_Command{offset() + position, size})
}



_process_draw_command :: proc(command: Draw_Command) {
    if _current_ctx.is_in_render_phase {
        if _current_ctx.render_draw_command != nil {
            _current_ctx->render_draw_command(command)
        }
    } else {
        append(&_current_layer().draw_commands, command)
    }
}