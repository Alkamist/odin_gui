package main

import "base:runtime"
import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:time"
import "core:slice"
import "core:strings"

Widget_Id :: rawptr
Vector2 :: [2]f32

//==========================================================================
// Context
//==========================================================================

@(thread_local) _gui_context: Context

Context :: struct {
    update: proc(),

    tick: time.Tick,

    screen_mouse_position: Vector2,
    mouse_down: [Mouse_Button]bool,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_wheel: Vector2,
    mouse_repeat_duration: time.Duration,
    mouse_repeat_movement_tolerance: f32,
    mouse_repeat_start_position: Vector2,
    mouse_repeat_ticks: [Mouse_Button]time.Tick,
    mouse_repeat_counts: [Mouse_Button]int,

    key_down: [Keyboard_Key]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_repeats: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    text_input: strings.Builder,

    keyboard_focus: Widget_Id,
    mouse_hit: Widget_Id,
    mouse_hover: Widget_Id,
    previous_mouse_hover: Widget_Id,
    mouse_hover_capture: Widget_Id,
    final_mouse_hover_request: Widget_Id,

    is_first_frame: bool,

    window_stack: [dynamic]^Window,

    previous_tick: time.Tick,
    previous_screen_mouse_position: Vector2,
}

gui_context :: proc() -> ^Context {
    return &_gui_context
}

gui_startup :: proc(update: proc()) {
    ctx := gui_context()
    ctx.update = update
    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.is_first_frame = true
    backend_startup()
}

gui_shutdown :: proc() {
    ctx := gui_context()
    backend_shutdown()
    delete(ctx.mouse_presses)
    delete(ctx.mouse_releases)
    delete(ctx.key_presses)
    delete(ctx.key_repeats)
    delete(ctx.key_releases)
    strings.builder_destroy(&ctx.text_input)
    free_all(context.temp_allocator)
}

gui_update :: proc() {
    context_update(gui_context())
    backend_poll_events()
    free_all(context.temp_allocator)
}

context_update :: proc(ctx: ^Context) {
    ctx.tick = time.tick_now()

    if ctx.is_first_frame {
        ctx.previous_tick = ctx.tick
        ctx.previous_screen_mouse_position = ctx.screen_mouse_position
    }

    ctx.window_stack = make([dynamic]^Window, context.temp_allocator)

    if ctx.update != nil {
        ctx.update()
    }

    ctx.previous_mouse_hover = ctx.mouse_hover
    ctx.mouse_hit = ctx.final_mouse_hover_request

    if ctx.mouse_hover_capture != nil {
        ctx.mouse_hover = ctx.mouse_hover_capture
    } else {
        ctx.mouse_hover = ctx.final_mouse_hover_request
    }

    ctx.final_mouse_hover_request = nil

    ctx.mouse_wheel = {0, 0}
    ctx.previous_tick = ctx.tick
    ctx.previous_screen_mouse_position = ctx.screen_mouse_position

    ctx.is_first_frame = false

    clear(&ctx.mouse_presses)
    clear(&ctx.mouse_releases)
    clear(&ctx.key_presses)
    clear(&ctx.key_repeats)
    clear(&ctx.key_releases)
    strings.builder_reset(&ctx.text_input)
}

//==========================================================================
// Input
//==========================================================================

