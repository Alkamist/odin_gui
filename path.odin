package main

import "base:runtime"
import "core:math"

KAPPA :: 0.5522847493

Sub_Path :: struct {
    is_hole: bool,
    is_closed: bool,
    points: [dynamic]Vector2,
}

Path :: struct {
    sub_paths: [dynamic]Sub_Path,
    allocator: runtime.Allocator,
}

temp_path :: proc() -> (res: Path) {
    path_init(&res, arena_allocator())
    return
}

path_init :: proc(path: ^Path, allocator := context.allocator) -> runtime.Allocator_Error {
    path.sub_paths = make([dynamic]Sub_Path, allocator = allocator) or_return
    path.allocator = allocator
    return nil
}

path_destroy :: proc(path: ^Path) {
    for sub_path in path.sub_paths {
        delete(sub_path.points)
    }
    delete(path.sub_paths)
}

// Closes the current sub-path.
path_close :: proc(path: ^Path, is_hole := false) {
    path.sub_paths[len(path.sub_paths) - 1].is_closed = true
    path.sub_paths[len(path.sub_paths) - 1].is_hole = is_hole
}

// Translates all points in the path by the given amount.
path_translate :: proc(path: ^Path, amount: Vector2) {
    for &sub_path in path.sub_paths {
        for &point in sub_path.points {
            point += amount
        }
    }
}

// Starts a new sub-path with the specified point as the first point.
path_move_to :: proc(path: ^Path, point: Vector2) {
    sub_path: Sub_Path
    sub_path.points = make([dynamic]Vector2, allocator = path.allocator)
    append(&sub_path.points, point)
    append(&path.sub_paths, sub_path)
}

// Adds a line segment from the last point in the path to the specified point.
path_line_to :: proc(path: ^Path, point: Vector2) {
    if len(path.sub_paths) <= 0 do return
    sub_path := &path.sub_paths[len(path.sub_paths) - 1]
    append(&sub_path.points, _sub_path_previous_point(sub_path), point, point)
}

// Adds a cubic bezier segment from the last point in the path via two control points to the specified point.
path_bezier_to :: proc(path: ^Path, control_start, control_end, point: Vector2) {
    if len(path.sub_paths) <= 0 do return
    sub_path := &path.sub_paths[len(path.sub_paths) - 1]
    append(&sub_path.points, control_start, control_end, point)
}

// Adds a quadratic bezier segment from the last point in the path via a control point to the specified point.
path_quad_to :: proc(path: ^Path, control, point: Vector2) {
    previous := _path_previous_point(path)
    path_bezier_to(path,
        previous + 2 / 3 * (control - previous),
        point + 2 / 3 * (control - point),
        point,
    )
}

// Adds a circlular arc shaped sub-path. Angles are in radians.
path_arc :: proc(
    path: ^Path,
    center: Vector2,
    radius: f32,
    start_angle, end_angle: f32,
    counterclockwise := false,
) {
    _path_arc(path, center.x, center.y, radius, start_angle, end_angle, counterclockwise)
}

// Adds an arc segment at the corner defined by the last path point, and two control points.
path_arc_to :: proc(path: ^Path, control1: Vector2, control2: Vector2, radius: f32) {
    _path_arc_to(path, control1.x, control1.y, control2.x, control2.y, radius)
}

// Adds a new rectangle shaped sub-path.
path_rectangle :: proc(path: ^Path, rectangle: Rectangle, is_hole := false) {
    if rectangle.size.x <= 0 || rectangle.size.y <= 0 do return
    _path_rectangle(path, rectangle.x, rectangle.y, rectangle.size.x, rectangle.size.y, is_hole)
}

// Adds a new rounded rectangle shaped sub-path.
path_rounded_rectangle :: proc(
    path: ^Path,
    rectangle: Rectangle,
    radius: f32,
    is_hole := false,
) {
    path_rounded_rectangle_varying(path, rectangle, radius, radius, radius, radius, is_hole)
}

// Adds a new rounded rectangle shaped sub-path with varying radii for each corner.
path_rounded_rectangle_varying :: proc(
    path: ^Path,
    rectangle: Rectangle,
    radius_top_left: f32,
    radius_top_right: f32,
    radius_bottom_right: f32,
    radius_bottom_left: f32,
    is_hole := false,
) {
    if rectangle.size.x <= 0 || rectangle.size.y <= 0 do return
    _path_rounded_rect_varying(path,
        rectangle.x, rectangle.y,
        rectangle.size.x, rectangle.size.y,
        radius_top_left,
        radius_top_right,
        radius_bottom_right,
        radius_bottom_left,
        is_hole,
    )
}

// Adds an ellipse shaped sub-path.
path_ellipse :: proc(path: ^Path, center, radius: Vector2, is_hole := false) {
    _path_ellipse(path, center.x, center.y, radius.x, radius.y, is_hole)
}

