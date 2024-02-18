package gui

import "core:math"
import "paths"
import "rects"

PI :: math.PI

Path :: paths.Path
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
    Fill_Path_Command,
    Fill_Text_Command,
    Clip_Drawing_Command,
}

Draw_Custom_Command :: struct {
    custom: proc(),
    global_offset: Vec2,
    global_clip_rect: Rect,
}

Fill_Path_Command :: struct {
    path: Path,
    color: Color,
}

Fill_Text_Command :: struct {
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
    window := current_window()
    _process_draw_command(window, Draw_Custom_Command{custom, global_offset(), global_clip_rect()})
}

fill_text :: proc(text: string, position: Vec2, font: Font, color: Color) {
    window := current_window()
    load_font(window, font)
    _process_draw_command(window, Fill_Text_Command{text, global_offset() + position, font, color})
}

clip_drawing :: proc(rect: Rect) {
    window := current_window()
    rect := rect
    rect.position += global_offset()
    _process_draw_command(window, Clip_Drawing_Command{rect})
}

fill_path :: proc(path: Path, color: Color) {
    window := current_window()
    path := path
    paths.translate(&path, global_offset())
    _process_draw_command(window, Fill_Path_Command{path, color})
}



_process_draw_command :: proc(window: ^Window, command: Draw_Command) {
    if window.is_rendering_draw_commands {
        _window_render_draw_command(window, command)
    } else {
        append(&_current_layer(window).draw_commands, command)
    }
}