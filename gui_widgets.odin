package main

// import "core:fmt"
import "core:time"
import "core:strings"
import cte "core:text/edit"

//==========================================================================
// Button
//==========================================================================

Button_Response :: struct {
    is_down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

button :: proc(id: Id, rectangle: Rectangle, color: Color, mouse_button := Mouse_Button.Left) -> (res: Button_Response) {
    is_down := get_state(id, false)

    res.is_down = is_down^
    res.pressed = false
    res.released = false
    res.clicked = false

    if mouse_hit_test(rectangle) {
        request_mouse_hover(id)
    }

    if !res.is_down && mouse_pressed(mouse_button) && mouse_hover() == id {
        capture_mouse_hover()
        res.is_down = true
        res.pressed = true
    }

    if res.is_down && mouse_released(mouse_button) {
        release_mouse_hover()
        res.is_down = false
        res.released = true
        if mouse_hit() == id {
            res.is_down = false
            res.clicked = true
        }
    }

    path := temp_path()
    path_rectangle(&path, rectangle)

    fill_path(path, color)
    if res.is_down {
        fill_path(path, {0, 0, 0, 0.2})
    } else if mouse_hover() == id {
        fill_path(path, {1, 1, 1, 0.05})
    }

    is_down^ = res.is_down

    return
}

// //==========================================================================
// // Slider
// //==========================================================================

// Slider :: struct {
//     id: Id,
//     using rectangle: Rectangle,
//     held: bool,
//     value: f32,
//     min_value: f32,
//     max_value: f32,
//     handle_length: f32,
//     value_when_grabbed: f32,
//     global_mouse_position_when_grabbed: Vector2,
//     mouse_button: Mouse_Button,
//     precision_key: Keyboard_Key,
// }

// slider_init :: proc(slider: ^Slider) {
//     slider.id = get_id()
//     slider.size = Vector2{300, 24}
//     slider.max_value = 1
//     slider.handle_length = 16
//     slider.mouse_button = .Left
//     slider.precision_key = .Left_Shift
// }

// slider_handle_rectangle :: proc(slider: ^Slider) -> Rectangle {
//     return {
//         slider.position + {
//             (slider.size.x - slider.handle_length) * (slider.value - slider.min_value) / (slider.max_value - slider.min_value),
//             0,
//         },
//         {
//             slider.handle_length,
//             slider.size.y,
//         },
//     }
// }

// slider_set_value :: proc(slider: ^Slider, value: f32) {
//     slider.value = value
//     _slider_clamp_value(slider)
// }

// slider_set_min_value :: proc(slider: ^Slider, min_value: f32) {
//     slider.min_value = min_value
//     _slider_clamp_value(slider)
// }

// slider_set_max_value :: proc(slider: ^Slider, max_value: f32) {
//     slider.max_value = max_value
//     _slider_clamp_value(slider)
// }

// slider_update :: proc(slider: ^Slider) {
//     if mouse_hit_test(slider) {
//         request_mouse_hover(slider.id)
//     }

//     if slider.held {
//         if key_pressed(slider.precision_key) ||
//            key_released(slider.precision_key) {
//             _slider_reset_grab_info(slider)
//         }
//     }

//     if !slider.held && mouse_hover() == slider.id && mouse_pressed(slider.mouse_button) {
//         slider.held = true
//         _slider_reset_grab_info(slider)
//         capture_mouse_hover()
//     }

//     if slider.held {
//         sensitivity: f32 = key_down(slider.precision_key) ? 0.15 : 1.0
//         global_mouse_position := global_mouse_position()
//         grab_delta := global_mouse_position.x - slider.global_mouse_position_when_grabbed.x
//         slider.value = slider.value_when_grabbed + sensitivity * grab_delta * (slider.max_value - slider.min_value) / (slider.size.x - slider.handle_length)

//         if mouse_released(slider.mouse_button) {
//             slider.held = false
//             release_mouse_hover()
//         }
//     }

//     _slider_clamp_value(slider)
// }

// slider_draw :: proc(slider: ^Slider) {
//     slider_path := temp_path()
//     path_rectangle(&slider_path, slider)

//     fill_path(slider_path, {0.05, 0.05, 0.05, 1})

//     handle_path := temp_path()
//     path_rectangle(&handle_path, slider_handle_rectangle(slider))

//     fill_path(handle_path, {0.4, 0.4, 0.4, 1})
//     if slider.held {
//         fill_path(handle_path, {0, 0, 0, 0.2})
//     } else if mouse_hover() == slider.id {
//         fill_path(handle_path, {1, 1, 1, 0.05})
//     }
// }

// _slider_reset_grab_info :: proc(slider: ^Slider) {
//     slider.value_when_grabbed = slider.value
//     slider.global_mouse_position_when_grabbed = global_mouse_position()
// }

// _slider_clamp_value :: proc(slider: ^Slider) {
//     slider.value = clamp(slider.value, slider.min_value, slider.max_value)
// }

//==========================================================================
// Box Select
//==========================================================================

box_select :: proc(id: Id, mouse_button: Mouse_Button) -> (rectangle: Rectangle, selected: bool) {
    start := get_state(id, Vector2{})

    mp := mouse_position()

    if mouse_pressed(mouse_button) {
        start^ = mp
    }

    pixel := pixel_size()

    position := Vector2{min(start.x, mp.x), min(start.y, mp.y)}
    bottom_right := Vector2{max(start.x, mp.x), max(start.y, mp.y)}

    rectangle = Rectangle{position, bottom_right - position}
    rectangle.size.x = max(rectangle.size.x, pixel.x)
    rectangle.size.y = max(rectangle.size.y, pixel.y)

    if mouse_down(mouse_button) {
        fill_rectangle(rectangle_expanded(rectangle, -pixel), {0, 0, 0, 0.3})
        outline_rectangle(rectangle, pixel.x, {1, 1, 1, 0.3})
    }

    if mouse_released(mouse_button) {
        selected = true
    }

    return
}

//==========================================================================
// Editable Text Line
//==========================================================================

editable_text_line :: proc(id: Id, builder: ^strings.Builder, rectangle: Rectangle, font: Font, color := Color{1, 1, 1, 1}) {
    quick_remove_line_ends_UNSAFE :: proc(str: string) -> string {
        bytes := make([dynamic]byte, len(str), allocator = context.temp_allocator)
        copy_from_string(bytes[:], str)

        keep_position := 0

        for i in 0 ..< len(bytes) {
            should_keep := bytes[i] != '\n' && bytes[i] != '\r'
            if should_keep {
                if keep_position != i {
                    bytes[keep_position] = bytes[i]
                }
                keep_position += 1
            }
        }

        resize(&bytes, keep_position)
        return string(bytes[:])
    }

    initial_edit_state :: proc(builder: ^strings.Builder) -> (edit_state: cte.State) {
        cte.init(&edit_state, context.allocator, context.allocator)
        cte.setup_once(&edit_state, builder)
        edit_state.selection = {0, 0}
        edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
            data = clipboard()
            return quick_remove_line_ends_UNSAFE(data), true
        }
        edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
            set_clipboard(data)
            return true
        }
        return
    }

    str := strings.to_string(builder^)
    edit_state := get_state(id, initial_edit_state(builder))

    glyphs := make([dynamic]Text_Glyph, context.temp_allocator)
    measure_string(str, font, &glyphs, nil)

    line_height := font_metrics(font).line_height

    edit_state.line_start = 0
    edit_state.line_end = len(str)

    // Update the undo state timeout manually.

    edit_state.current_time = time.tick_now()
    if edit_state.undo_timeout <= 0 {
        edit_state.undo_timeout = cte.DEFAULT_UNDO_TIMEOUT
    }

    // Handle keyboard editing behavior.

    is_keyboard_focus := keyboard_focus() == id

    text_input := text_input()
    if len(text_input) > 0 {
        cte.input_text(edit_state, quick_remove_line_ends_UNSAFE(text_input))
    }

    ctrl := key_down(.Left_Control) || key_down(.Right_Control)
    shift := key_down(.Left_Shift) || key_down(.Right_Shift)

    for key in key_presses(repeating = true) {
        #partial switch key {
        case .Escape: release_keyboard_focus()

        case .A: if ctrl do cte.perform_command(edit_state, .Select_All)
        case .C: if ctrl do cte.perform_command(edit_state, .Copy)
        case .V: if ctrl do cte.perform_command(edit_state, .Paste)
        case .X: if ctrl do cte.perform_command(edit_state, .Cut)
        case .Y: if ctrl do cte.perform_command(edit_state, .Redo)
        case .Z: if ctrl do cte.perform_command(edit_state, .Undo)

        case .Home:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_Start)
            case shift: cte.perform_command(edit_state, .Select_Line_Start)
            case ctrl: cte.perform_command(edit_state, .Start)
            case: cte.perform_command(edit_state, .Line_Start)
            }

        case .End:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_End)
            case shift: cte.perform_command(edit_state, .Select_Line_End)
            case ctrl: cte.perform_command(edit_state, .End)
            case: cte.perform_command(edit_state, .Line_End)
            }

        case .Insert:
            switch {
            case ctrl: cte.perform_command(edit_state, .Copy)
            case shift: cte.perform_command(edit_state, .Paste)
            }

        case .Backspace:
            switch {
            case ctrl: cte.perform_command(edit_state, .Delete_Word_Left)
            case: cte.perform_command(edit_state, .Backspace)
            }

        case .Delete:
            switch {
            case ctrl: cte.perform_command(edit_state, .Delete_Word_Right)
            case shift: cte.perform_command(edit_state, .Cut)
            case: cte.perform_command(edit_state, .Delete)
            }

        case .Left_Arrow:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_Word_Left)
            case shift: cte.perform_command(edit_state, .Select_Left)
            case ctrl: cte.perform_command(edit_state, .Word_Left)
            case: cte.perform_command(edit_state, .Left)
            }

        case .Right_Arrow:
            switch {
            case ctrl && shift: cte.perform_command(edit_state, .Select_Word_Right)
            case shift: cte.perform_command(edit_state, .Select_Right)
            case ctrl: cte.perform_command(edit_state, .Word_Right)
            case: cte.perform_command(edit_state, .Right)
            }
        }
    }

    // Figure out where things of interest are in the string.

    is_mouse_hover := mouse_hover() == id
    relative_mp := mouse_position() - rectangle.position.x + 3 // Add a little bias for better feel.
    mouse_byte_index: int

    head := edit_state.selection[0]
    caret_x: f32

    selection_left, selection_right := cte.sorted_selection(edit_state)
    selection_left_x: f32
    selection_right_x: f32

    for glyph in glyphs {
        if head == glyph.byte_index {
            caret_x = glyph.position
        }
        if selection_left == glyph.byte_index {
            selection_left_x = glyph.position
        }
        if selection_right == glyph.byte_index {
            selection_right_x = glyph.position
        }
        if relative_mp.x >= glyph.position && relative_mp.x < glyph.position + glyph.width {
            mouse_byte_index = glyph.byte_index
        }
    }

    if len(glyphs) > 0 {
        last_glyph := glyphs[len(glyphs) - 1]
        last_glyph_right := last_glyph.position + last_glyph.width
        if head >= len(str) {
            caret_x = last_glyph_right
        }
        if selection_left >= len(str) {
            selection_left_x = last_glyph_right
        }
        if selection_right >= len(str) {
            selection_right_x = last_glyph_right
        }
        if relative_mp.x >= last_glyph_right {
            mouse_byte_index = len(str)
        }
    }

    // Handle mouse editing behavior.

    if mouse_hit_test(rectangle) {
        request_mouse_hover(id)
    }

    if is_mouse_hover {
        set_mouse_cursor_style(.I_Beam)

        if mouse_pressed(.Left) {
            capture_mouse_hover()
            set_keyboard_focus(id)

            switch mouse_repeat_count(.Left) {
            case 0, 1: // Single click
                edit_state.selection[0] = mouse_byte_index
                if !shift do edit_state.selection[1] = mouse_byte_index

            case 2: // Double click
                cte.perform_command(edit_state, .Word_Right)
                cte.perform_command(edit_state, .Word_Left)
                cte.perform_command(edit_state, .Select_Word_Right)

            case 3: // Triple click
                cte.perform_command(edit_state, .Line_Start)
                cte.perform_command(edit_state, .Select_Line_End)

            case: // Quadruple click and beyond
                cte.perform_command(edit_state, .Start)
                cte.perform_command(edit_state, .Select_End)
            }
        }

        if mouse_repeat_count(.Left) == 1 && mouse_down(.Left) {
            edit_state.selection[0] = mouse_byte_index
        }

        if mouse_released(.Left) {
            release_mouse_hover()
        }
    } else {
        if mouse_pressed(.Left) {
            if is_keyboard_focus {
                release_keyboard_focus()
            }
        }
    }

    // Draw the selection, string, and then caret.
    fill_rectangle(rectangle, {0.4, 0, 0, 1})

    selection_color: Color = {0, 0.4, 0.8, 0.8} if is_keyboard_focus else {0, 0.4, 0.8, 0.65}
    fill_rectangle({rectangle.position + {selection_left_x, 0}, {selection_right_x - selection_left_x, line_height}}, selection_color)

    fill_string(str, rectangle.position, font, color)

    if is_keyboard_focus {
        fill_rectangle({rectangle.position + {caret_x, 0}, {2, line_height}}, {0.7, 0.9, 1, 1})
    }
}