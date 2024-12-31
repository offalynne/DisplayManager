// feather ignore all

// Config (edit these!)
#macro DISPLAY_AA_LEVEL 0  //AA level used when resetting display on Windows
#region Private constants

#macro __DISPLAY_SILENT  false
#macro __DISPLAY_DEPTH  -15998

#macro __DISPLAY_CONSOLE  ((os_type == os_switch)  || (os_type == os_xboxone) || (os_type == os_xboxseriesxs) || (os_type == os_ps4) || (os_type == os_ps5))
#macro __DISPLAY_DESKTOP  ((os_type == os_windows) || (os_type == os_macosx)  || (os_type == os_linux))
#macro __DISPLAY_MOBILE   ((os_type == os_android) || (os_type == os_tvos)    || (os_type == os_ios))

//Index identities for `window_get_visible_rects`
enum __DISPLAY_RECT
{
    __OVERLAP_X1 = 0,
    __OVERLAP_Y1 = 1,
    __OVERLAP_X2 = 2,
    __OVERLAP_Y2 = 3,
    __MONITOR_X1 = 4,
    __MONITOR_Y1 = 5,
    __MONITOR_X2 = 6,
    __MONITOR_Y2 = 7,
    __LENGTH     = 8
}

#endregion

#region Singleton

function DisplayManager() { static __instance = new (function() constructor 
{
    #region Setup    
    
    if ((os_browser != browser_not_a_browser) || (os_type == os_operagx)) __throw("Invalid platform. HTML5 and OperaGX are not supported");
    
    __max_unsinged = power(2, 32);
    __os_titlebar_height = ((os_type == os_windows)? 30 : 0);
    __titlebar_height = __os_titlebar_height;
    
    __display_width  = display_get_width();
    __display_height = display_get_height();
    
    __window_width   = window_get_width();
    __window_height  = window_get_height();
    __window_focus   = window_has_focus();
    __window_x       = 0;
    __window_y       = 0;
    
    __monitor_active = 0;
    __monitor_count  = 1;
    __monitor_list   = [];
    __rects          = [];
    
    __fullscreen     = false;
    __minimized      = false;
    __display_change = false;

    __recently_maximized  = false;
    __window_width_last   = __window_width;
    __window_height_last  = __window_height;
    __monitor_active_last = 0;
    __window_x_last       = undefined;
    __window_y_last       = undefined;
    __window_focus_last   = undefined;
    __fullscreen_last     = undefined;
    
    __deferred_handle   = undefined;
    __timesource_handle = undefined;
    
    #endregion
    
    #region Feature Detection
        
    __using_input_library = false;
    __using_showborder    = false;
    __using_borderless    = false;
    
    if (os_type == os_windows)
    {
        try { __using_input_library = !is_undefined(__INPUT_VERSION); }
        catch (_error) { __using_input_library = false; }
        
        try { __using_showborder = !is_undefined(window_get_showborder()); }
        catch (_error) { __using_showborder = false; }
        
        try { __using_borderless = !is_undefined(window_get_borderless_fullscreen()); }
        catch (_error) { __using_borderless = false; }        
    }
    
    #endregion    
    
    #region Utilities
    
    __log = function()
    {
        if (__DISPLAY_SILENT) return;    
        var _message = "";
        var _i = 0;
        repeat(argument_count)
        {
            _message += string(argument[_i]);
            ++_i;
        }
    
        show_debug_message("Display Manager: " + _message);
    }
    
    __throw = function()
    {
        var _message = "";
        var _i = 0;
        repeat(argument_count)
        {
            _message += string(argument[_i]);
            ++_i;
        }
    
        show_error("Display Manager: " + _message + "\n\n", true);
    }
    
    __handle_underflow = function(_i)
    {
        if (_i > __max_unsinged) return _i - __max_unsinged;
        return _i;
    }
    
    __fit_window = function(_monitor)
    {        
        //Invalid monitor
        if (__fullscreen || (_monitor == __monitor_active) || (_monitor < 0) || (_monitor >= array_length(__monitor_list))) return false;
                
        //Scall to fit smaller window
        if ((__window_width  > __monitor_list[_monitor].image_xscale) 
        ||  (__window_height > __monitor_list[_monitor].image_yscale - __titlebar_height))
        {
            var _scale = min(
                 __monitor_list[_monitor].image_xscale/__window_width,
                (__monitor_list[_monitor].image_yscale - __titlebar_height)/__window_height);
                
            window_set_size((__window_width*_scale) div 1, (__window_height*_scale) div 1);
        }
        
        return true;
    }
    
    __move_window = function(_monitor)
    {
        //Invalid monitor
        if (__fullscreen || (_monitor == __monitor_active) || (_monitor < 0) || (_monitor >= array_length(__monitor_list))) return false;
        
        window_set_position((__monitor_list[_monitor].x + __monitor_list[_monitor].image_xscale/2 - (__window_width /2)) div 1, 
                         max(__monitor_list[_monitor].y + __monitor_list[_monitor].image_yscale/2 - (__window_height/2), __titlebar_height) div 1);
        return true;
    }
    
    __block_input = function()
    {
        //Capture input to prevent thrashing
        if (DisplayManager().__using_input_library) input_clear(all);
        io_clear();
    }
    
    #endregion
    
    #region Classes
    
    __class_monitor = function(_x1, _y1, _x2, _y2) constructor
    {
        x = int64(_x1);
        y = int64(_y1);
        image_xscale = int64(_x2 - _x1);
        image_yscale = int64(_y2 - _y1);
    }
    
    __class_move_change = function(_monitor) constructor
    {
        __monitor = _monitor;
        __global  = DisplayManager();
        __abort   = false;
        __frame   = 0;
        
        static __tick = function()
        {
            __global.__block_input();
            
            switch (__frame)
            {
                case 0: __abort = !(__global.__fit_window(__monitor)); break;
                case 2: __abort = !(__global.__move_window(__monitor)); break;
                case 3: __abort = true; break;
            }
            
            if (__abort) __global.__deferred_handle = undefined;
            
            ++__frame;
        }
    }
    
    __class_fullscreen_change = function(_monitor) constructor
    {
        __monitor = _monitor;
        __frame   = 0;
        
        static __tick = function()
        {
            __global = DisplayManager();
            __global.__block_input();
            
            switch (__frame)
            {
                case  0: window_set_fullscreen(false); break;
                case 12: __global.__fit_window(__monitor); break;
                case 13: __global.__move_window(__monitor); break;
                case 15: window_set_fullscreen(true); break;
                case 26: __global.__deferred_handle = undefined; break;
            }
            
            ++__frame;
        }
    }
    
    #endregion
    
    #region Internal methods
           
    __monitor_list_update = function()
    {           
        if (os_type != os_windows)
        {
            array_resize(__monitor_list, 0);
            var _width  = __display_width;
            var _height = __display_height;
            if (!__DISPLAY_DESKTOP)
            {
                if ((__window_width != 0) && (__window_height != 0))
                {
                    _width  = __window_width;
                    _height = __window_height ;
                }
            }
            
            array_push(__monitor_list, new __class_monitor(0, 0, _width, _height));
           
            return false;
        }
        
        //Get and validate monitor data
        //NOTE: window_get_visible_rects works on Windows + Mac
        //This is *very* slow so we only recache when necessary
        //values are buggy but salvageable on Windows, on MacOS
        //values are inconsistent and non-salvagable so we pass   
        var _rects_last = __rects;        
        var _rects = window_get_visible_rects(__window_x, __window_y, __window_x + __window_width, __window_y + __window_height);
        if (array_length(_rects) != 0) __rects = _rects;
        
        //Count reported monitors
        __monitor_count  = array_length(__rects) div __DISPLAY_RECT.__LENGTH;
        
        //Build monitor attribute list
        var _display_change = false;
        if (!array_equals(__rects, _rects_last))
        {            
            //Monitor count change
            array_resize(__monitor_list, 0);  
            if (!is_array(_rects_last) || (array_length(__rects) != array_length(_rects_last)))
            {
                _display_change = true;
                if (_rects_last != undefined)
                {
                    if (__monitor_active > __monitor_count) __monitor_active = 0;
                    __monitor_count_changed = true;
                    __log("Monitor count changed to ", __monitor_count);
                }
            }
            
            //Find monitor changes
            var _x1 = 0;
            var _y1 = 0;
            var _x2 = 0;
            var _y2 = 0;
            var _overlap_x1   = 0;
            var _overlap_y1   = 0;
            var _overlap_x2   = 0;
            var _overlap_y2   = 0;
            var _overlap_area = 0;
            var _overlap_max  = 0;    
            
            var _monitor_index = 0;
            repeat (__monitor_count)
            {
                //Find display change
                _x1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X1];
                _y1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y1];
                _x2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X2]);
                _y2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y2]);                
                if (!_display_change)
                {
                    if ((_x1 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X1])
                    ||  (_y1 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y1])
                    ||  (_x2 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X2])
                    ||  (_y2 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y2]))
                    {
                        _display_change = true;
                    }
                }
                
                //Find monitor containing the window
                if (!__minimized)
                {
                    _overlap_x1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_X1];
                    _overlap_y1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_Y1];
                    _overlap_x2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_X2]);
                    _overlap_y2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_Y2]);
                    _overlap_area = (_overlap_x2 - _overlap_x1)*(_overlap_y2  - _overlap_y1);                
                    if ((_overlap_max < __window_width*__window_height) && (_overlap_area >= _overlap_max))
                    {
                        _overlap_max = _overlap_area;
                        __monitor_active = _monitor_index;
                    }
                }
                
                //Add monitor
                array_push(__monitor_list, new __class_monitor(_x1, _y1, _x2, _y2));
                
                ++_monitor_index;
            }
        }
        
        return _display_change;
    }
    
    __tick = function()
    {
        __display_width  = display_get_width();
        __display_height = display_get_height();
        
        if (!__DISPLAY_DESKTOP)        
        {
            __window_width  = __display_width;
            __window_height = __display_height;
        }
        else
        {
            //Find titlebar state
            __titlebar_height = __os_titlebar_height
            if (__using_showborder) if (!window_get_showborder()) __titlebar_height = 0;
            
            //Get window state
            __window_x      = window_get_x();
            __window_y      = window_get_y();
            __window_width  = window_get_width();
            __window_height = window_get_height();
            __window_focus  = window_has_focus();
            __fullscreen    = window_get_fullscreen();
            __minimized     = (((__window_x == -32000) && (__window_y == -32000)) || ((__window_width == 0) && (__window_height == 0)));
        }
        
        if (!__minimized)
        {
            //Resize resolution to match window
            if (__display_change || (((__window_width != __window_width_last) || (__window_height != __window_height_last)) && ((__window_width != 0) && (__window_height != 0))))
            {
                //Display resize can bug out rendering
                //moving the window seems to fix this
                if ((os_type == os_windows) && !__fullscreen)
                {
                    window_set_position(__window_x + 1, __window_y + 1);
                    window_set_position(__window_x - 1, __window_y - 1);
                    window_set_position(__window_x, __window_y);
                }
                
                //Match GUI scale to window
                display_set_gui_size(__window_width, __window_height);
                
                //Prevent display gore on window resize
                if (os_type == os_windows) display_reset(min(DISPLAY_AA_LEVEL, display_aa), true);
                
                __display_change = false;
            }
        }
            
        //Perform and evaluate resize outcomes
        if (__deferred_handle != undefined)
        {
            //Do resize
            __deferred_handle.__tick();
        }
        else if (!__fullscreen && !__minimized)
        {
            if (__fullscreen_last)
            {
                //Restored
                __recently_maximized = false;
            }
            else if ((__window_width != __window_width_last) && (__window_height != __window_height_last))
            {            
                //Capture window changes
                var _resize_sign = sign((__window_width*__window_height) - (__window_width_last*__window_height_last));
                if ((__monitor_list[__monitor_active].image_xscale - __window_width  <= 64) 
                &&  (__monitor_list[__monitor_active].image_yscale - __window_height <= 64))
                {
                    //Maximized
                    if (_resize_sign == 1) __recently_maximized = true;
                }
                else if (_resize_sign == -1)
                {
                    //Restored
                    __recently_maximized = false;
                }
            }
        }
        
        with (ObjectDisplayManagerCanvas) CanvasManager().__tick();
        
        if (!__minimized)
        {
            if ((__window_width_last  != __window_width)
            ||  (__window_height_last != __window_height)
            ||  (__window_x_last      != __window_x)
            ||  (__window_y_last      != __window_y)
            ||  (__window_focus_last  != __window_focus)
            ||  (__fullscreen_last    != __fullscreen))
            {                
                //Rebuild monitor list
                __display_change = __monitor_list_update();
                
                //Handle bugged out Windows runner fullscreen monitor change behavior
                if ((os_type == os_windows) && __fullscreen && (__monitor_active != __monitor_active_last) && (__deferred_handle == undefined)) 
                {
                    __deferred_handle = new __class_fullscreen_change(__monitor_active);
                }
            
                __monitor_active_last = __monitor_active;                
                __window_width_last   = __window_width;
                __window_height_last  = __window_height;
                __window_x_last       = __window_x;
                __window_y_last       = __window_y;
                __window_focus_last   = __window_focus;
                __fullscreen_last     = __fullscreen;
            }
        }
    }
    
    __monitor_set_error = function(_monitor)
    {
        if (os_type != os_windows)
        {
            return "Monitor change refused, window is already in active display";
        }
        else 
        {
            __monitor_list_update();
            
            if (_monitor == __monitor_active)
            {
                return "Monitor change refused, window is already in active monitor";
            }
            else if (__deferred_handle != undefined)
            {
                return "Monitor change refused, deferred change in progress";
            }
            else if ((_monitor < 0) || (_monitor >= array_length(__monitor_list)))
            {
                return "Monitor change refused, invalid monitor index " + _monitor;
            }
            else
            {
                if (!__fullscreen)
                {
                    if (__recently_maximized) return "Monitor change refused, window is maximized";
                }
                else if (__using_borderless && window_get_borderless_fullscreen())
                {
                    return "Monitor change refused, unsupported in borderless fullscreen";
                }   
            }
        }
        
        return undefined;
    }
    
    __monitor_set = function(_monitor)
    {
        var _error = __monitor_set_error(_monitor);
        if (is_undefined(_error))
        {
           __log("Moving from monitor index ", __monitor_active, " to ", _monitor);
           __deferred_handle = (__fullscreen? new __class_fullscreen_change(_monitor) : new __class_move_change(_monitor));
        }
        else
        {
            __log(_error);
        }
    }
    
    #endregion
    
    #region Initialize 
    
    __monitor_list_update();
    __timesource_handle = time_source_create(time_source_game, time_source_units_frames, 1, __tick, [], -1);
    time_source_start(__timesource_handle);
    if (display_aa < DISPLAY_AA_LEVEL) __log("Warning! Configured DISPLAY_AA_LEVEL ", DISPLAY_AA_LEVEL, " exceeds maximum available value ", display_aa);
    // feather ignore all

