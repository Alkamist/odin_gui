package paths

import "base:runtime"
import "core:math"
import "../rects"

// Basically the path logic of vendor:nanovg but without the context.

KAPPA :: 0.5522847493

Vec2 :: [2]f32
Rect :: rects.Rect
Color :: [4]f32

Sub_Path :: struct {
    is_closed: bool,
    points: [dynamic]Vec2,
}

Path :: struct {
    sub_paths: [dynamic]Sub_Path,
    allocator: runtime.Allocator,
}

init :: proc(path: ^Path, allocator := context.allocator) -> runtime.Allocator_Error {
    path.sub_paths = make([dynamic]Sub_Path, allocator = allocator) or_return
    path.allocator = allocator
    return nil
}

destroy :: proc(path: ^Path) {
    for sub_path in path.sub_paths {
        delete(sub_path.points)
    }
    delete(path.sub_paths)
}

// Closes the current sub-path.
close :: proc(path: ^Path) {
    path.sub_paths[len(path.sub_paths) - 1].is_closed = true
}

// Translates all points in the path by the given amount.
translate :: proc(path: ^Path, amount: Vec2) {
    for &sub_path in path.sub_paths {
        for &point in sub_path.points {
            point += amount
        }
    }
}

// Starts a new sub-path with the specified point as the first point.
move_to :: proc(path: ^Path, point: Vec2) {
    sub_path: Sub_Path
    sub_path.points = make([dynamic]Vec2, allocator = path.allocator)
    append(&sub_path.points, point)
    append(&path.sub_paths, sub_path)
}

// Adds a line segment from the last point in the path to the specified point.
line_to :: proc(path: ^Path, point: Vec2) {
    if len(path.sub_paths) <= 0 do return
    sub_path := &path.sub_paths[len(path.sub_paths) - 1]
    append(&sub_path.points, _sub_path_previous_point(sub_path), point, point)
}

// Adds a cubic bezier segment from the last point in the path via two control points to the specified point.
bezier_to :: proc(path: ^Path, control_start, control_end, point: Vec2) {
    if len(path.sub_paths) <= 0 do return
    sub_path := &path.sub_paths[len(path.sub_paths) - 1]
    append(&sub_path.points, control_start, control_end, point)
}

// Adds a quadratic bezier segment from the last point in the path via a control point to the specified point.
quad_to :: proc(path: ^Path, control, point: Vec2) {
    previous := _previous_point(path)
    bezier_to(path,
        previous + 2 / 3 * (control - previous),
        point + 2 / 3 * (control - point),
        point,
    )
}

// Adds a circlular arc shaped sub-path. Angles are in radians.
arc :: proc(
    path: ^Path,
    center: Vec2,
    radius: f32,
    start_angle, end_angle: f32,
    counterclockwise := false,
) {
    _arc(path, center.x, center.y, radius, start_angle, end_angle, counterclockwise)
}

// Adds an arc segment at the corner defined by the last path point, and two control points.
arc_to :: proc(path: ^Path, control1: Vec2, control2: Vec2, radius: f32) {
    _arc_to(path, control1.x, control1.y, control2.x, control2.y, radius)
}

// Adds a new rectangle shaped sub-path.
rect :: proc(path: ^Path, rect: Rect) {
    _rect(path, rect.x, rect.y, rect.size.x, rect.size.y)
}

// Adds a new rounded rectangle shaped sub-path.
rounded_rect :: proc(
    path: ^Path,
    rect: Rect,
    radius: f32,
) {
    rounded_rect_varying(path, rect, radius, radius, radius, radius)
}

// Adds a new rounded rectangle shaped sub-path with varying radii for each corner.
rounded_rect_varying :: proc(
    path: ^Path,
    rect: Rect,
    radius_top_left: f32,
    radius_top_right: f32,
    radius_bottom_right: f32,
    radius_bottom_left: f32,
) {
    _rounded_rect_varying(path,
        rect.position.x, rect.position.y,
        rect.size.x, rect.size.y,
        radius_top_left,
        radius_top_right,
        radius_bottom_right,
        radius_bottom_left,
    )
}

// Adds an ellipse shaped sub-path.
ellipse :: proc(path: ^Path, center, radius: Vec2) {
    _ellipse(path, center.x, center.y, radius.x, radius.y)
}

