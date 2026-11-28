return {
  "okuuva/auto-save.nvim",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    debounce_delay = 1000, -- ms to wait after the last change before saving
    -- noautocmd = true,   -- uncomment if you don't want it to format on every autosave
  },
}
