# Validación de los theme.json: claves que leen theme-set, Quickshell (Theme.qml) y
# nvim/colors/tema.lua, formato de los colores y que cada tema salga en los README.
import re

from conftest import REPO, SYN_GROUPS, THEMES, THEMES_DIR, load_theme

# Claves obligatorias por sección (sacadas de los generadores de theme-set, Theme.qml
# y tema.lua; todos los temas las tienen). term.colors y hypr.border son listas
REQUIRED = {
    "ui": ["accent", "accent2", "accentDim", "bg", "border", "butter", "cyan", "fg",
           "launcherBg", "launcherSel", "mint", "muted", "ok", "peach", "pink", "red",
           "surface", "yellow"],
    "hypr": ["border", "inactive", "group"],
    "term": ["background", "foreground", "cursor", "selection_background",
             "selection_foreground", "colors"],
    "gtk": ["accent", "accentBg", "accentFg", "card", "fg", "headerbar", "view", "window"],
}
# #rrggbb en todas partes; #rrggbbaa solo en hypr.* (hypr() de theme-set la admite).
# En ui no: Quickshell leería #aarrggbb y rgb() de theme-set ignora el alfa
HEX = re.compile(r"#[0-9a-fA-F]{6}")
HEX_ALPHA = re.compile(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?")

README = (REPO / "README.md").read_text()
THEMES_README = (THEMES_DIR / "README.md").read_text()


def colors(t):
    # (ruta, valor) de cada color del tema: todo lo que no es name, nvim ni light
    def walk(v, path):
        if isinstance(v, dict):
            for k, x in v.items():
                yield from walk(x, f"{path}.{k}" if path else k)
        elif isinstance(v, list):
            for i, x in enumerate(v):
                yield from walk(x, f"{path}[{i}]")
        else:
            yield path, v
    return [(p, v) for p, v in walk(t, "") if p not in ("name", "nvim", "light")]


def test_claves(theme):
    name, t = theme
    missing = [f"{s}.{k}" for s, keys in REQUIRED.items() for k in keys if k not in t.get(s, {})]
    missing += [f"nvimColors.syn.{k}" for k in SYN_GROUPS if k not in t.get("nvimColors", {}).get("syn", {})]
    missing += [k for k in ("name", "nvim") if not isinstance(t.get(k), str) or not t[k]]
    assert not missing, f"{name}: faltan {missing}"


def test_listas(theme):
    name, t = theme
    assert len(t["term"]["colors"]) == 16, f"{name}: term.colors no tiene 16 colores"
    assert isinstance(t["hypr"]["border"], list) and t["hypr"]["border"], \
        f"{name}: hypr.border debe ser una lista con al menos un color"


def test_colores_hex(theme):
    name, t = theme
    bad = [f"{p}={v!r}" for p, v in colors(t)
           if not isinstance(v, str)
           or not (HEX_ALPHA if p.startswith("hypr.") else HEX).fullmatch(v)]
    assert not bad, f"{name}: colores no válidos {bad}"


def test_light_booleano(theme):
    name, t = theme
    assert isinstance(t.get("light", False), bool), f"{name}: light no es booleano"


def test_en_tabla_del_readme(theme):
    # Fila "| `carpeta` | Nombre ... | dark/**light** | colorscheme |" del README raíz
    name, t = theme
    row = re.search(rf"^\| `{re.escape(name)}` \| (.*?) \| (.*?) \| (.*?) \|$", README, re.M)
    assert row, f"{name}: no está en la tabla de temas de README.md"
    shown, kind, nvim = row.groups()
    assert shown.startswith(t["name"]), f"{name}: README dice «{shown}», theme.json «{t['name']}»"
    assert kind.strip("*") == ("light" if t.get("light") else "dark"), f"{name}: tipo «{kind}» en README.md"
    assert nvim == t["nvim"], f"{name}: README dice colorscheme «{nvim}», theme.json «{t['nvim']}»"


def test_lista_de_claros_del_readme_de_temas():
    # "`a`, `b` ... and `c` are light" en .config/themes/README.md
    line = re.search(r"^(.*) are light", THEMES_README, re.M)
    assert line, ".config/themes/README.md: falta la frase con los temas claros"
    listed = set(re.findall(r"`([\w-]+)`", line.group(1)))
    light = {n for n in THEMES if load_theme(n).get("light")}
    assert listed == light, f".config/themes/README.md: lista {sorted(listed)}, claros {sorted(light)}"


def test_cuentas_del_readme():
    # "18 color themes", "18 themes, 4 of them light"
    light = sum(bool(load_theme(n).get("light")) for n in THEMES)
    for n in re.findall(r"\b(\d+) (?:color )?themes\b", README):
        assert int(n) == len(THEMES), f"README.md dice {n} temas y hay {len(THEMES)}"
    for n in re.findall(r"\b(\d+) of them light\b", README):
        assert int(n) == light, f"README.md dice {n} claros y hay {light}"
