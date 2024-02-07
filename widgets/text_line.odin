package widgets

import "base:runtime"
// import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:text/edit"
import "core:strings"
import "../../gui"

POSITIONAL_SELECTION_HORIZONTAL_BIAS :: 3 // Bias positional selection to the right a little for feel.
CARET_WIDTH :: 2
CARET_COLOR :: Color{0.7, .9, 1, 1}
SELECTION_COLOR :: Color{0, .4, 0.8, 0.7}

Text_Edit_Command :: edit.Command

Text_Line :: struct {
    id: gui.Id,
    position: Vec2,
    size: Vec2,
    builder: strings.Builder,
    color: Color,
    font: gui.Font,
    drag_selecting: bool,
    edit_state: edit.State,
    glyphs: [dynamic]gui.Text_Glyph,
    glyphs_need_remeasure: bool,
}

init_text_line :: proc(text: ^Text_Line, allocator := context.allocator) -> runtime.Allocator_Error {
    strings.builder_init(&text.builder, allocator = allocator) or_return
    text.glyphs = make([dynamic]gui.Text_Glyph, allocator)
    text.id = gui.get_id()
    text.size = {96, 32}
    text.color = {1, 1, 1, 1}
    edit.init(&text.edit_state, allocator, allocator)
    edit.setup_once(&text.edit_state, &text.builder)
    text.edit_state.selection = {0, 0}
    text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
        return gui.get_clipboard()
    }
    text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
        return gui.set_clipboard(data)
    }
    text.glyphs_need_remeasure = true
    return nil
}

destroy_text_line :: proc(text: ^Text_Line) {
    strings.builder_destroy(&text.builder)
    edit.destroy(&text.edit_state)
    delete(text.glyphs)
}

text_string :: proc(text: ^Text_Line) -> string {
    return strings.to_string(text.builder)
}

input_text :: proc(text: ^Text_Line, str: string) {
    edit.input_text(&text.edit_state, str)
    text.glyphs_need_remeasure = true
}

input_runes :: proc(text: ^Text_Line, runes: []rune) {
    str := utf8.runes_to_string(runes, gui.temp_allocator())
    edit.input_runes(&text.edit_state, runes)
    text.glyphs_need_remeasure = true
}

input_rune :: proc(text: ^Text_Line, r: rune) {
    edit.input_rune(&text.edit_state, r)
    text.glyphs_need_remeasure = true
}

insert_text :: proc(text: ^Text_Line, at: int, str: string) {
    edit.insert(&text.edit_state, at, str)
    text.glyphs_need_remeasure = true
}

remove_text_range :: proc(text: ^Text_Line, lo, hi: int) {
    edit.remove(&text.edit_state, lo, hi)
    text.glyphs_need_remeasure = true
}

text_has_selection :: proc(text: ^Text_Line) -> bool {
    return edit.has_selection(&text.edit_state)
}

sorted_text_selection :: proc(text: ^Text_Line) -> (lo, hi: int) {
    return edit.sorted_selection(&text.edit_state)
}

delete_text_selection :: proc(text: ^Text_Line) {
    edit.selection_delete(&text.edit_state)
    text.glyphs_need_remeasure = true
}

edit_text :: proc(text: ^Text_Line, command: Text_Edit_Command) {
    #partial switch command {
    case .Line_Start, .Line_End: _update_edit_state_line_start_and_end(text)
    }
    edit.perform_command(&text.edit_state, command)
    text.glyphs_need_remeasure = true
}

rune_index_at_x :: proc(text: ^Text_Line, x: f32) -> int {
    glyph_count := len(text.glyphs)
    if glyph_count == 0 do return 0

    x := x + POSITIONAL_SELECTION_HORIZONTAL_BIAS

    #reverse for glyph, i in text.glyphs {
        left := text.position.x + glyph.position
        right := text.position.x + glyph.position + glyph.width

        if i == glyph_count - 1 && x >= right {
            return len(text.builder.buf)
        }

        if x >= left && x < right {
            return glyph.rune_index
        }
    }

    return 0
}

