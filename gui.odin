package main

import "base:runtime"
import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:time"
import "core:slice"
import "core:strings"
import gl "vendor:OpenGL"
import cte "core:text/edit"
import osw "os_window"

@(thread_local) _window_stack: [dynamic]^Window

Vector2 :: [2]f32
Id :: u64

get_id :: proc "contextless" () -> Id {
    @(static) id: Id
    return 1 + intrinsics.atomic_add(&id, 1)
}

Mouse_Cursor_Style :: osw.Mouse_Cursor_Style
Mouse_Button :: osw.Mouse_Button
Keyboard_Key :: osw.Keyboard_Key

poll_window_events :: osw.poll_events
set_window_focus :: osw.set_focus
set_window_focus_native :: osw.set_focus_native

Gui_Event :: osw.Event
Gui_Event_Close :: osw.Event_Close
Gui_Event_Gain_Focus :: osw.Event_Gain_Focus
Gui_Event_Lose_Focus :: osw.Event_Lose_Focus
Gui_Event_Loop_Timer :: osw.Event_Loop_Timer
Gui_Event_Move :: osw.Event_Move
Gui_Event_Resize :: osw.Event_Resize
Gui_Event_Mouse_Enter :: osw.Event_Mouse_Enter
Gui_Event_Mouse_Exit :: osw.Event_Mouse_Exit
Gui_Event_Mouse_Move :: osw.Event_Mouse_Move
Gui_Event_Mouse_Press :: osw.Event_Mouse_Press
Gui_Event_Mouse_Release :: osw.Event_Mouse_Release
Gui_Event_Mouse_Scroll :: osw.Event_Mouse_Scroll
Gui_Event_Key_Press :: osw.Event_Key_Press
Gui_Event_Key_Release :: osw.Event_Key_Release
Gui_Event_Rune_Input :: osw.Event_Rune_Input

Window_Child_Kind :: osw.Child_Kind

//==========================================================================
// Input
//==========================================================================

is_first_frame_ever :: proc() -> bool {
    return current_window().is_first_frame_ever
}

delta_time :: proc() -> f32 {
    return current_window().delta_time
}

mouse_position :: proc() -> (res: Vector2) {
    window := current_window()
    res = window.mouse_position
    res -= global_offset()
    return
}

global_mouse_position :: proc() -> (res: Vector2) {
    window := current_window()
    res = window.mouse_position
    return
}

screen_mouse_position :: proc() -> (res: Vector2) {
    window := current_window()
    res = window.mouse_position - window.position
    return
}

mouse_delta :: proc() -> (res: Vector2) {
    window := current_window()
    res = window.mouse_position - window.previous_mouse_position
    return
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return current_window().mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return current_window().key_down[key]
}

mouse_wheel :: proc() -> Vector2 {
    return current_window().mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return mouse_wheel() != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(current_window().mouse_presses[:], button)
}

