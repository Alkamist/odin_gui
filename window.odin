package gui

import "core:slice"

Window :: struct {
    using rect: Rect,
    content_scale: Vec2,

    should_open: bool,
    should_close: bool,

    is_open: bool,
    is_visible: bool,
    is_mouse_hovered: bool,
    is_rendering_draw_commands: bool,

    local_offset_stack: [dynamic]Vec2,
    global_offset_stack: [dynamic]Vec2,
    global_clip_rect_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    loaded_fonts: map[Font]struct{},

    previous_rect: Rect,
    was_open: bool,

    last_position_set_externally: Vec2,
    last_size_set_externally: Vec2,
}

window_init :: proc(window: ^Window, rect: Rect) {
    window.rect = rect
    window.last_position_set_externally = rect.position
    window.last_size_set_externally = rect.size
    window.content_scale = {1, 1}
}

window_destroy :: proc(window: ^Window) {
    delete(window.loaded_fonts)
}

window_begin :: proc(window: ^Window) -> bool {
    ctx := current_context()

    window.size.x = max(0, window.size.x)
    window.size.y = max(0, window.size.y)

    if window.should_close {
        _close_window(ctx, window)
        window.should_close = false
    }

    if window.should_open {
        _open_window(ctx, window)
        window.should_open = false
    }

    window.was_open = window.is_open
    window.previous_rect = window.rect

    if window.is_open {
        append(&ctx.window_stack, window)
        ctx.active_windows[window] = {}

        window.local_offset_stack = make([dynamic]Vec2, ctx.arena_allocator)
        window.global_offset_stack = make([dynamic]Vec2, ctx.arena_allocator)
        window.global_clip_rect_stack = make([dynamic]Rect, ctx.arena_allocator)
        window.layer_stack = make([dynamic]Layer, ctx.arena_allocator)
        window.layers = make([dynamic]Layer, ctx.arena_allocator)

        begin_layer(0)

        _handle_move_and_resize(window)

        _activate_window_context(ctx, window)

        if ctx.backend.window_begin_frame != nil {
            ctx.backend.window_begin_frame(window)
        }

        return true
    } else {
        if len(ctx.window_stack) > 0 {
            containing_window := ctx.window_stack[len(ctx.window_stack) - 1]
            _activate_window_context(ctx, containing_window)
        }
        return false
    }
}

window_end :: proc(window: ^Window) {
    if !window.is_open do return
    ctx := current_context()

    end_layer()

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
            render := ctx.backend.render_draw_command
            if render != nil {
                c, is_custom := command.(Draw_Custom_Command)
                if is_custom {
                    begin_clip(c.global_clip_rect)
                    begin_offset(c.global_offset)
                }

                render(window, command)

                if is_custom {
                    end_offset()
                    end_clip()
                }
            }
        }
    }

    if ctx.backend.window_end_frame != nil {
        ctx.backend.window_end_frame(window)
    }

    window.is_rendering_draw_commands = false

    pop(&ctx.window_stack)

    // Restore the containing window's context if it exists.
    if len(ctx.window_stack) > 0 {
        _activate_window_context(ctx, ctx.window_stack[len(ctx.window_stack) - 1])
    }
}

@(deferred_in=window_end)
window_update :: proc(window: ^Window) -> bool {
    return window_begin(window)
}

window_load_font :: proc(window: ^Window, font: Font) -> (ok: bool) {
    ctx := current_context()
    if ctx.backend.load_font == nil do return
    if font not_in window.loaded_fonts {
        if ctx.backend.load_font(window, font) {
            window.loaded_fonts[font] = {}
            return true
        }
    }
    return false
}

window_unload_font :: proc(window: ^Window, font: Font) -> (ok: bool) {
    ctx := current_context()
    if ctx.backend.unload_font == nil do return
    if font in window.loaded_fonts {
        if ctx.backend.unload_font(window, font) {
            delete_key(&window.loaded_fonts, font)
            return true
        }
    }
    return false
}

current_window :: proc() -> ^Window {
    ctx := current_context()
    if len(ctx.window_stack) <= 0 do return nil
    return ctx.window_stack[len(ctx.window_stack) - 1]
}



_open_window :: proc(ctx: ^Context, window: ^Window) {
    if window.is_open do return
    if ctx.backend.open_window != nil && ctx.backend.open_window(window) {
        window.is_open = true
    }
}

_close_window :: proc(ctx: ^Context, window: ^Window) {
    if !window.is_open do return

    // Activate the window's context for any cleanup logic that needs it.
    _activate_window_context(ctx, window)

    if ctx.backend.close_window != nil && ctx.backend.close_window(window) {
        window.is_open = false

        // Restore the containing window's context if it exists.
        if len(ctx.window_stack) > 0 {
            _activate_window_context(ctx, ctx.window_stack[len(ctx.window_stack) - 1])
        }
    }
}

_handle_move_and_resize :: proc(window: ^Window) {
    ctx := current_context()

    if window.position != window.last_position_set_externally {
        failed := true
        if ctx.backend.set_window_position != nil {
            failed = ctx.backend.set_window_position(window, window.position)
        }
        if failed {
            window.position = window.last_position_set_externally
        }
    }

    if window.size != window.last_size_set_externally {
        failed := true
        if ctx.backend.set_window_size != nil {
            failed = ctx.backend.set_window_size(window, window.size)
        }
        if failed {
            window.size = window.last_size_set_externally
        }
    }
}

_update_hover :: proc(window: ^Window) {
    ctx := current_context()
    _clear_hover(ctx)

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

_activate_window_context :: proc(ctx: ^Context, window: ^Window) {
    if ctx.backend.activate_window_context != nil {
        ctx.backend.activate_window_context(window)
    }
}