package gui

import "core:slice"

Window :: struct {
    using rect: Rect,
    content_scale: Vec2,
    is_open: bool,
    is_hovered_by_mouse: bool,
    is_rendering_draw_commands: bool,

    // Delayed by 1 frame
    moved: bool,
    resized: bool,
    opened: bool,
    closed: bool,

    local_offset_stack: [dynamic]Vec2,
    global_offset_stack: [dynamic]Vec2,
    global_clip_rect_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    loaded_fonts: map[Font]struct{},

    previous_rect: Rect,
    was_open: bool,
    was_hovered_by_mouse: bool,

    last_position_set_externally: Vec2,
    last_size_set_externally: Vec2,
}

window_init :: proc(window: ^Window, rect: Rect) {
    window.rect = rect
    window.is_open = true
    window.content_scale = {1, 1}
}

window_destroy :: proc(window: ^Window) {
    delete(window.loaded_fonts)
}

window_begin :: proc(window: ^Window) -> bool {
    ctx := current_context()

    window.size.x = max(0, window.size.x)
    window.size.y = max(0, window.size.y)

    if !window.is_open && window.was_open {
        if ctx.backend.close_window != nil && ctx.backend.close_window(window) {
            window.is_open = false
        }
    }

    if window.is_open && !window.was_open {
        if ctx.backend.open_window != nil && ctx.backend.open_window(window) {
            window.is_open = true
        }
    }

    window.moved = window.position != window.previous_rect.position
    window.resized = window.size != window.previous_rect.size
    window.opened = window.is_open && !window.was_open
    window.closed = !window.is_open && window.was_open

    window.was_open = window.is_open
    window.previous_rect = window.rect

    if window.is_open {
        append(&ctx.window_stack, window)

        window.local_offset_stack = make([dynamic]Vec2, ctx.temp_allocator)
        window.global_offset_stack = make([dynamic]Vec2, ctx.temp_allocator)
        window.global_clip_rect_stack = make([dynamic]Rect, ctx.temp_allocator)
        window.layer_stack = make([dynamic]Layer, ctx.temp_allocator)
        window.layers = make([dynamic]Layer, ctx.temp_allocator)

        begin_layer(0)

        _handle_move_and_resize(window)

        if ctx.backend.window_begin_frame != nil {
            ctx.backend.window_begin_frame(window)
        }

        return true
    } else {
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

    if window.is_hovered_by_mouse {
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
    return ctx.window_stack[len(ctx.window_stack) - 1]
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