mouse_repeat_count :: proc(button: Mouse_Button) -> int {
    return current_window().mouse_repeat_counts[button]
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(current_window().mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(current_window().mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(current_window().mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key) -> bool {
    window := current_window()
    return window.key_down[key] && !window.previous_key_down[key]
}

key_released :: proc(key: Keyboard_Key, respect_focus := true) -> bool {
    window := current_window()
    return !window.key_down[key] && window.previous_key_down[key]
}

any_key_pressed :: proc(respect_focus := true, repeat := false) -> bool {
    for key in Keyboard_Key {
        if key_pressed(key) do return true
    }
    return false
}

any_key_released :: proc() -> bool {
    for key in Keyboard_Key {
        if key_released(key) do return true
    }
    return false
}

key_presses :: proc(repeat := false) -> []Keyboard_Key {
    window := current_window()
    if repeat {
        return window.key_repeats[:]
    } else {
        return window.key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return current_window().key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(current_window().text_input)
}

clipboard :: proc(allocator := context.allocator) -> string {
    return osw.clipboard(current_window(), allocator)
}

set_clipboard :: proc(str: string) {
    osw.set_clipboard(current_window(), str)
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) {
    window := current_window()
    if window == nil do return
    window.mouse_cursor_style = style
}

_window_event_proc :: proc(window: ^osw.Window, msg: osw.Event) {
    window := cast(^Window)window

    #partial switch msg in msg {
    case osw.Event_Close:
        window.close_requested = true

    case osw.Event_Gain_Focus:
        window.is_focused = true

    case osw.Event_Lose_Focus:
        window.is_focused = false
        for button in Mouse_Button {
            if window.mouse_down[button] {
                _window_event_proc(window, osw.Event_Mouse_Release{button = button})
            }
        }

    case osw.Event_Move:
        position := Vector2{f32(msg.x), f32(msg.y)}
        window.position = position
        window.actual_rectangle.position = position

    case osw.Event_Resize:
        size := Vector2{f32(msg.width), f32(msg.height)}
        window.size = size
        window.actual_rectangle.size = size

    case osw.Event_Mouse_Enter:
        window.is_mouse_hovered = true

    case osw.Event_Mouse_Exit:
        window.is_mouse_hovered = false

    case osw.Event_Mouse_Move:
        window.mouse_position = {f32(msg.x), f32(msg.y)}

    case osw.Event_Mouse_Press:
        button := msg.button

        window.mouse_down[button] = true
        previous_mouse_repeat_tick := window.mouse_repeat_ticks[button]

        window.mouse_repeat_ticks[button] = time.tick_now()

        delta := time.tick_diff(previous_mouse_repeat_tick, window.mouse_repeat_ticks[button])
        if delta <= 300 * time.Millisecond {
            window.mouse_repeat_counts[button] += 1
        } else {
            window.mouse_repeat_counts[button] = 1
        }

        TOLERANCE :: 3
        movement := window.mouse_position - window.mouse_repeat_start_position
        if abs(movement.x) > TOLERANCE || abs(movement.y) > TOLERANCE {
            window.mouse_repeat_counts[button] = 1
        }

        if window.mouse_repeat_counts[button] == 1 {
            window.mouse_repeat_start_position = window.mouse_position
        }

        append(&window.mouse_presses, button)

    case osw.Event_Mouse_Release:
        button := msg.button
        window.mouse_down[button] = false
        append(&window.mouse_releases, button)

    case osw.Event_Mouse_Scroll:
        window.mouse_wheel = {f32(msg.x), f32(msg.y)}

    case osw.Event_Key_Press:
        key := msg.key
        if !window.key_toggle[key] {
            append(&window.key_presses, key)
        }
        append(&window.key_repeats, key)
        window.key_toggle[key] = true

    case osw.Event_Key_Release:
        key := msg.key
        append(&window.key_releases, key)
        window.key_toggle[key] = false

    case osw.Event_Rune_Input:
        skip := false
        switch msg.r {
        case 0 ..< 32, 127: skip = true
        }
        if !skip {
            strings.write_rune(&window.text_input, msg.r)
        }
    }

    gui_event(window, msg)
}

//==========================================================================
// Window
//==========================================================================

Window :: struct {
    using backend: osw.Window,
    vg_ctx: Vg_Context,

    using rectangle: Rectangle,
    actual_rectangle: Rectangle,

    mouse_position: Vector2,
    previous_mouse_position: Vector2,
    mouse_down: [Mouse_Button]bool,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_wheel: Vector2,
    mouse_repeat_start_position: Vector2,
    mouse_repeat_ticks: [Mouse_Button]time.Tick,
    mouse_repeat_counts: [Mouse_Button]int,

    key_down: [Keyboard_Key]bool,
    previous_key_down: [Keyboard_Key]bool,
    key_toggle: [Keyboard_Key]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_repeats: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    text_input: strings.Builder,

    mouse_hit: Id,
    mouse_hover: Id,
    previous_mouse_hover: Id,
    mouse_hover_capture: Id,
    final_mouse_hover_request: Id,

    title: string,
    child_kind: Window_Child_Kind,

    is_open: bool,
    opened: bool,
    is_visible: bool,
    open_requested: bool,
    close_requested: bool,
    is_focused: bool,
    is_mouse_hovered: bool,
    is_first_frame_ever: bool,

    delta_time: f32,
    previous_tick: time.Tick,

    content_scale: Vector2,

    loaded_fonts: map[string]struct{},

    child_windows: [dynamic]^Window,

    mouse_cursor_style: Mouse_Cursor_Style,
    previous_mouse_cursor_style: Mouse_Cursor_Style,

    global_clip_rectangle_stack: [dynamic]Rectangle,
    local_offset_stack: [dynamic]Vector2,
    global_offset_stack: [dynamic]Vector2,
}

current_window :: proc() -> ^Window {
    if len(_window_stack) <= 0 do return nil
    return _window_stack[len(_window_stack) - 1]
}

window_init :: proc(window: ^Window, rectangle: Rectangle) {
    window.content_scale = {1, 1}
    window.rectangle = rectangle
    window.is_first_frame_ever = true
    window.event_proc = _window_event_proc
}

window_destroy :: proc(window: ^Window) {
    _window_do_close(window)
    delete(window.child_windows)
    delete(window.loaded_fonts)
    delete(window.mouse_presses)
    delete(window.mouse_releases)
    delete(window.key_presses)
    delete(window.key_repeats)
    delete(window.key_releases)
    strings.builder_destroy(&window.text_input)
}

window_begin :: proc(window: ^Window) -> bool {
    parent := current_window()

    append(&_window_stack, window)

    window.global_clip_rectangle_stack = make([dynamic]Rectangle, context.temp_allocator)
    window.local_offset_stack = make([dynamic]Vector2, context.temp_allocator)
    window.global_offset_stack = make([dynamic]Vector2, context.temp_allocator)

    clear(&window.child_windows)

    if window.is_first_frame_ever {
        osw.set_mouse_cursor_style(window, window.mouse_cursor_style)
        window.actual_rectangle = window.rectangle
        window.previous_mouse_position = window.mouse_position
        window.previous_tick = time.tick_now()
    }

    current_tick := time.tick_now()
    window.delta_time = f32(time.duration_seconds(time.tick_diff(window.previous_tick, current_tick)))
    window.previous_tick = current_tick

    if window.is_open {
        window.open_requested = false
        osw.activate_context(window)
        if parent != nil {
            append(&parent.child_windows, window)
        }
        window.mouse_cursor_style = .Arrow
        for key in Keyboard_Key {
            window.key_down[key] = osw.poll_key_state(key)
        }
        vg_begin_frame(&window.vg_ctx, window.size, window.content_scale.x)
    }

    return window.is_open
}

window_end :: proc() {
    window := current_window()

    if window.is_open {
        vg_end_frame(&window.vg_ctx)
    }

    if window.is_open && window.mouse_cursor_style != window.previous_mouse_cursor_style {
        osw.set_mouse_cursor_style(window, window.mouse_cursor_style)
    }
    window.previous_mouse_cursor_style = window.mouse_cursor_style

    window.previous_mouse_hover = window.mouse_hover
    window.mouse_hit = window.final_mouse_hover_request

    if window.mouse_hover_capture != 0 {
        window.mouse_hover = window.mouse_hover_capture
    } else {
        window.mouse_hover = window.final_mouse_hover_request
    }

    window.final_mouse_hover_request = 0

    window.mouse_wheel = {0, 0}
    window.previous_mouse_position = window.mouse_position

    window.is_first_frame_ever = false
    window.opened = false

    for key in Keyboard_Key {
        window.previous_key_down[key] = window.key_down[key]
    }
    clear(&window.mouse_presses)
    clear(&window.mouse_releases)
    clear(&window.key_presses)
    clear(&window.key_repeats)
    clear(&window.key_releases)
    strings.builder_reset(&window.text_input)

    if window.is_open && window.position != window.actual_rectangle.position {
        osw.set_position(window, int(window.position.x), int(window.position.y))
    }

    if window.is_open && window.size != window.actual_rectangle.size {
        window.actual_rectangle.size = window.size
        osw.set_size(window, int(window.size.x), int(window.size.y))
    }

    if window.open_requested {
        _window_do_open(window)
    }
    if window.close_requested {
        _window_do_close(window)
    }

    if window.is_open {
        osw.swap_buffers(window)
    }

    pop(&_window_stack)

    parent := current_window()
    if parent != nil {
        osw.activate_context(parent)
    }
}

@(deferred_none=window_end)
window_update :: proc(window: ^Window) -> bool {
    return window_begin(window)
}

_window_do_open :: proc(window: ^Window) {
    if window.is_open do return
    osw.open(window,
        window.title,
        int(window.x), int(window.y),
        int(window.size.x), int(window.size.y),
        window.parent_handle,
        window.child_kind,
    )
    window.is_open = true
    window.opened = true
    window.open_requested = false
    osw.show(window)
    vg_init(&window.vg_ctx)
}

_window_do_close :: proc(window: ^Window) {
    if !window.is_open do return

    for child in window.child_windows {
        _window_do_close(child)
    }

    vg_destroy(&window.vg_ctx)
    osw.close(window)
    clear(&window.loaded_fonts)
    window.is_open = false
    window.close_requested = false
}

//==========================================================================
// Color
//==========================================================================

Color :: [4]f32

color_rgb :: proc(r, g, b: u8) -> Color {
    return {
        f32(r) / 255,
        f32(g) / 255,
        f32(b) / 255,
        1.0,
    }
}

color_rgba :: proc(r, g, b, a: u8) -> Color {
    return {
        f32(r) / 255,
        f32(g) / 255,
        f32(b) / 255,
        f32(a) / 255,
    }
}

color_lerp :: proc(a, b: Color, weight: f32) -> Color {
    color := a
    color.r += (weight * (b.r - color.r))
    color.g += (weight * (b.g - color.g))
    color.b += (weight * (b.b - color.b))
    color.a += (weight * (b.a - color.a))
    return color
}

color_darken :: proc(c: Color, amount: f32) -> Color {
    color := c
    color.r *= 1.0 - amount
    color.g *= 1.0 - amount
    color.b *= 1.0 - amount
    return color
}

color_lighten :: proc(c: Color, amount: f32) -> Color {
    color := c
    color.r += (1.0 - color.r) * amount
    color.g += (1.0 - color.g) * amount
    color.b += (1.0 - color.b) * amount
    return color
}

//==========================================================================
// Vector Graphics
//==========================================================================

Font :: struct {
    name: string,
    size: int,
    data: []byte,
}

Font_Metrics :: struct {
    ascender: f32,
    descender: f32,
    line_height: f32,
}

Text_Glyph :: struct {
    byte_index: int,
    position: f32,
    width: f32,
    kerning: f32,
}

Draw_Command :: union {
    Fill_Path_Command,
    Fill_String_Command,
    Set_Clip_Rectangle_Command,
    Box_Shadow_Command,
}

Fill_Path_Command :: struct {
    path: Path,
    position: Vector2,
    color: Color,
}

Fill_String_Command :: struct {
    text: string,
    position: Vector2,
    font: Font,
    color: Color,
}

Set_Clip_Rectangle_Command :: struct {
    global_clip_rectangle: Rectangle,
}

// Temporary until I feel like tackling path blurring.
Box_Shadow_Command :: struct {
    rectangle: Rectangle,
    corner_radius: f32,
    feather: f32,
    inner_color: Color,
    outer_color: Color,
}

clear_background :: proc(color: Color) {
    size := current_window().size
    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.ClearColor(color.r, color.g, color.b, color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)
}

pixel_size :: proc() -> Vector2 {
    return 1.0 / current_window().content_scale
}

pixel_snapped :: proc{
    vector2_pixel_snapped,
    rectangle_pixel_snapped,
}

vector2_pixel_snapped :: proc(position: Vector2) -> Vector2 {
    pixel := pixel_size()
    return {
        math.round(position.x / pixel.x) * pixel.x,
        math.round(position.y / pixel.y) * pixel.y,
    }
}

rectangle_pixel_snapped :: proc(rectangle: Rectangle) -> Rectangle {
    return rectangle_snapped(rectangle, pixel_size())
}

fill_string :: proc(str: string, position: Vector2, font: Font, color: Color) {
    window := current_window()
    _load_font_if_not_loaded(window, font)
    vg_render_draw_command(&window.vg_ctx, Fill_String_Command{str, global_offset() + position, font, color})
}

fill_string_aligned :: proc(str: string, rectangle: Rectangle, font: Font, color: Color, alignment := Vector2{}) {
    size := measure_string(str, font)
    position := pixel_snapped(rectangle.position + (rectangle.size - size) * alignment)
    fill_string(str, position, font, color)
}

fill_path :: proc(path: Path, color: Color) {
    window := current_window()
    vg_render_draw_command(&window.vg_ctx, Fill_Path_Command{path, global_offset(), color})
}

set_clip_rectangle :: proc(rectangle: Rectangle) {
    window := current_window()
    rectangle := rectangle
    rectangle.position += global_offset()
    vg_render_draw_command(&window.vg_ctx, Set_Clip_Rectangle_Command{rectangle})
}

box_shadow :: proc(
    rectangle: Rectangle,
    corner_radius, feather: f32,
    inner_color, outer_color: Color,
) {
    window := current_window()
    rectangle := rectangle
    rectangle.position += global_offset()
    vg_render_draw_command(&window.vg_ctx, Box_Shadow_Command{rectangle, corner_radius, feather, inner_color, outer_color})
}

measure_string :: proc(str: string, font: Font) -> (size: Vector2) {
    glyphs := make([dynamic]Text_Glyph, context.temp_allocator)
    measure_glyphs(str, font, &glyphs)
    size.y = font_height(font)
    size.x = 0
    if len(glyphs) > 0 {
        first := glyphs[0]
        last := glyphs[len(glyphs) - 1]
        size.x = last.position + last.width - first.position
    }
    return
}

measure_glyphs :: proc(str: string, font: Font, glyphs: ^[dynamic]Text_Glyph) {
    window := current_window()
    _load_font_if_not_loaded(window, font)
    vg_measure_glyphs(&window.vg_ctx, str, font, glyphs)
}

font_metrics :: proc(font: Font) -> Font_Metrics {
    window := current_window()
    _load_font_if_not_loaded(window, font)
    return vg_font_metrics(&window.vg_ctx, font)
}

font_height :: proc(font: Font) -> f32 {
    metrics := font_metrics(font)
    return metrics.ascender - metrics.descender
}

fill_rectangle :: proc(rectangle: Rectangle, color: Color) {
    path := temp_path()
    path_rectangle(&path, rectangle)
    fill_path(path, color)
}

outline_rectangle :: proc(rectangle: Rectangle, thickness: f32, color: Color) {
    path := temp_path()
    path_rectangle(&path, rectangle)
    path_rectangle(&path, rectangle_expanded(rectangle, -thickness), true)
    fill_path(path, color)
}

pixel_outline_rectangle :: proc(rectangle: Rectangle, color: Color) {
    outline_rectangle(rectangle, pixel_size().x, color)
}

fill_rounded_rectangle :: proc(rectangle: Rectangle, radius: f32, color: Color) {
    path := temp_path()
    path_rounded_rectangle(&path, rectangle, radius)
    fill_path(path, color)
}

fill_circle :: proc(center: Vector2, radius: f32, color: Color) {
    path := temp_path()
    path_circle(&path, center, radius)
    fill_path(path, color)
}

outline_rounded_rectangle :: proc(rectangle: Rectangle, radius, thickness: f32, color: Color) {
    path := temp_path()
    path_rounded_rectangle(&path, rectangle, radius)
    path_rounded_rectangle(&path, rectangle_expanded(rectangle, -thickness), radius, true)
    fill_path(path, color)
}

pixel_outline_rounded_rectangle :: proc(rectangle: Rectangle, radius: f32, color: Color) {
    outline_rounded_rectangle(rectangle, radius, pixel_size().x, color)
}

_load_font_if_not_loaded :: proc(window: ^Window, font: Font) {
    if font.name not_in window.loaded_fonts {
        vg_load_font(&window.vg_ctx, font)
        window.loaded_fonts[font.name] = {}
    }
}

//==========================================================================
// Tools
//==========================================================================

mouse_hover :: proc() -> Id {
    return current_window().mouse_hover
}

mouse_hover_entered :: proc() -> Id {
    window := current_window()
    if window.mouse_hover != window.previous_mouse_hover {
        return window.mouse_hover
    } else {
        return 0
    }
}

mouse_hover_exited :: proc() -> Id {
    window := current_window()
    if window.mouse_hover != window.previous_mouse_hover {
        return window.previous_mouse_hover
    } else {
        return 0
    }
}

mouse_hit :: proc() -> Id {
    return current_window().mouse_hit
}

request_mouse_hover :: proc(id: Id) {
    current_window().final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    window := current_window()
    window.mouse_hover_capture = window.final_mouse_hover_request
}

release_mouse_hover :: proc() {
    current_window().mouse_hover_capture = 0
}

hit_test :: proc(rectangle: Rectangle, target: Vector2) -> bool {
    return rectangle_encloses(rectangle, target, include_borders = false) &&
           rectangle_encloses(clip_rectangle(), target, include_borders = false)
}

mouse_hit_test :: proc(rectangle: Rectangle) -> bool {
    return hit_test(rectangle, mouse_position())
}

clip_test :: proc(target: Vector2) -> bool {
    return rectangle_encloses(clip_rectangle(), target, include_borders = false)
}

mouse_clip_test :: proc() -> bool {
    return clip_test(mouse_position())
}

offset :: proc() -> Vector2 {
    window := current_window()
    if len(window.local_offset_stack) <= 0 do return {0, 0}
    return window.local_offset_stack[len(window.local_offset_stack) - 1]
}

global_offset :: proc() -> Vector2 {
    window := current_window()
    if len(window.global_offset_stack) <= 0 do return {0, 0}
    return window.global_offset_stack[len(window.global_offset_stack) - 1]
}

// Set in local coordinates
begin_offset :: proc(offset: Vector2) {
    window := current_window()
    append(&window.local_offset_stack, offset)
    append(&window.global_offset_stack, global_offset() + offset)
}

end_offset :: proc() {
    window := current_window()
    pop(&window.local_offset_stack)
    pop(&window.global_offset_stack)
}

@(deferred_none=end_offset)
scoped_offset :: proc(offset: Vector2) {
    begin_offset(offset)
}

clip_rectangle :: proc() -> Rectangle {
    window := current_window()
    if len(window.global_clip_rectangle_stack) <= 0 do return {-global_offset(), window.size}
    global_rect := window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]
    global_rect.position -= global_offset()
    return global_rect
}

global_clip_rectangle :: proc() -> Rectangle {
    window := current_window()
    if len(window.global_clip_rectangle_stack) <= 0 do return {{0, 0}, window.size}
    return window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]
}

// Set in local coordinates
begin_clip :: proc(rectangle: Rectangle, intersect := true) {
    window := current_window()

    offset := global_offset()
    global_rect := Rectangle{offset + rectangle.position, rectangle.size}

    if intersect && len(window.global_clip_rectangle_stack) > 0 {
        global_rect = rectangle_intersection(global_rect, window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1])
    }

    append(&window.global_clip_rectangle_stack, global_rect)
    vg_render_draw_command(&window.vg_ctx, Set_Clip_Rectangle_Command{global_rect})
}

