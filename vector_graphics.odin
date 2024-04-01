package main

// import "core:math"

// Color :: [4]f32

// Font :: struct {
//     name: string,
//     size: int,
//     data: []byte,
// }

// Font_Metrics :: struct {
//     ascender: f32,
//     descender: f32,
//     line_height: f32,
// }

// Text_Glyph :: struct {
//     byte_index: int,
//     position: f32,
//     width: f32,
//     kerning: f32,
// }

// Draw_Command :: union {
//     Custom_Draw_Command,
//     Fill_Path_Command,
//     Fill_String_Command,
//     Clip_Drawing_Command,
// }

// Custom_Draw_Command :: struct {
//     custom: proc(),
//     global_offset: Vector2,
//     global_clip_rectangle: Rectangle,
// }

// Fill_Path_Command :: struct {
//     path: Path,
//     color: Color,
// }

// Fill_String_Command :: struct {
//     text: string,
//     position: Vector2,
//     font: Font,
//     color: Color,
// }

// Clip_Drawing_Command :: struct {
//     global_clip_rectangle: Rectangle,
// }

// pixel_size :: proc() -> Vector2 {
//     return 1.0 / current_window().content_scale
// }

// pixel_snapped :: proc{
//     vector2_pixel_snapped,
//     rectangle_pixel_snapped,
// }

// vector2_pixel_snapped :: proc(position: Vector2) -> Vector2 {
//     pixel := pixel_size()
//     return {
//         math.round(position.x / pixel.x) * pixel.x,
//         math.round(position.y / pixel.y) * pixel.y,
//     }
// }

// rectangle_pixel_snapped :: proc(rectangle: Rectangle) -> Rectangle {
//     return rectangle_snapped(rectangle, pixel_size())
// }

// draw_custom :: proc(custom: proc()) {
//     window := current_window()
//     _process_draw_command(window, Custom_Draw_Command{custom, global_offset(), global_clip_rectangle()})
// }

// fill_string :: proc(str: string, position: Vector2, font: Font, color: Color) {
//     window := current_window()
//     _load_font_if_not_loaded(window, font)
//     _process_draw_command(window, Fill_String_Command{str, global_offset() + position, font, color})
// }

// clip_drawing :: proc(rectangle: Rectangle) {
//     window := current_window()
//     rectangle := rectangle
//     rectangle.position += global_offset()
//     _process_draw_command(window, Clip_Drawing_Command{rectangle})
// }

// fill_path :: proc(path: Path, color: Color) {
//     window := current_window()
//     path := path
//     path_translate(&path, global_offset())
//     _process_draw_command(window, Fill_Path_Command{path, color})
// }

// measure_string :: proc(str: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) {
//     window := current_window()
//     _load_font_if_not_loaded(window, font)
//     backend_measure_string(window, str, font, glyphs, byte_index_to_rune_index)
// }

// font_metrics :: proc(font: Font) -> Font_Metrics {
//     window := current_window()
//     _load_font_if_not_loaded(window, font)
//     return backend_font_metrics(window, font)
// }

// fill_rectangle :: proc(rectangle: Rectangle, color: Color) {
//     path := temp_path()
//     path_rectangle(&path, rectangle)
//     fill_path(path, color)
// }

// outline_rectangle :: proc(rectangle: Rectangle, thickness: f32, color: Color) {
//     path := temp_path()
//     path_rectangle(&path, rectangle)
//     path_rectangle(&path, rectangle_expanded(rectangle, -thickness), true)
//     fill_path(path, color)
// }

// pixel_outline_rectangle :: proc(rectangle: Rectangle, color: Color) {
//     outline_rectangle(rectangle, pixel_size().x, color)
// }

// fill_rounded_rectangle :: proc(rectangle: Rectangle, radius: f32, color: Color) {
//     path := temp_path()
//     path_rounded_rectangle(&path, rectangle, radius)
//     fill_path(path, color)
// }

// outline_rounded_rectangle :: proc(rectangle: Rectangle, radius, thickness: f32, color: Color) {
//     path := temp_path()
//     path_rounded_rectangle(&path, rectangle, radius)
//     path_rounded_rectangle(&path, rectangle_expanded(rectangle, -thickness), radius, true)
//     fill_path(path, color)
// }

// pixel_outline_rounded_rectangle :: proc(rectangle: Rectangle, radius: f32, color: Color) {
//     outline_rounded_rectangle(rectangle, radius, pixel_size().x, color)
// }

// _load_font_if_not_loaded :: proc(window: ^Window, font: Font) {
//     if font.name not_in window.loaded_fonts {
//         backend_load_font(window, font)
//         window.loaded_fonts[font.name] = {}
//     }
// }

// _process_draw_command :: proc(window: ^Window, command: Draw_Command) {
//     if window.is_rendering_draw_commands {
//         backend_render_draw_command(window, command)
//     } else {
//         append(&_current_layer(window).draw_commands, command)
//     }
// }