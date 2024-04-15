package main

import "core:fmt"
import "core:slice"
import "core:strings"

Track_Group :: struct {
    using rectangle: Rectangle,
    is_hovered: bool,
    is_selected: bool,
    is_editing_name: bool,
    position_when_drag_started: Vector2,
    name: strings.Builder,
}

track_group_init :: proc(group: ^Track_Group) {
    strings.builder_init(&group.name)
    strings.write_string(&group.name, "Ayy lmao")
}

track_group_destroy :: proc(group: ^Track_Group) {
    strings.builder_destroy(&group.name)
}

Track_Manager :: struct {
    font: Font,
    groups: [dynamic]^Track_Group,
    is_dragging_groups: bool,
    mouse_position_when_drag_started: Vector2,
    group_to_rename: ^Track_Group,
}

track_manager_update :: proc(manager: ^Track_Manager) {
    _track_manager_editing(manager)
}

track_manager_create_new_group :: proc(manager: ^Track_Manager, position: Vector2) {
    group := new(Track_Group)
    track_group_init(group)
    group.position = position
    append(&track_manager.groups, group)
}

// track_manager_bring_groups_to_front :: proc(manager: ^Track_Manager, groups: []^Track_Group) {
//     keep_if(&manager.groups, groups, proc(group: ^Track_Group, groups: []^Track_Group) -> bool {
//         return !slice.contains(groups, group)
//     })
//     append(&manager.groups, ..groups)
// }

// track_manager_bring_selected_groups_to_front :: proc(manager: ^Track_Manager) {
//     selected_groups := make([dynamic]^Track_Group, context.temp_allocator)
//     for group in manager.groups {
//         if group.is_selected {
//             append(&selected_groups, group)
//         }
//     }
//     track_manager_bring_groups_to_front(manager, selected_groups[:])
// }

track_manager_selection_logic :: proc(manager: ^Track_Manager, groups: []^Track_Group, keep_selection: bool) {
    addition := key_down(.Left_Shift)
    invert := key_down(.Left_Control)

    keep_selection := keep_selection || addition || invert

    for group in manager.groups {
        if group.is_selected && group.is_hovered {
            keep_selection = true
            break
        }
    }

    for group in manager.groups {
        if !keep_selection {
            group.is_selected = false
        }
    }

    for group in groups {
        if invert {
            group.is_selected = !group.is_selected
        } else {
            group.is_selected = true
        }
    }
}

_track_manager_editing :: proc(manager: ^Track_Manager) {
    // if key_pressed(.Enter) {
    //     track_manager_create_new_group(manager, mouse_position())
    // }

    // if key_pressed(.F2) {
    //     track_manager_rename_topmost_selected_group(manager)
    // }

    edit_name := key_pressed(.F2)

    // Update widget states and handle left click logic.

    group_pressed := false
    group_hover: ^Track_Group
    for group, i in manager.groups {
        scoped_iteration(i)

        group.position = pixel_snapped(group.position)

        color: Color = {0.4, 0.4, 0.4, 1} if group.is_selected else {0.2, 0.2, 0.2, 1}

        name_str := strings.to_string(group.name)

        glyphs := make([dynamic]Text_Glyph, context.temp_allocator)
        measure_string(name_str, manager.font, &glyphs, nil)

        group.size.y = font_metrics(manager.font).line_height
        group.size.x = 0
        if len(glyphs) > 0 {
            first := glyphs[0]
            last := glyphs[len(glyphs) - 1]
            group.size.x = last.position + last.width - first.position
        }

        button_state := invisible_button(group.rectangle)

        if edit_name {
            group.is_editing_name = !group.is_editing_name
        }

        if group.is_editing_name {
            editable_text_line(&group.name, group.rectangle, manager.font, {1, 1, 1, 1})
        } else {
            fill_string(name_str, group.position, manager.font, {1, 1, 1, 1})
        }

        group.is_hovered = mouse_hover() == button_state.id

        if button_state.pressed {
            track_manager_selection_logic(manager, {group}, false)
            group_pressed = true
        }

        if group.is_hovered {
            group_hover = group
        }
    }

    // Clear selection when left clicking empty space.

    if mouse_pressed(.Left) && !group_pressed {
        for group in manager.groups {
            group.is_selected = false
        }
    }

    // Bring selected groups to front on group left click interaction.

    // if group_pressed {
    //     track_manager_bring_selected_groups_to_front(manager)
    // }

    // Box select logic.

    if box, ok := box_select(.Right); ok {
        groups_touched_by_box_select := make([dynamic]^Track_Group, context.temp_allocator)
        for group in manager.groups {
            if rectangle_intersects(box, group, true) {
                append(&groups_touched_by_box_select, group)
            }
        }
        track_manager_selection_logic(manager, groups_touched_by_box_select[:], false)
    }

    // Dragging logic.

    if manager.is_dragging_groups && !mouse_down(.Left) && !mouse_down(.Middle) {
        manager.is_dragging_groups = false
    }

    start_left_drag := mouse_pressed(.Left) && group_hover != nil && group_hover.is_selected
    start_middle_drag := mouse_pressed(.Middle)
    start_drag := !manager.is_dragging_groups && (start_left_drag || start_middle_drag)

    if start_drag {
        manager.is_dragging_groups = true
        manager.mouse_position_when_drag_started = mouse_position()
    }

    do_left_drag := manager.is_dragging_groups && mouse_down(.Left)
    do_middle_drag := manager.is_dragging_groups && mouse_down(.Middle)

    for group in manager.groups {
        if start_drag {
            group.position_when_drag_started = group.position
        }

        if do_middle_drag || (do_left_drag && group.is_selected) {
            drag_delta := mouse_position() - manager.mouse_position_when_drag_started
            group.position = group.position_when_drag_started + drag_delta
        }
    }
}

keep_if :: proc {
    keep_if_no_user_data,
    keep_if_user_data,
}

keep_if_no_user_data :: proc(array: ^[dynamic]$T, should_keep: proc(x: T) -> bool) {
    keep_position := 0

    for i in 0 ..< len(array) {
        if should_keep(array[i]) {
            if keep_position != i {
                array[keep_position] = array[i]
            }
            keep_position += 1
        }
    }

    resize(array, keep_position)
}

keep_if_user_data :: proc(array: ^[dynamic]$T, user_data: $D, should_keep: proc(x: T, user_data: D) -> bool) {
    keep_position := 0

    for i in 0 ..< len(array) {
        if should_keep(array[i], user_data) {
            if keep_position != i {
                array[keep_position] = array[i]
            }
            keep_position += 1
        }
    }

    resize(array, keep_position)
}