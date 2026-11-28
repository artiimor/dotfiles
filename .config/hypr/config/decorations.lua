-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 1,
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
        -- "default" profile: square corners and Hyprland's default shadow
        rounding = 0,
        active_opacity = 1,
        inactive_opacity = 1,
        -- The inactive one is told apart by darkening it a bit, no transparency
        dim_inactive = true,
        dim_strength = 0.1,
        fullscreen_opacity = 1,
        -- No compositor blur in any profile: costs GPU (and battery) every frame
        blur = { enabled = false },
    },
})

-- "mac" profile: rounded corners and shadow like Plasma windows (Sur-Gris)
if PROFILE_MAC then
    hl.config({
        decoration = {
            rounding = 10,
            rounding_power = 2,
            dim_inactive = false,
            shadow = {
                enabled = true,
                range = 24,
                render_power = 3,
                offset = "0 6",
                color = PROFILE_LIGHT and "rgba(00000040)" or "rgba(00000077)",
                color_inactive = PROFILE_LIGHT and "rgba(00000022)" or "rgba(00000044)",
            },
        },
    })
end

-- Increase contrast (CONTRAST, see profile.lua and themes/contrast-set): thicker
-- border, the active one in the theme's text color and the inactive one too, at 60 %, so
-- window outlines are always visible (the theme's inactive grey gets lost
-- on light backgrounds)
if CONTRAST then
    hl.config({
        general = {
            border_size = 2,
            col = {
                active_border = THEME_FG,
                inactive_border = THEME_FG:gsub("%x%x%)$", "99)"),
            },
        },
    })
end