// Adds a circle shaped sub-path.
path_circle :: proc(path: ^Path, center: Vector2, radius: f32, is_hole := false) {
    _path_circle(path, center.x, center.y, radius, is_hole)
}

// path_hit_test :: proc(path: ^Path, point: Vector2, tolerance: f32 = 0.25) -> bool {
//     for &sub_path in path.sub_paths {
//         if sub_path_hit_test(&sub_path, point, tolerance) {
//             return true
//         }
//     }
//     return false
// }

// sub_path_hit_test :: proc(sub_path: ^Sub_Path, point: Vector2, tolerance: f32) -> bool {
//     if len(sub_path.points) <= 0 do return false

//     crossings := 0

//     downward_ray_end := point + {0, 1e6}

//     for i := 1; i < len(sub_path.points); i += 3 {
//         p1 := sub_path.points[i - 1]
//         c1 := sub_path.points[i]
//         c2 := sub_path.points[i + 1]
//         p2 := sub_path.points[i + 2]

//         if _, ok := bezier_and_line_segment_collision(p1, c1, c2, p2, point, downward_ray_end, 0, tolerance); ok {
//             crossings += 1
//         }
//     }

//     start_point := sub_path.points[0]
//     final_point := sub_path.points[len(sub_path.points) - 1]

//     if _, ok := line_segment_collision(point, downward_ray_end, start_point, final_point); ok {
//         crossings += 1
//     }

//     return crossings > 0 && crossings % 2 != 0
// }

// line_segment_collision :: proc(a0, a1, b0, b1: Vector2) -> (collision: Vector2, ok: bool) {
//     div := (b1.y - b0.y) * (a1.x - a0.x) - (b1.x - b0.x) * (a1.y - a0.y)

//     if abs(div) >= math.F32_EPSILON {
//         ok = true

//         xi := ((b0.x - b1.x) * (a0.x * a1.y - a0.y * a1.x) - (a0.x - a1.x) * (b0.x * b1.y - b0.y * b1.x)) / div
//         yi := ((b0.y - b1.y) * (a0.x * a1.y - a0.y * a1.x) - (a0.y - a1.y) * (b0.x * b1.y - b0.y * b1.x)) / div

//         if (abs(a0.x - a1.x) > math.F32_EPSILON && (xi < min(a0.x, a1.x) || xi > max(a0.x, a1.x))) ||
//            (abs(b0.x - b1.x) > math.F32_EPSILON && (xi < min(b0.x, b1.x) || xi > max(b0.x, b1.x))) ||
//            (abs(a0.y - a1.y) > math.F32_EPSILON && (yi < min(a0.y, a1.y) || yi > max(a0.y, a1.y))) ||
//            (abs(b0.y - b1.y) > math.F32_EPSILON && (yi < min(b0.y, b1.y) || yi > max(b0.y, b1.y))) {
//             ok = false
//         }

//         if ok && collision != 0 {
//             collision.x = xi
//             collision.y = yi
//         }
//     }

//     return
// }

// bezier_and_line_segment_collision :: proc(
//     start: Vector2,
//     control_start: Vector2,
//     control_finish: Vector2,
//     finish: Vector2,
//     segment_start: Vector2,
//     segment_finish: Vector2,
//     level: int,
//     tolerance: f32,
// ) -> (collision: Vector2, ok: bool) {
//     if level > 10 {
//         return
//     }

//     x12 := (start.x + control_start.x) * 0.5
//     y12 := (start.y + control_start.y) * 0.5
//     x23 := (control_start.x + control_finish.x) * 0.5
//     y23 := (control_start.y + control_finish.y) * 0.5
//     x34 := (control_finish.x + finish.x) * 0.5
//     y34 := (control_finish.y + finish.y) * 0.5
//     x123 := (x12 + x23) * 0.5
//     y123 := (y12 + y23) * 0.5

//     dx := finish.x - start.x
//     dy := finish.y - start.y
//     d2 := abs(((control_start.x - finish.x) * dy - (control_start.y - finish.y) * dx))
//     d3 := abs(((control_finish.x - finish.x) * dy - (control_finish.y - finish.y) * dx))

//     if (d2 + d3) * (d2 + d3) < tolerance * (dx * dx + dy * dy) {
//         return line_segment_collision(segment_start, segment_finish, {start.x, start.y}, {finish.x, finish.y})
//     }

//     x234 := (x23 + x34) * 0.5
//     y234 := (y23 + y34) * 0.5
//     x1234 := (x123 + x234) * 0.5
//     y1234 := (y123 + y234) * 0.5

