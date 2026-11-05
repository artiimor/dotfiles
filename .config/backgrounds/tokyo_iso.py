# Genera un cruce de Tokio de noche en pixel art con vista isométrica (estilo ARPG), ambiente cozy
# y paleta lavanda pastel. La ciudad es un mundo 3D de bloques (columnas con tramos de altura) que se
# renderiza lanzando un rayo isométrico por píxel; después se añaden brillo (bloom), charcos de luz y lluvia.
# Se pinta a 480x270 y se escala x4 sin suavizado
# Uso: python3 tokyo_iso.py > tokyo_iso.ppm && magick tokyo_iso.ppm -filter point -resize 400% wallpaper-tokyo-iso.png
# Cambia random.seed() para otra ciudad
import math, random, sys
import numpy as np

random.seed(7)
W, H = 480, 270
N = 280                 # el mundo mide N x N unidades; el cruce está en el centro
ZOOM = 1.6              # tamaño de cada unidad del mundo en píxeles (más = cámara más cerca)
OX, OY = 240, 150 - 300 * ZOOM  # proyección: px = OX + 2·ZOOM(x - y), py = OY + ZOOM(x + y - 2z)
K = 4                   # tramos sólidos como máximo por celda
ZMAX = 48.0
TOP, FX, FY = 0, 1, 2   # cara superior, cara que mira a +x (derecha) y a +y (izquierda)
FACE_LIGHT = {TOP: 1.0, FY: 0.82, FX: 0.64}

def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)

def mix(a, b, t):
    return a + (b - a) * t

BG, LAV = rgb("#221d33"), rgb("#848bbd")
PINK, CYAN, PURPLE = rgb("#e89bd0"), rgb("#86d4dc"), rgb("#a99bd6")
ORANGE, YELLOW, RED, WHITE = rgb("#eba57e"), rgb("#f0d49a"), rgb("#e8798a"), rgb("#e6e3ef")
NEONS = [LAV, PURPLE, PINK, YELLOW, ORANGE, CYAN]
WARM = np.array([YELLOW, YELLOW, YELLOW, ORANGE, ORANGE, PINK, LAV])
ROOFS = [rgb(c) for c in ("#332d4c", "#3a3456", "#2e2945", "#3f3a5e", "#363052")]
WALLS = [rgb(c) for c in ("#4a4568", "#544e74", "#463f62", "#5d6088")]

def hsh(*args):
    # Hash entero -> [0, 1) para texturas deterministas
    h = np.full(np.broadcast(*[np.asarray(a) for a in args]).shape, 2166136261, np.uint64)
    for a in args:
        v = np.asarray(a).astype(np.int64).astype(np.uint64) & np.uint64(0xffffffff)
        h = ((h ^ v) * np.uint64(16777619)) & np.uint64(0xffffffff)
    h ^= h >> np.uint64(13)
    h = (h * np.uint64(0x5bd1e995)) & np.uint64(0xffffffff)
    h ^= h >> np.uint64(15)
    return h.astype(np.float64) / 4294967296.0

# --- Mundo -----------------------------------------------------------------------
lo = np.zeros((K, N, N), np.float32)
hi = np.zeros((K, N, N), np.float32)
mat = np.zeros((K, N, N), np.int32)
used = np.zeros((N, N), np.int8)
MATS = [None]
lights = []     # (x, y, z, color, radio, intensidad) -> charco de luz en el suelo
overlay = []    # (x, y, z, color) puntos de luz que se dibujan encima

def material(**kw):
    MATS.append(kw)
    return len(MATS) - 1

def box(x0, y0, x1, y1, z0, z1, m):
    for x in range(max(0, int(x0)), min(N, int(x1))):
        for y in range(max(0, int(y0)), min(N, int(y1))):
            k = used[x, y]
            if k < K:
                lo[k, x, y], hi[k, x, y], mat[k, x, y] = z0, z1, m
                used[x, y] += 1

def cells_disc(cx, cy, r):
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                yield x, y

def proj(x, y, z):
    return OX + 2 * ZOOM * (x - y), OY + ZOOM * (x + y - 2 * z)

