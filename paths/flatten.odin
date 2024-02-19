package paths

// import "core:fmt"
// import "../rects"

// _tesselate_bezier :: proc(
//     path: ^Path,
//     x1, y1: f32,
//     x2, y2: f32,
//     x3, y3: f32,
//     x4, y4: f32,
//     level: int,
// ) {
//     if level > 10 {
//         return
//     }

//     x12 := (x1 + x2) * 0.5
//     y12 := (y1 + y2) * 0.5
//     x23 := (x2 + x3) * 0.5
//     y23 := (y2 + y3) * 0.5
//     x34 := (x3 + x4) * 0.5
//     y34 := (y3 + y4) * 0.5
//     x123 := (x12 + x23) * 0.5
//     y123 := (y12 + y23) * 0.5

//     dx := x4 - x1
//     dy := y4 - y1
//     d2 := abs(((x2 - x4) * dy - (y2 - y4) * dx))
//     d3 := abs(((x3 - x4) * dy - (y3 - y4) * dx))

//     if (d2 + d3) * (d2 + d3) < path.tesselation_tolerance * (dx * dx + dy * dy) {
//         append(&path.flattened_points, Vec2{x4, y4})
//         return
//     }

//     x234 := (x23 + x34) * 0.5
//     y234 := (y23 + y34) * 0.5
//     x1234 := (x123 + x234) * 0.5
//     y1234 := (y123 + y234) * 0.5

//     _tesselate_bezier(path, x1, y1, x12, y12, x123, y123, x1234, y1234, level + 1)
//     _tesselate_bezier(path, x1234, y1234, x234, y234, x34, y34, x4, y4, level + 1)
// }

// _flatten_path :: proc(path: ^Path) {
//     for sub_path in path.sub_paths {
//         if len(sub_path.points) <= 0 do continue

//         // Add the first point.
//         append(&path.flattened_points, sub_path.points[0])

//         for i := 1; i < len(sub_path.points); i += 3 {
//             p1 := sub_path.points[i - 1]
//             c1 := sub_path.points[i]
//             c2 := sub_path.points[i + 1]
//             p2 := sub_path.points[i + 2]
//             _tesselate_bezier(path,
//                 p1.x, p1.y,
//                 c1.x, c1.y,
//                 c2.x, c2.y,
//                 p2.x, p2.y,
//                 0,
//             )
//         }
//     }

//     tl := Vec2{1e6, 1e6}
//     br := Vec2{-1e6, -1e6}

//     for i := 0; i < len(path.flattened_points); i += 1 {
//         p0 := path.flattened_points[i]
//         tl.x = min(tl.x, p0.x)
//         tl.y = min(tl.y, p0.y)
//         br.x = max(br.x, p0.x)
//         br.y = max(br.y, p0.y)
//     }

//     path.bounds = {tl, br - tl}
// }