start_drag_selection :: proc(text: ^Text_Line, position: Vec2, only_head := false) {
    gui.set_keyboard_focus(text.id)
    index := rune_index_at_x(text, position.x)
    text.drag_selecting = true
    text.edit_state.selection[0] = index
    if !only_head do text.edit_state.selection[1] = index
}

move_drag_selection :: proc(text: ^Text_Line, position: Vec2) {
    if !text.drag_selecting do return
    text.edit_state.selection[0] = rune_index_at_x(text, position.x)
}

end_drag_selection :: proc(text: ^Text_Line) {
    if !text.drag_selecting do return
    text.drag_selecting = false
}

update_text_line :: proc(text: ^Text_Line) {
    assert(text.font != nil, "update_text_line called with nil font.")

    gui.scoped_clip(text.position, text.size)

    if text.glyphs_need_remeasure {
        _remeasure_text_line(text)
        text.glyphs_need_remeasure = false
    }

    // Update the undo state timeout manually.
    text.edit_state.current_time = gui.tick()
    if text.edit_state.undo_timeout <= 0 {
        text.edit_state.undo_timeout = edit.DEFAULT_UNDO_TIMEOUT
    }

    edit_text_with_keyboard(text)
    edit_text_with_mouse(text)

    height := line_height(text.font)

    low, high := sorted_text_selection(text)
    if high > low {
        left := text.glyphs[low].position
        right := text.glyphs[high - 1].position + text.glyphs[high - 1].width
        gui.draw_rect(text.position + {left, 0}, {right - left, height}, SELECTION_COLOR)
    }

    gui.draw_text(text_string(text), text.position, text.font, text.color)

    glyph_count := len(text.glyphs)
    head := text.edit_state.selection[0]

    caret_position := text.position

    if glyph_count > 0 {
        if head >= glyph_count {
            final_glyph := text.glyphs[glyph_count - 1]
            caret_position += {final_glyph.position + final_glyph.width, 0}
        } else {
            caret_position += {text.glyphs[head].position, 0}
        }
    }

    gui.draw_rect(caret_position, {CARET_WIDTH, height}, CARET_COLOR)
}

edit_text_with_mouse :: proc(text: ^Text_Line) {
    if gui.hit_test(text.position, text.size, gui.mouse_position()) {
        gui.request_mouse_hover(text.id)
    }

    if gui.mouse_hover_entered() == text.id {
        gui.set_cursor_style(.I_Beam)
    }

    if gui.mouse_hover_exited() == text.id {
        gui.set_cursor_style(.Arrow)
    }

    if gui.mouse_hover() == text.id &&
       !text.drag_selecting &&
       (gui.mouse_pressed(.Left) || gui.mouse_pressed(.Middle)) {
        gui.capture_mouse_hover()

        switch gui.mouse_repeat_count() {
        case 1: // Single click
            shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)
            start_drag_selection(text, gui.mouse_position(), only_head = shift)

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
    }

    if text.drag_selecting {
        move_drag_selection(text, gui.mouse_position())
    }

    if text.drag_selecting && (gui.mouse_released(.Left) || gui.mouse_released(.Middle)) {
        end_drag_selection(text)
        gui.release_mouse_hover()
    }
}

edit_text_with_keyboard :: proc(text: ^Text_Line) {
    text_input := gui.text_input()
    if len(text_input) > 0 {
        input_text(text, text_input)
    }

    ctrl := gui.key_down(.Left_Control) || gui.key_down(.Right_Control)
    shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)

    for key in gui.key_presses(repeating = true) {
        #partial switch key {
        case .Escape: gui.release_keyboard_focus()
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

        // case .Up_Arrow:
        //     switch {
        //     case shift: edit_text(text, .Select_Up)
        //     case: edit_text(text, .Up)
        //     }

        // case .Down_Arrow:
        //     switch {
        //     case shift: edit_text(text, .Select_Down)
        //     case: edit_text(text, .Down)
        //     }
        }
    }
}



_remeasure_text_line :: proc(text: ^Text_Line) {
    gui.measure_text(&text.glyphs, text_string(text), text.font)
    _update_edit_state_line_start_and_end(text)
}

_update_edit_state_line_start_and_end :: proc(text: ^Text_Line) {
    text.edit_state.line_start = 0
    text.edit_state.line_end = len(text.builder.buf)
}

