package main

import "core:fmt"
import "core:slice"
import "core:strings"

TRACK_GROUP_PADDING :: 8
TRACK_GROUP_MIN_WIDTH :: 48

Track_Group :: struct {
    using rectangle: Rectangle,
    is_selected: bool,
    position_when_drag_started: Vector2,
    name: strings.Builder,
    editable_name: Editable_Text_Line,
    button: Button,
}

track_group_init :: proc(group: ^Track_Group) {
    strings.builder_init(&group.name)
    editable_text_line_init(&group.editable_name, &group.name)
    button_base_init(&group.button)
}

track_group_destroy :: proc(group: ^Track_Group) {
    strings.builder_destroy(&group.name)
    editable_text_line_destroy(&group.editable_name)
}

track_group_name_rectangle :: proc(group: ^Track_Group, font: Font) -> (res: Rectangle) {
    res.position = pixel_snapped(group.position + TRACK_GROUP_PADDING * 0.5)
    res.size = measure_string(strings.to_string(group.name), font)
    return
}

track_group_update_rectangle :: proc(group: ^Track_Group, name_rectangle: Rectangle) {
    group.position = pixel_snapped(group.position)
    group.size = name_rectangle.size + TRACK_GROUP_PADDING
    group.size.x = max(group.size.x, TRACK_GROUP_MIN_WIDTH)
}

track_group_draw_frame :: proc(group: ^Track_Group) {
    pixel := pixel_size()
    fill_rounded_rectangle(group.rectangle, 3, {0.2, 0.2, 0.2, 1})
    if group.is_selected {
        outline_rounded_rectangle(group.rectangle, 3, pixel.x, {0.6, 0.6, 0.6, 1})
    } else {
        outline_rounded_rectangle(group.rectangle, 3, pixel.x, {0.3, 0.3, 0.3, 1})
    }
}

Track_Manager_State :: enum {
    Editing,
    Renaming,
    Confirm_Delete,
}

Track_Manager :: struct {
    state: Track_Manager_State,
    state_changed: bool,
    font: Font,
    groups: [dynamic]^Track_Group,
    is_dragging_groups: bool,
    group_movement_is_locked: bool,
    mouse_position_when_drag_started: Vector2,
    box_select: Box_Select,
    background_button: Button,
    delete_prompt_yes_button: Button,
    delete_prompt_no_button: Button,
}

track_manager_init :: proc(manager: ^Track_Manager, font: Font) {
    manager.font = font
    button_base_init(&manager.background_button)
    button_base_init(&manager.delete_prompt_yes_button)
    button_base_init(&manager.delete_prompt_no_button)
}

track_manager_destroy :: proc(manager: ^Track_Manager) {
    for group in manager.groups {
        track_group_destroy(group)
        free(group)
    }
    delete(manager.groups)
}

