package main

import "base:runtime"
import "core:mem/virtual"
import "core:time"
import "core:strings"

// A thread local context is held here.
// The idea is to avoid having to pass the context manually
// into every function everywhere.
@(thread_local) _gui_context: Gui_Context

Gui_Context :: struct {
    update: proc(), // User update code goes in here

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

    keyboard_focus: Id,
    mouse_hit: Id,
    mouse_hover: Id,
    previous_mouse_hover: Id,
    mouse_hover_capture: Id,

    window_stack: [dynamic]^Window,
    active_windows: map[^Window]struct{},
    previous_active_windows: map[^Window]struct{},

    is_first_frame: bool,

    previous_tick: time.Tick,
    previous_screen_mouse_position: Vector2,

    arena_allocator: runtime.Allocator,
    arena: virtual.Arena,

    // For the previous frame
    previous_arena_allocator: runtime.Allocator,
    previous_arena: virtual.Arena,

    any_window_hovered: bool,
}

gui_context :: proc() -> ^Gui_Context {
    return &_gui_context
}

gui_startup :: proc(update: proc()) -> runtime.Allocator_Error {
    ctx := gui_context()
    ctx.update = update

    virtual.arena_init_growing(&ctx.arena) or_return
    ctx.arena_allocator = virtual.arena_allocator(&ctx.arena)

    virtual.arena_init_growing(&ctx.previous_arena) or_return
    ctx.previous_arena_allocator = virtual.arena_allocator(&ctx.previous_arena)

    _remake_input_buffers() or_return

    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.is_first_frame = true

    backend_startup()

    return nil
}

gui_shutdown :: proc() {
    ctx := gui_context()
    backend_shutdown()
    free_all(ctx.arena_allocator)
    free_all(ctx.previous_arena_allocator)
}

gui_update :: proc() {
    _context_update(gui_context())
    backend_poll_events()
}

_context_update :: proc(ctx: ^Gui_Context) {
    ctx.tick = time.tick_now()

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
        window.previous_actual_rectangle = window.actual_rectangle
    }

    for window in ctx.previous_active_windows {
        if window not_in ctx.active_windows {
            _close_window(window)
        }
    }

    free_all(ctx.previous_arena_allocator)

    ctx.previous_active_windows = make(map[^Window]struct{}, allocator = ctx.previous_arena_allocator)
    for window in ctx.active_windows {
        ctx.previous_active_windows[window] = {}
    }

    if !ctx.any_window_hovered {
        _clear_hover()
    }

    ctx.mouse_wheel = {0, 0}
    ctx.previous_tick = ctx.tick
    ctx.previous_screen_mouse_position = ctx.screen_mouse_position

    ctx.is_first_frame = false
    ctx.any_window_hovered = false

    free_all(ctx.arena_allocator)

    _remake_input_buffers()
}

arena_allocator :: proc() -> runtime.Allocator {
    return gui_context().arena_allocator
}

_remake_input_buffers :: proc() -> runtime.Allocator_Error {
    ctx := gui_context()
    ctx.mouse_presses = make([dynamic]Mouse_Button, ctx.arena_allocator) or_return
    ctx.mouse_releases = make([dynamic]Mouse_Button, ctx.arena_allocator) or_return
    ctx.key_presses = make([dynamic]Keyboard_Key, ctx.arena_allocator) or_return
    ctx.key_repeats = make([dynamic]Keyboard_Key, ctx.arena_allocator) or_return
    ctx.key_releases = make([dynamic]Keyboard_Key, ctx.arena_allocator) or_return
    strings.builder_init(&ctx.text_input, ctx.arena_allocator) or_return
    return nil
}

_clear_hover :: proc() {
    ctx := gui_context()
    ctx.previous_mouse_hover = ctx.mouse_hover
    ctx.mouse_hover = 0
    ctx.mouse_hit = 0
}