M_AC = material(kind="flat", color=rgb("#625c80"))
M_TANK = material(kind="flat", color=mix(rgb("#3a3456"), PURPLE, 0.35))
M_POLE = material(kind="flat", color=rgb("#2a2540"))
M_BODY = material(kind="flat", color=rgb("#2a2440"))
M_HEAD = material(kind="flat", color=rgb("#1c1729"))
M_TRUNK = material(kind="flat", color=rgb("#3a2433"))
M_SAKURA = material(kind="canopy")
M_STONE = material(kind="flat", color=rgb("#6a6585"))
M_LANTERN = material(kind="flat", color=YELLOW, emissive=True)
M_TORII = material(kind="flat", color=RED)
M_TORII_TOP = material(kind="flat", color=rgb("#3a2433"))
M_WALL = material(kind="flat", color=rgb("#575174"))
M_GLASS = material(kind="flat", color=mix(rgb("#1c1f3a"), CYAN, 0.3))
M_CAT = material(kind="flat", color=rgb("#16121f"))

# Tipos de suelo
ASPH, SIDE, GRAVEL, STONE, ALLEY = range(5)
gt = np.full((N, N), SIDE, np.int8)
R0, R1 = 134, 146   # las dos carreteras ocupan [R0, R1) en y (la horizontal) y en x (la vertical)
gt[:, R0:R1] = ASPH
gt[R0:R1, :] = ASPH
B0, B1 = R0 - 3, R1 + 3  # las manzanas empiezan después de 3 de acera

# --- Edificios -------------------------------------------------------------------
def cuts(a, b, wmin, wmax):
    out = []
    while b > a:
        w = random.randint(wmin, wmax)
        out.append((max(a, b - w), b))
        b -= w
    return out