track_manager_create_new_group :: proc(manager: ^Track_Manager, position: Vector2) {
    group := new(Track_Group)
    track_group_init(group)
    group.position = position
    group.is_selected = true
    append(&manager.groups, group)
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

track_manager_bring_groups_to_front :: proc(manager: ^Track_Manager, groups: []^Track_Group) {
    keep_position := 0
    for i in 0 ..< len(manager.groups) {
        if !slice.contains(groups, manager.groups[i]) {
            if keep_position != i {
                manager.groups[keep_position] = manager.groups[i]
            }
            keep_position += 1
        }
    }
    resize(&manager.groups, keep_position)
    append(&manager.groups, ..groups)
}

track_manager_bring_selected_groups_to_front :: proc(manager: ^Track_Manager) {
    selected_groups := make([dynamic]^Track_Group, context.temp_allocator)
    for group in manager.groups {
        if group.is_selected {
            append(&selected_groups, group)
        }
    }
    track_manager_bring_groups_to_front(manager, selected_groups[:])
}

track_manager_unselect_all_groups :: proc(manager: ^Track_Manager) {
    for group in manager.groups {
        group.is_selected = false
    }
}

track_manager_selected_group_count :: proc(manager: ^Track_Manager) -> (res: int) {
    for group in manager.groups {
        if group.is_selected {
            res += 1
        }
    }
    return
}

track_manager_remove_selected_groups :: proc(manager: ^Track_Manager) {
    selected_groups := make([dynamic]^Track_Group, context.temp_allocator)
    for group in manager.groups {
        if group.is_selected {
            append(&selected_groups, group)
        }
    }

    keep_position := 0
    for i in 0 ..< len(manager.groups) {
        if !manager.groups[i].is_selected {
            if keep_position != i {
                manager.groups[keep_position] = manager.groups[i]
            }
            keep_position += 1
        }
    }
    resize(&manager.groups, keep_position)

    for group in selected_groups {
        track_group_destroy(group)
        free(group)
    }
}

track_manager_center_groups :: proc(manager: ^Track_Manager, rectangle: Rectangle) {
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
    view_center := rectangle.size * 0.5

    offset := pixel_snapped(view_center - center)

    for group in manager.groups {
        group.position += offset
    }
}

track_manager_update :: proc(manager: ^Track_Manager) {
    previous_state := manager.state

    rectangle := Rectangle{{0, 0}, current_window().size}

    scoped_clip(rectangle)
    scoped_offset(rectangle.position)

    relative_rectangle := Rectangle{{0, 0}, rectangle.size}

    switch manager.state {
    case .Editing: _track_manager_editing(manager, relative_rectangle)
    case .Renaming: _track_manager_renaming(manager, relative_rectangle)
    case .Confirm_Delete: _track_manager_confirm_delete(manager, relative_rectangle)
    }

    manager.state_changed = manager.state != previous_state
}

_track_manager_renaming :: proc(manager: ^Track_Manager, rectangle: Rectangle) {
    if key_pressed(.Enter) || key_pressed(.Escape) {
        manager.state = .Editing
    }

    invisible_button_update(&manager.background_button, rectangle)
    if manager.background_button.pressed {
        track_manager_unselect_all_groups(manager)
        manager.state = .Editing
    }

    for group in manager.groups {
        if manager.state_changed {
            editable_text_line_edit(&group.editable_name, .Select_All)
        }

        name_rectangle := track_group_name_rectangle(group, manager.font)
        track_group_update_rectangle(group, name_rectangle)

        track_group_draw_frame(group)

        invisible_button_update(&group.button, group.rectangle)

        if group.button.pressed {
            track_manager_selection_logic(manager, {group}, false)
            editable_text_line_edit(&group.editable_name, .Select_All)
        }

        if group.is_selected {
            editable_text_line_update(&group.editable_name, name_rectangle, manager.font, {1, 1, 1, 1})
        } else {
            fill_string(strings.to_string(group.name), name_rectangle.position, manager.font, {1, 1, 1, 1})
        }
    }
}

_track_manager_editing :: proc(manager: ^Track_Manager, rectangle: Rectangle) {
    mouse_pos := mouse_position()
    start_dragging_groups := false
    group_pressed := false

    if key_pressed(.F2) {
        manager.state = .Renaming
    }

    if key_pressed(.Enter) {
        track_manager_unselect_all_groups(manager)
        track_manager_create_new_group(manager, mouse_pos)
        manager.state = .Renaming
    }

    if key_pressed(.Delete) && track_manager_selected_group_count(manager) > 0 {
        manager.state = .Confirm_Delete
    }

    if key_pressed(.C) {
        track_manager_center_groups(manager, rectangle)
    }

    if key_pressed(.L) {
        manager.group_movement_is_locked = !manager.group_movement_is_locked
    }

    // Group logic

    invisible_button_update(&manager.background_button, rectangle)
    if manager.background_button.pressed {
        for group in manager.groups {
            group.is_selected = false
        }
    }

    for group in manager.groups {
        name_rectangle := track_group_name_rectangle(group, manager.font)
        track_group_update_rectangle(group, name_rectangle)

        track_group_draw_frame(group)

        invisible_button_update(&group.button, group.rectangle)
        fill_string(strings.to_string(group.name), name_rectangle.position, manager.font, {1, 1, 1, 1})

        if group.button.pressed {
            group_pressed = true
            track_manager_selection_logic(manager, {group}, false)
            start_dragging_groups = group.is_selected
        }
    }

    if group_pressed {
        track_manager_bring_selected_groups_to_front(manager)
    }

    // Dragging logic

    if mouse_pressed(.Middle) && mouse_clip_test() {
        start_dragging_groups = true
    }

    if start_dragging_groups {
        manager.is_dragging_groups = true
        manager.mouse_position_when_drag_started = mouse_pos
    }

    if manager.is_dragging_groups && !mouse_down(.Left) && !mouse_down(.Middle) {
        manager.is_dragging_groups = false
    }

    if !manager.group_movement_is_locked && manager.is_dragging_groups {
        drag_delta := mouse_pos - manager.mouse_position_when_drag_started
        for group in manager.groups {
            if start_dragging_groups {
                group.position_when_drag_started = group.position
            }
            if group.is_selected || mouse_down(.Middle) {
                group.position = group.position_when_drag_started + drag_delta
            }
        }
    }

    // Box select logic

    box_select_update(&manager.box_select, .Right)
    if manager.box_select.selected {
        groups_touched_by_box_select := make([dynamic]^Track_Group, context.temp_allocator)
        for group in manager.groups {
            if rectangle_intersects(manager.box_select.rectangle, group, true) {
                append(&groups_touched_by_box_select, group)
            }
        }
        track_manager_selection_logic(manager, groups_touched_by_box_select[:], false)
    }
}

_track_manager_confirm_delete :: proc(manager: ^Track_Manager, rectangle: Rectangle) {
    pixel := pixel_size()

    do_abort := false
    do_delete := false

    if key_pressed(.Escape) {
        do_abort = true
    }

    if key_pressed(.Enter) {
        do_delete = true
    }

    for group in manager.groups {
        name_rectangle := track_group_name_rectangle(group, manager.font)
        track_group_update_rectangle(group, name_rectangle)
        track_group_draw_frame(group)
        fill_string(strings.to_string(group.name), name_rectangle.position, manager.font, {1, 1, 1, 1})
    }

    prompt_rectangle := Rectangle{
        pixel_snapped((rectangle.size - {290, 128}) * 0.5),
        {290, 128},
    }

    fill_rounded_rectangle(prompt_rectangle, 3, {0.4, 0.4, 0.4, 0.8})
    outline_rounded_rectangle(prompt_rectangle, 3, pixel.x, {1, 1, 1, 0.3})

    scoped_clip(prompt_rectangle)

    fill_string_aligned(
        "Delete selected groups?",
        {prompt_rectangle.position + {0, 16}, {prompt_rectangle.size.x, 24}},
        manager.font,
        {1, 1, 1, 1},
        {0.5, 0.5},
    )

    BUTTON_SPACING :: 10
    BUTTON_SIZE :: Vector2{96, 32}

    button_anchor := prompt_rectangle.position + prompt_rectangle.size * 0.5
    button_anchor.y += 12

    prompt_button :: proc(button: ^Button, rectangle: Rectangle, label: string, font: Font, outline := false) {
        invisible_button_update(button, rectangle)

        fill_rounded_rectangle(rectangle, 3, {0.1, 0.1, 0.1, 1})

        if outline {
            outline_rounded_rectangle(rectangle, 3, pixel_size().x, {0.4, 0.9, 1, 0.7})
        }

        if button.is_down {
            fill_rounded_rectangle(rectangle, 3, {0, 0, 0, 0.04})
        } else if mouse_hover() == button.id {
            fill_rounded_rectangle(rectangle, 3, {1, 1, 1, 0.04})
        }

        fill_string_aligned(label, rectangle, font, {1, 1, 1, 1}, {0.5, 0.5})
    }

    yes_button_position: Vector2
    yes_button_position = button_anchor
    yes_button_position.x -= BUTTON_SIZE.x + BUTTON_SPACING * 0.5
    prompt_button(
        &manager.delete_prompt_yes_button,
        {yes_button_position, BUTTON_SIZE},
        "Yes",
        manager.font,
        true,
    )
    if manager.delete_prompt_yes_button.clicked {
        do_delete = true
    }

    no_button_position: Vector2
    no_button_position = button_anchor
    no_button_position.x += BUTTON_SPACING * 0.5
    prompt_button(
        &manager.delete_prompt_no_button,
        {no_button_position, BUTTON_SIZE},
        "No",
        manager.font,
        false,
    )
    if manager.delete_prompt_no_button.clicked {
        do_abort = true
    }

    if do_delete {
        track_manager_remove_selected_groups(manager)
        manager.state = .Editing
    } else if do_abort {
        manager.state = .Editing
    }
}