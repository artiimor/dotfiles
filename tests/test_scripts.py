# Tests for the bin/ scripts (wasdjy-theme, wasdjy-config, wasdjy-font, wasdjy-background,
# wasdjy-contrast; wasdjy-migrate and wasdjy-update at the end, with their own repo).
# Each test copies the repo's .config to a temporary HOME and runs the scripts there with
# THEMES_NO_RELOAD=1. Some stubs go first in PATH (qs, hyprctl, gsettings...) that only
# record their call: at the end of each test
# it checks that nothing outside was notified. If the switch failed,
# the stubs also avoid touching the user's desktop.
import json
import os
import re
import shutil
import subprocess
import sys

import pytest

from conftest import BIN, CONFIG, LIB, REPO, THEMES, load_theme

# Programs with effects outside the files (and fc-list, which only reads)
STUBS = ("qs", "hyprctl", "gsettings", "notify-send", "nvim", "ghostty", "pkill",
         "fc-list")
# What the fake fc-list returns to wasdjy-font: "family\tspacing"
FONTS = "Foo Nerd Font\t100\nFoo Nerd Font Propo\t0\nFoo Nerd Font Mono\t100\nBar Sans\t0\n"

LIGHT = sorted(n for n in THEMES if load_theme(n).get("light"))
DARK = sorted(n for n in THEMES if not load_theme(n).get("light"))


@pytest.fixture
def home(tmp_path):
    shutil.copytree(CONFIG, tmp_path / ".config", symlinks=True)
    state = tmp_path / ".local/state"
    state.mkdir(parents=True)
    # With a saved profile: otherwise the first wasdjy-theme switches to Mac Mode
    (state / "desktop-profile").write_text("default\n")
    # An "open Neovim": without the switch, wasdjy-theme would send it the new theme
    (tmp_path / "run").mkdir()
    (tmp_path / "run/nvim.1.0").touch()
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    for name in STUBS:
        out = f"printf '{FONTS}'\n" if name == "fc-list" else ""
        # One line per call (arguments may contain line breaks)
        log = f'"{tmp_path}/calls.log"'
        (stubs / name).write_text(f'#!/bin/sh\necho "{name} $*" | tr "\\n" " " >> {log}\n'
                                  f'echo >> {log}\n{out}')
        (stubs / name).chmod(0o755)
    yield tmp_path
    log = tmp_path / "calls.log"
    assert calls(tmp_path) <= {"fc-list"}, "llamadas de fuera:\n" + log.read_text()


def calls(home):
    # Programs called by the scripts (first word of each line)
    log = home / "calls.log"
    return {l.split()[0] for l in log.read_text().splitlines()} if log.exists() else set()


def run(home, script, *args, check=True, reload=False):
    env = {**os.environ, "HOME": str(home), "PATH": f"{home}/stubs:{os.environ['PATH']}",
           "XDG_RUNTIME_DIR": str(home / "run"), "LC_ALL": "C",
           # As inside Hyprland: wasdjy-config's restart_shell() must respect the switch
           "HYPRLAND_INSTANCE_SIGNATURE": "test"}
    env.pop("THEMES_NO_RELOAD", None)
    if not reload:
        env["THEMES_NO_RELOAD"] = "1"
    r = subprocess.run([sys.executable, str(BIN / script), *args],
                       env=env, capture_output=True, text=True)
    if check:
        assert r.returncode == 0, r.stderr
    return r


def read(home, path):
    return (home / path).read_text()


def profile(home):
    return read(home, ".local/state/desktop-profile").strip()


# ── wasdjy-theme ────────────────────────────────────────────────

def hypr(c):
    h = c.lstrip("#")
    return f"rgba({h if len(h) == 8 else h + 'ff'})"


