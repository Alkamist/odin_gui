package gui

import "core:fmt"
import "core:time"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import gl "vendor:OpenGL"
import backend "window"

@(thread_local) ctx: Context

Vec2 :: [2]f32
Color :: [4]f32
Paint :: nvg.Paint

Font :: struct {
    name: string,
    data: []byte,
}

Native_Handle :: backend.Native_Handle
Child_Kind :: backend.Child_Kind
Cursor_Style :: backend.Cursor_Style
Mouse_Button :: backend.Mouse_Button
Keyboard_Key :: backend.Keyboard_Key

Path_Winding :: enum {
    Positive,
    Negative,
}

Window_Parameters :: struct {
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    resizable: bool,
    double_buffer: bool,
    background_color: Color,
    child_kind: Child_Kind,
    parent_handle: Native_Handle,
}

default_window_parameters := Window_Parameters{
    min_size = nil,
    max_size = nil,
    swap_interval = 0,
    dark_mode = true,
    resizable = true,
    double_buffer = true,
    background_color = {0, 0, 0, 1},
    child_kind = .None,
    parent_handle = nil,
}

Window :: struct {
    id: string,

    mouse_position: Vec2,
    global_mouse_position: Vec2,
    previous_global_mouse_position: Vec2,
    mouse_wheel_state: Vec2,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,

    background_color: Color,

    is_hovered: bool,
    open_requested: bool,
    reopen_pending: bool,

    pending_position: Maybe(Vec2),
    pending_size: Maybe(Vec2),
    pending_visibility: Maybe(bool),

    parameters: Window_Parameters,
    previous_parameters: Window_Parameters,

    nvg_ctx: ^nvg.Context,
    current_font: ^Font,
    current_font_size: f32,

    child_windows: map[string]^Window,
    loaded_fonts: [dynamic]^Font,

    backend_window: backend.Window,
}

Context :: struct {
    on_update: proc(),
    dummy_window: backend.Window,
    current_window: ^Window,
    top_level_windows: map[string]^Window,
    window_stack: [dynamic]^Window,
    default_font: ^Font,
    tick: time.Tick,
    previous_tick: time.Tick,
    host_handle: Native_Handle,
}

create_font :: proc(name: string, data: []byte) -> ^Font {
    font := new(Font)
    font.name = name
    font.data = data
    return font
}

destroy_font :: proc(font: ^Font) {
    free(font)
}

startup :: proc(app_id: string, default_font: ^Font, on_update: proc()) {
    backend.startup(app_id)

    err := backend.open(&ctx.dummy_window,
        title = "",
        size = {400, 300},
        min_size = nil,
        max_size = nil,
        swap_interval = 0,
        dark_mode = true,
        resizable = true,
        double_buffer = true,
        child_kind = .None,
        parent_handle = nil,
    )
    if err != nil {
        fmt.eprintln("Failed to create gui context.")
        return
    }

    ctx.default_font = default_font
    ctx.dummy_window.user_data = &ctx

    ctx.tick = time.tick_now()
    ctx.previous_tick = ctx.tick

    backend.activate_context(&ctx.dummy_window)
    gl.load_up_to(3, 3, backend.gl_set_proc_address)
    backend.deactivate_context(&ctx.dummy_window)

    ctx.on_update = on_update

    backend._update_proc = proc() {
        ctx.previous_tick = ctx.tick
        ctx.tick = time.tick_now()
        ctx.on_update()
    }
}

shutdown :: proc() {
    backend.close(&ctx.dummy_window)

    // Clean up windows.
    for key in ctx.top_level_windows {
        w := ctx.top_level_windows[key]
        _close_window(w)
        _destroy_window(w)
    }

    backend.shutdown()

    delete(ctx.top_level_windows)
    delete(ctx.window_stack)
}

update :: backend.update

current_window :: proc() -> ^Window {
    return ctx.current_window
}

