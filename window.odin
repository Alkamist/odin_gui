package gui

import "core:fmt"
import "core:slice"

Window :: struct {
    using rect: Rect,
    content_scale: Vec2,
    is_open: bool,
    is_hovered_by_mouse: bool,

    local_offset_stack: [dynamic]Vec2,
    global_offset_stack: [dynamic]Vec2,
    local_clip_rect_stack: [dynamic]Rect,
    global_clip_rect_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    loaded_fonts: map[Font]struct{},

    previous_rect: Rect,
    was_open: bool,
    was_hovered_by_mouse: bool,
}

window_init :: proc(window: ^Window, rect: Rect, allocator := context.allocator) {
    window.rect = rect
    window.is_open = true
    window.content_scale = {1, 1}
    if ctx.backend.init_window != nil {
        ctx.backend.init_window(window)
    }
}

window_destroy :: proc(window: ^Window) {
    if ctx.backend.destroy_window != nil {
        ctx.backend.destroy_window(window)
    }
    delete(window.loaded_fonts)
}

window_moved :: proc(window: ^Window) -> bool {
    return window.position != window.previous_rect.position
}

window_resized :: proc(window: ^Window) -> bool {
    return window.size != window.previous_rect.size
}

window_opened :: proc(window: ^Window) -> bool {
    return window.is_open && !window.was_open
}

window_closed :: proc(window: ^Window) -> bool {
    return !window.is_open && window.was_open
}

window_mouse_entered :: proc(window: ^Window) -> bool {
    return window.is_hovered_by_mouse && !window.was_hovered_by_mouse
}

window_mouse_exited :: proc(window: ^Window) -> bool {
    return !window.is_hovered_by_mouse && window.was_hovered_by_mouse
}

window_begin_update :: proc(window: ^Window) -> bool {
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

    window.was_open = window.is_open
    window.previous_rect = window.rect

    if window.is_open {
        append(&ctx.window_stack, window)

        window.local_offset_stack = make([dynamic]Vec2, ctx.temp_allocator)
        window.global_offset_stack = make([dynamic]Vec2, ctx.temp_allocator)
        window.local_clip_rect_stack = make([dynamic]Rect, ctx.temp_allocator)
        window.global_clip_rect_stack = make([dynamic]Rect, ctx.temp_allocator)
        window.layer_stack = make([dynamic]Layer, ctx.temp_allocator)
        window.layers = make([dynamic]Layer, ctx.temp_allocator)

        begin_layer(0)

        if ctx.backend.window_begin_frame != nil {
            ctx.backend.window_begin_frame(window)
        }

        return true
    } else {
        return false
    }
}

window_end_update :: proc(window: ^Window) {
    if window.is_open {
        if ctx.backend.window_end_frame != nil {
            ctx.backend.window_end_frame(window)
        }

        end_layer()

        slice.reverse(window.layers[:])
        slice.stable_sort_by(window.layers[:], proc(i, j: Layer) -> bool {
            return i.global_z_index < j.global_z_index
        })

        if window.is_hovered_by_mouse {
            _update_hover(window)
        }

        for layer in window.layers {
            for command in layer.draw_commands {
                render := ctx.backend.render_draw_command
                if render != nil {
                    // c, is_custom := command.(Draw_Custom_Command)
                    // if is_custom {
                    //     begin_offset(c.offset)
                    //     begin_clip(c.clip_rect)
                    // }

                    render(window, command)

                    // if is_custom {
                    //     end_clip()
                    //     end_offset()
                    // }
                }
            }
        }

        pop(&ctx.window_stack)
    }
}

@(deferred_in=window_end_update)
window_update :: proc(window: ^Window) -> bool {
    return window_begin_update(window)
}

window_load_font :: proc(window: ^Window, font: Font) {
    if ctx.backend.load_font == nil do return
    if font not_in window.loaded_fonts {
        if ctx.backend.load_font(window, font) {
            window.loaded_fonts[font] = {}
        } else {
            fmt.eprintf("Failed to load font: %v\n", font)
        }
    }
}

window_unload_font :: proc(window: ^Window, font: Font) {
    if ctx.backend.unload_font == nil do return
    if font in window.loaded_fonts {
        if ctx.backend.unload_font(window, font) {
            delete_key(&window.loaded_fonts, font)
        } else {
            fmt.eprintf("Failed to unload font: %v\n", font)
        }
    }
}

window_unload_all_fonts :: proc(window: ^Window) {
    for font in window.loaded_fonts {
        window_unload_font(window, font)
    }
}

current_window :: proc{
    current_window_cast,
    current_window_base,
}

current_window_cast :: proc($T: typeid) -> ^T {
    return cast(^T)ctx.window_stack[len(ctx.window_stack) - 1]
}

current_window_base :: proc() -> ^Window {
    return ctx.window_stack[len(ctx.window_stack) - 1]
}



_update_hover :: proc(window: ^Window) {
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