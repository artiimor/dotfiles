#!/usr/bin/env python3
# Pepe en color con un rayo de sol cálido sobre él; el resto del prado sigue de noche.
# Uso: python3 pepe_sol.py → wallpaper-pepe-sol.png (4K) + wallpaper-desktop.jpg (1920x1080)
#
# El dibujo es de tonos planos (línea 30, base 69, brillo 88, pantalón 166), así que
# cada zona se colorea escalando un color base por la luminancia original.
import subprocess, numpy as np
from pathlib import Path

DIR = Path(__file__).parent
SRC = DIR / "wallpaper-pepe.png"
W, H = 3840, 2160
CX, CY = 2260, 1300            # esquina del recorte de Pepe (mismo que el logo de fastfetch)

# Silueta de Pepe (coords dentro del recorte 760x680), pegada a su contorno negro
POLY = [(72,155),(85,118),(135,76),(200,66),(260,78),(300,64),(352,62),(397,86),(427,140),
        (447,190),(464,232),(457,292),(450,322),(472,352),(490,395),(494,460),(480,520),
        (472,545),(474,592),(447,614),(380,622),(300,614),(118,612),(88,592),(86,555),
        (64,545),(78,518),(118,508),(150,498),(158,460),(168,332),(138,292),(118,257),
        (88,242),(73,200)]

SKIN  = np.array([104, 156, 76])    # verde Pepe en el tono base (69)
LIPS  = np.array([150, 80, 62])    # labios marrón rojizo
SHIRT = np.array([84, 112, 168])   # camiseta azul
PANTS = np.array([250, 240, 222])  # pantalón crema (tono 166)
SUN   = np.array([255, 196, 120])  # luz del sol

raw = subprocess.run(["magick", str(SRC), "-depth", "8", "rgb:-"],
                     capture_output=True, check=True).stdout
img = np.frombuffer(raw, np.uint8).reshape(H, W, 3).astype(float)
lum = img @ [0.299, 0.587, 0.114]
yy, xx = np.mgrid[0:H, 0:W]
ly, lx = yy - CY, xx - CX      # coords locales del recorte

# Máscara del polígono (even-odd ray casting)
mask = np.zeros((H, W), bool)
for (x1, y1), (x2, y2) in zip(POLY, POLY[1:] + POLY[:1]):
    cond = (y1 > ly) != (y2 > ly)
    xi = x1 + (ly - y1) * (x2 - x1) / ((y2 - y1) or 1e-9)
    mask ^= cond & (lx < xi)

# El polígono es aproximado, así que cada parte se rellena desde una semilla hasta
# chocar con las líneas negras del dibujo (como el cubo de pintura), sin salir del
# polígono ensanchado. Todas crecen a la vez: donde no hay línea que las separe
# (cuello), la frontera queda a medio camino.
def grow(m, r=1):
    for _ in range(r):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m

lines = lum < 45
room = grow(mask, 12) & ~lines
SEEDS = {"skin": [(250, 150), (330, 130), (100, 525), (430, 545), (330, 575), (307, 337), (241, 332), (272, 342)],
         "lips": [(240, 280), (113, 243)],
         "shirt": [(300, 420), (220, 380)],
         "pants": [(200, 575), (420, 590)]}
part = {}
for name, pts in SEEDS.items():
    m = np.zeros((H, W), bool)
    for x, y in pts:
        m[CY + y, CX + x] = True
    part[name] = m
taken = np.zeros((H, W), bool)
while True:
    new = {k: grow(m) & room & ~taken for k, m in part.items()}
    if not any(n.any() for n in new.values()):
        break
    for k in part:
        new[k] &= ~taken
        part[k] |= new[k]
        taken |= new[k]
# Sombra bajo la barbilla: trocitos cerrados por líneas que no alcanza ninguna semilla
neck = mask & ~taken & ~lines & (ly > 310) & (ly < 350)
part["skin"] |= neck
taken |= neck
skin, lips, shirt, pants = part["skin"], part["lips"], part["shirt"], part["pants"]
# Líneas del dibujo: las que tocan alguna parte (no la hierba oscura de alrededor)
lines &= grow(taken, 4) & grow(mask, 6)
mask = taken | lines

out = img.copy()
k = (lum / 69.0)[..., None]
out[skin]  = (SKIN  * k[skin])
out[lips]  = (LIPS  * k[lips])
out[shirt] = (SHIRT * k[shirt])
out[pants] = (PANTS * (lum / 166.0)[..., None][pants])
# Trazos negros: marrón muy oscuro en vez de negro azulado, más cálido bajo el sol
out[lines] = [38, 30, 26]

# Rayo de sol: elipse suave centrada en Pepe y su cojín, aclara y calienta la escena
sx, sy = CX + 300, CY + 380
d = np.sqrt(((xx - sx) / 900) ** 2 + ((yy - sy) / 640) ** 2)
glow = np.clip(1 - d, 0, 1) ** 2
g = glow[..., None]
scene = ~mask[..., None]
lit = out * (1 + 1.8 * g * SUN / 255) + SUN * 0.3 * g  # el fondo: luz cálida que se desvanece
lit_pepe = out * (0.92 + 0.25 * g) + SUN * 0.06 * g    # Pepe: ya está en color, solo un toque
out = np.where(scene, lit, lit_pepe)

# Haz de luz diagonal muy tenue desde arriba a la izquierda hacia Pepe
t = ((xx - sx) * 0.35 + (yy - sy) * 0.94)              # a lo largo del haz
n = ((xx - sx) * 0.94 - (yy - sy) * 0.35)              # perpendicular
beam = np.clip(1 - np.abs(n) / (260 + np.clip(-t, 0, None) * 0.25), 0, 1) ** 2
beam *= np.clip(-t / 1800, 0, 1) * np.clip(1 + t / 2600, 0, 1)
out += SUN * 0.10 * beam[..., None]

out = np.clip(out, 0, 255).astype(np.uint8)
png = DIR / "wallpaper-pepe-sol.png"
subprocess.run(["magick", "-size", f"{W}x{H}", "-depth", "8", "rgb:-", str(png)],
               input=out.tobytes(), check=True)
# Wallpaper.qml usa smooth:false → bajar a 1920x1080 con Lanczos aquí
subprocess.run(["magick", str(png), "-filter", "Lanczos", "-resize", "1920x1080",
                "-quality", "95", str(DIR / "wallpaper-desktop.jpg")], check=True)
print("ok", png)
