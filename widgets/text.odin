package widgets

import "core:fmt"
import "core:mem"
import "core:strings"
import "../../gui"

Font :: gui.Font
Glyph :: gui.Glyph

Text :: struct {
    position: Vec2,
    size: Vec2,
    builder: strings.Builder,
    font: ^Font,
    font_size: f32,
    selection_head: int,
    selection_tail: int,

    // Read-only.
    glyphs: [dynamic]Glyph,
    ascender: f32,
    descender: f32,
    x_height: f32,
}

make_text :: proc(
    data := "",
    position := Vec2{0, 0},
    font := _default_font,
    font_size := f32(13),
    allocator := context.allocator,
) -> (res: Text, err: mem.Allocator_Error) #optional_allocator_error {
    res = {
        font = font,
        font_size = font_size,
        glyphs = make([dynamic]Glyph, allocator) or_return,
    }
    strings.builder_init(&res.builder, allocator) or_return
    strings.write_string(&res.builder, data)
    return
}

destroy_text :: proc(text: ^Text) {
    strings.builder_destroy(&text.builder)
    delete(text.glyphs)
}

update_text :: proc(text: ^Text) {
    if text.font == nil do text.font = _default_font
    if text.font_size <= 0 do text.font_size = 13

    ascender, descender, line_height := gui.text_metrics(text.font, text.font_size)
    text.ascender = ascender
    text.descender = descender
    text.x_height = ascender + descender

    gui.measure_glyphs(&text.glyphs, strings.to_string(text.builder), text.font, text.font_size)

    if len(text.glyphs) > 0 {
        text.size.x = text.glyphs[len(text.glyphs) - 1].right - text.glyphs[0].left
    } else {
        text.size.x = 0
    }
    text.size.y = line_height
}

draw_text :: proc(text: ^Text, color := Color{1, 1, 1, 1}, selection_color := Color{0.36, 0.6, 0.98, 0.6}, show_selection := false) {
    if text.font == nil || text.font_size <= 0 {
        return
    }

    if show_selection {
        _draw_selection(text, selection_color)
    }

    if strings.builder_len(text.builder) == 0 || len(text.glyphs) == 0 {
        return
    }

    text_offset := Vec2{
        text.glyphs[0].draw_offset_x,
        text.size.y * 0.5 - text.x_height,
    }

    gui.fill_text_raw(
        strings.to_string(text.builder),
        text.position + text_offset,
        color = color,
        font = text.font,
        font_size = text.font_size,
    )
}

edit_text :: proc(text: ^Text, selection_color := Color{0.36, 0.6, 0.98, 0.6}) {
    if text.font == nil do text.font = _default_font
    if text.font_size <= 0 do text.font_size = 13

    hover_index := index_at_position(text, gui.mouse_position())

    shift := gui.key_down(.Left_Shift) || gui.key_down(.Right_Shift)
    control := gui.key_down(.Left_Control) || gui.key_down(.Right_Control)

    gui.set_cursor_style(.I_Beam)

    if gui.mouse_pressed(.Left) {
        move_caret(text, hover_index)
    }
    if gui.mouse_down(.Left){
        drag_selection(text, hover_index)
    }

    if gui.key_pressed(.Backspace, true) {
        backspace_text(text)
    }

    if gui.key_pressed(.Left_Arrow, true) {
        if shift {
            nudge_selection(text, -1)
        } else {
            nudge_caret(text, -1)
        }
    }

    if gui.key_pressed(.Right_Arrow, true) {
        if shift {
            nudge_selection(text, 1)
        } else {
            nudge_caret(text, 1)
        }
    }

    if control && gui.key_pressed(.C) {
        gui.set_clipboard(selection_to_string(text))
    }

    if control && gui.key_pressed(.V, true) {
        input_string(text, gui.get_clipboard())
    }

    if control && gui.key_pressed(.A) {
        select_all(text)
    }

    if !control {
        if data := gui.text_input(); data != "" {
            input_string(text, data)
        }
    }
}

index_at_position :: proc(text: ^Text, position: Vec2) -> int {
    if position.x < text.position.x {
        return 0
    }

    for glyph, i in text.glyphs {
        left := text.position.x + glyph.left
        right := text.position.x + glyph.right

        if position.x >= left && position.x < right {
            return i
        }
    }

    return len(text.glyphs)
}

set_text :: proc(text: ^Text, data: string) {
    strings.builder_reset(&text.builder)
    strings.write_string(&text.builder, data)
}

move_caret :: proc(text: ^Text, index: int) {
    text.selection_tail = index
    text.selection_head = index
}

nudge_caret :: proc(text: ^Text, amount: int) {
    text.selection_head += amount
    text.selection_tail = text.selection_head
}

drag_selection :: proc(text: ^Text, index: int) {
    text.selection_head = index
}

nudge_selection :: proc(text: ^Text, amount: int) {
    text.selection_head += amount
}

get_selection :: proc(text: ^Text) -> (low, high: int) {
    low = clamp(min(text.selection_tail, text.selection_head), 0, strings.builder_len(text.builder))
    high = clamp(max(text.selection_tail, text.selection_head), 0, strings.builder_len(text.builder))
    return low, high
}

select_all :: proc(text: ^Text) {
    text.selection_tail = 0
    text.selection_head = strings.builder_len(text.builder)
}

text_is_selected :: proc(text: ^Text) -> bool {
    return abs(text.selection_head - text.selection_tail) > 0
}

delete_selection :: proc(text: ^Text) {
    low, high := get_selection(text)
    remove_range(&text.builder.buf, low, high)
    text.selection_tail = low
    text.selection_head = low
}

to_string :: proc(text: ^Text) -> string {
    return strings.to_string(text.builder)
}

selection_to_string :: proc(text: ^Text) -> string {
    low, high := get_selection(text)
    return string(text.builder.buf[low:high])
}

backspace_text :: proc(text: ^Text) {
    if !text_is_selected(text) {
        text.selection_head -= 1
    }
    delete_selection(text)
}

input_string :: proc(text: ^Text, data: string) {
    if len(data) == 0 {
		return
	}
	if text_is_selected(text) {
		delete_selection(text)
	}
    inject_at(&text.builder.buf, text.selection_tail, data)
    text.selection_tail += len(data)
    text.selection_head += len(data)
}

_draw_selection :: proc(text: ^Text, color: Color) {
    low, high := get_selection(text)

    // Draw selection.
    if high - low > 0 {
        if strings.builder_len(text.builder) == 0 || len(text.glyphs) == 0 {
            return
        }

        low := clamp(low, 0, len(text.glyphs) - 1)

        selection_position := text.position + {text.glyphs[low].left, 0}

        selection_size := Vec2{0, text.size.y}
        if high < len(text.glyphs) {
            selection_size.x += text.glyphs[high - 1].right - text.glyphs[low].left
        } else {
            selection_size.x += text.glyphs[len(text.glyphs) - 1].right - text.glyphs[low].left
        }

        gui.begin_path()
        gui.path_rounded_rect(selection_position, selection_size, 3)
        gui.fill_path(color)

    // Draw caret.
    } else {
        pixel := gui.pixel_distance()

        caret_position := text.position + {pixel * 0.5, 0}
        if len(text.glyphs) > 0 {
            if low < len(text.glyphs) {
                low := max(low, 0)
                caret_position.x += text.glyphs[low].left
            } else {
                caret_position.x += text.glyphs[len(text.glyphs) - 1].right
            }
        }

        gui.begin_path()
        gui.path_move_to(caret_position)
        gui.path_line_to(caret_position + {0, text.size.y})
        gui.stroke_path(color, pixel)
    }
}