package paths

import "core:math"

hit_test :: proc(path: ^Path, point: Vec2, tolerance: f32 = 0.25) -> bool {
    for &sub_path in path.sub_paths {
        if _sub_path_hit_test(&sub_path, point, tolerance) {
            return true
        }
    }
    return false
}

_sub_path_hit_test :: proc(sub_path: ^Sub_Path, point: Vec2, tolerance: f32) -> bool {
    if len(sub_path.points) <= 0 do return false

    crossings := 0

    downward_ray_end := point + {0, 1e6}

    for i := 1; i < len(sub_path.points); i += 3 {
        p1 := sub_path.points[i - 1]
        c1 := sub_path.points[i]
        c2 := sub_path.points[i + 1]
        p2 := sub_path.points[i + 2]

        if _, ok := _bezier_and_line_segment_collision(p1, c1, c2, p2, point, downward_ray_end, 0, tolerance); ok {
            crossings += 1
        }
    }

    start_point := sub_path.points[0]
    final_point := sub_path.points[len(sub_path.points) - 1]

    if _, ok := _line_segment_collision(point, downward_ray_end, start_point, final_point); ok {
        crossings += 1
    }

    return crossings > 0 && crossings % 2 != 0
}

_line_segment_collision :: proc(a0, a1, b0, b1: Vec2) -> (collision: Vec2, ok: bool) {
    div := (b1.y - b0.y) * (a1.x - a0.x) - (b1.x - b0.x) * (a1.y - a0.y)

    if abs(div) >= math.F32_EPSILON {
        ok = true

        xi := ((b0.x - b1.x) * (a0.x * a1.y - a0.y * a1.x) - (a0.x - a1.x) * (b0.x * b1.y - b0.y * b1.x)) / div
        yi := ((b0.y - b1.y) * (a0.x * a1.y - a0.y * a1.x) - (a0.y - a1.y) * (b0.x * b1.y - b0.y * b1.x)) / div

        if (abs(a0.x - a1.x) > math.F32_EPSILON && (xi < min(a0.x, a1.x) || xi > max(a0.x, a1.x))) ||
           (abs(b0.x - b1.x) > math.F32_EPSILON && (xi < min(b0.x, b1.x) || xi > max(b0.x, b1.x))) ||
           (abs(a0.y - a1.y) > math.F32_EPSILON && (yi < min(a0.y, a1.y) || yi > max(a0.y, a1.y))) ||
           (abs(b0.y - b1.y) > math.F32_EPSILON && (yi < min(b0.y, b1.y) || yi > max(b0.y, b1.y))) {
            ok = false
        }

        if ok && collision != 0 {
            collision.x = xi
            collision.y = yi
        }
    }

    return
}

_bezier_and_line_segment_collision :: proc(
    start: Vec2,
    control_start: Vec2,
    control_finish: Vec2,
    finish: Vec2,
    segment_start: Vec2,
    segment_finish: Vec2,
    level: int,
    tolerance: f32,
) -> (collision: Vec2, ok: bool) {
    if level > 10 {
        return
    }

    x12 := (start.x + control_start.x) * 0.5
    y12 := (start.y + control_start.y) * 0.5
    x23 := (control_start.x + control_finish.x) * 0.5
    y23 := (control_start.y + control_finish.y) * 0.5
    x34 := (control_finish.x + finish.x) * 0.5
    y34 := (control_finish.y + finish.y) * 0.5
    x123 := (x12 + x23) * 0.5
    y123 := (y12 + y23) * 0.5

    dx := finish.x - start.x
    dy := finish.y - start.y
    d2 := abs(((control_start.x - finish.x) * dy - (control_start.y - finish.y) * dx))
    d3 := abs(((control_finish.x - finish.x) * dy - (control_finish.y - finish.y) * dx))

    if (d2 + d3) * (d2 + d3) < tolerance * (dx * dx + dy * dy) {
        return _line_segment_collision(segment_start, segment_finish, {start.x, start.y}, {finish.x, finish.y})
    }

    x234 := (x23 + x34) * 0.5
    y234 := (y23 + y34) * 0.5
    x1234 := (x123 + x234) * 0.5
    y1234 := (y123 + y234) * 0.5

    if collision, ok := _bezier_and_line_segment_collision(start, {x12, y12}, {x123, y123}, {x1234, y1234}, segment_start, segment_finish, level + 1, tolerance); ok {
        return collision, ok
    }
    if collision, ok := _bezier_and_line_segment_collision({x1234, y1234}, {x234, y234}, {x34, y34}, finish, segment_start, segment_finish, level + 1, tolerance); ok {
        return collision, ok
    }

    return {}, false
}