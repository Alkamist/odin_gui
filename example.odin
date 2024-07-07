package main

import "core:fmt"
import "core:mem"

// This is a track manager I made to help with organizing large projects
// in the DAW Reaper. It runs as an extension in Reaper, but this is a
// standalone version of it for demonstration.
//
// The idea is to enable the user to be able to create track groups and
// arrange them in 2D space. The user can assign multiple tracks to
// multiple groups. When the user selects these groups in the editor,
// the tracks in Reaper become visible.
//
// There are two kinds of track groups: regular (green), and sections (purple).
// Regular groups represent categories, such as drums, vocals, guitars, etc...
// Sections represent parts of the song, such as Verse, Chorus, Bridge, etc...
// These categories behave slightly differently in how they affect track visibility.
//
// The controls are as follows:
//
// Double click to make a new group, which will immediately be renamable.
// Use the left mouse button to select groups.
// Use the right mouse button and drag to box-select groups.
// Hold shift while selecting to add to the current selection.
// Hold control while selecting to toggle the selection.
// Push the "Edit" button in the upper left corner to enable the groups to be relatively positioned.
// Drag groups with the left mouse button to move them.
// Drag anywhere with the middle mouse button to move all groups.
// Push F2 to rename the selected groups.
// Push C to center existing groups.
// Use the green and purple buttons on the toolbar to change the type of selected groups.
// The - and + buttons are for adding tracks in Reaper to selected groups.
// Push Delete while some groups are selected to open a prompt to confirm deleting those groups.

running := true

gui_update :: proc() {
    if window_update(&track_manager_window) {
        clear_background({0.2, 0.2, 0.2, 1})
        track_manager_update(&track_manager)
        free_all(context.temp_allocator)
    }
    if !track_manager_window.is_open {
        running = false
    }
}

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
            fmt.println("Success")
        }
    }

    window_init(&track_manager_window, {{100, 100}, {400, 300}})
    defer window_destroy(&track_manager_window)
    track_manager_window.open_requested = true

    track_manager_init(&track_manager)
    defer track_manager_destroy(&track_manager)

    for running {
        poll_window_events()
        gui_update()
    }
}