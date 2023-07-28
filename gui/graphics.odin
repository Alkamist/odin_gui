package gui

import "core:fmt"
import "core:math"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import gl "vendor:OpenGL"

Font :: int
Color :: [4]f32
Paint :: nvg.Paint

Path_Winding :: enum {
    Positive,
    Negative,
}

Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_hover_request: Id,
}

pixel_align :: proc{
    pixel_align_f32,
    pixel_align_vec2,
}

pixel_align_f32 :: proc(ctx: ^Context, value: f32) -> f32 {
    scale := content_scale(ctx)
    return math.round(value * scale) / scale
}

pixel_align_vec2 :: proc(ctx: ^Context, position: Vec2) -> Vec2 {
    return {pixel_align_f32(ctx, position.x), pixel_align_f32(ctx, position.y)}
}

solid_paint :: proc(color: Color) -> Paint {
    paint: Paint
    nvg.TransformIdentity(&paint.xform)
    paint.radius = 0.0
    paint.feather = 1.0
    paint.innerColor = color
    paint.outerColor = color
    return paint
}

begin_path :: proc(ctx: ^Context) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Begin_Path_Command{})
}

close_path :: proc(ctx: ^Context) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Close_Path_Command{})
}

move_to :: proc(ctx: ^Context, position: Vec2) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Move_To_Command{
        position + current_offset(ctx),
    })
}

line_to :: proc(ctx: ^Context, position: Vec2) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Line_To_Command{
        position + current_offset(ctx),
    })
}

arc_to :: proc(ctx: ^Context, p0, p1: Vec2, radius: f32) {
    layer := current_layer(ctx)
    offset := current_offset(ctx)
    append(&layer.draw_commands, Arc_To_Command{
        p0 + offset,
        p1 + offset,
        radius,
    })
}

