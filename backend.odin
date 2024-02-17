package gui

Context_VTable :: struct {
    tick_now: proc() -> (tick: Tick, ok: bool),
    set_mouse_cursor_style: proc(style: Mouse_Cursor_Style) -> (ok: bool),
    get_clipboard: proc() -> (data: string, ok: bool),
    set_clipboard: proc(data: string) -> (ok: bool),
}

_context_tick_now :: proc(ctx: ^Context) -> (tick: Tick, ok: bool) {
    if ctx.vtable.tick_now == nil do return {}, false
    return ctx.vtable.tick_now()
}

_context_set_mouse_cursor_style :: proc(ctx: ^Context, style: Mouse_Cursor_Style) -> (ok: bool) {
    if ctx.vtable.set_mouse_cursor_style == nil do return false
    return ctx.vtable.set_mouse_cursor_style(style)
}

_context_get_clipboard :: proc(ctx: ^Context) -> (data: string, ok: bool) {
    if ctx.vtable.get_clipboard == nil do return "", false
    return ctx.vtable.get_clipboard()
}

_context_set_clipboard :: proc(ctx: ^Context, data: string) -> (ok: bool) {
    if ctx.vtable.set_clipboard == nil do return false
    return ctx.vtable.set_clipboard(data)
}

Window_VTable :: struct {
    init: proc(window: ^Window),
    destroy: proc(window: ^Window),
    open: proc(window: ^Window) -> (ok: bool),
    close: proc(window: ^Window) -> (ok: bool),
    show: proc(window: ^Window) -> (ok: bool),
    hide: proc(window: ^Window) -> (ok: bool),
    set_position: proc(window: ^Window, position: Vec2) -> (ok: bool),
    set_size: proc(window: ^Window, size: Vec2) -> (ok: bool),
    activate_context: proc(window: ^Window),
    begin_frame: proc(window: ^Window),
    end_frame: proc(window: ^Window),
    load_font: proc(window: ^Window, font: Font) -> (ok: bool),
    measure_text: proc(window: ^Window, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int) -> (ok: bool),
    font_metrics: proc(window: ^Window, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(window: ^Window, command: Draw_Command),
}

_window_init :: proc(window: ^Window) {
    if window.vtable == nil do return
    if window.vtable.init == nil do return
    window.vtable.init(window)
}

_window_destroy :: proc(window: ^Window) {
    if window.vtable == nil do return
    if window.vtable.destroy == nil do return
    window.vtable.destroy(window)
}

_window_open :: proc(window: ^Window) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.open == nil do return false
    return window.vtable.open(window)
}

_window_close :: proc(window: ^Window) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.close == nil do return false
    return window.vtable.close(window)
}

_window_show :: proc(window: ^Window) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.show == nil do return false
    return window.vtable.show(window)
}

_window_hide :: proc(window: ^Window) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.hide == nil do return false
    return window.vtable.hide(window)
}

_window_set_position :: proc(window: ^Window, position: Vec2) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.set_position == nil do return false
    return window.vtable.set_position(window, position)
}

_window_set_size :: proc(window: ^Window, size: Vec2) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.set_size == nil do return false
    return window.vtable.set_size(window, size)
}

_window_activate_context :: proc(window: ^Window) {
    if window.vtable == nil do return
    if window.vtable.activate_context == nil do return
    window.vtable.activate_context(window)
}

_window_begin_frame :: proc(window: ^Window) {
    if window.vtable == nil do return
    if window.vtable.begin_frame == nil do return
    window.vtable.begin_frame(window)
}

_window_end_frame :: proc(window: ^Window) {
    if window.vtable == nil do return
    if window.vtable.end_frame == nil do return
    window.vtable.end_frame(window)
}

_window_load_font :: proc(window: ^Window, font: Font) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.load_font == nil do return false
    return window.vtable.load_font(window, font)
}

_window_measure_text :: proc(window: ^Window, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) -> (ok: bool) {
    if window.vtable == nil do return false
    if window.vtable.measure_text == nil do return false
    return window.vtable.measure_text(window, text, font, glyphs, byte_index_to_rune_index)
}

_window_font_metrics :: proc(window: ^Window, font: Font) -> (metrics: Font_Metrics, ok: bool) {
    if window.vtable == nil do return {}, false
    if window.vtable.font_metrics == nil do return {}, false
    return window.vtable.font_metrics(window, font)
}

_window_render_draw_command :: proc(window: ^Window, command: Draw_Command) {
    if window.vtable == nil do return
    if window.vtable.render_draw_command == nil do return
    window.vtable.render_draw_command(window, command)
}