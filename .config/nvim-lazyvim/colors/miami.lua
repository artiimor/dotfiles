-- Miami night: soft pastels on purple, matching ~/.config/themes/miami
-- (same palette as the terminal). Pink for keywords, cyan for functions,
-- lavender for types. The groups are in lua/scheme.lua.
require("scheme").apply("miami", {
  fg = "#d9d6e6", bright = "#e6e3ef", light = "#e6e3ef",
  grey = "#a99bd6", dim = "#8f8aa8", muted = "#6b6789", faint = "#3d3558",
  line = "#2a2440", surface = "#1c1826", sel = "#3d3558", ink = "#221d33",
  red = "#e8798a", yellow = "#e8cf8a", green = "#8fd6b4", blue = "#848bbd", cyan = "#86d4dc",
  diff_add = "#253a35", diff_change = "#2c2a45", diff_delete = "#3a2433", diff_text = "#3a3660",
  keyword = "#e89bd0", keyword_bold = false,
  func = "#86d4dc",
  string = "#8fd6b4",
  const = "#f2b8a0",
  type = "#a99bd6",
  term = { "#2e2945", "#e8798a", "#8fd6b4", "#e8cf8a", "#a99bd6", "#e89bd0", "#86d4dc", "#c9c5d8",
           "#6b6789", "#f0939f", "#a8e2c6", "#f0dba3", "#bdb2e2", "#f0b4dc", "#a3e0e6", "#e6e3ef" },
})
