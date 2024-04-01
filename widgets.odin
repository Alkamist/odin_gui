package main

import "base:runtime"
import "core:time"
import "core:strings"
import utf8 "core:unicode/utf8"
import core_text_edit "core:text/edit"

// //==========================================================================
// // Button
// //==========================================================================

// Button_Base :: struct {
//     id: Gui_Id,
//     using rectangle: Rectangle,
//     is_down: bool,
//     pressed: bool,
//     released: bool,
//     clicked: bool,
// }

// button_base_init :: proc(button: ^Button_Base) {
//     button.id = gui_id()
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
// // Slider
// //==========================================================================

// Slider :: struct {
//     id: Gui_Id,
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
//     slider.id = gui_id()
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

// //==========================================================================
// // Box Select
// //==========================================================================

// Box_Select :: struct {
//     selected: bool,
//     is_active: bool,
//     start: Vector2,
//     finish: Vector2,
//     mouse_button: Mouse_Button,
// }

// box_select_update :: proc(box_select: ^Box_Select) {
//     box_select.selected = false

//     mp := mouse_position()

//     if mouse_pressed(box_select.mouse_button) {
//         box_select.is_active = true
//         box_select.start = mp
//         box_select.finish = mp
//     }

//     if box_select.is_active {
//         if mouse_down(box_select.mouse_button) {
//             box_select.finish = mp
//         }

//         if mouse_released(box_select.mouse_button) {
//             box_select.is_active = false
//             box_select.selected = true
//         }
//     }
// }

// box_select_draw :: proc(box_select: ^Box_Select) {
//     if box_select.is_active {
//         pixel := pixel_size()
//         outer := box_select_rectangle(box_select)
//         inner := rectangle_expanded(outer, -pixel)

//         background_path := temp_path()
//         path_rectangle(&background_path, inner)
//         fill_path(background_path, {0, 0, 0, 0.3})

//         outline_path := temp_path()

//         outer.size.x = max(outer.size.x, pixel.x)
//         outer.size.y = max(outer.size.y, pixel.y)
//         path_rectangle(&outline_path, outer)

//         if inner.size.x > 0 && inner.size.y > 0 {
//             path_rectangle(&outline_path, inner, true)
//         }

//         fill_path(outline_path, {1, 1, 1, 0.3})
//     }
// }

// box_select_rectangle :: proc(box_select: ^Box_Select) -> Rectangle {
//     position := Vector2{
//         min(box_select.start.x, box_select.finish.x),
//         min(box_select.start.y, box_select.finish.y),
//     }
//     bottom_right := Vector2{
//         max(box_select.start.x, box_select.finish.x),
//         max(box_select.start.y, box_select.finish.y),
//     }
//     return {position, bottom_right - position}
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
//         measure_string(text.str, text.font, &text.glyphs, &text.byte_index_to_rune_index)
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
//     str, x_compensation := text_visible_string(text)
//     position := text.position
//     position.x += x_compensation
//     if len(text.glyphs) > 0 {
//         fill_string(str, position + {text.glyphs[0].kerning, 0}, text.font, text.color)
//     } else {
//         fill_string(str, position, text.font, text.color)
//     }
// }

// text_visible_string :: proc(text: ^Text_Line) -> (str: string, x_compensation: f32) {
//     glyph_count := len(text.glyphs)
//     if glyph_count <= 0 do return "", 0

//     left, right_exclusive := text_visible_glyph_range(text)
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

// text_byte_index_to_rune_index :: proc(text: ^Text_Line, byte_index: int) -> (rune_index: int, out_of_bounds: bool) {
//     if byte_index >= len(text.str) {
//         return 0, true
//     } else {
//         return text.byte_index_to_rune_index[byte_index], false
//     }
// }

// text_visible_glyph_range :: proc(text: ^Text_Line) -> (left, right_exclusive: int) {
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

// Text_Edit_Command :: core_text_edit.Command