begin_window :: proc(id: string, initial_parameters: Window_Parameters, initial_size: Vec2) -> bool {
    window_map: ^map[string]^Window
    if ctx.current_window == nil {
        window_map = &ctx.top_level_windows
    } else {
        window_map = &ctx.current_window.child_windows
    }

    w, exists := window_map[id]
    if !exists {
        w = new(Window)
        w.id = id
        w.parameters = initial_parameters
        w.previous_parameters = initial_parameters
        window_map[id] = w
    }

    if w.open_requested || !exists {
        if !_open_window(w, initial_size) {
            fmt.eprintf("Failed to open window: %v\n", id)
            return false
        }
        backend.show(&w.backend_window)
        w.open_requested = false
    }

    if !backend.is_open(&w.backend_window) {
        return false
    }

    backend.activate_context(&w.backend_window)

    append(&ctx.window_stack, w)
    ctx.current_window = w

    _sync_backend_window(w)

    bg := w.background_color

    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    content_scale := backend.content_scale(&w.backend_window)
    size := backend.size(&w.backend_window)

    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    nvg.BeginFrame(w.nvg_ctx, size.x, size.y, content_scale)
    nvg.TextAlign(w.nvg_ctx, .LEFT, .TOP)
    w.current_font = ctx.default_font
    w.current_font_size = 16.0

    return true
}

end_window :: proc() {
    assert(len(ctx.window_stack) > 0, "Mismatch in begin_window and end_window calls.")
    w := pop(&ctx.window_stack)

    backend.activate_context(&w.backend_window)
    nvg.EndFrame(w.nvg_ctx)

    _sync_backend_window(w)

    if w.backend_window.close_requested {
        _close_window(w)
    }

    clear(&w.mouse_presses)
    clear(&w.mouse_releases)
    clear(&w.key_presses)
    clear(&w.key_releases)
    strings.builder_reset(&w.text_input)
    w.mouse_wheel_state = {0, 0}
    w.previous_global_mouse_position = w.global_mouse_position

    if len(ctx.window_stack) == 0 {
        ctx.current_window = nil
    } else {
        ctx.current_window = ctx.window_stack[len(ctx.window_stack) - 1]
        backend.activate_context(&ctx.current_window.backend_window)
    }
}

scoped_end_window :: proc(is_open: bool) {
    if is_open {
        end_window()
    }
}

@(deferred_out=scoped_end_window)
window :: proc(id: string, child_kind: Child_Kind = .None, initial_size: Vec2 = {400, 300}) -> bool {
    parameters := default_window_parameters
    parameters.child_kind = child_kind
    return begin_window(id, parameters, initial_size)
}

@(deferred_out=scoped_end_window)
child_window :: proc(id: string, initial_size: Vec2 = {400, 300}) -> bool {
    parameters := default_window_parameters
    parameters.child_kind = .Transient
    return begin_window(id, parameters, initial_size)
}

@(deferred_out=scoped_end_window)
embedded_window :: proc(id: string, initial_size: Vec2 = {400, 300}) -> bool {
    parameters := default_window_parameters
    parameters.child_kind = .Embedded
    return begin_window(id, parameters, initial_size)
}



delta_time :: proc() -> time.Duration {
    return time.tick_diff(ctx.previous_tick, ctx.tick)
}

set_window_background_color :: proc(color: Color, w := ctx.current_window) {
    if w == nil { return }
    w.background_color = color
}

window_position :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return backend.position(&w.backend_window)
}

set_window_position :: proc(position: Vec2, w := ctx.current_window) {
    if w == nil { return }
    w.pending_position = position
}

window_size :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return backend.size(&w.backend_window)
}

set_window_size :: proc(size: Vec2, w := ctx.current_window) {
    if w == nil { return }
    w.pending_size = size
}

open_window :: proc(w := ctx.current_window) {
    if w == nil { return }
    w.open_requested = true
}

close_window :: proc(w := ctx.current_window) {
    if w == nil { return }
    w.backend_window.close_requested = true
}

show_window :: proc(w := ctx.current_window) {
    if w == nil { return }
    w.pending_visibility = true
}

hide_window :: proc(w := ctx.current_window) {
    if w == nil { return }
    w.pending_visibility = false
}

window_is_visible :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return backend.is_visible(&w.backend_window)
}

window_will_close :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.backend_window.close_requested
}

window_is_hovered :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.is_hovered
}

mouse_position :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.mouse_position
}

global_mouse_position :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.global_mouse_position
}

mouse_delta :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.global_mouse_position - w.previous_global_mouse_position
}

mouse_down :: proc(button: Mouse_Button, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.mouse_down_states[button]
}

key_down :: proc(key: Keyboard_Key, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.key_down_states[key]
}

mouse_wheel :: proc(w := ctx.current_window) -> Vec2 {
    if w == nil { return {0, 0} }
    return w.mouse_wheel_state
}

mouse_moved :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return mouse_delta(w) != {0, 0}
}

mouse_wheel_moved :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return w.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.mouse_presses[:], button)
}