// Config (edit these!)
#macro DISPLAY_AA_LEVEL 0  //AA level used when resetting display on Windows

#region Private constants

#macro __DISPLAY_SILENT  false
#macro __DISPLAY_DEPTH  -15998

#macro __DISPLAY_CONSOLE  ((os_type == os_switch)  || (os_type == os_xboxone) || (os_type == os_xboxseriesxs) || (os_type == os_ps4) || (os_type == os_ps5))
#macro __DISPLAY_DESKTOP  ((os_type == os_windows) || (os_type == os_macosx)  || (os_type == os_linux))
#macro __DISPLAY_MOBILE   ((os_type == os_android) || (os_type == os_tvos)    || (os_type == os_ios))

//Index identities for `window_get_visible_rects`
enum __DISPLAY_RECT
{
    __OVERLAP_X1 = 0,
    __OVERLAP_Y1 = 1,
    __OVERLAP_X2 = 2,
    __OVERLAP_Y2 = 3,
    __MONITOR_X1 = 4,
    __MONITOR_Y1 = 5,
    __MONITOR_X2 = 6,
    __MONITOR_Y2 = 7,
    __LENGTH     = 8
}

#macro __DISPLAY_SHIMMERLESS_THRESHOLD  2.0

#endregion

#region Singleton

