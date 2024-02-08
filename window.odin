package gui

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:slice"
import "core:strings"
import "rect"

@(thread_local) _current_window: ^Window

Id :: u64

get_id :: proc "contextless" () -> u64 {
    @(static) id: u64
    return 1 + intrinsics.atomic_add(&id, 1)
}

Vec2 :: [2]f32
Rect :: rect.Rect

Tick :: time.Tick
Duration :: time.Duration

Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
    Scroll,
}

Mouse_Button :: enum {
    Unknown,
    Left, Middle, Right,
    Extra_1, Extra_2,
}

Keyboard_Key :: enum {
    Unknown,
    A, B, C, D, E, F, G, H, I,
    J, K, L, M, N, O, P, Q, R,
    S, T, U, V, W, X, Y, Z,
    Key_1, Key_2, Key_3, Key_4, Key_5,
    Key_6, Key_7, Key_8, Key_9, Key_0,
    Pad_1, Pad_2, Pad_3, Pad_4, Pad_5,
    Pad_6, Pad_7, Pad_8, Pad_9, Pad_0,
    F1, F2, F3, F4, F5, F6, F7,
    F8, F9, F10, F11, F12,
    Backtick, Minus, Equal, Backspace,
    Tab, Caps_Lock, Enter, Left_Shift,
    Right_Shift, Left_Control, Right_Control,
    Left_Alt, Right_Alt, Left_Meta, Right_Meta,
    Left_Bracket, Right_Bracket, Space,
    Escape, Backslash, Semicolon, Apostrophe,
    Comma, Period, Slash, Scroll_Lock,
    Pause, Insert, End, Page_Up, Delete,
    Home, Page_Down, Left_Arrow, Right_Arrow,
    Down_Arrow, Up_Arrow, Num_Lock, Pad_Divide,
    Pad_Multiply, Pad_Subtract, Pad_Add, Pad_Enter,
    Pad_Decimal, Print_Screen,
}



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
    hover_captured: bool,

    offset_stack: [dynamic]Vec2,
    clip_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    was_open: bool,
    previous_tick: Tick,
    previous_global_mouse_position: Vec2,

    temp_allocator: runtime.Allocator,
}