mouse_released :: proc(button: Mouse_Button, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.mouse_releases[:], button)
}

any_mouse_pressed :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.mouse_presses) > 0
}

any_mouse_released :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.key_presses[:], key)
}

key_released :: proc(key: Keyboard_Key, w := ctx.current_window) -> bool {
    if w == nil { return false }
    return slice.contains(w.key_releases[:], key)
}

any_key_pressed :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.key_presses) > 0
}

any_key_released :: proc(w := ctx.current_window) -> bool {
    if w == nil { return false }
    return len(w.key_releases) > 0
}

key_presses :: proc(w := ctx.current_window) -> []Keyboard_Key {
    if w == nil { return nil }
    return w.key_presses[:]
}

key_releases :: proc(w := ctx.current_window) -> []Keyboard_Key {
    if w == nil { return nil }
    return w.key_releases[:]
}

text_input :: proc(w := ctx.current_window) -> string {
    if w == nil { return "" }
    return strings.to_string(w.text_input)
}



solid_paint :: proc(color: Color) -> Paint {
    paint: Paint
    nvg.TransformIdentity(&paint.xform)
    paint.radius = 0.0
    paint.feather = 1.0
    paint.innerColor = color
    paint.outerColor = color
    return paint
}

begin_path :: proc() {
    nvg.BeginPath(ctx.current_window.nvg_ctx)
}

close_path :: proc() {
    nvg.ClosePath(ctx.current_window.nvg_ctx)
}

move_to :: proc(position: Vec2) {
    nvg.MoveTo(ctx.current_window.nvg_ctx, position.x, position.y)
}

line_to :: proc(position: Vec2) {
    nvg.LineTo(ctx.current_window.nvg_ctx, position.x, position.y)
}

arc_to :: proc(p0, p1: Vec2, radius: f32) {
    nvg.ArcTo(ctx.current_window.nvg_ctx, p0.x, p0.y, p1.x, p1.y, radius)
}

rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
    w := ctx.current_window
    nvg.Rect(w.nvg_ctx, position.x, position.y, size.x, size.y)
    nvg.PathWinding(w.nvg_ctx, _path_winding_to_nvg_winding(winding))
}

rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    w := ctx.current_window
    nvg.RoundedRectVarying(w.nvg_ctx,
        position.x, position.y, size.x, size.y,
        top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius,
    )
    nvg.PathWinding(w.nvg_ctx, _path_winding_to_nvg_winding(winding))
}

rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    rounded_rect_varying(position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(paint: Paint) {
    w := ctx.current_window
    nvg.FillPaint(w.nvg_ctx, paint)
    nvg.Fill(w.nvg_ctx)
}

fill_path :: proc(color: Color) {
    fill_path_paint(solid_paint(color))
}

fill_text_line :: proc(text: string, position: Vec2, color := Color{1, 1, 1, 1}, font := ctx.default_font, font_size: f32 = 13.0) {
    if len(text) == 0 {
        return
    }
    w := ctx.current_window
    _set_font(w, font)
    _set_font_size(w, font_size)
    nvg.FillColor(w.nvg_ctx, color)
    nvg.Text(w.nvg_ctx, position.x, position.y, text)
}

text_metrics :: proc(w: ^Window, font: ^Font, font_size: f32) -> (ascender, descender, line_height: f32) {
    _set_font(w, font)
    _set_font_size(w, font_size)
    return nvg.TextMetrics(w.nvg_ctx)
}



_set_font :: proc(w: ^Window, font: ^Font) {
    if !slice.contains(w.loaded_fonts[:], font) {
        id := nvg.CreateFontMem(w.nvg_ctx, font.name, font.data, false)
        if id == -1 {
            fmt.eprintf("Failed to load font: %v\n", font.name)
            return
        }
        append(&w.loaded_fonts, font)
    }
    if font == w.current_font {
        return
    }
    nvg.FontFace(w.nvg_ctx, font.name)
    w.current_font = font
}

_set_font_size :: proc(w: ^Window, font_size: f32) {
    if font_size == w.current_font_size {
        return
    }
    nvg.FontSize(w.nvg_ctx, font_size)
    w.current_font_size = font_size
}

_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
}

