text_color       = '4f4f4f'
background_color = 'dedede'

function cnf ()
    local_config = {
        alignment = 'top_left',
        background = true,
        border_width = 1,
        cpu_avg_samples = 2,
        default_color = text_color,
        default_outline_color = text_color,
        default_shade_color = text_color,
        draw_borders = true,
        draw_graph_borders = true,
        draw_outline = false,
        draw_shades = false,
        use_xft = true,
        font = 'Mono:size=12',
        own_window = true,
        own_window_class = 'Conky',
        own_window_type = 'override',
        own_window_transparent = false,
        own_window_argb_visual = true,
        own_window_argb_value = 200,
        own_window_colour = background_color,
        net_avg_samples = 2,
        double_buffer = true,    
        out_to_console = false,
        out_to_stderr = false,
        extra_newline = false,
        stippled_borders = 0,
        update_interval = 1.0,
        uppercase = false,
        use_spacer = 'none',
        show_graph_scale = false,
        show_graph_range = false,
        default_graph_height = 60,
    }
    return local_config
end

function mergeFn(a, b)
    if type(a) == 'table' and type(b) == 'table'
    then
	for k,v in pairs(b)
        do
            if type(v)=='table' and type(a[k] or false)=='table'
            then
                merge(a[k],v)
            else
                a[k]=v
            end
        end
    end
    return a
end
