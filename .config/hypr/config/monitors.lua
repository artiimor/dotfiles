-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Los nombres de las salidas salen de `hyprctl monitors all`. install.sh, en la primera
-- instalación, cambia este archivo por uno con una regla por pantalla detectada.
-- Ejemplo de una pantalla concreta (gana a la regla general de abajo):
-- hl.monitor({
--     output    = "eDP-1",
--     mode      = "1920x1080@60",
--     position  = "0x0",
--     scale     = "1",
-- })

-- Regla general (output "" = cualquier pantalla): vale en cualquier equipo sin tocar nada
hl.monitor({
    output    = "",
    mode      = "preferred",
    position  = "auto",
    scale     = "auto",
})
