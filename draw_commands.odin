package gui

import nvg "vendor:nanovg"

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
    font: ^Font,
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



_render_draw_commands :: proc(w: ^Window, commands: []Draw_Command) {
    nvg_ctx := w.nvg_ctx
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
            _set_font(w, c.font)
            _set_font_size(w, c.font_size)
            nvg.FillColor(nvg_ctx, c.color)
            nvg.Text(nvg_ctx, c.position.x, c.position.y, c.text)
        case Clip_Command:
            c := command.(Clip_Command)
            nvg.Scissor(nvg_ctx, c.position.x, c.position.y, c.size.x, c.size.y)
        }
    }
}