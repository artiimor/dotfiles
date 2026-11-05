# Genera un Tokio nocturno en pixel art con la paleta synthwave (cielo, sol a franjas, Tokyo Tower,
# edificios con ventanas y letreros neón, calle mojada con reflejos y lluvia)
# Se pinta a 480x270 y se escala x4 sin suavizado para que los píxeles queden nítidos
# Uso: python3 tokyo.py > tokyo.ppm && magick tokyo.ppm -filter point -resize 400% wallpaper-tokyo.png
# Cambia random.seed() para otra ciudad
import math, random, sys
random.seed(84)
W, H = 480, 270
GROUND = 212

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))

BG, BG2 = rgb("#262335"), rgb("#1a1033")
PINK, CYAN, PURPLE = rgb("#ff7edb"), rgb("#36f9f6"), rgb("#b893ce")
ORANGE, YELLOW, RED = rgb("#f97e72"), rgb("#fede5d"), rgb("#ff2a6d")
NEONS = [PINK, CYAN, PURPLE, ORANGE, YELLOW]

img = [[(0, 0, 0)] * W for _ in range(H)]

def put(x, y, c, a=1.0):
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = c if a >= 1 else mix(img[y][x], c, a)

def rect(x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            img[y][x] = c

# Cielo en bandas con tramado Bayer, como en los juegos de 16 bits
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
SKY = [rgb(c) for c in ("#0b0420", "#170a33", "#251048", "#3a1458", "#5a1a68", "#80226f", "#b0307a")]
for y in range(GROUND):
    f = (y / GROUND) ** 1.3 * (len(SKY) - 1)
    for x in range(W):
        i = int(f) + (1 if (f - int(f)) * 16 > BAYER[y % 4][x % 4] else 0)
        img[y][x] = SKY[min(i, len(SKY) - 1)]

# Estrellas en la parte alta
for _ in range(90):
    x, y = random.randrange(W), int(random.random() ** 2 * 110)
    put(x, y, rgb("#f0eff1"), random.choice([0.4, 0.7, 1.0]))

# Sol a franjas detrás de la ciudad
SX, SY, R = 330, 128, 58
for y in range(SY - R, SY + R + 1):
    dy = y - SY
    if dy > -6 and (dy + 6) % 9 < 1 + (dy + 6) * 4 // R:
        continue
    half = int(math.sqrt(max(0, R * R - dy * dy)))
    c = mix(YELLOW, RED, (dy + R) / (2 * R))
    for x in range(SX - half, SX + half + 1):
        put(x, y, c)

def skyline(color, hmin, hmax, wmin, wmax, lit, win_color=None):
    x = -random.randint(0, wmax)
    while x < W:
        w, h = random.randint(wmin, wmax), random.randint(hmin, hmax)
        top = GROUND - h
        rect(x, top, x + w, GROUND, color)
        if random.random() < 0.3:  # antena con luz roja
            ax = x + w // 2
            rect(ax, top - 6, ax + 1, top, color)
            put(ax, top - 7, RED)
        for wy in range(top + 3, GROUND - 2, 4):
            for wx in range(x + 2, x + w - 2, 3):
                if random.random() < lit:
                    c = win_color or random.choice([YELLOW, YELLOW, CYAN, PINK, ORANGE])
                    put(wx, wy, mix(color, c, random.uniform(0.35, 0.9)))
                    put(wx, wy + 1, mix(color, c, random.uniform(0.2, 0.6)))
        x += w + random.randint(0, 3)

# Ciudad lejana, morada y casi sin luces
skyline(rgb("#3b1a5e"), 30, 85, 10, 22, 0.08, PURPLE)

# Tokyo Tower: celosía naranja con dos miradores
TX, TB, TH = 130, GROUND, 165
for y in range(TB - TH, TB):
    k = (TB - y) / TH  # 0 abajo, 1 arriba
    half = max(1, int(26 * (1 - k) ** 2.2))
    for x in range(TX - half, TX + half + 1):
        edge = abs(abs(x - TX) - half) < 1
        lattice = (x + y) % 4 == 0 or (x - y) % 4 == 0
        if edge or lattice or half < 3:
            put(x, y, mix(ORANGE, rgb("#ffffff"), 0.15) if (TB - y) % 24 < 12 else ORANGE)
for dy, hw in ((62, 11), (112, 6)):
    rect(TX - hw, TB - dy, TX + hw + 1, TB - dy + 4, ORANGE)
    for x in range(TX - hw + 1, TX + hw, 2):
        put(x, TB - dy + 1, YELLOW)
put(TX, TB - TH - 1, RED)

# Ciudad media, más oscura y con más ventanas
skyline(rgb("#24123f"), 25, 70, 12, 26, 0.25)

# Edificios del primer plano con letreros verticales tipo kanji
def sign(x, y, n, c):
    rect(x, y, x + 7, y + n * 6 + 2, mix(BG2, c, 0.15))
    for i in range(n):
        g = random.getrandbits(15) | 0b010000010000010
        for b in range(15):
            if g >> b & 1:
                put(x + 1 + b % 5, y + 1 + i * 6 + b // 5, c)
    for yy in range(y - 1, y + n * 6 + 3):  # halo
        put(x - 1, yy, c, 0.35)
        put(x + 7, yy, c, 0.35)

def front(x0, x1, top):
    rect(x0, top, x1, GROUND, BG2)
    rect(x0, top, x1, top + 1, mix(BG2, PURPLE, 0.4))
    for wy in range(top + 6, GROUND - 4, 6):
        for wx in range(x0 + 3, x1 - 3, 5):
            if random.random() < 0.3:
                rect(wx, wy, wx + 2, wy + 2, mix(BG2, random.choice([YELLOW, CYAN, PINK]), 0.5))

front(0, 48, 70)
sign(36, 90, 7, PINK)
sign(8, 120, 5, CYAN)
front(440, 480, 55)
sign(444, 75, 8, CYAN)
front(400, 440, 120)
sign(424, 130, 5, YELLOW)
rect(400, 165, 440, 172, mix(BG2, PINK, 0.2))  # cartel horizontal
for x in range(402, 438, 2):
    put(x, 168, PINK)

# Calle mojada: reflejo de la ciudad, oscurecido y ondulado
rect(0, GROUND, W, GROUND + 1, mix(BG2, PURPLE, 0.6))
for y in range(GROUND + 1, H):
    d = y - GROUND
    src = GROUND - d * 2
    if src < 0:
        src = 0
    shift = int(2 * math.sin(y * 0.9))
    for x in range(W):
        c = img[src][min(W - 1, max(0, x + shift))]
        img[y][x] = mix(BG2, c, 0.45 * (1 - d / (H - GROUND)) + 0.1)

# Lluvia: rayas diagonales cortas
for _ in range(420):
    x, y, L = random.randrange(W + 40), random.randrange(H), random.randint(3, 6)
    for i in range(L):
        put(x - i // 2, y + i, mix(PURPLE, CYAN, 0.3), 0.25 + 0.15 * (i == L - 1))

sys.stdout.buffer.write(f"P6 {W} {H} 255\n".encode() + bytes(v for row in img for px in row for v in px))
