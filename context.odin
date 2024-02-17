package gui

import "base:runtime"
import "core:mem/virtual"
import "core:time"
import "core:strings"

// A thread local pointer to the current context is held here.
// The idea is to avoid having to pass the context manually
// into every function everywhere. Unless there is some very unique
// user code, there should only be one context per thread anyway.
@(thread_local) _current_ctx: ^Context

Context :: struct {
    update: proc(), // User update code goes in here

    vtable: ^Context_VTable,

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
    active_windows: map[^Window]struct{},
    previous_active_windows: map[^Window]struct{},

    is_first_frame: bool,

    previous_tick: Tick,
    previous_screen_mouse_position: Vec2,

    arena_allocator: runtime.Allocator,
    arena: virtual.Arena,

    // For the previous frame
    previous_arena_allocator: runtime.Allocator,
    previous_arena: virtual.Arena,

    any_window_hovered: bool,
}

current_context :: proc() -> ^Context {
    assert(_current_ctx != nil)
    return _current_ctx
}

context_init :: proc(
    ctx: ^Context,
    vtable: ^Context_VTable,
    allocator := context.allocator,
) -> runtime.Allocator_Error {
    ctx.vtable = vtable

    virtual.arena_init_growing(&ctx.arena) or_return
    ctx.arena_allocator = virtual.arena_allocator(&ctx.arena)

    virtual.arena_init_growing(&ctx.previous_arena) or_return
    ctx.previous_arena_allocator = virtual.arena_allocator(&ctx.previous_arena)

    _remake_input_buffers(ctx) or_return

    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.is_first_frame = true

    _current_ctx = ctx

    return nil
}

context_destroy :: proc(ctx: ^Context) {
    free_all(ctx.arena_allocator)
}

context_update :: proc(ctx: ^Context) {
    previous_ctx := _current_ctx
    _current_ctx = ctx
    defer _current_ctx = previous_ctx

    ctx.tick, _ = tick_now()

    if ctx.is_first_frame {
        ctx.previous_tick = ctx.tick
        ctx.previous_screen_mouse_position = ctx.screen_mouse_position
    }

    ctx.window_stack = make([dynamic]^Window, ctx.arena_allocator)
    ctx.active_windows = make(map[^Window]struct{}, allocator = ctx.arena_allocator)

    if ctx.update != nil {
        ctx.update()
    }

    for window in ctx.active_windows {
        window.was_open = window.is_open
        window.previous_actual_rect = window.actual_rect
    }

    for window in ctx.previous_active_windows {
        if window not_in ctx.active_windows {
            _close_window(ctx, window)
        }
    }

    free_all(ctx.previous_arena_allocator)

    ctx.previous_active_windows = make(map[^Window]struct{}, allocator = ctx.previous_arena_allocator)
    for window in ctx.active_windows {
        ctx.previous_active_windows[window] = {}
    }

    if !ctx.any_window_hovered {
        _clear_hover(ctx)
    }

    ctx.mouse_wheel = {0, 0}
    ctx.previous_tick = ctx.tick
    ctx.previous_screen_mouse_position = ctx.screen_mouse_position

    ctx.is_first_frame = false
    ctx.any_window_hovered = false

    free_all(ctx.arena_allocator)

    _remake_input_buffers(ctx)
}

arena_allocator :: proc() -> runtime.Allocator {
    return current_context().arena_allocator
}

tick_now :: proc() -> (tick: Tick, ok: bool) {
    return _backend_vtable_tick_now(current_context())
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) -> (ok: bool) {
    return _backend_vtable_set_mouse_cursor_style(current_context(), style)
}

get_clipboard :: proc() -> (data: string, ok: bool) {
    return _backend_vtable_get_clipboard(current_context())
}

set_clipboard :: proc(data: string) -> (ok: bool) {
    return _backend_vtable_set_clipboard(current_context(), data)
}



_remake_input_buffers :: proc(ctx: ^Context) -> runtime.Allocator_Error {
    ctx.mouse_presses = make([dynamic]Mouse_Button, ctx.arena_allocator) or_return
    ctx.mouse_releases = make([dynamic]Mouse_Button, ctx.arena_allocator) or_return
    ctx.key_presses = make([dynamic]Keyboard_Key, ctx.arena_allocator) or_return
    ctx.key_repeats = make([dynamic]Keyboard_Key, ctx.arena_allocator) or_return
    ctx.key_releases = make([dynamic]Keyboard_Key, ctx.arena_allocator) or_return
    strings.builder_init(&ctx.text_input, ctx.arena_allocator) or_return
    return nil
}

_clear_hover :: proc(ctx: ^Context) {
    ctx.previous_mouse_hover = ctx.mouse_hover
    ctx.mouse_hover = 0
    ctx.mouse_hit = 0
}