package main

import "base:runtime"
import "base:intrinsics"
import "core:time"
import "core:strings"
import utf8 "core:unicode/utf8"
import text_edit "core:text/edit"

//==========================================================================
// Tools
//==========================================================================

// Gui_Id :: u64

// get_gui_id :: proc "contextless" () -> Gui_Id {
//     @(static) id: Gui_Id
//     return 1 + intrinsics.atomic_add(&id, 1)
// }

// mouse_hover :: proc() -> Gui_Id {
//     return current_window().mouse_hover
// }

// mouse_hover_entered :: proc() -> Gui_Id {
//     window := current_window()
//     if window.mouse_hover != window.previous_mouse_hover {
//         return window.mouse_hover
//     } else {
//         return 0
//     }
// }

// mouse_hover_exited :: proc() -> Gui_Id {
//     window := current_window()
//     if window.mouse_hover != window.previous_mouse_hover {
//         return window.previous_mouse_hover
//     } else {
//         return 0
//     }
// }

// mouse_hit :: proc() -> Gui_Id {
//     return current_window().mouse_hit
// }

// request_mouse_hover :: proc(id: Gui_Id) {
//     current_window().final_mouse_hover_request = id
// }

// capture_mouse_hover :: proc() {
//     window := current_window()
//     window.mouse_hover_capture = window.final_mouse_hover_request
// }

// release_mouse_hover :: proc() {
//     current_window().mouse_hover_capture = 0
// }

// keyboard_focus :: proc() -> Gui_Id {
//     return current_window().keyboard_focus
// }

// set_keyboard_focus :: proc(id: Gui_Id) {
//     current_window().keyboard_focus = id
// }

// release_keyboard_focus :: proc() {
//     current_window().keyboard_focus = 0
// }

// // Local coordinates
// offset :: proc() -> Vector2 {
//     window := current_window()
//     if len(window.local_offset_stack) <= 0 do return {0, 0}
//     return window.local_offset_stack[len(window.local_offset_stack) - 1]
// }

// // Global coordinates
// global_offset :: proc() -> Vector2 {
//     window := current_window()
//     if len(window.global_offset_stack) <= 0 do return {0, 0}
//     return window.global_offset_stack[len(window.global_offset_stack) - 1]
// }

// // Set in local coordinates
// begin_offset :: proc(offset: Vector2) {
//     window := current_window()
//     append(&window.local_offset_stack, offset)
//     append(&window.global_offset_stack, global_offset() + offset)
// }

// end_offset :: proc() {
//     window := current_window()
//     if len(window.local_offset_stack) <= 0 ||
//        len(window.global_offset_stack) <= 0 {
//         return
//     }
//     pop(&window.local_offset_stack)
//     pop(&window.global_offset_stack)
// }

// @(deferred_none=end_offset)
// scoped_offset :: proc(offset: Vector2) {
//     begin_offset(offset)
// }

// // Local coordinates
// clip_rectangle :: proc() -> Rectangle {
//     window := current_window()
//     if len(window.global_clip_rect_stack) <= 0 do return {-global_offset(), window.size}
//     global_rect := window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1]
//     global_rect.position -= global_offset()
//     return global_rect
// }

// // Global coordinates
// global_clip_rectangle :: proc() -> Rectangle {
//     window := current_window()
//     if len(window.global_clip_rect_stack) <= 0 do return {{0, 0}, window.size}
//     return window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1]
// }

// // Set in local coordinates
// begin_clip :: proc(rectangle: Rectangle, intersect := true) {
//     window := current_window()

//     offset := global_offset()
//     global_rect := Rectangle{offset + rectangle.position, rectangle.size}

//     if intersect && len(window.global_clip_rect_stack) > 0 {
//         global_rect = rectangle_intersection(global_rect, window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1])
//     }

//     append(&window.global_clip_rect_stack, global_rect)
//     set_visual_clip_rectangle(global_rect)
// }

// end_clip :: proc() {
//     window := current_window()

//     if len(window.global_clip_rect_stack) <= 0 {
//         return
//     }

//     pop(&window.global_clip_rect_stack)

//     if len(window.global_clip_rect_stack) <= 0 {
//         return
//     }

//     global_rect := window.global_clip_rect_stack[len(window.global_clip_rect_stack) - 1]
//     set_visual_clip_rectangle(global_rect)
// }

