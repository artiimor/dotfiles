#!/usr/bin/env python3
# Colored ASCII Pepes for fastfetch, made from images.
# Generates pepe-<name>.txt; theme-set makes the theme-tinted version
# (fastfetch/themed/), and config.jsonc uses the wizard one.
#
# Idea: the dark lines of the drawing and the silhouette edge become
# characters following their direction ( - _ / \ | ) in a light tone, so they
# show on a dark background; the fill uses a density ramp ( .:-=+*#%@ ) by
# brightness, with the image color. This keeps each Pepe's features.
#
# Usage: python3 pepe.py          → all of them
#        python3 pepe.py hype 50  → just one, with another width in columns
import subprocess, sys, numpy as np
from pathlib import Path

BG = Path.home() / ".config/backgrounds"
ASPECT = 2.1                 # height/width of a terminal cell
RAMP = " .:-=+*#%@"          # from least to most dense
STROKE_RGB = np.array([200, 196, 226])

# crop = (x, y, w, h) in the original image; bg = how it is separated from the background:
#   ("flood", fuzz%) → the corner color is erased (flat background)
#   "blue"           → bluish areas connected to the edge are erased (galaxy background)
# ink = brightness below which a pixel is a stroke
PEPES = {
    "hype":    dict(src=BG / "pepe-hype.jpg",    crop=(40, 40, 520, 520),  cols=46, bg=("flood", 12), ink=30),
    "mago":    dict(src=BG / "pepe-mago.png",    crop=(30, 190, 486, 760), cols=40, bg=("flood", 8),  ink=45),
    "galaxia": dict(src=BG / "pepe-galaxia.jpg", crop=(105, 4, 100, 158),  cols=34, bg="blue",        ink=30),
}


def load(cfg):
    x, y, w, h = cfg["crop"]
    cmd = ["magick", str(cfg["src"]), "-crop", f"{w}x{h}+{x}+{y}", "+repage", "-alpha", "set"]
    if cfg["bg"] != "blue":
        cmd += ["-fuzz", f"{cfg['bg'][1]}%", "-fill", "none", "-draw", "color 0,0 floodfill"]
    raw = subprocess.run(cmd + ["-depth", "8", "rgba:-"], capture_output=True, check=True).stdout
    img = np.frombuffer(raw, np.uint8).reshape(h, w, 4).astype(float)
    mask = img[..., 3] > 127
    if cfg["bg"] == "blue":
        r, g, b = img[..., 0], img[..., 1], img[..., 2]
        bg = (b > r + 20) & (b > g + 12)
        seen = np.zeros_like(bg)
        stack = [(i, j) for i in range(h) for j in (0, w - 1)] + [(i, j) for j in range(w) for i in (0, h - 1)]
        while stack:
            i, j = stack.pop()
            if 0 <= i < h and 0 <= j < w and bg[i, j] and not seen[i, j]:
                seen[i, j] = True
                stack += [(i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)]
        mask = ~seen
    return img[..., :3], mask


def render(name, cfg, cols):
    img, mask = load(cfg)
    lum = img @ [0.299, 0.587, 0.114]
    h, w = mask.shape

    # Strokes: dark pixels + the silhouette edge (the outer outline would get lost on a dark background)
    inner = mask.copy()
    for _ in range(max(1, w // 200)):
        inner &= np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    line_px = mask & ((lum < cfg["ink"]) | ~inner)

    ys, xs = np.nonzero(mask)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cw = (x1 - x0) / cols
    rows = round((y1 - y0) / (cw * ASPECT))
    ch = (y1 - y0) / rows

    # Stroke direction: structure tensor of the smoothed brightness (outside the silhouette = black)
    blur = np.where(mask, lum, 0)
    for _ in range(2):
        blur = (np.roll(blur, 1, 0) + np.roll(blur, -1, 0) + np.roll(blur, 1, 1) + np.roll(blur, -1, 1) + blur) / 5
    gy, gx = np.gradient(blur)

    def stroke_char(sl, lp):
        sx, sy = gx[sl], gy[sl]
        jxx, jyy, jxy = (sx * sx).sum(), (sy * sy).sum(), (sx * sy).sum()
        coh = np.sqrt((jxx - jyy) ** 2 + 4 * jxy ** 2) / (jxx + jyy + 1e-9)
        if coh < 0.35:                       # crossing or blob without direction
            return "*"
        ang = (-(0.5 * np.degrees(np.arctan2(2 * jxy, jxx - jyy)) + 90)) % 180  # 0 = horizontal
        if ang < 22 or ang >= 158:
            py, _ = np.nonzero(lp)
            return "_" if py.mean() > lp.shape[0] * 0.6 else "-"
        return "/" if ang < 68 else "|" if ang < 112 else "\\"

    # fill brightness range: percentiles of the figure itself, to use the whole ramp
    lo, hi = np.percentile(lum[mask & ~line_px], (8, 97))
    lines = []
    for r in range(rows):
        line, last = "", None
        for c in range(cols):
            sl = np.s_[int(y0 + r * ch):int(y0 + (r + 1) * ch), int(x0 + c * cw):int(x0 + (c + 1) * cw)]
            m = mask[sl]
            if m.mean() < 0.3:
                line += " "
                continue
            lp = line_px[sl] & m
            bright = (lum[sl][m] > 200).mean()   # whites of the eyes: they win over the stroke
            if lp.sum() / m.sum() > 0.2 and bright < 0.3:
                char, rgb = stroke_char(sl, lp), STROKE_RGB
            else:
                fill = img[sl][m & ~lp] if (m & ~lp).any() else img[sl][m]
                # flat areas of the drawing fall in the dense half of the ramp, not in dots
                t = 0.45 + 0.55 * np.clip(((fill @ [0.299, 0.587, 0.114]).mean() - lo) / (hi - lo), 0, 1)
                char = RAMP[1 + round(t * (len(RAMP) - 2))]
                rgb = 255 * (fill.mean(0) / 255) ** 0.7          # a bit lighter for a dark background
            code = "\x1b[38;2;%d;%d;%dm" % tuple(np.clip(rgb, 0, 255).astype(int))
            line += (code if code != last else "") + char
            last = code
        lines.append(line.rstrip() + "\x1b[0m")

    strip = lambda l: l.replace("\x1b[0m", "").strip()
    while lines and not strip(lines[0]):
        lines.pop(0)
    while lines and not strip(lines[-1]):
        lines.pop()
    out = Path(__file__).with_name(f"pepe-{name}.txt")
    out.write_text("\n".join(lines) + "\n")
    print(f"{out}  ({cols}x{len(lines)})")


for n in sys.argv[1:2] or list(PEPES):
    render(n, PEPES[n], int(sys.argv[2]) if len(sys.argv) > 2 else PEPES[n]["cols"])
