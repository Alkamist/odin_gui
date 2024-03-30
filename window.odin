package main

import "core:slice"

Window_Base :: struct {
    using rectangle: Rectangle,
    actual_rectangle: Rectangle,

    background_color: Color,

    content_scale: Vector2,

    should_open: bool,
    should_close: bool,
    should_show: bool,
    should_hide: bool,

    is_open: bool,
    is_visible: bool,
    is_mouse_hovered: bool,
    is_rendering_draw_commands: bool,

    local_offset_stack: [dynamic]Vector2,
    global_offset_stack: [dynamic]Vector2,
    global_clip_rectangle_stack: [dynamic]Rectangle,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    loaded_fonts: map[string]struct{},

    previous_actual_rectangle: Rectangle,
    was_open: bool,
}

current_window :: proc() -> ^Window {
    ctx := gui_context()
    if len(ctx.window_stack) <= 0 do return nil
    return ctx.window_stack[len(ctx.window_stack) - 1]
}

window_init :: proc(window: ^Window, rectangle: Rectangle) {
    window.rectangle = rectangle
    window.actual_rectangle = rectangle
    window.content_scale = {1, 1}
    window.is_visible = true
    backend_init_window(window)
}

window_destroy :: proc(window: ^Window) {
    backend_destroy_window(window)
    if window.is_open {
        _close_window(window)
    }
    delete(window.loaded_fonts)
}

window_is_open :: proc(window: ^Window) -> bool {
    return window.is_open
}

window_opened :: proc(window: ^Window) -> bool {
    return window.is_open && !window.was_open
}

window_closed :: proc(window: ^Window) -> bool {
    return !window.is_open && window.was_open
}

window_position :: proc(window: ^Window) -> Vector2 {
    return window.actual_rectangle.position
}

window_set_position :: proc(window: ^Window, position: Vector2) {
    window.rectangle.position = position
}

window_size :: proc(window: ^Window) -> Vector2 {
    return window.actual_rectangle.size
}

window_set_size :: proc(window: ^Window, size: Vector2) {
    window.rectangle.size = size
}

window_moved :: proc(window: ^Window) -> bool {
    return window.actual_rectangle.position != window.previous_actual_rectangle.position
}

window_resized :: proc(window: ^Window) -> bool {
    return window.actual_rectangle.position != window.previous_actual_rectangle.position
}

window_open :: proc(window: ^Window) {
    window.should_open = true
}

window_close :: proc(window: ^Window) {
    window.should_close = true
}

window_show :: proc(window: ^Window) {
    window.should_show = true
}

window_hide :: proc(window: ^Window) {
    window.should_hide = true
}

@(deferred_in=window_end)
window_update :: proc(window: ^Window) -> bool {
    return window_begin(window)
}

window_begin :: proc(window: ^Window) -> bool {
    ctx := gui_context()

    window.size.x = max(0, window.size.x)
    window.size.y = max(0, window.size.y)

    if window.should_close {
        _close_window(window)
        window.should_close = false
    }

    if window.should_open {
        _open_window(window)
        window.should_open = false
    }

    if window.should_hide {
        _hide_window(window)
        window.should_hide = false
    }

    if window.should_show {
        _show_window(window)
        window.should_show = false
    }

    if window.is_open {
        append(&ctx.window_stack, window)
        ctx.active_windows[window] = {}

        window.local_offset_stack = make([dynamic]Vector2, ctx.arena_allocator)
        window.global_offset_stack = make([dynamic]Vector2, ctx.arena_allocator)
        window.global_clip_rectangle_stack = make([dynamic]Rectangle, ctx.arena_allocator)
        window.layer_stack = make([dynamic]Layer, ctx.arena_allocator)
        window.layers = make([dynamic]Layer, ctx.arena_allocator)

        begin_z_index(0)

        _handle_move_and_resize(window)
        backend_activate_gl_context(window)
        backend_begin_window(window)

        return true
    } else {
        if len(ctx.window_stack) > 0 {
            containing_window := ctx.window_stack[len(ctx.window_stack) - 1]
            backend_activate_gl_context(containing_window)
        }
        return false
    }
}

window_end :: proc(window: ^Window) {
    if !window.is_open do return
    ctx := gui_context()

    end_z_index()

    slice.reverse(window.layers[:])
    slice.stable_sort_by(window.layers[:], proc(i, j: Layer) -> bool {
        return i.global_z_index < j.global_z_index
    })

    if window.is_mouse_hovered {
        _update_hover(window)
    }

    window.is_rendering_draw_commands = true

    for layer in window.layers {
        for command in layer.draw_commands {
            c, is_custom := command.(Custom_Draw_Command)
            if is_custom {
                begin_clip(c.global_clip_rectangle)
                begin_offset(c.global_offset)
            }

            backend_render_draw_command(window, command)

            if is_custom {
                end_offset()
                end_clip()
            }
        }
    }

    backend_end_window(window)

    window.is_rendering_draw_commands = false

    pop(&ctx.window_stack)

    // Restore the containing window's context if it exists.
    if len(ctx.window_stack) > 0 {
        backend_activate_gl_context(ctx.window_stack[len(ctx.window_stack) - 1])
    }
}

_open_window :: proc(window: ^Window) {
    if window.is_open do return
    backend_open_window(window)
    window.is_open = true
}

_close_window :: proc(window: ^Window) {
    if !window.is_open do return

    // Activate the window's context for any cleanup logic that needs it.
    backend_activate_gl_context(window)

    backend_close_window(window)
    window.is_open = false

    // Restore the containing window's context if it exists.
    ctx := gui_context()
    if len(ctx.window_stack) > 0 {
        backend_activate_gl_context(ctx.window_stack[len(ctx.window_stack) - 1])
    }
}

_show_window :: proc(window: ^Window) {
    if window.is_visible do return
    backend_show_window(window)
    window.is_visible = true
}

_hide_window :: proc(window: ^Window) {
    if !window.is_visible do return
    backend_hide_window(window)
    window.is_visible = false
}

_handle_move_and_resize :: proc(window: ^Window) {
    ctx := gui_context()

    if window.position != window.actual_rectangle.position {
        backend_set_window_position(window, window.position)
    }

    if window.size != window.actual_rectangle.size {
        backend_set_window_size(window, window.size)
    }
}

_update_hover :: proc(window: ^Window) {
    ctx := gui_context()
    _clear_hover()

    for layer in window.layers {
        mouse_hover_request := layer.final_mouse_hover_request
        if mouse_hover_request != 0 {
            ctx.mouse_hover = mouse_hover_request
            ctx.mouse_hit = mouse_hover_request
        }
    }

    if ctx.mouse_hover_capture != 0 {
        ctx.mouse_hover = ctx.mouse_hover_capture
    }

    ctx.any_window_hovered = true
}