// @(deferred_none=end_clip)
// scoped_clip :: proc(rectangle: Rectangle, intersect := true) {
//     begin_clip(rectangle, intersect = intersect)
// }

//==========================================================================
// Button
//==========================================================================

// Button_Base :: struct {
//     id: Gui_Id,
//     using rectangle: Rectangle,
//     is_down: bool,
//     pressed: bool,
//     released: bool,
//     clicked: bool,
// }

// button_base_init :: proc(button: ^Button_Base) {
//     button.id = get_gui_id()
// }

// button_base_update :: proc(button: ^Button_Base, press, release: bool) {
//     button.pressed = false
//     button.released = false
//     button.clicked = false

//     if rectangle_hit_test(button, mouse_position()) {
//         request_mouse_hover(button.id)
//     }

//     if !button.is_down && press && mouse_hover() == button.id {
//         capture_mouse_hover()
//         button.is_down = true
//         button.pressed = true
//     }

//     if button.is_down && release {
//         release_mouse_hover()
//         button.is_down = false
//         button.released = true
//         if mouse_hit() == button.id {
//             button.is_down = false
//             button.clicked = true
//         }
//     }
// }

// Button :: struct {
//     using base: Button_Base,
//     mouse_button: Mouse_Button,
//     color: Color,
// }

// button_init :: proc(button: ^Button) {
//     button_base_init(button)
//     button.size = {96, 32}
//     button.mouse_button = .Left
//     button.color = {0.5, 0.5, 0.5, 1}
// }

// button_update :: proc(button: ^Button) {
//     button_base_update(button,
//         press = mouse_pressed(button.mouse_button),
//         release = mouse_released(button.mouse_button),
//     )
// }

// button_draw :: proc(button: ^Button) {
//     path := temp_path()
//     path_rectangle(&path, button)

//     fill_path(path, button.color)
//     if button.is_down {
//         fill_path(path, {0, 0, 0, 0.2})
//     } else if mouse_hover() == button.id {
//         fill_path(path, {1, 1, 1, 0.05})
//     }
// }

// //==========================================================================
// // Text Line
// //
// // This is a simple text line that measures itself and
// // updates its rectangle accordingly. It is aware of the
// // current clip rectangle and will only draw the portion
// // of the string that is visible on screen for optimization.
// // The text does not own its string.
// //==========================================================================

// Text_Line :: struct {
//     using rectangle: Rectangle,
//     str: string,
//     color: Color,
//     font: Font,
//     glyphs: [dynamic]Text_Glyph,
//     byte_index_to_rune_index: map[int]int,
//     needs_remeasure: bool, // Set this to true to ask the text to remeasure
// }

// text_line_init :: proc(text: ^Text_Line, font: Font, allocator := context.allocator) -> runtime.Allocator_Error {
//     text.glyphs = make([dynamic]Text_Glyph, allocator = allocator)
//     text.byte_index_to_rune_index = make(map[int]int, allocator = allocator)
//     text.font = font
//     text.color = {1, 1, 1, 1}
//     text.needs_remeasure = true
//     return nil
// }

// text_line_destroy :: proc(text: ^Text_Line) {
//     delete(text.glyphs)
//     delete(text.byte_index_to_rune_index)
// }

// text_line_update :: proc(text: ^Text_Line) {
//     if text.needs_remeasure {
//         measure_text(text.str, text.font, &text.glyphs, &text.byte_index_to_rune_index)
//         text.needs_remeasure = false
//     }

//     text.size.y = font_metrics(text.font).line_height
//     if len(text.glyphs) <= 0 {
//         text.size.x = 0
//     } else {
//         left := text.glyphs[0]
//         right := text.glyphs[len(text.glyphs) - 1]
//         text.size.x = right.position + right.width - left.position
//     }
// }

// text_line_draw :: proc(text: ^Text_Line) {
//     str, x_compensation := text_line_visible_string(text)
//     position := text.position
//     position.x += x_compensation
//     fill_text(str, position, text.font, text.color)
// }

// text_line_visible_string :: proc(text: ^Text_Line) -> (str: string, x_compensation: f32) {
//     glyph_count := len(text.glyphs)
//     if glyph_count <= 0 do return "", 0

