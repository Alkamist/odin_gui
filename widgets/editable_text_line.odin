package widgets

import "base:runtime"
import "core:unicode/utf8"
import text_edit "core:text/edit"
import "core:strings"
import "../../gui"

// This is an editable extension of Text_Line.
// It owns a strings.Builder and will update the string
// of its Text_Line to reference that when editing occurs.
// It will not behave properly if you set the Text_Line str
// directly.

POSITIONAL_SELECTION_HORIZONTAL_BIAS :: 3 // Bias positional selection to the right a little for feel.
CARET_WIDTH :: 2

Text_Edit_Command :: text_edit.Command

Editable_Text_Line :: struct {
    using text_line: Text_Line,
    id: gui.Id,
    builder: strings.Builder,
    caret_color: Color,
    focused_selection_color: Color,
    unfocused_selection_color: Color,
    is_editable: bool,
    drag_selecting: bool,
    edit_state: text_edit.State,
}

editable_text_line_init :: proc(text: ^Editable_Text_Line, allocator := context.allocator) -> runtime.Allocator_Error {
    text_line_init(text) or_return
    strings.builder_init(&text.builder, allocator = allocator) or_return
    text_edit.init(&text.edit_state, allocator, allocator)
    text_edit.setup_once(&text.edit_state, &text.builder)
    text.edit_state.selection = {0, 0}
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        data, ok = gui.get_clipboard()
        if !ok do return "", false
        return _quick_remove_line_ends_UNSAFE(data), true
    }
    text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
        return gui.set_clipboard(data)
    }
    text.id = gui.get_id()
    text.caret_color = Color{0.7, .9, 1, 1}
    text.focused_selection_color = Color{0, .4, 0.8, 0.8}
    text.unfocused_selection_color = Color{0, .4, 0.8, 0.65}
    text.is_editable = true
    return nil
}

editable_text_line_destroy :: proc(text: ^Editable_Text_Line) {
    strings.builder_destroy(&text.builder)
    text_edit.destroy(&text.edit_state)
    text_line_destroy(text)
}

editable_text_line_update :: proc(text: ^Editable_Text_Line) {
    text_line_update(text)

    // Update the undo state timeout manually.
    text.edit_state.current_time = gui.tick()
    if text.edit_state.undo_timeout <= 0 {
        text.edit_state.undo_timeout = text_edit.DEFAULT_UNDO_TIMEOUT
    }

    edit_with_keyboard(text)
    edit_with_mouse(text)
}

editable_text_line_draw :: proc(text: ^Editable_Text_Line) {
    is_focus := gui.keyboard_focus() == text.id

    if text.is_editable {
        if selection, exists := selection_rect(text); exists {
            color := text.focused_selection_color if is_focus else text.unfocused_selection_color
            gui.draw_rect(selection, color)
        }
    }

    text_line_draw(text)

    if text.is_editable && is_focus {
        gui.draw_rect(caret_rect(text), text.caret_color)
    }
}

input_string :: proc(text: ^Editable_Text_Line, str: string) {
    text_edit.input_text(&text.edit_state, _quick_remove_line_ends_UNSAFE(str))
    _update_text_line_str(text)
}

input_runes :: proc(text: ^Editable_Text_Line, runes: []rune) {
    str := utf8.runes_to_string(runes, gui.arena_allocator())
    input_string(text, str)
}

input_rune :: proc(text: ^Editable_Text_Line, r: rune) {
    if r == '\n' || r == '\r' do return
    text_edit.input_rune(&text.edit_state, r)
    _update_text_line_str(text)
}

insert_string :: proc(text: ^Editable_Text_Line, at: int, str: string) {
    text_edit.insert(&text.edit_state, at, _quick_remove_line_ends_UNSAFE(str))
    _update_text_line_str(text)
}

remove_text_range :: proc(text: ^Editable_Text_Line, lo, hi: int) {
    text_edit.remove(&text.edit_state, lo, hi)
    _update_text_line_str(text)
}

has_selection :: proc(text: ^Editable_Text_Line) -> bool {
    return text_edit.has_selection(&text.edit_state)
}

sorted_selection :: proc(text: ^Editable_Text_Line) -> (lo, hi: int) {
    return text_edit.sorted_selection(&text.edit_state)
}

