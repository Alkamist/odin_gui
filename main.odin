package main

import "core:unicode/utf8"
import "core:fmt"
import gl "vendor:OpenGL"
import wnd "os_window"
import vg "vector_graphics"
import "gui"

setup_gui :: proc(root: ^gui.Widget) {
    button := gui.add_button(root)
}

on_frame :: proc(window: ^wnd.Window, root: ^gui.Widget) {
    wnd.make_context_current(window)

    gl.ClearColor(0.05, 0.05, 0.05, 1.0)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    // gui.process_frame(root, )

    wnd.swap_buffers(window)
}

gui_impl_os_window :: proc(window: ^wnd.Window, root: ^gui.Widget) {
    window.user_ptr = root
    window.on_resize = proc(window: ^wnd.Window, width, height: int) {
        root := (^gui.Widget)(window.user_ptr)
        gui.input_resize(root, {f32(width), f32(height)})
        on_frame(window, root)
    }
    window.on_mouse_move = proc(window: ^wnd.Window, x, y: int) {
		root := (^gui.Widget)(window.user_ptr)
        gui.input_mouse_move(root, {f32(x), f32(y)})
    }
    window.on_mouse_press = proc(window: ^wnd.Window, button: wnd.Mouse_Button, x, y: int) {
        root := (^gui.Widget)(window.user_ptr)
        button := cast(gui.Mouse_Button)button
        gui.input_mouse_press(root, button, {f32(x), f32(y)})
    }
	window.on_mouse_release = proc(window: ^wnd.Window, button: wnd.Mouse_Button, x, y: int) {
        root := (^gui.Widget)(window.user_ptr)
        button := cast(gui.Mouse_Button)button
        gui.input_mouse_release(root, button, {f32(x), f32(y)})
    }
	window.on_mouse_wheel = proc(window: ^wnd.Window, x, y: f64) {
		root := (^gui.Widget)(window.user_ptr)
		gui.input_mouse_wheel(root, {f32(x), f32(y)})
	}
	window.on_key_press = proc(window: ^wnd.Window, key: wnd.Keyboard_Key) {
		root := (^gui.Widget)(window.user_ptr)
        key := cast(gui.Keyboard_Key)key
        gui.input_key_press(root, key)
	}
	window.on_key_release = proc(window: ^wnd.Window, key: wnd.Keyboard_Key) {
		root := (^gui.Widget)(window.user_ptr)
        key := cast(gui.Keyboard_Key)key
        gui.input_key_release(root, key)
	}
	window.on_rune = proc(window: ^wnd.Window, r: rune) {
		root := (^gui.Widget)(window.user_ptr)
		bytes, count := utf8.encode_rune(r)
		gui.input_text(root, string(bytes[:count]))
	}
}

main :: proc() {
    window := wnd.create()
    defer wnd.destroy(window)

    wnd.show(window)
    wnd.make_context_current(window)

    gl.load_up_to(3, 3, wnd.gl_set_proc_address)

    root := gui.new_root()
    defer gui.destroy(root)

    gui_impl_os_window(window, root)

    setup_gui(root)

    for wnd.is_open(window) {
        wnd.poll_events(window)
        on_frame(window, root)
    }
}