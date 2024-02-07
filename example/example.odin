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
// slider: widgets.Slider
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

    widgets.init_text(&text)
    defer widgets.destroy_text(&text)
    gui.set_parent(&text, &window.root)
    text.position = {100, 100}
    text.size = {400, 400}
    text.font = &consola
    widgets.input_text(&text, SAMPLE_TEXT)

    for &button, i in buttons {
        widgets.init_button(&button)
        if i == 0 {
            gui.set_parent(&button, &window.root)
        } else {
            gui.set_parent(&button, &buttons[i - 1])
        }

        button.position = {
            f32(i * 20),
            f32(i * 20),
        }
        button.size = {
            32 + rand.float32() * 100,
            32 + rand.float32() * 100,
        }
        button.color = {
            0.5 + rand.float32() * 0.5,
            0.5 + rand.float32() * 0.5,
            0.5 + rand.float32() * 0.5,
            1,
        }

        button.response_proc = proc(button: ^widgets.Button, event: widgets.Button_Event) {
            #partial switch e in event {
            case widgets.Button_Click_Event:
                fmt.println("Clicked")
            }
        }

        button.event_proc = proc(widget: ^gui.Widget, event: gui.Event) {
            button := cast(^widgets.Button)widget
            widgets.button_event_proc(button, event)

            #partial switch e in event {
            case gui.Window_Mouse_Press_Event:
                if e.button == .Extra_1 {
                    gui.show(button)
                }

            case gui.Mouse_Press_Event:
                if e.button == .Middle {
                    gui.hide(button)
                }

            case gui.Window_Mouse_Move_Event:
                if gui.mouse_down(.Right) {
                    gui.set_position(button, button.position + e.delta)
                    gui.redraw()
                }
                if gui.mouse_hover() == button && button.is_down {
                    gui.set_position(button, button.position + e.delta)
                    gui.redraw()
                }
            }
        }
    }
    defer for &button in buttons {
        widgets.destroy_button(&button)
    }

    // widgets.init_slider(&slider)
    // defer widgets.destroy_slider(&slider)
    // gui.set_parent(&slider, &button)
    // slider.position = {50, 50}

    open_window(&window)
    for window_is_open(&window) {
        update()
        free_all(context.temp_allocator)
    }
}