delete_selection :: proc(text: ^Editable_Text_Line) {
    text_edit.selection_delete(&text.edit_state)
    _update_text_line_str(text)
}

edit :: proc(text: ^Editable_Text_Line, command: Text_Edit_Command) {
    #partial switch command {
    case .New_Line:
        return
    case .Line_Start, .Line_End:
        _update_edit_state_line_start_and_end(text)
    }

    text_edit.perform_command(&text.edit_state, command)

    #partial switch command {
    case .Backspace, .Delete,
            .Delete_Word_Left, .Delete_Word_Right,
            .Paste, .Cut, .Undo, .Redo:
        _update_text_line_str(text)
    }
}

start_drag_selection :: proc(text: ^Editable_Text_Line, position: Vec2, only_head := false) {
    gui.set_keyboard_focus(text.id)
    index := byte_index_at_x(text, position.x)
    text.drag_selecting = true
    text.edit_state.selection[0] = index
    if !only_head do text.edit_state.selection[1] = index
}

move_drag_selection :: proc(text: ^Editable_Text_Line, position: Vec2) {
    if !text.drag_selecting do return
    text.edit_state.selection[0] = byte_index_at_x(text, position.x)
}

end_drag_selection :: proc(text: ^Editable_Text_Line) {
    if !text.drag_selecting do return
    text.drag_selecting = false
}

edit_with_mouse :: proc(text: ^Editable_Text_Line) {
    if !text.is_editable do return

    if gui.mouse_hit_test(gui.clip_rect()) {
        gui.request_mouse_hover(text.id)
    }

    if gui.mouse_hover_entered() == text.id {
        gui.set_mouse_cursor_style(.I_Beam)
    }

    if gui.mouse_hover_exited() == text.id {
        gui.set_mouse_cursor_style(.Arrow)
    }

    is_hover := gui.mouse_hover() == text.id
    left_or_middle_pressed := gui.mouse_pressed(.Left) || gui.mouse_pressed(.Middle)
    left_or_middle_released := gui.mouse_released(.Left) || gui.mouse_released(.Middle)

    if left_or_middle_pressed {
        if is_hover {
            gui.set_keyboard_focus(text.id)
        } else {
            gui.release_keyboard_focus()
        }
    }

    if left_or_middle_pressed && is_hover && !text.drag_selecting {
        gui.capture_mouse_hover()

        switch gui.mouse_repeat_count() {
        case 0, 1: // Single click
            shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)
            start_drag_selection(text, gui.mouse_position(), only_head = shift)

        case 2: // Double click
            edit(text, .Word_Right)
            edit(text, .Word_Left)
            edit(text, .Select_Word_Right)

        case 3: // Triple click
            edit(text, .Line_Start)
            edit(text, .Select_Line_End)

        case: // Quadruple click and beyond
            edit(text, .Start)
            edit(text, .Select_End)
        }
    }

    if text.drag_selecting {
        move_drag_selection(text, gui.mouse_position())
    }

    if text.drag_selecting && left_or_middle_released {
        end_drag_selection(text)
        gui.release_mouse_hover()
    }
}