init_window :: proc(
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

destroy_window :: proc(window: ^Window) {
    free_all(window.temp_allocator)
}

update_window :: proc(window: ^Window) {
    _current_window = window
    window.tick, _ = tick_now(window)

    window.offset_stack = make([dynamic]Vec2, window.temp_allocator)
    window.clip_stack = make([dynamic]Rect, window.temp_allocator)
    window.layer_stack = make([dynamic]Layer, window.temp_allocator)
    window.layers = make([dynamic]Layer, window.temp_allocator)

    begin_z_index(0, global = true)
    begin_offset({0, 0}, global = true)
    begin_clip({0, 0}, window.size, global = true, intersect = false)

    if window.update != nil {
        window->update()
    }

    end_clip()
    end_offset()
    end_z_index()

    assert(len(window.offset_stack) == 0)
    assert(len(window.clip_stack) == 0)
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



input_open :: proc(window: ^Window) {
    window.is_open = true
}

input_close :: proc(window: ^Window) {
    window.is_open = false
}

input_move :: proc(window: ^Window, position: Vec2) {
    window.position = position
}

input_resize :: proc(window: ^Window, size: Vec2) {
    window.size = size
}

input_mouse_enter :: proc(window: ^Window) {
    window.client_area_hovered = true
}

input_mouse_exit :: proc(window: ^Window) {
    window.client_area_hovered = false
}

input_mouse_move :: proc(window: ^Window, position: Vec2) {
    window.global_mouse_position = position
}

input_mouse_press :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = true

    tick_available := false
    previous_mouse_repeat_tick := window.mouse_repeat_tick
    window.mouse_repeat_tick, tick_available = tick_now(window)

    if tick_available {
        delta := time.tick_diff(previous_mouse_repeat_tick, window.mouse_repeat_tick)
        if delta <= window.mouse_repeat_duration {
            window.mouse_repeat_count += 1
        } else {
            window.mouse_repeat_count = 1
        }

        // This is just a simple x, y comparison, not true distance.
        movement := window.global_mouse_position - window.mouse_repeat_start_position
        if abs(movement.x) > window.mouse_repeat_movement_tolerance ||
           abs(movement.y) > window.mouse_repeat_movement_tolerance {
            window.mouse_repeat_count = 1
        }
    }

    if window.mouse_repeat_count == 1 {
        window.mouse_repeat_start_position = window.global_mouse_position
    }

    append(&window.mouse_presses, button)
}

input_mouse_release :: proc(window: ^Window, button: Mouse_Button) {
    window.mouse_down[button] = false
    append(&window.mouse_releases, button)
}

input_mouse_scroll :: proc(window: ^Window, amount: Vec2) {
    window.mouse_wheel = amount
}

input_key_press :: proc(window: ^Window, key: Keyboard_Key) {
    already_down := window.key_down[key]
    window.key_down[key] = true
    if !already_down {
        append(&window.key_presses, key)
    }
    append(&window.key_repeats, key)
}

input_key_release :: proc(window: ^Window, key: Keyboard_Key) {
    window.key_down[key] = false
    append(&window.key_releases, key)
}

input_text :: proc(window: ^Window, text: rune) {
    strings.write_rune(&window.text_input, text)
}

input_content_scale :: proc(window: ^Window, scale: Vec2) {
    window.content_scale = scale
}



temp_allocator :: proc() -> runtime.Allocator {
    return _current_window.temp_allocator
}

tick :: proc() -> time.Tick {
    return _current_window.tick
}

delta_time_duration :: proc() -> time.Duration {
    return time.tick_diff(_current_window.previous_tick, _current_window.tick)
}

delta_time :: proc() -> f32 {
    return f32(time.duration_seconds(time.tick_diff(_current_window.previous_tick, _current_window.tick)))
}

mouse_position :: proc() -> Vec2 {
    return _current_window.global_mouse_position - current_offset()
}

global_mouse_position :: proc() -> Vec2 {
    return _current_window.global_mouse_position
}

mouse_delta :: proc() -> Vec2 {
    return _current_window.global_mouse_position - _current_window.previous_global_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return _current_window.mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return _current_window.key_down[key]
}

mouse_wheel :: proc() -> Vec2 {
    return _current_window.mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return _current_window.mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(_current_window.mouse_presses[:], button)
}

mouse_repeat_count :: proc() -> int {
    return _current_window.mouse_repeat_count
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(_current_window.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(_current_window.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(_current_window.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    return slice.contains(_current_window.key_presses[:], key) ||
           repeating && slice.contains(_current_window.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(_current_window.key_releases[:], key)
}

any_key_pressed :: proc() -> bool {
    return len(_current_window.key_presses) > 0
}

any_key_released :: proc() -> bool {
    return len(_current_window.key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return _current_window.key_repeats[:]
    } else {
        return _current_window.key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return _current_window.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(_current_window.text_input)
}

content_scale :: proc() -> Vec2 {
    return _current_window.content_scale
}

pixel_size :: proc() -> Vec2 {
    return 1.0 / _current_window.content_scale
}



Layer :: struct {
    z_index: int,
    draw_commands: [dynamic]Draw_Command,
    final_mouse_hover_request: Id,
}

current_layer :: proc() -> ^Layer {
    return &_current_window.layer_stack[len(_current_window.layer_stack) - 1]
}

current_z_index :: proc() -> int {
    return current_layer().z_index
}

current_offset :: proc() -> Vec2 {
    return _current_window.offset_stack[len(_current_window.offset_stack) - 1]
}

current_clip_rect :: proc() -> Rect {
    clip := _current_window.clip_stack[len(_current_window.clip_stack) - 1]
    clip.position -= current_offset()
    return clip
}

mouse_hover :: proc() -> Id {
    return _current_window.mouse_hover
}

mouse_hover_entered :: proc() -> Id {
    if _current_window.mouse_hover != _current_window.previous_mouse_hover {
        return _current_window.mouse_hover
    } else {
        return 0
    }
}

mouse_hover_exited :: proc() -> Id {
    if _current_window.mouse_hover != _current_window.previous_mouse_hover {
        return _current_window.previous_mouse_hover
    } else {
        return 0
    }
}

mouse_hit :: proc() -> Id {
    return _current_window.mouse_hit
}

request_mouse_hover :: proc(id: Id) {
    current_layer().final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    _current_window.hover_captured = true
}

release_mouse_hover :: proc() {
    _current_window.hover_captured = false
}

set_keyboard_focus :: proc(id: Id) {
    _current_window.keyboard_focus = id
}

release_keyboard_focus :: proc() {
    _current_window.keyboard_focus = 0
}

begin_offset :: proc(offset: Vec2, global := false) {
    if global {
        append(&_current_window.offset_stack, offset)
    } else {
        append(&_current_window.offset_stack, current_offset() + offset)
    }
}

end_offset :: proc() {
    pop(&_current_window.offset_stack)
}

@(deferred_none=end_offset)
scoped_offset :: proc(offset: Vec2, global := false) {
    begin_offset(offset, global = global)
}

begin_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    r := Rect{position = position, size = size}

    if !global {
        r.position += current_offset()
    }

    if intersect {
        r = rect.intersection(r, _current_window.clip_stack[len(_current_window.clip_stack) - 1])
    }

    append(&_current_window.clip_stack, r)
    append(&current_layer().draw_commands, Clip_Drawing_Command{
        position = r.position,
        size = r.size,
    })
}

end_clip :: proc() {
    pop(&_current_window.clip_stack)

    if len(_current_window.clip_stack) == 0 {
        return
    }

    clip_rect := _current_window.clip_stack[len(_current_window.clip_stack) - 1]
    append(&current_layer().draw_commands, Clip_Drawing_Command{
        position = clip_rect.position,
        size = clip_rect.size,
    })
}

@(deferred_none=end_clip)
scoped_clip :: proc(position, size: Vec2, global := false, intersect := true) {
    begin_clip(position, size, global = global, intersect = intersect)
}

begin_z_index :: proc(z_index: int, global := false) {
    layer: Layer
    layer.draw_commands = make([dynamic]Draw_Command, _current_window.temp_allocator)
    if global do layer.z_index = z_index
    else do layer.z_index = current_z_index() + z_index
    append(&_current_window.layer_stack, layer)
}

end_z_index :: proc() {
    layer := pop(&_current_window.layer_stack)
    append(&_current_window.layers, layer)
}

@(deferred_none=end_z_index)
scoped_z_index :: proc(z_index: int, global := false) {
    begin_z_index(z_index, global = global)
}

hit_test :: proc(position, size, target: Vec2) -> bool {
    return rect.contains({position, size}, target, include_borders = false) &&
           rect.contains(current_clip_rect(), target, include_borders = false)
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

tick_now :: proc(window: ^Window) -> (tick: Tick, ok: bool) {
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