end_clip :: proc() {
    window := current_window()

    pop(&window.global_clip_rectangle_stack)

    if len(window.global_clip_rectangle_stack) <= 0 {
        vg_render_draw_command(&window.vg_ctx, Set_Clip_Rectangle_Command{{{0, 0}, window.size}})
        return
    }

    global_rect := window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]

    vg_render_draw_command(&window.vg_ctx, Set_Clip_Rectangle_Command{global_rect})
}

@(deferred_none=end_clip)
scoped_clip :: proc(rectangle: Rectangle, intersect := true) {
    begin_clip(rectangle, intersect = intersect)
}

//==========================================================================
// Rectangle
//==========================================================================

Rectangle :: struct {
    using position: Vector2,
    size: Vector2,
}

rectangle_expanded :: proc(rectangle: Rectangle, amount: Vector2) -> Rectangle {
    return {
        position = {
            min(rectangle.position.x + rectangle.size.x * 0.5, rectangle.position.x - amount.x),
            min(rectangle.position.y + rectangle.size.y * 0.5, rectangle.position.y - amount.y),
        },
        size = {
            max(0, rectangle.size.x + amount.x * 2),
            max(0, rectangle.size.y + amount.y * 2),
        },
    }
}

rectangle_expand :: proc(rectangle: ^Rectangle, amount: Vector2) {
    rectangle^ = rectangle_expanded(rectangle^, amount)
}

