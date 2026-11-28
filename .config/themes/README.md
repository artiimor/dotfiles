# Color themes

Every folder with a `theme.json` is a theme. `current` is a link to the active one.

- Switch themes: **Super+T**, or `~/.config/themes/theme-set <folder>`
- **Super+M** → Style gathers theme, font, background, profile and increase contrast (in Mac mode, the Appearance window)
- List the themes: `~/.config/themes/theme-set`
- After editing the active theme's `theme.json`: `~/.config/themes/theme-set --reapply`

## Creating a new one

1. Copy a folder: `cp -r miami my-theme`
2. Change `name` (what the menu shows) and the colors in `theme.json`
3. Pick it with Super+T

## What each part of theme.json is for

| Section | What for | Programs |
|---|---|---|
| `ui` | Bar, launcher, notifications, OSD, lock screen | Quickshell, hyprlock |
| `ui.launcherBg` / `ui.launcherSel` | Launcher background and its selected row | Quickshell |
| `ui.border` | Thin border of the islands (used at 25 %) | Quickshell |
| `hypr.border` | Gradient of the active window border (2 or more colors) | Hyprland |
| `hypr.inactive` | Border of inactive windows, accepts transparency `#rrggbbaa` | Hyprland |
| `hypr.group` | Border of window groups | Hyprland |
| `term` | Background, text, cursor, selection and the 16 ANSI colors (`colors[0..15]`) | Ghostty, btop, fzf, starship |
| `gtk` | Windows, header bars, cards and accent | GTK3/GTK4 apps |
| `nvim` | Colorscheme name: `catppuccin-mocha`, `catppuccin-macchiato`, `catppuccin-frappe`, `catppuccin-latte`, `tokyonight`, `rose-pine`, `rose-pine-dawn`, `gruvbox`, `kanagawa-dragon`, `everforest`, `dracula` | Neovim |
| `nvimColors.syn` | Syntax colors (string, fun, keyword, comment...) of the "tema" colorscheme; without them mini.hues is almost gray. Every theme has them, taken from its original palette | Neovim |
| `nvimColors.ui` | Optional: overrides interface colors of "tema" (see below) | Neovim |
| `light` | `true` for light themes (without it, dark): decides light or dark Mac mode and light or dark GTK (see below) | config-set |

When the change shows up: Quickshell, Hyprland, Ghostty and open Neovims
(theme-set sends them `background` and the colorscheme through their socket) right away; btop
and GTK and Qt apps when reopened; fzf and fastfetch (the Pepe, tinted with the
accent) in new terminals; hyprlock on the next lock.

Outside the themes: ReGreet (macOS-style dark gray) and Plymouth ("sobrio"). The lock
screen keeps the night Pepe.

## Backgrounds

As in Omarchy, each theme can bring its backgrounds in `<theme>/backgrounds/`
(jpg, png, webp...). **Super+Ctrl+B** shows them with thumbnails (plus the usual
Pepes) and **Super+Ctrl+Shift+B** moves to the next one. The "＋ Add wallpapers…" entry
opens that folder in Dolphin to drag images into. One is remembered per theme;
with none chosen, the first (the Pepes if the theme has none). Also from the terminal
with `background-set` (see the script).

## Font

The monospace font is separate from the theme: it isn't in `theme.json` and doesn't
change when switching themes or with `--reapply`. Pick it in the **Font** tab of Super+T
(each row written in its font) or with `font-set "<family>"` (`font-set` alone
lists the installed monospace Nerd Fonts, one per family). It's saved in
`~/.local/state/font` and font-set writes `ghostty/font.ghostty` and
`hypr/font.conf` (hyprbars in Normal mode, with the "Propo" variant if it exists). With
none chosen, each program keeps its own: Ghostty's default and JetBrains
Mono in hyprbars. The Quickshell interface, hyprlock and
Mac mode keep theirs.

## Increase contrast

