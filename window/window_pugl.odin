package window

import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:runtime"
import "core:intrinsics"
import utf8 "core:unicode/utf8"
import gl "vendor:OpenGL"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import "pugl"

_open_gl_is_loaded: bool
@(thread_local) _odin_context: runtime.Context
@(thread_local) _world: ^pugl.World
@(thread_local) _window_count: int

Window :: struct {
    is_open: bool,
    title: string,
    min_size: Maybe(Vec2),
    max_size: Maybe(Vec2),
    swap_interval: int,
    dark_mode: bool,
    is_resizable: bool,
    double_buffer: bool,
    child_kind: Child_Kind,
    parent_handle: Native_Handle,

    last_visibility: bool,
    last_position: Vec2,
    last_size: Vec2,
    last_mouse_position: Vec2,

    background_color: Color,

    user_data: rawptr,
    event_proc: proc(^Window, any) -> bool,

    close_requested: bool,

    timer_id: uintptr,
    view: ^pugl.View,
    ctx: ^nvg.Context,

    mouse_button_states: [Mouse_Button]bool,
    key_states: [Keyboard_Key]bool,
}

update :: proc() {
    _odin_context = context
    if _world == nil {
        return
    }
    pugl.Update(_world, 0)
}

init :: proc(
    window: ^Window,
    title := "",
    position := Vec2{0, 0},
    size := Vec2{400, 300},
    min_size: Maybe(Vec2) = nil,
    max_size: Maybe(Vec2) = nil,
    background_color := Color{0, 0, 0, 0},
    swap_interval := 0,
    dark_mode := true,
    is_visible := true,
    is_resizable := true,
    double_buffer := true,
    child_kind := Child_Kind.None,
    parent_handle: Native_Handle = nil,
) {
    window.title = title
    window.last_position = position
    window.last_size = size
    window.min_size = min_size
    window.max_size = max_size
    window.background_color = background_color
    window.swap_interval = swap_interval
    window.dark_mode = dark_mode
    window.last_visibility = is_visible
    window.is_resizable = is_resizable
    window.double_buffer = double_buffer
    window.child_kind = child_kind
    window.parent_handle = parent_handle
    for button in Mouse_Button {
        window.mouse_button_states[button] = false
    }
    for key in Keyboard_Key {
        window.key_states[key] = false
    }
}

destroy :: proc(window: ^Window) {
    _force_close(window)
}

open :: proc(window: ^Window) -> bool {
    if window.is_open {
        return false
    }

    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)

    if _window_count == 0 {
        when ODIN_BUILD_MODE == .Dynamic {
            world_type := pugl.WorldType.MODULE
        } else {
            world_type := pugl.WorldType.PROGRAM
        }
        _world = pugl.NewWorld(world_type, {})

        world_id := fmt.tprint("WindowThread", _generate_id())
        pugl.SetWorldString(_world, .CLASS_NAME, strings.clone_to_cstring(world_id, context.temp_allocator))
    }

    if window.parent_handle != nil && window.child_kind == .None {
        window.child_kind = .Embedded
    }

    view := pugl.NewView(_world)

    pugl.SetViewString(view, .WINDOW_TITLE, strings.clone_to_cstring(window.title, context.temp_allocator))
    pugl.SetSizeHint(view, .DEFAULT_SIZE, u16(window.last_size.x), u16(window.last_size.y))

    if min_size, ok := window.min_size.?; ok {
        pugl.SetSizeHint(view, .MIN_SIZE, u16(min_size.x), u16(min_size.y))
    }

    if max_size, ok := window.max_size.?; ok {
        pugl.SetSizeHint(view, .MAX_SIZE, u16(max_size.x), u16(max_size.y))
    }

    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .STENCIL_BITS, 8)

    pugl.SetViewHint(view, .DARK_FRAME, window.dark_mode ? 1 : 0)
    pugl.SetViewHint(view, .RESIZABLE, window.is_resizable ? 1 : 0)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, window.double_buffer ? 1 : 0)
    pugl.SetViewHint(view, .SWAP_INTERVAL, i32(window.swap_interval))
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    #partial switch window.child_kind {
    case .Embedded:
        pugl.SetParentWindow(view, cast(uintptr)window.parent_handle)
    case .Transient:
        pugl.SetTransientParent(view, cast(uintptr)window.parent_handle)
    }

    pugl.SetHandle(view, window)
    pugl.SetEventFunc(view, _on_event)

    status := pugl.Realize(view)
    if status != .SUCCESS {
        pugl.FreeView(view)
        fmt.eprintln(pugl.Strerror(status))
        return false
    }

    pugl.SetPosition(view, c.int(window.last_position.x), c.int(window.last_position.y))

    if window.last_visibility {
        pugl.Show(view, .RAISE)
    }

    window.view = view
    window.is_open = true

    _window_count += 1

    pugl.EnterContext(view)
    if !_open_gl_is_loaded {
        gl.load_up_to(3, 3, pugl.gl_set_proc_address)
        _open_gl_is_loaded = true
    }

    window.ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
    send_event(window, Open_Event{})

    return true
}

