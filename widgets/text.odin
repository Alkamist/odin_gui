package widgets

import "core:mem"
import "core:strings"
import "../../gui"

Text_Line :: struct {
    start: int,
    length: int,
}

Text :: struct {
    using widget: gui.Widget,
    builder: strings.Builder,
    color: Color,
    font: gui.Font,
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
    strings.builder_init(&text.builder, allocator = allocator)
    strings.write_string(&text.builder, str)
    text.font = font
    text.color = color
    text.lines = make([dynamic]Text_Line, allocator) or_return
    return text, nil
}

destroy_text :: proc(text: ^Text) {
    strings.builder_destroy(&text.builder)
    delete(text.lines)
    gui.destroy_widget(text)
}

line_string :: proc(text: ^Text, line: Text_Line) -> string {
    return string(text.builder.buf[line.start:][:line.length])
}

update_text_lines :: proc(text: ^Text) {
    clear(&text.lines)

    n := len(text.builder.buf)
    i := 0
    line_start := 0

    for i < n {
        c := text.builder.buf[i]
        if c == '\n' {
            append(&text.lines, Text_Line{line_start, i - line_start})
            i += 1
            line_start = i
        } else {
            i += 1
        }
    }

    if line_start < n {
        append(&text.lines, Text_Line{line_start, i - line_start})
    }
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

            update_text_lines(text)

            metrics := gui.font_metrics(text.font)
            position: Vec2

            for line in text.lines {
                gui.draw_text(line_string(text, line), position, text.font, text.color)
                position.y += metrics.line_height
            }
        }
    }
}