def test_theme_set(home, theme):
    name, t = theme
    ui, term, gtk = t["ui"], t["term"], t["gtk"]
    # Each generated file with some theme color it must contain
    files = {
        ".config/hypr/config/theme.lua": [hypr(ui["bg"]), hypr(ui["fg"]), hypr(ui["accent"])],
        ".config/hypr/hyprlock-colors.conf": [
            "rgba({}, {}, {}, 0.75)".format(*(int(term["background"][i:i + 2], 16) for i in (1, 3, 5)))],
        ".config/ghostty/themes/current": [term["background"], term["foreground"], *(f"{i}={c}" for i, c in enumerate(term["colors"]))],
        ".config/btop/themes/current.theme": [f'theme[main_bg]="{term["background"]}"'],
        ".config/themes/current-env.sh": [f"fg:{term['foreground']}", f"hl:{ui['accent']}"],
        ".config/gtk-3.0/gtk.css": [f"@define-color window_bg_color {gtk['window']};"],
        ".config/gtk-4.0/gtk.css": [f"--window-bg-color: {gtk['window']};"],
        ".config/qt6ct/colors/current.conf": [gtk["card"], gtk["fg"]],
        ".local/share/color-schemes/Theme.colors": ["[Colors:Window]"],
    }
    # Deleted first: the repo already ships one theme's files
    for f in files:
        (home / f).unlink(missing_ok=True)
    shutil.rmtree(home / ".config/fastfetch/themed")

    run(home, "wasdjy-theme", name)

    assert os.readlink(home / ".config/themes/current") == name
    for f, colors in files.items():
        text = read(home, f)
        assert f"Generado por wasdjy-theme a partir de themes/{name}/theme.json" in text.splitlines()[0], f
        for c in colors:
            assert c in text, f"{f}: falta {c}"
    assert "[Colors:Window]" in read(home, ".config/kdeglobals")
    pepes = sorted(p.name for p in (home / ".config/fastfetch").glob("pepe-*.txt"))
    assert pepes and sorted(p.name for p in (home / ".config/fastfetch/themed").iterdir()) == pepes
    # fastfetch uses the tinted logo
    assert '"source": "~/.config/fastfetch/themed/pepe-' in read(home, ".config/fastfetch/config.jsonc")


def test_theme_set_list(home):
    run(home, "wasdjy-theme", DARK[0])
    rows = [json.loads(l) for l in run(home, "wasdjy-theme", "--list").stdout.splitlines()]
    assert [r["dir"] for r in rows] == THEMES
    assert [r["dir"] for r in rows if r["cur"]] == [DARK[0]]
    assert sorted(r["dir"] for r in rows if r["light"]) == LIGHT
    assert run(home, "wasdjy-theme").stdout.splitlines()[THEMES.index(DARK[0])] == f"* {DARK[0]}"


def test_theme_set_unknown(home):
    r = run(home, "wasdjy-theme", "no-existe", check=False)
    assert r.returncode != 0 and "no-existe" in r.stderr


def test_theme_set_reapply(home):
    # The header's workflow: theme.json is changed and --reapply regenerates it
    name = DARK[0]
    run(home, "wasdjy-theme", name)
    path = home / ".config/themes" / name / "theme.json"
    t = json.loads(path.read_text())
    t["ui"]["bg"] = "#123456"
    path.write_text(json.dumps(t))
    run(home, "wasdjy-theme", "--reapply")
    assert 'THEME_BG       = "rgba(123456ff)"' in read(home, ".config/hypr/config/theme.lua")
    assert os.readlink(home / ".config/themes/current") == name


def test_sin_interruptor_avisa(home):
    # Checks that the stubs detect the calls: without THEMES_NO_RELOAD, wasdjy-theme
    # notifies Quickshell, Hyprland, terminals, Neovim, GTK and notifications
    run(home, "wasdjy-theme", DARK[0], reload=True)
    assert {"qs", "hyprctl", "pkill", "nvim", "gsettings", "notify-send"} <= calls(home)
    (home / "calls.log").unlink()


# ── wasdjy-config ───────────────────────────────────────────────

def qt6ct(home):
    return read(home, ".config/qt6ct/qt6ct.conf")


def test_config_set_mac_dark(home):
    run(home, "wasdjy-theme", DARK[0])
    run(home, "wasdjy-config", "mac")
    assert profile(home) == "mac"
    assert "style=Breeze" in qt6ct(home) and "icon_theme=Sur-Transparente" in qt6ct(home)
    assert "gtk-application-prefer-dark-theme=1" in read(home, ".config/gtk-3.0/settings.ini")
    assert "Theme=Sur-Transparente" in read(home, ".config/kdeglobals")
    assert run(home, "wasdjy-config", "--list").stdout == "mac\tMac mode\t1\ndefault\tNormal mode\t0\n"


