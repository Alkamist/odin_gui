package widgets

import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:text/edit"
import "core:strings"
import "../../gui"

// Todo:
// Single, double, triple, and quadruple clicks.
// Mouse cursor changing.
// Glyph measuring allocation.
// Figure out the problem with line starts/ends.

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
) -> (res: ^Text, err: mem.Allocator_Error) #optional_allocator_error {
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
    strings.write_string(&text.builder, str)
    text.font = font
    text.color = color
    edit.init(&text.edit_state, allocator, allocator)
    edit.setup_once(&text.edit_state, &text.builder)
    text.edit_state.selection = {0, 0}
    text.edit_state.clipboard_user_data = text
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        return gui.get_clipboard(cast(^Text)user_data)
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

input_text :: proc(text: ^Text, str: string) {
    edit.input_text(&text.edit_state, str)
    gui.redraw(text)
}

input_runes :: proc(text: ^Text, runes: []rune) {
    edit.input_runes(&text.edit_state, runes)
    gui.redraw(text)
}

input_rune :: proc(text: ^Text, r: rune) {
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
    edit.perform_command(&text.edit_state, command)
    gui.redraw(text)
}

start_drag_selection :: proc(text: ^Text, position: Vec2, only_head := false) {
    gui.set_focus(text)
    index := rune_index_at_position(text, position)
    text.is_drag_selecting = true
    text.edit_state.selection[0] = index
    if !only_head do text.edit_state.selection[1] = index
    gui.redraw()
}

move_drag_selection :: proc(text: ^Text, position: Vec2) {
    if !text.is_drag_selecting do return
    text.edit_state.selection[0] = rune_index_at_position(text, position)
    gui.redraw()
}

end_drag_selection :: proc(text: ^Text) {
    if !text.is_drag_selecting do return
    text.is_drag_selecting = false
    gui.redraw()
}

rune_index_at_position :: proc(text: ^Text, position: Vec2) -> int {
    _update_text_lines(text)
    metrics := gui.font_metrics(text.font)

    if position.x < 0 || position.y < 0 {
        return 0
    }

    for line, i in text.lines {
        line_y := metrics.line_height * f32(i)
        if position.y < line_y || position.y > line_y + metrics.line_height {
            continue
        }

        line_str := string(text.builder.buf[line.start:][:line.length])

        glyphs: [dynamic]gui.Text_Glyph
        defer delete(glyphs)
        gui.measure_text(&glyphs, line_str, text.font)

        for glyph in glyphs {
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
            edit.update_time(&text.edit_state)

        case gui.Mouse_Press_Event:
            gui.capture_hover()
            shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)
            start_drag_selection(text, e.position, only_head = shift)

        case gui.Mouse_Release_Event:
            end_drag_selection(text)
            gui.release_hover()

        case gui.Mouse_Move_Event:
            move_drag_selection(text, e.position)

        case gui.Text_Event:
            input_rune(text, e.text)

        case gui.Key_Press_Event:
            _handle_text_edit_keybinds(text, e.key)

        case gui.Draw_Event:
            _handle_text_render(text)
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
    CARET_WIDTH :: 2
    CARET_COLOR :: Color{0, 1, 0, 1}

    gui.draw_rect({0, 0}, text.size, {0.4, 0, 0, 1})
    gui.clip_drawing({0, 0}, text.size)
    _update_text_lines(text)

    metrics := gui.font_metrics(text.font)

    head := text.edit_state.selection[0]
    low, high := sorted_text_selection(text)
    range_is_selected := high > low

    line_count := len(text.lines)

    caret_set := false
    caret_position: Vec2

    for line, i in text.lines {
        start := line.start
        line_str := string(text.builder.buf[start:][:line.length])
        line_y := metrics.line_height * f32(i)
        line_end := f32(0)

        glyphs: [dynamic]gui.Text_Glyph
        defer delete(glyphs)
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
            gui.draw_rect({left_, line_y}, {right_ - left_, metrics.line_height}, {0, 1, 0, 0.5})
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

    gui.draw_rect(caret_position, {CARET_WIDTH, metrics.line_height}, CARET_COLOR)
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