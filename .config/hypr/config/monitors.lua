-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Output names come from `hyprctl monitors all`. On first install, install.sh
-- replaces this file with one that has a rule per detected screen.
-- Example for a specific screen (wins over the general rule below):
-- hl.monitor({
--     output    = "eDP-1",
--     mode      = "1920x1080@60",
--     position  = "0x0",
--     scale     = "1",
-- })

-- General rule (output "" = any screen): works on any machine without changes
hl.monitor({
    output    = "",
    mode      = "preferred",
    position  = "auto",
    scale     = "auto",
})
