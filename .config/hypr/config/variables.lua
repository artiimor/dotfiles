-- Hyprland default apps

-- ¿Sesión "Hyprland (uwsm-managed)"? El plugin de Hyprland de uwsm exporta esta
-- variable; en la sesión "Hyprland" normal (start-hyprland) no existe
UWSM = os.getenv("UWSM_FINALIZE_VARNAMES") ~= nil

TERMINAL = "ghostty"
FILE_MANAGER = "dolphin"
EDITOR = "gnome-text-editor --new-window"
CALCULATOR = "gnome-calculator"

-- Monitors
MONITOR1 = ""
PRIMARY_MONITOR = MONITOR1

-- Workspaces
NUM_WPM = 10 -- Number of workspaces per monitor (Max 10)