def test_config_set_mac_light(home):
    # With a light theme, "mac" is saved as mac-light, with its fixed light gtk.css;
    # going back to a dark theme, wasdjy-theme switches it to mac with the theme's gtk.css
    run(home, "wasdjy-theme", LIGHT[0])
    run(home, "wasdjy-config", "mac")
    assert profile(home) == "mac-light"
    assert "icon_theme=Sur" in qt6ct(home) and "mac-light.conf" in qt6ct(home)
    assert read(home, ".config/gtk-4.0/gtk.css").startswith("/* Generado por wasdjy-config (perfil mac-light)")
    assert "gtk-application-prefer-dark-theme=0" in read(home, ".config/gtk-4.0/settings.ini")

    run(home, "wasdjy-theme", DARK[0])
    assert profile(home) == "mac"
    assert f"themes/{DARK[0]}/theme.json" in read(home, ".config/gtk-4.0/gtk.css")


def test_mac_light_sin_reiniciar(home):
    # Between mac and mac-light Quickshell isn't restarted (macshell's Appearance window
    # would stay open): only wasdjy-theme's normal reload
    run(home, "wasdjy-theme", DARK[0])
    run(home, "wasdjy-config", "mac")
    run(home, "wasdjy-theme", LIGHT[0], reload=True)
    assert profile(home) == "mac-light"
    log = read(home, "calls.log")
    assert "qs ipc call theme reload" in log and "hyprctl reload" in log
    assert "qs kill" not in log and "qs list" not in log and "hyprctl dispatch" not in log
    (home / "calls.log").unlink()


def test_cambio_de_perfil_reinicia(home):
    # On a real profile change Quickshell is restarted from Hyprland (with
    # macshell in Mac Mode). The fake qs lists no instances, so there's no qs kill.
    run(home, "wasdjy-theme", DARK[0])
    run(home, "wasdjy-config", "mac")
    run(home, "wasdjy-config", "default", reload=True)
    assert profile(home) == "default"
    log = read(home, "calls.log")
    assert "hyprctl reload" in log and "hyprctl dispatch hl.dsp.exec_cmd('qs')" in log
    assert "macshell')" not in log
    (home / "calls.log").unlink()

    run(home, "wasdjy-config", "mac", reload=True)
    assert profile(home) == "mac"
    log = read(home, "calls.log")
    assert "hyprctl reload" in log and "hyprctl dispatch hl.dsp.exec_cmd('qs')" in log
    assert f"hyprctl dispatch hl.dsp.exec_cmd('qs -p {home}/.config/quickshell/macshell')" in log
    (home / "calls.log").unlink()


def test_config_set_default(home):
    run(home, "wasdjy-theme", DARK[0])
    run(home, "wasdjy-config", "mac")
    run(home, "wasdjy-config", "normal")
    assert profile(home) == "default"
    assert "style=Fusion" in qt6ct(home) and "colors/current.conf" in qt6ct(home)
    assert "[Fonts]" not in qt6ct(home)
    assert "icon_theme=Papirus-Dark" in qt6ct(home)
    # Normal Mode with a light theme: light GTK and icons
    run(home, "wasdjy-theme", LIGHT[0])
    assert profile(home) == "default" and "icon_theme=Papirus-Light" in qt6ct(home)
    assert run(home, "wasdjy-config", "no-existe", check=False).returncode != 0


# ── wasdjy-font ─────────────────────────────────────────────────

def test_font_set(home):
    assert run(home, "wasdjy-font").stdout == "  Foo Nerd Font\n"  # no Mono/Propo or Bar Sans
    run(home, "wasdjy-font", "Foo Nerd Font")
    assert read(home, ".local/state/font") == "Foo Nerd Font\n"
    assert "font-family = Foo Nerd Font\n" in read(home, ".config/ghostty/font.ghostty")
    assert read(home, ".config/hypr/font.conf").endswith("\nFoo Nerd Font Propo\n")
    assert json.loads(run(home, "wasdjy-font", "--list").stdout) == {"font": "Foo Nerd Font", "cur": True}
    assert run(home, "wasdjy-font", "Bar Sans", check=False).returncode != 0


# ── wasdjy-contrast ─────────────────────────────────────────────

