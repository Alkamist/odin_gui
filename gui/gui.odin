package gui

import "core:fmt"
import "core:time"
import "core:slice"
import "core:strings"
import "core:intrinsics"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import gl "vendor:OpenGL"
import wnd "window"

@(thread_local) ctx: Context

Vec2 :: [2]f32
Color :: [4]f32
Paint :: nvg.Paint

Font :: struct {
    name: string,
    data: []byte,
}

Native_Handle :: wnd.Native_Handle
Child_Kind :: wnd.Child_Kind
Cursor_Style :: wnd.Cursor_Style
Mouse_Button :: wnd.Mouse_Button
Keyboard_Key :: wnd.Keyboard_Key

Path_Winding :: enum {
    Positive,
    Negative,
}

Window :: struct {
    using window: wnd.Window,

    background_color: Color,

    is_hovered: bool,
    mouse_position: Vec2,
    previous_mouse_position: Vec2,
    mouse_wheel_state: Vec2,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,

    nvg_ctx: ^nvg.Context,
    current_font: ^Font,
    current_font_size: f32,

    child_windows: map[string]^Window,
    loaded_fonts: [dynamic]^Font,
}

Context :: struct {
    on_update: proc(),
    dummy_window: wnd.Window,
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
    wnd.startup(app_id)

    ctx.dummy_window.size = {512, 512}
    ctx.dummy_window.double_buffer = true

    err := wnd.open(&ctx.dummy_window)
    if err != nil {
        fmt.eprintln("Failed to create gui context.")
        return
    }

    ctx.default_font = default_font
    ctx.dummy_window.user_data = &ctx

    ctx.tick = time.tick_now()
    ctx.previous_tick = ctx.tick

    wnd.activate_context(&ctx.dummy_window)
    gl.load_up_to(3, 3, wnd.gl_set_proc_address)
    wnd.deactivate_context(&ctx.dummy_window)

    ctx.on_update = on_update

    wnd._update_proc = proc() {
        ctx.previous_tick = ctx.tick
        ctx.tick = time.tick_now()
        ctx.on_update()
    }
}

shutdown :: proc() {
    wnd.close(&ctx.dummy_window)

    // Clean up windows.
    for key in ctx.top_level_windows {
        w := ctx.top_level_windows[key]
        _close_window(w)
        _destroy_window(w)
    }

    wnd.shutdown()

    delete(ctx.top_level_windows)
    delete(ctx.window_stack)
}

update :: wnd.update

begin_window :: proc(id: string, child_kind := Child_Kind.None) -> bool {
    window_map: ^map[string]^Window

    is_in_scope_of_other_window := false

    if ctx.current_window == nil {
        window_map = &ctx.top_level_windows
    } else {
        window_map = &ctx.current_window.child_windows
        is_in_scope_of_other_window = true
    }

    w, exists := window_map[id]

    if !exists {
        w = new(Window)
        w.title = id
        w.size = {400, 300}
        w.min_size = nil
        w.max_size = nil
        w.swap_interval = 0
        w.dark_mode = true
        w.resizable = true
        w.double_buffer = true
        w.child_kind = child_kind

        if child_kind != .None {
            if is_in_scope_of_other_window {
                w.parent_handle = wnd.native_handle(ctx.current_window)
            } else {
                w.parent_handle  = ctx.host_handle
            }
        }

        err := wnd.open(&w.window)
        if err != nil {
            free(w)
            fmt.eprintf("Failed to open window: %v\n", id)
            return false
        }

        w.window.user_data = w

        window_map[id] = w

        wnd.activate_context(w)
        w.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})

        _setup_window_callbacks(w)
        wnd.show(w)
    }

    if !w.is_open {
        return false
    }

    wnd.activate_context(w)

    append(&ctx.window_stack, w)
    ctx.current_window = w

    size := wnd.size(w)
    content_scale := wnd.content_scale(w)

    bg := w.background_color
    gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)

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

    wnd.activate_context(w)
    nvg.EndFrame(w.nvg_ctx)

    clear(&w.mouse_presses)
    clear(&w.mouse_releases)
    clear(&w.key_presses)
    clear(&w.key_releases)
    strings.builder_reset(&w.text_input)
    w.mouse_wheel_state = {0, 0}
    w.previous_mouse_position = w.mouse_position

    if wnd.close_requested(w) {
        _close_window(w)
    }

    if len(ctx.window_stack) == 0 {
        ctx.current_window = nil
    } else {
        ctx.current_window = ctx.window_stack[len(ctx.window_stack) - 1]
        wnd.activate_context(ctx.current_window)
    }
}

// @(deferred_out=scoped_end_window)
// window :: proc(
//     id: string,
//     size := Vec2{400, 300},
//     min_size: Maybe(Vec2) = nil,
//     max_size: Maybe(Vec2) = nil,
//     swap_interval := 0,
//     dark_mode := true,
//     resizable := true,
//     double_buffer := true,
//     child_kind: Child_Kind = .None,
//     parent_handle: Native_Handle = nil,
// ) -> bool {
//     return begin_window(
//         id,
//         size,
//         min_size,
//         max_size,
//         swap_interval,
//         dark_mode,
//         resizable,
//         double_buffer,
//         child_kind,
//         parent_handle,
//     )
// }

