draw_clear(0);
draw_sprite_tiled_ext(SpriteTestDisplayManagerMotion, 0, 0, frame div 2, 1, 1, c_gray, 1);
draw_sprite(SpriteTestDIsplayManagerLinearity, 0, display_gui_point_to_canvas_x(window_get_width()/2, window_get_height()/2), display_gui_point_to_canvas_y(window_get_width()/2, window_get_height()/2));
frame++;