// Editable_Text_Line :: struct {
//     using text_line: Text_Line,
//     id: Gui_Id,
//     builder: strings.Builder,
//     caret_color: Color,
//     focused_selection_color: Color,
//     unfocused_selection_color: Color,
//     is_editable: bool,
//     drag_selecting: bool,
//     edit_state: core_text_edit.State,
// }

// editable_text_line_init :: proc(text: ^Editable_Text_Line, font: Font, allocator := context.allocator) -> runtime.Allocator_Error {
//     text_line_init(text, font) or_return
//     strings.builder_init(&text.builder, allocator = allocator) or_return
//     core_text_edit.init(&text.edit_state, allocator, allocator)
//     core_text_edit.setup_once(&text.edit_state, &text.builder)
//     text.edit_state.selection = {0, 0}
//     text.edit_state.get_clipboard = proc(user_data: rawptr) -> (data: string, ok: bool) {
//         data = clipboard()
//         return _quick_remove_line_ends_UNSAFE(data), true
//     }
//     text.edit_state.set_clipboard = proc(user_data: rawptr, data: string) -> (ok: bool) {
//         set_clipboard(data)
//         return true
//     }
//     text.id = gui_id()
//     text.caret_color = Color{0.7, .9, 1, 1}
//     text.focused_selection_color = Color{0, .4, 0.8, 0.8}
//     text.unfocused_selection_color = Color{0, .4, 0.8, 0.65}
//     text.is_editable = true
//     return nil
// }

// editable_text_line_destroy :: proc(text: ^Editable_Text_Line) {
//     strings.builder_destroy(&text.builder)
//     core_text_edit.destroy(&text.edit_state)
//     text_line_destroy(text)
// }

// editable_text_line_update :: proc(text: ^Editable_Text_Line) {
//     text_line_update(text)

//     // Update the undo state timeout manually.
//     text.edit_state.current_time = time.tick_now()
//     if text.edit_state.undo_timeout <= 0 {
//         text.edit_state.undo_timeout = core_text_edit.DEFAULT_UNDO_TIMEOUT
//     }

//     text_edit_with_keyboard(text)
//     text_edit_with_mouse(text)
// }

// editable_text_line_draw :: proc(text: ^Editable_Text_Line) {
//     is_focus := keyboard_focus() == text.id

//     if text.is_editable {
//         if selection, exists := text_selection_rectangle(text); exists {
//             color := text.focused_selection_color if is_focus else text.unfocused_selection_color
//             selection_path := temp_path()
//             path_rectangle(&selection_path, selection)
//             fill_path(selection_path, color)
//         }
//     }

//     text_line_draw(text)

//     if text.is_editable && is_focus {
//         caret_path := temp_path()
//         path_rectangle(&caret_path, text_caret_rectangle(text))
//         fill_path(caret_path, text.caret_color)
//     }
// }

// text_input_string :: proc(text: ^Editable_Text_Line, str: string) {
//     core_text_edit.input_text(&text.edit_state, _quick_remove_line_ends_UNSAFE(str))
//     _text_update_str(text)
// }

// text_input_runes :: proc(text: ^Editable_Text_Line, runes: []rune) {
//     str := utf8.runes_to_string(runes, context.temp_allocator)
//     text_input_string(text, str)
// }

// text_input_rune :: proc(text: ^Editable_Text_Line, r: rune) {
//     if r == '\n' || r == '\r' do return
//     core_text_edit.input_rune(&text.edit_state, r)
//     _text_update_str(text)
// }

// text_insert_string :: proc(text: ^Editable_Text_Line, at: int, str: string) {
//     core_text_edit.insert(&text.edit_state, at, _quick_remove_line_ends_UNSAFE(str))
//     _text_update_str(text)
// }

// text_remove_range :: proc(text: ^Editable_Text_Line, lo, hi: int) {
//     core_text_edit.remove(&text.edit_state, lo, hi)
//     _text_update_str(text)
// }