_open_window :: proc(w: ^Window, initial_size: Vec2) -> bool {
    backend_window := &w.backend_window
    if backend.is_open(backend_window) {
        return true
    }

    parameters := &w.parameters

    if parameters.child_kind != .None {
        if ctx.current_window != nil {
            parameters.parent_handle = backend.native_handle(&ctx.current_window.backend_window)
        } else {
            parameters.parent_handle  = ctx.host_handle
        }
    }

    err := backend.open(backend_window,
        title = w.id,
        size = initial_size,
        min_size = parameters.min_size,
        max_size = parameters.max_size,
        swap_interval = parameters.swap_interval,
        dark_mode = parameters.dark_mode,
        resizable = parameters.resizable,
        double_buffer = parameters.double_buffer,
        child_kind = parameters.child_kind,
        parent_handle = parameters.parent_handle,
    )

    if err != nil {
        return false
    }

    backend_window.user_data = w

    backend.activate_context(backend_window)
    w.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

    _setup_window_callbacks(w)

    return true
}

_close_window :: proc(w: ^Window) {
    backend_window := &w.backend_window
    if !backend.is_open(backend_window) {
        return
    }
    for _, child in w.child_windows {
        _close_window(child)
    }
    backend.activate_context(backend_window)
    nvg_gl.Destroy(w.nvg_ctx)
    w.nvg_ctx = nil
    backend.close(backend_window)
    clear(&w.loaded_fonts)
}

_destroy_window :: proc(w: ^Window) {
    for _, child in w.child_windows {
        _destroy_window(child)
    }
    delete(w.mouse_presses)
    delete(w.mouse_releases)
    delete(w.key_presses)
    delete(w.key_releases)
    strings.builder_destroy(&w.text_input)
    delete(w.child_windows)
    delete(w.loaded_fonts)
    free(w)
}

_sync_backend_window :: proc(w: ^Window) {
    backend_window := &w.backend_window
    if !backend.is_open(backend_window) {
        return
    }

    if position, ok := w.pending_position.?; ok {
        backend.set_position(backend_window, position)
        w.pending_position = nil
    }
    if size, ok := w.pending_size.?; ok {
        backend.set_position(backend_window, size)
        w.pending_size = nil
    }
    if is_visible, ok := w.pending_visibility.?; ok {
        if is_visible {
            backend.show(backend_window)
        } else {
            backend.hide(backend_window)
        }
        w.pending_visibility = nil
    }

    // Changing parameters requires a window reload.
    if w.parameters != w.previous_parameters {
        w.reopen_pending = true
    }

    w.previous_parameters = w.parameters
}

_setup_window_callbacks :: proc(w: ^Window) {
    backend.set_on_mouse_move(&w.backend_window, proc(backend_window: ^backend.Window, position, global_position: [2]f32) {
        w := cast(^Window)backend_window.user_data
        w.mouse_position = position
        w.global_mouse_position = global_position
    })
    backend.set_on_mouse_enter(&w.backend_window, proc(backend_window: ^backend.Window) {
        w := cast(^Window)backend_window.user_data
        w.is_hovered = true
    })
    backend.set_on_mouse_exit(&w.backend_window, proc(backend_window: ^backend.Window) {
        w := cast(^Window)backend_window.user_data
        w.is_hovered = false
    })
    backend.set_on_mouse_wheel(&w.backend_window, proc(backend_window: ^backend.Window, amount: [2]f32) {
        w := cast(^Window)backend_window.user_data
        w.mouse_wheel_state = amount
    })
    backend.set_on_mouse_press(&w.backend_window, proc(backend_window: ^backend.Window, button: Mouse_Button) {
        w := cast(^Window)backend_window.user_data
        w.mouse_down_states[button] = true
        append(&w.mouse_presses, button)
    })
    backend.set_on_mouse_release(&w.backend_window, proc(backend_window: ^backend.Window, button: Mouse_Button) {
        w := cast(^Window)backend_window.user_data
        w.mouse_down_states[button] = false
        append(&w.mouse_releases, button)
    })
    backend.set_on_key_press(&w.backend_window, proc(backend_window: ^backend.Window, key: Keyboard_Key) {
        w := cast(^Window)backend_window.user_data
        w.key_down_states[key] = true
        append(&w.key_presses, key)
    })
    backend.set_on_key_release(&w.backend_window, proc(backend_window: ^backend.Window, key: Keyboard_Key) {
        w := cast(^Window)backend_window.user_data
        w.key_down_states[key] = false
        append(&w.key_releases, key)
    })
    backend.set_on_rune(&w.backend_window, proc(backend_window: ^backend.Window, r: rune) {
        w := cast(^Window)backend_window.user_data
        strings.write_rune(&w.text_input, r)
    })
}