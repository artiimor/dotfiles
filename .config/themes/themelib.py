# Shared by theme-set, config-set, background-set and font-set: paths, current theme, saved
# profile, file writing, Quickshell notifications and translation (tr). It isn't a
# theme (it has no theme.json): they import it, running from this
# folder (sys.path[0]) and setting sys.dont_write_bytecode = True first so no
# __pycache__ shows up here.
#
# Bash scripts (install.sh, quickshell/scripts/webapp...) translate with
#   python3 ~/.config/themes/themelib.py tr "Text %1" arg

import importlib.util
import json
import os
import subprocess
import sys
from importlib.machinery import SourceFileLoader

HOME = os.path.expanduser("~")
CONF = f"{HOME}/.config"
THEMES = f"{CONF}/themes"
CURRENT = f"{THEMES}/current"
PROFILE_STATE = f"{HOME}/.local/state/desktop-profile"  # written by config-set

QUIET = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# THEMES_NO_RELOAD=1: files are written but nothing outside is notified
# (Quickshell, Hyprland, terminals, Neovim, gsettings, notifications). For the
# tests: with a temporary HOME the user's files aren't touched, but gsettings would write
# to their real dconf. Everything goes through run_quiet(), except theme-set's reload_nvim() and
# config-set's restart_shell(), which check it themselves
NO_RELOAD = bool(os.environ.get("THEMES_NO_RELOAD"))


# ── Idioma ───────────────────────────────────────────────────

_dict = None  # translations of the active language; loaded the first time they're needed


def tr(s, *args):
    # English text → active language (i18n/<language>.json next to this file; with no
    # file or no key, English). %1, %2... are replaced by args
    global _dict
    if _dict is None:
        _dict = {}
        env = next((v for v in (os.environ.get(k) for k in ("LC_ALL", "LC_MESSAGES", "LANG")) if v), "")
        lang = env.replace(".", "_").replace("@", "_").split("_")[0]
        if lang not in ("", "en", "C", "POSIX"):
            try:
                with open(f"{os.path.dirname(os.path.abspath(__file__))}/i18n/{lang}.json") as f:
                    _dict = json.load(f)
            except (OSError, ValueError):
                pass
    s = _dict.get(s, s)
    for i in range(len(args), 0, -1):  # from highest to lowest: %10 before %1
        s = s.replace(f"%{i}", str(args[i - 1]))
    return s


# ── Temas ────────────────────────────────────────────────────

def current_theme():
    # Name of the active theme (where the current link points), or None
    try:
        return os.path.basename(os.readlink(CURRENT))
    except OSError:
        return None


def list_themes():
    # Every folder with a theme.json is a theme
    return sorted(d for d in os.listdir(THEMES)
                  if os.path.isfile(f"{THEMES}/{d}/theme.json") and d != "current")


def load_theme(name="current"):
    with open(f"{THEMES}/{name}/theme.json") as f:
        return json.load(f)


def theme_light():
    # "light": true in the active theme's theme.json (without it, dark)
    try:
        return bool(load_theme().get("light"))
    except (OSError, ValueError):
        return False


# ── Increase contrast (contrast-set) ────────────────────────
# With the mode on, theme-set writes the terminal colors (Ghostty, btop,
# fzf) passed through boost_contrast() and leaves the whole theme like that in CONTRAST_THEME,
# which Neovim reads instead of themes/current/theme.json (nvim/lua/tema/theme.lua).

CONTRAST_STATE = f"{HOME}/.local/state/increased-contrast"
CONTRAST_THEME = f"{HOME}/.local/state/increased-contrast.json"
CONTRAST_MIN = 4.5   # minimum contrast of each color against the background (WCAG AA)
CONTRAST_BG = 0.3    # how close the background gets to black (to white in light themes)
CONTRAST_FG = 0.5    # how close the text gets to white (to black in light themes)


def contrast_on():
    return read_state(CONTRAST_STATE) == "1"