//     left, right_exclusive := text_line_visible_glyph_range(text)
//     if right_exclusive - left <= 0 do return "", 0

//     left_byte_index := text.glyphs[left].byte_index
//     byte_count := len(text.str)
//     if left_byte_index >= byte_count do return "", 0

//     x_compensation = text.glyphs[left].position

//     if right_exclusive >= glyph_count {
//         str = text.str[left_byte_index:]
//     } else {
//         right_byte_index := text.glyphs[right_exclusive].byte_index
//         if right_byte_index < byte_count {
//             str = text.str[left_byte_index:right_byte_index]
//         } else {
//             str = text.str[left_byte_index:]
//         }
//     }

//     return
// }

// text_line_byte_index_to_rune_index :: proc(text: ^Text_Line, byte_index: int) -> (rune_index: int, out_of_bounds: bool) {
//     if byte_index >= len(text.str) {
//         return 0, true
//     } else {
//         return text.byte_index_to_rune_index[byte_index], false
//     }
// }

// text_line_visible_glyph_range :: proc(text: ^Text_Line) -> (left, right_exclusive: int) {
//     clip_rect := clip_rectangle()
//     if clip_rect.size.x <= 0 || clip_rect.size.y <= 0 {
//         return 0, 0
//     }

//     position := text.position
//     height := text.size.y
//     left_set := false

//     for glyph, i in text.glyphs {
//         glyph_rect := Rectangle{position + {glyph.position, 0}, {glyph.width, height}}
//         glyph_visible := rectangle_intersects(clip_rect, glyph_rect, include_borders = false)

//         if !left_set {
//             if glyph_visible {
//                 left = i
//                 left_set = true
//             }
//         } else {
//             if !glyph_visible {
//                 right_exclusive = max(0, i)
//                 return
//             }
//         }
//     }

//     if left_set {
//         right_exclusive = len(text.glyphs)
//     }

//     return
// }

// //==========================================================================
// // Editable Text Line
// //
// // This is an editable extension of Text_Line.
// // It owns a strings.Builder and will update the string
// // of its Text_Line to reference that when editing occurs.
// // It will not behave properly if you set the Text_Line str
// // directly.
// //==========================================================================

// POSITIONAL_SELECTION_HORIZONTAL_BIAS :: 3 // Bias positional selection to the right a little for feel.
// CARET_WIDTH :: 2

// Text_Edit_Command :: text_edit.Command

// Editable_Text_Line :: struct {
//     using text_line: Text_Line,
//     id: Gui_Id,
//     builder: strings.Builder,
//     caret_color: Color,
//     focused_selection_color: Color,
//     unfocused_selection_color: Color,
//     is_editable: bool,
//     drag_selecting: bool,
//     edit_state: text_edit.State,
// }

// editable_text_line_init :: proc(text: ^Editable_Text_Line, font: Font, allocator := context.allocator) -> runtime.Allocator_Error {
//     text_line_init(text, font) or_return
//     strings.builder_init(&text.builder, allocator = allocator) or_return
//     text_edit.init(&text.edit_state, allocator, allocator)
//     text_edit.setup_once(&text.edit_state, &text.builder)
//     text.edit_state.selection = {0, 0}
//     text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
//         data = get_clipboard()
//         return _quick_remove_line_ends_UNSAFE(data), true
//     }
//     text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
//         set_clipboard(data)
//         return true
//     }
//     text.id = get_gui_id()
//     text.caret_color = Color{0.7, .9, 1, 1}
//     text.focused_selection_color = Color{0, .4, 0.8, 0.8}
//     text.unfocused_selection_color = Color{0, .4, 0.8, 0.65}
//     text.is_editable = true
//     return nil
// }

// editable_text_line_destroy :: proc(text: ^Editable_Text_Line) {
//     strings.builder_destroy(&text.builder)
//     text_edit.destroy(&text.edit_state)
//     text_line_destroy(text)
// }

// editable_text_line_update :: proc(text: ^Editable_Text_Line) {
//     text_line_update(text)

//     // Update the undo state timeout manually.
//     text.edit_state.current_time = time.tick_now()
//     if text.edit_state.undo_timeout <= 0 {
//         text.edit_state.undo_timeout = text_edit.DEFAULT_UNDO_TIMEOUT
//     }