def building(x0, y0, x1, y1, h, shopfaces=(), billboard=False, sign=False):
    shop = random.choice(NEONS)
    m = material(kind="bld", wall=random.choice(WALLS), roof=random.choice(ROOFS), shop=shop,
                 x0=x0, y0=y0, x1=x1, y1=y1, h=h, shopfaces=list(shopfaces), seed=random.randrange(1 << 20))
    box(x0, y0, x1, y1, 0, h, m)
    if x1 - x0 >= 6 and y1 - y0 >= 6:
        for _ in range((x1 - x0) * (y1 - y0) // 70 + 1):
            ax, ay = random.randint(x0 + 1, x1 - 4), random.randint(y0 + 1, y1 - 4)
            if random.random() < 0.65:
                box(ax, ay, ax + 2, ay + 2, h, h + 1.2, M_AC)
            else:
                for cx, cy in cells_disc(ax + 1.5, ay + 1.5, 1.6):
                    box(cx, cy, cx + 1, cy + 1, h, h + 2.6, M_TANK)
    for f in shopfaces:
        if f == FX:
            lights.append((x1 + 2, (y0 + y1) / 2, 0, shop, 7, 0.4))
        else:
            lights.append(((x0 + x1) / 2, y1 + 2, 0, shop, 7, 0.4))
    if billboard and shopfaces and h > 8:
        mb = material(kind="sign", color=random.choice([LAV, PINK, PURPLE]), seed=random.randrange(1 << 20))
        if shopfaces[0] == FX:
            L = min(y1 - y0 - 2, 12)
            ys = (y0 + y1 - L) // 2
            box(x1 - 2, ys, x1 - 1, ys + L, h + 0.5, h + 4.5, mb)
        else:
            L = min(x1 - x0 - 2, 12)
            xs = (x0 + x1 - L) // 2
            box(xs, y1 - 2, xs + L, y1 - 1, h + 0.5, h + 4.5, mb)
    if sign and shopfaces and h > 10:
        f = random.choice(shopfaces)
        ms = material(kind="sign", color=random.choice(NEONS), seed=random.randrange(1 << 20))
        top = min(h - 1, 4 + random.randint(6, 12))
        if f == FX:
            ys = random.choice([y0 + 1, y1 - 3])
            box(x1, ys, x1 + 1, ys + 2, 4, top, ms)
        else:
            xs = random.choice([x0 + 1, x1 - 3])
            box(xs, y1, xs + 2, y1 + 1, 4, top, ms)
    return m

# Manzana del fondo: edificios altos, más altos cuanto más lejos del cruce
for ya, yb in cuts(0, B0, 12, 20):
    for xa, xb in cuts(0, B0, 12, 20):
        far = max(0, 220 - (xa + ya)) * 0.1
        h = min(40, random.randint(12, 22) + int(far))
        faces = ([FX] if xb == B0 else []) + ([FY] if yb == B0 else [])
        building(xa + 1, ya + 1, xb, yb, h, faces, billboard=random.random() < 0.55, sign=random.random() < 0.7)

# Manzanas laterales: más bajas para no tapar las calles
cat_roof = None
for ya, yb in cuts(B1, N, 10, 16):
    for xa, xb in cuts(0, B0, 10, 16):
        b = building(xa + 1, ya + 1, xb, yb, random.randint(6, 12), [FX] if xb == B0 else [], sign=True)
        if xb == B0 and cat_roof is None:
            cat_roof = MATS[b]
for ya, yb in cuts(0, B0, 10, 16):
    for xa, xb in cuts(B1, N, 10, 16):
        building(xa + 1, ya + 1, xb, yb, random.randint(7, 14), [FY] if yb == B0 else [], sign=True)

# Manzana delantera derecha: callejón con tiendas bajas y un puesto de ramen
AX = 201
for xa, xb in cuts(AX, N, 10, 15):
    building(xa + 1, B1 + 1, xb, 164, random.randint(7, 10), [FY])
gt[AX:, 164:176] = ALLEY
for y0, y1 in ((176, 192), (198, 214), (220, 236)):
    for xa, xb in cuts(AX, N, 10, 15):
        building(xa + 1, y0, xb, y1, random.randint(6, 9), [FY])
    gt[AX:, y1:y1 + 6] = ALLEY
for i, x in enumerate(range(AX + 4, N - 4, 11)):  # máquinas expendedoras
    if 218 <= x <= 236:
        continue
    c = [CYAN, WHITE, PINK, YELLOW][i % 4]
    box(x, 164, x + 2, 165, 0, 3, material(kind="vend", color=c))
    lights.append((x + 1, 166, 0, c, 4, 0.45))

M_WOOD = material(kind="stall")
M_AWN = material(kind="awning")
box(224, 167, 232, 170, 0, 2, M_WOOD)
for px_, py_ in ((223, 171), (232, 171), (223, 166), (232, 166)):
    box(px_, py_, px_ + 1, py_ + 1, 0, 3.4, M_POLE)
box(223, 166, 233, 172, 3.4, 3.8, M_AWN)
box(233, 171, 234, 172, 2.4, 3.3, material(kind="flat", color=RED, emissive=True))
lights.append((228, 169, 0, ORANGE, 11, 0.6))
lights.append((233, 172, 0, RED, 5, 0.5))
for sx, c in ((225, LAV), (228, PURPLE), (231, PINK)):  # clientes sentados
    box(sx, 171, sx + 1, 172, 0, 1.4, material(kind="flat", color=c))
    box(sx, 171, sx + 1, 172, 1.4, 1.9, M_HEAD)

# Manzana delantera izquierda: santuario con torii, faroles de piedra y sakuras
gt[B1:AX, B1:] = GRAVEL
box(B1, B1, 160, B1 + 1, 0, 1.6, M_WALL)
box(169, B1, AX, B1 + 1, 0, 1.6, M_WALL)
box(B1, B1, B1 + 1, 176, 0, 1.6, M_WALL)
box(B1, 182, B1 + 1, N, 0, 1.6, M_WALL)
box(AX - 1, B1, AX, N, 0, 1.6, M_WALL)
gt[161:168, B1:197] = STONE
box(159, 154, 160, 155, 0, 8, M_TORII)
box(169, 154, 170, 155, 0, 8, M_TORII)
box(157, 154, 172, 155, 8, 8.6, M_TORII)
box(156, 154, 173, 155, 8.6, 9.0, M_TORII_TOP)
box(160, 154, 169, 155, 6.4, 6.9, M_TORII)
lights.append((164.5, 156, 0, RED, 6, 0.3))
for lx in (158, 170):
    for ly in (166, 182):
        box(lx, ly, lx + 1, ly + 1, 0, 2.4, M_STONE)
        box(lx, ly, lx + 1, ly + 1, 2.4, 3.2, M_LANTERN)
        box(lx, ly, lx + 1, ly + 1, 3.2, 3.6, M_STONE)
        lights.append((lx + 0.5, ly + 0.5, 0, YELLOW, 5, 0.5))
M_SHRINE = material(kind="shrine")
M_SROOF = material(kind="flat", color=rgb("#3a2440"))
box(156, 198, 174, 210, 0, 5, M_SHRINE)
box(154, 196, 176, 212, 5, 6.2, M_SROOF)
box(156, 201, 174, 207, 6.2, 7.4, M_SROOF)
box(155, 211, 175, 212, 5, 5.4, material(kind="flat", color=ORANGE))
lights.append((165, 213, 0, YELLOW, 9, 0.5))

TREES = [(184, 162, 5.5), (190, 190, 5), (176, 226, 5.5), (151 + 4, 228, 4.5), (188, 248, 5)]
for cx, cy, r in TREES:
    zc = r + 1.5
    box(cx, cy, cx + 1, cy + 1, 0, zc, M_TRUNK)
    for x, y in cells_disc(cx + 0.5, cy + 0.5, r):
        hh = math.sqrt(max(0.0, r * r - (x + 0.5 - cx - 0.5) ** 2 - (y + 0.5 - cy - 0.5) ** 2))
        box(x, y, x + 1, y + 1, zc - hh * 0.6, zc + hh * 0.8, M_SAKURA)

# --- Calle: farolas, coches y gente -------------------------------------------------
M_LAMPS = {}
for x, y, c in ((132, 132, YELLOW), (147, 132, LAV), (132, 147, LAV), (147, 147, YELLOW),
                (100, 147, YELLOW), (60, 147, LAV), (90, 132, YELLOW), (40, 132, YELLOW),
                (147, 100, LAV), (147, 60, YELLOW), (132, 100, YELLOW), (132, 190, YELLOW),
                (132, 230, LAV), (147, 230, YELLOW), (190, 147, YELLOW), (240, 147, LAV),
                (190, 132, LAV), (240, 132, YELLOW)):
    key = tuple(c)
    M_LAMPS.setdefault(key, material(kind="flat", color=mix(c, WHITE, 0.4), emissive=True))
    box(x, y, x + 1, y + 1, 0, 6, M_POLE)
    box(x, y, x + 1, y + 1, 6, 6.8, M_LAMPS[key])
    lights.append((x + 0.5, y + 0.5, 0, c, 10, 0.4))

def car(x0, y0, along_x, d, c):
    l, w = 6, 3
    x1, y1 = (x0 + l, y0 + w) if along_x else (x0 + w, y0 + l)
    m = material(kind="car", color=c, along_x=along_x, d=d, x0=x0, y0=y0, x1=x1, y1=y1)
    box(x0, y0, x1, y1, 0.3, 1.4, m)
    if along_x:
        box(x0 + 1.5, y0, x1 - 1.5, y1, 1.4, 2.2, M_GLASS)
        lights.append((x1 + 4 if d > 0 else x0 - 4, (y0 + y1) / 2, 0, YELLOW, 6, 0.35))
        lights.append((x0 - 0.5 if d > 0 else x1 + 0.5, (y0 + y1) / 2, 0, RED, 3, 0.4))
    else:
        box(x0, y0 + 1.5, x1, y1 - 1.5, 1.4, 2.2, M_GLASS)
        lights.append(((x0 + x1) / 2, y1 + 4 if d > 0 else y0 - 4, 0, YELLOW, 6, 0.35))
        lights.append(((x0 + x1) / 2, y0 - 0.5 if d > 0 else y1 + 0.5, 0, RED, 3, 0.4))

car(70, 141, True, 1, rgb("#e89bd0"))
car(196, 135, True, -1, rgb("#848bbd"))
car(141, 186, False, 1, rgb("#86d4dc"))
car(135, 60, False, -1, rgb("#f0d49a"))

UMB = [LAV, LAV, PINK, PURPLE, YELLOW, ORANGE, WHITE, CYAN]
UMB_M = [material(kind="flat", color=c) for c in UMB]
taken = set()

def person(x, y):
    if (x, y) in taken or any((x + dx, y + dy) in taken for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)):
        return
    taken.add((x, y))
    box(x, y, x + 1, y + 1, 0, 1.6, M_BODY)
    if random.random() < 0.85:
        mu = random.choice(UMB_M)
        box(x, y, x + 2, y + 2, 1.8, 2.3, mu)
    else:
        box(x, y, x + 1, y + 1, 1.6, 2.0, M_HEAD)

