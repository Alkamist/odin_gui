package gui

import "core:fmt"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

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

begin_path :: proc(window: ^Window) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Begin_Path_Command{})
}

close_path :: proc(window: ^Window) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Close_Path_Command{})
}

move_to :: proc(window: ^Window, position: Vec2) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Move_To_Command{
        position + current_offset(window),
    })
}

line_to :: proc(window: ^Window, position: Vec2) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Line_To_Command{
        position + current_offset(window),
    })
}

arc_to :: proc(window: ^Window, p0, p1: Vec2, radius: f32) {
    layer := _current_layer(window)
    offset := current_offset(window)
    append(&layer.draw_commands, Arc_To_Command{
        p0 + offset,
        p1 + offset,
        radius,
    })
}

rect :: proc(window: ^Window, position, size: Vec2, winding: Path_Winding = .Positive) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Rect_Command{
        position + current_offset(window),
        size,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect_varying :: proc(window: ^Window, position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Rounded_Rect_Command{
        position + current_offset(window),
        size,
        top_left_radius, top_right_radius,
        bottom_right_radius, bottom_left_radius,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

rounded_rect :: proc(window: ^Window, position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    rounded_rect_varying(window, position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(window: ^Window, paint: Paint) {
    layer := _current_layer(window)
    append(&layer.draw_commands, Fill_Path_Command{paint})
}

fill_path :: proc(window: ^Window, color: Color) {
    fill_path_paint(window, solid_color(color))
}

add_font :: proc(ctx: ^Vg_Context, data: []byte) -> Font {
    font := nvg.CreateFontMem(ctx.nvg_ctx, "", data, false)
    if font == -1 {
        fmt.eprintln("Failed to load font.")
    }
    return font
}

text_metrics :: proc(ctx: ^Vg_Context, font: Font, font_size: f32) -> (ascender, descender, line_height: f32) {
    _set_font(ctx, font)
    _set_font_size(ctx, font_size)
    return nvg.TextMetrics(ctx.nvg_ctx)
}

render_draw_commands :: proc(window: ^Window, commands: []Draw_Command) {
    vg_ctx := window.vg_ctx
    nvg_ctx := vg_ctx.nvg_ctx
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
            _set_font(vg_ctx, c.font)
            _set_font_size(vg_ctx, c.font_size)
            nvg.FillColor(nvg_ctx, c.color)
            _render_text_raw(vg_ctx, c.position.x, c.position.y, c.text)
        case Clip_Command:
            c := command.(Clip_Command)
            nvg.Scissor(nvg_ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        }
    }
}

Vg_Context :: struct {
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

_vg_init_context :: proc(ctx: ^Vg_Context) {
    ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

_vg_destroy_context :: proc(ctx: ^Vg_Context) {
    nvg_gl.Destroy(ctx.nvg_ctx)
}

_vg_begin_frame :: proc(ctx: ^Vg_Context, size: Vec2, content_scale: f32) {
    nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(ctx.nvg_ctx, .LEFT, .TOP)
    ctx.font = 0
    ctx.font_size = 16.0
}

_vg_end_frame :: proc(ctx: ^Vg_Context) {
    nvg.EndFrame(ctx.nvg_ctx)
}

_current_layer :: proc(window: ^Window) -> ^Layer {
    return &window.layer_stack[len(window.layer_stack) - 1]
}

_render_text_raw :: proc(ctx: ^Vg_Context, x, y: f32, text: string) {
    if len(text) == 0 {
        return
    }
    nvg.Text(ctx.nvg_ctx, x, y, text)
}

_set_font :: proc(ctx: ^Vg_Context, font: Font) {
    if font == ctx.font {
        return
    }
    nvg.FontFaceId(ctx.nvg_ctx, font)
    ctx.font = font
}

_set_font_size :: proc(ctx: ^Vg_Context, font_size: f32) {
    if font_size == ctx.font_size {
        return
    }
    nvg.FontSize(ctx.nvg_ctx, font_size)
    ctx.font_size = font_size
}

// proc measureGlyphs*(ctx: ^Context, text: openArray[char], font: Font, fontSize: float): seq[Glyph] =
//   if text.len == 0:
//     return

//   ctx.setFont(font)
//   ctx.setFontSize(fontSize)

//   var nvgPositions = newSeq[NVGglyphPosition](text.len)
//   let positionCount = nvgTextGlyphPositions(
//     ctx.nvg_ctx, 0, 0,
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