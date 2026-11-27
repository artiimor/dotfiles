# Idiomas: los i18n/*.json son JSON plano inglés → traducción, con los mismos
# marcadores %N, y todo texto que se traduce en el código tiene su entrada en es.json.
import ast
import json
import re

import pytest

from conftest import CONFIG, REPO, THEMES_DIR

QS = CONFIG / "quickshell"
MAC = QS / "macshell"
I18N_DIRS = [QS / "i18n", MAC / "i18n", THEMES_DIR / "i18n"]
JSONS = sorted(p for d in I18N_DIRS for p in d.glob("*.json"))

# Literal entre comillas dobles, con escapes (\n, \")
STR = r'"((?:[^"\\\n]|\\.)*)"'


def rel(p):
    return str(p.relative_to(REPO))


def load(path):
    # Como json.load, pero falla con claves repetidas (json se queda con la última)
    def pairs(items):
        keys = [k for k, _ in items]
        dup = {k for k in keys if keys.count(k) > 1}
        assert not dup, f"{rel(path)}: claves repetidas {sorted(dup)}"
        return dict(items)
    return json.loads(path.read_text(), object_pairs_hook=pairs)


def lines(path, comment):
    # El archivo sin las líneas de comentario (p. ej. los ejemplos de user.lua)
    return "\n".join(l for l in path.read_text().splitlines() if not l.lstrip().startswith(comment))


# ── Textos que se traducen en el código ──────────────────────

def qml_texts(root, skip=None):
    # Literales de I18n.tr("...") en los QML de root (sin la carpeta skip)
    return {json.loads(f'"{s}"') for f in root.rglob("*.qml") if not (skip and skip in f.parents)
            for s in re.findall(r"I18n\.tr\(" + STR, f.read_text())}


def bind_texts():
    # Descripciones de los binds de Hyprland (las traduce el Launcher de la raíz con I18n.tr):
    # los literales de "description = ..." y el último argumento de bindDigits(..., end, "X")
    # y resizeBind("H", -50, 0, "X"), que la pasan por la variable desc
    out = set()
    for f in (CONFIG / "hypr/config").glob("*.lua"):
        text = lines(f, "--")
        for expr in re.findall(r"description = ([^}\n]*)", text):
            out |= {json.loads(f'"{s}"') for s in re.findall(STR, expr)}
        out |= {json.loads(f'"{s}"') for s in re.findall(r"(?:end|\d), " + STR + r"\)\s*$", text, re.M)}
    return out


def python_texts():
    # tr("...") con un literal como primer argumento en los scripts de themes
    out = set()
    for name in ["theme-set", "config-set", "background-set", "font-set", "themelib.py"]:
        for node in ast.walk(ast.parse((THEMES_DIR / name).read_text())):
            if (isinstance(node, ast.Call) and getattr(node.func, "id", None) == "tr"
                    and node.args and isinstance(node.args[0], ast.Constant)):
                out.add(node.args[0].value)
    return out


def bash_texts():
    # t "Text %1" arg en install.sh y quickshell/scripts (t llama a themelib.py tr);
    # también $(t No) sin comillas. Los que llevan variables ($1...) se saltan
    out = set()
    for f in [REPO / "install.sh", *(QS / "scripts").iterdir()]:
        for s, word in re.findall(r"(?<![\w$-])t (?:" + STR + r"|(\w+)\))", lines(f, "#")):
            s = re.sub(r'\\(["\\$`])', r"\1", s) or word
            if "$" not in s:
                out.add(s)
    return out


CASES = {
    "quickshell": (QS / "i18n/es.json", qml_texts(QS, MAC) | bind_texts()),
    "macshell": (MAC / "i18n/es.json", qml_texts(MAC)),
    "themes": (THEMES_DIR / "i18n/es.json", python_texts() | bash_texts()),
}


# ── Tests ────────────────────────────────────────────────────

@pytest.mark.parametrize("path", JSONS, ids=rel)
def test_json_plano(path):
    d = load(path)
    bad = [k for k, v in d.items() if not isinstance(k, str) or not isinstance(v, str)]
    assert not bad, f"{rel(path)}: valores que no son texto {bad}"
    empty = [k for k, v in d.items() if not v.strip()]
    assert not empty, f"{rel(path)}: traducciones vacías {empty}"


@pytest.mark.parametrize("path", JSONS, ids=rel)
def test_marcadores(path):
    marks = lambda s: sorted(set(re.findall(r"%\d+", s)))
    bad = [k for k, v in load(path).items() if marks(k) != marks(v)]
    assert not bad, f"{rel(path)}: los %N no coinciden en {bad}"


def test_i18n_qml_identicos():
    assert (QS / "I18n.qml").read_text() == (MAC / "I18n.qml").read_text(), \
        "quickshell/I18n.qml y macshell/I18n.qml son distintos"


@pytest.mark.parametrize("case", CASES)
def test_textos_traducidos(case):
    path, texts = CASES[case]
    missing = sorted(texts - set(load(path)))
    assert not missing, f"{rel(path)}: faltan {missing}"


@pytest.mark.parametrize("case", CASES)
def test_sin_huerfanas(case):
    path, texts = CASES[case]
    orphans = sorted(set(load(path)) - texts)
    assert not orphans, f"{rel(path)}: entradas que no usa nadie {orphans}"