zones = [((80, 130), (131, 134)), ((80, 130), (146, 149)), ((150, 210), (131, 134)), ((150, 210), (146, 149)),
         ((131, 134), (80, 130)), ((146, 149), (80, 130)), ((131, 134), (150, 210)), ((146, 149), (150, 210)),
         ((135, 145), (128, 133)), ((135, 145), (147, 152)), ((128, 133), (135, 145)), ((147, 152), (135, 145)),
         ((203, 275), (166, 176)), ((161, 168), (158, 194))]
weights = [6, 6, 6, 6, 5, 5, 5, 5, 3, 3, 3, 3, 5, 2]
for _ in range(70):
    (x0, x1), (y0, y1) = random.choices(zones, weights)[0]
    person(random.randint(x0, x1 - 1), random.randint(y0, y1 - 1))

# Gato en una azotea, mirando la calle
if cat_roof:
    cx, cy, ch = cat_roof["x1"] - 3, (cat_roof["y0"] + cat_roof["y1"]) // 2, cat_roof["h"]
    box(cx - 1, cy, cx + 1, cy + 1, ch, ch + 1, M_CAT)
    box(cx + 1, cy, cx + 2, cy + 1, ch, ch + 1.8, M_CAT)
    overlay.append((cx + 2, cy + 0.3, ch + 1.4, YELLOW))
    overlay.append((cx + 2, cy + 0.8, ch + 1.4, YELLOW))

