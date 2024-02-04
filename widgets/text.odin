package widgets

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:text/edit"
import "core:strings"
import "../../gui"

// Todo:
// Single line mode?
// Text edit events.

POSITIONAL_SELECTION_HORIZONTAL_BIAS :: 3 // Bias positional selection to the right a little for feel.
CARET_WIDTH :: 2
CARET_COLOR :: Color{0.7, .9, 1, 1}
SELECTION_COLOR :: Color{0, .4, 0.8, 0.7}

Text_Edit_Command :: edit.Command

Text_Line :: struct {
    start: int,
    length: int,
}

Text :: struct {
    using widget: gui.Widget,
    builder: strings.Builder,
    color: Color,
    font: gui.Font,
    is_drag_selecting: bool,
    edit_state: edit.State,
    lines: [dynamic]Text_Line,
}

init_text :: proc(
    text: ^Text,
    parent: ^gui.Widget,
    position := Vec2{0, 0},
    size := Vec2{0, 0},
    str := "",
    color := Color{1, 1, 1, 1},
    font: gui.Font = nil,
    event_proc: proc(^gui.Widget, ^gui.Widget, any) = text_event_proc,
    allocator := context.allocator,
) -> (res: ^Text, err: runtime.Allocator_Error) #optional_allocator_error {
    gui.init_widget(
        text,
        parent,
        position = position,
        size = size,
        event_proc = event_proc,
        allocator = allocator,
    ) or_return
    text.is_drag_selecting = false
    text.lines = make([dynamic]Text_Line, allocator = allocator)
    strings.builder_init(&text.builder, allocator = allocator)

    checkpoint := runtime.default_temp_allocator_temp_begin()
    str_, _ := _remove_carriage_returns(str, context.temp_allocator)
    strings.write_string(&text.builder, str_)
    runtime.default_temp_allocator_temp_end(checkpoint)

    text.font = font
    text.color = color
    edit.init(&text.edit_state, allocator, allocator)
    edit.setup_once(&text.edit_state, &text.builder)
    text.edit_state.selection = {0, 0}
    text.edit_state.clipboard_user_data = text
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        if data_, ok_ := gui.get_clipboard(cast(^Text)user_data); ok_ {
            data_no_cr, _ := _remove_carriage_returns(data_, context.temp_allocator)
            return data_no_cr, ok_
        }
        return "", false
    }
    text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
        return gui.set_clipboard(data, cast(^Text)user_data)
    }
    return text, nil
}

destroy_text :: proc(text: ^Text) {
    delete(text.lines)
    strings.builder_destroy(&text.builder)
    edit.destroy(&text.edit_state)
    gui.destroy_widget(text)
}

line_height :: proc(text: ^Text) -> f32 {
    pixel_height := gui.pixel_size(text).y
    metrics, _ := gui.font_metrics(text.font)
    return math.ceil(metrics.line_height / pixel_height) * pixel_height
}

input_text :: proc(text: ^Text, str: string) {
    checkpoint := runtime.default_temp_allocator_temp_begin()
    str_, _ := _remove_carriage_returns(str, context.temp_allocator)
    edit.input_text(&text.edit_state, str)
    runtime.default_temp_allocator_temp_end(checkpoint)
    gui.redraw(text)
}

input_runes :: proc(text: ^Text, runes: []rune) {
    checkpoint := runtime.default_temp_allocator_temp_begin()
    str := utf8.runes_to_string(runes, context.temp_allocator)
    str_, _ := _remove_carriage_returns(str, context.temp_allocator)
    edit.input_runes(&text.edit_state, runes)
    runtime.default_temp_allocator_temp_end(checkpoint)
    gui.redraw(text)
}

input_rune :: proc(text: ^Text, r: rune) {
    if r == '\r' do return
    edit.input_rune(&text.edit_state, r)
    gui.redraw(text)
}

insert_text :: proc(text: ^Text, at: int, str: string) {
    edit.insert(&text.edit_state, at, str)
    gui.redraw(text)
}

remove_text_range :: proc(text: ^Text, lo, hi: int) {
    edit.remove(&text.edit_state, lo, hi)
    gui.redraw(text)
}

