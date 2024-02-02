package widgets

import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:text/edit"
import "core:strings"
import "../../gui"

Text_Edit_Command :: edit.Command

Text :: struct {
    using widget: gui.Widget,
    builder: strings.Builder,
    color: Color,
    font: gui.Font,
    edit_state: edit.State,
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
            gui.set_focus(widget)

        case gui.Text_Event:
            input_rune(text, e.text)

        case gui.Key_Press_Event:
            ctrl := gui.key_down(.Left_Control) || gui.key_down(.Right_Control)
            shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)

            #partial switch e.key {
            case .Escape:
                gui.release_focus()

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

            case .Backspace:
                switch {
                case ctrl: edit_text(text, .Delete_Word_Left)
                case: edit_text(text, .Backspace)
                }

            case .Delete:
                switch {
                case ctrl: edit_text(text, .Delete_Word_Right)
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

            case .Enter, .Pad_Enter:
                edit_text(text, .New_Line)

            case .A:
                if ctrl do edit_text(text, .Select_All)

            case .C:
                if ctrl do edit_text(text, .Copy)

            case .V:
                if ctrl do edit_text(text, .Paste)

            case .X:
                if ctrl do edit_text(text, .Cut)

            case .Y:
                if ctrl do edit_text(text, .Redo)

            case .Z:
                if ctrl do edit_text(text, .Undo)
            }

        case gui.Draw_Event:
            gui.draw_rect({0, 0}, text.size, {0.4, 0, 0, 1})

            // metrics := gui.font_metrics(text.font)
            // position: Vec2

            // str := strings.to_string(text.builder)

            // for line in strings.split_lines_iterator(&str) {
            //     glyphs: [dynamic]gui.Text_Glyph
            //     defer delete(glyphs)

            //     gui.measure_text(&glyphs, line, text.font)

            //     // for glyph in glyphs {
            //     //     gui.draw_rect(position + {glyph.position, 0}, {glyph.width, metrics.line_height}, {0, 1, 0, 0.5})
            //     // }

            //     gui.draw_text(line, position, text.font, text.color)

            //     position.y += metrics.line_height
            // }

            metrics := gui.font_metrics(text.font)
            position: Vec2

            n := len(text.builder.buf)
            i := 0
            line_start := 0

            for i < n {
                c := text.builder.buf[i]

                if c == '\n' || i == n - 1 {
                    line_length := i - line_start
                    if line_length > 0 {
                        line_str := string(text.builder.buf[line_start:][:line_length])

                        line_glyphs: [dynamic]gui.Text_Glyph
                        defer delete(line_glyphs)

                        gui.measure_text(&line_glyphs, line_str, text.font)

                        // line_selection: Maybe([2]f32)

                        for glyph in line_glyphs {
                            if _rune_index_selected(text, line_start + glyph.rune_index) {
                                gui.draw_rect(position + {glyph.position, 0}, {glyph.width, metrics.line_height}, {0, 1, 0, 0.5})
                            }
                        }

                        gui.draw_text(line_str, position, text.font, text.color)
                    }

                    i += 1
                    line_start = i
                    position.y += metrics.line_height

                    continue
                }

                i += 1
            }
        }
    }
}



_rune_index_selected :: proc(text: ^Text, index: int) -> bool {
    low, high := sorted_text_selection(text)
    return index >= low && index <= high
}