// position_of_rune_index :: proc(text: ^Text_Line, rune_index: int) -> Vec2 {
//     line_count := len(text.lines)
//     line_height := line_height(text)

//     for line, i in text.lines {
//         if rune_index < line.start {
//             continue
//         }

//         start := line.start
//         line_str := string(text.builder.buf[start:][:line.length])
//         line_y := line_height * f32(i)
//         line_end := f32(0)

//         glyphs := make([dynamic]gui.Text_Glyph, text.temp_allocator)
//         gui.measure_text(&glyphs, line_str, text.font)

//         for glyph in glyphs {
//             if rune_index == start + glyph.rune_index {
//                 return {glyph.position, line_y}
//             }
//             line_end = glyph.position + glyph.width
//         }

//         if i == line_count - 1 {
//             return {line_end, line_y}
//         }
//     }

//     return {0, 0}
// }

// text_event_proc :: proc(widget: ^gui.Widget, event: gui.Event) {
//     text := cast(^Text_Line)widget

//     _handle_text_editing(text, event)

//     #partial switch e in event {
//     case gui.Window_Mouse_Press_Event:
//         if gui.mouse_hover() != widget && gui.keyboard_focus() == widget {
//             gui.release_keyboard_focus()
//         }

//     case gui.Update_Event:
//         // Manually update the edit state time with the
//         // time provided by the backend.
//         text.edit_state.current_time = gui.get_tick() or_else gui.Tick{}
//         if text.edit_state.undo_timeout <= 0 {
//             text.edit_state.undo_timeout = edit.DEFAULT_UNDO_TIMEOUT
//         }

//     case gui.Draw_Event:
//         _handle_text_render(text)
//     }
// }

// _update_text_lines :: proc(text: ^Text_Line) {
//     clear(&text.lines)
//     n := len(text.builder.buf)
//     i := 0
//     line_start := 0
//     for i <= n {
//         if i == n || text.builder.buf[i] == '\n' {
//             line_length := i - line_start if i == n else i - line_start + 1
//             append(&text.lines, Text_Line{
//                 start = line_start,
//                 length = line_length,
//             })
//             i += 1
//             line_start = i
//             continue
//         }
//         i += 1
//     }
// }

// _handle_text_render :: proc(text: ^Text_Line) {
//     // gui.clip_drawing({0, 0}, text.size)
//     _update_text_lines(text)

//     line_height := line_height(text)

//     head := text.edit_state.selection[0]
//     low, high := sorted_text_selection(text)
//     range_is_selected := high > low

//     line_count := len(text.lines)

//     caret_set := false
//     caret_position: Vec2

//     for line, i in text.lines {
//         start := line.start
//         line_str := string(text.builder.buf[start:][:line.length])
//         line_y := line_height * f32(i)
//         line_end := f32(0)

//         glyphs := make([dynamic]gui.Text_Glyph, text.temp_allocator)
//         gui.measure_text(&glyphs, line_str, text.font)

//         // Left and right of the selection.
//         left, right: Maybe(f32)

//         for glyph in glyphs {
//             index := start + glyph.rune_index
//             if index == head {
//                 caret_set = true
//                 caret_position = {glyph.position, line_y}
//             }

//             // Figure out the bounds of the selection if it exists.
//             if range_is_selected {
//                 if left == nil && index >= low do left = glyph.position
//                 if index >= low && index < high do right = glyph.position + glyph.width
//             }

//             line_end = glyph.position + glyph.width
//         }

//         // Draw the selection.
//         left_, left_exists := left.?
//         right_, right_exists := right.?
//         if left_exists && right_exists {
//             gui.draw_rect({left_, line_y}, {right_ - left_, line_height}, SELECTION_COLOR)
//         }

//         // If the line ends with '\n', trim it off and don't draw it.
//         draw_length := line.length
//         if line.length > 0 && line_str[line.length - 1] == '\n' do draw_length -= 1
//         gui.draw_text(line_str[:draw_length], {0, line_y}, text.font, text.color)

//         // Set the caret to the end of the text if necessary.
//         if !caret_set && i == line_count - 1 {
//             caret_position = {line_end, line_y}
//         }
//     }