text_has_selection :: proc(text: ^Text) -> bool {
    return edit.has_selection(&text.edit_state)
}

sorted_text_selection :: proc(text: ^Text) -> (lo, hi: int) {
    return edit.sorted_selection(&text.edit_state)
}

delete_text_selection :: proc(text: ^Text) {
    edit.selection_delete(&text.edit_state)
    gui.redraw(text)
}

edit_text :: proc(text: ^Text, command: Text_Edit_Command) {
    #partial switch command {
    case .Line_Start, .Line_End: _update_edit_state_line_start_and_end(text)
    case .Up, .Select_Up: _update_edit_state_up_index(text)
    case .Down, .Select_Down: _update_edit_state_down_index(text)
    }
    checkpoint := runtime.default_temp_allocator_temp_begin()
    edit.perform_command(&text.edit_state, command)
    runtime.default_temp_allocator_temp_end(checkpoint)
    gui.redraw(text)
}

start_drag_selection :: proc(text: ^Text, position: Vec2, only_head := false) {
    gui.set_focus(text)
    index := rune_index_at_position(text, position)
    text.is_drag_selecting = true
    text.edit_state.selection[0] = index
    if !only_head do text.edit_state.selection[1] = index
    gui.redraw(text)
}

move_drag_selection :: proc(text: ^Text, position: Vec2) {
    if !text.is_drag_selecting do return
    text.edit_state.selection[0] = rune_index_at_position(text, position)
    gui.redraw(text)
}

end_drag_selection :: proc(text: ^Text) {
    if !text.is_drag_selecting do return
    text.is_drag_selecting = false
    gui.redraw(text)
}

line_index_at_position :: proc(text: ^Text, position: Vec2) -> int {
    _update_text_lines(text)
    line_height := line_height(text)

    if position.y < 0 {
        return 0
    }

    for line, i in text.lines {
        if _position_is_on_line(position.y, line_height * f32(i), line_height) {
            return i
        }
    }

    return len(text.lines) - 1
}

rune_index_at_position :: proc(text: ^Text, position: Vec2) -> int {
    position := position
    position.x += POSITIONAL_SELECTION_HORIZONTAL_BIAS

    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)

    _update_text_lines(text)
    line_height := line_height(text)

    if position.y < 0 {
        return 0
    }

    for line, i in text.lines {
        line_y := line_height * f32(i)
        if !_position_is_on_line(position.y, line_y, line_height) {
            continue
        }

        line_str := string(text.builder.buf[line.start:][:line.length])

        glyphs := make([dynamic]gui.Text_Glyph, context.temp_allocator)
        gui.measure_text(&glyphs, line_str, text.font)

        #reverse for glyph in glyphs {
            left := glyph.position
            right := glyph.position + glyph.width
            if position.x >= left && position.x < right {
                return line.start + glyph.rune_index
            }
        }

        // If this point is reached then the position is to the right
        // of all of the glyphs in the line.
        if line.length > 0 && line_str[line.length - 1] == '\n' {
            // Put the cursor before the '\n' if there is one.
            return line.start + line.length - 1
        } else {
            return line.start + line.length
        }
    }

    return len(text.builder.buf)
}

position_of_rune_index :: proc(text: ^Text, rune_index: int) -> Vec2 {
    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)

    line_count := len(text.lines)
    line_height := line_height(text)

    for line, i in text.lines {
        if rune_index < line.start {
            continue
        }

        start := line.start
        line_str := string(text.builder.buf[start:][:line.length])
        line_y := line_height * f32(i)
        line_end := f32(0)

        glyphs := make([dynamic]gui.Text_Glyph, context.temp_allocator)
        gui.measure_text(&glyphs, line_str, text.font)

        for glyph in glyphs {
            if rune_index == start + glyph.rune_index {
                return {glyph.position, line_y}
            }
            line_end = glyph.position + glyph.width
        }

        if i == line_count - 1 {
            return {line_end, line_y}
        }
    }

    return {0, 0}
}

