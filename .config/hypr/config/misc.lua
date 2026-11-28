hl.config({
    dwindle = {
        preserve_split = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    misc = {
        col = {
            splash = THEME_ACCENT,
        },
        -- Without Hyprland's default girl/logo: if the Quickshell wallpaper
        -- takes a moment (e.g. when unlocking), only this flat color is shown
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = THEME_BG,
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "(" .. require("config.util").TERMINAL_CLASSES .. ")",
        vrr = 3,
        -- If the lock screen (Quickshell) closes while locked,
        -- allows relaunching it instead of being stuck on the red screen
        allow_session_lock_restore = true,
    },
    render = {
        direct_scanout = 2,
        -- Use the option below if you find games constantly black screening for a couple seconds whenever direct scanout enables/disables
        -- non_shader_cm = 0,
    },
    xwayland = {
        force_zero_scaling = true
    },
})
