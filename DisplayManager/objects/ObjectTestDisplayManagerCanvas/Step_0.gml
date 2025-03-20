//Toggle fullscreen
if (keyboard_check_pressed(vk_space)) window_set_fullscreen(!window_get_fullscreen());

//Change monitor
var _monitor_index = 0;
repeat(array_length(display_monitor_list()))
{
    if keyboard_check_pressed(ord(string(_monitor_index + 1))) display_monitor_set(_monitor_index);
    ++_monitor_index;
}

//Test for Canvas before Canvas stuff so we can test Display-only features
if (instance_exists(ObjectDisplayManagerCanvas))
{
    //Toggle overlay
    if (keyboard_check_pressed(vk_tab)) display_canvas_overlay_set(!display_canvas_overlay());
    
    //Cycle scale modes
    var _mode_list = [CANVAS_MODE.SHARP, CANVAS_MODE.CRISP, CANVAS_MODE.SMOOTH];
    var _mode_index = 0;
    repeat(array_length(_mode_list))
    {
        if (_mode_list[_mode_index] == display_canvas_mode()) break;
        ++_mode_index;
    }
    _mode_index += keyboard_check_pressed(vk_down) - keyboard_check_pressed(vk_up);
    if (_mode_index < 0) _mode_index = array_length(_mode_list) - 1;
    if (_mode_index >= array_length(_mode_list)) _mode_index = 0;
    display_canvas_mode_set(_mode_list[_mode_index]);
    
    //Cycle orientations
    var _orientation_list = [display_portrait_flipped, display_landscape_flipped, display_portrait, display_landscape];
    var _orientation_index = 0;
    repeat(array_length(_orientation_list))
    {
        if (_orientation_list[_orientation_index] == display_canvas_orientation()) break;
        ++_orientation_index;
    }
    _orientation_index += keyboard_check_pressed(vk_right) - keyboard_check_pressed(vk_left);
    if (_orientation_index < 0) _orientation_index = array_length(_orientation_list) - 1;
    if (_orientation_index >= array_length(_orientation_list)) _orientation_index = 0;
    display_canvas_orientation_set(_orientation_list[_orientation_index]);
}
