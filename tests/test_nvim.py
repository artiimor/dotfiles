# Colorscheme "tema" de Neovim: por cada tema, nvim sin config del usuario carga
# .config/nvim/colors/tema.lua con TEMA_THEME_JSON=<tema> y los grupos llevan los colores
# del theme.json. Necesita mini.nvim (mini.hues): MINI_PATH (CI) o la copia de vim.pack.
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

from conftest import CONFIG, SYN_GROUPS, THEMES_DIR

NVIM = shutil.which("nvim")
MINI = next(
    (p for p in (os.environ.get("MINI_PATH"), "~/.local/share/nvim/site/pack/core/opt/mini.nvim")
     if p and (Path(p).expanduser() / "lua/mini/hues.lua").is_file()),
    None,
)

pytestmark = [
    pytest.mark.skipif(not NVIM, reason="nvim no está instalado"),
    pytest.mark.skipif(not MINI, reason="falta mini.nvim: define MINI_PATH con un checkout de nvim-mini/mini.nvim"),
]

# Carga el colorscheme y vuelca los grupos y los errores a JSON (arg[1])
SCRIPT = """
vim.opt.rtp:prepend(vim.env.MINI_DIR)
vim.opt.rtp:prepend(vim.env.NVIM_DIR)
local ok, err = pcall(vim.cmd.colorscheme, "tema")
local hl = {}
for name, spec in pairs(vim.api.nvim_get_hl(0, {})) do
  hl[name] = { fg = spec.fg, bg = spec.bg, italic = spec.italic }
end
local f = assert(io.open(_G.arg[1], "w"))
f:write(vim.json.encode({
  error = not ok and tostring(err) or vim.v.errmsg,
  messages = vim.fn.execute("messages"),
  colors_name = vim.g.colors_name,
  hl = hl,
}))
f:close()
"""

def run_nvim(name, tmp_path):
    out = tmp_path / "hl.json"
    script = tmp_path / "dump.lua"
    script.write_text(SCRIPT)
    home = tmp_path / "home"
    env = {
        **os.environ,
        "HOME": str(home),
        "XDG_RUNTIME_DIR": str(tmp_path),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "TEMA_THEME_JSON": str(THEMES_DIR / name / "theme.json"),
        "NVIM_DIR": str(CONFIG / "nvim"),
        "MINI_DIR": str(Path(MINI).expanduser()),
    }
    r = subprocess.run([NVIM, "--clean", "-i", "NONE", "-l", str(script), str(out)],
                       env=env, capture_output=True, text=True, timeout=30)
    assert r.returncode == 0 and not r.stderr.strip(), r.stderr
    return json.loads(out.read_text())


def hexcolor(n):
    return None if n is None else f"#{n:06x}"


def expected(t):
    # {(grupo, atributo): color} que tema.lua saca directamente del theme.json.
    # Solo lo que no depende de la paleta de mini.hues (los huecos se omiten).
    ui = t.get("ui", {})
    term = t.get("term", {})
    nc = t.get("nvimColors", {})
    o = nc.get("ui", {})
    exp = {(g, "fg"): nc.get("syn", {}).get(k) for k, g in SYN_GROUPS.items()}
    exp[("Normal", "fg")] = ui.get("fg")
    exp[("LineNr", "fg")] = o.get("linenr") or o.get("nontext") or ui.get("muted")
    exp[("NonText", "fg")] = o.get("nontext") or ui.get("muted")
    exp[("Whitespace", "fg")] = o.get("whitespace") or ui.get("accentDim")
    exp[("SpecialKey", "fg")] = o.get("special") or ui.get("muted")
    exp[("CursorLineNr", "fg")] = o.get("accent") or ui.get("accent")
    exp[("Visual", "bg")] = o.get("visual") or term.get("selection_background") or ui.get("launcherSel")
    exp[("DiagnosticError", "fg")] = o.get("red") or ui.get("red")
    exp[("DiagnosticWarn", "fg")] = o.get("yellow") or ui.get("yellow")
    return {k: v.lower() for k, v in exp.items() if v}


def test_colorscheme(theme, tmp_path):
    name, t = theme
    d = run_nvim(name, tmp_path)
    assert not d["error"], d["error"]
    assert not d["messages"].strip(), d["messages"]
    assert d["colors_name"] == "tema"
    hl = d["hl"]
    exp = expected(t)
    got = {k: hexcolor(hl.get(k[0], {}).get(k[1])) for k in exp}
    assert got == exp
    # fondo transparente y comentarios en cursiva
    assert hl["Normal"].get("bg") is None
    if "comment" in t.get("nvimColors", {}).get("syn", {}):
        assert hl["Comment"].get("italic")