rectangle_padded :: proc(rectangle: Rectangle, amount: Vector2) -> Rectangle {
    return rectangle_expanded(rectangle, -amount)
}

rectangle_pad :: proc(rectangle: ^Rectangle, amount: Vector2) {
    rectangle^ = rectangle_padded(rectangle^, amount)
}

rectangle_snapped :: proc(rectangle: Rectangle, increment: Vector2) -> Rectangle {
    return {
        {
            math.round(rectangle.position.x / increment.x) * increment.x,
            math.round(rectangle.position.y / increment.y) * increment.y,
        },
        {
            math.round(rectangle.size.x / increment.x) * increment.x,
            math.round(rectangle.size.y / increment.y) * increment.y,
        },
    }
}

rectangle_snap :: proc(rectangle: ^Rectangle, increment: Vector2) {
    rectangle^ = rectangle_snapped(rectangle^, increment)
}

rectangle_intersection :: proc(a, b: Rectangle) -> Rectangle {
    if a.size.x < 0 || a.size.y < 0 || b.size.x < 0 || b.size.y < 0 {
        return {}
    }

    x1 := max(a.position.x, b.position.x)
    y1 := max(a.position.y, b.position.y)
    x2 := min(a.position.x + a.size.x, b.position.x + b.size.x)
    y2 := min(a.position.y + a.size.y, b.position.y + b.size.y)

    if x2 < x1 {
        x2 = x1
    }
    if y2 < y1 {
        y2 = y1
    }

    return {{x1, y1}, {x2 - x1, y2 - y1}}
}