// Asks the window to close itself when it gets the chance.
close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }
    event := pugl.EventType.CLOSE
    pugl.SendEvent(window.view, cast(^pugl.Event)(&event))
    window.close_requested = true
}

redraw :: proc(window: ^Window) {
    pugl.PostRedisplay(window.view)
}

native_handle :: proc(window: ^Window) -> Native_Handle {
    return cast(rawptr)pugl.GetNativeView(window.view)
}

activate_context :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
}

deactivate_context :: proc(window: ^Window) {
    pugl.LeaveContext(window.view)
}

is_open :: proc(window: ^Window) -> bool {
    return window.is_open
}

is_visible :: proc(window: ^Window) -> bool {
    if window.view != nil {
        return pugl.GetVisible(window.view)
    } else {
        return window.last_visibility
    }
}

set_visibility :: proc(window: ^Window, visibility: bool) {
    if window.view != nil {
        if visibility {
            pugl.Show(window.view, .RAISE)
        } else {
            pugl.Hide(window.view)
        }
    }
    window.last_visibility = visibility
}

position :: proc(window: ^Window) -> Vec2 {
    if window.view != nil {
        frame := pugl.GetFrame(window.view)
        return {f32(frame.x), f32(frame.y)}
    } else {
        return window.last_position
    }
}

set_position :: proc(window: ^Window, position: Vec2) {
    if window.view != nil {
        pugl.SetPosition(window.view, c.int(position.x), c.int(position.y))
    } else {
        window.last_position = position
    }
}

size :: proc(window: ^Window) -> Vec2 {
    if window.view != nil {
        frame := pugl.GetFrame(window.view)
        return {f32(frame.width), f32(frame.height)}
    } else {
        return window.last_size
    }
}

set_size :: proc(window: ^Window, size: Vec2) {
    if window.view != nil {
        pugl.SetSize(window.view, c.uint(size.x), c.uint(size.y))
    } else {
        window.last_size = size
    }
}

content_scale :: proc(window: ^Window) -> f32 {
    return f32(pugl.GetScaleFactor(window.view))
}

mouse_position :: proc(window: ^Window) -> Vec2 {
    return window.last_mouse_position
}

set_cursor_style :: proc(window: ^Window, style: Cursor_Style) {
    pugl.SetCursor(window.view, _cursor_style_to_pugl_cursor(style))
}

get_clipboard :: proc(window: ^Window) -> string {
    length: uint
    clipboard_cstring := cast(cstring)pugl.GetClipboard(window.view, 0, &length)
    return string(clipboard_cstring)
}

set_clipboard :: proc(window: ^Window, data: string) {
    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)
    data_cstring := strings.clone_to_cstring(data, context.temp_allocator)
    pugl.SetClipboard(window.view, "text/plain", cast(rawptr)data_cstring, len(data_cstring) + 1)
}

mouse_down :: proc(window: ^Window, button: Mouse_Button) -> bool {
    return window.mouse_button_states[button]
}

key_down :: proc(window: ^Window, key: Keyboard_Key) -> bool {
    return window.key_states[key]
}


