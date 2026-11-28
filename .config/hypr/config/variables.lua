-- Hyprland default apps

-- "Hyprland (uwsm-managed)" session? uwsm's Hyprland plugin exports this
-- variable; in the plain "Hyprland" session (start-hyprland) it doesn't exist
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
