package main

import "base:runtime"
import "base:intrinsics"
import "core:math"
import "core:time"
import "core:slice"
import "core:strings"

Vector2 :: [2]f32

Id :: u64

get_id :: proc "contextless" () -> Id {
    @(static) id: Id
    return 1 + intrinsics.atomic_add(&id, 1)
}

//==========================================================================
// Context
//==========================================================================

@(thread_local) _gui_context: Context

Context :: struct {
    update: proc(),

    tick: time.Tick,

    global_mouse_position: Vector2,
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

    keyboard_focus: Id,
    mouse_hit: Id,
    mouse_hover: Id,
    previous_mouse_hover: Id,
    mouse_hover_capture: Id,

    last_id: Id,
    is_first_frame: bool,

    // container_stack: [dynamic]Id,
    // containers: map[Id]Container,

    window_stack: [dynamic]Id,
    windows: map[Id]^Window,

    previous_tick: time.Tick,
    previous_global_mouse_position: Vector2,
}

gui_context :: proc() -> ^Context {
    return &_gui_context
}

gui_startup :: proc(update: proc()) {
    ctx := gui_context()
    _remake_input_buffers(ctx)
    ctx.update = update
    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.is_first_frame = true
    backend_startup()
}

gui_shutdown :: proc() {
    ctx := gui_context()
    for window_id in ctx.windows {
        window := ctx.windows[window_id]
        if window.is_open {
            _window_close(window)
        }
        delete(window.child_windows)
        free(window)
    }
    backend_shutdown()
    delete(ctx.windows)
    free_all(context.temp_allocator)
}

gui_update :: proc() {
    context_update(gui_context())
    backend_poll_events()
}

context_update :: proc(ctx: ^Context) {
    ctx.tick = time.tick_now()

    if ctx.is_first_frame {
        ctx.previous_tick = ctx.tick
        ctx.previous_global_mouse_position = ctx.global_mouse_position
    }

    ctx.window_stack = make([dynamic]Id, allocator = context.temp_allocator)

    if ctx.update != nil {
        ctx.update()
    }

    ctx.mouse_wheel = {0, 0}
    ctx.previous_tick = ctx.tick
    ctx.previous_global_mouse_position = ctx.global_mouse_position

    ctx.is_first_frame = false

    free_all(context.temp_allocator)

    _remake_input_buffers(ctx)
}

_remake_input_buffers :: proc(ctx: ^Context) {
    ctx.mouse_presses = make([dynamic]Mouse_Button, context.temp_allocator)
    ctx.mouse_releases = make([dynamic]Mouse_Button, context.temp_allocator)
    ctx.key_presses = make([dynamic]Keyboard_Key, context.temp_allocator)
    ctx.key_repeats = make([dynamic]Keyboard_Key, context.temp_allocator)
    ctx.key_releases = make([dynamic]Keyboard_Key, context.temp_allocator)
    strings.builder_init(&ctx.text_input, context.temp_allocator)
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

input_mouse_move :: proc(ctx: ^Context, global_position: Vector2) {
    ctx.global_mouse_position = global_position
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
    movement := ctx.global_mouse_position - ctx.mouse_repeat_start_position
    if abs(movement.x) > TOLERANCE || abs(movement.y) > TOLERANCE {
        ctx.mouse_repeat_counts[button] = 1
    }

    if ctx.mouse_repeat_counts[button] == 1 {
        ctx.mouse_repeat_start_position = ctx.global_mouse_position
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

// mouse_position :: proc() -> (res: Vector2) {
//     ctx := gui_context()
//     res = ctx.global_mouse_position
//     container := current_container()
//     if container == nil {
//         return
//     }
//     res -= container.global_position
//     return
// }

mouse_position :: proc() -> (res: Vector2) {
    return gui_context().global_mouse_position
}

global_mouse_position :: proc() -> (res: Vector2) {
    return gui_context().global_mouse_position
}

mouse_delta :: proc() -> Vector2 {
    ctx := gui_context()
    return ctx.global_mouse_position - ctx.previous_global_mouse_position
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

//==========================================================================
// Container
//==========================================================================

// Container :: struct {
//     position: Vector2,
//     global_position: Vector2,
//     size: Vector2,
//     z_index: int,
//     global_z_index: int,
//     // draw_commands: [dynamic]Draw_Command,
// }

// current_container :: proc() -> ^Container {
//     ctx := gui_context()
//     if len(ctx.container_stack) <= 0 do return nil
//     return &ctx.containers[ctx.container_stack[len(ctx.container_stack) - 1]]
// }

// container_begin :: proc(id: Id) -> bool {
//     ctx := gui_context()

//     container, exists := &ctx.containers[id]
//     if !exists {
//         ctx.containers[id] = Container{}
//     }

//     append(&ctx.container_stack, id)

//     return true
// }

// container_end :: proc() {
//     ctx := gui_context()
//     pop(&ctx.container_stack)
// }

// @(deferred_none=container_end)
// container :: proc(id: Id) -> bool {
//     return container_begin(id)
// }

//==========================================================================
// Window
//==========================================================================

Window_Base :: struct {
    using rectangle: Rectangle,
    is_open: bool,
    should_open: bool,
    should_close: bool,
    content_scale: Vector2,
    loaded_fonts: map[string]struct{},
    child_windows: [dynamic]Id,
}

current_window :: proc() -> ^Window {
    ctx := gui_context()
    if len(ctx.window_stack) <= 0 do return nil
    return ctx.windows[ctx.window_stack[len(ctx.window_stack) - 1]]
}

parent_window :: proc() -> ^Window {
    ctx := gui_context()
    if len(ctx.window_stack) <= 1 do return nil
    return ctx.windows[ctx.window_stack[len(ctx.window_stack) - 2]]
}

window_base_init :: proc(id: Id, initial_state: Window) {
    ctx := gui_context()
    if id not_in ctx.windows {
        window := new(Window)
        window^ = initial_state
        ctx.windows[id] = window
    }
}

window_base_begin :: proc(id: Id) -> bool {
    ctx := gui_context()
    append(&ctx.window_stack, id)

    window := current_window()

    clear(&window.child_windows)
    backend_window_begin_frame(window)

    if window.is_open {
        backend_activate_gl_context(window)
        parent := parent_window()
        if parent != nil {
            append(&parent.child_windows, id)
        }
    }

    return window.is_open
}

window_base_end :: proc() {
    ctx := gui_context()

    window := current_window()
    backend_window_end_frame(window)

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

_window_open :: proc(window: ^Window) {
    if !window.is_open {
        backend_open_window(window)
        backend_activate_gl_context(window)
        window.is_open = true
        window.should_open = false
    }
}

_window_close :: proc(window: ^Window) {
    ctx := gui_context()

    for child_id in window.child_windows {
        _window_close(ctx.windows[child_id])
    }

    if window.is_open {
        backend_activate_gl_context(window)
        backend_close_window(window)
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
    Clip_Drawing_Command,
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

Clip_Drawing_Command :: struct {
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
    backend_render_draw_command(window, Fill_String_Command{str, position, font, color})
}

clip_drawing :: proc(rectangle: Rectangle) {
    window := current_window()
    backend_render_draw_command(window, Clip_Drawing_Command{rectangle})
}

fill_path :: proc(path: Path, color: Color) {
    window := current_window()
    // path := path
    // path_translate(&path, global_offset())
    backend_render_draw_command(window, Fill_Path_Command{path, color})
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