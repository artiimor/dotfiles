#!/usr/bin/env python3
# Añade el Pepe mago (pepe-mago.png) a la izquierda de los dos fondos, y un Pepe
# pequeñito (pepe-galaxia.jpg) a lo lejos en la cresta de la colina:
#   escritorio → en color con su propio rayo de sol cálido (wallpaper-desktop.jpg)
#   bloqueo    → apagado, en los grises lavanda de la noche (wallpaper.jpg)
# Uso: python3 pepe_sol.py && python3 pepe_mago_wall.py   (lee los PNG 4K, no se acumula)
import subprocess, numpy as np
from pathlib import Path

DIR = Path(__file__).parent
W, H = 1920, 1080
BG = np.array([45, 51, 63])        # fondo plano del dibujo del mago
CROP = (20, 180, 680, 960)         # x0, y0, x1, y1 del mago en pepe-mago.png
SCALE = 0.62
FX, FY = 150, 975                  # esquina izq. del recorte / línea de los pies en pantalla
SUN = np.array([255, 196, 120])

def load(path, w, h):
    raw = subprocess.run(["magick", str(path), "-filter", "Lanczos", "-resize", f"{w}x{h}!",
                          "-depth", "8", "rgb:-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(h, w, 3).astype(float)

def save(arr, path):
    subprocess.run(["magick", "-size", f"{W}x{H}", "-depth", "8", "rgb:-", "-quality", "95",
                    str(path)], input=np.clip(arr, 0, 255).astype(np.uint8).tobytes(), check=True)

# Recorte del mago escalado, alfa por distancia al color de fondo + quitar el halo del fondo
x0, y0, x1, y1 = CROP
cw, ch = round((x1 - x0) * SCALE), round((y1 - y0) * SCALE)
raw = subprocess.run(["magick", str(DIR / "pepe-mago.png"), "-crop", f"{x1-x0}x{y1-y0}+{x0}+{y0}",
                      "+repage", "-filter", "Lanczos", "-resize", f"{cw}x{ch}!", "-depth", "8", "rgb:-"],
                     capture_output=True, check=True).stdout
mago = np.frombuffer(raw, np.uint8).reshape(ch, cw, 3).astype(float)
a = np.clip((np.linalg.norm(mago - BG, axis=2) - 8) / 30, 0, 1)[..., None]
mago = np.where(a > 0, (mago - (1 - a) * BG) / np.maximum(a, 1e-3), 0)
px, py = FX, FY - ch               # el borde inferior del recorte toca los pies
assert 0 <= px and px + cw <= W and 0 <= py and py + ch <= H

# Pepe lejano: recortado de su fondo de galaxia (verde + labios + contorno oscuro, huecos rellenos)
def grow(m, n=1):
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m
src = load(DIR / "pepe-galaxia.jpg", 300, 169)[10:158, 104:198]
r, g, b = src[..., 0], src[..., 1], src[..., 2]
green = (g > r + 15) & (g > b + 5)
body = green | ((r > g + 20) & (r > b + 10)) | (grow(green, 3) & (src @ [0.299, 0.587, 0.114] < 60))
body = ~grow(~grow(body, 5), 5)    # cierre: tapa la boca abierta
out = np.zeros_like(body)
out[0, :] = out[-1, :] = out[:, 0] = out[:, -1] = True
out &= ~body
while True:                         # lo que no se alcanza desde el borde = ojos/boca
    n = grow(out) & ~body
    if (n == out).all():
        break
    out = n
lmask = ~grow(out)                  # 1 px menos para quitar el halo azul
LH, LX, LY = 64, 500, 482           # alto, centro x y pies del Pepe lejano (cresta ≈ y 468)
lw = round(src.shape[1] * LH / src.shape[0])
rgba = np.dstack([src, lmask * 255.0]).astype(np.uint8)
raw = subprocess.run(["magick", "-size", f"{src.shape[1]}x{src.shape[0]}", "-depth", "8", "rgba:-",
                      "-filter", "Lanczos", "-resize", f"{lw}x{LH}!", "rgba:-"],
                     input=rgba.tobytes(), capture_output=True, check=True).stdout
lej = np.frombuffer(raw, np.uint8).reshape(LH, lw, 4).astype(float)
la, lej = lej[..., 3:] / 255, lej[..., :3]
la *= np.clip((LH - 1 - np.arange(LH)) / 14, 0, 1)[:, None, None]  # pies hundidos en la hierba
lx, ly = LX - lw // 2, LY - LH

# Pepe hype (pepe-hype.jpg, pegatina): fuera todo lo claro alcanzable desde el borde (fondo +
# borde blanco); lo encerrado por el contorno negro (ojos) se queda. Asoma de la hierba.
src = load(DIR / "pepe-hype.jpg", 600, 600)[60:530, 70:540]
bright = (src.min(axis=2) > 170) & (np.ptp(src, axis=2) < 40)
out = np.zeros_like(bright)
out[0, :] = out[-1, :] = out[:, 0] = out[:, -1] = True
out &= bright
while True:
    n = grow(out) & bright
    if (n == out).all():
        break
    out = n
hmask = ~grow(out)
HH, HX, HY = 100, 780, 690          # alto, centro x y base del Pepe hype (ladera de la colina)
hw = round(src.shape[1] * HH / src.shape[0])
rgba = np.dstack([src, hmask * 255.0]).astype(np.uint8)
raw = subprocess.run(["magick", "-size", f"{src.shape[1]}x{src.shape[0]}", "-depth", "8", "rgba:-",
                      "-filter", "Lanczos", "-resize", f"{hw}x{HH}!", "rgba:-"],
                     input=rgba.tobytes(), capture_output=True, check=True).stdout
hyp = np.frombuffer(raw, np.uint8).reshape(HH, hw, 4).astype(float)
ha, hyp = hyp[..., 3:] / 255, hyp[..., :3]
ha *= np.clip((HH - 1 - np.arange(HH)) / 25, 0, 1)[:, None, None]  # la camiseta se hunde en la hierba
hx, hy = HX - hw // 2, HY - HH

def blend(scene, fig, alpha, x, y):
    h, w = alpha.shape[:2]
    scene[y:y + h, x:x + w] = scene[y:y + h, x:x + w] * (1 - alpha) + fig * alpha

yy, xx = np.mgrid[0:H, 0:W]
fx = px + 0.30 * cw                # centro de los pies (bajo la túnica, no el bastón)
# Sombra en la hierba bajo los pies
shadow = np.clip(1 - np.sqrt(((xx - fx) / 190) ** 2 + ((yy - FY + 8) / 26) ** 2), 0, 1)[..., None]

def paste(scene, fig, far, hype):
    out = scene * (1 - 0.45 * shadow)
    blend(out, far, la, lx, ly)
    blend(out, hype, ha, hx, hy)
    blend(out, fig, a, px, py)
    return out

# Escritorio: en color, con un foco de sol cálido como el otro Pepe
desk = load(DIR / "wallpaper-pepe-sol.png", W, H)
d = np.sqrt(((xx - fx) / 420) ** 2 + ((yy - FY + 140) / 330) ** 2)
g = (np.clip(1 - d, 0, 1) ** 2)[..., None]
desk = desk * (1 + 1.6 * g * SUN / 255) + SUN * 0.25 * g
# el lejano en color pero algo velado por la distancia
save(paste(desk, mago * 0.95 + SUN * 0.04, lej * 0.8 + 0.2 * desk[ly:ly + LH, lx:lx + lw],
           hyp * 0.85 + 0.15 * desk[hy:hy + HH, hx:hx + hw]), DIR / "wallpaper-desktop.jpg")

# Bloqueo: apagado, luminancia llevada a los tonos gris lavanda del Pepe nocturno
night = load(DIR / "wallpaper-pepe.png", W, H)
def apagar(fig, light):
    dark = np.array([34, 32, 50])
    return dark + (light - dark) * (fig @ [0.299, 0.587, 0.114])[..., None] / 255
save(paste(night, apagar(mago, np.array([150, 150, 180])), apagar(lej, np.array([115, 115, 145])),
           apagar(hyp, np.array([128, 128, 158]))), DIR / "wallpaper.jpg")
print("ok")
