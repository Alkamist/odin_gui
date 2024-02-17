package paths

import "base:runtime"

Vec2 :: [2]f32
Color :: [4]f32

// start control point, end control point, destination
Bezier_Segment ::  [3]Vec2

Path :: struct {
    position: Vec2,
    segments: [dynamic]Bezier_Segment,
}

init :: proc(path: ^Path, allocator := context.allocator) -> runtime.Allocator_Error {
    path.segments = make([dynamic]Bezier_Segment, allocator = allocator) or_return
    return nil
}

destroy :: proc(path: ^Path) {
    delete(path.segments)
}

close :: proc(path: ^Path) {
    append(&path.segments, Bezier_Segment{_previous_point(path), {0, 0}, {0, 0}})
}

line_to :: proc(path: ^Path, point: Vec2) {
    append(&path.segments, Bezier_Segment{_previous_point(path), point, point})
}

bezier_to :: proc(path: ^Path, control_start, control_end, point: Vec2) {
    append(&path.segments, Bezier_Segment{control_start, control_end, point})
}



_previous_point :: #force_inline proc(path: ^Path) -> Vec2 {
    if len(path.segments) <= 0 {
        return {0, 0}
    } else {
        return path.segments[len(path.segments) - 1][2]
    }
}