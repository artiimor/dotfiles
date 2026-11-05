-- Input configuration

hl.config({
    input = {
        kb_layout = "us",
        kb_options = "caps:none",
        kb_variant = "altgr-intl", -- AltGr + a/e/i/o/u = áéíóú, AltGr + n = ñ
        -- sensitivity = -0.25,
        accel_profile = "flat",
    },
    -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
    -- cursor = {
    --     no_hardware_cursors = 1,
    -- },
})

-- Swap left Alt <-> left Super solo en el teclado del ThinkPad (no en el HHKB)
hl.device({
    name       = "at-translated-set-2-keyboard",
    kb_layout  = "us",
    kb_variant = "altgr-intl",
    kb_options = "altwin:swap_lalt_lwin,caps:none",
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
