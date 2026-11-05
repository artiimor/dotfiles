# Genera un cruce de Tokio de noche en pixel art con vista cenital tipo RPG y paleta synthwave
# (azoteas, fachadas con tiendas, coches, gente con paraguas, santuario con torii y sakuras, lluvia)
# Se pinta a 480x270 con una capa de luz aditiva y se escala x4 sin suavizado
# Uso: python3 tokyo_rpg.py > tokyo_rpg.ppm && magick tokyo_rpg.ppm -filter point -resize 400% wallpaper-tokyo-rpg.png
# Cambia random.seed() para otra distribución
import math, random, sys
random.seed(7)
W, H = 480, 270

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))

def shade(c, k):
    return tuple(max(0, min(255, round(v * k))) for v in c)

BG2 = rgb("#1a1033")
PINK, CYAN, PURPLE = rgb("#ff7edb"), rgb("#36f9f6"), rgb("#b893ce")
ORANGE, YELLOW, RED, WHITE = rgb("#f97e72"), rgb("#fede5d"), rgb("#ff2a6d"), rgb("#f0eff1")
NEONS = [PINK, CYAN, PURPLE, ORANGE, YELLOW]

img = [[BG2] * W for _ in range(H)]
glow = [[[0.0, 0.0, 0.0] for _ in range(W)] for _ in range(H)]

def put(x, y, c, a=1.0):
    x, y = int(x), int(y)
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = c if a >= 1 else mix(img[y][x], c, a)

def rect(x0, y0, x1, y1, c, a=1.0):
    for y in range(max(0, int(y0)), min(H, int(y1))):
        for x in range(max(0, int(x0)), min(W, int(x1))):
            img[y][x] = c if a >= 1 else mix(img[y][x], c, a)

def disc(cx, cy, r, c, a=1.0):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                put(x, y, c, a)

def light(x, y, c, r, k=0.5, sy=1.0):
    ry = r * sy
    for yy in range(max(0, int(y - ry)), min(H, int(y + ry) + 1)):
        for xx in range(max(0, int(x - r)), min(W, int(x + r) + 1)):
            d = math.hypot((xx - x) / r, (yy - y) / ry)
            if d < 1:
                f = k * (1 - d) ** 2 / 255
                g = glow[yy][xx]
                g[0] += c[0] * f * 255; g[1] += c[1] * f * 255; g[2] += c[2] * f * 255

# --- Suelo -----------------------------------------------------------------
ROAD_H = (124, 156)   # carretera horizontal (y)
ROAD_V = (204, 244)   # carretera vertical (x)
SW = 10               # ancho de la acera
ASPHALT, PAVE = rgb("#1c1630"), rgb("#2f2745")

for y in range(H):
    for x in range(W):
        n = random.uniform(0.92, 1.08)
        img[y][x] = shade(PAVE, n * (0.88 if (x % 8 == 0 or y % 8 == 0) else 1))
for y in range(H):
    for x in range(W):
        if ROAD_H[0] <= y < ROAD_H[1] or ROAD_V[0] <= x < ROAD_V[1]:
            img[y][x] = shade(ASPHALT, random.uniform(0.85, 1.15))

LINE = mix(ASPHALT, PURPLE, 0.45)
mid_h, mid_v = sum(ROAD_H) // 2, sum(ROAD_V) // 2
for x in range(0, W, 12):  # líneas discontinuas
    if not ROAD_V[0] - 16 <= x <= ROAD_V[1] + 16:
        rect(x, mid_h, x + 6, mid_h + 1, LINE)
for y in range(0, H, 12):
    if not ROAD_H[0] - 16 <= y <= ROAD_H[1] + 16:
        rect(mid_v, y, mid_v + 1, y + 6, LINE)

ZEBRA = mix(ASPHALT, WHITE, 0.5)
for x in range(ROAD_V[0] + 2, ROAD_V[1] - 1, 5):  # pasos de cebra
    rect(x, ROAD_H[0] - 13, x + 3, ROAD_H[0] - 2, ZEBRA)
    rect(x, ROAD_H[1] + 2, x + 3, ROAD_H[1] + 13, ZEBRA)
for y in range(ROAD_H[0] + 2, ROAD_H[1] - 1, 5):
    rect(ROAD_V[0] - 13, y, ROAD_V[0] - 2, y + 3, ZEBRA)
    rect(ROAD_V[1] + 2, y, ROAD_V[1] + 13, y + 3, ZEBRA)
