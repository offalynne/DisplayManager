DisplayManager

Console, PC and mobile native GMS2 display manager

Features
- Monitor details, active identification and selection
- Orientation change for rotated output including TATE
- Variable aspect ratio support with overscan cropping
- Sharp bilinear resolution upscaling for clean pixels
- Bicubic resolution downscaling for preserving detail

Quick Start
1. Set RoomDisplayManagerInit as first room for Canvas
2. Change CanvasManager macro values for initial state 

display_canvas_orientation()
 Get Canvas orientation
 Returns display_landscape, display_landscape_flipped, display_portrait, or display_portrait_flipped

display_canvas_orientation_set(orientation, [resize])
 Set Canvas orientation
 Use display_landscape, display_landscape_flipped, display_portrait, or display_portrait_flipped

display_canvas_mode()
 Get Canvas mode
 Returns DISPLAY_MODE_PIXEL_PERFECT, DISPLAY_MODE_FIT_SHARP, or DISPLAY_MODE_FIT_SMOOTH

display_canvas_mode_set(mode)
 Set Canvas mode
 Use DISPLAY_MODE_PIXEL_PERFECT, DISPLAY_MODE_FIT_SHARP, or DISPLAY_MODE_FIT_SMOOTH

display_canvas_overlay()
 Get Canvas overlay state
 Returns boolean

display_canvas_overlay_set(enabled)
 Set Canvas overlay state
 Returns boolean

display_canvas_x()
 Get Canvas X position
 Returns numeric value

display_canvas_y()
 Get Canvas Y position
 Returns numeric value

display_canvas_width()
 Get Canvas Width
 Returns numeric value

display_canvas_height()
 Get Canvas Height
 Returns numeric value

display_canvas_scale()
 Get Canvas scale
 Returns numeric value

display_canvas_point_to_gui_x(x, y)
 Get X component of Canvas point in GUI coordinate space
 Returns numeric value

display_canvas_point_to_gui_y(x, y)
 Get Y component of Canvas point in GUI coordinate space
 Returns numeric value

display_gui_point_to_canvas_x(x, y)
 Get X component of GUI point in Canvas coordinate space
 Returns numeric value

display_gui_point_to_canvas_y(x, y)
 Get Y component of GUI point in Canvas coordinate space
 Returns numeric value

display_canvas_size_set(minWidth, minHeight, [maxWidth], [maxHeight])
 Set canvas size
 Use numeric values

Community: discord.gg/8krYCqr

@offalynne, 2024
MIT licensed, use as you please
