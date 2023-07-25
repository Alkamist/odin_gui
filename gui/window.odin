package gui

import "pugl"
import "core:time"
import "core:strings"
import "core:runtime"
import gl "vendor:OpenGL"

Window_Error :: enum {
    None,
    Failed_To_Open,
}

Window :: struct {
    on_frame: proc(window: ^Window),
    background_color: [4]f32,
    should_close: bool,
    highest_z_index: int,

    tick: time.Tick,
    is_hovered: bool,
    content_scale: f32,
    size: Vec2,
    global_mouse_position: Vec2,
    mouse_wheel_state: Vec2,
    mouse_presses: [dynamic]Mouse_Button,
    mouse_releases: [dynamic]Mouse_Button,
    mouse_down_states: [Mouse_Button]bool,
    key_presses: [dynamic]Keyboard_Key,
    key_releases: [dynamic]Keyboard_Key,
    key_down_states: [Keyboard_Key]bool,
    text_input: strings.Builder,

    offset_stack: [dynamic]Vec2,
    clip_region_stack: [dynamic]Region,
    layer_stack: [dynamic]Layer,

    layers: [dynamic]Layer,

    vg_ctx: ^Vg_Context,
    view: ^pugl.View,

    previous_global_mouse_position: Vec2,
    previous_tick: time.Tick,
}

create_window :: proc(title: cstring) -> (^Window, Window_Error) {
    view := pugl.NewView(world)

    pugl.SetViewString(view, .WINDOW_TITLE, title)
    pugl.SetSizeHint(view, .DEFAULT_SIZE, 512, 512)
    pugl.SetSizeHint(view, .MIN_SIZE, 128, 128)
    pugl.SetSizeHint(view, .MAX_SIZE, 1024, 1024)
    pugl.SetBackend(view, pugl.GlBackend())

    pugl.SetViewHint(view, .DARK_FRAME, 1)
    pugl.SetViewHint(view, .RESIZABLE, 1)
    pugl.SetViewHint(view, .SAMPLES, 1)
    pugl.SetViewHint(view, .DOUBLE_BUFFER, 1)
    pugl.SetViewHint(view, .SWAP_INTERVAL, 1)
    pugl.SetViewHint(view, .IGNORE_KEY_REPEAT, 0)

    pugl.SetEventFunc(view, _on_event)

    if pugl.Realize(view) != .SUCCESS {
        return nil, .Failed_To_Open
    }

    window := new(Window)
    window.view = view

    pugl.SetHandle(view, window)

    pugl.EnterContext(view)

    gl.load_up_to(3, 3, pugl.gl_set_proc_address)
    window.vg_ctx = new(Vg_Context)
    _vg_init_context(window.vg_ctx)

	pugl.LeaveContext(view)

    return window, .None
}

free_window :: proc(window: ^Window) {
    pugl.EnterContext(window.view)
    _vg_destroy_context(window.vg_ctx)
    pugl.LeaveContext(window.view)
    pugl.FreeView(window.view)

    delete(window.offset_stack)
    delete(window.layers)
    delete(window.layer_stack)
    free(window)
}

show_window :: proc(window: ^Window) {
    pugl.Show(window.view, .RAISE)
}

hide_window :: proc(window: ^Window) {
    pugl.Hide(window.view)
}

close_window :: proc(window: ^Window) {
    window.should_close = true
}

window_should_close :: proc(window: ^Window) -> bool {
    return window.should_close
}

set_window_background_color :: proc(window: ^Window, color: [4]f32) {
    window.background_color = color
}

set_window_on_frame_proc :: proc(window: ^Window, on_frame: proc(window: ^Window)) {
    window.on_frame = on_frame
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    context = runtime.default_context()

    window := cast(^Window)pugl.GetHandle(view)

    #partial switch event.type {

    case .EXPOSE:
        bg := window.background_color
        gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        if window.on_frame != nil {
            window->on_frame()
        }

    case .CLOSE:
        window.should_close = true

    }

    return .SUCCESS
}