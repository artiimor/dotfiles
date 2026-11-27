# Fixtures comunes de los tests: rutas del repo y lista de temas.
import json
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
CONFIG = REPO / ".config"
THEMES_DIR = CONFIG / "themes"
# current es un symlink al tema activo: no es un tema más
THEMES = sorted(p.parent.name for p in THEMES_DIR.glob("*/theme.json") if not p.parent.is_symlink())

# Mismo mapeo que `groups` en nvim/colors/tema.lua: clave de nvimColors.syn -> grupos
SYN_GROUPS = {
    "string": "String", "number": "Number", "constant": "Constant", "identifier": "Identifier",
    "parameter": "@variable.parameter", "fun": "Function", "statement": "Statement",
    "keyword": "Keyword", "operator": "Operator", "preproc": "PreProc", "type": "Type",
    "regex": "@string.regexp", "punct": "Delimiter", "comment": "Comment",
    "special1": "Special", "special2": "SpecialChar", "special3": "@punctuation.special",
}


def load_theme(name):
    return json.loads((THEMES_DIR / name / "theme.json").read_text())


@pytest.fixture(params=THEMES)
def theme(request):
    # (nombre, contenido de theme.json) de cada tema
    return request.param, load_theme(request.param)