//     editable_text_line_edit_with_keyboard(text)
//     editable_text_line_edit_with_mouse(text)
// }

// editable_text_line_draw :: proc(text: ^Editable_Text_Line) {
//     is_focus := keyboard_focus() == text.id

//     if text.is_editable {
//         if selection, exists := editable_text_line_selection_rectangle(text); exists {
//             color := text.focused_selection_color if is_focus else text.unfocused_selection_color
//             selection_path := temp_path()
//             path_rectangle(&selection_path, selection)
//             fill_path(selection_path, color)
//         }
//     }

//     text_line_draw(text)

//     if text.is_editable && is_focus {
//         caret_path := temp_path()
//         path_rectangle(&caret_path, editable_text_line_caret_rectangle(text))
//         fill_path(caret_path, text.caret_color)
//     }
// }

// editable_text_line_input_string :: proc(text: ^Editable_Text_Line, str: string) {
//     text_edit.input_text(&text.edit_state, _quick_remove_line_ends_UNSAFE(str))
//     _editable_text_line_update_str(text)
// }

// editable_text_line_input_runes :: proc(text: ^Editable_Text_Line, runes: []rune) {
//     str := utf8.runes_to_string(runes, context.temp_allocator)
//     editable_text_line_input_string(text, str)
// }

// editable_text_line_input_rune :: proc(text: ^Editable_Text_Line, r: rune) {
//     if r == '\n' || r == '\r' do return
//     text_edit.input_rune(&text.edit_state, r)
//     _editable_text_line_update_str(text)
// }

// editable_text_line_insert_string :: proc(text: ^Editable_Text_Line, at: int, str: string) {
//     text_edit.insert(&text.edit_state, at, _quick_remove_line_ends_UNSAFE(str))
//     _editable_text_line_update_str(text)
// }

// editable_text_line_remove_text_range :: proc(text: ^Editable_Text_Line, lo, hi: int) {
//     text_edit.remove(&text.edit_state, lo, hi)
//     _editable_text_line_update_str(text)
// }

// editable_text_line_has_selection :: proc(text: ^Editable_Text_Line) -> bool {
//     return text_edit.has_selection(&text.edit_state)
// }

// editable_text_line_sorted_selection :: proc(text: ^Editable_Text_Line) -> (lo, hi: int) {
//     return text_edit.sorted_selection(&text.edit_state)
// }

// editable_text_line_delete_selection :: proc(text: ^Editable_Text_Line) {
//     text_edit.selection_delete(&text.edit_state)
//     _editable_text_line_update_str(text)
// }

// editable_text_line_edit :: proc(text: ^Editable_Text_Line, command: Text_Edit_Command) {
//     #partial switch command {
//     case .New_Line:
//         return
//     case .Line_Start, .Line_End:
//         _editable_text_line_update_edit_state_line_start_and_end(text)
//     }

//     text_edit.perform_command(&text.edit_state, command)

//     #partial switch command {
//     case .Backspace, .Delete,
//             .Delete_Word_Left, .Delete_Word_Right,
//             .Paste, .Cut, .Undo, .Redo:
//         _editable_text_line_update_str(text)
//     }
// }

// editable_text_line_start_drag_selection :: proc(text: ^Editable_Text_Line, position: Vector2, only_head := false) {
//     set_keyboard_focus(text.id)
//     index := editable_text_line_byte_index_at_x(text, position.x)
//     text.drag_selecting = true
//     text.edit_state.selection[0] = index
//     if !only_head do text.edit_state.selection[1] = index
// }

// editable_text_line_move_drag_selection :: proc(text: ^Editable_Text_Line, position: Vector2) {
//     if !text.drag_selecting do return
//     text.edit_state.selection[0] = editable_text_line_byte_index_at_x(text, position.x)
// }

// editable_text_line_end_drag_selection :: proc(text: ^Editable_Text_Line) {
//     if !text.drag_selecting do return
//     text.drag_selecting = false
// }

// editable_text_line_edit_with_mouse :: proc(text: ^Editable_Text_Line) {
//     if !text.is_editable do return

//     if rectangle_hit_test(clip_rectangle(), mouse_position()) {
//         request_mouse_hover(text.id)
//     }

