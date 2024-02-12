package gui

Window_VTable :: struct {
    poll_events: proc(),
    init: proc(window: ^Window),
    open: proc(window: ^Window) -> (ok: bool),
    close: proc(window: ^Window) -> (ok: bool),
    begin_frame: proc(window: ^Window),
    end_frame: proc(window: ^Window),
}

Window :: struct {
    using rect: Rect,
    content_scale: Vec2,
    is_open: bool,

    previous_rect: Rect,
    was_open: bool,
}

window_init :: proc(window: ^Window, rect: Rect) {
    window.rect = rect
    window.is_open = true
    window.content_scale = {1, 1}
    ctx.window_vtable.init(window)
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

window_begin_update :: proc(window: ^Window) -> bool {
    if !window.is_open && window.was_open {
        if ctx.window_vtable.close(window) {
            window.is_open = false
        }
    }

    if window.is_open && !window.was_open {
        if ctx.window_vtable.open(window) {
            window.is_open = true
        }
    }

    window.was_open = window.is_open
    window.previous_rect = window.rect

    if window.is_open {
        ctx.window_vtable.begin_frame(window)
        return true
    } else {
        return false
    }
}

window_end_update :: proc(window: ^Window) {
    if window.is_open {
        ctx.window_vtable.end_frame(window)
    }
}

@(deferred_in=window_end_update)
window_update :: proc(window: ^Window) -> bool {
    return window_begin_update(window)
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