//====================================================================================
// Vector Graphics
//====================================================================================


Paint :: nvg.Paint

Path_Winding :: enum {
    Positive,
    Negative,
}

Font :: struct {
    name: string,
    data: []byte,
}

Glyph :: struct {
    rune_position: int,
    left: f32,
    right: f32,
    draw_offset_x: f32,
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

transform_identity :: proc(t: ^[6]f32) {
    t[0] = 1.0
    t[1] = 0.0
    t[2] = 0.0
    t[3] = 1.0
    t[4] = 0.0
    t[5] = 0.0
}

transform_rotate :: proc(t: ^[6]f32, angle: f32) {
    cs := math.cos(angle)
    sn := math.sin(angle)
    t[0] = cs
    t[1] = sn
    t[2] = -sn
    t[3] = cs
    t[4] = 0.0
    t[5] = 0.0
}

linear_gradient :: proc(start, finish: Vec2, inner_color, outer_color: Color) -> Paint {
    large :: 1e5

    dx, dy, d: f32

    // Calculate transform aligned to the line
    dx = finish.x - start.x
    dy = finish.y - start.y
    d = math.sqrt(dx * dx + dy * dy)

    if d > 0.0001 {
        dx /= d
        dy /= d
    } else {
        dx = 0
        dy = 1
    }

    paint: Paint

    paint.xform[0] = dy
    paint.xform[1] = -dx
    paint.xform[2] = dx
    paint.xform[3] = dy
    paint.xform[4] = start.x - dx * large
    paint.xform[5] = start.y - dy * large

    paint.extent[0] = large
    paint.extent[1] = large + d * 0.5

    paint.radius = 0.0

    paint.feather = max(1.0, d)

    paint.innerColor = inner_color
    paint.outerColor = outer_color

    return paint
}

radial_gradient :: proc(center: Vec2, inner_radius, outer_radius: f32, inner_color, outer_color: Color) -> Paint {
    radius := (inner_radius + outer_radius) * 0.5
    feather := (outer_radius - inner_radius)

    paint: Paint

    transform_identity(&paint.xform)

    paint.xform[4] = center.x
    paint.xform[5] = center.y

    paint.extent[0] = radius
    paint.extent[1] = radius

    paint.radius = radius

    paint.feather = max(1.0, feather)

    paint.innerColor = inner_color
    paint.outerColor = outer_color

    return paint
}

box_gradient :: proc(position, size: Vec2, radius, feather: f32, inner_color, outer_color: Color) -> Paint {
    paint: Paint

    transform_identity(&paint.xform)

    paint.xform[4] = position.x + size.x * 0.5
    paint.xform[5] = position.y + size.y * 0.5

    paint.extent[0] = size.x * 0.5
    paint.extent[1] = size.y * 0.5

    paint.radius = radius

    paint.feather = max(1.0, feather)

    paint.innerColor = inner_color
    paint.outerColor = outer_color

    return paint
}

image_pattern :: proc(center, size: Vec2, angle: f32, image: int, alpha: f32) -> Paint {
    paint: Paint

    transform_rotate(&paint.xform, angle)

    paint.xform[4] = center.x
    paint.xform[5] = center.y

    paint.extent[0] = size.x
    paint.extent[1] = size.y

    paint.image = image

    paint.innerColor = {1, 1, 1, alpha}
    paint.outerColor = {1, 1, 1, alpha}

    return paint
}

begin_path :: proc(window: ^Window) {
    nvg.BeginPath(window.ctx)
}

close_path :: proc(window: ^Window) {
    nvg.ClosePath(window.ctx)
}

path_move_to :: proc(window: ^Window, position: Vec2) {
    nvg.MoveTo(window.ctx, position.x, position.y)
}

path_line_to :: proc(window: ^Window, position: Vec2) {
    nvg.LineTo(window.ctx, position.x, position.y)
}

path_arc_to :: proc(window: ^Window, p0, p1: Vec2, radius: f32) {
    nvg.ArcTo(window.ctx, p0.x, p0.y, p1.x, p1.y, radius)
}

path_circle :: proc(window: ^Window, center: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    nvg.Circle(window.ctx, center.x, center.y, radius)
    nvg.PathWinding(window.ctx, _path_winding_to_nvg_winding(winding))
}

path_rect :: proc(window: ^Window, position, size: Vec2, winding: Path_Winding = .Positive) {
    nvg.Rect(window.ctx, position.x, position.y, size.x, size.y)
    nvg.PathWinding(window.ctx, _path_winding_to_nvg_winding(winding))
}

path_rounded_rect_varying :: proc(window: ^Window, position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    nvg.RoundedRectVarying(window.ctx, position.x, position.y, size.x, size.y, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius)
    nvg.PathWinding(window.ctx, _path_winding_to_nvg_winding(winding))
}

path_rounded_rect :: proc(window: ^Window, position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    path_rounded_rect_varying(window, position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(window: ^Window, paint: Paint) {
    nvg.FillPaint(window.ctx, paint)
    nvg.Fill(window.ctx)
}

fill_path :: proc(window: ^Window, color: Color) {
    fill_path_paint(window, solid_paint(color))
}

stroke_path_paint :: proc(window: ^Window, paint: Paint, width := f32(1)) {
    nvg.StrokeWidth(window.ctx, width)
    nvg.StrokePaint(window.ctx, paint)
    nvg.Stroke(window.ctx)
}

stroke_path :: proc(window: ^Window, color: Color, width := f32(1)) {
    stroke_path_paint(window, solid_paint(color), width)
}

translate_path :: proc(window: ^Window, amount: Vec2) {
    nvg.Translate(window.ctx, amount.x, amount.y)
}


//====================================================================================
// Private
//====================================================================================


_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
}

_generate_id :: proc "contextless" () -> u64 {
    @(static) id: u64
    return 1 + intrinsics.atomic_add(&id, 1)
}

// It is not safe for a window to close itself this way.
_force_close :: proc(window: ^Window) {
    if !window.is_open {
        return
    }

    view := window.view

    pugl.EnterContext(view)

    window.last_visibility = pugl.GetVisible(view)

    send_event(window, Close_Event{})
    nvg_gl.Destroy(window.ctx)

    pugl.Unrealize(view)
    pugl.FreeView(view)

    window.view = nil
    window.is_open = false

    _window_count -= 1

    if _window_count == 0 {
        pugl.FreeWorld(_world)
        _world = nil
    }
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    window := cast(^Window)pugl.GetHandle(view)
    context = _odin_context

    #partial switch event.type {
    case .EXPOSE:
        size := size(window)
        gl.Viewport(0, 0, i32(size.x), i32(size.y))
        c := window.background_color
        gl.ClearColor(c.r, c.g, c.b, c.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        nvg.BeginFrame(window.ctx, size.x, size.y, 1)
        send_event(window, Draw_Event{})
        nvg.EndFrame(window.ctx)

    case .UPDATE:
        pugl.EnterContext(view)

        is_visible := pugl.GetVisible(view)
        if is_visible != window.last_visibility {
            if is_visible {
                send_event(window, Show_Event{})
            } else {
                send_event(window, Hide_Event{})
            }
            window.last_visibility = is_visible
        }

        send_event(window, Update_Event{})

    case .LOOP_ENTER:
        pugl.StartTimer(view, window.timer_id, 0)

    case .LOOP_LEAVE:
        pugl.StopTimer(view, window.timer_id)

    case .TIMER:
        event := event.timer
        if window.timer_id == event.id {
            update()
        }

    case .CONFIGURE:
        event := event.configure

        pugl.EnterContext(view)

        position := Vec2{f32(event.x), f32(event.y)}
        size := Vec2{f32(event.width), f32(event.height)}

        if position != window.last_position {
            send_event(window, Move_Event{
                position = position,
                delta = position - window.last_position,
            })
        }

        if size != window.last_size {
            send_event(window, Resize_Event{
                size = size,
                delta = size - window.last_size,
            })
        }

        window.last_position = position
        window.last_size = size

    case .MOTION:
        event := event.motion

        pugl.EnterContext(view)

        position := Vec2{f32(event.x), f32(event.y)}

        send_event(window, Mouse_Move_Event{
            position = position,
            delta = position - window.last_mouse_position,
        })

        window.last_mouse_position = position

    case .POINTER_IN:
        event := event.crossing
        pugl.EnterContext(view)
        send_event(window, Mouse_Enter_Event{
            position = Vec2{f32(event.x), f32(event.y)},
        })

    case .POINTER_OUT:
        event := event.crossing
        pugl.EnterContext(view)
        send_event(window, Mouse_Exit_Event{
            position = Vec2{f32(event.x), f32(event.y)},
        })

    case .FOCUS_IN:
        pugl.EnterContext(view)
        send_event(window, Gain_Focus_Event{})

    case .FOCUS_OUT:
        pugl.EnterContext(view)
        send_event(window, Lose_Focus_Event{})

    case .SCROLL:
        event := &event.scroll
        pugl.EnterContext(view)
        send_event(window, Mouse_Scroll_Event{
            position = window.last_mouse_position,
            amount = {f32(event.dx), f32(event.dy)},
        })

    case .BUTTON_PRESS:
        event := &event.button
        pugl.EnterContext(view)
        button := _pugl_button_to_mouse_button(event.button)
        window.mouse_button_states[button] = true
        send_event(window, Mouse_Press_Event{
            position = window.last_mouse_position,
            button = button,
        })

    case .BUTTON_RELEASE:
        event := &event.button
        pugl.EnterContext(view)
        button := _pugl_button_to_mouse_button(event.button)
        window.mouse_button_states[button] = false
        send_event(window, Mouse_Release_Event{
            position = window.last_mouse_position,
            button = button,
        })

    case .KEY_PRESS:
        event := &event.key
        pugl.EnterContext(view)
        key := _pugl_key_event_to_keyboard_key(event)
        was_already_down := window.key_states[key]
        window.key_states[key] = true
        if was_already_down {
            send_event(window, Key_Repeat_Event{
                key = key,
            })
        } else {
            send_event(window, Key_Press_Event{
                key = key,
            })
        }

    case .KEY_RELEASE:
        event := &event.key
        pugl.EnterContext(view)
        key := _pugl_key_event_to_keyboard_key(event)
        window.key_states[key] = false
        send_event(window, Key_Release_Event{
            key = key,
        })

    case .TEXT:
        event := &event.text
        pugl.EnterContext(view)

        // Filter out backspace, enter, tab, and escape.
        skip := false
        switch event.character {
        case 8, 9, 13, 27: skip = true
        }

        if !skip {
            r, len := utf8.decode_rune(event.string[:4])
            send_event(window, Text_Event{
                text = r,
            })
        }

    case .CLOSE:
        _force_close(window)
        window.close_requested = false
    }

    return .SUCCESS
}

_pugl_key_event_to_keyboard_key :: proc(event: ^pugl.KeyEvent) -> Keyboard_Key {
    #partial switch event.key {
    case .BACKSPACE: return .Backspace
    case .ENTER: return .Enter
    case .ESCAPE: return .Escape
    case .DELETE: return .Delete
    case .SPACE: return .Space
    case .F1: return .F1
    case .F2: return .F2
    case .F3: return .F3
    case .F4: return .F4
    case .F5: return .F5
    case .F6: return .F6
    case .F7: return .F7
    case .F8: return .F8
    case .F9: return .F9
    case .F10: return .F10
    case .F11: return .F11
    case .F12: return .F12
    case .PAGE_UP: return .Page_Up
    case .PAGE_DOWN: return .Page_Down
    case .END: return .End
    case .HOME: return .Home
    case .LEFT: return .Left_Arrow
    case .UP: return .Up_Arrow
    case .RIGHT: return .Right_Arrow
    case .DOWN: return .Down_Arrow
    case .PRINT_SCREEN: return .Print_Screen
    case .INSERT: return .Insert
    case .PAUSE: return .Pause
    case .NUM_LOCK: return .Num_Lock
    case .SCROLL_LOCK: return .Scroll_Lock
    case .CAPS_LOCK: return .Caps_Lock
    case .SHIFT_L: return .Left_Shift
    case .SHIFT_R: return .Right_Shift
    case .CTRL_L: return .Right_Control // Switched for some reason
    case .CTRL_R: return .Left_Control // Switched for some reason
    case .ALT_L: return .Right_Alt // Switched for some reason
    case .ALT_R: return .Left_Alt // Switched for some reason
    case .SUPER_L: return .Left_Meta
    case .SUPER_R: return .Right_Meta
    case .PAD_0: return .Pad_0
    case .PAD_1: return .Pad_1
    case .PAD_2: return .Pad_2
    case .PAD_3: return .Pad_3
    case .PAD_4: return .Pad_4
    case .PAD_5: return .Pad_5
    case .PAD_6: return .Pad_6
    case .PAD_7: return .Pad_7
    case .PAD_8: return .Pad_8
    case .PAD_9: return .Pad_9
    case .PAD_ENTER: return .Pad_Enter
    case .PAD_MULTIPLY: return .Pad_Multiply
    case .PAD_ADD: return .Pad_Add
    case .PAD_SUBTRACT: return .Pad_Subtract
    case .PAD_DECIMAL: return .Pad_Decimal
    case .PAD_DIVIDE: return .Pad_Divide
    case:
        switch int(event.key) {
        case 9: return .Tab
        case 96: return .Backtick
        case 49: return .Key_1
        case 50: return .Key_2
        case 51: return .Key_3
        case 52: return .Key_4
        case 53: return .Key_5
        case 54: return .Key_6
        case 55: return .Key_7
        case 56: return .Key_8
        case 57: return .Key_9
        case 48: return .Key_0
        case 45: return .Minus
        case 61: return .Equal
        case 113: return .Q
        case 119: return .W
        case 101: return .E
        case 114: return .R
        case 116: return .T
        case 121: return .Y
        case 117: return .U
        case 105: return .I
        case 111: return .O
        case 112: return .P
        case 91: return .Left_Bracket
        case 93: return .Right_Bracket
        case 92: return .Backslash
        case 97: return .A
        case 115: return .S
        case 100: return .D
        case 102: return .F
        case 103: return .G
        case 104: return .H
        case 106: return .J
        case 107: return .K
        case 108: return .L
        case 59: return .Semicolon
        case 39: return .Apostrophe
        case 122: return .Z
        case 120: return .X
        case 99: return .C
        case 118: return .V
        case 98: return .B
        case 110: return .N
        case 109: return .M
        case 44: return .Comma
        case 46: return .Period
        case 47: return .Slash
        case 57502: return .Pad_0
        case 57459: return .Pad_1
        case 57464: return .Pad_2
        case 57458: return .Pad_3
        case 57461: return .Pad_4
        case 57501: return .Pad_5
        case 57463: return .Pad_6
        case 57460: return .Pad_7
        case 57462: return .Pad_8
        case 57457: return .Pad_9
        case 57503: return .Pad_Decimal
        }
    }
    return .Unknown
}

_pugl_button_to_mouse_button :: proc(button: u32) -> Mouse_Button {
    switch button {
    case 0: return .Left
    case 1: return .Right
    case 2: return .Middle
    case 3: return .Extra_1
    case 4: return .Extra_2
    case: return .Unknown
    }
}

_cursor_style_to_pugl_cursor :: proc(style: Cursor_Style) -> pugl.Cursor {
    switch style {
    case .Arrow: return .ARROW
    case .I_Beam: return .CARET
    case .Crosshair: return .CROSSHAIR
    case .Hand: return .HAND
    case .Resize_Left_Right: return .LEFT_RIGHT
    case .Resize_Top_Bottom: return .UP_DOWN
    case .Resize_Top_Left_Bottom_Right: return .UP_LEFT_DOWN_RIGHT
    case .Resize_Top_Right_Bottom_Left: return .UP_RIGHT_DOWN_LEFT
    case .Scroll: return .ALL_SCROLL
    }
    return .ARROW
}