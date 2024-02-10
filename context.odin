package gui

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:slice"
import "core:strings"
import "rect"

@(thread_local) _current_ctx: ^Context

Context :: struct {
    update: proc(ctx: ^Context),
    tick_now: proc(ctx: ^Context) -> (tick: Tick, ok: bool),
    set_mouse_cursor_style: proc(ctx: ^Context, style: Mouse_Cursor_Style) -> (ok: bool),
    get_clipboard: proc(ctx: ^Context) -> (data: string, ok: bool),
    set_clipboard: proc(ctx: ^Context, data: string) -> (ok: bool),
    measure_text: proc(ctx: ^Context, text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int) -> (ok: bool),
    font_metrics: proc(ctx: ^Context, font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(ctx: ^Context, command: Draw_Command),

    is_open: bool,
    tick: Tick,
    position: Vec2,
    size: Vec2,
    content_scale: Vec2,

    client_area_hovered: bool,
    global_mouse_position: Vec2,
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

    offset_stack: [dynamic]Vec2, // Stored in global coordinates
    clip_rect_stack: [dynamic]Rect, // Stored in global coordinates
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    is_in_render_phase: bool,

    was_open: bool,
    previous_tick: Tick,
    previous_global_mouse_position: Vec2,

    temp_allocator: runtime.Allocator,
}

init :: proc(
    ctx: ^Context,
    position: Vec2,
    size: Vec2,
    temp_allocator := context.temp_allocator,
) -> runtime.Allocator_Error {
    _current_ctx = ctx
    ctx.temp_allocator = temp_allocator
    _remake_input_buffers(ctx) or_return
    ctx.position = position
    ctx.size = size
    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.content_scale = Vec2{1, 1}
    return nil
}

destroy :: proc(ctx: ^Context) {
    free_all(ctx.temp_allocator)
}

update :: proc(ctx: ^Context) {
    // Update phase

    _current_ctx = ctx
    ctx.tick, _ = _tick_now(ctx)

    ctx.offset_stack = make([dynamic]Vec2, ctx.temp_allocator)
    ctx.clip_rect_stack = make([dynamic]Rect, ctx.temp_allocator)
    ctx.layer_stack = make([dynamic]Layer, ctx.temp_allocator)
    ctx.layers = make([dynamic]Layer, ctx.temp_allocator)

    begin_z_index(0, global = true)
    begin_offset({0, 0}, global = true)
    begin_clip({0, 0}, ctx.size, global = true, intersect = false)

    if ctx.update != nil {
        ctx->update()
    }

    end_clip();    assert(len(ctx.clip_rect_stack) == 0)
    end_offset();  assert(len(ctx.offset_stack) == 0)
    end_z_index(); assert(len(ctx.layer_stack) == 0)

    slice.reverse(ctx.layers[:])
    slice.stable_sort_by(ctx.layers[:], proc(i, j: Layer) -> bool {
        return i.z_index < j.z_index
    })

    _update_hover(ctx)

    // Render phase

    ctx.is_in_render_phase = true

    begin_z_index(0, global = true)
    begin_offset({0, 0}, global = true)
    begin_clip({0, 0}, ctx.size, global = true, intersect = false)

    for layer in ctx.layers {
        for command in layer.draw_commands {
            render := ctx.render_draw_command
            if render != nil {
                c, is_custom := command.(Draw_Custom_Command)
                if is_custom {
                    begin_offset(c.offset)
                    begin_clip(c.clip_rect.position, c.clip_rect.size, global = true)
                }

                render(ctx, command)

                if is_custom {
                    end_clip()
                    end_offset()
                }
            }
        }
    }

    ctx.is_in_render_phase = false

    end_clip();    assert(len(ctx.clip_rect_stack) == 0)
    end_offset();  assert(len(ctx.offset_stack) == 0)
    end_z_index(); assert(len(ctx.layer_stack) == 0)

    // Cleanup for next frame

    ctx.mouse_wheel = {0, 0}
    ctx.was_open = ctx.is_open
    ctx.previous_tick = ctx.tick
    ctx.previous_global_mouse_position = ctx.global_mouse_position

    free_all(ctx.temp_allocator)
    _remake_input_buffers(ctx)
}

current_context :: proc($T: typeid) -> ^T {
    return cast(^T)_current_ctx
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) -> (ok: bool) {
    if _current_ctx.set_mouse_cursor_style == nil do return false
    return _current_ctx->set_mouse_cursor_style(style)
}

get_clipboard :: proc() -> (data: string, ok: bool) {
    if _current_ctx.get_clipboard == nil do return "", false
    return _current_ctx->get_clipboard()
}

set_clipboard :: proc(data: string) -> (ok: bool) {
    if _current_ctx.set_clipboard == nil do return false
    return _current_ctx->set_clipboard(data)
}

measure_text :: proc(text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) -> (ok: bool) {
    if _current_ctx.measure_text == nil do return false
    return _current_ctx->measure_text(text, font, glyphs, byte_index_to_rune_index)
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics, ok: bool) {
    if _current_ctx.font_metrics == nil do return {}, false
    return _current_ctx->font_metrics(font)
}



_tick_now :: proc(ctx: ^Context) -> (tick: Tick, ok: bool) {
    if ctx.tick_now == nil do return {}, false
    return ctx->tick_now()
}

_remake_input_buffers :: proc(ctx: ^Context) -> runtime.Allocator_Error {
    ctx.mouse_presses = make([dynamic]Mouse_Button, ctx.temp_allocator) or_return
    ctx.mouse_releases = make([dynamic]Mouse_Button, ctx.temp_allocator) or_return
    ctx.key_presses = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    ctx.key_repeats = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    ctx.key_releases = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    strings.builder_init(&ctx.text_input, ctx.temp_allocator) or_return
    return nil
}

_update_hover :: proc(ctx: ^Context) {
    ctx.previous_mouse_hover = ctx.mouse_hover
    ctx.mouse_hover = 0
    ctx.mouse_hit = 0

    for layer in ctx.layers {
        mouse_hover_request := layer.final_mouse_hover_request
        if mouse_hover_request != 0 {
            ctx.mouse_hover = mouse_hover_request
            ctx.mouse_hit = mouse_hover_request
        }
    }

    if ctx.mouse_hover_capture != 0 {
        ctx.mouse_hover = ctx.mouse_hover_capture
    }
}