// text_has_selection :: proc(text: ^Editable_Text_Line) -> bool {
//     return core_text_edit.has_selection(&text.edit_state)
// }

// text_sorted_selection :: proc(text: ^Editable_Text_Line) -> (lo, hi: int) {
//     return core_text_edit.sorted_selection(&text.edit_state)
// }

// text_delete_selection :: proc(text: ^Editable_Text_Line) {
//     core_text_edit.selection_delete(&text.edit_state)
//     _text_update_str(text)
// }

// text_edit :: proc(text: ^Editable_Text_Line, command: Text_Edit_Command) {
//     #partial switch command {
//     case .New_Line:
//         return
//     case .Line_Start, .Line_End:
//         _text_update_edit_state_line_start_and_end(text)
//     }

//     core_text_edit.perform_command(&text.edit_state, command)

//     #partial switch command {
//     case .Backspace, .Delete,
//             .Delete_Word_Left, .Delete_Word_Right,
//             .Paste, .Cut, .Undo, .Redo:
//         _text_update_str(text)
//     }
// }

// text_start_drag_selection :: proc(text: ^Editable_Text_Line, position: Vector2, only_head := false) {
//     set_keyboard_focus(text.id)
//     index := text_byte_index_at_x(text, position.x)
//     text.drag_selecting = true
//     text.edit_state.selection[0] = index
//     if !only_head do text.edit_state.selection[1] = index
// }

// text_move_drag_selection :: proc(text: ^Editable_Text_Line, position: Vector2) {
//     if !text.drag_selecting do return
//     text.edit_state.selection[0] = text_byte_index_at_x(text, position.x)
// }

// text_end_drag_selection :: proc(text: ^Editable_Text_Line) {
//     if !text.drag_selecting do return
//     text.drag_selecting = false
// }

// text_edit_with_mouse :: proc(text: ^Editable_Text_Line) {
//     if mouse_hover_exited() == text.id {
//         set_mouse_cursor_style(.Arrow)
//     }

//     if !text.is_editable do return

//     if rectangle_hit_test(clip_rectangle(), mouse_position()) {
//         request_mouse_hover(text.id)
//     }

//     if mouse_hover_entered() == text.id {
//         set_mouse_cursor_style(.I_Beam)
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
//             text_start_drag_selection(text, mouse_position(), only_head = shift)

//         case 2: // Double click
//             text_edit(text, .Word_Right)
//             text_edit(text, .Word_Left)
//             text_edit(text, .Select_Word_Right)

//         case 3: // Triple click
//             text_edit(text, .Line_Start)
//             text_edit(text, .Select_Line_End)

//         case: // Quadruple click and beyond
//             text_edit(text, .Start)
//             text_edit(text, .Select_End)
//         }
//     }

//     if text.drag_selecting {
//         text_move_drag_selection(text, mouse_position())
//     }

//     if text.drag_selecting && left_or_middle_released {
//         text_end_drag_selection(text)
//         release_mouse_hover()
//     }
// }

// text_edit_with_keyboard :: proc(text: ^Editable_Text_Line) {
//     if !text.is_editable do return
//     if keyboard_focus() != text.id do return

//     text_input := text_input()
//     if len(text_input) > 0 {
//         text_input_string(text, text_input)
//     }

//     ctrl := key_down(.Left_Control) || key_down(.Right_Control)
//     shift := key_down(.Left_Shift) || key_down(.Right_Shift)

//     for key in key_presses(repeating = true) {
//         #partial switch key {
//         case .Escape: release_keyboard_focus()
//         // case .Enter, .Pad_Enter: edit(text, .New_Line)
//         case .A: if ctrl do text_edit(text, .Select_All)
//         case .C: if ctrl do text_edit(text, .Copy)
//         case .V: if ctrl do text_edit(text, .Paste)
//         case .X: if ctrl do text_edit(text, .Cut)
//         case .Y: if ctrl do text_edit(text, .Redo)
//         case .Z: if ctrl do text_edit(text, .Undo)