# Guirnalda de bombillas sobre el callejón
for i in range(AX + 1, N, 2):
    t = ((i - AX) % 24) / 24
    overlay.append((i, 170, 6.5 - 1.4 * math.sin(t * math.pi), YELLOW))

# --- Render: un rayo isométrico por píxel ----------------------------------------------
pyy, pxx = np.mgrid[0:H, 0:W].astype(np.float64)
dd = (pxx + 0.5 - OX) / (2 * ZOOM)
s0 = (pyy + 0.5 - OY) / ZOOM

def point(z, d, s):
    s = s + 2 * z
    return (s + d) / 2, (s - d) / 2

def probe(x, y, z):
    xi, yi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
    ok = (xi >= 0) & (xi < N) & (yi >= 0) & (yi < N)
    xi, yi = np.clip(xi, 0, N - 1), np.clip(yi, 0, N - 1)
    inside = np.zeros(x.shape, bool)
    m = np.zeros(x.shape, np.int32)
    for k in range(K):
        ins = ok & (z >= lo[k, xi, yi]) & (z < hi[k, xi, yi])
        m = np.where(ins & ~inside, mat[k, xi, yi], m)
        inside |= ins
    return inside, m, xi, yi

d, s = dd.ravel(), s0.ravel()
n = d.size
hitz = np.full(n, -1.0)
step = 0.25
active = np.ones(n, bool)
z = ZMAX
while z >= 0 and active.any():
    idx = np.nonzero(active)[0]
    x, y = point(z, d[idx], s[idx])
    ins, _, _, _ = probe(x, y, np.full(idx.size, z))
    hitz[idx[ins]] = z
    active[idx[ins]] = False
    z -= step

hit = hitz >= 0
hidx = np.nonzero(hit)[0]
zin, zout = hitz[hidx], hitz[hidx] + step
for _ in range(10):  # afinar el punto de impacto
    zm = (zin + zout) / 2
    x, y = point(zm, d[hidx], s[hidx])
    ins, _, _, _ = probe(x, y, zm)
    zin, zout = np.where(ins, zm, zin), np.where(ins, zout, zm)
xh, yh = point(zin, d[hidx], s[hidx])
_, mh, xih, yih = probe(xh, yh, zin)
xo, yo = point(zout, d[hidx], s[hidx])
xio, yio = np.floor(xo).astype(np.int64), np.floor(yo).astype(np.int64)
face = np.where((xio == xih) & (yio == yih), TOP, np.where(xio != xih, FX, FY))

col = np.zeros((n, 3))
emis = np.zeros(n, bool)

