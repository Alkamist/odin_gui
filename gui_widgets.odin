package main

// import "core:fmt"
import "core:time"
import "core:strings"
import cte "core:text/edit"

//==========================================================================
// Button
//==========================================================================

Button :: struct {
    id: Id,
    is_down: bool,
    pressed: bool,
    released: bool,
    clicked: bool,
}

button_base_init :: proc(button: ^Button) {
    button.id = get_id()
}

button_base_update :: proc(
    button: ^Button,
    rectangle: Rectangle,
    press, release: bool,
) {
    button.pressed = false
    button.released = false
    button.clicked = false

    if mouse_hit_test(rectangle) {
        request_mouse_hover(button.id)
    }

    if !button.is_down && press && mouse_hover() == button.id {
        capture_mouse_hover()
        button.is_down = true
        button.pressed = true
    }

    if button.is_down && release {
        release_mouse_hover()
        button.is_down = false
        button.released = true
        if mouse_hit() == button.id {
            button.is_down = false
            button.clicked = true
        }
    }

    return
}

invisible_button_update :: proc(
    button: ^Button,
    rectangle: Rectangle,
    mouse_button := Mouse_Button.Left
) {
    button_base_update(
        button,
        rectangle,
        mouse_pressed(mouse_button),
        mouse_released(mouse_button),
    )
    return
}

button_update :: proc(
    button: ^Button,
    rectangle: Rectangle,
    color: Color,
    mouse_button := Mouse_Button.Left
) {
    invisible_button_update(button, rectangle, mouse_button)

    path := temp_path()
    path_rectangle(&path, rectangle)

    fill_path(path, color)
    if button.is_down {
        fill_path(path, {0, 0, 0, 0.2})
    } else if mouse_hover() == button.id {
        fill_path(path, {1, 1, 1, 0.05})
    }

    return
}

//==========================================================================
// Slider
//==========================================================================

Slider :: struct {
    id: Id,
    held: bool,
    value_when_grabbed: f32,
    global_mouse_position_when_grabbed: Vector2,
}

slider_init :: proc(slider: ^Slider) {
    slider.id = get_id()
}

slider_update :: proc(
    slider: ^Slider,
    value: ^f32,
    rectangle: Rectangle,
    min_value := f32(0),
    max_value := f32(1),
    mouse_button := Mouse_Button.Left,
    precision_key := Keyboard_Key.Left_Shift,
) {
    HANDLE_LENGTH :: 16

    if mouse_hit_test(rectangle) {
        request_mouse_hover(slider.id)
    }

    reset_grab_info := false

    if slider.held {
        if key_pressed(precision_key) ||
           key_released(precision_key) {
            reset_grab_info = true
        }
    }

    if !slider.held && mouse_hover() == slider.id && mouse_pressed(mouse_button) {
        slider.held = true
        reset_grab_info = true
        capture_mouse_hover()
    }

    if reset_grab_info {
        slider.value_when_grabbed = value^
        slider.global_mouse_position_when_grabbed = global_mouse_position()
    }

    if slider.held {
        sensitivity: f32 = key_down(precision_key) ? 0.15 : 1.0
        global_mouse_position := global_mouse_position()
        grab_delta := global_mouse_position.x - slider.global_mouse_position_when_grabbed.x
        value^ = slider.value_when_grabbed + sensitivity * grab_delta * (max_value - min_value) / (rectangle.size.x - HANDLE_LENGTH)

        if mouse_released(mouse_button) {
            slider.held = false
            release_mouse_hover()
        }
    }

    value^ = clamp(value^, min_value, max_value)

    slider_path := temp_path()
    path_rectangle(&slider_path, rectangle)

    fill_path(slider_path, {0.05, 0.05, 0.05, 1})

    handle_rectangle := Rectangle{
        rectangle.position + {
            (rectangle.size.x - HANDLE_LENGTH) * (value^ - min_value) / (max_value - min_value),
            0,
        }, {
            HANDLE_LENGTH,
            rectangle.size.y,
        },
    }
    handle_path := temp_path()
    path_rectangle(&handle_path, handle_rectangle)

    fill_path(handle_path, {0.4, 0.4, 0.4, 1})
    if slider.held {
        fill_path(handle_path, {0, 0, 0, 0.2})
    } else if mouse_hover() == slider.id {
        fill_path(handle_path, {1, 1, 1, 0.05})
    }
}

//==========================================================================
// Box Select
//==========================================================================