rectangle_intersects :: proc(a, b: Rectangle, include_borders := false) -> bool {
    if a.size.x < 0 || a.size.y < 0 || b.size.x < 0 || b.size.y < 0 {
        return false
    }
    if include_borders {
        if a.position.x > b.position.x + b.size.x {
            return false
        }
        if a.position.x + a.size.x < b.position.x {
            return false
        }
        if a.position.y > b.position.y + b.size.y {
            return false
        }
        if a.position.y + a.size.y < b.position.y {
            return false
        }
    } else {
        if a.position.x >= b.position.x + b.size.x {
            return false
        }
        if a.position.x + a.size.x <= b.position.x {
            return false
        }
        if a.position.y >= b.position.y + b.size.y {
            return false
        }
        if a.position.y + a.size.y <= b.position.y {
            return false
        }
    }

    return true
}

rectangle_encloses :: proc{
    rectangle_encloses_rect,
    rectangle_encloses_vector2,
}

rectangle_encloses_rect :: proc(a, b: Rectangle, include_borders := false) -> bool {
    if a.size.x < 0 || a.size.y < 0 || b.size.x < 0 || b.size.y < 0 {
        return false
    }
    if include_borders {
        return b.position.x >= a.position.x &&
               b.position.y >= a.position.y &&
               b.position.x + b.size.x <= a.position.x + a.size.x &&
               b.position.y + b.size.y <= a.position.y + a.size.y
    } else {
        return b.position.x > a.position.x &&
               b.position.y > a.position.y &&
               b.position.x + b.size.x < a.position.x + a.size.x &&
               b.position.y + b.size.y < a.position.y + a.size.y
    }
}

rectangle_encloses_vector2 :: proc(a: Rectangle, b: Vector2, include_borders := false) -> bool {
    if a.size.x < 0 || a.size.y < 0 {
        return false
    }
    if include_borders {
        return b.x >= a.position.x && b.x <= a.position.x + a.size.x &&
               b.y >= a.position.y && b.y <= a.position.y + a.size.y
    } else {
        return b.x > a.position.x && b.x < a.position.x + a.size.x &&
               b.y > a.position.y && b.y < a.position.y + a.size.y
    }
}

//==========================================================================
// Path
//==========================================================================

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
    path_init(&res, context.temp_allocator)
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

//==========================================================================
// Nanovg Implementation
//==========================================================================

