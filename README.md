# dotfiles

My CachyOS desktop: **Hyprland** (Lua config) + **Quickshell** for everything else (bar, launcher, notifications, lock screen and dock).

Designed by me and implemented with help from [Claude Code](https://claude.com/claude-code).
[Omarchy](https://omarchy.org) was the inspiration for the desktop mode and the theme switcher.

![Tiling](screenshots/tiling.png)

## What's inside

- **Hyprland 0.57 with a Lua config** (`.config/hypr/hyprland.lua` + `config/*.lua`), dwindle tiling,
  per-monitor workspaces, rounded corners and dimmed inactive windows.
- **Quickshell** (`.config/quickshell`) replaces waybar, wofi, swaync, swayosd, hyprpaper and the polkit agent:
  bar, app launcher and menus (power, clipboard, emoji, themes, keybinding cheatsheet, wifi and bluetooth via dmenu),
  notifications, volume and brightness OSD, night light, wallpaper, lock screen and polkit dialog.
- **Per-workspace desktop mode**: on the workspaces you pick, windows float, can be minimized
  and a dock shows up at the bottom. In the bar, those workspaces have their number inside a box.
- **macOS-style titlebars** on every floating window (close, minimize, maximize), using a patched `hyprbars` plugin.
- **Color theme switcher** (`.config/themes`): one `theme.json` per theme that colors Hyprland, Quickshell,
  hyprlock, ghostty, kitty, btop, GTK, Qt/KDE, fzf, fastfetch and running Neovims at once.
  Ships with kanagawa-dragon, everforest, miami, catppuccin, tokyo-night, rose-pine, gruvbox and vantablack. See `.config/themes/README.md`.
- **ghostty** as the terminal, bash + starship prompt, Neovim with LazyVim (own miami and vantablack colorschemes),
  btop, and fastfetch with a random ASCII Pepe tinted with the theme accent.

![Launcher](screenshots/launcher.png)

### Desktop mode

![Desktop mode](screenshots/desktop-mode.png)

- **Super+Alt+D** turns it on or off for the current workspace. New windows open floating, centered and at 65% of the screen.
- **Super+M** (or the yellow titlebar button) minimizes the window.
- **Dock** (auto-hides, hover the bottom edge): click a window to bring it to the front; click the active one to minimize it; click a minimized one to restore it.
- **Snapping**: drop a window against the left or right edge for half the screen, against the top to maximize. Dragging it away restores its size.
- Moving a window to a normal workspace puts it back in tiling.

It lives in `.config/hypr/config/desktopmode.lua` and `.config/quickshell/modules/Dock.qml`.

The titlebars need `hyprbars` built by hand with the patch in `.config/hypr/hyprbars-on-drag-end.patch`
(adds the drag hooks the snapping uses); the build steps are in a comment in `desktopmode.lua`.
Without the plugin everything else still works, just without titlebars.

## Keybindings

**Super+/** shows the full list on screen.

| Keys | Action |
|---|---|
| Super+Space | App launcher |
| Super+Enter | Terminal (ghostty) |
| Super+F | Files (Dolphin) |
| Super+Ctrl+T | Text editor |
| Super+Shift+C | Calculator |
| Ctrl+Shift+Esc | btop |
| Super+W | Close window |
| Super+Shift+Esc | Kill window (click it) |
| Super+H/J/K/L | Move focus |
| Super+Shift+H/J/K/L | Move window |
| Super+1…0 | Go to workspace |
| Super+Shift+1…0 | Send window to workspace |
| Super+Alt+1…0 | Go to workspace 11–20 (external monitor's), if it has windows |
| Super+Tab / Super+Shift+Tab | Focus other monitor / send window there |
| Super+D | Fullscreen |
| Super+Alt+Space | Toggle floating |
| Super+Alt+J | Toggle split direction |
| Super+Alt+D | Desktop mode on this workspace |
| Super+M | Minimize |
| Alt+Tab | Next window |
| Super+S / Super+Shift+S | Scratchpad: show / send window |
| Super+Plus / Super+Minus | Zoom in / out |
| Super+Esc | Power menu |
| Super+Ctrl+V | Clipboard history |
| Super+. | Emoji |
| Super+T | Switch theme |
| Super+A | Notification center |
| Super+Alt+L | Lock |
| Super+Shift+P | Screenshot a region |
| Super+C / Super+V / Super+X | Copy / paste / cut in any app |

Workspace numbers are bound by keycode, so they also work on AZERTY keyboards.

## Installation

There's no script: copy whatever you want into your `~`.

```sh
git clone https://github.com/artiimor/dotfiles.git
cp -r dotfiles/.config/* ~/.config/
cp dotfiles/.bashrc dotfiles/.bash_profile ~/
```

Packages it uses: `hyprland` (0.57 or newer, for the Lua config), `quickshell`, `uwsm`, `ghostty`, `hypridle`,
`hyprlock` (as a fallback), `hyprsunset`, `hyprshot`, `cliphist`, `wl-clipboard`, `brightnessctl`, `playerctl`,
`wireplumber`, `power-profiles-daemon`, `networkmanager-dmenu`, `bzmenu`, `pavucontrol`, `dolphin`, `qt6ct`,
`starship`, `btop`, `fastfetch`, `neovim`, `python` (for `theme-set`) and the `ttf-jetbrains-mono-nerd` font.
Optional: `kitty` (also themed) and the `hyprbars` plugin.

After copying, run `~/.config/themes/theme-set miami` (or any other theme) to generate the color files.

Things you'll probably want to change:

- `.config/hypr/config/variables.lua`: default apps and monitor names.
- `.config/hypr/config/inputs.lua`: keyboard layout (`us` altgr-intl). On my ThinkPad, Alt and Super are swapped with keyd, outside this repo.
- `.config/quickshell/Theme.qml`: the wallpaper paths.
