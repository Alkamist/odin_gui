package widgets

import "core:fmt"
import "base:runtime"
import "core:unicode/utf8"
import "core:text/edit"
import "core:strings"
import "../../gui"
import "../rect"

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
    alignment: Vec2,
    drag_selecting: bool,
    edit_state: edit.State,
    glyphs: [dynamic]gui.Text_Glyph,
    rune_index_to_glyph_index: map[int]int,
    glyphs_need_remeasure: bool,
}

init_text_line :: proc(text: ^Text_Line, allocator := context.allocator) -> runtime.Allocator_Error {
    strings.builder_init(&text.builder, allocator = allocator) or_return
    text.glyphs = make([dynamic]gui.Text_Glyph, allocator = allocator)
    text.rune_index_to_glyph_index = make(map[int]int, allocator = allocator)
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
    delete(text.rune_index_to_glyph_index)
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
    case .New_Line:
        return
    case .Line_Start, .Line_End:
        _update_edit_state_line_start_and_end(text)
    case .Backspace, .Delete,
         .Delete_Word_Left, .Delete_Word_Right,
         .Paste, .Cut, .Undo, .Redo:
        text.glyphs_need_remeasure = true
    }
    edit.perform_command(&text.edit_state, command)
}

rune_index_at_x :: proc(text: ^Text_Line, x: f32) -> int {
    glyph_count := len(text.glyphs)
    if glyph_count == 0 do return 0

    x := x + POSITIONAL_SELECTION_HORIZONTAL_BIAS
    position := text_string_position(text)

    // There's almost certainly a better way to do this.
    #reverse for glyph, i in text.glyphs {
        left := position.x + glyph.position
        right := position.x + glyph.position + glyph.width

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

    gui.draw_rect(text.position, text.size, {0.2, 0, 0, 1})

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

    if selection, exists := text_selection_rect(text); exists {
        gui.draw_rect(selection.position, selection.size, SELECTION_COLOR)
    }

    gui.draw_text(text_visible_string(text), {text.position.x, text_string_position(text).y}, text.font, text.color)

    // gui.draw_text(text_string(text), text_string_position(text), text.font, text.color)

    gui.draw_rect(text_caret_position(text), {CARET_WIDTH, line_height(text.font)}, CARET_COLOR)
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
        // case .Enter, .Pad_Enter: edit_text(text, .New_Line)
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

text_string_size :: proc(text: ^Text_Line) -> (size: Vec2) {
    size.y = line_height(text.font)
    glyph_count := len(text.glyphs)
    if glyph_count <= 0 do return
    final_glyph := text.glyphs[glyph_count - 1]
    size.x = final_glyph.position + final_glyph.width
    return
}

text_string_position :: proc(text: ^Text_Line) -> Vec2 {
    return text.position + (text.size - {CARET_WIDTH, 0} - text_string_size(text)) * text.alignment
}

text_caret_position :: proc(text: ^Text_Line) -> (position: Vec2) {
    glyph_count := len(text.glyphs)

    position = text_string_position(text)

    if glyph_count == 0 do return

    head := text.edit_state.selection[0]
    caret_glyph_index, caret_oob := _rune_index_to_glyph_index(text, head)

    if caret_oob {
        position.x += text.glyphs[glyph_count - 1].position + text.glyphs[glyph_count - 1].width
    } else {
        position.x += text.glyphs[caret_glyph_index].position
    }

    return
}

text_selection_rect :: proc(text: ^Text_Line) -> (rect: rect.Rect, exists: bool) {
    glyph_count := len(text.glyphs)

    if glyph_count == 0 do return

    height := line_height(text.font)

    low, high := sorted_text_selection(text)
    if high > low {
        left_glyph_index, left_oob := _rune_index_to_glyph_index(text, low)
        if left_oob do left_glyph_index = glyph_count - 1

        right_glyph_index, right_oob := _rune_index_to_glyph_index(text, high)
        if right_oob {
            right_glyph_index = glyph_count - 1
        } else {
            right_glyph_index -= 1
        }

        left := text.glyphs[left_glyph_index].position
        right := text.glyphs[right_glyph_index].position + text.glyphs[right_glyph_index].width

        rect.position = text_string_position(text) + {left, 0}
        rect.size = {right - left, height}

        exists = true
    }

    return
}

text_visible_string :: proc(text: ^Text_Line) -> (str: string) {
    glyph_count := len(text.glyphs)
    if glyph_count <= 0 do return ""

    left, right_exclusive := text_visible_glyph_range(text)
    if right_exclusive - left <= 0 do return ""

    left_rune_index := text.glyphs[left].rune_index

    if right_exclusive >= len(text.glyphs) {
        str = text_string(text)[left_rune_index:]
    } else {
        right_rune_index := text.glyphs[right_exclusive].rune_index
        if right_rune_index < len(text.builder.buf) {
            str = text_string(text)[left_rune_index:right_rune_index]
        } else {
            str = text_string(text)[left_rune_index:]
        }
    }

    return
}

text_visible_glyph_range :: proc(text: ^Text_Line) -> (left, right_exclusive: int) {
    height := line_height(text.font)
    clip_rect := gui.current_clip_rect()
    if clip_rect.size.x <= 0 || clip_rect.size.y <= 0 {
        return 0, 0
    }

    position := text_string_position(text)

    // gui.draw_rect(clip_rect.position, clip_rect.size, {0.2, 0, 0, 1})

    left_set := false

    for glyph, i in text.glyphs {
        glyph_rect := rect.Rect{position + {glyph.position, 0}, {glyph.width, height}}
        glyph_visible := rect.intersects(clip_rect, glyph_rect, include_borders = false)

        // if glyph_visible {
        //     gui.draw_rect(glyph_rect.position, glyph_rect.size, {0, 0, 0.4, 1})
        // }

        if !left_set {
            if glyph_visible {
                left = i
                left_set = true
            }
        } else {
            if !glyph_visible {
                right_exclusive = max(0, i)
                return
            }
        }
    }

    if left_set {
        right_exclusive = len(text.glyphs)
    }

    return
}



_rune_index_to_glyph_index :: proc(text: ^Text_Line, rune_index: int) -> (glyph_index: int, out_of_bounds: bool) {
    if rune_index >= len(text.builder.buf) {
        return 0, true
    } else {
        return text.rune_index_to_glyph_index[rune_index], false
    }
}

_remeasure_text_line :: proc(text: ^Text_Line) {
    gui.measure_text(text_string(text), text.font, &text.glyphs, &text.rune_index_to_glyph_index)
    _update_edit_state_line_start_and_end(text)
}

_update_edit_state_line_start_and_end :: proc(text: ^Text_Line) {
    text.edit_state.line_start = 0
    text.edit_state.line_end = len(text.builder.buf)
}