import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

Vg_Context :: struct {
    nvg_ctx: ^nvg.Context,
}

vg_init :: proc(ctx: ^Vg_Context) {
    ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

vg_destroy :: proc(ctx: ^Vg_Context) {
    nvg_gl.Destroy(ctx.nvg_ctx)
    ctx.nvg_ctx = nil
}

vg_begin_frame :: proc(ctx: ^Vg_Context, size: Vector2, content_scale: f32) {
    nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, content_scale)
}

vg_end_frame :: proc(ctx: ^Vg_Context) {
    nvg.EndFrame(ctx.nvg_ctx)
}

vg_load_font :: proc(ctx: ^Vg_Context, font: Font) {
    if len(font.data) <= 0 do return
    if nvg.CreateFontMem(ctx.nvg_ctx, font.name, font.data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
    }
}

vg_measure_glyphs :: proc(ctx: ^Vg_Context, str: string, font: Font, glyphs: ^[dynamic]Text_Glyph) {
    nvg_ctx := ctx.nvg_ctx

    clear(glyphs)

    if len(str) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(str), context.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, str, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        glyphs[i] = Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }
}

vg_font_metrics :: proc(ctx: ^Vg_Context, font: Font) -> (metrics: Font_Metrics) {
    nvg_ctx := ctx.nvg_ctx
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)
    return
}

vg_render_draw_command :: proc(ctx: ^Vg_Context, command: Draw_Command) {
    nvg_ctx := ctx.nvg_ctx

    switch cmd in command {
    case Fill_Path_Command:
        nvg.Save(nvg_ctx)

        nvg.Translate(nvg_ctx, cmd.position.x, cmd.position.y)
        nvg.BeginPath(nvg_ctx)

        for sub_path in cmd.path.sub_paths {
            nvg.MoveTo(nvg_ctx, sub_path.points[0].x, sub_path.points[0].y)

            for i := 1; i < len(sub_path.points); i += 3 {
                c1 := sub_path.points[i]
                c2 := sub_path.points[i + 1]
                point := sub_path.points[i + 2]
                nvg.BezierTo(nvg_ctx,
                    c1.x, c1.y,
                    c2.x, c2.y,
                    point.x, point.y,
                )
            }

            if sub_path.is_closed {
                nvg.ClosePath(nvg_ctx)
                if sub_path.is_hole {
                    nvg.PathWinding(nvg_ctx, .CW)
                }
            }
        }

        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Fill(nvg_ctx)

        nvg.Restore(nvg_ctx)

    case Fill_String_Command:
        nvg.Save(nvg_ctx)
        position := pixel_snapped(cmd.position)
        nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
        nvg.FontFace(nvg_ctx, cmd.font.name)
        nvg.FontSize(nvg_ctx, f32(cmd.font.size))
        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Text(nvg_ctx, position.x, position.y, cmd.text)
        nvg.Restore(nvg_ctx)

    case Set_Clip_Rectangle_Command:
        rect := pixel_snapped(cmd.global_clip_rectangle)
        nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))

    case Box_Shadow_Command:
        nvg.Save(nvg_ctx)
        rect := cmd.rectangle
        paint := nvg.BoxGradient(
            rect.x, rect.y,
            rect.size.x, rect.size.y,
            cmd.corner_radius,
            cmd.feather,
            cmd.inner_color,
            cmd.outer_color,
        )
        nvg.BeginPath(nvg_ctx)
        nvg.Rect(nvg_ctx,
            rect.x - cmd.feather, rect.y - cmd.feather,
            rect.size.x + cmd.feather * 2, rect.size.y + cmd.feather * 2,
        )
        nvg.FillPaint(nvg_ctx, paint)
        nvg.Fill(nvg_ctx)
        nvg.Restore(nvg_ctx)
    }
}

//==========================================================================
// Button
//==========================================================================

