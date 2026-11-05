-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = THEME_BORDER,
                angle = 45,
            },
            inactive_border = THEME_INACTIVE,
        },
    },
    group = {
        col = {
            border_active = THEME_GROUP,
            border_inactive = THEME_INACTIVE,
            border_locked_active = THEME_ACCENT,
            border_locked_inactive = THEME_INACTIVE,
        },
        groupbar = {
            col = {
                active = THEME_GROUP,
                inactive = THEME_INACTIVE,
                locked_active = THEME_ACCENT,
                locked_inactive = THEME_INACTIVE,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 10,
        active_opacity = 0.95,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = {
            size = 5,
            passes = 4,
            special = true,
        },
    },
})