def c_bld(M, x, y, z, f):
    c = np.zeros((x.size, 3))
    em = np.zeros(x.size, bool)
    wall, roof, h = M["wall"], M["roof"], M["h"]
    t = f == TOP
    nz = hsh(np.floor(x * 2), np.floor(y * 2), M["seed"])
    c[t] = roof * (0.94 + 0.1 * nz[t, None])
    rim = t & ((x >= M["x1"] - 0.5) | (y >= M["y1"] - 0.5) | (x < M["x0"] + 0.5) | (y < M["y0"] + 0.5))
    c[rim] = roof * 1.3
    sd = ~t
    u = np.where(f == FX, y, x)
    u0 = np.where(f == FX, M["y0"], M["x0"])
    wd = np.where(f == FX, M["y1"] - M["y0"], M["x1"] - M["x0"])
    lu = u - u0
    c[sd] = wall
    fl = np.floor((z - 3.6) / 2.5)
    fv = (z - 3.6) - fl * 2.5
    cc = np.floor(lu / 2)
    fu = lu - cc * 2
    win = sd & (z >= 3.6) & (z < h - 1) & (fu >= 0.5) & (fu < 1.5) & (fv >= 0.5) & (fv < 1.75) & (lu >= 0.5) & (lu < wd - 0.5)
    hv = hsh(fl, cc, f, M["seed"])
    lit = win & (hv < 0.55)
    c[win] = wall * 0.55
    wc = WARM[(hsh(fl, cc, M["seed"], 9) * len(WARM)).astype(int)]
    c[lit] = mix(wall, wc[lit], 0.8)
    em |= lit
    c[sd & (z >= h - 0.4)] = wall * 1.25
    gf = sd & np.isin(f, M["shopfaces"]) & (z < 2.9)
    c[gf] = wall * 0.8
    sh = gf & (z >= 0.3) & (z < 2.2) & (lu >= 0.8) & (lu < wd - 0.8)
    shelf = np.floor(z * 2) % 2 == 0
    c[sh] = np.where(shelf[sh, None], mix(wall, M["shop"], 0.75), mix(wall, M["shop"], 0.55))
    door = sh & (np.abs(lu - wd / 2) < 0.8)
    c[door] = mix(M["shop"], WHITE, 0.45)
    em |= sh
    aw = gf & (z >= 2.2) & (lu >= 0.3) & (lu < wd - 0.3)
    stripe = np.floor(lu * 2) % 2 == 0
    c[aw & stripe] = M["shop"]
    c[aw & ~stripe] = WHITE * 0.9
    return c, em

def c_sign(M, x, y, z, f):
    c = np.tile(mix(BG, M["color"], 0.22), (x.size, 1))
    u = np.where(f == FX, y, x)
    tx, ty = np.floor(u * 2), np.floor(z * 2)
    g = (f != TOP) & (hsh(tx, ty, M["seed"]) < 0.5) & (ty % 4 != 3)
    c[g] = M["color"]
    return c, g

def c_flat(M, x, y, z, f):
    c = np.tile(M["color"], (x.size, 1))
    return c, np.full(x.size, bool(M.get("emissive")))

def c_canopy(M, x, y, z, f):
    pal = np.array([rgb("#c98bbf"), rgb("#e89bd0"), rgb("#f0b4dc"), rgb("#a9779f")])
    i = (hsh(np.floor(x * 2), np.floor(y * 2), np.floor(z * 2)) * 4).astype(int)
    return pal[i], np.zeros(x.size, bool)

def c_vend(M, x, y, z, f):
    c = np.tile(mix(BG, M["color"], 0.45), (x.size, 1))
    g = (f != TOP) & (z > 1.2) & (z < 2.6) & (np.floor(z * 2) % 2 == 0)
    c[g] = mix(M["color"], WHITE, 0.3)
    em = (f != TOP) & (z > 0.4)
    return c, em

def c_car(M, x, y, z, f):
    c = np.tile(M["color"], (x.size, 1))
    em = np.zeros(x.size, bool)
    lf = FX if M["along_x"] else FY
    u = np.where(f == FX, y, x)
    u0 = M["y0"] if M["along_x"] else M["x0"]
    lu = u - u0
    lamp = (f == lf) & (z > 0.6) & (z < 1.1) & ((lu < 0.8) | (lu > 2.2))
    c[lamp] = WHITE if M["d"] > 0 else RED
    em |= lamp
    return c, em

