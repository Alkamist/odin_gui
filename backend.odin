package gui

Backend_VTable :: struct {
    tick_now: proc() -> (tick: Tick, ok: bool),
    set_mouse_cursor_style: proc(style: Mouse_Cursor_Style) -> (ok: bool),
    get_clipboard: proc() -> (data: string, ok: bool),
    set_clipboard: proc(data: string) -> (ok: bool),

    init_window: proc(window: ^Window),
    destroy_window: proc(window: ^Window),
    open_window: proc(window: ^Window) -> (ok: bool),
    close_window: proc(window: ^Window) -> (ok: bool),
    show_window: proc(window: ^Window) -> (ok: bool),
    hide_window: proc(window: ^Window) -> (ok: bool),
    set_window_position: proc(window: ^Window, position: Vec2) -> (ok: bool),
    set_window_size: proc(window: ^Window, size: Vec2) -> (ok: bool),
    activate_window_context: proc(window: ^Window),
    window_begin_frame: proc(window: ^Window),
    window_end_frame: proc(window: ^Window),

    load_font: proc(window: ^Window, font: Font) -> (ok: bool),
    unload_font: proc(window: ^Window, font: Font) -> (ok: bool),
    measure_text: proc(window: ^Window, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int) -> (ok: bool),
    font_metrics: proc(window: ^Window, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(window: ^Window, command: Draw_Command),
}

_tick_now :: proc(ctx: ^Context) -> (tick: Tick, ok: bool) {
    if ctx.backend.tick_now == nil do return {}, false
    return ctx.backend.tick_now()
}

_set_mouse_cursor_style :: proc(ctx: ^Context, style: Mouse_Cursor_Style) -> (ok: bool) {
    if ctx.backend.set_mouse_cursor_style == nil do return false
    return ctx.backend.set_mouse_cursor_style(style)
}

_get_clipboard :: proc(ctx: ^Context) -> (data: string, ok: bool) {
    if ctx.backend.get_clipboard == nil do return "", false
    return ctx.backend.get_clipboard()
}

_set_clipboard :: proc(ctx: ^Context, data: string) -> (ok: bool) {
    if ctx.backend.set_clipboard == nil do return false
    return ctx.backend.set_clipboard(data)
}

_measure_text :: proc(ctx: ^Context, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) -> (ok: bool) {
    if ctx.backend.measure_text == nil do return false
    window := current_window()
    load_font(window, font)
    return ctx.backend.measure_text(window, text, font, glyphs, byte_index_to_rune_index)
}

_font_metrics :: proc(ctx: ^Context, font: Font) -> (metrics: Font_Metrics, ok: bool) {
    if ctx.backend.font_metrics == nil do return {}, false
    window := current_window()
    load_font(window, font)
    return ctx.backend.font_metrics(window, font)
}