Box_Select :: struct {
    using rectangle: Rectangle,
    selected: bool,
    is_dragging: bool,
    start: Vector2,
}

box_select_update :: proc(box_select: ^Box_Select, mouse_button := Mouse_Button.Left) {
    box_select.selected = false

    mp := mouse_position()

    if mouse_pressed(mouse_button) && mouse_clip_test() {
        box_select.start = mp
        box_select.is_dragging = true
    }

    if box_select.is_dragging {
        pixel := pixel_size()

        position := Vector2{min(box_select.start.x, mp.x), min(box_select.start.y, mp.y)}
        bottom_right := Vector2{max(box_select.start.x, mp.x), max(box_select.start.y, mp.y)}

        box_select.rectangle = Rectangle{position, bottom_right - position}
        box_select.rectangle.size.x = max(box_select.rectangle.size.x, pixel.x)
        box_select.rectangle.size.y = max(box_select.rectangle.size.y, pixel.y)

        fill_rectangle(rectangle_expanded(box_select.rectangle, -pixel), {0, 0, 0, 0.3})
        outline_rectangle(box_select.rectangle, pixel.x, {1, 1, 1, 0.3})
    }

    if box_select.is_dragging && mouse_released(mouse_button) {
        box_select.selected = true
        box_select.is_dragging = false
    }
}

//==========================================================================
// Editable Text Line
//==========================================================================

Text_Edit_Command :: cte.Command

Editable_Text_Line :: struct {
    id: Id,
    edit_state: cte.State,
    builder: ^strings.Builder,
}

editable_text_line_init :: proc(
    text: ^Editable_Text_Line,
    builder: ^strings.Builder,
    allocator := context.allocator,
) {
    text.id = get_id()
    text.builder = builder
    cte.init(&text.edit_state, allocator, allocator)
    cte.setup_once(&text.edit_state, text.builder)
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        data = clipboard()
        return _quick_remove_line_ends_UNSAFE(data), true
    }
    text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
        set_clipboard(data)
        return true
    }
}

editable_text_line_destroy :: proc(text: ^Editable_Text_Line) {
    cte.destroy(&text.edit_state)
}

editable_text_line_edit :: proc(text: ^Editable_Text_Line, command: Text_Edit_Command) {
    cte.perform_command(&text.edit_state, command)
}

editable_text_line_update :: proc(
    text: ^Editable_Text_Line,
    rectangle: Rectangle,
    font: Font,
    color := Color{1, 1, 1, 1},
    alignment := Vector2{},
) {
    CARET_WIDTH :: 2

    str := strings.to_string(text.builder^)

    edit_state := &text.edit_state

    edit_state.line_start = 0
    edit_state.line_end = len(str)

    // Update the undo state timeout manually.

    edit_state.current_time = time.tick_now()
    if edit_state.undo_timeout <= 0 {
        edit_state.undo_timeout = cte.DEFAULT_UNDO_TIMEOUT
    }

    // Handle keyboard editing behavior.

    text_input := text_input()
    if len(text_input) > 0 {
        cte.input_text(edit_state, _quick_remove_line_ends_UNSAFE(text_input))
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

    glyphs := make([dynamic]Text_Glyph, context.temp_allocator)
    measure_glyphs(str, font, &glyphs)

    text_size: Vector2
    text_size.y = font_height(font)
    text_size.x = 0
    if len(glyphs) > 0 {
        first := glyphs[0]
        last := glyphs[len(glyphs) - 1]
        text_size.x = last.position + last.width - first.position
    }
    text_position := pixel_snapped(rectangle.position + (rectangle.size - text_size) * alignment)

    relative_mp := mouse_position() - text_position.x + 3 // Add a little bias for better feel.
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
            caret_x = last_glyph_right - CARET_WIDTH
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
        request_mouse_hover(text.id)
    }

    if mouse_hover() == text.id {
        set_mouse_cursor_style(.I_Beam)

        if mouse_pressed(.Left) {
            capture_mouse_hover()

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
    }

    // Draw the selection, string, and then caret.

    {
        scoped_clip(rectangle)
        fill_rectangle({text_position + {selection_left_x, 0}, {selection_right_x - selection_left_x, text_size.y}}, {0, 0.4, 0.8, 0.8})
        fill_string(str, text_position, font, color)
    }

    fill_rectangle({text_position + {caret_x, 0}, {CARET_WIDTH, text_size.y}}, {0.7, 0.9, 1, 1})
}

_quick_remove_line_ends_UNSAFE :: proc(str: string) -> string {
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