def rgb(hexcolor):
    h = hexcolor.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a, b, k):
    # Color between a and b (k = 0 → a, k = 1 → b); keeps a's alpha if it has one
    out = "#" + "".join(f"{round(x + (y - x) * k):02x}" for x, y in zip(rgb(a), rgb(b)))
    return out + a.lstrip("#")[6:8]


def _lum(h):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _ratio(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def _legible(c, bg, ink):
    # Moves c towards ink (white or black) just enough to reach CONTRAST_MIN against bg
    k = 0.0
    while _ratio(mix(c, ink, k), bg) < CONTRAST_MIN and k < 1:
        k = min(1.0, k + 0.05)
    return mix(c, ink, k)


def boost_contrast(t):
    # Copy of the theme with a darker terminal background (lighter in light
    # themes), stronger text and every ANSI, Neovim syntax and ui text
    # color with minimum contrast against that background. The ones already readable don't change.
    # colors[0], [7] and [15] aren't touched: each palette's ANSI black and whites
    # (in light ones, some are the background color on purpose).
    t = json.loads(json.dumps(t))
    light = bool(t.get("light"))
    edge, ink = ("#ffffff", "#000000") if light else ("#000000", "#ffffff")
    term = t["term"]
    bg = term["background"] = mix(term["background"], edge, CONTRAST_BG)
    term["foreground"] = mix(term["foreground"], ink, CONTRAST_FG)
    term["colors"] = [c if i in (0, 7, 15) else _legible(c, bg, ink) for i, c in enumerate(term["colors"])]
    ui = t.get("ui", {})
    if "fg" in ui:
        ui["fg"] = mix(ui["fg"], ink, CONTRAST_FG)
    for k in ("muted", "accent", "accent2", "ok", "red", "yellow", "cyan"):
        if k in ui:
            ui[k] = _legible(ui[k], bg, ink)
    # From nvimColors.ui only the text ones (panel, sel, visual... are backgrounds)
    nv = t.get("nvimColors", {})
    text = ("nontext", "special", "muted", "accent", "accent2", "red", "yellow",
            "ok", "info", "hint")
    for group, keys in ((nv.get("syn", {}), None), (nv.get("ui", {}), text)):
        for k, c in group.items():
            if keys is None or k in keys:
                group[k] = _legible(c, bg, ink)
    return t


def saved_profile():
    # What's in ~/.local/state/desktop-profile, or None if there is no file
    return read_state(PROFILE_STATE)


# ── Archivos ─────────────────────────────────────────────────

def read_state(path):
    # Contents of a state file (~/.local/state/...), or None if it doesn't exist
    try:
        return open(path).read().strip()
    except OSError:
        return None


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def write_atomic(path, text):
    # Written separately and swapped in one go: readers never see it half-written
    tmp = path + ".tmp"
    write(tmp, text)
    os.replace(tmp, path)


def load_script(name):
    # Loads another script from this folder (without .py) as a module, without __pycache__
    sys.dont_write_bytecode = True
    mod = name.replace("-", "_")
    loader = SourceFileLoader(mod, f"{THEMES}/{name}")
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(mod, loader))
    loader.exec_module(module)
    return module


# ── Avisos ───────────────────────────────────────────────────

def run_quiet(cmd):
    if not NO_RELOAD:
        subprocess.run(cmd, **QUIET)


def qs_theme_reload():
    # Quickshell re-reads theme.json and asks background-set for the background
    run_quiet(["qs", "ipc", "call", "theme", "reload"])


def reload_terminals():
    run_quiet(["pkill", "-USR2", "-x", "ghostty"])  # Ghostty re-reads its config


def notify(app, title, body):
    run_quiet(["notify-send", "-a", app, title, body])


if __name__ == "__main__" and sys.argv[1:2] == ["tr"] and len(sys.argv) > 2:
    print(tr(*sys.argv[2:]), end="")