Button :: struct {
    id: Id,
    is_down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

button_base_init :: proc(button: ^Button) {
    button.id = get_id()
}

button_base_update :: proc(
    button: ^Button,
    rectangle: Rectangle,
    press, release: bool,
) {
    button.pressed = false
    button.released = false
    button.clicked = false

    if mouse_hit_test(rectangle) {
        request_mouse_hover(button.id)
    }

    if !button.is_down && press && mouse_hover() == button.id {
        capture_mouse_hover()
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        release_mouse_hover()
        button.is_down = false
        button.released = true
        if mouse_hit() == button.id {
            button.is_down = false
            button.clicked = true
        }
    }
}

invisible_button_update :: proc(
    button: ^Button,
    rectangle: Rectangle,
    mouse_button := Mouse_Button.Left
) {
    button_base_update(
        button,
        rectangle,
        mouse_pressed(mouse_button),
        mouse_released(mouse_button),
    )
}

button_update :: proc(
    button: ^Button,
    rectangle: Rectangle,
    color: Color,
    mouse_button := Mouse_Button.Left
) {
    invisible_button_update(button, rectangle, mouse_button)

    path := temp_path()
    path_rectangle(&path, rectangle)

    fill_path(path, color)
    if button.is_down {
        fill_path(path, {0, 0, 0, 0.2})
    } else if mouse_hover() == button.id {
        fill_path(path, {1, 1, 1, 0.05})
    }
}

//==========================================================================
// Slider
//==========================================================================

Slider :: struct {
    id: Id,
    held: bool,
    value_when_grabbed: f32,
    global_mouse_position_when_grabbed: Vector2,
}

slider_init :: proc(slider: ^Slider) {
    slider.id = get_id()
}

slider_update :: proc(
    slider: ^Slider,
    value: ^f32,
    rectangle: Rectangle,
    min_value := f32(0),
    max_value := f32(1),
    mouse_button := Mouse_Button.Left,
    precision_key := Keyboard_Key.Left_Shift,
) {
    HANDLE_LENGTH :: 16

    if mouse_hit_test(rectangle) {
        request_mouse_hover(slider.id)
    }

    reset_grab_info := false

    if slider.held {
        if key_pressed(precision_key) || key_released(precision_key) {
            reset_grab_info = true
        }
    }

    if !slider.held && mouse_hover() == slider.id && mouse_pressed(mouse_button) {
        slider.held = true
        reset_grab_info = true
        capture_mouse_hover()
    }

    if reset_grab_info {
        slider.value_when_grabbed = value^
        slider.global_mouse_position_when_grabbed = global_mouse_position()
    }

    if slider.held {
        sensitivity: f32 = key_down(precision_key) ? 0.15 : 1.0
        global_mouse_position := global_mouse_position()
        grab_delta := global_mouse_position.x - slider.global_mouse_position_when_grabbed.x
        value^ = slider.value_when_grabbed + sensitivity * grab_delta * (max_value - min_value) / (rectangle.size.x - HANDLE_LENGTH)

        if mouse_released(mouse_button) {
            slider.held = false
            release_mouse_hover()
        }
    }

    value^ = clamp(value^, min_value, max_value)

    slider_path := temp_path()
    path_rectangle(&slider_path, rectangle)

    fill_path(slider_path, {0.05, 0.05, 0.05, 1})

    handle_rectangle := Rectangle{
        rectangle.position + {
            (rectangle.size.x - HANDLE_LENGTH) * (value^ - min_value) / (max_value - min_value),
            0,
        }, {
            HANDLE_LENGTH,
            rectangle.size.y,
        },
    }
    handle_path := temp_path()
    path_rectangle(&handle_path, handle_rectangle)

    fill_path(handle_path, {0.4, 0.4, 0.4, 1})
    if slider.held {
        fill_path(handle_path, {0, 0, 0, 0.2})
    } else if mouse_hover() == slider.id {
        fill_path(handle_path, {1, 1, 1, 0.05})
    }
}

//==========================================================================
// Box Select
//==========================================================================

Box_Select :: struct {
    using rectangle: Rectangle,
    selected: bool,
    is_dragging: bool,
    start: Vector2,
}

box_select_update :: proc(box_select: ^Box_Select, mouse_button := Mouse_Button.Left) {
    box_select.selected = false

    mp := mouse_position()

    if mouse_pressed(mouse_button) && mouse_clip_test() {
        box_select.start = mp
        box_select.is_dragging = true
    }

    if box_select.is_dragging {
        pixel := pixel_size()

        position := Vector2{min(box_select.start.x, mp.x), min(box_select.start.y, mp.y)}
        bottom_right := Vector2{max(box_select.start.x, mp.x), max(box_select.start.y, mp.y)}

        box_select.rectangle = Rectangle{position, bottom_right - position}
        box_select.rectangle.size.x = max(box_select.rectangle.size.x, pixel.x)
        box_select.rectangle.size.y = max(box_select.rectangle.size.y, pixel.y)

        fill_rectangle(rectangle_expanded(box_select.rectangle, -pixel), {0, 0, 0, 0.3})
        outline_rectangle(box_select.rectangle, pixel.x, {1, 1, 1, 0.3})
    }

    if box_select.is_dragging && mouse_released(mouse_button) {
        box_select.selected = true
        box_select.is_dragging = false
    }
}

//==========================================================================
// Editable Text Line
//==========================================================================

Text_Edit_Command :: cte.Command

Editable_Text_Line :: struct {
    id: Id,
    edit_state: cte.State,
    builder: ^strings.Builder,
}

editable_text_line_init :: proc(
    text: ^Editable_Text_Line,
    builder: ^strings.Builder,
    allocator := context.allocator,
) {
    text.id = get_id()
    text.builder = builder
    cte.init(&text.edit_state, allocator, allocator)
    cte.setup_once(&text.edit_state, text.builder)
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        data = clipboard(context.temp_allocator)
        return _quick_remove_line_ends_UNSAFE(data), true
    }
    text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
        set_clipboard(data)
        return true
    }
}

editable_text_line_destroy :: proc(text: ^Editable_Text_Line) {
    cte.destroy(&text.edit_state)
}

editable_text_line_edit :: proc(text: ^Editable_Text_Line, command: Text_Edit_Command) {
    cte.perform_command(&text.edit_state, command)
}

