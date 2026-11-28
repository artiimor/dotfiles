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

-- ThinkPad Alt/Super swap and CapsLock->Control: done by keyd (/etc/keyd/thinkpad.conf), not xkb
-- (with a per-device keymap Hyprland didn't apply the Super modifier)

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