// Adds a circle shaped sub-path.
circle :: proc(path: ^Path, center: Vec2, radius: f32) {
    _circle(path, center.x, center.y, radius)
}



_sub_path_previous_point :: #force_inline proc(sub_path: ^Sub_Path) -> Vec2 {
    return sub_path.points[len(sub_path.points) - 1]
}

_previous_point :: #force_inline proc(path: ^Path) -> Vec2 {
    if len(path.sub_paths) <= 0 do return {0, 0}
    return _sub_path_previous_point(&path.sub_paths[len(path.sub_paths) - 1])
}

_close :: close

_move_to :: proc(path: ^Path, x, y: f32) {
    move_to(path, {x, y})
}

_line_to :: proc(path: ^Path, x, y: f32) {
    line_to(path, {x, y})
}

_bezier_to :: proc(path: ^Path, c1x, c1y, c2x, c2y, x, y: f32) {
    bezier_to(path, {c1x, c1y}, {c2x, c2y}, {x, y})
}

_quad_to :: proc(path: ^Path, cx, cy, x, y: f32) {
    quad_to(path, {cx, cy}, {x, y})
}

_arc :: proc(path: ^Path, cx, cy, r, a0, a1: f32, counterclockwise: bool) {
    use_move_to := len(path.sub_paths) <= 0 || path.sub_paths[len(path.sub_paths) - 1].is_closed

    // Clamp angles
    da := a1 - a0
    if !counterclockwise {
        if abs(da) >= math.PI*2 {
            da = math.PI*2
        } else {
            for da < 0.0 {
                da += math.PI*2
            }
        }
    } else {
        if abs(da) >= math.PI*2 {
            da = -math.PI*2
        } else {
            for da > 0.0 {
                da -= math.PI*2
            }
        }
    }

    // Split arc into max 90 degree segments.
    ndivs := max(1, min((int)(abs(da) / (math.PI*0.5) + 0.5), 5))
    hda := (da / f32(ndivs)) / 2.0
    kappa := abs(4.0 / 3.0 * (1.0 - math.cos(hda)) / math.sin(hda))

    if counterclockwise {
        kappa = -kappa
    }

    px, py, ptanx, ptany: f32
    for i in 0..=ndivs {
        a := a0 + da * f32(i) / f32(ndivs)
        dx := math.cos(a)
        dy := math.sin(a)
        x := cx + dx*r
        y := cy + dy*r
        tanx := -dy*r*kappa
        tany := dx*r*kappa

        if i == 0 {
            if use_move_to {
                _move_to(path, x, y)
            } else {
                _line_to(path, x, y)
            }
        } else {
            _bezier_to(path,
                px + ptanx, py + ptany,
                x - tanx, y - tany,
                x, y,
            )
        }

        px = x
        py = y
        ptanx = tanx
        ptany = tany
    }
}

_arc_to :: proc(
    path: ^Path,
    x1, y1: f32,
    x2, y2: f32,
    radius: f32,
) {
    if len(path.sub_paths) <= 0 do return

    previous := _previous_point(path)

    x0 := previous.x
    y0 := previous.y

    __ptEquals :: proc(x0, y0, x1, y1: f32) -> bool {
        return x0 == x1 && y0 == y1
    }

    __distPtSeg :: proc(x, y, px, py, qx, qy: f32) -> f32 {
        pqx := qx - px
        pqy := qy - py
        dx := x - px
        dy := y - py
        d := pqx * pqx + pqy * pqy
        t := pqx * dx + pqy * dy

        if d > 0 {
            t /= d
        }
        t = clamp(t, 0, 1)

        dx = px + t * pqx - x
        dy = py + t * pqy - y
        return dx * dx + dy * dy
    }

    // Handle degenerate cases.
    if __ptEquals(x0,y0, x1,y1) ||
       __ptEquals(x1,y1, x2,y2) ||
       __distPtSeg(x1,y1, x0,y0, x2,y2) <= 0 ||
        radius <= 0 {
        _line_to(path, x1, y1)
        return
    }

    __normalize :: proc(x, y: ^f32) -> f32 {
        d := math.sqrt(x^ * x^ + y^ * y^)
        if d > 1e-6 {
            id := 1.0 / d
            x^ *= id
            y^ *= id
        }
        return d
    }

    // Calculate tangential circle to lines (x0,y0)-(x1,y1) and (x1,y1)-(x2,y2).
    dx0 := x0-x1
    dy0 := y0-y1
    dx1 := x2-x1
    dy1 := y2-y1
    __normalize(&dx0,&dy0)
    __normalize(&dx1,&dy1)
    a := math.acos(dx0*dx1 + dy0*dy1)
    d := radius / math.tan(a / 2.0)

    if d > 10000 {
        _line_to(path, x1, y1)
        return
    }

    a0, a1, cx, cy: f32
    counterclockwise: bool

    __cross :: proc(dx0, dy0, dx1, dy1: f32) -> f32 {
        return dx1*dy0 - dx0*dy1
    }

    if __cross(dx0,dy0, dx1,dy1) > 0.0 {
        cx = x1 + dx0*d + dy0*radius
        cy = y1 + dy0*d + -dx0*radius
        a0 = math.atan2(dx0, -dy0)
        a1 = math.atan2(-dx1, dy1)
        counterclockwise = false
    } else {
        cx = x1 + dx0*d + -dy0*radius
        cy = y1 + dy0*d + dx0*radius
        a0 = math.atan2(-dx0, dy0)
        a1 = math.atan2(dx1, -dy1)
        counterclockwise = true
    }

    _arc(path, cx, cy, radius, a0, a1, counterclockwise)
}

