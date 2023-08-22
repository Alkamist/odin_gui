package widgets

import "core:mem"
import "core:fmt"
import "core:time"
import "../../gui"

Performance :: struct {
    frame_time: f32,
    average_window: int,
    index: int,
    delta_times: [dynamic]time.Duration,
    previous_average_window: int,
}

init_performance :: proc(
    perf: ^Performance,
    average_window := 100,
    allocator := context.allocator,
) -> (res: ^Performance, err: mem.Allocator_Error) #optional_allocator_error {
    perf.average_window = average_window
    perf.delta_times = make([dynamic]time.Duration, allocator)
    return perf, nil
}

destroy_performance :: proc(perf: ^Performance) {
    delete(perf.delta_times)
}

frame_time :: proc(perf: ^Performance) -> f32 {
    return perf.frame_time
}

fps :: proc(perf: ^Performance) -> f32 {
    return 1.0 / perf.frame_time
}

update_performance :: proc(perf: ^Performance) {
    average_window := perf.average_window

    if average_window != perf.previous_average_window {
        perf.index = 0
        resize(&perf.delta_times, average_window)
    }

    if perf.index < len(perf.delta_times) {
        perf.delta_times[perf.index] = gui.delta_time_duration()
    }

    perf.index += 1
    if perf.index >= len(perf.delta_times) {
        perf.index = 0
    }

    perf.frame_time = 0

    for dt in perf.delta_times {
        perf.frame_time += f32(time.duration_seconds(dt))
    }

    perf.frame_time /= f32(average_window)
    perf.previous_average_window = average_window
}

// draw_performance :: proc(perf: ^Performance) {
//     fps_str := fmt.aprintf("Fps: %v", fps(perf))
//     defer delete(fps_str)
//     gui.fill_text_raw(fps_str, {0, 0})
// }