//     gui.draw_rect(caret_position, {CARET_WIDTH, line_height}, CARET_COLOR)
// }

// _handle_text_editing :: proc(text: ^Text_Line, event: gui.Event) {
//     #partial switch e in event {
//     case gui.Mouse_Enter_Event:
//         gui.set_cursor_style(.I_Beam)

//     case gui.Mouse_Exit_Event:
//         gui.set_cursor_style(.Arrow)

//     case gui.Mouse_Repeat_Event:
//         gui.capture_mouse_hover()

//         switch e.press_count {
//         case 1: // Single click
//             #partial switch e.button {
//             case .Left, .Middle:
//                 shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)
//                 start_drag_selection(text, e.position, only_head = shift)
//             }

//         case 2: // Double click
//             edit_text(text, .Word_Right)
//             edit_text(text, .Word_Left)
//             edit_text(text, .Select_Word_Right)

//         case 3: // Triple click
//             edit_text(text, .Line_Start)
//             edit_text(text, .Select_Line_End)

//         case 4: // Quadruple click
//             edit_text(text, .Start)
//             edit_text(text, .Select_End)
//         }

//     case gui.Mouse_Release_Event:
//         end_drag_selection(text)
//         gui.release_mouse_hover()

//     case gui.Mouse_Move_Event:
//         move_drag_selection(text, e.position)

//     case gui.Text_Event:
//         input_rune(text, e.text)

//     case gui.Key_Repeat_Event:
//         _handle_text_edit_keybinds(text, e.key)
//     }
// }

// _handle_text_edit_keybinds :: proc(text: ^Text_Line, key: gui.Keyboard_Key) {
//     ctrl := gui.key_down(.Left_Control) || gui.key_down(.Right_Control)
//     shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)

//     #partial switch key {
//     case .Escape: gui.release_keyboard_focus()
//     case .Enter, .Pad_Enter: edit_text(text, .New_Line)
//     case .A: if ctrl do edit_text(text, .Select_All)
//     case .C: if ctrl do edit_text(text, .Copy)
//     case .V: if ctrl do edit_text(text, .Paste)
//     case .X: if ctrl do edit_text(text, .Cut)
//     case .Y: if ctrl do edit_text(text, .Redo)
//     case .Z: if ctrl do edit_text(text, .Undo)

//     case .Home:
//         switch {
//         case ctrl && shift: edit_text(text, .Select_Start)
//         case shift: edit_text(text, .Select_Line_Start)
//         case ctrl: edit_text(text, .Start)
//         case: edit_text(text, .Line_Start)
//         }

//     case .End:
//         switch {
//         case ctrl && shift: edit_text(text, .Select_End)
//         case shift: edit_text(text, .Select_Line_End)
//         case ctrl: edit_text(text, .End)
//         case: edit_text(text, .Line_End)
//         }

//     case .Insert:
//         switch {
//         case ctrl: edit_text(text, .Copy)
//         case shift: edit_text(text, .Paste)
//         }

//     case .Backspace:
//         switch {
//         case ctrl: edit_text(text, .Delete_Word_Left)
//         case: edit_text(text, .Backspace)
//         }

//     case .Delete:
//         switch {
//         case ctrl: edit_text(text, .Delete_Word_Right)
//         case shift: edit_text(text, .Cut)
//         case: edit_text(text, .Delete)
//         }

//     case .Left_Arrow:
//         switch {
//         case ctrl && shift: edit_text(text, .Select_Word_Left)
//         case shift: edit_text(text, .Select_Left)
//         case ctrl: edit_text(text, .Word_Left)
//         case: edit_text(text, .Left)
//         }

//     case .Right_Arrow:
//         switch {
//         case ctrl && shift: edit_text(text, .Select_Word_Right)
//         case shift: edit_text(text, .Select_Right)
//         case ctrl: edit_text(text, .Word_Right)
//         case: edit_text(text, .Right)
//         }

//     case .Up_Arrow:
//         switch {
//         case shift: edit_text(text, .Select_Up)
//         case: edit_text(text, .Up)
//         }

//     case .Down_Arrow:
//         switch {
//         case shift: edit_text(text, .Select_Down)
//         case: edit_text(text, .Down)
//         }
//     }
// }