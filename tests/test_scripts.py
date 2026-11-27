# Tests de los scripts de .config/themes (theme-set, config-set, font-set,
# background-set, contrast-set). Cada test copia el .config del repo a un HOME temporal y
# ejecuta los scripts ahí con THEMES_NO_RELOAD=1. En PATH van delante unos stubs
# (qs, hyprctl, gsettings...) que solo apuntan su llamada: al terminar cada test
# se comprueba que no se ha avisado a nada de fuera. Si el interruptor fallara,
# los stubs también evitan tocar el escritorio del usuario.
import json
import os
import shutil
import subprocess
import sys

import pytest

from conftest import CONFIG, THEMES, load_theme

# Programas con efecto fuera de los archivos (y fc-list, que solo lee)
STUBS = ("qs", "hyprctl", "gsettings", "notify-send", "nvim", "kitty", "ghostty", "pkill",
         "fc-list")
# Lo que devuelve el fc-list falso a font-set: "familia\tspacing"
FONTS = "Foo Nerd Font\t100\nFoo Nerd Font Propo\t0\nFoo Nerd Font Mono\t100\nBar Sans\t0\n"

LIGHT = sorted(n for n in THEMES if load_theme(n).get("light"))
DARK = sorted(n for n in THEMES if not load_theme(n).get("light"))


@pytest.fixture
def home(tmp_path):
    shutil.copytree(CONFIG, tmp_path / ".config", symlinks=True)
    state = tmp_path / ".local/state"
    state.mkdir(parents=True)
    # Con perfil guardado: si no, el primer theme-set pasa a Modo Mac (y espera 1,5 s)
    (state / "desktop-profile").write_text("default\n")
    # Un "Neovim abierto": sin el interruptor, theme-set le mandaría el tema nuevo
    (tmp_path / "run").mkdir()
    (tmp_path / "run/nvim.1.0").touch()
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    for name in STUBS:
        out = f"printf '{FONTS}'\n" if name == "fc-list" else ""
        # Una línea por llamada (los argumentos pueden llevar saltos de línea)
        log = f'"{tmp_path}/calls.log"'
        (stubs / name).write_text(f'#!/bin/sh\necho "{name} $*" | tr "\\n" " " >> {log}\n'
                                  f'echo >> {log}\n{out}')
        (stubs / name).chmod(0o755)
    yield tmp_path
    log = tmp_path / "calls.log"
    assert calls(tmp_path) <= {"fc-list"}, "llamadas de fuera:\n" + log.read_text()


def calls(home):
    # Programas a los que han llamado los scripts (primera palabra de cada línea)
    log = home / "calls.log"
    return {l.split()[0] for l in log.read_text().splitlines()} if log.exists() else set()


def run(home, script, *args, check=True, reload=False):
    env = {**os.environ, "HOME": str(home), "PATH": f"{home}/stubs:{os.environ['PATH']}",
           "XDG_RUNTIME_DIR": str(home / "run"), "LC_ALL": "C",
           # Como dentro de Hyprland: restart_shell() de config-set tiene que respetar el interruptor
           "HYPRLAND_INSTANCE_SIGNATURE": "test"}
    env.pop("THEMES_NO_RELOAD", None)
    if not reload:
        env["THEMES_NO_RELOAD"] = "1"
    r = subprocess.run([sys.executable, str(home / ".config/themes" / script), *args],
                       env=env, capture_output=True, text=True)
    if check:
        assert r.returncode == 0, r.stderr
    return r


def read(home, path):
    return (home / path).read_text()


def profile(home):
    return read(home, ".local/state/desktop-profile").strip()


# ── theme-set ────────────────────────────────────────────────

def hypr(c):
    h = c.lstrip("#")
    return f"rgba({h if len(h) == 8 else h + 'ff'})"