rect :: proc(ctx: ^Context, position, size: Vec2, winding: Path_Winding = .Positive) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Rect_Command{
        position + current_offset(ctx),
        size,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect_varying :: proc(ctx: ^Context, position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Rounded_Rect_Command{
        position + current_offset(ctx),
        size,
        top_left_radius, top_right_radius,
        bottom_right_radius, bottom_left_radius,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect :: proc(ctx: ^Context, position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    rounded_rect_varying(ctx, position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(ctx: ^Context, paint: Paint) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Fill_Path_Command{paint})
}

fill_path :: proc(ctx: ^Context, color: Color) {
    fill_path_paint(ctx, solid_paint(color))
}

fill_text_line :: proc(ctx: ^Context, text: string, position: Vec2, color := Color{1, 1, 1, 1}, font: Font = 0, font_size: f32 = 13.0) {
    layer := current_layer(ctx)
    append(&layer.draw_commands, Fill_Text_Command{
      font = font,
      font_size = font_size,
      position = pixel_align(ctx, current_offset(ctx) + position),
      text = text,
      color = color,
    })
}

load_font_data :: proc(ctx: ^Context, data: []byte) -> Font {
    font := nvg.CreateFontMem(ctx.nvg_ctx, "", data, false)
    if font == -1 {
        fmt.eprintln("Failed to load font.")
    }
    return font
}

text_metrics :: proc(ctx: ^Context, font: Font, font_size: f32) -> (ascender, descender, line_height: f32) {
    _set_font(ctx, font)
    _set_font_size(ctx, font_size)
    return nvg.TextMetrics(ctx.nvg_ctx)
}

current_layer :: proc(ctx: ^Context) -> ^Layer {
    return &ctx.layer_stack[len(ctx.layer_stack) - 1]
}

_render_draw_commands :: proc(ctx: ^Context, commands: []Draw_Command) {
    nvg_ctx := ctx.nvg_ctx
    for command in commands {
        switch in command {
        case Begin_Path_Command:
            nvg.BeginPath(nvg_ctx)
        case Close_Path_Command:
            nvg.ClosePath(nvg_ctx)
        case Rect_Command:
            c := command.(Rect_Command)
            nvg.Rect(nvg_ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        case Rounded_Rect_Command:
            c := command.(Rounded_Rect_Command)
            nvg.RoundedRectVarying(nvg_ctx, c.position.x, c.position.y, c.size.x, c.size.y, c.top_left_radius, c.top_right_radius, c.bottom_right_radius, c.bottom_left_radius)
        case Move_To_Command:
            c := command.(Move_To_Command)
            nvg.MoveTo(nvg_ctx, c.position.x, c.position.y)
        case Line_To_Command:
            c := command.(Line_To_Command)
            nvg.LineTo(nvg_ctx, c.position.x, c.position.y)
        case Arc_To_Command:
            c := command.(Arc_To_Command)
            nvg.ArcTo(nvg_ctx, c.p0.x, c.p0.y, c.p1.x, c.p1.y, c.radius)
        case Winding_Command:
            c := command.(Winding_Command)
            winding: nvg.Winding = ---
            switch c.winding {
            case .Negative: winding = .CW
            case .Positive: winding = .CCW
            }
            nvg.PathWinding(nvg_ctx, winding)
        case Fill_Path_Command:
            c := command.(Fill_Path_Command)
            nvg.FillPaint(nvg_ctx, c.paint)
            nvg.Fill(nvg_ctx)
        case Stroke_Path_Command:
            c := command.(Stroke_Path_Command)
            nvg.StrokeWidth(nvg_ctx, c.width)
            nvg.StrokePaint(nvg_ctx, c.paint)
            nvg.Stroke(nvg_ctx)
        case Fill_Text_Command:
            c := command.(Fill_Text_Command)
            _set_font(ctx, c.font)
            _set_font_size(ctx, c.font_size)
            nvg.FillColor(nvg_ctx, c.color)
            _render_text_raw(ctx, c.position.x, c.position.y, c.text)
        case Clip_Command:
            c := command.(Clip_Command)
            nvg.Scissor(nvg_ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        }
    }
}

_render_text_raw :: proc(ctx: ^Context, x, y: f32, text: string) {
    if len(text) == 0 {
        return
    }
    nvg.Text(ctx.nvg_ctx, x, y, text)
}

_set_font :: proc(ctx: ^Context, font: Font) {
    if font == ctx.font {
        return
    }
    nvg.FontFaceId(ctx.nvg_ctx, font)
    ctx.font = font
}

_set_font_size :: proc(ctx: ^Context, font_size: f32) {
    if font_size == ctx.font_size {
        return
    }
    nvg.FontSize(ctx.nvg_ctx, font_size)
    ctx.font_size = font_size
}

Begin_Path_Command :: struct {}
Close_Path_Command :: struct {}

Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
}

Rounded_Rect_Command :: struct {
    position: Vec2,
    size: Vec2,
    top_left_radius: f32,
    top_right_radius: f32,
    bottom_right_radius: f32,
    bottom_left_radius: f32,
}

Move_To_Command :: struct {
    position: Vec2,
}

Line_To_Command :: struct {
    position: Vec2,
}

Arc_To_Command :: struct {
    p0, p1: Vec2,
    radius: f32,
}

Winding_Command :: struct {
    winding: Path_Winding,
}

Fill_Path_Command :: struct {
    paint: Paint,
}

Stroke_Path_Command :: struct {
    paint: Paint,
    width: f32,
}

Fill_Text_Command :: struct {
    font: Font,
    font_size: f32,
    position: Vec2,
    text: string,
    color: Color,
}

Clip_Command :: struct {
    position: Vec2,
    size: Vec2,
}

Draw_Command :: union {
    Begin_Path_Command,
    Close_Path_Command,
    Rect_Command,
    Rounded_Rect_Command,
    Move_To_Command,
    Line_To_Command,
    Arc_To_Command,
    Winding_Command,
    Fill_Path_Command,
    Stroke_Path_Command,
    Fill_Text_Command,
    Clip_Command,
}