//     if mouse_hover_entered() == text.id {
//         set_mouse_cursor_style(.I_Beam)
//     }

//     if mouse_hover_exited() == text.id {
//         set_mouse_cursor_style(.Arrow)
//     }

//     is_hover := mouse_hover() == text.id
//     left_or_middle_pressed := mouse_pressed(.Left) || mouse_pressed(.Middle)
//     left_or_middle_released := mouse_released(.Left) || mouse_released(.Middle)

//     if left_or_middle_pressed {
//         if is_hover {
//             set_keyboard_focus(text.id)
//         } else {
//             release_keyboard_focus()
//         }
//     }

//     if left_or_middle_pressed && is_hover && !text.drag_selecting {
//         capture_mouse_hover()

//         switch mouse_repeat_count(.Left) {
//         case 0, 1: // Single click
//             shift := key_down(.Left_Shift) || key_down(.Right_Shift)
//             editable_text_line_start_drag_selection(text, mouse_position(), only_head = shift)

//         case 2: // Double click
//             editable_text_line_edit(text, .Word_Right)
//             editable_text_line_edit(text, .Word_Left)
//             editable_text_line_edit(text, .Select_Word_Right)

//         case 3: // Triple click
//             editable_text_line_edit(text, .Line_Start)
//             editable_text_line_edit(text, .Select_Line_End)

//         case: // Quadruple click and beyond
//             editable_text_line_edit(text, .Start)
//             editable_text_line_edit(text, .Select_End)
//         }
//     }

//     if text.drag_selecting {
//         editable_text_line_move_drag_selection(text, mouse_position())
//     }

//     if text.drag_selecting && left_or_middle_released {
//         editable_text_line_end_drag_selection(text)
//         release_mouse_hover()
//     }
// }

// editable_text_line_edit_with_keyboard :: proc(text: ^Editable_Text_Line) {
//     if !text.is_editable do return
//     if keyboard_focus() != text.id do return

//     text_input := text_input()
//     if len(text_input) > 0 {
//         editable_text_line_input_string(text, text_input)
//     }

//     ctrl := key_down(.Left_Control) || key_down(.Right_Control)
//     shift := key_down(.Left_Shift) || key_down(.Right_Shift)

//     for key in key_presses(repeating = true) {
//         #partial switch key {
//         case .Escape: release_keyboard_focus()
//         // case .Enter, .Pad_Enter: edit(text, .New_Line)
//         case .A: if ctrl do editable_text_line_edit(text, .Select_All)
//         case .C: if ctrl do editable_text_line_edit(text, .Copy)
//         case .V: if ctrl do editable_text_line_edit(text, .Paste)
//         case .X: if ctrl do editable_text_line_edit(text, .Cut)
//         case .Y: if ctrl do editable_text_line_edit(text, .Redo)
//         case .Z: if ctrl do editable_text_line_edit(text, .Undo)

//         case .Home:
//             switch {
//             case ctrl && shift: editable_text_line_edit(text, .Select_Start)
//             case shift: editable_text_line_edit(text, .Select_Line_Start)
//             case ctrl: editable_text_line_edit(text, .Start)
//             case: editable_text_line_edit(text, .Line_Start)
//             }

//         case .End:
//             switch {
//             case ctrl && shift: editable_text_line_edit(text, .Select_End)
//             case shift: editable_text_line_edit(text, .Select_Line_End)
//             case ctrl: editable_text_line_edit(text, .End)
//             case: editable_text_line_edit(text, .Line_End)
//             }

//         case .Insert:
//             switch {
//             case ctrl: editable_text_line_edit(text, .Copy)
//             case shift: editable_text_line_edit(text, .Paste)
//             }

//         case .Backspace:
//             switch {
//             case ctrl: editable_text_line_edit(text, .Delete_Word_Left)
//             case: editable_text_line_edit(text, .Backspace)
//             }

//         case .Delete:
//             switch {
//             case ctrl: editable_text_line_edit(text, .Delete_Word_Right)
//             case shift: editable_text_line_edit(text, .Cut)
//             case: editable_text_line_edit(text, .Delete)
//             }

//         case .Left_Arrow:
//             switch {
//             case ctrl && shift: editable_text_line_edit(text, .Select_Word_Left)
//             case shift: editable_text_line_edit(text, .Select_Left)
//             case ctrl: editable_text_line_edit(text, .Word_Left)
//             case: editable_text_line_edit(text, .Left)
//             }

