package gui

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:slice"
import "core:strings"
import "rect"

@(thread_local) _current_window: ^Window

Vec2 :: [2]f32
Rect :: rect.Rect

Tick :: time.Tick
Duration :: time.Duration

Window :: struct {
    update: proc(window: ^Window),
    tick_now: proc(window: ^Window) -> (tick: Tick, ok: bool),
    set_cursor_style: proc(window: ^Window, style: Cursor_Style) -> (ok: bool),
    get_clipboard: proc(window: ^Window) -> (data: string, ok: bool),
    set_clipboard: proc(window: ^Window, data: string) -> (ok: bool),
    measure_text: proc(window: ^Window, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, rune_index_to_glyph_index: ^map[int]int) -> (ok: bool),
    font_metrics: proc(window: ^Window, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(window: ^Window, command: Draw_Command),

    is_open: bool,
    tick: Tick,
    position: Vec2,
    size: Vec2,
    content_scale: Vec2,

    client_area_hovered: bool,
    global_mouse_position: Vec2,
    mouse_down: [Mouse_Button]bool,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_wheel: Vec2,
    mouse_repeat_duration: Duration,
    mouse_repeat_movement_tolerance: f32,
    mouse_repeat_start_position: Vec2,
    mouse_repeat_count: int,
    mouse_repeat_tick: Tick,

    key_down: [Keyboard_Key]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_repeats: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    text_input: strings.Builder,

    keyboard_focus: Id,
    mouse_hit: Id,
    mouse_hover: Id,
    previous_mouse_hover: Id,
    mouse_hover_captured: bool,

    position_offset_stack: [dynamic]Vec2,
    clip_rect_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    was_open: bool,
    previous_tick: Tick,
    previous_global_mouse_position: Vec2,

    temp_allocator: runtime.Allocator,
}

window_init :: proc(
    window: ^Window,
    position: Vec2,
    size: Vec2,
    temp_allocator := context.temp_allocator,
) -> runtime.Allocator_Error {
    _current_window = window
    window.temp_allocator = temp_allocator
    _remake_input_buffers(window) or_return
    window.position = position
    window.size = size
    window.mouse_repeat_duration = 300 * time.Millisecond
    window.mouse_repeat_movement_tolerance = 3
    window.content_scale = Vec2{1, 1}
    return nil
}

window_destroy :: proc(window: ^Window) {
    free_all(window.temp_allocator)
}

window_update :: proc(window: ^Window) {
    _current_window = window
    window.tick, _ = _tick_now(window)

    window.position_offset_stack = make([dynamic]Vec2, window.temp_allocator)
    window.clip_rect_stack = make([dynamic]Rect, window.temp_allocator)
    window.layer_stack = make([dynamic]Layer, window.temp_allocator)
    window.layers = make([dynamic]Layer, window.temp_allocator)

    begin_z_index(0, global = true)
    begin_position_offset({0, 0}, global = true)
    begin_clip({0, 0}, window.size, global = true, intersect = false)

    if window.update != nil {
        window->update()
    }

    end_clip()
    end_position_offset()
    end_z_index()

    assert(len(window.position_offset_stack) == 0)
    assert(len(window.clip_rect_stack) == 0)
    assert(len(window.layer_stack) == 0)

    slice.reverse(window.layers[:])
    slice.stable_sort_by(window.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    window.previous_mouse_hover = window.mouse_hover
    window.mouse_hover = 0
    window.mouse_hit = 0

    for layer in window.layers {
        for command in layer.draw_commands {
            render := window.render_draw_command
            if render != nil {
                render(window, command)
            }
        }

        mouse_hover_request := layer.final_mouse_hover_request
        if mouse_hover_request != 0 {
            window.mouse_hover = mouse_hover_request
            window.mouse_hit = mouse_hover_request
        }
    }

    window.mouse_wheel = {0, 0}
    window.was_open = window.is_open
    window.previous_tick = window.tick
    window.previous_global_mouse_position = window.global_mouse_position

    free_all(window.temp_allocator)
    _remake_input_buffers(window)
}

set_cursor_style :: proc(style: Cursor_Style) -> (ok: bool) {
    if _current_window.set_cursor_style == nil do return false
    return _current_window->set_cursor_style(style)
}

get_clipboard :: proc() -> (data: string, ok: bool) {
    if _current_window.get_clipboard == nil do return "", false
    return _current_window->get_clipboard()
}

set_clipboard :: proc(data: string) -> (ok: bool) {
    if _current_window.set_clipboard == nil do return false
    return _current_window->set_clipboard(data)
}

measure_text :: proc(text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, rune_index_to_glyph_index: ^map[int]int = nil) -> (ok: bool) {
    if _current_window.measure_text == nil do return false
    return _current_window->measure_text(text, font, glyphs, rune_index_to_glyph_index)
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics, ok: bool) {
    if _current_window.font_metrics == nil do return {}, false
    return _current_window->font_metrics(font)
}



_tick_now :: proc(window: ^Window) -> (tick: Tick, ok: bool) {
    if window.tick_now == nil do return {}, false
    return window->tick_now()
}

_remake_input_buffers :: proc(window: ^Window) -> runtime.Allocator_Error {
    window.mouse_presses = make([dynamic]Mouse_Button, window.temp_allocator) or_return
    window.mouse_releases = make([dynamic]Mouse_Button, window.temp_allocator) or_return
    window.key_presses = make([dynamic]Keyboard_Key, window.temp_allocator) or_return
    window.key_repeats = make([dynamic]Keyboard_Key, window.temp_allocator) or_return
    window.key_releases = make([dynamic]Keyboard_Key, window.temp_allocator) or_return
    strings.builder_init(&window.text_input, window.temp_allocator) or_return
    return nil
}