package gui

import "pugl"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:runtime"
import utf8 "core:unicode/utf8"
import gl "vendor:OpenGL"

world: ^pugl.World

startup_window_manager :: proc() {
    when ODIN_BUILD_MODE == .Dynamic {
        world_type := pugl.WorldType.MODULE
    } else {
        world_type := pugl.WorldType.PROGRAM
    }
    world = pugl.NewWorld(world_type, {})
    pugl.SetWorldString(world, .CLASS_NAME, "WindowManager")
}

shutdown_window_manager :: proc() {
    pugl.FreeWorld(world)
}

update_window_manager :: proc() {
    pugl.Update(world, 0.0)
}

Window :: struct {
    view: ^pugl.View,
}

init_window :: proc(ctx: ^Context, title: string) {
    title := strings.clone_to_cstring(title)
    defer delete(title)

    view := pugl.NewView(world)

    input_size(ctx, {512, 512})

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
        fmt.eprintln("A window failed to open.")
    }

    ctx.window_is_open = true
    ctx.window.view = view

    pugl.SetHandle(view, ctx)

    activate_gl_context(ctx)
    gl.load_up_to(3, 3, pugl.gl_set_proc_address)
	deactivate_gl_context(ctx)
}

destroy_window :: proc(ctx: ^Context) {
    pugl.FreeView(ctx.window.view)
}

activate_gl_context :: proc(ctx: ^Context) {
    pugl.EnterContext(ctx.window.view)
}

deactivate_gl_context :: proc(ctx: ^Context) {
    pugl.EnterContext(ctx.window.view)
}

show :: proc(ctx: ^Context) {
    pugl.Show(ctx.window.view, .RAISE)
}

hide :: proc(ctx: ^Context) {
    pugl.Hide(ctx.window.view)
}

close :: proc(ctx: ^Context) {
    ctx.window_is_open = false
    pugl.Unrealize(ctx.window.view)
}

_on_event :: proc "c" (view: ^pugl.View, event: ^pugl.Event) -> pugl.Status {
    context = runtime.default_context()

    ctx := cast(^Context)pugl.GetHandle(view)

    #partial switch event.type {

    case .EXPOSE:
        input_content_scale(ctx, f32(pugl.GetScaleFactor(view)))

        bg := ctx.background_color
        gl.ClearColor(bg.r, bg.g, bg.b, bg.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        if ctx.on_frame != nil {
            ctx->on_frame()
        }

    case .UPDATE:
        pugl.PostRedisplay(view)

    case .CONFIGURE:
        event := event.configure
        input_size(ctx, {f32(event.width), f32(event.height)})

    case .MOTION:
        event := event.motion
        input_mouse_move(ctx, {f32(event.x), f32(event.y)})

    case .POINTER_IN:
        input_mouse_enter(ctx)

    case .POINTER_OUT:
        input_mouse_exit(ctx)

    case .SCROLL:
        event := &event.scroll
        input_mouse_wheel(ctx, {f32(event.dx), f32(event.dy)})

    case .BUTTON_PRESS:
        event := &event.button
        input_mouse_press(ctx, _pugl_button_to_mouse_button(event.button))

    case .BUTTON_RELEASE:
        event := &event.button
        input_mouse_release(ctx, _pugl_button_to_mouse_button(event.button))

    case .KEY_PRESS:
        event := &event.key
        input_key_press(ctx, _pugl_key_event_to_keyboard_key(event))

    case .KEY_RELEASE:
        event := &event.key
        input_key_release(ctx, _pugl_key_event_to_keyboard_key(event))

    case .TEXT:
        event := &event.text
        r, len := utf8.decode_rune(event.string[:4])
        input_rune(ctx, r)

    case .CLOSE:
        close(ctx)

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