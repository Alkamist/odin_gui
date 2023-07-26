package gui

import "core:fmt"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import gl "vendor:OpenGL"

Paint :: nvg.Paint

Path_Winding :: enum {
    Positive,
    Negative,
}

solid_color :: proc(color: Color) -> Paint {
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
    fill_path_paint(ctx, solid_color(color))
}

add_font :: proc(ctx: ^Context, data: []byte) -> Font {
    font := nvg.CreateFontMem(ctx.gfx.nvg_ctx, "", data, false)
    if font == -1 {
        fmt.eprintln("Failed to load font.")
    }
    return font
}

text_metrics :: proc(ctx: ^Context, font: Font, font_size: f32) -> (ascender, descender, line_height: f32) {
    gfx := &ctx.gfx
    _set_font(gfx, font)
    _set_font_size(gfx, font_size)
    return nvg.TextMetrics(ctx.gfx.nvg_ctx)
}

render_draw_commands :: proc(ctx: ^Context, commands: []Draw_Command) {
    gfx := &ctx.gfx
    nvg_ctx := gfx.nvg_ctx
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
            _set_font(gfx, c.font)
            _set_font_size(gfx, c.font_size)
            nvg.FillColor(nvg_ctx, c.color)
            _render_text_raw(gfx, c.position.x, c.position.y, c.text)
        case Clip_Command:
            c := command.(Clip_Command)
            nvg.Scissor(nvg_ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        }
    }
}

Vector_Graphics :: struct {
    nvg_ctx: ^nvg.Context,
    font: Font,
    font_size: f32,
}

Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_hover_request: rawptr,
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

init_vector_graphics :: proc(ctx: ^Context) {
    activate_gl_context(ctx)
    ctx.gfx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
    deactivate_gl_context(ctx)
}

destroy_vector_graphics :: proc(ctx: ^Context) {
    activate_gl_context(ctx)
    nvg_gl.Destroy(ctx.gfx.nvg_ctx)
    deactivate_gl_context(ctx)
}

vector_graphics_begin_frame :: proc(ctx: ^Context, size: Vec2, content_scale: f32) {
    gfx := ctx.gfx
    nvg.BeginFrame(gfx.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(gfx.nvg_ctx, .LEFT, .TOP)
    gfx.font = 0
    gfx.font_size = 16.0
}

vector_graphics_end_frame :: proc(ctx: ^Context) {
    nvg.EndFrame(ctx.gfx.nvg_ctx)
}

current_layer :: proc(ctx: ^Context) -> ^Layer {
    return &ctx.layer_stack[len(ctx.layer_stack) - 1]
}

_render_text_raw :: proc(gfx: ^Vector_Graphics, x, y: f32, text: string) {
    if len(text) == 0 {
        return
    }
    nvg.Text(gfx.nvg_ctx, x, y, text)
}

_set_font :: proc(gfx: ^Vector_Graphics, font: Font) {
    if font == gfx.font {
        return
    }
    nvg.FontFaceId(gfx.nvg_ctx, font)
    gfx.font = font
}

_set_font_size :: proc(gfx: ^Vector_Graphics, font_size: f32) {
    if font_size == gfx.font_size {
        return
    }
    nvg.FontSize(gfx.nvg_ctx, font_size)
    gfx.font_size = font_size
}

// proc measureGlyphs*(gfx: ^Context, text: openArray[char], font: Font, fontSize: float): seq[Glyph] =
//   if text.len == 0:
//     return

//   gfx.setFont(font)
//   gfx.setFontSize(fontSize)

//   var nvgPositions = newSeq[NVGglyphPosition](text.len)
//   let positionCount = nvgTextGlyphPositions(
//     gfx.nvg_ctx, 0, 0,
//     cast[cstring](unsafeAddr(text[0])),
//     cast[cstring](cast[uint64](unsafeAddr(text[text.len - 1])) + 1),
//     addr(nvgPositions[0]),
//     cint(text.len),
//   )

//   result = newSeq[Glyph](positionCount)

//   for i in 0 ..< positionCount:
//     let byteOffset = cast[uint64](unsafeAddr(text[0]))

//     let lastByte =
//       if i == positionCount - 1:
//         text.len - 1
//       else:
//         int(cast[uint64](nvgPositions[i + 1].str) - byteOffset - 1)

//     result[i] = Glyph(
//       firstByte: int(cast[uint64](nvgPositions[i].str) - byteOffset),
//       lastByte: lastByte,
//       left: nvgPositions[i].minx,
//       right: nvgPositions[i].maxx,
//       drawOffsetX: nvgPositions[i].x - nvgPositions[i].minx,
//     )