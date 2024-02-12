package gui

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:slice"
import "core:strings"
import "rects"

@(thread_local) ctx: Context

Backend_VTable :: struct {
    update: proc(),
    tick_now: proc() -> (tick: Tick, ok: bool),
    set_mouse_cursor_style: proc(style: Mouse_Cursor_Style) -> (ok: bool),
    get_clipboard: proc() -> (data: string, ok: bool),
    set_clipboard: proc(data: string) -> (ok: bool),
    measure_text: proc(text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int) -> (ok: bool),
    font_metrics: proc(font: Font) -> (metrics: Font_Metrics, ok: bool),
    render_draw_command: proc(command: Draw_Command),
}

Context :: struct {
    update: proc(),

    backend_vtable: Backend_VTable,
    window_vtable: Window_VTable,

    tick: Tick,

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

    window_stack: [dynamic]^Window,
    offset_stack: [dynamic]Vec2,
    clip_rect_stack: [dynamic]Rect,
    layer_stack: [dynamic]Layer,
    layers: [dynamic]Layer,

    // is_in_render_phase: bool,
    is_first_frame: bool,

    previous_tick: Tick,
    previous_global_mouse_position: Vec2,

    odin_context: runtime.Context,
    temp_allocator: runtime.Allocator,
}

init :: proc(update_proc: proc(), temp_allocator := context.temp_allocator) -> runtime.Allocator_Error {
    ctx.update = update_proc
    ctx.odin_context = context
    ctx.temp_allocator = temp_allocator
    _remake_input_buffers() or_return
    ctx = ctx
    ctx.mouse_repeat_duration = 300 * time.Millisecond
    ctx.mouse_repeat_movement_tolerance = 3
    ctx.is_first_frame = true
    return nil
}

shutdown :: proc() {
    free_all(ctx.temp_allocator)
}

update :: proc() {
    ctx.backend_vtable.update()
    context_update()
}

context_update :: proc() {
    // Update phase
    ctx.tick, _ = tick_now()

    if ctx.is_first_frame {
        ctx.previous_tick = ctx.tick
        ctx.previous_global_mouse_position = ctx.global_mouse_position
    }

    ctx.window_stack = make([dynamic]^Window, ctx.temp_allocator)
    ctx.offset_stack = make([dynamic]Vec2, ctx.temp_allocator)
    ctx.clip_rect_stack = make([dynamic]Rect, ctx.temp_allocator)
    ctx.layer_stack = make([dynamic]Layer, ctx.temp_allocator)
    ctx.layers = make([dynamic]Layer, ctx.temp_allocator)

    // begin_z_index(0, global = true)
    // begin_offset({0, 0}, global = true)
    // begin_clip({{0, 0}, _current_window().size}, global = true, intersect = false)

    ctx.update()

    // end_clip()
    // end_offset()
    // end_z_index()

    // slice.reverse(ctx.layers[:])
    // slice.stable_sort_by(ctx.layers[:], proc(i, j: Layer) -> bool {
    //     return i.z_index < j.z_index
    // })

    _update_hover()

    // Render phase

    // ctx.is_in_render_phase = true

    // begin_z_index(0, global = true)
    // begin_offset({0, 0}, global = true)
    // begin_clip({{0, 0}, _current_window().size}, global = true, intersect = false)

    // for layer in ctx.layers {
    //     for command in layer.draw_commands {
    //         render := ctx.backend_vtable.render_draw_command
    //         if render != nil {
    //             c, is_custom := command.(Draw_Custom_Command)
    //             if is_custom {
    //                 begin_offset(c.offset)
    //                 begin_clip(c.clip_rect, global = true)
    //             }

    //             render(command)

    //             if is_custom {
    //                 end_clip()
    //                 end_offset()
    //             }
    //         }
    //     }
    // }

    // ctx.is_in_render_phase = false

    // end_clip()
    // end_offset()
    // end_z_index()

    // Cleanup for next frame

    ctx.mouse_wheel = {0, 0}
    ctx.previous_tick = ctx.tick
    ctx.previous_global_mouse_position = ctx.global_mouse_position

    ctx.is_first_frame = false

    free_all(ctx.temp_allocator)
    _remake_input_buffers()
}

odin_context :: proc() -> runtime.Context {
    return ctx.odin_context
}

tick_now :: proc() -> (tick: Tick, ok: bool) {
    if ctx.backend_vtable.tick_now == nil do return {}, false
    return ctx.backend_vtable.tick_now()
}

set_mouse_cursor_style :: proc(style: Mouse_Cursor_Style) -> (ok: bool) {
    if ctx.backend_vtable.set_mouse_cursor_style == nil do return false
    return ctx.backend_vtable.set_mouse_cursor_style(style)
}

get_clipboard :: proc() -> (data: string, ok: bool) {
    if ctx.backend_vtable.get_clipboard == nil do return "", false
    return ctx.backend_vtable.get_clipboard()
}

set_clipboard :: proc(data: string) -> (ok: bool) {
    if ctx.backend_vtable.set_clipboard == nil do return false
    return ctx.backend_vtable.set_clipboard(data)
}

measure_text :: proc(text: string, font: Font, glyphs: ^[dynamic]Text_Glyph, byte_index_to_rune_index: ^map[int]int = nil) -> (ok: bool) {
    if ctx.backend_vtable.measure_text == nil do return false
    return ctx.backend_vtable.measure_text(text, font, glyphs, byte_index_to_rune_index)
}

font_metrics :: proc(font: Font) -> (metrics: Font_Metrics, ok: bool) {
    if ctx.backend_vtable.font_metrics == nil do return {}, false
    return ctx.backend_vtable.font_metrics(font)
}



_remake_input_buffers :: proc() -> runtime.Allocator_Error {
    ctx.mouse_presses = make([dynamic]Mouse_Button, ctx.temp_allocator) or_return
    ctx.mouse_releases = make([dynamic]Mouse_Button, ctx.temp_allocator) or_return
    ctx.key_presses = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    ctx.key_repeats = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    ctx.key_releases = make([dynamic]Keyboard_Key, ctx.temp_allocator) or_return
    strings.builder_init(&ctx.text_input, ctx.temp_allocator) or_return
    return nil
}

_update_hover :: proc() {
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