text_event_proc :: proc(widget, subject: ^gui.Widget, event: any) {
    text := cast(^Text)widget

    // Release focus if any other widget is clicked.
    if subject != widget {
        switch e in event {
        case gui.Mouse_Press_Event:
            if gui.current_focus() == widget do gui.release_focus()
        }
    }

    switch subject {
    case nil:
        switch e in event {
        case gui.Open_Event: gui.redraw()
        }

    case widget:
        switch e in event {
        case gui.Update_Event:
            // Manually update the edit state time with the
            // time provided by the backend.
            text.edit_state.current_time = gui.get_tick() or_else gui.Tick{}
            if text.edit_state.undo_timeout <= 0 {
                text.edit_state.undo_timeout = edit.DEFAULT_UNDO_TIMEOUT
            }

        case gui.Mouse_Enter_Event:
            gui.set_cursor_style(.I_Beam)

        case gui.Mouse_Exit_Event:
            gui.set_cursor_style(.Arrow)

        case gui.Mouse_Repeat_Event:
            gui.capture_hover()

            switch e.press_count {
            case 1: // Single click
                #partial switch e.button {
                case .Left, .Middle:
                    shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)
                    start_drag_selection(text, e.position, only_head = shift)
                }

            case 2: // Double click
                edit_text(text, .Word_Right)
                edit_text(text, .Word_Left)
                edit_text(text, .Select_Word_Right)

            case 3: // Triple click
                edit_text(text, .Line_Start)
                edit_text(text, .Select_Line_End)

            case 4: // Quadruple click
                edit_text(text, .Start)
                edit_text(text, .Select_End)
            }

        case gui.Mouse_Release_Event:
            end_drag_selection(text)
            gui.release_hover()

        case gui.Mouse_Move_Event:
            move_drag_selection(text, e.position)

        case gui.Text_Event:
            input_rune(text, e.text)

        case gui.Key_Press_Event:
            _handle_text_edit_keybinds(text, e.key)

        case gui.Key_Repeat_Event:
            _handle_text_edit_keybinds(text, e.key)

        case gui.Draw_Event:
            _handle_text_render(text)
        }
    }
}



_remove_carriage_returns :: proc(str: string, allocator := context.allocator) -> (output: string, was_allocation: bool) {
    return strings.remove(str, "\r", -1, allocator)
}

_position_is_on_line :: proc(position: Vec2, line_y, line_height: f32) -> bool {
    return position.y >= line_y && position.y < line_y + line_height
}

_update_edit_state_up_index :: proc(text: ^Text) {
    head := text.edit_state.selection[0]
    edit_position := position_of_rune_index(text, head)
    up_position := edit_position - {0, line_height(text)}
    text.edit_state.up_index = rune_index_at_position(text, up_position)
}

_update_edit_state_down_index :: proc(text: ^Text) {
    head := text.edit_state.selection[0]
    edit_position := position_of_rune_index(text, head)
    down_position := edit_position + {0, line_height(text)}
    text.edit_state.down_index = rune_index_at_position(text, down_position)
}

_update_edit_state_line_start_and_end :: proc(text: ^Text) {
    head := text.edit_state.selection[0]
    for line in text.lines {
        if head >= line.start && head <= line.start + line.length {
            text.edit_state.line_start = line.start

            // If the line ends with '\n' it needs to be handled differently.
            if line.length > 0 && text.builder.buf[line.start + line.length - 1] == '\n' {
                text.edit_state.line_end = line.start + line.length - 1
            } else {
                text.edit_state.line_end = line.start + line.length
            }
        }
    }
}

_update_text_lines :: proc(text: ^Text) {
    clear(&text.lines)
    n := len(text.builder.buf)
    i := 0
    line_start := 0
    for i <= n {
        if i == n || text.builder.buf[i] == '\n' {
            line_length := i - line_start if i == n else i - line_start + 1
            append(&text.lines, Text_Line{
                start = line_start,
                length = line_length,
            })
            i += 1
            line_start = i
            continue
        }
        i += 1
    }
}

