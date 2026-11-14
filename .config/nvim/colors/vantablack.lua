-- Vantablack: casi monocromo, a juego con ~/.config/themes/vantablack.
-- Grises para casi todo; solo strings, constantes y diagnósticos llevan un tono apagado.
-- Los grupos están en lua/scheme.lua.
require("scheme").apply("vantablack", {
  fg = "#d4d4d4", bright = "#f0f0f0", light = "#e6e6e6",
  grey = "#a0a0a0", dim = "#8a8a8a", muted = "#5c5c5c", faint = "#3a3a3a",
  line = "#121212", surface = "#0d0d0d", sel = "#262626", ink = "#000000",
  red = "#c46a6a", yellow = "#c9b27c", green = "#8c9c8c", blue = "#8a96a8", cyan = "#8aa3a3",
  diff_add = "#141a14", diff_change = "#14161a", diff_delete = "#1a1212", diff_text = "#20242c",
  term = { "#121212", "#b86b6b", "#8c9c8c", "#b8a77e", "#8a96a8", "#a48ca8", "#8aa3a3", "#bdbdbd",
           "#4a4a4a", "#cc8080", "#a3b3a3", "#ccbc94", "#a0abbd", "#b9a3bd", "#a0b8b8", "#f0f0f0" },
})