Mouse_Cursor_Style :: enum {
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

input_mouse_move :: proc(ctx: ^Context, screen_position: Vector2) {
    ctx.screen_mouse_position = screen_position
}

input_mouse_press :: proc(ctx: ^Context, button: Mouse_Button) {
    ctx.mouse_down[button] = true
    previous_mouse_repeat_tick := ctx.mouse_repeat_ticks[button]

    ctx.mouse_repeat_ticks[button] = time.tick_now()

    delta := time.tick_diff(previous_mouse_repeat_tick, ctx.mouse_repeat_ticks[button])
    if delta <= 300 * time.Millisecond {
        ctx.mouse_repeat_counts[button] += 1
    } else {
        ctx.mouse_repeat_counts[button] = 1
    }

    TOLERANCE :: 3
    movement := ctx.screen_mouse_position - ctx.mouse_repeat_start_position
    if abs(movement.x) > TOLERANCE || abs(movement.y) > TOLERANCE {
        ctx.mouse_repeat_counts[button] = 1
    }

    if ctx.mouse_repeat_counts[button] == 1 {
        ctx.mouse_repeat_start_position = ctx.screen_mouse_position
    }

    append(&ctx.mouse_presses, button)
}

input_mouse_release :: proc(ctx: ^Context, button: Mouse_Button) {
    ctx.mouse_down[button] = false
    append(&ctx.mouse_releases, button)
}

input_mouse_scroll :: proc(ctx: ^Context, amount: Vector2) {
    ctx.mouse_wheel = amount
}

input_key_press :: proc(ctx: ^Context, key: Keyboard_Key) {
    already_down := ctx.key_down[key]
    ctx.key_down[key] = true
    if !already_down {
        append(&ctx.key_presses, key)
    }
    append(&ctx.key_repeats, key)
}

input_key_release :: proc(ctx: ^Context, key: Keyboard_Key) {
    ctx.key_down[key] = false
    append(&ctx.key_releases, key)
}

input_rune :: proc(ctx: ^Context, r: rune) {
    strings.write_rune(&ctx.text_input, r)
}

is_first_frame :: proc() -> bool {
    return gui_context().is_first_frame
}

clipboard :: backend_clipboard
set_clipboard :: backend_set_clipboard

mouse_position :: proc() -> (res: Vector2) {
    ctx := gui_context()
    res = ctx.screen_mouse_position
    window := current_window()
    if window == nil {
        return
    }
    res -= window.position
    res -= global_offset()
    return
}

screen_mouse_position :: proc() -> (res: Vector2) {
    return gui_context().screen_mouse_position
}

mouse_delta :: proc() -> Vector2 {
    ctx := gui_context()
    return ctx.screen_mouse_position - ctx.previous_screen_mouse_position
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return gui_context().mouse_down[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return gui_context().key_down[key]
}

mouse_wheel :: proc() -> Vector2 {
    return gui_context().mouse_wheel
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return gui_context().mouse_wheel != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(gui_context().mouse_presses[:], button)
}

mouse_repeat_count :: proc(button: Mouse_Button) -> int {
    return gui_context().mouse_repeat_counts[button]
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(gui_context().mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(gui_context().mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(gui_context().mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, repeating := false) -> bool {
    ctx := gui_context()
    return slice.contains(ctx.key_presses[:], key) ||
           repeating && slice.contains(ctx.key_repeats[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(gui_context().key_releases[:], key)
}

any_key_pressed :: proc(repeating := false) -> bool {
    if repeating {
        return len(gui_context().key_repeats) > 0
    } else {
        return len(gui_context().key_presses) > 0
    }
}

any_key_released :: proc() -> bool {
    return len(gui_context().key_releases) > 0
}

key_presses :: proc(repeating := false) -> []Keyboard_Key {
    if repeating {
        return gui_context().key_repeats[:]
    } else {
        return gui_context().key_presses[:]
    }
}

key_releases :: proc() -> []Keyboard_Key {
    return gui_context().key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(gui_context().text_input)
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) {
    window := current_window()
    if window == nil do return
    window.mouse_cursor_style = style
}

//==========================================================================
// Window
//==========================================================================

Window_Base :: struct {
    using rectangle: Rectangle,
    is_open: bool,
    should_open: bool,
    should_close: bool,
    is_focused: bool,
    is_mouse_hovered: bool,
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
    ctx := gui_context()
    if len(ctx.window_stack) <= 0 do return nil
    return ctx.window_stack[len(ctx.window_stack) - 1]
}

window_init :: proc(window: ^Window, rectangle: Rectangle) {
    window.content_scale = {1, 1}
    window.rectangle = rectangle
    backend_window_init(window, rectangle)
}

window_destroy :: proc(window: ^Window) {
    backend_window_destroy(window)
    _window_close(window)
    delete(window.child_windows)
    delete(window.loaded_fonts)
}

window_begin :: proc(window: ^Window) -> bool {
    parent := current_window()

    ctx := gui_context()
    append(&ctx.window_stack, window)

    window.global_clip_rectangle_stack = make([dynamic]Rectangle, context.temp_allocator)
    window.local_offset_stack = make([dynamic]Vector2, context.temp_allocator)
    window.global_offset_stack = make([dynamic]Vector2, context.temp_allocator)

    clear(&window.child_windows)
    backend_window_begin_frame(window)

    if window.is_open {
        backend_activate_gl_context(window)
        if parent != nil {
            append(&parent.child_windows, window)
        }
        window.mouse_cursor_style = .Arrow
    }

    return window.is_open
}

window_end :: proc() {
    ctx := gui_context()

    window := current_window()

    backend_window_end_frame(window)

    if window.mouse_cursor_style != window.previous_mouse_cursor_style {
        backend_set_mouse_cursor_style(window.mouse_cursor_style)
    }
    window.previous_mouse_cursor_style = window.mouse_cursor_style

    if window.should_open {
        _window_open(window)
    }
    if window.should_close {
        _window_close(window)
    }

    pop(&ctx.window_stack)

    parent := current_window()
    if parent != nil {
        backend_activate_gl_context(parent)
    }
}

@(deferred_none=window_end)
window_update :: proc(window: ^Window) -> bool {
    return window_begin(window)
}

_window_open :: proc(window: ^Window) {
    if !window.is_open {
        backend_window_open(window)
        backend_activate_gl_context(window)
        window.is_open = true
        window.should_open = false
    }
}

_window_close :: proc(window: ^Window) {
    ctx := gui_context()

    for child in window.child_windows {
        _window_close(child)
    }

    if window.is_open {
        backend_activate_gl_context(window)
        backend_window_close(window)
        window.is_open = false
        window.should_close = false
    }
}

//==========================================================================
// Vector Graphics
//==========================================================================

Color :: [4]f32

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
}

Fill_Path_Command :: struct {
    path: Path,
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
    backend_render_draw_command(window, Fill_String_Command{str, global_offset() + position, font, color})
}

fill_path :: proc(path: Path, color: Color) {
    window := current_window()
    path := path
    path_translate(&path, global_offset())
    backend_render_draw_command(window, Fill_Path_Command{path, color})
}

set_clip_rectangle :: proc(rectangle: Rectangle) {
    window := current_window()
    rectangle := rectangle
    rectangle.position += global_offset()
    backend_render_draw_command(window, Set_Clip_Rectangle_Command{rectangle})
}

measure_string :: proc(str: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) {
    window := current_window()
    _load_font_if_not_loaded(window, font)
    backend_measure_string(window, str, font, glyphs, byte_index_to_rune_index)
}

font_metrics :: proc(font: Font) -> Font_Metrics {
    window := current_window()
    _load_font_if_not_loaded(window, font)
    return backend_font_metrics(window, font)
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
        backend_load_font(window, font)
        window.loaded_fonts[font.name] = {}
    }
}

//==========================================================================
// Tools
//==========================================================================

mouse_hover :: proc() -> Widget_Id {
    ctx := gui_context()
    return ctx.mouse_hover
}

mouse_hover_entered :: proc() -> Widget_Id {
    ctx := gui_context()
    if ctx.mouse_hover != ctx.previous_mouse_hover {
        return ctx.mouse_hover
    } else {
        return nil
    }
}

mouse_hover_exited :: proc() -> Widget_Id {
    ctx := gui_context()
    if ctx.mouse_hover != ctx.previous_mouse_hover {
        return ctx.previous_mouse_hover
    } else {
        return nil
    }
}

mouse_hit :: proc() -> Widget_Id {
    ctx := gui_context()
    return ctx.mouse_hit
}

request_mouse_hover :: proc(id: Widget_Id) {
    gui_context().final_mouse_hover_request = id
}

capture_mouse_hover :: proc() {
    ctx := gui_context()
    ctx.mouse_hover_capture = ctx.final_mouse_hover_request
}

release_mouse_hover :: proc() {
    ctx := gui_context()
    ctx.mouse_hover_capture = nil
}

keyboard_focus :: proc() -> Widget_Id {
    ctx := gui_context()
    return ctx.keyboard_focus
}

set_keyboard_focus :: proc(id: Widget_Id) {
    ctx := gui_context()
    ctx.keyboard_focus = id
}

release_keyboard_focus :: proc() {
    ctx := gui_context()
    ctx.keyboard_focus = nil
}

hit_test :: proc(rectangle: Rectangle, target: Vector2) -> bool {
    return rectangle_encloses(rectangle, target, include_borders = false) &&
           rectangle_encloses(local_clip_rectangle(), target, include_borders = false)
}

mouse_hit_test :: proc(rectangle: Rectangle) -> bool {
    return hit_test(rectangle, mouse_position())
}

local_offset :: proc() -> Vector2 {
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
    if len(window.local_offset_stack) <= 0 ||
       len(window.global_offset_stack) <= 0 {
        return
    }
    pop(&window.local_offset_stack)
    pop(&window.global_offset_stack)
}

@(deferred_none=end_offset)
scoped_offset :: proc(offset: Vector2) {
    begin_offset(offset)
}

local_clip_rectangle :: proc() -> Rectangle {
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
    backend_render_draw_command(window, Set_Clip_Rectangle_Command{global_rect})
}

end_clip :: proc() {
    window := current_window()

    if len(window.global_clip_rectangle_stack) <= 0 {
        return
    }

    pop(&window.global_clip_rectangle_stack)

    if len(window.global_clip_rectangle_stack) <= 0 {
        return
    }

    global_rect := window.global_clip_rectangle_stack[len(window.global_clip_rectangle_stack) - 1]

    backend_render_draw_command(window, Set_Clip_Rectangle_Command{global_rect})
}

@(deferred_none=end_clip)
scoped_clip :: proc(rectangle: Rectangle, intersect := true) {
    begin_clip(rectangle, intersect = intersect)
}

// z_index :: proc() -> int {
//     window := current_window()
//     if len(window.layer_stack) <= 0 do return 0
//     return _current_layer(window).local_z_index
// }

// global_z_index :: proc() -> int {
//     window := current_window()
//     if len(window.layer_stack) <= 0 do return 0
//     return _current_layer(window).global_z_index
// }

// // Local z index
// begin_z_index :: proc(z_index: int) {
//     window := current_window()
//     layer: Layer
//     layer.draw_commands = make([dynamic]Draw_Command, arena_allocator())
//     layer.local_z_index = z_index
//     layer.global_z_index = global_z_index() + z_index
//     append(&window.layer_stack, layer)
// }

// end_z_index :: proc() {
//     window := current_window()
//     if len(window.layer_stack) <= 0 do return
//     layer := pop(&window.layer_stack)
//     append(&window.layers, layer)
// }

// @(deferred_none=end_z_index)
// scoped_z_index :: proc(z_index: int) {
//     begin_z_index(z_index)
// }

// _current_layer :: proc(window: ^Window) -> ^Layer {
//     return &window.layer_stack[len(window.layer_stack) - 1]
// }