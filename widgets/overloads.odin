package widgets

init :: proc{
    button_init,
    slider_init,
    text_line_init,
    editable_text_line_init,
}

destroy :: proc{
    text_line_destroy,
    editable_text_line_destroy,
}

update :: proc{
    button_update,
    slider_update,
    text_line_update,
    editable_text_line_update,
}

draw :: proc{
    button_draw,
    slider_draw,
    text_line_draw,
    editable_text_line_draw,
}