package gui

import "core:slice"

Window :: struct {
    vtable: ^Window_VTable,

    using rect: Rect,
    actual_rect: Rect,

    content_scale: Vec2,

    should_open: bool,
    should_close: bool,
    should_show: bool,
    should_hide: bool,

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

    previous_actual_rect: Rect,
    was_open: bool,
}

init :: proc(window: ^Window, vtable: ^Window_VTable, rect: Rect) {
    window.vtable = vtable
    window.rect = rect
    window.actual_rect = rect
    window.content_scale = {1, 1}
    window.is_visible = true
    _window_init(window)
}

destroy :: proc(window: ^Window) {
    _window_destroy(window)
    delete(window.loaded_fonts)
}

opened :: proc(window: ^Window) -> bool {
    return window.is_open && !window.was_open
}

closed :: proc(window: ^Window) -> bool {
    return !window.is_open && window.was_open
}

moved :: proc(window: ^Window) -> bool {
    return window.actual_rect.position != window.previous_actual_rect.position
}

resized :: proc(window: ^Window) -> bool {
    return window.actual_rect.position != window.previous_actual_rect.position
}

open :: proc(window: ^Window) {
    window.should_open = true
}

close :: proc(window: ^Window) {
    window.should_close = true
}

show :: proc(window: ^Window) {
    window.should_show = true
}

hide :: proc(window: ^Window) {
    window.should_hide = true
}

measure_text :: proc(text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) -> (ok: bool) {
    window := current_window()
    load_font(window, font)
    return _window_measure_text(window, text, font, glyphs, byte_index_to_rune_index)
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics, ok: bool) {
    window := current_window()
    load_font(window, font)
    return _window_font_metrics(window, font)
}

@(deferred_in=window_end)
update :: proc(window: ^Window) -> bool {
    return window_begin(window)
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

        window.local_offset_stack = make([dynamic]Vec2, ctx.arena_allocator)
        window.global_offset_stack = make([dynamic]Vec2, ctx.arena_allocator)
        window.global_clip_rect_stack = make([dynamic]Rect, ctx.arena_allocator)
        window.layer_stack = make([dynamic]Layer, ctx.arena_allocator)
        window.layers = make([dynamic]Layer, ctx.arena_allocator)

        begin_layer(0)

        _handle_move_and_resize(window)
        _window_activate_context(window)
        _window_begin_frame(window)

        return true
    } else {
        if len(ctx.window_stack) > 0 {
            containing_window := ctx.window_stack[len(ctx.window_stack) - 1]
            _window_activate_context(containing_window)
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
            c, is_custom := command.(Draw_Custom_Command)
            if is_custom {
                begin_clip(c.global_clip_rect)
                begin_offset(c.global_offset)
            }

            _window_render_draw_command(window, command)

            if is_custom {
                end_offset()
                end_clip()
            }
        }
    }

    _window_end_frame(window)

    window.is_rendering_draw_commands = false

    pop(&ctx.window_stack)

    // Restore the containing window's context if it exists.
    if len(ctx.window_stack) > 0 {
        _window_activate_context(ctx.window_stack[len(ctx.window_stack) - 1])
    }
}

load_font :: proc(window: ^Window, font: Font) -> (ok: bool) {
    if font not_in window.loaded_fonts {
        if _window_load_font(window, font) {
            window.loaded_fonts[font] = {}
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



_open_window :: proc(window: ^Window) {
    if window.is_open do return
    if _window_open(window) {
        window.is_open = true
    }
}

_close_window :: proc(ctx: ^Context, window: ^Window) {
    if !window.is_open do return

    // Activate the window's context for any cleanup logic that needs it.
    _window_activate_context(window)

    if _window_close(window) {
        window.is_open = false

        // Restore the containing window's context if it exists.
        if len(ctx.window_stack) > 0 {
            _window_activate_context(ctx.window_stack[len(ctx.window_stack) - 1])
        }
    }
}

_show_window :: proc(window: ^Window) {
    if window.is_visible do return
    if _window_show(window) {
        window.is_visible = true
    }
}

_hide_window :: proc(window: ^Window) {
    if !window.is_visible do return
    if _window_hide(window) {
        window.is_visible = false
    }
}

_handle_move_and_resize :: proc(window: ^Window) {
    ctx := current_context()

    if window.position != window.actual_rect.position {
        if !_window_set_position(window, window.position) {
            window.position = window.actual_rect.position
        }
    }

    if window.size != window.actual_rect.size {
        if !_window_set_size(window, window.size) {
            window.size = window.actual_rect.size
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