//     if collision, ok := bezier_and_line_segment_collision(start, {x12, y12}, {x123, y123}, {x1234, y1234}, segment_start, segment_finish, level + 1, tolerance); ok {
//         return collision, ok
//     }
//     if collision, ok := bezier_and_line_segment_collision({x1234, y1234}, {x234, y234}, {x34, y34}, finish, segment_start, segment_finish, level + 1, tolerance); ok {
//         return collision, ok
//     }

//     return {}, false
// }

_sub_path_previous_point :: #force_inline proc(sub_path: ^Sub_Path) -> Vector2 {
    return sub_path.points[len(sub_path.points) - 1]
}

_path_previous_point :: #force_inline proc(path: ^Path) -> Vector2 {
    if len(path.sub_paths) <= 0 do return {0, 0}
    return _sub_path_previous_point(&path.sub_paths[len(path.sub_paths) - 1])
}

_path_close :: path_close

_path_move_to :: proc(path: ^Path, x, y: f32) {
    path_move_to(path, {x, y})
}

_path_line_to :: proc(path: ^Path, x, y: f32) {
    path_line_to(path, {x, y})
}

_path_bezier_to :: proc(path: ^Path, c1x, c1y, c2x, c2y, x, y: f32) {
    path_bezier_to(path, {c1x, c1y}, {c2x, c2y}, {x, y})
}

_path_quad_to :: proc(path: ^Path, cx, cy, x, y: f32) {
    path_quad_to(path, {cx, cy}, {x, y})
}

_path_arc :: proc(path: ^Path, cx, cy, r, a0, a1: f32, counterclockwise: bool) {
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
                _path_move_to(path, x, y)
            } else {
                _path_line_to(path, x, y)
            }
        } else {
            _path_bezier_to(path,
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

_path_arc_to :: proc(
    path: ^Path,
    x1, y1: f32,
    x2, y2: f32,
    radius: f32,
) {
    if len(path.sub_paths) <= 0 do return

    previous := _path_previous_point(path)

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
        _path_line_to(path, x1, y1)
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
        _path_line_to(path, x1, y1)
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

    _path_arc(path, cx, cy, radius, a0, a1, counterclockwise)
}

_path_rectangle :: proc(path: ^Path, x, y, w, h: f32, is_hole: bool) {
    _path_move_to(path, x, y)
    _path_line_to(path, x, y + h)
    _path_line_to(path, x + w, y + h)
    _path_line_to(path, x + w, y)
    _path_close(path, is_hole)
}

_path_rounded_rect_varying :: proc(
    path: ^Path,
    x, y: f32,
    w, h: f32,
    radius_top_left: f32,
    radius_top_right: f32,
    radius_bottom_right: f32,
    radius_bottom_left: f32,
    is_hole: bool,
) {
    if radius_top_left < 0.1 && radius_top_right < 0.1 && radius_bottom_right < 0.1 && radius_bottom_left < 0.1 {
        _path_rectangle(path, x, y, w, h, is_hole)
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
        _path_move_to(path, x, y + ryTL)
        _path_line_to(path, x, y + h - ryBL)
        _path_bezier_to(path, x, y + h - ryBL*(1 - KAPPA), x + rxBL*(1 - KAPPA), y + h, x + rxBL, y + h)
        _path_line_to(path, x + w - rxBR, y + h)
        _path_bezier_to(path, x + w - rxBR*(1 - KAPPA), y + h, x + w, y + h - ryBR*(1 - KAPPA), x + w, y + h - ryBR)
        _path_line_to(path, x + w, y + ryTR)
        _path_bezier_to(path, x + w, y + ryTR*(1 - KAPPA), x + w - rxTR*(1 - KAPPA), y, x + w - rxTR, y)
        _path_line_to(path, x + rxTL, y)
        _path_bezier_to(path, x + rxTL*(1 - KAPPA), y, x, y + ryTL*(1 - KAPPA), x, y + ryTL)
        _path_close(path, is_hole)
    }
}

_path_ellipse :: proc(path: ^Path, cx, cy, rx, ry: f32, is_hole: bool) {
    _path_move_to(path, cx-rx, cy)
    _path_bezier_to(path, cx-rx, cy+ry*KAPPA, cx-rx*KAPPA, cy+ry, cx, cy+ry)
    _path_bezier_to(path, cx+rx*KAPPA, cy+ry, cx+rx, cy+ry*KAPPA, cx+rx, cy)
    _path_bezier_to(path, cx+rx, cy-ry*KAPPA, cx+rx*KAPPA, cy-ry, cx, cy-ry)
    _path_bezier_to(path, cx-rx*KAPPA, cy-ry, cx-rx, cy-ry*KAPPA, cx-rx, cy)
    _path_close(path, is_hole)
}

_path_circle :: #force_inline proc(path: ^Path, cx, cy: f32, radius: f32, is_hole: bool) {
    _path_ellipse(path, cx, cy, radius, radius, is_hole)
}