// feather ignore all

#macro __CANVAS_SAMPLING_SHIMMERLESS  "shimmerless"
#macro __CANVAS_SAMPLING_BILINEAR     "bilinear"
#macro __CANVAS_SAMPLING_BICUBIC      "bicubic"
#macro __CANVAS_SAMPLING_SHARP        "sharp"
#macro __CANVAS_SAMPLING_POINT        "point"

#macro __CANVAS_MODE_PIXEL_PERFECT    "pixel"
#macro __CANVAS_MODE_FIT_SHARP        "sharp"
#macro __CANVAS_MODE_FIT_SMOOTH       "smooth"

#macro __CANVAS_SHIMMERLESS_THRESHOLD  2.0

// Config (edit these!)
#macro CANVAS_APP_SURFACE_SIZE  2048  //Application size max
#macro CANVAS_INITIAL_WIDTH     320   //Initial window width
#macro CANVAS_INITIAL_HEIGHT    240   //Initial window height

#macro CANVAS_SCALE_MODE_INITIAL  __CANVAS_MODE_PIXEL_PERFECT

#macro CANVAS_SMOOTHING_THRESHOLD_MIN  -infinity
#macro CANVAS_SMOOTHING_THRESHOLD_MAX   infinity

#region Singleton

function CanvasManager(__check_object = true) { static __instance = new (function() constructor
{
    #region Setup
    
    __global = DisplayManager();

    __mode          = __CANVAS_MODE_PIXEL_PERFECT;  
    __sampling_type = __CANVAS_SAMPLING_POINT;
    __orientation   = display_landscape;
    __fill_color    = c_black;
    
    __min_width  = CANVAS_INITIAL_WIDTH;
    __min_height = CANVAS_INITIAL_HEIGHT;
    
    __max_width  = CANVAS_INITIAL_WIDTH;
    __max_height = CANVAS_INITIAL_HEIGHT;
    
    __width  = __max_width;
    __height = __max_height; 
    
    __x      = 0;
    __y      = 0;
    __top    = 0;
    __left   = 0;
    __xscale = 1;
    __yscale = 1;
    __angle  = 0;
    __blend  = c_white;
    
    __overlay_enabled = false;
    __configured      = false;
    
    __debug_background_color = c_black;
    __debug_text_color       = c_white;
    __debug_text_font        = undefined;
    
    __orientation_change = __orientation;
    __mode_change        = __mode;
    __min_width_change   = __min_width;
    __min_height_change  = __min_height;    
    __max_width_change   = __max_width;
    __max_height_change  = __max_height;
    
    __point = { x:0, y:0 };
    
    #endregion
    
    #region Utilities
    
    __draw_debug_rect = function(_outline, _x, _y, _width, _height, _color, _alpha)
    {
        //GM's primitives do not rasterize consistently across platforms 
        //so we are using sprite drawing for accurate debug drawing here
        if (_outline) { draw_sprite_ext(SpriteDisplayManagerRectOutline, 0, _x, _y, _width/9, _height/9, 0, _color, _alpha); }
        else          { draw_sprite_ext(SpriteDisplayManagerRectSolid,   0, _x, _y, _width/2, _height/2, 0, _color, _alpha); }
    }
    
    __gui_to_canvas_point = function(_x, _y)
    {
        switch (__orientation)
        {
            case display_landscape:         __point.x =  (_x - __x)/__xscale + __left; __point.y =  (_y - __y)/__yscale + __top; break;
            case display_landscape_flipped: __point.x = -(_x - __x)/__xscale + __left; __point.y = -(_y - __y)/__yscale + __top; break;
            case display_portrait:          __point.x = -(_y - __y)/__yscale + __left; __point.y =  (_x - __x)/__xscale + __top; break;
            case display_portrait_flipped:  __point.x =  (_y - __y)/__yscale + __left; __point.y = -(_x - __x)/__xscale + __top; break;
            
            default: __global.__throw("Invalid orientation \"", __orientation, "\""); return undefined; break;
        }
            
        return __point;
    }
    
    __canvas_to_gui_point = function(_x, _y)
    {
        switch (__orientation)
        {
            case display_landscape:         __point.x =  (__xscale*(_x - __left)) + __x; __point.y =  (__yscale*(_y - __top))  + __y; break;
            case display_landscape_flipped: __point.x = -(__xscale*(_x - __left)) + __x; __point.y = -(__yscale*(_y - __top))  + __y; break;
            case display_portrait:          __point.x =  (__yscale*(_y - __top))  + __x; __point.y = -(__xscale*(_x - __left)) + __y; break;
            case display_portrait_flipped:  __point.x = -(__yscale*(_y - __top))  + __x; __point.y =  (__xscale*(_x - __left)) + __y; break;
            
            default: __global.__throw("Invalid orientation \"", __orientation, "\""); return undefined; break;
        }
        
        return __point;
    }
    
    __draw_debug_overlay = function()
    {
        //Max border
        var _top_left = __canvas_to_gui_point(0, 0);
        var _x1 = _top_left.x;
        var _y1 = _top_left.y;
        var _bottom_right = __canvas_to_gui_point(__max_width, __max_height);
        var _x2 = _bottom_right.x;
        var _y2 = _bottom_right.y;
        var _w  = max(_x2, _x1) - min(_x2, _x1);
        var _h  = max(_y2, _y1) - min(_y2, _y1);
        var _x1 = min(_x2, _x1);
        var _y1 = min(_y2, _y1);        
        __draw_debug_rect(true, _x1 + 1, _y1 + 1, _w, _h, __debug_background_color, 1);
        __draw_debug_rect(true, _x1, _y1, _w, _h, __debug_text_color, 1);

        //Min border
        _top_left = __canvas_to_gui_point((__max_width -__min_width) div 2, (__max_height - __min_height) div 2);
        _x1 = _top_left.x;
        _y1 = _top_left.y;
        _bottom_right = __canvas_to_gui_point(__max_width - (__max_width - __min_width) div 2, __max_height - (__max_height - __min_height) div 2);
        _x2 = _bottom_right.x;
        _y2 = _bottom_right.y;
        _w  = max(_x2, _x1) - min(_x2, _x1);
        _h  = max(_y2, _y1) - min(_y2, _y1);
        _x1 = min(_x2, _x1);
        _y1 = min(_y2, _y1);
        __draw_debug_rect(true, _x1 + 1, _y1 + 1, _w, _h, __debug_background_color, 1);
        __draw_debug_rect(true, _x1, _y1, _w, _h, __debug_text_color, 1);
        
        //Readout
        var _orientation = "";
        switch (__orientation)
        {
            case display_landscape:         _orientation = "landscape         "; break;    
            case display_landscape_flipped: _orientation = "landscape flipped "; break;
            case display_portrait:          _orientation = "portrait          "; break;
            case display_portrait_flipped:  _orientation = "portrait flipped  "; break;
        }
        
        var _readout = " Angle     " + _orientation + "\n" +
                       " Mode      " + string(__mode) + "\n" +
                       " Scale     " + string(__xscale*100) + "%" + "\n" +
                       " Sampling  " + string(__sampling_type) + "\n" +
                       " Monitor   " + string(DisplayManager().__monitor_active + 1) + "/" + string(array_length(DisplayManager().__monitor_list));

        if ((__global.__window_width > string_width(_readout)) && (__global.__window_height > string_height(_readout)))
        {        
            var _font_previous        = draw_get_font();
            var _font_halign_previous = draw_get_halign();
            var _font_valign_previous = draw_get_valign();
            var _color_previous       = draw_get_color();
            
            //Container
            __draw_debug_rect(false, 1, 1, string_width(_readout) + 8, string_height(_readout) + 6, __debug_background_color, 0.66);
            __draw_debug_rect(true,  1, 1, string_width(_readout) + 8, string_height(_readout) + 6, __debug_text_color, 1);
            
            //Test
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(__debug_background_color);            
            if (__debug_text_font != undefined) draw_set_font(__debug_text_font);
            draw_text(6, 6, _readout);
            draw_set_color(__debug_text_color);
            draw_text(4, 4, _readout);
    
            draw_set_font(_font_previous);
            draw_set_halign(_font_halign_previous);
            draw_set_valign(_font_valign_previous);
            draw_set_color(_color_previous);
        }
    }
    
    #endregion
    
    #region Internal methods
    
    __room_creation = function()
    {
        if (!__configured)
        {
            //Validate canvas macros
            if (!is_numeric(CANVAS_APP_SURFACE_SIZE))        __global.__throw("Macro CANVAS_APP_SURFACE_SIZE is invalid: \"",        CANVAS_APP_SURFACE_SIZE,        "\". Number expected");
            if (!is_numeric(CANVAS_INITIAL_WIDTH))           __global.__throw("Macro CANVAS_INITIAL_WIDTH is invalid: \"",           CANVAS_INITIAL_WIDTH,           "\". Number expected");
            if (!is_numeric(CANVAS_INITIAL_HEIGHT))          __global.__throw("Macro CANVAS_INITIAL_HEIGHT is invalid: \"",          CANVAS_INITIAL_HEIGHT,          "\". Number expected");
            if (!is_numeric(CANVAS_SMOOTHING_THRESHOLD_MIN)) __global.__throw("Macro CANVAS_SMOOTHING_THRESHOLD_MIN is invalid: \"", CANVAS_SMOOTHING_THRESHOLD_MIN, "\". Number expected");
            if (!is_numeric(CANVAS_SMOOTHING_THRESHOLD_MAX)) __global.__throw("Macro CANVAS_SMOOTHING_THRESHOLD_MAX is invalid: \"", CANVAS_SMOOTHING_THRESHOLD_MAX, "\". Number expected");
            
            //Android texture limit
            var _info = os_get_info();
            if (!ds_exists(_info, ds_type_map)) _info = ds_map_create();
            var _max_supported_texture_size = _info[? "GL_MAX_TEXTURE_SIZE"];
            
            //Console display limits
            if (_max_supported_texture_size == undefined)
            {
                var _hd = 2048;
                var _4k = 4096;
                switch (os_type)
                {
                    case os_switch: _max_supported_texture_size = _hd; break;
                    case os_ps5:    _max_supported_texture_size = _4k; break;
                    case os_ps4:    _max_supported_texture_size = (_info[? "is_neo_mode"] == 1)? _4k : _hd; break;
            
                    case os_xboxone:
                        _max_supported_texture_size = _hd;
                        var _device_type = _info[? "device_type"];
                        if ((_device_type == device_gdk_xboxones)    || (_device_type == device_gdk_xboxonex)    || (_device_type == device_gdk_xboxonexdevkit) 
                        ||  (_device_type == device_gdk_xboxseriess) || (_device_type == device_gdk_xboxseriesx) || (_device_type == device_gdk_xboxseriesdevkit))
                        {
                            _max_supported_texture_size = _4k;
                        }
                    break;
            
                    default:
                        var _scale  = 0;
                        var _error  = undefined;
                        var _width  = surface_get_width(application_surface);
                        var _height = surface_get_height(application_surface);
                        while (_error == undefined)
                        {
                            _scale++;
                            try { surface_resize(application_surface, power(2, _scale), power(2, _scale)); }
                            catch (_error) { break; }
                            if (_scale > 14) __global.__throw("Texture scale exceeds ", power(2, _scale - 1));
                        }
                        _max_supported_texture_size = power(2, _scale - 1);
                    break;
                }
            }
    
            if (ds_exists(_info, ds_type_map)) ds_map_destroy(_info);
    
            //Set up application surface
            var _requested_size = power(2, ceil(log2(CANVAS_APP_SURFACE_SIZE))/1);
            var _texture_size = min(_max_supported_texture_size, _requested_size);
            if (_requested_size > _texture_size) __global.__log("Warning! Configured texture size ", _requested_size, " above maximum available size of ", _texture_size);
            surface_resize(application_surface, _texture_size, _texture_size);
            __global.__log("Application surface set to ", _texture_size);
    
            //Resize to support maximum display area
            room_set_height(room_next(room), _texture_size);
            room_set_width( room_next(room), _texture_size);
        
            //Resize window
            if ((os_type == os_windows) || (os_type == os_macosx)  || (os_type == os_linux))
            {
                window_set_size(CANVAS_INITIAL_WIDTH, CANVAS_INITIAL_HEIGHT);
                if (os_type == os_macosx) window_center();
            }
            else
            {
                window_set_size(display_get_width(), display_get_height());
            }

            __configured = true;
        }
        
        //Set up draw override
        application_surface_draw_enable(false);
        if (!instance_exists(ObjectDisplayManagerCanvas)) instance_create_depth(0, 0, 0, ObjectDisplayManagerCanvas);
        room_goto(room_next(room));
    }
    
    __create = function(){ if (instance_number(ObjectDisplayManagerCanvas) > 1) instance_destroy(); }
    
    __tick = function()
    {
        __orientation = __orientation_change;
        __mode        = __mode_change;
        __min_width   = __min_width_change;
        __min_height  = __min_height_change;    
        __max_width   = __max_width_change;
        __max_height  = __max_height_change;
        __width       = __max_width;
        __height      = __max_height;
        
        var _mode = __mode;
        var _scale = false;
        var _portrait = (__orientation == display_portrait) || (__orientation == display_portrait_flipped);
        var _orientation_window_width  = __global.__window_width;
        var _orientation_window_height = __global.__window_height;
        var _integer_scale = max(1, min(__global.__window_width div __min_width, __global.__window_height div __min_height));
        
        if (_portrait)
        {
            _orientation_window_width  = __global.__window_height;
            _orientation_window_height = __global.__window_width;
            _integer_scale = max(1, min(__global.__window_width div __min_height, __global.__window_height div __min_width));
        }

        //Downscale width
        __left = 0;
        if (_orientation_window_width < __min_width)
        {
            __left += (__width - __min_width) div 2;
            __width = __min_width;
            _mode = __CANVAS_MODE_FIT_SMOOTH;
            _scale = true;
        }

        //Upscale height
        __top = 0;
        if (_orientation_window_height < __min_height)
        {
            __top += (__height - __min_height) div 2;
            __height = __min_height;
            _mode = __CANVAS_MODE_FIT_SMOOTH;
            _scale = true;
        }

        //Fill scale
        if ((_mode == __CANVAS_MODE_FIT_SHARP) || (_mode == __CANVAS_MODE_FIT_SMOOTH))
        {
            if (_orientation_window_width/__width > _orientation_window_height/__height)
            {
                if (_orientation_window_height/_integer_scale > __height)
                {
                    _mode = __CANVAS_MODE_FIT_SMOOTH;
                    _scale = true;
                }
            }
            else if (_orientation_window_width/_integer_scale > __width)
            {
                _mode = __CANVAS_MODE_FIT_SMOOTH;
                _scale = true;
            }
        }

        //Set scale and rotation
        __xscale = _integer_scale;
        __yscale = _integer_scale;
        switch (__orientation) 
        {
            case display_landscape:
                __angle = 0;        
                __x = floor((__global.__window_width  - __width *__xscale)/2);
                __y = floor((__global.__window_height - __height*__yscale)/2);
                if (_scale)
                {
                    __x = 0;
                    __y = 0;
                    __xscale = __global.__window_width /__width;
                    __yscale = __global.__window_height/__height;
                    if (__xscale > __yscale)
                    {
                        __xscale = __yscale;
                        __x = floor((__global.__window_width - __width*__xscale)/2);
                    }
                    else
                    {
                        __yscale = __xscale;
                        __y = floor((__global.__window_height - __height*__yscale)/2);
                    }
                }
            break;
    
            case display_landscape_flipped:
                __angle = 180;        
                __x = floor(__global.__window_width /2 + __width *__xscale/2);
                __y = floor(__global.__window_height/2 + __height*__yscale/2);
                if (_scale)
                {
                    __xscale = __global.__window_width /__width;
                    __yscale = __global.__window_height/__height;
                    __x = __global.__window_width;
                    __y = __global.__window_height;
                    if (__xscale > __yscale)
                    {
                        __xscale = __yscale;
                        __x = __global.__window_width - floor((__global.__window_width - __width*__xscale)/2);
                    }
                    else
                    {
                        __yscale = __xscale;
                        __y = __global.__window_height - floor((__global.__window_height - __height*__yscale)/2);
                    }
                }
            break;
    
            case display_portrait:
                __angle = 90;
                __x = floor((__global.__window_width - __height*__yscale)/2);
                __y = floor( __global.__window_height/2 + __width*__xscale/2);
                if (_scale)
                {
                    __x = 0;
                    __y = __global.__window_height;
                    __xscale = __global.__window_height/__width;
                    __yscale = __global.__window_width /__height;
                    if (__xscale > __yscale)
                    {
                        __xscale = __yscale;
                        __y = __global.__window_height - floor((__global.__window_height - __width*__yscale)/2);
                    }
                    else
                    {
                        __yscale = __xscale;
                        __x = floor((__global.__window_width - __height*__xscale)/2);
                    }
                }
            break;
    
            case display_portrait_flipped:
                __angle = 270;        
                __x = floor(__global.__window_width/2 + __height*__yscale/2);
                __y = floor((__global.__window_height - __width*__xscale)/2);
                if (_scale)
                {
                    __x = __global.__window_width;
                    __y = 0;
                    __xscale = __global.__window_height/__width;
                    __yscale = __global.__window_width /__height;
                    if (__xscale > __yscale)
                    {
                        __xscale = __yscale;
                        __y = floor((__global.__window_height - __width*__yscale)/2);
                    }
                    else
                    {
                        __yscale = __xscale;
                        __x = __global.__window_width - floor((__global.__window_width - __height*__xscale)/2);
                    }
                }
            break;
            
            default: show_error("Display Manager: Invalid orientation value " + string(__orientation), true); break;
        }

        //Set sampling mode
        __sampling_type = __CANVAS_SAMPLING_POINT;
        
        if ((__xscale == 1.0) && (__yscale == 1.0 )) exit;

        var _minScale = min(__xscale, __yscale)
        if (_minScale >= 1.0)
        {
            //Upscale
            if (__mode == __CANVAS_MODE_FIT_SMOOTH)
            {
                __sampling_type = __CANVAS_SAMPLING_BILINEAR;
            }
            else if (frac(_minScale) != 0.0)
            {
                if ((_minScale < CANVAS_SMOOTHING_THRESHOLD_MIN) 
                ||  (_minScale > CANVAS_SMOOTHING_THRESHOLD_MAX))
                {
                    __sampling_type = __CANVAS_SAMPLING_POINT;
                }
                else if (_minScale < __CANVAS_SHIMMERLESS_THRESHOLD)
                {
                    __sampling_type = __CANVAS_SAMPLING_SHIMMERLESS;
                }
                else
                {
                    __sampling_type = __CANVAS_SAMPLING_SHARP;
                }
            }
        }
        else
        {
            //Downscale
            if (__mode == __CANVAS_MODE_FIT_SMOOTH)
            {    
                __sampling_type = __CANVAS_SAMPLING_BICUBIC;
            }
            else
            {                
                __sampling_type = __CANVAS_SAMPLING_BILINEAR;
            }
        }
    }
    
    __step = function()
    {
        if (!time_source_exists(__global.__timesource_handle) 
        || (time_source_get_state(__global.__timesource_handle) != time_source_state_active)) 
        {
            __global.__throw("Time source is misconfigured. Do not destroy or pause");
        }
    }
    
    __draw = function()
    {
        var _shader_set   = false;
        var _texture      = undefined;
        var _texfilter    = gpu_get_texfilter();
        var _blend_enable = gpu_get_blendenable();

        if (__fill_color != undefined) draw_clear(__fill_color);
        gpu_set_blendenable(false);

        switch (__sampling_type)
        {
            case __CANVAS_SAMPLING_POINT:    gpu_set_texfilter(false); break;
            case __CANVAS_SAMPLING_BILINEAR: gpu_set_texfilter(true);  break;
    
            case __CANVAS_SAMPLING_SHARP:
                _shader_set = true;
                gpu_set_texfilter(true);
                _texture = surface_get_texture(application_surface);
                shader_set(ShaderScaleSharpBilinear);
                shader_set_uniform_f(shader_get_uniform(ShaderScaleSharpBilinear, "u_vTexelSize"), texture_get_texel_width(_texture), texture_get_texel_height(_texture));
                shader_set_uniform_f(shader_get_uniform(ShaderScaleSharpBilinear, "u_vScale"), __xscale, __yscale);
            break;
    
            case __CANVAS_SAMPLING_SHIMMERLESS:
                _shader_set = true;
                gpu_set_texfilter(true);
                _texture = surface_get_texture(application_surface);
                shader_set(ShaderScaleSharpShimmerless);
                shader_set_uniform_f(shader_get_uniform(ShaderScaleSharpShimmerless, "u_vTexelSize"), texture_get_texel_width(_texture), texture_get_texel_height(_texture));
                shader_set_uniform_f(shader_get_uniform(ShaderScaleSharpShimmerless, "u_vScale"), __xscale, __yscale);
            break;

            case __CANVAS_SAMPLING_BICUBIC:
                _shader_set = true;
                gpu_set_texfilter(true);
                _texture = surface_get_texture(application_surface);
                shader_set(ShaderScaleBicubic);
                shader_set_uniform_f(shader_get_uniform(ShaderScaleBicubic, "u_vTexelSize"), texture_get_texel_width(_texture), texture_get_texel_height(_texture));
            break;
        }

        draw_surface_general(application_surface, __left, __top, __width, __height, __x, __y, __xscale, __yscale, __angle, __blend, __blend, __blend, __blend, 1);

        if (_shader_set) shader_reset();
        gpu_set_texfilter(_texfilter);
        gpu_set_blendenable(_blend_enable);
        
        if (__overlay_enabled) __draw_debug_overlay();
    }
    
    #endregion
    
})(); if (__check_object && !instance_exists(ObjectDisplayManagerCanvas)) DisplayManager().__throw("Missing \"ObjectDisplayManagerCanvas\" instance"); return __instance; };

