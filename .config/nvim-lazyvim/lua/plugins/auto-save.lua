return {
  "okuuva/auto-save.nvim",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    debounce_delay = 1000, -- ms que espera tras el último cambio antes de guardar
    -- noautocmd = true,   -- descomenta si no quieres que formatee en cada autosave
  },
}
