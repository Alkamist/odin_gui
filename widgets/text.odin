package widgets

import "core:mem"
import "core:strings"
import "../../gui"

Text_Span :: struct {
    start: int,
    length: int,
    color: Color,
    starts_new_line: bool,
}

Text :: struct {
    using widget: gui.Widget,
    builder: strings.Builder,
    default_color: Color,
    font: gui.Font,
    spans: [dynamic]Text_Span,
}

init_text :: proc(
    text: ^Text,
    parent: ^gui.Widget,
    position := Vec2{0, 0},
    size := Vec2{0, 0},
    str := "",
    default_color := Color{1, 1, 1, 1},
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
    text.default_color = default_color
    text.spans = make([dynamic]Text_Span, allocator) or_return
    return text, nil
}

destroy_text :: proc(text: ^Text) {
    strings.builder_destroy(&text.builder)
    delete(text.spans)
    gui.destroy_widget(text)
}

text_span_string :: proc(text: ^Text, start, length: int) -> string {
    return string(text.builder.buf[start:][:length])
}

append_span :: proc(text: ^Text, start, length: int, color: Color, starts_new_line := false) {
    append(&text.spans, Text_Span{
        start = start,
        length = length,
        color = color,
        starts_new_line = starts_new_line,
    })
}

text_event_proc :: proc(widget, subject: ^gui.Widget, event: any) {
    text := cast(^Text)widget

    switch subject {
    case nil:
        switch e in event {
        case gui.Open_Event: gui.redraw()
        }

    case widget:
        switch e in event {
        case gui.Draw_Event:
            gui.draw_rect({0, 0}, text.size, {0.4, 0, 0, 1})
            // width := gui.measure_text(text.data, text.font)
            // metrics := gui.font_metrics(text.font)
            // gui.draw_rect({0, 0}, {width, metrics.line_height}, {0, 0.4, 0, 1})

            _update_text_spans_using_lines(text)

            metrics := gui.font_metrics(text.font)
            position: Vec2

            for span in text.spans {
                if span.starts_new_line {
                    position.x = 0
                    position.y += metrics.line_height
                }
                str := text_span_string(text, span.start, span.length)
                if len(str) == 0 do continue
                gui.draw_text(str, position, text.font, span.color)
                position.x += gui.measure_text(str, text.font)
            }
        }
    }
}



_update_text_spans_using_lines :: proc(text: ^Text) {
    clear(&text.spans)

    n := len(text.builder.buf)
    i := 0
    start := 0
    next_starts_new_line := false

    for i < n {
        c := text.builder.buf[i]

        if c == '\r' {
            append_span(text, start, i - start, text.default_color, next_starts_new_line)
            next_starts_new_line = false
            i += 1
            start = i
            continue
        }

        if c == '\n' {
            length := i - start
            if length > 0 {
                append_span(text, start, length, text.default_color, next_starts_new_line)
            }
            i += 1
            start = i
            next_starts_new_line = true
            continue
        }

        i += 1
    }

    if start < n {
        append_span(text, start, i - start, text.default_color, next_starts_new_line)
    }
}