def test_contrast_set(home):
    state = ".local/state/increased-contrast"
    assert run(home, "wasdjy-contrast").stdout == "off\n"  # no state file
    run(home, "wasdjy-contrast", "on")
    assert read(home, state) == "1\n" and run(home, "wasdjy-contrast").stdout == "on\n"
    run(home, "wasdjy-contrast", "toggle")
    assert read(home, state) == "0\n" and run(home, "wasdjy-contrast").stdout == "off\n"
    run(home, "wasdjy-contrast", "toggle")
    assert read(home, state) == "1\n"
    run(home, "wasdjy-contrast", "off")
    assert read(home, state) == "0\n"
    assert run(home, "wasdjy-contrast", "no-existe", check=False).returncode != 0
    # Without the switch: GTK high contrast, terminals, Neovim, hyprctl reload and notice
    run(home, "wasdjy-contrast", "on", reload=True)
    assert calls(home) == {"gsettings", "pkill", "nvim", "hyprctl", "notify-send"}
    (home / "calls.log").unlink()


@pytest.mark.parametrize("theme", ["grafito", "terminal-clasico"])
def test_contrast_terminals(home, theme):
    # With the mode on, terminals get more contrast and Neovim has its own theme;
    # when it's removed, everything goes back to the theme.json values
    term, nv = ".config/ghostty/themes/current", home / ".local/state/increased-contrast.json"
    run(home, "wasdjy-theme", theme)
    before = read(home, term)
    run(home, "wasdjy-contrast", "on")
    boosted = json.loads(nv.read_text())
    assert boosted["term"]["background"] in read(home, term)
    run(home, "wasdjy-theme", "--reapply")  # changing theme with the mode on keeps it
    assert boosted["term"]["background"] in read(home, term)
    run(home, "wasdjy-contrast", "off")
    assert read(home, term) == before and not nv.exists()


# ── wasdjy-background ───────────────────────────────────────────

def test_background_set(home):
    name = DARK[0]
    run(home, "wasdjy-theme", name)
    d = home / ".config/themes" / name / "backgrounds"
    d.mkdir()
    for f in ("b.png", "a.jpg", "notas.txt"):
        (d / f).touch()
    pepes = f"{home}/.config/backgrounds/wallpaper-desktop.jpg"

    def listing():
        return [l.split("\t") for l in run(home, "wasdjy-background").stdout.splitlines()]

    # The theme's ones in order and the Pepes last; with no choice, the first one
    assert listing() == [["a.jpg", f"{d}/a.jpg", "1"], ["b.png", f"{d}/b.png", "0"], ["pepes", pepes, "0"]]
    run(home, "wasdjy-background", "pepes")
    assert run(home, "wasdjy-background", "--path").stdout == pepes + "\n"
    assert json.loads(read(home, ".local/state/theme-backgrounds")) == {name: "pepes"}
    run(home, "wasdjy-background", "--next")  # wraps back to the start
    assert run(home, "wasdjy-background", "--path").stdout == f"{d}/a.jpg\n"
    run(home, "wasdjy-background", "--next")
    assert [r[0] for r in listing() if r[2] == "1"] == ["b.png"]
    assert run(home, "wasdjy-background", "notas.txt", check=False).returncode != 0


def test_background_set_light_pepes(home):
    # Light themes get the daytime meadow as "pepes"
    run(home, "wasdjy-theme", LIGHT[0])
    day = f"{home}/.config/backgrounds/wallpaper-desktop-day.jpg"
    assert run(home, "wasdjy-background", "--path").stdout == day + "\n"


# ── wasdjy layout: bin/, old names, references ───────────────

OLD_NAMES = {"theme-set": "wasdjy-theme", "config-set": "wasdjy-config",
             "background-set": "wasdjy-background", "font-set": "wasdjy-font",
             "contrast-set": "wasdjy-contrast"}


def test_bin_ejecutables():
    # The scripts are in bin/ and executable (Quickshell, Hyprland and install.sh run them directly)
    for new in [*OLD_NAMES.values(), "wasdjy-migrate", "wasdjy-update"]:
        assert os.access(BIN / new, os.X_OK), new


