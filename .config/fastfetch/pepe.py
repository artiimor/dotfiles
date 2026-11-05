#!/usr/bin/env python3
# ASCII art con color truecolor de Pepes sacados de imágenes.
# Genera un pepe-<nombre>.txt por cada Pepe; ~/.bashrc elige uno al azar para fastfetch.
#
# Idea: las líneas negras del dibujo (ojos, labios, contorno) se convierten en
# caracteres que siguen su dirección ( - _ / \ | ), y el relleno en caracteres
# suaves según el tono. Así se mantienen los rasgos que hacen reconocible a Pepe.
import subprocess, sys, numpy as np
from pathlib import Path

BG = Path.home() / ".config/backgrounds"
ASPECT = 2.1                   # alto/ancho de una celda de kitty

# Cada Pepe: imagen, recorte (x, y, w, h), cómo separarlo del fondo y cómo rellenarlo.
#   poly → silueta a mano (fondo con hierba);  key → color de fondo liso a quitar
#   ink  → por debajo de este brillo un píxel es trazo negro
#   tone → rango de brillo (oscuro, claro) que se reparte en la rampa fill
#   stroke="tinted" → trazos del color de la zona y oscurecidos (para dibujos con color),
#                     si no, lavanda clara (para dibujos casi monocromos)
PEPES = {
    "mago": dict(
        src=BG / "pepe-mago.png", crop=(30, 190, 640, 760), cols=56,
        ink=45, tone=(60, 230), fill=" ++###@", gamma=0.9, stroke="tinted",
        key=(45, 51, 63)),
}

def render(name, cfg, cols):
    x, y, w, h = cfg["crop"]
    raw = subprocess.run(["magick", str(cfg["src"]), "-crop", f"{w}x{h}+{x}+{y}", "+repage",
                          "-depth", "8", "rgb:-"], capture_output=True, check=True).stdout
    img = np.frombuffer(raw, np.uint8).reshape(h, w, 3).astype(float)
    lum = img @ [0.299, 0.587, 0.114]

    yy, xx = np.mgrid[0:h, 0:w]
    if "poly" in cfg:          # máscara del polígono (even-odd ray casting)
        poly = cfg["poly"]
        mask = np.zeros((h, w), bool)
        for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
            cond = (y1 > yy) != (y2 > yy)
            xi = x1 + (yy - y1) * (x2 - x1) / ((y2 - y1) or 1e-9)
            mask ^= cond & (xx < xi)
    else:                      # todo lo que no sea el color de fondo
        mask = np.abs(img - cfg["key"]).sum(2) > 30

    # Trazos negros + el borde de la silueta (si el fondo es oscuro el contorno exterior se perdería)
    edge = mask.copy()
    for _ in range(4):
        edge &= np.roll(edge, 1, 0) & np.roll(edge, -1, 0) & np.roll(edge, 1, 1) & np.roll(edge, -1, 1)
    line_px = mask & ((lum < cfg["ink"]) | ~edge)

    ys, xs = np.nonzero(mask)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cw = (x1 - x0) / cols
    rows = round((y1 - y0) / (cw * ASPECT))
    ch = (y1 - y0) / rows

    # Gradiente del brillo (suavizado) para saber hacia dónde va cada trazo
    blur = lum.copy()
    for _ in range(2):
        blur = (np.roll(blur, 1, 0) + np.roll(blur, -1, 0) + np.roll(blur, 1, 1) + np.roll(blur, -1, 1) + blur) / 5
    gy, gx = np.gradient(blur)

    def stroke_char(ya, yb, xa, xb, lp):
        """Carácter que sigue la dirección del trazo (perpendicular al gradiente dominante)."""
        sx, sy = gx[ya:yb, xa:xb], gy[ya:yb, xa:xb]
        jxx, jyy, jxy = (sx * sx).sum(), (sy * sy).sum(), (sx * sy).sum()
        tr = jxx + jyy
        coh = np.sqrt((jxx - jyy) ** 2 + 4 * jxy ** 2) / (tr + 1e-9)
        if coh < 0.35:                                        # cruce o mancha sin dirección
            return "*"
        gang = 0.5 * np.degrees(np.arctan2(2 * jxy, jxx - jyy))   # ángulo del gradiente
        ang = (gang + 90) % 180                                # dirección del trazo, 0 = horizontal
        ang = (-ang) % 180                                     # eje y de imagen hacia abajo
        if ang < 22 or ang >= 158:
            py, _ = np.nonzero(lp)
            return "_" if py.mean() > (yb - ya) * 0.6 else "-"
        if ang < 68:
            return "/"
        if ang < 112:
            return "|"
        return "\\"

    STROKE_RGB = (196, 190, 228)   # trazos en lavanda clara para que destaquen

    lines = []
    for r in range(rows):
        line, last = "", None
        for c in range(cols):
            ya, yb = int(y0 + r*ch), int(y0 + (r+1)*ch)
            xa, xb = int(x0 + c*cw), int(x0 + (c+1)*cw)
            m = mask[ya:yb, xa:xb]
            if m.mean() < 0.3:
                line += " "; continue
            lp = line_px[ya:yb, xa:xb]
            bright = (lum[ya:yb, xa:xb][m] > 200).mean()   # blancos de ojos/gallina: mandan sobre el trazo
            if lp.sum() / m.sum() > 0.08 and bright < 0.3:
                char, rgb = stroke_char(ya, yb, xa, xb, lp), STROKE_RGB
                rest = img[ya:yb, xa:xb][m & ~lp]
                if cfg.get("stroke") == "tinted" and len(rest):
                    rgb = (rest.mean(0) * 0.6).astype(int)
            else:
                fill = img[ya:yb, xa:xb][m & ~lp]
                l = (fill @ [0.299, 0.587, 0.114]).mean()
                lo, hi = cfg["tone"]
                t = np.clip((l - lo) / (hi - lo), 0, 0.999)
                char = cfg["fill"][1 + int(t * (len(cfg["fill"]) - 1))]
                rgb = (255 * (fill.mean(0) / 255) ** cfg["gamma"]).astype(int)  # gamma < 1 aclara
            code = "\x1b[38;2;%d;%d;%dm" % tuple(rgb)
            line += (code if code != last else "") + char
            last = code
        lines.append(line.rstrip() + "\x1b[0m")

    while lines and not lines[0].replace("\x1b[0m", "").strip(): lines.pop(0)
    while lines and not lines[-1].replace("\x1b[0m", "").strip(): lines.pop()
    out = Path(__file__).with_name(f"pepe-{name}.txt")
    out.write_text("\n".join(lines) + "\n")
    print(f"{out}  ({cols}x{len(lines)})")


# Uso: python3 pepe.py            → todos los Pepes
#      python3 pepe.py mago 40    → solo uno, con otro ancho
names = sys.argv[1:2] or list(PEPES)
for name in names:
    render(name, PEPES[name], int(sys.argv[2]) if len(sys.argv) > 2 else PEPES[name]["cols"])