Like macOS's Accessibility > Increase contrast, for any theme and both profiles:
thicker, opaque window borders (the active one in the theme's text color), no blur,
pure black/white hyprbars text, more marked secondary text and bar borders in
Quickshell, and GTK/libadwaita high contrast (`org.gnome.desktop.a11y.interface
high-contrast`, which the portal passes on to GTK4 apps). Qt apps don't change.
Terminals (Ghostty, btop, fzf) and Neovim get slightly stronger colors:
the background moves 30 % towards black (white in light themes), the text towards
white (black), and every ANSI, syntax and UI text color that reads below 4.5:1
against that background is nudged just enough to reach it (`boost_contrast()` in
`themelib.py`). theme-set writes the boosted theme to
`~/.local/state/increased-contrast.json`, which Neovim reads instead of the theme's
`theme.json`. Ghostty and open Neovims change at once; btop and fzf when reopened.
Toggle it from the **Increase Contrast** tile of the Control Center (Mac mode), the
contrast button of the bar next to Night light and Keep awake (Normal mode), or with
`contrast-set on|off|toggle` (`contrast-set` alone prints `on` or `off`). It's saved in
`~/.local/state/increased-contrast`: Hyprland reads it on `hyprctl reload` (the
script does it) and Quickshell watches the file.

## Light themes

`catppuccin-latte`, `rose-pine-dawn`, `snow` and `terminal-clasico` are light (`"light": true`), with the 16
ANSI colors of their original palettes (`snow`, all grays; `terminal-clasico`, Terminal.app "Basic" with Vim's `default` syntax). In light themes theme-set doesn't use
`colors[0]`/`colors[15]` for the selected row of fzf and btop (it uses
`term.selection_background` and `ui.fg`) nor for Qt's bevels (it computes them
from the buttons); dark themes are unchanged. Open Neovims get
`background=light|dark` along with the colorscheme, and the lock screen
(Quickshell and hyprlock) makes the text almost white over the night background.

In the theme menu (Super+T) each row shows its palette (terminal background and
text, accent and 6 colors) and a sun or a moon for light or dark. The
themes are in two tabs, **Dark** and **Light** (the third, **Font**, is
font-set's); it opens on the active theme's tab,
with it selected. Switch tabs with a click, Tab / Shift+Tab or ←/→. Each tab has its own search
(typing filters; going back to a tab keeps what you typed in it), and in Font
fonts are also found by their original name (e.g. "Cascadia" → CaskaydiaCove).

## Neovim

The "tema" colorscheme (`nvim/colors/tema.lua`, the same in LazyVim) takes the whole
interface from the theme's palette, not just the syntax: line numbers, cursor
line, selection (`term.selection_background`), menus and floats
(`ui.launcherBg`, selected row `ui.launcherSel`, border `ui.border` at 25 %),
statusline, tabs, separators, search (`ui.accent`), diagnostics
(`ui.red`, `ui.yellow`, `ui.cyan`, `ui.accent2`, `ui.ok`) and diff. The background stays
transparent. If a background color matches the terminal's (`term.background`),
the next distinguishable one is used.

`nvimColors.ui` (optional) overrides any of these keys: `panel` (menus,
floats, statusline), `sel`, `cursorline`, `visual`, `nontext` and `special` (default
`ui.muted`), `whitespace` (default `ui.accentDim`), `border`, `dim`, `accent`, `accent2`, `muted`, `red`, `yellow`, `ok`,
`info`, `hint`. To try a theme without switching the active one:
`TEMA_THEME_JSON=~/.config/themes/snow/theme.json nvim`. Line numbers are always
black in light themes and white in dark ones.

## Configs: Mac mode / Normal mode

Besides the color theme there are two desktop profiles. Switch them with
**Super+Shift+T** ("Config" menu: *Mac mode* and *Normal mode*) or
`~/.config/themes/config-set mac|default` (`config-set` alone lists the
profiles). It applies right away, without logging out.

| | Mac mode | Normal mode (`default`) |
|---|---|---|
| Bar, notifications | macshell (`quickshell/macshell`) | this Quickshell's |
| Super+Space / Super+Esc / Super+A | Spotlight / PowerMenu / macshell's center | launcher / power menu / this one's notifications |
| Windows | 10 px corners and shadow | square, default shadow |
| hyprbars | Sur-Gris gray, Noto Sans, 32 px | theme color, font-set's font (JetBrains Mono), 28 px |
| Icons (GTK, Qt, Dolphin) | Sur-Transparente (Sur with a light theme) | Papirus-Dark (Papirus-Light with a light theme) |
| Qt (qt6ct) | Breeze, `mac-dark.conf` colors, Noto Sans | Fusion, theme colors (`current.conf`) |
| Workspaces | all floating; Super+Alt+D turns one into tiling | tiling; Super+Alt+D turns one into floating |

**Light or dark is decided by the color theme.** In Mac mode, with a light theme
the profile becomes **light Mac** (`mac-light`, internal): light macshell and hyprbars,
Sur icons, GTK `adw-gtk3` + `prefer-light` with a fixed light `gtk.css` (theme-set
doesn't overwrite it in this profile) and Qt with `mac-light.conf`; with a dark one it goes back to `mac`.
theme-set does it when switching themes (it calls config-set's `sync_theme()`; macshell
switches live, without restarting Quickshell), and `config-set mac` with a light
theme already saves `mac-light`. `config-set mac-light` still forces it by
hand (until the next theme switch or `--reapply`). Terminals keep the color theme.

In Normal mode, a light theme sets GTK `adw-gtk3` + `prefer-light` (with the theme's
`gtk.css`) and Papirus-Light icons; Qt, Hyprland, hyprbars and the bar already follow the theme.

In Mac mode, the windows of this Quickshell that are still used
(launcher menus: themes, configs, clipboard, emojis, keybindings...; OSD, polkit
and dock) copy macshell's look (`Theme.mac` in `quickshell/Theme.qml`).

Common to both: color theme (in Mac it doesn't recolor Qt apps or hyprbars),
macOS cursor (black), keyd (Alt/Super swapped, HHKB untouched), Super+Shift+Space
= app launcher, `QT_QPA_PLATFORMTHEME=qt6ct`, window rules, etc.

The profile is saved in `~/.local/state/desktop-profile` and read by
`hypr/config/profile.lua` and `quickshell/shell.qml`. Without that file,
"mac" is used if macshell is present and "default" otherwise.
