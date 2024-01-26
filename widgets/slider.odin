package widgets

// import "../../gui"

// Slider :: struct {
//     using widget: gui.Widget,
//     is_grabbed: bool,
//     value: f32,
//     min_value: f32,
//     max_value: f32,
//     handle_length: f32,
//     value_when_handle_grabbed: f32,
//     // global_mouse_position_when_handle_grabbed: Vec2,
// }

// Slider_Grabbed_Event :: struct {}
// Slider_Released_Event :: struct {}

// create_slider :: proc(
//     position := Vec2{0, 0},
//     size := Vec2{300, 24},
//     value: f32 = 0,
//     min_value: f32 = 0,
//     max_value: f32 = 1,
//     handle_length: f32 = 16,
// ) -> ^Slider {
//     slider := gui.create_widget(Slider)
//     slider.event_proc = slider_event_proc
//     slider.position = position
//     slider.size = size
//     slider.value = clamp(value, min_value, max_value)
//     slider.min_value = min_value
//     slider.max_value = max_value
//     slider.handle_length = handle_length
//     return slider
// }

// destroy_slider :: proc(slider: ^Slider) {
//     gui.destroy_widget(slider)
// }

// slider_handle_position :: proc(slider: ^Slider) -> Vec2 {
//     return {
//         slider.position.x + (slider.size.x - slider.handle_length) * (slider.value - slider.min_value) / (slider.max_value - slider.min_value),
//         slider.position.y,
//     }
// }

// slider_handle_size :: proc(slider: ^Slider) -> Vec2 {
//     return {slider.handle_length, slider.size.y}
// }

// slider_event_proc :: proc(widget: ^gui.Widget, event: any) -> bool {
//     slider := cast(^Slider)widget

//     switch e in event {

//     case gui.Mouse_Pressed_Event:
//         slider.is_grabbed = true
//         gui.capture_hover()
//         gui.send_event(slider, Slider_Grabbed_Event{})

//     case gui.Mouse_Released_Event:
//         slider.is_grabbed = false
//         gui.release_hover()
//         gui.send_event(slider, Slider_Released_Event{})

//     case gui.Mouse_Moved_Event:


//     case gui.Draw_Event:
//         gui.begin_path()
//         gui.path_rounded_rect(slider.position, slider.size, 3)
//         gui.fill_path(gui.rgb(31, 32, 34))

//         handle_position := slider_handle_position(slider)
//         handle_size := slider_handle_size(slider)

//         gui.begin_path()
//         gui.path_rounded_rect(handle_position, handle_size, 3)
//         gui.fill_path(gui.lighten(gui.rgb(49, 51, 56), 0.3))

//         // if handle.is_down {
//         //     gui.begin_path()
//         //     gui.path_rounded_rect(handle_position, handle_size, 3)
//         //     gui.fill_path(gui.rgba(0, 0, 0, 8))

//         // } else if gui.current_hover() == handle {
//         //     gui.begin_path()
//         //     gui.path_rounded_rect(handle_position, handle_size, 3)
//         //     gui.fill_path(gui.rgba(255, 255, 255, 8))
//         // }

//     }

//     return false
// }

// update_slider :: proc(slider: ^Slider) {
//     position := slider.position
//     size := slider.size
//     handle_length := slider.handle_length
//     min_value := slider.min_value
//     max_value := max(slider.max_value, min_value)
//     value := clamp(slider.value, min_value, max_value)
//     global_mouse_position := gui.global_mouse_position()

//     handle := &slider.handle
//     handle.position.x = position.x + (size.x - handle_length) * (value - min_value) / (max_value - min_value)
//     handle.position.y = position.y
//     handle.size = {handle_length, size.y}

//     update_button(handle)

//     if handle.pressed || gui.key_pressed(.Left_Control) || gui.key_released(.Left_Control) {
//         slider.value_when_handle_grabbed = value
//         slider.global_mouse_position_when_handle_grabbed = global_mouse_position
//     }

//     sensitivity: f32 = gui.key_down(.Left_Control) ? 0.15 : 1.0

//     if handle.is_down {
//         grab_delta := global_mouse_position.x - slider.global_mouse_position_when_handle_grabbed.x
//         value = slider.value_when_handle_grabbed + sensitivity * grab_delta * (max_value - min_value) / (size.x - handle_length)
//         slider.value = clamp(value, min_value, max_value)
//     }
// }