// scoped_end_window :: proc(is_open: bool) {
//     if is_open {
//         end_window()
//     }
// }



set_window_background_color :: proc(color: Color) {
    ctx.current_window.background_color = color
}

window_will_close :: proc() -> bool {
    return wnd.close_requested(ctx.current_window)
}

window_is_hovered :: proc() -> bool {
    return ctx.current_window.is_hovered
}

mouse_position :: proc() -> Vec2 {
    return ctx.current_window.mouse_position
}

mouse_delta :: proc() -> Vec2 {
    return ctx.current_window.mouse_position - ctx.current_window.previous_mouse_position
}

delta_time :: proc() -> time.Duration {
    return time.tick_diff(ctx.previous_tick, ctx.tick)
}

mouse_down :: proc(button: Mouse_Button) -> bool {
    return ctx.current_window.mouse_down_states[button]
}

key_down :: proc(key: Keyboard_Key) -> bool {
    return ctx.current_window.key_down_states[key]
}

mouse_wheel :: proc() -> Vec2 {
    return ctx.current_window.mouse_wheel_state
}

mouse_moved :: proc() -> bool {
    return mouse_delta() != {0, 0}
}

mouse_wheel_moved :: proc() -> bool {
    return ctx.current_window.mouse_wheel_state != {0, 0}
}

mouse_pressed :: proc(button: Mouse_Button) -> bool {
    return slice.contains(ctx.current_window.mouse_presses[:], button)
}

mouse_released :: proc(button: Mouse_Button) -> bool {
    return slice.contains(ctx.current_window.mouse_releases[:], button)
}

any_mouse_pressed :: proc() -> bool {
    return len(ctx.current_window.mouse_presses) > 0
}

any_mouse_released :: proc() -> bool {
    return len(ctx.current_window.mouse_releases) > 0
}

key_pressed :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(ctx.current_window.key_presses[:], key)
}

key_released :: proc(key: Keyboard_Key) -> bool {
    return slice.contains(ctx.current_window.key_releases[:], key)
}

any_key_pressed :: proc() -> bool {
    return len(ctx.current_window.key_presses) > 0
}

any_key_released :: proc() -> bool {
    return len(ctx.current_window.key_releases) > 0
}

key_presses :: proc() -> []Keyboard_Key {
    return ctx.current_window.key_presses[:]
}

key_releases :: proc() -> []Keyboard_Key {
    return ctx.current_window.key_releases[:]
}

text_input :: proc() -> string {
    return strings.to_string(ctx.current_window.text_input)
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

_close_window :: proc(w: ^Window) {
    if !w.is_open {
        return
    }
    for _, child in w.child_windows {
        _close_window(child)
    }
    wnd.activate_context(w)
    nvg_gl.Destroy(w.nvg_ctx)
    w.nvg_ctx = nil
    wnd.close(w)
    clear(&w.loaded_fonts)
}

_setup_window_callbacks :: proc(w: ^Window) {
    wnd.set_on_mouse_move(w, proc(_w: ^wnd.Window, position: [2]f32) {
        w := cast(^Window)_w.user_data
        w.mouse_position = position
    })
    wnd.set_on_mouse_enter(w, proc(_w: ^wnd.Window) {
        w := cast(^Window)_w.user_data
        w.is_hovered = true
    })
    wnd.set_on_mouse_exit(w, proc(_w: ^wnd.Window) {
        w := cast(^Window)_w.user_data
        w.is_hovered = false
    })
    wnd.set_on_mouse_wheel(w, proc(_w: ^wnd.Window, amount: [2]f32) {
        w := cast(^Window)_w.user_data
        w.mouse_wheel_state = amount
    })
    wnd.set_on_mouse_press(w, proc(_w: ^wnd.Window, button: Mouse_Button) {
        w := cast(^Window)_w.user_data
        w.mouse_down_states[button] = true
        append(&w.mouse_presses, button)
    })
    wnd.set_on_mouse_release(w, proc(_w: ^wnd.Window, button: Mouse_Button) {
        w := cast(^Window)_w.user_data
        w.mouse_down_states[button] = false
        append(&w.mouse_releases, button)
    })
    wnd.set_on_key_press(w, proc(_w: ^wnd.Window, key: Keyboard_Key) {
        w := cast(^Window)_w.user_data
        w.key_down_states[key] = true
        append(&w.key_presses, key)
    })
    wnd.set_on_key_release(w, proc(_w: ^wnd.Window, key: Keyboard_Key) {
        w := cast(^Window)_w.user_data
        w.key_down_states[key] = false
        append(&w.key_releases, key)
    })
    wnd.set_on_rune(w, proc(_w: ^wnd.Window, r: rune) {
        w := cast(^Window)_w.user_data
        strings.write_rune(&w.text_input, r)
    })
}