edit_with_keyboard :: proc(text: ^Editable_Text_Line) {
    if !text.is_editable do return
    if gui.keyboard_focus() != text.id do return

    text_input := gui.text_input()
    if len(text_input) > 0 {
        input_string(text, text_input)
    }

    ctrl := gui.key_down(.Left_Control) || gui.key_down(.Right_Control)
    shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)

    for key in gui.key_presses(repeating = true) {
        #partial switch key {
        case .Escape: gui.release_keyboard_focus()
        // case .Enter, .Pad_Enter: edit(text, .New_Line)
        case .A: if ctrl do edit(text, .Select_All)
        case .C: if ctrl do edit(text, .Copy)
        case .V: if ctrl do edit(text, .Paste)
        case .X: if ctrl do edit(text, .Cut)
        case .Y: if ctrl do edit(text, .Redo)
        case .Z: if ctrl do edit(text, .Undo)

        case .Home:
            switch {
            case ctrl && shift: edit(text, .Select_Start)
            case shift: edit(text, .Select_Line_Start)
            case ctrl: edit(text, .Start)
            case: edit(text, .Line_Start)
            }

        case .End:
            switch {
            case ctrl && shift: edit(text, .Select_End)
            case shift: edit(text, .Select_Line_End)
            case ctrl: edit(text, .End)
            case: edit(text, .Line_End)
            }

        case .Insert:
            switch {
            case ctrl: edit(text, .Copy)
            case shift: edit(text, .Paste)
            }

        case .Backspace:
            switch {
            case ctrl: edit(text, .Delete_Word_Left)
            case: edit(text, .Backspace)
            }

        case .Delete:
            switch {
            case ctrl: edit(text, .Delete_Word_Right)
            case shift: edit(text, .Cut)
            case: edit(text, .Delete)
            }

        case .Left_Arrow:
            switch {
            case ctrl && shift: edit(text, .Select_Word_Left)
            case shift: edit(text, .Select_Left)
            case ctrl: edit(text, .Word_Left)
            case: edit(text, .Left)
            }

        case .Right_Arrow:
            switch {
            case ctrl && shift: edit(text, .Select_Word_Right)
            case shift: edit(text, .Select_Right)
            case ctrl: edit(text, .Word_Right)
            case: edit(text, .Right)
            }

        // case .Up_Arrow:
        //     switch {
        //     case shift: edit(text, .Select_Up)
        //     case: edit(text, .Up)
        //     }

        // case .Down_Arrow:
        //     switch {
        //     case shift: edit(text, .Select_Down)
        //     case: edit(text, .Down)
        //     }
        }
    }
}

caret_rect :: proc(text: ^Editable_Text_Line) -> (rect: Rect) {
    glyph_count := len(text.glyphs)

    rect.position = text.position
    rect.size = {CARET_WIDTH, text.size.y}

    if glyph_count == 0 do return

    head := text.edit_state.selection[0]
    caret_rune_index, caret_oob := byte_index_to_rune_index(text, head)

    if caret_oob {
        rect.position.x += text.glyphs[glyph_count - 1].position + text.glyphs[glyph_count - 1].width
    } else {
        rect.position.x += text.glyphs[caret_rune_index].position
    }

    return
}

selection_rect :: proc(text: ^Editable_Text_Line) -> (rect: Rect, exists: bool) {
    glyph_count := len(text.glyphs)

    if glyph_count == 0 do return

    height := line_height(text.font)

    low, high := sorted_selection(text)
    if high > low {
        left_rune_index, left_oob := byte_index_to_rune_index(text, low)
        if left_oob do left_rune_index = glyph_count - 1

        right_rune_index, right_oob := byte_index_to_rune_index(text, high)
        if right_oob {
            right_rune_index = glyph_count - 1
        } else {
            right_rune_index -= 1
        }

        left := text.glyphs[left_rune_index].position
        right := text.glyphs[right_rune_index].position + text.glyphs[right_rune_index].width

        rect.position = text.position + {left, 0}
        rect.size = {right - left, height}

        exists = true
    }

    return
}

byte_index_at_x :: proc(text: ^Editable_Text_Line, x: f32) -> int {
    glyph_count := len(text.glyphs)
    if glyph_count == 0 do return 0

    x := x + POSITIONAL_SELECTION_HORIZONTAL_BIAS
    position := text.position

    // There's almost certainly a better way to do this.
    #reverse for glyph, i in text.glyphs {
        left := position.x + glyph.position
        right := position.x + glyph.position + glyph.width

        if i == glyph_count - 1 && x >= right {
            return len(text.builder.buf)
        }

        if x >= left && x < right {
            return glyph.byte_index
        }
    }

    return 0
}



_quick_remove_line_ends_UNSAFE :: proc(str: string) -> string {
    bytes := make([dynamic]byte, len(str), allocator = gui.arena_allocator())
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

_update_text_line_str :: proc(text: ^Editable_Text_Line) {
    text.str = strings.to_string(text.builder)
    text.needs_remeasure = true
}

_update_edit_state_line_start_and_end :: proc(text: ^Editable_Text_Line) {
    text.edit_state.line_start = 0
    text.edit_state.line_end = len(text.builder.buf)
}