editable_text_line_update :: proc(
    text: ^Editable_Text_Line,
    rectangle: Rectangle,
    font: Font,
    color := Color{1, 1, 1, 1},
    alignment := Vector2{},
) {
    CARET_WIDTH :: 2

    str := strings.to_string(text.builder^)

    edit_state := &text.edit_state

    edit_state.line_start = 0
    edit_state.line_end = len(str)

    // Update the undo state timeout manually.

    edit_state.current_time = time.tick_now()
    if edit_state.undo_timeout <= 0 {
        edit_state.undo_timeout = cte.DEFAULT_UNDO_TIMEOUT
    }

    // Handle keyboard editing behavior.

    text_input := text_input()
    if len(text_input) > 0 {
        cte.input_text(edit_state, _quick_remove_line_ends_UNSAFE(text_input))
    }

    ctrl := key_down(.Left_Control) || key_down(.Right_Control)
    shift := key_down(.Left_Shift) || key_down(.Right_Shift)

    for key in key_presses(true) {
        #partial switch key {
        case .A: if ctrl do cte.perform_command(edit_state, .Select_All)
        case .C: if ctrl do cte.perform_command(edit_state, .Copy)
        case .V: if ctrl do cte.perform_command(edit_state, .Paste)
        case .X: if ctrl do cte.perform_command(edit_state, .Cut)
        case .Y: if ctrl do cte.perform_command(edit_state, .Redo)
        case .Z: if ctrl do cte.perform_command(edit_state, .Undo)

        case .Home:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_Start)
            case shift: cte.perform_command(edit_state, .Select_Line_Start)
            case ctrl: cte.perform_command(edit_state, .Start)
            case: cte.perform_command(edit_state, .Line_Start)
            }

        case .End:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_End)
            case shift: cte.perform_command(edit_state, .Select_Line_End)
            case ctrl: cte.perform_command(edit_state, .End)
            case: cte.perform_command(edit_state, .Line_End)
            }

        case .Insert:
            switch {
            case ctrl: cte.perform_command(edit_state, .Copy)
            case shift: cte.perform_command(edit_state, .Paste)
            }

        case .Backspace:
            switch {
            case ctrl: cte.perform_command(edit_state, .Delete_Word_Left)
            case: cte.perform_command(edit_state, .Backspace)
            }

        case .Delete:
            switch {
            case ctrl: cte.perform_command(edit_state, .Delete_Word_Right)
            case shift: cte.perform_command(edit_state, .Cut)
            case: cte.perform_command(edit_state, .Delete)
            }

        case .Left_Arrow:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_Word_Left)
            case shift: cte.perform_command(edit_state, .Select_Left)
            case ctrl: cte.perform_command(edit_state, .Word_Left)
            case: cte.perform_command(edit_state, .Left)
            }

        case .Right_Arrow:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_Word_Right)
            case shift: cte.perform_command(edit_state, .Select_Right)
            case ctrl: cte.perform_command(edit_state, .Word_Right)
            case: cte.perform_command(edit_state, .Right)
            }
        }
    }

    // Figure out where things of interest are in the string.

    glyphs := make([dynamic]Text_Glyph, context.temp_allocator)
    measure_glyphs(str, font, &glyphs)

    text_size: Vector2
    text_size.y = font_height(font)
    text_size.x = 0
    if len(glyphs) > 0 {
        first := glyphs[0]
        last := glyphs[len(glyphs) - 1]
        text_size.x = last.position + last.width - first.position
    }
    text_position := pixel_snapped(rectangle.position + (rectangle.size - text_size) * alignment)

    relative_mp := mouse_position() - text_position.x + 3 // Add a little bias for better feel.
    mouse_byte_index: int

    head := edit_state.selection[0]
    caret_x: f32

    selection_left, selection_right := cte.sorted_selection(edit_state)
    selection_left_x: f32
    selection_right_x: f32

    for glyph in glyphs {
        if head == glyph.byte_index {
            caret_x = glyph.position
        }
        if selection_left == glyph.byte_index {
            selection_left_x = glyph.position
        }
        if selection_right == glyph.byte_index {
            selection_right_x = glyph.position
        }
        if relative_mp.x >= glyph.position && relative_mp.x < glyph.position + glyph.width {
            mouse_byte_index = glyph.byte_index
        }
    }

    if len(glyphs) > 0 {
        last_glyph := glyphs[len(glyphs) - 1]
        last_glyph_right := last_glyph.position + last_glyph.width
        if head >= len(str) {
            caret_x = last_glyph_right - CARET_WIDTH
        }
        if selection_left >= len(str) {
            selection_left_x = last_glyph_right
        }
        if selection_right >= len(str) {
            selection_right_x = last_glyph_right
        }
        if relative_mp.x >= last_glyph_right {
            mouse_byte_index = len(str)
        }
    }

    // Handle mouse editing behavior.

    if mouse_hit_test(rectangle) {
        request_mouse_hover(text.id)
    }

    if mouse_hover() == text.id {
        set_mouse_cursor_style(.I_Beam)

        if mouse_pressed(.Left) {
            capture_mouse_hover()

            switch mouse_repeat_count(.Left) {
            case 0, 1: // Single click
                edit_state.selection[0] = mouse_byte_index
                if !shift do edit_state.selection[1] = mouse_byte_index

            case 2: // Double click
                cte.perform_command(edit_state, .Word_Right)
                cte.perform_command(edit_state, .Word_Left)
                cte.perform_command(edit_state, .Select_Word_Right)

            case 3: // Triple click
                cte.perform_command(edit_state, .Line_Start)
                cte.perform_command(edit_state, .Select_Line_End)

            case: // Quadruple click and beyond
                cte.perform_command(edit_state, .Start)
                cte.perform_command(edit_state, .Select_End)
            }
        }

        if mouse_repeat_count(.Left) == 1 && mouse_down(.Left) {
            edit_state.selection[0] = mouse_byte_index
        }

        if mouse_released(.Left) {
            release_mouse_hover()
        }
    }

    // Draw everything.

    {
        scoped_clip(rectangle)

        // Draw selection.
        fill_rectangle({text_position + {selection_left_x, 0}, {selection_right_x - selection_left_x, text_size.y}}, {0, 0.4, 0.8, 0.8})

        // Draw string.
        fill_string(str, text_position, font, color)
    }

    // Draw caret.
    rectangle_extended_by_caret_width := rectangle
    rectangle_extended_by_caret_width.size.x += CARET_WIDTH
    scoped_clip(rectangle_extended_by_caret_width)
    fill_rectangle({text_position + {caret_x, 0}, {CARET_WIDTH, text_size.y}}, {0.7, 0.9, 1, 1})
}

_quick_remove_line_ends_UNSAFE :: proc(str: string) -> string {
    bytes := make([dynamic]byte, len(str), allocator = context.temp_allocator)
    copy_from_string(bytes[:], str)

    keep_position := 0

    for i in 0 ..< len(bytes) {
        should_keep := bytes[i] != '\n' && bytes[i] != '\r'
        if should_keep {
            if keep_position != i {
                bytes[keep_position] = bytes[i]
            }
            keep_position += 1
        }
    }

    resize(&bytes, keep_position)
    return string(bytes[:])
}