function DisplayManager() { static __instance = new (function() constructor 
{
    #region Setup    
    
    if ((os_browser != browser_not_a_browser) || (os_type == os_operagx)) __throw("Invalid platform. HTML5 and OperaGX are not supported");
    
    __max_unsinged = power(2, 32);
    __os_titlebar_height = ((os_type == os_windows)? 30 : 0);
    __titlebar_height = __os_titlebar_height;
    
    __display_width  = display_get_width();
    __display_height = display_get_height();
    
    __window_width   = window_get_width();
    __window_height  = window_get_height();
    __window_focus   = window_has_focus();
    __window_x       = 0;
    __window_y       = 0;
    
    __monitor_active = 0;
    __monitor_count  = 1;
    __monitor_list   = [];
    __rects          = [];
    
    __fullscreen     = false;
    __minimized      = false;
    __display_change = false;

    __recently_maximized  = false;
    __window_width_last   = __window_width;
    __window_height_last  = __window_height;
    __monitor_active_last = 0;
    __window_x_last       = undefined;
    __window_y_last       = undefined;
    __window_focus_last   = undefined;
    __fullscreen_last     = undefined;
    
    __deferred_handle   = undefined;
    __timesource_handle = undefined;
    
    #endregion
    
    #region Feature Detection
        
    __using_input_library = false;
    __using_showborder    = false;
    __using_borderless    = false;
    
    if (os_type == os_windows)
    {
        try { __using_input_library = !is_undefined(__INPUT_VERSION); }
        catch (_error) { __using_input_library = false; }
        
        try { __using_showborder = !is_undefined(window_get_showborder()); }
        catch (_error) { __using_showborder = false; }
        
        try { __using_borderless = !is_undefined(window_get_borderless_fullscreen()); }
        catch (_error) { __using_borderless = false; }        
    }
    
    #endregion    
    
    #region Utilities
    
    __log = function()
    {
        if (__DISPLAY_SILENT) return;    
        var _message = "";
        var _i = 0;
        repeat(argument_count)
        {
            _message += string(argument[_i]);
            ++_i;
        }
    
        show_debug_message("Display Manager: " + _message);
    }
    
    __throw = function()
    {
        var _message = "";
        var _i = 0;
        repeat(argument_count)
        {
            _message += string(argument[_i]);
            ++_i;
        }
    
        show_error("Display Manager: " + _message + "\n\n", true);
    }
    
    __handle_underflow = function(_i)
    {
        if (_i > __max_unsinged) return _i - __max_unsinged;
        return _i;
    }
    
    __fit_window = function(_monitor)
    {        
        //Invalid monitor
        if (__fullscreen || (_monitor == __monitor_active) || (_monitor < 0) || (_monitor >= array_length(__monitor_list))) return false;
                
        //Scall to fit smaller window
        if ((__window_width  > __monitor_list[_monitor].image_xscale) 
        ||  (__window_height > __monitor_list[_monitor].image_yscale - __titlebar_height))
        {
            var _scale = min(
                 __monitor_list[_monitor].image_xscale/__window_width,
                (__monitor_list[_monitor].image_yscale - __titlebar_height)/__window_height);
                
            window_set_size((__window_width*_scale) div 1, (__window_height*_scale) div 1);
        }
        
        return true;
    }
    
    __move_window = function(_monitor)
    {
        //Invalid monitor
        if (__fullscreen || (_monitor == __monitor_active) || (_monitor < 0) || (_monitor >= array_length(__monitor_list))) return false;
        
        window_set_position((__monitor_list[_monitor].x + __monitor_list[_monitor].image_xscale/2 - (__window_width /2)) div 1, 
                         max(__monitor_list[_monitor].y + __monitor_list[_monitor].image_yscale/2 - (__window_height/2), __titlebar_height) div 1);
        return true;
    }
    
    __block_input = function()
    {
        //Capture input to prevent thrashing
        if (DisplayManager().__using_input_library) input_clear(all);
        io_clear();
    }
    
    #endregion
    
    #region Classes
    
    __class_monitor = function(_x1, _y1, _x2, _y2) constructor
    {
        x = int64(_x1);
        y = int64(_y1);
        image_xscale = int64(_x2 - _x1);
        image_yscale = int64(_y2 - _y1);
    }
    
    __class_move_change = function(_monitor) constructor
    {
        __monitor = _monitor;
        __global  = DisplayManager();
        __abort   = false;
        __frame   = 0;
        
        static __tick = function()
        {
            __global.__block_input();
            
            switch (__frame)
            {
                case 0: __abort = !(__global.__fit_window(__monitor)); break;
                case 2: __abort = !(__global.__move_window(__monitor)); break;
                case 3: __abort = true; break;
            }
            
            if (__abort) __global.__deferred_handle = undefined;
            
            ++__frame;
        }
    }
    
    __class_fullscreen_change = function(_monitor) constructor
    {
        __monitor = _monitor;
        __frame   = 0;
        
        static __tick = function()
        {
            __global = DisplayManager();
            __global.__block_input();
            
            switch (__frame)
            {
                case  0: window_set_fullscreen(false); break;
                case 12: __global.__fit_window(__monitor); break;
                case 13: __global.__move_window(__monitor); break;
                case 15: window_set_fullscreen(true); break;
                case 26: __global.__deferred_handle = undefined; break;
            }
            
            ++__frame;
        }
    }
    
    #endregion
    
    #region Internal methods
           
    __monitor_list_update = function()
    {           
        if (os_type != os_windows)
        {
            array_resize(__monitor_list, 0);
            var _width  = __display_width;
            var _height = __display_height;
            if (!__DISPLAY_DESKTOP)
            {
                if ((__window_width != 0) && (__window_height != 0))
                {
                    _width  = __window_width;
                    _height = __window_height ;
                }
            }
            
            array_push(__monitor_list, new __class_monitor(0, 0, _width, _height));
           
            return false;
        }
        
        //Get and validate monitor data
        //NOTE: window_get_visible_rects works on Windows + Mac
        //This is *very* slow so we only recache when necessary
        //values are buggy but salvageable on Windows, on MacOS
        //values are inconsistent and non-salvagable so we pass   
        var _rects_last = __rects;        
        var _rects = window_get_visible_rects(__window_x, __window_y, __window_x + __window_width, __window_y + __window_height);
        if (array_length(_rects) != 0) __rects = _rects;
        
        //Count reported monitors
        __monitor_count  = array_length(__rects) div __DISPLAY_RECT.__LENGTH;
        
        //Build monitor attribute list
        var _display_change = false;
        if (!array_equals(__rects, _rects_last))
        {            
            //Monitor count change
            array_resize(__monitor_list, 0);  
            if (!is_array(_rects_last) || (array_length(__rects) != array_length(_rects_last)))
            {
                _display_change = true;
                if (_rects_last != undefined)
                {
                    if (__monitor_active > __monitor_count) __monitor_active = 0;
                    __monitor_count_changed = true;
                    __log("Monitor count changed to ", __monitor_count);
                }
            }
            
            //Find monitor changes
            var _x1 = 0;
            var _y1 = 0;
            var _x2 = 0;
            var _y2 = 0;
            var _overlap_x1   = 0;
            var _overlap_y1   = 0;
            var _overlap_x2   = 0;
            var _overlap_y2   = 0;
            var _overlap_area = 0;
            var _overlap_max  = 0;    
            
            var _monitor_index = 0;
            repeat (__monitor_count)
            {
                //Find display change
                _x1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X1];
                _y1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y1];
                _x2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X2]);
                _y2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y2]);                
                if (!_display_change)
                {
                    if ((_x1 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X1])
                    ||  (_y1 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y1])
                    ||  (_x2 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X2])
                    ||  (_y2 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y2]))
                    {
                        _display_change = true;
                    }
                }
                
                //Find monitor containing the window
                if (!__minimized)
                {
                    _overlap_x1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_X1];
                    _overlap_y1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_Y1];
                    _overlap_x2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_X2]);
                    _overlap_y2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_Y2]);
                    _overlap_area = (_overlap_x2 - _overlap_x1)*(_overlap_y2  - _overlap_y1);                
                    if ((_overlap_max < __window_width*__window_height) && (_overlap_area >= _overlap_max))
                    {
                        _overlap_max = _overlap_area;
                        __monitor_active = _monitor_index;
                    }
                }
                
                //Add monitor
                array_push(__monitor_list, new __class_monitor(_x1, _y1, _x2, _y2));
                
                ++_monitor_index;
            }
        }
        
        return _display_change;
    }
    
    __tick = function()
    {
        __display_width  = display_get_width();
        __display_height = display_get_height();
        
        if (!__DISPLAY_DESKTOP)        
        {
            __window_width  = __display_width;
            __window_height = __display_height;
        }
        else
        {
            //Find titlebar state
            __titlebar_height = __os_titlebar_height
            if (__using_showborder) if (!window_get_showborder()) __titlebar_height = 0;
            
            //Get window state
            __window_x      = window_get_x();
            __window_y      = window_get_y();
            __window_width  = window_get_width();
            __window_height = window_get_height();
            __window_focus  = window_has_focus();
            __fullscreen    = window_get_fullscreen();
            __minimized     = (((__window_x == -32000) && (__window_y == -32000)) || ((__window_width == 0) && (__window_height == 0)));
        }
        
        if (!__minimized)
        {
            //Resize resolution to match window
            if (__display_change || (((__window_width != __window_width_last) || (__window_height != __window_height_last)) && ((__window_width != 0) && (__window_height != 0))))
            {
                //Display resize can bug out rendering
                //moving the window seems to fix this
                if ((os_type == os_windows) && !__fullscreen)
                {
                    window_set_position(__window_x + 1, __window_y + 1);
                    window_set_position(__window_x - 1, __window_y - 1);
                    window_set_position(__window_x, __window_y);
                }
                
                //Match GUI scale to window
                display_set_gui_size(__window_width, __window_height);
                
                //Prevent display gore on window resize
                if (os_type == os_windows) display_reset(min(DISPLAY_AA_LEVEL, display_aa), true);
                
                __display_change = false;
            }
        }
            
        //Perform and evaluate resize outcomes
        if (__deferred_handle != undefined)
        {
            //Do resize
            __deferred_handle.__tick();
        }
        else if (!__fullscreen && !__minimized)
        {
            if (__fullscreen_last)
            {
                //Restored
                __recently_maximized = false;
            }
            else if ((__window_width != __window_width_last) && (__window_height != __window_height_last))
            {            
                //Capture window changes
                var _resize_sign = sign((__window_width*__window_height) - (__window_width_last*__window_height_last));
                if ((__monitor_list[__monitor_active].image_xscale - __window_width  <= 64) 
                &&  (__monitor_list[__monitor_active].image_yscale - __window_height <= 64))
                {
                    //Maximized
                    if (_resize_sign == 1) __recently_maximized = true;
                }
                else if (_resize_sign == -1)
                {
                    //Restored
                    __recently_maximized = false;
                }
            }
        }
        
        with (ObjectDisplayManagerCanvas) CanvasManager().__tick();
        
        if (!__minimized)
        {
            if ((__window_width_last  != __window_width)
            ||  (__window_height_last != __window_height)
            ||  (__window_x_last      != __window_x)
            ||  (__window_y_last      != __window_y)
            ||  (__window_focus_last  != __window_focus)
            ||  (__fullscreen_last    != __fullscreen))
            {                
                //Rebuild monitor list
                __display_change = __monitor_list_update();
                
                //Handle bugged out Windows runner fullscreen monitor change behavior
                if ((os_type == os_windows) && __fullscreen && (__monitor_active != __monitor_active_last) && (__deferred_handle == undefined)) 
                {
                    __deferred_handle = new __class_fullscreen_change(__monitor_active);
                }
            
                __monitor_active_last = __monitor_active;                
                __window_width_last   = __window_width;
                __window_height_last  = __window_height;
                __window_x_last       = __window_x;
                __window_y_last       = __window_y;
                __window_focus_last   = __window_focus;
                __fullscreen_last     = __fullscreen;
            }
        }
    }
    
    __monitor_set_error = function(_monitor)
    {
        if (os_type != os_windows)
        {
            return "Monitor change refused, window is already in active display";
        }
        else 
        {
            __monitor_list_update();
            
            if (_monitor == __monitor_active)
            {
                return "Monitor change refused, window is already in active monitor";
            }
            else if (__deferred_handle != undefined)
            {
                return "Monitor change refused, deferred change in progress";
            }
            else if ((_monitor < 0) || (_monitor >= array_length(__monitor_list)))
            {
                return "Monitor change refused, invalid monitor index " + _monitor;
            }
            else
            {
                if (!__fullscreen)
                {
                    if (__recently_maximized) return "Monitor change refused, window is maximized";
                }
                else if (__using_borderless && window_get_borderless_fullscreen())
                {
                    return "Monitor change refused, unsupported in borderless fullscreen";
                }   
            }
        }
        
        return undefined;
    }
    
    __monitor_set = function(_monitor)
    {
        var _error = __monitor_set_error(_monitor);
        if (is_undefined(_error))
        {
           __log("Moving from monitor index ", __monitor_active, " to ", _monitor);
           __deferred_handle = (__fullscreen? new __class_fullscreen_change(_monitor) : new __class_move_change(_monitor));
        }
        else
        {
            __log(_error);
        }
    }
    
    #endregion
    
    #region Initialize 
    
    __monitor_list_update();
    __timesource_handle = time_source_create(time_source_game, time_source_units_frames, 1, __tick, [], -1);
    time_source_start(__timesource_handle);
    if (display_aa < DISPLAY_AA_LEVEL) __log("Warning! Configured DISPLAY_AA_LEVEL ", DISPLAY_AA_LEVEL, " exceeds maximum available value ", display_aa);
    
    #endregion
    
})(); return __instance; };