//         case .Right_Arrow:
//             switch {
//             case ctrl && shift: editable_text_line_edit(text, .Select_Word_Right)
//             case shift: editable_text_line_edit(text, .Select_Right)
//             case ctrl: editable_text_line_edit(text, .Word_Right)
//             case: editable_text_line_edit(text, .Right)
//             }

//         // case .Up_Arrow:
//         //     switch {
//         //     case shift: edit(text, .Select_Up)
//         //     case: edit(text, .Up)
//         //     }

//         // case .Down_Arrow:
//         //     switch {
//         //     case shift: edit(text, .Select_Down)
//         //     case: edit(text, .Down)
//         //     }
//         }
//     }
// }

// editable_text_line_caret_rectangle :: proc(text: ^Editable_Text_Line) -> (rectangle: Rectangle) {
//     glyph_count := len(text.glyphs)

//     rectangle.position = text.position
//     rectangle.size = {CARET_WIDTH, text.size.y}

//     if glyph_count == 0 do return

//     head := text.edit_state.selection[0]
//     caret_rune_index, caret_oob := text_line_byte_index_to_rune_index(text, head)

//     if caret_oob || caret_rune_index >= len(text.glyphs) {
//         rectangle.position.x += text.glyphs[glyph_count - 1].position + text.glyphs[glyph_count - 1].width
//     } else {
//         rectangle.position.x += text.glyphs[caret_rune_index].position
//     }

//     return
// }

// editable_text_line_selection_rectangle :: proc(text: ^Editable_Text_Line) -> (rectangle: Rectangle, exists: bool) {
//     glyph_count := len(text.glyphs)

//     if glyph_count == 0 do return

//     height := font_metrics(text.font).line_height

//     low, high := editable_text_line_sorted_selection(text)
//     if high > low {
//         left_rune_index, left_oob := text_line_byte_index_to_rune_index(text, low)
//         if left_oob do left_rune_index = glyph_count - 1

//         right_rune_index, right_oob := text_line_byte_index_to_rune_index(text, high)
//         if right_oob {
//             right_rune_index = glyph_count - 1
//         } else {
//             right_rune_index -= 1
//         }

//         left := text.glyphs[left_rune_index].position
//         right := text.glyphs[right_rune_index].position + text.glyphs[right_rune_index].width

//         rectangle.position = text.position + {left, 0}
//         rectangle.size = {right - left, height}

//         exists = true
//     }

//     return
// }

// editable_text_line_byte_index_at_x :: proc(text: ^Editable_Text_Line, x: f32) -> int {
//     glyph_count := len(text.glyphs)
//     if glyph_count == 0 do return 0

//     x := x + POSITIONAL_SELECTION_HORIZONTAL_BIAS
//     position := text.position

//     // There's almost certainly a better way to do this.
//     #reverse for glyph, i in text.glyphs {
//         left := position.x + glyph.position
//         right := position.x + glyph.position + glyph.width

//         if i == glyph_count - 1 && x >= right {
//             return len(text.builder.buf)
//         }

//         if x >= left && x < right {
//             return glyph.byte_index
//         }
//     }

//     return 0
// }

// _editable_text_line_update_str :: proc(text: ^Editable_Text_Line) {
//     text.str = strings.to_string(text.builder)
//     text.needs_remeasure = true
// }

// _editable_text_line_update_edit_state_line_start_and_end :: proc(text: ^Editable_Text_Line) {
//     text.edit_state.line_start = 0
//     text.edit_state.line_end = len(text.builder.buf)
// }

// _quick_remove_line_ends_UNSAFE :: proc(str: string) -> string {
//     bytes := make([dynamic]byte, len(str), allocator = context.temp_allocator)
//     copy_from_string(bytes[:], str)

//     keep_position := 0

//     for i in 0 ..< len(bytes) {
//         should_keep := bytes[i] != '\n' && bytes[i] != '\r'
//         if should_keep {
//             if keep_position != i {
//                 bytes[keep_position] = bytes[i]
//             }
//             keep_position += 1
//         }
//     }

//     resize(&bytes, keep_position)
//     return string(bytes[:])
// }