for i in range(-14, 15):  # la diagonal del cruce tipo Shibuya
    for w in range(3):
        if i % 5 < 3:
            put(mid_v + i * 1.3 + w, mid_h + i, ZEBRA, 0.6)
            put(mid_v - i * 1.3 + w, mid_h + i, ZEBRA, 0.6)

# --- Edificios ---------------------------------------------------------------
ROOFS = [rgb(c) for c in ("#2b2142", "#31264a", "#272038", "#352a50", "#2d2340")]
WALLS = [rgb(c) for c in ("#3b2d5c", "#45326a", "#352850", "#4a3466")]
signs = []

def glyph_sign(x, y, n, c, vertical=True):
    w, h = (7, n * 6 + 2) if vertical else (n * 6 + 2, 7)
    rect(x, y, x + w, y + h, mix(BG2, c, 0.18))
    for i in range(n):
        g = random.getrandbits(15) | 0b010000010000010
        ox, oy = (1, 1 + i * 6) if vertical else (1 + i * 6, 1)
        for b in range(15):
            if g >> b & 1:
                put(x + ox + b % 5, y + oy + b // 5, c)
    light(x + w / 2, y + h / 2, c, max(w, h) * 0.9 + 6, 0.45)
    signs.append((x + w / 2, y + h, c))

def roof_details(x0, y0, x1, y1, roof):
    rect(x0, y1 - 1, x1, y1, shade(roof, 1.5))  # borde que da a la cámara
    rect(x0, y0, x0 + 1, y1, shade(roof, 0.75))
    rect(x1 - 1, y0, x1, y1, shade(roof, 1.25))
    for _ in range((x1 - x0) * (y1 - y0) // 500 + 1):
        kind = random.random()
        ax, ay = random.randint(x0 + 3, max(x0 + 3, x1 - 11)), random.randint(y0 + 3, max(y0 + 3, y1 - 10))
        if kind < 0.5:  # aire acondicionado
            rect(ax, ay + 1, ax + 8, ay + 7, shade(roof, 0.6))
            rect(ax, ay, ax + 8, ay + 6, rgb("#4d4266"))
            rect(ax, ay, ax + 8, ay + 1, rgb("#6a5d86"))
            disc(ax + 4, ay + 3, 1.5, rgb("#231b36"))
        elif kind < 0.75:  # depósito de agua
            disc(ax + 4, ay + 5, 4, shade(roof, 0.6))
            disc(ax + 4, ay + 4, 4, mix(roof, PURPLE, 0.3))
            disc(ax + 4, ay + 4, 2, mix(roof, PURPLE, 0.45))
        else:  # rejillas
            for i in range(0, 8, 2):
                rect(ax + i, ay, ax + i + 1, ay + 6, shade(roof, 0.7))

def building(x0, x1, ybase, fh, roof_top, shop=True, billboard=False):
    roof, wall = random.choice(ROOFS), random.choice(WALLS)
    ytop = ybase - fh
    rect(x0, roof_top, x1, ytop, roof)
    roof_details(x0, roof_top, x1, ytop, roof)
    rect(x0, ytop, x1, ybase, wall)
    rect(x0, ytop, x0 + 1, ybase, shade(wall, 0.7))
    rect(x1 - 1, ytop, x1, ybase, shade(wall, 0.8))
    for wy in range(ytop + 3, ybase - 12, 5):
        for wx in range(x0 + 3, x1 - 4, 4):
            if random.random() < 0.45:
                c = random.choice([YELLOW, YELLOW, ORANGE, CYAN, PINK])
                rect(wx, wy, wx + 2, wy + 3, mix(wall, c, 0.65))
                light(wx + 1, wy + 1, c, 4, 0.12)
            else:
                rect(wx, wy, wx + 2, wy + 3, shade(wall, 0.6))
    if shop:
        c = random.choice(NEONS)
        sx0, sx1 = x0 + 3, x1 - 3
        rect(sx0, ybase - 9, sx1, ybase - 1, mix(wall, c, 0.55))
        for x in range(sx0, sx1):  # toldo a rayas
            put(x, ybase - 11, c if (x // 2) % 2 else WHITE, 0.85)
            put(x, ybase - 10, shade(c if (x // 2) % 2 else WHITE, 0.7))
        dx = (sx0 + sx1) // 2
        rect(dx - 2, ybase - 8, dx + 2, ybase, mix(c, WHITE, 0.4))
        light(dx, ybase + 3, c, 20, 0.45, sy=0.7)
    if random.random() < 0.6 and fh > 24:
        sx = x0 + 2 if random.random() < 0.5 else x1 - 9
        glyph_sign(sx, ytop + 2, max(2, (fh - 16) // 6), random.choice(NEONS))
    if billboard and ytop - roof_top > 18:
        bw = min(x1 - x0 - 6, 40)
        bx = x0 + (x1 - x0 - bw) // 2
        c = random.choice([PINK, CYAN])
        rect(bx, ytop - 12, bx + bw, ytop - 2, mix(BG2, c, 0.25))
        rect(bx, ytop - 12, bx + bw, ytop - 11, c)
        rect(bx, ytop - 3, bx + bw, ytop - 2, c)
        glyph_sign(bx + 3, ytop - 10, (bw - 6) // 6, mix(c, WHITE, 0.3), vertical=False)
        light(bx + bw / 2, ytop - 7, c, bw * 0.8, 0.5)

def row(x0, x1, ybase, roof_top, fh_range, billboard_chance=0.4):
    x = x0
    while x < x1 - 20:
        w = random.randint(30, 56)
        w = x1 - x if x1 - x - w < 26 else w
        building(x, x + w, ybase, random.randint(*fh_range), roof_top,
                 billboard=random.random() < billboard_chance)
        x += w + 1

top = ROAD_H[0] - SW
row(0, ROAD_V[0] - SW, top, 0, (26, 40), 0.7)
row(ROAD_V[1] + SW, W, top, 0, (26, 44), 0.7)

# Abajo a la derecha: fila de tiendas, callejón y azoteas de la siguiente manzana
bot = ROAD_H[1] + SW
row(ROAD_V[1] + SW, W, 214, bot, (22, 28), 0.0)
ALLEY = rgb("#272038")
rect(ROAD_V[1] + SW, 214, W, 252, ALLEY)
for y in range(214, 252):
    for x in range(ROAD_V[1] + SW, W):
        if (x + y) % 9 == 0:
            put(x, y, shade(ALLEY, 0.8))
for i, x in enumerate(range(ROAD_V[1] + SW + 6, W - 6, 34)):  # máquinas expendedoras
    c = [CYAN, WHITE, PINK, YELLOW][i % 4]
    rect(x, 215, x + 7, 224, mix(BG2, c, 0.5))
    rect(x + 1, 216, x + 6, 220, mix(c, WHITE, 0.3))
    light(x + 3, 224, c, 14, 0.4, sy=0.8)
for x in range(ROAD_V[1] + SW + 22, W - 6, 34):  # farolillos rojos
    disc(x, 212, 2, RED)
    put(x, 211, mix(RED, YELLOW, 0.6))
    light(x, 214, RED, 12, 0.5)
x = ROAD_V[1] + SW
while x < W:
    w = random.randint(30, 50)
    roof = random.choice(ROOFS)
    rect(x, 252, x + w, H, roof)
    rect(x, 252, x + w, 253, shade(roof, 1.4))
    x += w + 1

# Abajo a la izquierda: santuario con torii, sakuras y faroles de piedra
bx0, bx1 = 0, ROAD_V[0] - SW
GRAVEL = rgb("#3a3150")
for y in range(bot, H):
    for x in range(bx0, bx1):
        img[y][x] = shade(GRAVEL, random.uniform(0.85, 1.1))
WALL = rgb("#4a4062")
tx = 96
rect(bx0, bot, tx - 14, bot + 4, WALL)
rect(tx + 15, bot, bx1, bot + 4, WALL)
rect(bx0, bot, bx1, bot + 1, shade(WALL, 1.3))
for y in range(bot + 4, 236, 5):  # camino de losas
    rect(tx - 6, y, tx + 7, y + 4, rgb("#5a4f75"))
TORII = rgb("#ff3b5c")
rect(tx - 12, bot + 2, tx - 9, bot + 20, shade(TORII, 0.8))
rect(tx + 10, bot + 2, tx + 13, bot + 20, shade(TORII, 0.8))
rect(tx - 16, bot + 1, tx + 17, bot + 4, TORII)
rect(tx - 17, bot, tx + 18, bot + 1, rgb("#2a1a30"))
rect(tx - 12, bot + 7, tx + 13, bot + 9, TORII)
light(tx, bot + 8, RED, 26, 0.3)
# santuario
SR, SWALL = rgb("#3a2440"), rgb("#5a3d4f")
rect(tx - 26, 236, tx + 27, 254, SR)
for x in range(tx - 26, tx + 27, 3):
    rect(x, 236, x + 1, 254, shade(SR, 1.2))
rect(tx - 28, 253, tx + 29, 255, ORANGE)
rect(tx - 22, 255, tx + 23, H, SWALL)
rect(tx - 4, 256, tx + 5, H, mix(SWALL, YELLOW, 0.5))
light(tx, 262, YELLOW, 22, 0.45)
for lx in (tx - 16, tx + 16):  # faroles de piedra
    for ly in (bot + 26, 222):
        rect(lx - 2, ly, lx + 3, ly + 5, rgb("#6a6080"))
        rect(lx - 1, ly + 1, lx + 2, ly + 3, YELLOW)
        light(lx, ly + 2, YELLOW, 14, 0.5)

def sakura(cx, cy, r):
    disc(cx + 2, cy + r - 1, r * 0.8, rgb("#120c22"), 0.3)  # sombra
    rect(cx - 1, cy, cx + 2, cy + r, rgb("#3a2433"))
    for _ in range(int(r * 3)):
        a, d = random.uniform(0, 6.3), random.uniform(0, r * 0.7)
        disc(cx + math.cos(a) * d, cy - r * 0.3 + math.sin(a) * d * 0.8, random.uniform(2, 4),
             random.choice([rgb("#d65fa8"), rgb("#ff7edb"), rgb("#ffa8e4"), rgb("#b84a91")]))
    for _ in range(int(r * 2)):  # pétalos en el suelo
        a, d = random.uniform(0, 6.3), random.uniform(r * 0.6, r * 1.8)
        put(cx + math.cos(a) * d, cy + r * 0.5 + math.sin(a) * d * 0.6, rgb("#ffa8e4"), 0.8)

for cx, cy, r in ((30, 196, 13), (160, 192, 12), (52, 238, 11), (150, 236, 12), (12, 256, 9)):
    sakura(cx, cy, r)

# --- Farolas -----------------------------------------------------------------
for x, y, c in ((ROAD_V[0] - 4, ROAD_H[0] - 4, YELLOW), (ROAD_V[1] + 3, ROAD_H[0] - 4, CYAN),
                (ROAD_V[0] - 4, ROAD_H[1] + 3, CYAN), (ROAD_V[1] + 3, ROAD_H[1] + 3, YELLOW),
                (70, ROAD_H[0] - 4, YELLOW), (140, ROAD_H[1] + 3, YELLOW),
                (330, ROAD_H[0] - 4, CYAN), (420, ROAD_H[1] + 3, YELLOW),
                (ROAD_V[0] - 4, 40, YELLOW), (ROAD_V[1] + 3, 220, CYAN)):
    rect(x, y, x + 2, y + 2, mix(c, WHITE, 0.5))
    light(x + 1, y + 1, c, 30, 0.35)

# --- Coches ------------------------------------------------------------------
CARS = [rgb(c) for c in ("#fede5d", "#b893ce", "#36a3f9", "#e8e4f0", "#ff7edb", "#6b5a8e")]

def car(x, y, horizontal, d, c):
    l, w = 20, 10
    if horizontal:
        rect(x + 1, y + 2, x + l + 1, y + w + 1, rgb("#100a1e"))
        rect(x, y, x + l, y + w, c)
        rect(x + 6, y + 1, x + 14, y + w - 1, shade(c, 0.7))
        fx = x + l - 1 if d > 0 else x
        wx = x + 13 if d > 0 else x + 5
        rect(wx, y + 2, wx + 2, y + w - 2, mix(rgb("#102040"), CYAN, 0.35))
        bx = x if d > 0 else x + l - 1
        for hy in (y + 1, y + w - 2):
            put(fx, hy, WHITE); put(bx, hy, RED)
        light(fx + d * 14, y + w / 2, mix(YELLOW, WHITE, 0.5), 16, 0.4, sy=0.5)
        light(bx, y + w / 2, RED, 7, 0.5)
    else:
        rect(x + 1, y + 2, x + w + 1, y + l + 1, rgb("#100a1e"))
        rect(x, y, x + w, y + l, c)
        rect(x + 1, y + 6, x + w - 1, y + 14, shade(c, 0.7))
        fy = y + l - 1 if d > 0 else y
        wy = y + 13 if d > 0 else y + 5
        rect(x + 2, wy, x + w - 2, wy + 2, mix(rgb("#102040"), CYAN, 0.35))
        by = y if d > 0 else y + l - 1
        for hx in (x + 1, x + w - 2):
            put(hx, fy, WHITE); put(hx, by, RED)
        light(x + w / 2, fy + d * 14, mix(YELLOW, WHITE, 0.5), 16, 0.4, sy=1.6)
        light(x + w / 2, by, RED, 7, 0.5)

for x, d in ((30, -1), (110, -1), (290, -1), (400, -1)):
    car(x, ROAD_H[0] + 3, True, d, random.choice(CARS))
for x, d in ((60, 1), (150, 1), (340, 1)):
    car(x, ROAD_H[1] - 14, True, d, random.choice(CARS))
for y, d in ((20, 1), (70, 1)):
    car(ROAD_V[0] + 5, y, False, d, random.choice(CARS))
for y, d in ((180, -1), (232, -1)):
    car(ROAD_V[1] - 15, y, False, d, random.choice(CARS))

# --- Gente con paraguas -------------------------------------------------------
UMB = [PINK, CYAN, PURPLE, YELLOW, ORANGE, WHITE, RED]

def person(x, y):
    if random.random() < 0.8:
        c = random.choice(UMB)
        disc(x + 1, y + 2, 3, rgb("#120c22"), 0.35)
        disc(x, y, 3, shade(c, 0.75))
        disc(x - 0.5, y - 0.5, 2, c)
        put(x - 1, y - 1, mix(c, WHITE, 0.6))
    else:
        rect(x - 1, y - 1, x + 2, y + 4, rgb("#2a2040"))
        rect(x - 1, y - 2, x + 2, y, rgb("#15101f"))

zones = [(0, ROAD_V[0] - 2, ROAD_H[0] - SW + 2, ROAD_H[0] - 2), (ROAD_V[1] + 2, W, ROAD_H[0] - SW + 2, ROAD_H[0] - 2),
         (0, ROAD_V[0] - 2, ROAD_H[1] + 3, ROAD_H[1] + SW - 1), (ROAD_V[1] + 2, W, ROAD_H[1] + 3, ROAD_H[1] + SW - 1),
         (ROAD_V[0] + 3, ROAD_V[1] - 3, ROAD_H[0] - 12, ROAD_H[0] - 3), (ROAD_V[0] + 3, ROAD_V[1] - 3, ROAD_H[1] + 3, ROAD_H[1] + 12),
         (ROAD_V[0] - 12, ROAD_V[0] - 3, ROAD_H[0] + 3, ROAD_H[1] - 3), (ROAD_V[1] + 3, ROAD_V[1] + 12, ROAD_H[0] + 3, ROAD_H[1] - 3),
         (ROAD_V[1] + SW + 4, W - 4, 228, 249), (tx - 5, tx + 6, bot + 6, 232)]
weights = [8, 8, 8, 8, 5, 5, 3, 3, 6, 2]
for _ in range(56):
    x0, x1, y0, y1 = random.choices(zones, weights)[0]
    person(random.randint(x0 + 2, x1 - 3), random.randint(y0 + 1, max(y0 + 1, y1 - 1)))

# --- Reflejos de neón en el suelo mojado y charcos -----------------------------
for sx, sy, c in signs:
    if sy > ROAD_H[0] - SW - 30 and sy < ROAD_H[0]:
        light(sx, ROAD_H[0] + 8, c, 8, 0.35, sy=2.2)
for _ in range(14):
    px = random.randint(0, W); py = random.choice([random.randint(*ROAD_H), random.randint(ROAD_V[0], ROAD_V[1])])
    if random.random() < 0.5:
        px, py = random.randint(*ROAD_V), random.randint(0, H)
    rx = random.randint(5, 10)
    for y in range(py - 2, py + 3):
        for x in range(px - rx, px + rx + 1):
            if ((x - px) / rx) ** 2 + ((y - py) / 2.5) ** 2 < 1:
                put(x, y, mix(img[min(H - 1, max(0, y))][min(W - 1, max(0, x))], PURPLE, 0.25))
    put(px - rx // 2, py - 1, WHITE, 0.5)

# --- Lluvia ------------------------------------------------------------------
for _ in range(380):
    x, y, L = random.randrange(W + 20), random.randrange(H), random.randint(3, 6)
    for i in range(L):
        put(x - i // 2, y + i, mix(PURPLE, CYAN, 0.35), 0.22 + 0.15 * (i == L - 1))
for _ in range(70):  # salpicaduras
    x, y = random.randrange(W), random.randrange(H)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        put(x + dx, y + dy, mix(PURPLE, WHITE, 0.4), 0.3)

# --- Composición: base + luz, con viñeta ----------------------------------------
out = bytearray()
for y in range(H):
    for x in range(W):
        vx, vy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
        v = 1 - 0.32 * (vx * vx + vy * vy)
        b, g = img[y][x], glow[y][x]
        for i in range(3):
            out.append(max(0, min(255, round((b[i] * 0.92 + g[i] * (0.6 + b[i] / 255)) * v))))
sys.stdout.buffer.write(f"P6 {W} {H} 255\n".encode() + bytes(out))