#endregion

#region Public functions

function display_monitor_set(_monitor) { DisplayManager().__monitor_set(_monitor); }
function display_monitor_set_allowed(_monitor) { return is_undefined(DisplayManager().__monitor_set_error()); }
function display_monitor_active() { return DisplayManager().__monitor_active; }
function display_monitor_list() { return DisplayManager().__monitor_list; }
function display_time_source() { return DisplayManager().__timesource_handle; }

#endregion
    #endregion
    
})(); return __instance; };

#endregion

#region Public functions

function display_monitor_set(_monitor) { DisplayManager().__monitor_set(_monitor); }
function display_monitor_set_allowed(_monitor) { return is_undefined(DisplayManager().__monitor_set_error()); }
function display_monitor_active() { return DisplayManager().__monitor_active; }
function display_monitor_list() { return DisplayManager().__monitor_list; }
function display_time_source() { return DisplayManager().__timesource_handle; }

#endregion

#macro __DISPLAY_SILENT  false
#macro __DISPLAY_DEPTH  -15998

#macro __DISPLAY_CONSOLE  ((os_type == os_switch)  || (os_type == os_xboxone) || (os_type == os_xboxseriesxs) || (os_type == os_ps4) || (os_type == os_ps5))
#macro __DISPLAY_DESKTOP  ((os_type == os_windows) || (os_type == os_macosx)  || (os_type == os_linux))
#macro __DISPLAY_MOBILE   ((os_type == os_android) || (os_type == os_tvos)    || (os_type == os_ios))

