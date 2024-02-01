package widgets

// import "../../gui"

// Text :: struct {
//     using widget: gui.Widget,
//     data: string,
//     color: Color,
//     font: gui.Font,
// }

// init_text :: proc(
//     text: ^Text,
//     parent: ^gui.Widget,
//     position := Vec2{0, 0},
//     size := Vec2{0, 0},
//     data := "",
//     color := Color{1, 1, 1, 1},
//     font: gui.Font = nil,
//     event_proc: proc(^gui.Widget, ^gui.Widget, any) = text_event_proc,
// ) {
//     gui.init_widget(
//         text,
//         parent,
//         position = position,
//         size = size,
//         event_proc = event_proc,
//     )
//     text.data = data
//     text.font = font
//     text.color = color
// }

// destroy_text :: proc(text: ^Text) {
//     gui.destroy_widget(text)
// }

// text_event_proc :: proc(widget, subject: ^gui.Widget, event: any) {
//     text := cast(^Text)widget

//     switch subject {
//     case nil:
//         switch e in event {
//         case gui.Open_Event: gui.redraw()
//         }

//     case widget:
//         switch e in event {
//         case gui.Draw_Event:
//             gui.draw_text(text.data, {0, 0}, text.font, text.color)
//         }
//     }
// }


















// set_font :: proc(text: ^Text, font: gui.Font) {
//     text.font = font
//     _update_font_metrics(text)
// }

// set_text :: proc(text: ^Text, data: string) {
//     text.data = data
//     _update_text_measurement(text)
// }

// _update_font_metrics :: proc(text: ^Text) {
//     metrics, err := gui.font_metrics(text.font, text)
//     if err != nil {
//         text.needs_font_metrics_update = true
//         return
//     }
//     text.needs_font_metrics_update = false
//     text.font_metrics = metrics
//     text.size.y = text.font_metrics.line_height
//     _update_text_measurement(text)
//     gui.redraw()
// }

// _update_text_measurement :: proc(text: ^Text) {
//     if len(text.data) == 0 {
//         text.size.x = 0
//     } else {
//         width, err := gui.measure_text(text.data, text.font)
//         if err != nil {
//             text.needs_text_measurement_update = true
//             return
//         }
//         text.needs_text_measurement_update = false
//         text.size.x = width
//     }
//     gui.redraw()
// }