#endregion

#region Public functions

function display_canvas_point_to_gui_x(_x, _y) { return CanvasManager().__canvas_to_gui_point(_x, _y).x; }
function display_canvas_point_to_gui_y(_x, _y) { return CanvasManager().__canvas_to_gui_point(_x, _y).y; }
function display_gui_point_to_canvas_x(_x, _y) { return CanvasManager().__gui_to_canvas_point(_x, _y).x; }
function display_gui_point_to_canvas_y(_x, _y) { return CanvasManager().__gui_to_canvas_point(_x, _y).y; }
function display_canvas_orientation_set(_orientation) { CanvasManager().__orientation_change = _orientation; }
function display_canvas_overlay_set(_enabled) { CanvasManager().__overlay_enabled = _enabled; }
function display_canvas_mode_set(_mode) { CanvasManager().__mode_change = _mode; }
function display_canvas_orientation() { return CanvasManager().__orientation_change; }
function display_canvas_overlay() { return CanvasManager().__overlay_enabled; }
function display_canvas_mode() { return CanvasManager().__mode_change; }
function display_canvas_width() { return CanvasManager().__width   }
function display_canvas_height() { return CanvasManager().__height; }
function display_canvas_scale() { return CanvasManager().__xscale; }
function display_canvas_x() { return CanvasManager().__x; }
function display_canvas_y() { return CanvasManager().__y; }

function display_canvas_size_set(_min_width, _min_height, _max_width = undefined, _max_height = undefined)
{
    CanvasManager().__min_width_change  = _min_width;
    CanvasManager().__min_height_change = _min_height;
    CanvasManager().__max_width_change  = _max_width  ?? _min_width;
    CanvasManager().__max_height_change = _max_height ?? _min_height;
}

#endregion