def test_theme_set(home, theme):
    name, t = theme
    ui, term, gtk = t["ui"], t["term"], t["gtk"]
    # Cada archivo generado con algún color del tema que debe llevar
    files = {
        ".config/hypr/config/theme.lua": [hypr(ui["bg"]), hypr(ui["fg"]), hypr(ui["accent"])],
        ".config/hypr/hyprlock-colors.conf": [
            "rgba({}, {}, {}, 0.75)".format(*(int(term["background"][i:i + 2], 16) for i in (1, 3, 5)))],
        ".config/kitty/themes/current.conf": [term["background"], term["foreground"], *term["colors"]],
        ".config/ghostty/themes/current": [term["background"], *(f"{i}={c}" for i, c in enumerate(term["colors"]))],
        ".config/btop/themes/current.theme": [f'theme[main_bg]="{term["background"]}"'],
        ".config/themes/current-env.sh": [f"fg:{term['foreground']}", f"hl:{ui['accent']}"],
        ".config/gtk-3.0/gtk.css": [f"@define-color window_bg_color {gtk['window']};"],
        ".config/gtk-4.0/gtk.css": [f"--window-bg-color: {gtk['window']};"],
        ".config/qt6ct/colors/current.conf": [gtk["card"], gtk["fg"]],
        ".local/share/color-schemes/Theme.colors": ["[Colors:Window]"],
    }
    # Se borran antes: el repo ya trae los de un tema
    for f in files:
        (home / f).unlink(missing_ok=True)
    shutil.rmtree(home / ".config/fastfetch/themed")

    run(home, "theme-set", name)

    assert os.readlink(home / ".config/themes/current") == name
    for f, colors in files.items():
        text = read(home, f)
        assert f"Generado por theme-set a partir de themes/{name}/theme.json" in text.splitlines()[0], f
        for c in colors:
            assert c in text, f"{f}: falta {c}"
    assert "[Colors:Window]" in read(home, ".config/kdeglobals")
    pepes = sorted(p.name for p in (home / ".config/fastfetch").glob("pepe-*.txt"))
    assert pepes and sorted(p.name for p in (home / ".config/fastfetch/themed").iterdir()) == pepes


def test_theme_set_list(home):
    run(home, "theme-set", DARK[0])
    rows = [json.loads(l) for l in run(home, "theme-set", "--list").stdout.splitlines()]
    assert [r["dir"] for r in rows] == THEMES
    assert [r["dir"] for r in rows if r["cur"]] == [DARK[0]]
    assert sorted(r["dir"] for r in rows if r["light"]) == LIGHT
    assert run(home, "theme-set").stdout.splitlines()[THEMES.index(DARK[0])] == f"* {DARK[0]}"


def test_theme_set_unknown(home):
    r = run(home, "theme-set", "no-existe", check=False)
    assert r.returncode != 0 and "no-existe" in r.stderr


def test_theme_set_reapply(home):
    # El flujo de la cabecera: se cambia el theme.json y --reapply lo regenera
    name = DARK[0]
    run(home, "theme-set", name)
    path = home / ".config/themes" / name / "theme.json"
    t = json.loads(path.read_text())
    t["ui"]["bg"] = "#123456"
    path.write_text(json.dumps(t))
    run(home, "theme-set", "--reapply")
    assert 'THEME_BG       = "rgba(123456ff)"' in read(home, ".config/hypr/config/theme.lua")
    assert os.readlink(home / ".config/themes/current") == name


def test_sin_interruptor_avisa(home):
    # Comprueba que los stubs detectan las llamadas: sin THEMES_NO_RELOAD, theme-set
    # avisa a Quickshell, Hyprland, terminales, Neovim, GTK y notificaciones
    run(home, "theme-set", DARK[0], reload=True)
    assert {"qs", "hyprctl", "pkill", "nvim", "gsettings", "notify-send"} <= calls(home)
    (home / "calls.log").unlink()


# ── config-set ───────────────────────────────────────────────

def qt6ct(home):
    return read(home, ".config/qt6ct/qt6ct.conf")


def test_config_set_mac_dark(home):
    run(home, "theme-set", DARK[0])
    run(home, "config-set", "mac")
    assert profile(home) == "mac"
    assert "style=Breeze" in qt6ct(home) and "icon_theme=Sur-Transparente" in qt6ct(home)
    assert "gtk-application-prefer-dark-theme=1" in read(home, ".config/gtk-3.0/settings.ini")
    assert "Theme=Sur-Transparente" in read(home, ".config/kdeglobals")
    assert run(home, "config-set", "--list").stdout == "mac\tMac mode\t1\ndefault\tNormal mode\t0\n"