_rect :: proc(path: ^Path, x, y, w, h: f32) {
    _move_to(path, x, y)
    _line_to(path, x, y + h)
    _line_to(path, x + w, y + h)
    _line_to(path, x + w, y)
    _close(path)
}

_rounded_rect_varying :: proc(
    path: ^Path,
    x, y: f32,
    w, h: f32,
    radius_top_left: f32,
    radius_top_right: f32,
    radius_bottom_right: f32,
    radius_bottom_left: f32,
) {
    if radius_top_left < 0.1 && radius_top_right < 0.1 && radius_bottom_right < 0.1 && radius_bottom_left < 0.1 {
        _rect(path, x, y, w, h)
    } else {
        halfw := abs(w) * 0.5
        halfh := abs(h) * 0.5
        rxBL := min(radius_bottom_left, halfw) * math.sign(w)
        ryBL := min(radius_bottom_left, halfh) * math.sign(h)
        rxBR := min(radius_bottom_right, halfw) * math.sign(w)
        ryBR := min(radius_bottom_right, halfh) * math.sign(h)
        rxTR := min(radius_top_right, halfw) * math.sign(w)
        ryTR := min(radius_top_right, halfh) * math.sign(h)
        rxTL := min(radius_top_left, halfw) * math.sign(w)
        ryTL := min(radius_top_left, halfh) * math.sign(h)
        _move_to(path, x, y + ryTL)
        _line_to(path, x, y + h - ryBL)
        _bezier_to(path, x, y + h - ryBL*(1 - KAPPA), x + rxBL*(1 - KAPPA), y + h, x + rxBL, y + h)
        _line_to(path, x + w - rxBR, y + h)
        _bezier_to(path, x + w - rxBR*(1 - KAPPA), y + h, x + w, y + h - ryBR*(1 - KAPPA), x + w, y + h - ryBR)
        _line_to(path, x + w, y + ryTR)
        _bezier_to(path, x + w, y + ryTR*(1 - KAPPA), x + w - rxTR*(1 - KAPPA), y, x + w - rxTR, y)
        _line_to(path, x + rxTL, y)
        _bezier_to(path, x + rxTL*(1 - KAPPA), y, x, y + ryTL*(1 - KAPPA), x, y + ryTL)
        _close(path)
    }
}

_ellipse :: proc(path: ^Path, cx, cy, rx, ry: f32) {
    _move_to(path, cx-rx, cy)
    _bezier_to(path, cx-rx, cy+ry*KAPPA, cx-rx*KAPPA, cy+ry, cx, cy+ry)
    _bezier_to(path, cx+rx*KAPPA, cy+ry, cx+rx, cy+ry*KAPPA, cx+rx, cy)
    _bezier_to(path, cx+rx, cy-ry*KAPPA, cx+rx*KAPPA, cy-ry, cx, cy-ry)
    _bezier_to(path, cx-rx*KAPPA, cy-ry, cx-rx, cy-ry*KAPPA, cx-rx, cy)
    _close(path)
}

_circle :: #force_inline proc(path: ^Path, cx, cy: f32, radius: f32) {
    _ellipse(path, cx, cy, radius, radius)
}