#macro __DISPLAY_SAMPLING_SHIMMERLESS  "shimmerless"
#macro __DISPLAY_SAMPLING_BILINEAR     "bilinear"
#macro __DISPLAY_SAMPLING_BICUBIC      "bicubic"
#macro __DISPLAY_SAMPLING_SHARP        "sharp"
#macro __DISPLAY_SAMPLING_POINT        "point"

//Index identities for `window_get_visible_rects`
enum __DISPLAY_RECT
{
    __OVERLAP_X1 = 0,
    __OVERLAP_Y1 = 1,
    __OVERLAP_X2 = 2,
    __OVERLAP_Y2 = 3,
    __MONITOR_X1 = 4,
    __MONITOR_Y1 = 5,
    __MONITOR_X2 = 6,
    __MONITOR_Y2 = 7,
    __LENGTH     = 8
}

#macro __DISPLAY_SHIMMERLESS_THRESHOLD  2.0

#endregion

#region Singleton

function DisplayManager() { static __instance = new (function() constructor 
{
    #region Setup    
    
    if ((os_browser != browser_not_a_browser) || (os_type == os_operagx)) __throw("Invalid platform. HTML5 and OperaGX are not supported");
    
    __max_unsinged = power(2, 32);
    __os_titlebar_height = ((os_type == os_windows)? 30 : 0);
    __titlebar_height = __os_titlebar_height;
    
    __display_width  = display_get_width();
    __display_height = display_get_height();
    
    __window_width   = window_get_width();
    __window_height  = window_get_height();
    __window_focus   = window_has_focus();
    __window_x       = 0;
    __window_y       = 0;
    
    __monitor_active = 0;
    __monitor_count  = 1;
    __monitor_list   = [];
    __rects          = [];
    
    __fullscreen     = false;
    __minimized      = false;
    __display_change = false;

    __recently_maximized  = false;
    __window_width_last   = __window_width;
    __window_height_last  = __window_height;
    __monitor_active_last = 0;
    __window_x_last       = undefined;
    __window_y_last       = undefined;
    __window_focus_last   = undefined;
    __fullscreen_last     = undefined;
    
    __deferred_handle   = undefined;
    __timesource_handle = undefined;
    
    #endregion
    
    #region Feature Detection
        
    __using_input_library = false;
    __using_showborder    = false;
    __using_borderless    = false;
    
    if (os_type == os_windows)
    {
        try { __using_input_library = !is_undefined(__INPUT_VERSION); }
        catch (_error) { __using_input_library = false; }
        
        try { __using_showborder = !is_undefined(window_get_showborder()); }
        catch (_error) { __using_showborder = false; }
        
        try { __using_borderless = !is_undefined(window_get_borderless_fullscreen()); }
        catch (_error) { __using_borderless = false; }        
    }
    
    #endregion    
    
    #region Utilities
    
    __log = function()
    {
        if (__DISPLAY_SILENT) return;    
        var _message = "";
        var _i = 0;
        repeat(argument_count)
        {
            _message += string(argument[_i]);
            ++_i;
        }
    
        show_debug_message("Display Manager: " + _message);
    }
    
    __throw = function()
    {
        var _message = "";
        var _i = 0;
        repeat(argument_count)
        {
            _message += string(argument[_i]);
            ++_i;
        }
    
        show_error("Display Manager: " + _message + "\n\n", true);
    }
    
    __handle_underflow = function(_i)
    {
        if (_i > __max_unsinged) return _i - __max_unsinged;
        return _i;
    }
    
    __fit_window = function(_monitor)
    {        
        //Invalid monitor
        if (__fullscreen || (_monitor == __monitor_active) || (_monitor < 0) || (_monitor >= array_length(__monitor_list))) return false;
                
        //Scall to fit smaller window
        if ((__window_width  > __monitor_list[_monitor].image_xscale) 
        ||  (__window_height > __monitor_list[_monitor].image_yscale - __titlebar_height))
        {
            var _scale = min(
                 __monitor_list[_monitor].image_xscale/__window_width,
                (__monitor_list[_monitor].image_yscale - __titlebar_height)/__window_height);
                
            window_set_size((__window_width*_scale) div 1, (__window_height*_scale) div 1);
        }
        
        return true;
    }
    
    __move_window = function(_monitor)
    {
        //Invalid monitor
        if (__fullscreen || (_monitor == __monitor_active) || (_monitor < 0) || (_monitor >= array_length(__monitor_list))) return false;
        
        window_set_position((__monitor_list[_monitor].x + __monitor_list[_monitor].image_xscale/2 - (__window_width /2)) div 1, 
                         max(__monitor_list[_monitor].y + __monitor_list[_monitor].image_yscale/2 - (__window_height/2), __titlebar_height) div 1);
        return true;
    }
    
    __block_input = function()
    {
        //Capture input to prevent thrashing
        if (DisplayManager().__using_input_library) input_clear(all);
        io_clear();
    }
    
    #endregion
    
    #region Classes
    
    __class_monitor = function(_x1, _y1, _x2, _y2) constructor
    {
        x = int64(_x1);
        y = int64(_y1);
        image_xscale = int64(_x2 - _x1);
        image_yscale = int64(_y2 - _y1);
    }
    
    __class_move_change = function(_monitor) constructor
    {
        __monitor = _monitor;
        __global  = DisplayManager();
        __abort   = false;
        __frame   = 0;
        
        static __tick = function()
        {
            __global.__block_input();
            
            switch (__frame)
            {
                case 0: __abort = !(__global.__fit_window(__monitor)); break;
                case 2: __abort = !(__global.__move_window(__monitor)); break;
                case 3: __abort = true; break;
            }
            
            if (__abort) __global.__deferred_handle = undefined;
            
            ++__frame;
        }
    }
    
    __class_fullscreen_change = function(_monitor) constructor
    {
        __monitor = _monitor;
        __frame   = 0;
        
        static __tick = function()
        {
            __global = DisplayManager();
            __global.__block_input();
            
            switch (__frame)
            {
                case  0: window_set_fullscreen(false); break;
                case 12: __global.__fit_window(__monitor); break;
                case 13: __global.__move_window(__monitor); break;
                case 15: window_set_fullscreen(true); break;
                case 26: __global.__deferred_handle = undefined; break;
            }
            
            ++__frame;
        }
    }
    
    #endregion
    
    #region Internal methods
           
    __monitor_list_update = function()
    {           
        if (os_type != os_windows)
        {
            array_resize(__monitor_list, 0);
            var _width  = __display_width;
            var _height = __display_height;
            if (!__DISPLAY_DESKTOP)
            {
                if ((__window_width != 0) && (__window_height != 0))
                {
                    _width  = __window_width;
                    _height = __window_height ;
                }
            }
            
            array_push(__monitor_list, new __class_monitor(0, 0, _width, _height));
           
            return false;
        }
        
        //Get and validate monitor data
        //NOTE: window_get_visible_rects works on Windows + Mac
        //This is *very* slow so we only recache when necessary
        //values are buggy but salvageable on Windows, on MacOS
        //values are inconsistent and non-salvagable so we pass   
        var _rects_last = __rects;        
        var _rects = window_get_visible_rects(__window_x, __window_y, __window_x + __window_width, __window_y + __window_height);
        if (array_length(_rects) != 0) __rects = _rects;
        
        //Count reported monitors
        __monitor_count  = array_length(__rects) div __DISPLAY_RECT.__LENGTH;
        
        //Build monitor attribute list
        var _display_change = false;
        if (!array_equals(__rects, _rects_last))
        {            
            //Monitor count change
            array_resize(__monitor_list, 0);  
            if (!is_array(_rects_last) || (array_length(__rects) != array_length(_rects_last)))
            {
                _display_change = true;
                if (_rects_last != undefined)
                {
                    if (__monitor_active > __monitor_count) __monitor_active = 0;
                    __monitor_count_changed = true;
                    __log("Monitor count changed to ", __monitor_count);
                }
            }
            
            //Find monitor changes
            var _x1 = 0;
            var _y1 = 0;
            var _x2 = 0;
            var _y2 = 0;
            var _overlap_x1   = 0;
            var _overlap_y1   = 0;
            var _overlap_x2   = 0;
            var _overlap_y2   = 0;
            var _overlap_area = 0;
            var _overlap_max  = 0;    
            
            var _monitor_index = 0;
            repeat (__monitor_count)
            {
                //Find display change
                _x1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X1];
                _y1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y1];
                _x2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X2]);
                _y2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y2]);                
                if (!_display_change)
                {
                    if ((_x1 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X1])
                    ||  (_y1 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y1])
                    ||  (_x2 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_X2])
                    ||  (_y2 != _rects_last[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__MONITOR_Y2]))
                    {
                        _display_change = true;
                    }
                }
                
                //Find monitor containing the window
                if (!__minimized)
                {
                    _overlap_x1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_X1];
                    _overlap_y1 = __rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_Y1];
                    _overlap_x2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_X2]);
                    _overlap_y2 = __handle_underflow(__rects[_monitor_index*__DISPLAY_RECT.__LENGTH + __DISPLAY_RECT.__OVERLAP_Y2]);
                    _overlap_area = (_overlap_x2 - _overlap_x1)*(_overlap_y2  - _overlap_y1);                
                    if ((_overlap_max < __window_width*__window_height) && (_overlap_area >= _overlap_max))
                    {
                        _overlap_max = _overlap_area;
                        __monitor_active = _monitor_index;
                    }
                }
                
                //Add monitor
                array_push(__monitor_list, new __class_monitor(_x1, _y1, _x2, _y2));
                
                ++_monitor_index;
            }
        }
        
        return _display_change;
    }
    
    __tick = function()
    {
        __display_width  = display_get_width();
        __display_height = display_get_height();
        
        if (!__DISPLAY_DESKTOP)        
        {
            __window_width  = __display_width;
            __window_height = __display_height;
        }
        else
        {
            //Find titlebar state
            __titlebar_height = __os_titlebar_height
            if (__using_showborder) if (!window_get_showborder()) __titlebar_height = 0;
            
            //Get window state
            __window_x      = window_get_x();
            __window_y      = window_get_y();
            __window_width  = window_get_width();
            __window_height = window_get_height();
            __window_focus  = window_has_focus();
            __fullscreen    = window_get_fullscreen();
            __minimized     = (((__window_x == -32000) && (__window_y == -32000)) || ((__window_width == 0) && (__window_height == 0)));
        }
        
        if (!__minimized)
        {
            //Resize resolution to match window
            if (__display_change || (((__window_width != __window_width_last) || (__window_height != __window_height_last)) && ((__window_width != 0) && (__window_height != 0))))
            {
                //Display resize can bug out rendering
                //moving the window seems to fix this
                if ((os_type == os_windows) && !__fullscreen)
                {
                    window_set_position(__window_x + 1, __window_y + 1);
                    window_set_position(__window_x - 1, __window_y - 1);
                    window_set_position(__window_x, __window_y);
                }
                
                //Match GUI scale to window
                display_set_gui_size(__window_width, __window_height);
                
                //Prevent display gore on window resize
                if (os_type == os_windows) display_reset(min(DISPLAY_AA_LEVEL, display_aa), true);
                
                __display_change = false;
            }
        }
            
        //Perform and evaluate resize outcomes
        if (__deferred_handle != undefined)
        {
            //Do resize
            __deferred_handle.__tick();
        }
        else if (!__fullscreen && !__minimized)
        {
            if (__fullscreen_last)
            {
                //Restored
                __recently_maximized = false;
            }
            else if ((__window_width != __window_width_last) && (__window_height != __window_height_last))
            {            
                //Capture window changes
                var _resize_sign = sign((__window_width*__window_height) - (__window_width_last*__window_height_last));
                if ((__monitor_list[__monitor_active].image_xscale - __window_width  <= 64) 
                &&  (__monitor_list[__monitor_active].image_yscale - __window_height <= 64))
                {
                    //Maximized
                    if (_resize_sign == 1) __recently_maximized = true;
                }
                else if (_resize_sign == -1)
                {
                    //Restored
                    __recently_maximized = false;
                }
            }
        }
        
        with (ObjectDisplayManagerCanvas) CanvasManager().__tick();
        
        if (!__minimized)
        {
            if ((__window_width_last  != __window_width)
            ||  (__window_height_last != __window_height)
            ||  (__window_x_last      != __window_x)
            ||  (__window_y_last      != __window_y)
            ||  (__window_focus_last  != __window_focus)
            ||  (__fullscreen_last    != __fullscreen))
            {                
                //Rebuild monitor list
                __display_change = __monitor_list_update();
                
                //Handle bugged out Windows runner fullscreen monitor change behavior
                if ((os_type == os_windows) && __fullscreen && (__monitor_active != __monitor_active_last) && (__deferred_handle == undefined)) 
                {
                    __deferred_handle = new __class_fullscreen_change(__monitor_active);
                }
            
                __monitor_active_last = __monitor_active;                
                __window_width_last   = __window_width;
                __window_height_last  = __window_height;
                __window_x_last       = __window_x;
                __window_y_last       = __window_y;
                __window_focus_last   = __window_focus;
                __fullscreen_last     = __fullscreen;
            }
        }
    }
    
    __monitor_set_error = function(_monitor)
    {
        if (os_type != os_windows)
        {
            return "Monitor change refused, window is already in active display";
        }
        else 
        {
            __monitor_list_update();
            
            if (_monitor == __monitor_active)
            {
                return "Monitor change refused, window is already in active monitor";
            }
            else if (__deferred_handle != undefined)
            {
                return "Monitor change refused, deferred change in progress";
            }
            else if ((_monitor < 0) || (_monitor >= array_length(__monitor_list)))
            {
                return "Monitor change refused, invalid monitor index " + _monitor;
            }
            else
            {
                if (!__fullscreen)
                {
                    if (__recently_maximized) return "Monitor change refused, window is maximized";
                }
                else if (__using_borderless && window_get_borderless_fullscreen())
                {
                    return "Monitor change refused, unsupported in borderless fullscreen";
                }   
            }
        }
        
        return undefined;
    }
    
    __monitor_set = function(_monitor)
    {
        var _error = __monitor_set_error(_monitor);
        if (is_undefined(_error))
        {
           __log("Moving from monitor index ", __monitor_active, " to ", _monitor);
           __deferred_handle = (__fullscreen? new __class_fullscreen_change(_monitor) : new __class_move_change(_monitor));
        }
        else
        {
            __log(_error);
        }
    }
    
    #endregion
    
    #region Initialize 
    
    __monitor_list_update();
    __timesource_handle = time_source_create(time_source_game, time_source_units_frames, 1, __tick, [], -1);
    time_source_start(__timesource_handle);
    if (display_aa < DISPLAY_AA_LEVEL) __log("Warning! Configured DISPLAY_AA_LEVEL ", DISPLAY_AA_LEVEL, " exceeds maximum available value ", display_aa);
    
    #endregion
    
})(); return __instance; };

#endregion

#region Public functions

function display_monitor_set(_monitor) { DisplayManager().__monitor_set(_monitor); }
function display_monitor_set_allowed(_monitor) { return is_undefined(DisplayManager().__monitor_set_error()); }
function display_monitor_active() { return DisplayManager().__monitor_active; }
function display_monitor_list() { return DisplayManager().__monitor_list; }
function display_time_source() { return DisplayManager().__timesource_handle; }

#endregion