_handle_text_render :: proc(text: ^Text) {
    checkpoint := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(checkpoint)

    gui.clip_drawing({0, 0}, text.size)
    _update_text_lines(text)

    line_height := line_height(text)

    head := text.edit_state.selection[0]
    low, high := sorted_text_selection(text)
    range_is_selected := high > low

    line_count := len(text.lines)

    caret_set := false
    caret_position: Vec2

    for line, i in text.lines {
        start := line.start
        line_str := string(text.builder.buf[start:][:line.length])
        line_y := line_height * f32(i)
        line_end := f32(0)

        glyphs := make([dynamic]gui.Text_Glyph, context.temp_allocator)
        gui.measure_text(&glyphs, line_str, text.font)

        // Left and right of the selection.
        left, right: Maybe(f32)

        for glyph in glyphs {
            index := start + glyph.rune_index
            if index == head {
                caret_set = true
                caret_position = {glyph.position, line_y}
            }

            // Figure out the bounds of the selection if it exists.
            if range_is_selected {
                if left == nil && index >= low do left = glyph.position
                if index >= low && index < high do right = glyph.position + glyph.width
            }

            line_end = glyph.position + glyph.width
        }

        // Draw the selection.
        left_, left_exists := left.?
        right_, right_exists := right.?
        if left_exists && right_exists {
            gui.draw_rect({left_, line_y}, {right_ - left_, line_height}, SELECTION_COLOR)
        }

        // If the line ends with '\n', trim it off and don't draw it.
        draw_length := line.length
        if line.length > 0 && line_str[line.length - 1] == '\n' do draw_length -= 1
        gui.draw_text(line_str[:draw_length], {0, line_y}, text.font, text.color)

        // Set the caret to the end of the text if necessary.
        if !caret_set && i == line_count - 1 {
            caret_position = {line_end, line_y}
        }
    }

    gui.draw_rect(caret_position, {CARET_WIDTH, line_height}, CARET_COLOR)
}

_handle_text_edit_keybinds :: proc(text: ^Text, key: gui.Keyboard_Key) {
    ctrl := gui.key_down(.Left_Control) || gui.key_down(.Right_Control)
    shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)

    #partial switch key {
    case .Escape: gui.release_focus()
    case .Enter, .Pad_Enter: edit_text(text, .New_Line)
    case .A: if ctrl do edit_text(text, .Select_All)
    case .C: if ctrl do edit_text(text, .Copy)
    case .V: if ctrl do edit_text(text, .Paste)
    case .X: if ctrl do edit_text(text, .Cut)
    case .Y: if ctrl do edit_text(text, .Redo)
    case .Z: if ctrl do edit_text(text, .Undo)

    case .Home:
        switch {
        case ctrl && shift: edit_text(text, .Select_Start)
        case shift: edit_text(text, .Select_Line_Start)
        case ctrl: edit_text(text, .Start)
        case: edit_text(text, .Line_Start)
        }

    case .End:
        switch {
        case ctrl && shift: edit_text(text, .Select_End)
        case shift: edit_text(text, .Select_Line_End)
        case ctrl: edit_text(text, .End)
        case: edit_text(text, .Line_End)
        }

    case .Insert:
        switch {
        case ctrl: edit_text(text, .Copy)
        case shift: edit_text(text, .Paste)
        }

    case .Backspace:
        switch {
        case ctrl: edit_text(text, .Delete_Word_Left)
        case: edit_text(text, .Backspace)
        }

    case .Delete:
        switch {
        case ctrl: edit_text(text, .Delete_Word_Right)
        case shift: edit_text(text, .Cut)
        case: edit_text(text, .Delete)
        }

    case .Left_Arrow:
        switch {
        case ctrl && shift: edit_text(text, .Select_Word_Left)
        case shift: edit_text(text, .Select_Left)
        case ctrl: edit_text(text, .Word_Left)
        case: edit_text(text, .Left)
        }

    case .Right_Arrow:
        switch {
        case ctrl && shift: edit_text(text, .Select_Word_Right)
        case shift: edit_text(text, .Select_Right)
        case ctrl: edit_text(text, .Word_Right)
        case: edit_text(text, .Right)
        }

    case .Up_Arrow:
        switch {
        case shift: edit_text(text, .Select_Up)
        case: edit_text(text, .Up)
        }

    case .Down_Arrow:
        switch {
        case shift: edit_text(text, .Select_Down)
        case: edit_text(text, .Down)
        }
    }
}