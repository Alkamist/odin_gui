package gui

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:slice"
import "core:strings"
import "rects"

@(thread_local) ctx: Context

Backend_VTable :: struct {
    poll_events: proc(),
    tick_now: proc() -> (tick: Tick, ok: bool),
    set_mouse_cursor_style: proc(style: Mouse_Cursor_Style) -> (ok: bool),
    get_clipboard: proc() -> (data: string, ok: bool),
    set_clipboard: proc(data: string) -> (ok: bool),

    init_window: proc(window: ^Window),
    destroy_window: proc(window: ^Window),
    open_window: proc(window: ^Window) -> (ok: bool),
    close_window: proc(window: ^Window) -> (ok: bool),
    window_begin_frame: proc(window: ^Window),
    window_end_frame: proc(window: ^Window),

    load_font: proc(window: ^Window, font: Font) -> (ok: bool),
    unload_font: proc(window: ^Window, font: Font) -> (ok: bool),
    measure_text: proc(window: ^Window, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int) -> (ok: bool),
    font_metrics: proc(window: ^Window, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(window: ^Window, command: Draw_Command),
}

Context :: struct {
    update: proc(),

    backend: Backend_VTable,

    tick: Tick,

    screen_mouse_position: Vec2,
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
    mouse_hover_capture: Id,

    window_stack: [dynamic]^Window,

    is_first_frame: bool,

    previous_tick: Tick,
    previous_global_mouse_position: Vec2,

    odin_context: runtime.Context,
    temp_allocator: runtime.Allocator,

    last_id: Id,
    any_window_hovered: bool,
}

init :: proc(update_proc: proc(), temp_allocator := context.temp_allocator) -> runtime.Allocator_Error {
    ctx.update = update_proc
    ctx.odin_context = context
    ctx.temp_allocator = temp_allocator
    _remake_input_buffers() or_return
    ctx = ctx
    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.is_first_frame = true
    return nil
}

shutdown :: proc() {
    free_all(ctx.temp_allocator)
}

update :: proc() {
    ctx.backend.poll_events()
    context_update()
}

context_update :: proc() {
    ctx.tick, _ = tick_now()

    if ctx.is_first_frame {
        ctx.previous_tick = ctx.tick
        ctx.previous_global_mouse_position = ctx.screen_mouse_position
    }

    ctx.window_stack = make([dynamic]^Window, ctx.temp_allocator)

    ctx.update()

    if !ctx.any_window_hovered {
        _clear_hover()
    }

    ctx.mouse_wheel = {0, 0}
    ctx.previous_tick = ctx.tick
    ctx.previous_global_mouse_position = ctx.screen_mouse_position

    ctx.is_first_frame = false
    ctx.any_window_hovered = false

    free_all(ctx.temp_allocator)
    _remake_input_buffers()
}

odin_context :: proc() -> runtime.Context {
    return ctx.odin_context
}

tick_now :: proc() -> (tick: Tick, ok: bool) {
    if ctx.backend.tick_now == nil do return {}, false
    return ctx.backend.tick_now()
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) -> (ok: bool) {
    if ctx.backend.set_mouse_cursor_style == nil do return false
    return ctx.backend.set_mouse_cursor_style(style)
}

get_clipboard :: proc() -> (data: string, ok: bool) {
    if ctx.backend.get_clipboard == nil do return "", false
    return ctx.backend.get_clipboard()
}

set_clipboard :: proc(data: string) -> (ok: bool) {
    if ctx.backend.set_clipboard == nil do return false
    return ctx.backend.set_clipboard(data)
}

measure_text :: proc(text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) -> (ok: bool) {
    if ctx.backend.measure_text == nil do return false
    window := current_window()
    window_load_font(window, font)
    return ctx.backend.measure_text(window, text, font, glyphs, byte_index_to_rune_index)
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics, ok: bool) {
    if ctx.backend.font_metrics == nil do return {}, false
    window := current_window()
    window_load_font(window, font)
    return ctx.backend.font_metrics(window, font)
}



_remake_input_buffers :: proc() -> runtime.Allocator_Error {
    ctx.mouse_presses = make([dynamic]Mouse_Button, ctx.temp_allocator) or_return
    ctx.mouse_releases = make([dynamic]Mouse_Button, ctx.temp_allocator) or_return
    ctx.key_presses = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    ctx.key_repeats = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    ctx.key_releases = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    strings.builder_init(&ctx.text_input, ctx.temp_allocator) or_return
    return nil
}

_clear_hover :: proc() {
    ctx.previous_mouse_hover = ctx.mouse_hover
    ctx.mouse_hover = 0
    ctx.mouse_hit = 0
}