def c_stall(M, x, y, z, f):
    c = np.tile(rgb("#7a5a62"), (x.size, 1))
    g = (f == FY) & (z > 0.9) & (z < 1.7)
    c[g] = YELLOW
    return c, g

def c_awning(M, x, y, z, f):
    c = np.where((np.floor(x) % 2 == 0)[:, None], RED, WHITE * 0.9)
    return c, np.zeros(x.size, bool)

def c_shrine(M, x, y, z, f):
    c = np.tile(rgb("#5a3d4f"), (x.size, 1))
    c[np.floor(x * 2) % 3 == 0] = rgb("#4a3242")
    g = (f == FY) & (np.abs(x - 165) < 2) & (z < 3.5)
    c[g] = mix(rgb("#5a3d4f"), YELLOW, 0.8)
    return c, g

SHADERS = {"bld": c_bld, "sign": c_sign, "flat": c_flat, "canopy": c_canopy, "vend": c_vend,
           "car": c_car, "stall": c_stall, "awning": c_awning, "shrine": c_shrine}
for m in np.unique(mh):
    sel = mh == m
    M = MATS[m]
    c, em = SHADERS[M["kind"]](M, xh[sel], yh[sel], zin[sel], face[sel])
    shadef = np.vectorize(FACE_LIGHT.get)(face[sel])
    c = np.where(em[:, None], c, c * shadef[:, None])
    col[hidx[sel]] = c
    emis[hidx[sel]] = em

# Suelo
gidx = np.nonzero(~hit)[0]
gx, gy = point(0.0, d[gidx], s[gidx])
xi, yi = np.clip(np.floor(gx).astype(int), 0, N - 1), np.clip(np.floor(gy).astype(int), 0, N - 1)
g = gt[xi, yi]
nz = hsh(np.floor(gx * 2), np.floor(gy * 2), 1)
gc = np.zeros((gidx.size, 3))
asph = rgb("#252038")
gc[:] = asph * (0.88 + 0.24 * nz[:, None])
LINE, ZEBRA = mix(asph, PURPLE, 0.45), mix(asph, WHITE, 0.45)
lane = ((np.abs(gy - 140) < 0.3) & (gx % 6 < 3) & (np.abs(gx - 140) > 13)) | \
       ((np.abs(gx - 140) < 0.3) & (gy % 6 < 3) & (np.abs(gy - 140) > 13))
gc[(g == ASPH) & lane] = LINE
zebra = ((gx >= R0) & (gx < R1) & (((gy >= 128) & (gy < 133)) | ((gy >= 147) & (gy < 152))) & (gx % 1.5 < 0.75)) | \
        ((gy >= R0) & (gy < R1) & (((gx >= 128) & (gx < 133)) | ((gx >= 147) & (gx < 152))) & (gy % 1.5 < 0.75))
gc[(g == ASPH) & zebra] = ZEBRA
inter = (gx >= R0 + 1) & (gx < R1 - 1) & (gy >= R0 + 1) & (gy < R1 - 1)
diag = inter & ((np.abs(gx - gy) < 0.45) | (np.abs(gx + gy - 280) < 0.45)) & ((gx * 1.5) % 2 < 1)
gc[diag] = mix(asph, WHITE, 0.3)
pave = rgb("#3a3452")
sdw = g == SIDE
gc[sdw] = pave * (0.92 + 0.12 * nz[sdw, None])
gc[sdw & ((gx % 2 < 0.2) | (gy % 2 < 0.2))] = pave * 0.85
curb = sdw & ((np.abs(gy - R0) < 0.5) | (np.abs(gy - R1) < 0.5) | (np.abs(gx - R0) < 0.5) | (np.abs(gx - R1) < 0.5))
gc[curb] = pave * 1.3
gr = g == GRAVEL
gc[gr] = pave * (0.8 + 0.3 * nz[gr, None])
petal = np.zeros(gidx.size, bool)
for cx, cy, r in TREES:
    dist = np.hypot(gx - cx - 0.5, gy - cy - 0.5)
    petal |= gr & (dist < r * 1.9) & (hsh(np.floor(gx * 2), np.floor(gy * 2), 5) < 0.12 * (1 - dist / (r * 1.9)) + 0.02)