def test_nombres_viejos(home):
    # install.sh leaves ~/.config/themes/<old> as a symlink to bin/: through the link
    # the script still finds lib/ and the other scripts (realpath, not the link's folder)
    for old, new in OLD_NAMES.items():
        (home / ".config/themes" / old).symlink_to(BIN / new)
    env = {**os.environ, "HOME": str(home), "PATH": f"{home}/stubs:{os.environ['PATH']}",
           "XDG_RUNTIME_DIR": str(home / "run"), "LC_ALL": "C", "THEMES_NO_RELOAD": "1"}
    old = subprocess.run([str(home / ".config/themes/theme-set"), "--list"],
                         env=env, capture_output=True, text=True)
    assert old.returncode == 0, old.stderr
    assert old.stdout == run(home, "wasdjy-theme", "--list").stdout
    # theme-set → config-set's sync_theme() through load_script
    r = subprocess.run([str(home / ".config/themes/theme-set"), DARK[0]], env=env,
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_sin_rutas_viejas():
    # Hyprland, Quickshell and the scripts call bin/wasdjy-*, never the old
    # ~/.config/themes/*-set (only kept as temporary symlinks by install.sh)
    old = re.compile(r'themes/(theme|config|background|font|contrast)-set|themes/themelib|"/\.config/themes"')
    bad = []
    for root in (CONFIG / "hypr", CONFIG / "quickshell", BIN, REPO / "lib"):
        for f in root.rglob("*"):
            if f.is_file() and f.suffix not in (".png", ".jpg", ".svg", ".so"):
                for i, line in enumerate(f.read_text(errors="ignore").splitlines(), 1):
                    if old.search(line):
                        bad.append(f"{f.relative_to(REPO)}:{i}: {line.strip()}")
    assert not bad, "\n".join(bad)


# ── wasdjy-migrate and wasdjy-update (bash) ─────────────

def bash_env(tmp_path, **extra):
    return {**os.environ, "HOME": str(tmp_path / "home"), "LC_ALL": "C", **extra}


@pytest.fixture
def migrations(tmp_path):
    # A repo of its own (bin/, lib/ and migrations/) and a temporary HOME. Each migration
    # appends its name to ran.log; "b" fails if fail.flag exists
    repo = tmp_path / "repo"
    shutil.copytree(BIN, repo / "bin")
    shutil.copytree(LIB, repo / "lib")
    (repo / "migrations").mkdir()
    (tmp_path / "home").mkdir()
    for name in ("20260101-a.sh", "20260102-b.sh", "20260103-c.sh"):
        fail = f'[ ! -e "{tmp_path}/fail.flag" ] || exit 3\n' if name.endswith("b.sh") else ""
        (repo / "migrations" / name).write_text(
            f'echo "{name} $REPO" >> "{tmp_path}/ran.log"\n{fail}')
    return tmp_path


def migrate(tmp, *args):
    return subprocess.run([str(tmp / "repo/bin/wasdjy-migrate"), *args], env=bash_env(tmp),
                          capture_output=True, text=True)


def ran(tmp):
    log = tmp / "ran.log"
    return [l.split()[0] for l in log.read_text().splitlines()] if log.exists() else []


def applied(tmp):
    return (tmp / "home/.local/state/wasdjy/migrations").read_text().splitlines()


ALL = ["20260101-a.sh", "20260102-b.sh", "20260103-c.sh"]


def test_migrate_en_orden(migrations):
    # The pending ones run in order, with REPO, and the ones already done aren't repeated
    r = migrate(migrations)
    assert r.returncode == 0, r.stdout + r.stderr
    assert ran(migrations) == ALL
    assert applied(migrations) == ALL
    assert f" {migrations / 'repo'}" in (migrations / "ran.log").read_text()
    (migrations / "repo/migrations/20260104-d.sh").write_text(f'echo d >> "{migrations}/ran.log"\n')
    assert migrate(migrations).returncode == 0
    assert ran(migrations) == [*ALL, "d"]
    assert applied(migrations) == [*ALL, "20260104-d.sh"]


def test_migrate_falla(migrations):
    # The one that fails stops the run, isn't marked and the next ones don't run;
    # once fixed, it's retried
    (migrations / "fail.flag").touch()
    r = migrate(migrations)
    assert r.returncode != 0
    assert "20260102-b.sh failed" in r.stdout
    assert ran(migrations) == ALL[:2]
    assert applied(migrations) == ALL[:1]
    (migrations / "fail.flag").unlink()
    assert migrate(migrations).returncode == 0
    assert ran(migrations) == [*ALL[:2], *ALL[1:]]
    assert applied(migrations) == ALL


def test_migrate_mark_all(migrations):
    # Fresh install: all marked, none run (and not repeated afterwards). --pending only checks
    assert migrate(migrations, "--pending").returncode == 0
    assert migrate(migrations, "--mark-all").returncode == 0
    assert migrate(migrations, "--pending").returncode == 1
    assert applied(migrations) == ALL
    assert migrate(migrations).returncode == 0
    assert ran(migrations) == []
    assert migrate(migrations, "--bad").returncode == 2


@pytest.fixture
def update_repo(tmp_path):
    # A bare remote and a clone with bin/, lib/ and an install.sh stub that records its
    # call; stubs for sudo (records it) and the rest of the outside programs
    git_env = bash_env(tmp_path, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                       GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t",
                       GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
    git = lambda cwd, *a: subprocess.run(["git", *a], cwd=cwd, env=git_env, check=True,
                                         capture_output=True)
    (tmp_path / "home").mkdir()
    src = tmp_path / "src"
    shutil.copytree(BIN, src / "bin")
    shutil.copytree(LIB, src / "lib")
    (src / "install.sh").write_text(f'#!/bin/sh\necho "install.sh $*" >> "{tmp_path}/calls.log"\n')
    (src / "install.sh").chmod(0o755)
    git(tmp_path, "init", "-q", "--bare", "-b", "main", "remote.git")
    git(src, "init", "-q", "-b", "main")
    git(src, "add", ".")
    git(src, "commit", "-qm", "First")
    git(src, "remote", "add", "origin", str(tmp_path / "remote.git"))
    git(src, "push", "-q", "-u", "origin", "main")
    git(tmp_path, "clone", "-q", str(tmp_path / "remote.git"), "repo")
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    for name in ("sudo", "pacman", "hyprctl", "qs"):
        (stubs / name).write_text(f'#!/bin/sh\necho "{name} $*" >> "{tmp_path}/calls.log"\n')
        (stubs / name).chmod(0o755)
    env = {**git_env, "PATH": f"{stubs}:{os.environ['PATH']}"}
    return tmp_path, src, git, env


def test_update(update_repo):
    tmp, src, git, env = update_repo
    update = [str(tmp / "repo/bin/wasdjy-update"), "--yes"]
    # Nothing new: no install.sh, but pacman -Syu without asking
    r = subprocess.run(update, env=env, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "Already up to date." in r.stdout
    assert (tmp / "calls.log").read_text().splitlines() == ["sudo pacman -Syu --noconfirm"]
    # A new commit upstream: pull, its log and install.sh --update
    (src / "new.txt").write_text("x\n")
    git(src, "add", ".")
    git(src, "commit", "-qm", "Second commit")
    git(src, "push", "-q")
    (tmp / "calls.log").unlink()
    r = subprocess.run(update, env=env, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "Second commit" in r.stdout and "First" not in r.stdout
    assert (tmp / "repo/new.txt").exists()
    assert (tmp / "calls.log").read_text().splitlines() == [
        "sudo pacman -Syu --noconfirm", "install.sh --update"]
    # Nothing new but a migration still pending (it failed last time): install.sh --update again
    (tmp / "repo/migrations").mkdir()
    (tmp / "repo/migrations/20260101-a.sh").write_text("true\n")
    (tmp / "calls.log").unlink()
    r = subprocess.run(update, env=env, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "Already up to date." in r.stdout
    assert (tmp / "calls.log").read_text().splitlines() == [
        "sudo pacman -Syu --noconfirm", "install.sh --update"]
    # A pull that isn't fast-forward: warns and stops before pacman
    (tmp / "repo/new.txt").write_text("local\n")
    git(tmp / "repo", "commit", "-qam", "Local")
    (src / "new.txt").write_text("remote\n")
    git(src, "commit", "-qam", "Remote")
    git(src, "push", "-q")
    (tmp / "calls.log").unlink()
    r = subprocess.run(update, env=env, capture_output=True, text=True)
    assert r.returncode != 0
    assert "git pull failed" in r.stdout
    assert not (tmp / "calls.log").exists()