def test_config_set_mac_light(home):
    # Con un tema claro, "mac" se guarda como mac-light, con su gtk.css claro fijo;
    # al volver a un tema oscuro, theme-set lo pasa a mac con el gtk.css del tema
    run(home, "theme-set", LIGHT[0])
    run(home, "config-set", "mac")
    assert profile(home) == "mac-light"
    assert "icon_theme=Sur" in qt6ct(home) and "mac-light.conf" in qt6ct(home)
    assert read(home, ".config/gtk-4.0/gtk.css").startswith("/* Generado por config-set (perfil mac-light)")
    assert "gtk-application-prefer-dark-theme=0" in read(home, ".config/gtk-4.0/settings.ini")

    run(home, "theme-set", DARK[0])
    assert profile(home) == "mac"
    assert f"themes/{DARK[0]}/theme.json" in read(home, ".config/gtk-4.0/gtk.css")


def test_config_set_default(home):
    run(home, "theme-set", DARK[0])
    run(home, "config-set", "mac")
    run(home, "config-set", "normal")
    assert profile(home) == "default"
    assert "style=Fusion" in qt6ct(home) and "colors/current.conf" in qt6ct(home)
    assert "[Fonts]" not in qt6ct(home)
    assert "icon_theme=Papirus-Dark" in qt6ct(home)
    # Modo normal con un tema claro: GTK e iconos claros
    run(home, "theme-set", LIGHT[0])
    assert profile(home) == "default" and "icon_theme=Papirus-Light" in qt6ct(home)
    assert run(home, "config-set", "no-existe", check=False).returncode != 0


# ── font-set ─────────────────────────────────────────────────

def test_font_set(home):
    assert run(home, "font-set").stdout == "  Foo Nerd Font\n"  # sin Mono/Propo ni Bar Sans
    run(home, "font-set", "Foo Nerd Font")
    assert read(home, ".local/state/font") == "Foo Nerd Font\n"
    assert "font_family Foo Nerd Font\n" in read(home, ".config/kitty/font.conf")
    assert "font-family = Foo Nerd Font\n" in read(home, ".config/ghostty/font.ghostty")
    assert read(home, ".config/hypr/font.conf").endswith("\nFoo Nerd Font Propo\n")
    assert json.loads(run(home, "font-set", "--list").stdout) == {"font": "Foo Nerd Font", "cur": True}
    assert run(home, "font-set", "Bar Sans", check=False).returncode != 0


# ── contrast-set ─────────────────────────────────────────────

def test_contrast_set(home):
    state = ".local/state/increased-contrast"
    assert run(home, "contrast-set").stdout == "off\n"  # sin archivo de estado
    run(home, "contrast-set", "on")
    assert read(home, state) == "1\n" and run(home, "contrast-set").stdout == "on\n"
    run(home, "contrast-set", "toggle")
    assert read(home, state) == "0\n" and run(home, "contrast-set").stdout == "off\n"
    run(home, "contrast-set", "toggle")
    assert read(home, state) == "1\n"
    run(home, "contrast-set", "off")
    assert read(home, state) == "0\n"
    assert run(home, "contrast-set", "no-existe", check=False).returncode != 0
    # Sin el interruptor: alto contraste de GTK, hyprctl reload y aviso
    run(home, "contrast-set", "on", reload=True)
    assert calls(home) == {"gsettings", "hyprctl", "notify-send"}
    (home / "calls.log").unlink()


# ── background-set ───────────────────────────────────────────

def test_background_set(home):
    name = DARK[0]
    run(home, "theme-set", name)
    d = home / ".config/themes" / name / "backgrounds"
    d.mkdir()
    for f in ("b.png", "a.jpg", "notas.txt"):
        (d / f).touch()
    pepes = f"{home}/.config/backgrounds/wallpaper-desktop.jpg"

    def listing():
        return [l.split("\t") for l in run(home, "background-set").stdout.splitlines()]

    # Los del tema por orden y los Pepes al final; sin elegir, el primero
    assert listing() == [["a.jpg", f"{d}/a.jpg", "1"], ["b.png", f"{d}/b.png", "0"], ["pepes", pepes, "0"]]
    run(home, "background-set", "pepes")
    assert run(home, "background-set", "--path").stdout == pepes + "\n"
    assert json.loads(read(home, ".local/state/theme-backgrounds")) == {name: "pepes"}
    run(home, "background-set", "--next")  # vuelve al principio
    assert run(home, "background-set", "--path").stdout == f"{d}/a.jpg\n"
    run(home, "background-set", "--next")
    assert [r[0] for r in listing() if r[2] == "1"] == ["b.png"]
    assert run(home, "background-set", "notas.txt", check=False).returncode != 0