gc[petal] = rgb("#f0b4dc")
st = g == STONE
gc[st] = rgb("#5d5a7e") * (0.95 + 0.1 * nz[st, None])
gc[st & (gy % 2 < 0.25)] = rgb("#46425f")
al = g == ALLEY
gc[al] = rgb("#2e2945") * (0.9 + 0.15 * nz[al, None])
gc[al & ((gx + gy) % 3 < 0.35)] = rgb("#29243e")
for px_, py_, rx, ry in ((120, 140, 4, 2), (155, 137, 3, 1.5), (139, 110, 1.5, 3), (141, 170, 2, 4),
                         (80, 143, 3, 1.5), (230, 170, 3, 1.5), (175, 175, 2.5, 2), (138, 215, 2, 3)):
    pud = ((gx - px_) / rx) ** 2 + ((gy - py_) / ry) ** 2 < 1
    gc[pud] = mix(gc[pud], LAV, 0.22)
col[gidx] = gc

base = col.reshape(H, W, 3)
emimg = np.where(emis.reshape(H, W)[..., None], base, 0.0)

# --- Luz: charcos en el suelo, bloom de lo que brilla y puntos encima ----------------------
glow = np.zeros((H, W, 3))
for x, y, z, c, r, k in lights:
    cx, cy = proj(x, y, z)
    rx, ry = 2.83 * r * ZOOM, 1.41 * r * ZOOM
    x0, x1 = max(0, int(cx - rx)), min(W, int(cx + rx) + 1)
    y0, y1 = max(0, int(cy - ry)), min(H, int(cy + ry) + 1)
    if x0 >= x1 or y0 >= y1:
        continue
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dist = np.hypot((xx - cx) / rx, (yy - cy) / ry)
    f = np.clip(1 - dist, 0, 1) ** 2 * k
    glow[y0:y1, x0:x1] += f[..., None] * c

def blur(a, r):
    for axis in (0, 1):
        pad = [(r + 1, r) if i == axis else (0, 0) for i in range(3)]
        cs = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
        L = a.shape[axis]
        a = (np.take(cs, range(2 * r + 1, L + 2 * r + 1), axis) - np.take(cs, range(0, L), axis)) / (2 * r + 1)
    return a

bloom = blur(blur(emimg, 2), 2) * 0.55 + blur(blur(emimg, 7), 7) * 0.45

out = base * 0.95 + glow * (0.5 + base / 255) + bloom
out += np.array([6, 2, -2])

for x, y, z, c in overlay:
    px_, py_ = proj(x, y, z)
    px_, py_ = int(px_), int(py_)
    if 0 <= px_ < W and 0 <= py_ < H:
        out[py_, px_] = mix(c, WHITE, 0.3)
        y0, y1, x0, x1 = max(0, py_ - 3), min(H, py_ + 4), max(0, px_ - 4), min(W, px_ + 5)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        f = np.clip(1 - np.hypot((xx - px_) / 4.5, (yy - py_) / 3.5), 0, 1) ** 2 * 0.35
        out[y0:y1, x0:x1] += f[..., None] * c

# Vapor del ramen
sx, sy = proj(228, 168, 4)
for _ in range(40):
    vy = random.uniform(0, 22)
    vx = sx + random.uniform(-5, 5) + math.sin(vy * 0.35) * 2
    px_, py_ = int(vx), int(sy - vy)
    if 0 <= px_ < W and 0 <= py_ < H:
        out[py_, px_] = mix(out[py_, px_], WHITE, 0.18 + 0.1 * random.random())

# Llovizna
for _ in range(170):
    x, y, L = random.randrange(W + 20), random.randrange(H), random.randint(3, 6)
    for i in range(L):
        px_, py_ = x - i // 2, y + i
        if 0 <= px_ < W and 0 <= py_ < H:
            a = 0.15 + 0.12 * (i == L - 1)
            out[py_, px_] = mix(out[py_, px_], mix(LAV, WHITE, 0.3), a)

vy, vx = np.mgrid[0:H, 0:W]
v = 1 - 0.25 * (((vx - W / 2) / (W / 2)) ** 2 + ((vy - H / 2) / (H / 2)) ** 2)
out = np.clip(out * v[..., None], 0, 255).astype(np.uint8)
sys.stdout.buffer.write(f"P6 {W} {H} 255\n".encode() + out.tobytes())