//         case .Home:
//             switch {
//             case ctrl && shift: text_edit(text, .Select_Start)
//             case shift: text_edit(text, .Select_Line_Start)
//             case ctrl: text_edit(text, .Start)
//             case: text_edit(text, .Line_Start)
//             }

//         case .End:
//             switch {
//             case ctrl && shift: text_edit(text, .Select_End)
//             case shift: text_edit(text, .Select_Line_End)
//             case ctrl: text_edit(text, .End)
//             case: text_edit(text, .Line_End)
//             }

//         case .Insert:
//             switch {
//             case ctrl: text_edit(text, .Copy)
//             case shift: text_edit(text, .Paste)
//             }

//         case .Backspace:
//             switch {
//             case ctrl: text_edit(text, .Delete_Word_Left)
//             case: text_edit(text, .Backspace)
//             }

//         case .Delete:
//             switch {
//             case ctrl: text_edit(text, .Delete_Word_Right)
//             case shift: text_edit(text, .Cut)
//             case: text_edit(text, .Delete)
//             }

//         case .Left_Arrow:
//             switch {
//             case ctrl && shift: text_edit(text, .Select_Word_Left)
//             case shift: text_edit(text, .Select_Left)
//             case ctrl: text_edit(text, .Word_Left)
//             case: text_edit(text, .Left)
//             }

//         case .Right_Arrow:
//             switch {
//             case ctrl && shift: text_edit(text, .Select_Word_Right)
//             case shift: text_edit(text, .Select_Right)
//             case ctrl: text_edit(text, .Word_Right)
//             case: text_edit(text, .Right)
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

// text_caret_rectangle :: proc(text: ^Editable_Text_Line) -> (rectangle: Rectangle) {
//     glyph_count := len(text.glyphs)

//     rectangle.position = text.position
//     rectangle.size = {CARET_WIDTH, text.size.y}

//     if glyph_count == 0 do return

//     head := text.edit_state.selection[0]
//     caret_rune_index, caret_oob := text_byte_index_to_rune_index(text, head)

//     if caret_oob || caret_rune_index >= len(text.glyphs) {
//         rectangle.position.x += text.glyphs[glyph_count - 1].position + text.glyphs[glyph_count - 1].width
//     } else {
//         rectangle.position.x += text.glyphs[caret_rune_index].position
//     }

//     return
// }

// text_selection_rectangle :: proc(text: ^Editable_Text_Line) -> (rectangle: Rectangle, exists: bool) {
//     glyph_count := len(text.glyphs)

//     if glyph_count == 0 do return

//     height := font_metrics(text.font).line_height

//     low, high := text_sorted_selection(text)
//     if high > low {
//         left_rune_index, left_oob := text_byte_index_to_rune_index(text, low)
//         if left_oob do left_rune_index = glyph_count - 1

//         right_rune_index, right_oob := text_byte_index_to_rune_index(text, high)
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

// text_byte_index_at_x :: proc(text: ^Editable_Text_Line, x: f32) -> int {
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

// _text_update_str :: proc(text: ^Editable_Text_Line) {
//     text.str = strings.to_string(text.builder)
//     text.needs_remeasure = true
// }

// _text_update_edit_state_line_start_and_end :: proc(text: ^Editable_Text_Line) {
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

// //==========================================================================
// // Overloads
// //==========================================================================

// text_init :: proc {
//     text_line_init,
//     editable_text_line_init,
// }

// text_destroy :: proc {
//     text_line_destroy,
//     editable_text_line_destroy,
// }

// text_update :: proc {
//     text_line_update,
//     editable_text_line_update,
// }

// text_draw :: proc {
//     text_line_draw,
//     editable_text_line_draw,
// }