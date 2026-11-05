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
        -- Sin la chica/logo por defecto de Hyprland: si el fondo de Quickshell
        -- tarda un instante (p. ej. al desbloquear), se ve solo este color liso
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = THEME_BG,
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
        vrr = 3,
        -- Si la pantalla de bloqueo (Quickshell) se cierra estando bloqueado,
        -- permite volver a lanzarla en vez de quedarte en la pantalla roja
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
