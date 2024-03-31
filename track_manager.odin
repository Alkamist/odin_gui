package main

import "core:slice"

Track_Group :: struct {
    using button: Button,
    name: Editable_Text_Line,
    is_selected: bool,
    position_when_drag_started: Vector2,
}

track_group_init :: proc(group: ^Track_Group) {
    button_init(&group.button)
    text_init(&group.name, default_font)
}

track_group_destroy :: proc(group: ^Track_Group) {
    text_destroy(&group.name)
}

Track_Manager_State :: enum {
    Editing,
    Renaming_Group,
}

Track_Manager :: struct {
    state: Track_Manager_State,
    groups: [dynamic]^Track_Group,
    group_edge_padding: f32,
    background_color: Color,
    // remove_groups_prompt: Remove_Groups_Prompt,
    // right_click_menu: Right_Click_Menu,
    box_select: Box_Select,
    is_dragging_groups: bool,
    mouse_position_when_drag_started: Vector2,
    group_to_rename: ^Track_Group,
}

track_manager_init :: proc(manager: ^Track_Manager) {
    manager.background_color = {0.2, 0.2, 0.2, 1}
    manager.group_edge_padding = 3
    manager.box_select.mouse_button = .Right
}

track_manager_destroy :: proc(manager: ^Track_Manager) {
    for group in manager.groups {
        track_group_destroy(group)
        free(group)
    }
    // destroy_remove_groups_prompt(&manager.remove_groups_prompt)
    delete(manager.groups)
}

track_manager_update :: proc(manager: ^Track_Manager) {
    switch manager.state {
    case .Editing:
        _track_manager_editing(manager)

    case .Renaming_Group:
        group := manager.group_to_rename

        // group.name.position = group.name.position + manager.group_edge_padding
        group.name.is_editable = true
        group.name.position = group.position + manager.group_edge_padding
        text_update(&group.name)

        group.size = pixel_snapped(group.name.size + manager.group_edge_padding * 2)

        if key_pressed(.Enter) || key_pressed(.Escape) {
            manager.group_to_rename = nil
            manager.state = .Editing
        }
    }
}

track_manager_draw :: proc(manager: ^Track_Manager) {
    for group in manager.groups {
        // Draw background.
        fill_rounded_rectangle(group, 3, manager.background_color)
        pixel_outline_rounded_rectangle(group, 3, {1, 1, 1, 0.1})

        // Outline if selected.
        if group.is_selected {
            pixel_outline_rounded_rectangle(group, 3, {1, 1, 1, 0.7})
        }

        // Draw group name text.
        text_draw(&group.name)

        // Highlight when hovered.
        if mouse_hover() == group.id {
            fill_rounded_rectangle(group, 3, {1, 1, 1, 0.08})
        }
    }

    if manager.state == .Editing {
        box_select_draw(&manager.box_select)
    }
}

track_manager_selection_logic :: proc(manager: ^Track_Manager, groups: []^Track_Group, keep_selection: bool) {
    addition := key_down(.Left_Shift)
    invert := key_down(.Left_Control)

    keep_selection := keep_selection || addition || invert

    for group in manager.groups {
        if group.is_selected && mouse_hover() == group.button.id {
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

track_manager_rename_group :: proc(manager: ^Track_Manager, group: ^Track_Group) {
    manager.group_to_rename = group
    manager.state = .Renaming_Group
    set_keyboard_focus(group.name.id)
    text_edit(&group.name, .Select_All)
}

track_manager_rename_topmost_selected_group :: proc(manager: ^Track_Manager) {
    for i := len(manager.groups) - 1; i >= 0; i -= 1 {
        group := manager.groups[i]
        if group.is_selected {
            track_manager_rename_group(manager, group)
            return
        }
    }
}

track_manager_create_new_group :: proc(manager: ^Track_Manager, position: Vector2) {
    group := new(Track_Group)
    track_group_init(group)
    group.position = position
    append(&track_manager.groups, group)
    track_manager_rename_group(manager, group)
}

track_manager_bring_groups_to_front :: proc(manager: ^Track_Manager, groups: []^Track_Group) {
    keep_if(&manager.groups, groups, proc(group: ^Track_Group, groups: []^Track_Group) -> bool {
        return !slice.contains(groups, group)
    })
    append(&manager.groups, ..groups)
}

track_manager_bring_selected_groups_to_front :: proc(manager: ^Track_Manager) {
    selected_groups := make([dynamic]^Track_Group, arena_allocator())
    for group in manager.groups {
        if group.is_selected {
            append(&selected_groups, group)
        }
    }
    track_manager_bring_groups_to_front(manager, selected_groups[:])
}

track_manager_center_groups :: proc(manager: ^Track_Manager) {
    if len(manager.groups) == 0 {
        return
    }

    top_left := Vector2{max(f32), max(f32)}
    bottom_right := Vector2{min(f32), min(f32)}

    for group in manager.groups {
        top_left.x = min(top_left.x, group.position.x)
        top_left.y = min(top_left.y, group.position.y)

        group_bottom_right := group.position + group.size

        bottom_right.x = max(bottom_right.x, group_bottom_right.x)
        bottom_right.y = max(bottom_right.y, group_bottom_right.y)
    }

    center := top_left + (bottom_right - top_left) * 0.5
    view_center := current_window().size * 0.5

    offset := pixel_snapped(view_center - center)

    for group in manager.groups {
        group.position += offset
    }
}

_track_manager_editing :: proc(manager: ^Track_Manager) {
    if key_pressed(.Enter) {
        track_manager_create_new_group(manager, mouse_position())
    }

    if key_pressed(.F2) {
        track_manager_rename_topmost_selected_group(manager)
    }

    if key_pressed(.Escape) {
        current_window().should_close = true
    }

    // Update widget states and handle left click logic.
    group_pressed := false
    group_hover: ^Track_Group
    for group in manager.groups {
        group.position = pixel_snapped(group.position)

        // Update name text.
        group.name.is_editable = false
        group.name.position = group.position + manager.group_edge_padding
        text_update(&group.name)

        // Update size to fit name.
        group.size = pixel_snapped(group.name.size + manager.group_edge_padding * 2)
        button_update(group)

        if group.pressed {
            track_manager_selection_logic(manager, {group}, false)
            group_pressed = true
        }

        if mouse_hover() == group.id {
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
    if group_pressed {
        track_manager_bring_selected_groups_to_front(manager)
    }

    // Box select logic.
    box_select_update(&manager.box_select)
    if manager.box_select.selected {
        groups_touched_by_box_select := make([dynamic]^Track_Group, arena_allocator())
        for group in manager.groups {
            if rectangle_intersects(box_select_rectangle(&manager.box_select), group, true) {
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