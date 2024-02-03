package main

import "core:fmt"
import "core:mem"
import "core:math/rand"
import "../../gui"
import "../widgets"

SAMPLE_TEXT :: `Οὐχὶ ταὐτὰ παρίσταταί μοι γιγνώσκειν, ὦ ἄνδρες ᾿Αθηναῖοι,
ὅταν τ᾿ εἰς τὰ πράγματα ἀποβλέψω καὶ ὅταν πρὸς τοὺς
λόγους οὓς ἀκούω· τοὺς μὲν γὰρ λόγους περὶ τοῦ
τιμωρήσασθαι Φίλιππον ὁρῶ γιγνομένους, τὰ δὲ πράγματ᾿
εἰς τοῦτο προήκοντα,  ὥσθ᾿ ὅπως μὴ πεισόμεθ᾿ αὐτοὶ
πρότερον κακῶς σκέψασθαι δέον. οὐδέν οὖν ἄλλο μοι δοκοῦσιν
οἱ τὰ τοιαῦτα λέγοντες ἢ τὴν ὑπόθεσιν, περὶ ἧς βουλεύεσθαι,
οὐχὶ τὴν οὖσαν παριστάντες ὑμῖν ἁμαρτάνειν. ἐγὼ δέ, ὅτι μέν
ποτ᾿ ἐξῆν τῇ πόλει καὶ τὰ αὑτῆς ἔχειν ἀσφαλῶς καὶ Φίλιππον
τιμωρήσασθαι, καὶ μάλ᾿ ἀκριβῶς οἶδα· ἐπ᾿ ἐμοῦ γάρ, οὐ πάλαι
γέγονεν ταῦτ᾿ ἀμφότερα· νῦν μέντοι πέπεισμαι τοῦθ᾿ ἱκανὸν
προλαβεῖν ἡμῖν εἶναι τὴν πρώτην, ὅπως τοὺς συμμάχους
σώσομεν. ἐὰν γὰρ τοῦτο βεβαίως ὑπάρξῃ, τότε καὶ περὶ τοῦ
τίνα τιμωρήσεταί τις καὶ ὃν τρόπον ἐξέσται σκοπεῖν· πρὶν δὲ
τὴν ἀρχὴν ὀρθῶς ὑποθέσθαι, μάταιον ἡγοῦμαι περὶ τῆς
τελευτῆς ὁντινοῦν ποιεῖσθαι λόγον.`

consola := Font{"Consola", 13}

window: Window
buttons: [8]widgets.Button
slider: widgets.Slider
text: widgets.Text

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    init_window(&window,
        position = {50, 50},
        size = {400, 300},
        background_color = {0.2, 0.2, 0.2, 1},
    )
    defer destroy_window(&window)

    for &button, i in buttons {
        widgets.init_button(&button, &window.root,
            position = {f32(i * 20), f32(i * 20)},
            size = {32 + rand.float32() * 100, 32 + rand.float32() * 100},
            event_proc = proc(widget, subject: ^gui.Widget, event: any) {
                button := cast(^widgets.Button)widget
                widgets.button_event_proc(button, subject, event)

                switch subject {
                case nil:
                    switch e in event {
                    case gui.Mouse_Move_Event:
                        if gui.mouse_down(.Right) {
                            gui.set_position(button.position + e.delta)
                            gui.redraw()
                        }
                    }

                case widget:
                    switch e in event {
                    case gui.Mouse_Move_Event:
                        if button.is_down {
                            gui.set_position(button.position + e.delta)
                            gui.redraw()
                        }
                    case widgets.Button_Click_Event:
                        fmt.println("Clicked")
                    }
                }
            },
        )
    }
    defer for &button in buttons {
        widgets.destroy_button(&button)
    }

    widgets.init_slider(&slider, &window.root,
        position = {100, 100},
        // event_proc = proc(widget, subject: ^gui.Widget, event: any) {
        //     slider := cast(^widgets.Slider)widget
        //     widgets.slider_event_proc(widget, subject, event)
        //     switch subject {
        //     case widget:
        //         switch e in event {
        //         case widgets.Slider_Value_Change_Event:
        //             consola.size = slider.value * 64
        //             gui.redraw(&text)
        //         }
        //     }
        // },
    )
    defer widgets.destroy_slider(&slider)

    widgets.init_text(&text, &window.root, {50, 50}, {100, 100}, SAMPLE_TEXT, font = &consola)
    defer widgets.destroy_text(&text)

    // text.clip_children = true

    open_window(&window)
    for window_is_open(&window) {
        update()
    }
}