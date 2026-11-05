# Genera un MVG de ImageMagick con un atardecer synthwave (sol a franjas, montañas y cuadrícula)
# Uso: python3 synthwave.py > synthwave.mvg && magick -size 1920x1080 mvg:synthwave.mvg wallpaper-synthwave.png
# Cambia random.seed() para otra distribución de estrellas y montañas
import math, random
random.seed(84)
W, H = 1920, 1080
HORIZON = 720
CX = W // 2

def mix(a, b, t):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(a, b))

out = [f"viewbox 0 0 {W} {H}", "stroke-antialias 1"]

# Cielo: azul noche arriba, violeta y magenta al acercarse al horizonte
for y in range(0, HORIZON, 2):
    t = y / HORIZON
    c = mix("#0b0420", "#3a1458", t / 0.6) if t < 0.6 else mix("#3a1458", "#b0307a", (t - 0.6) / 0.4)
    out += [f"fill '{c}'", f"rectangle 0,{y} {W},{y + 2}"]

# Estrellas, más densas arriba
for _ in range(220):
    x, y = random.uniform(0, W), random.uniform(0, HORIZON * 0.6) ** 1.0
    if random.random() < y / (HORIZON * 0.6):
        continue
    r = random.choice([0.6, 0.8, 1.0, 1.4])
    out += [f"fill 'rgba(240,239,241,{random.uniform(0.3, 0.9):.2f})'", f"circle {x:.1f},{y:.1f} {x + r:.1f},{y:.1f}"]

# Sol: amarillo arriba, rosa abajo, con franjas cada vez más anchas en la mitad inferior
R, SY = 300, HORIZON - 130
for y in range(SY - R, HORIZON):
    dy = y - SY
    if abs(dy) > R:
        continue
    t = (y - (SY - R)) / (2 * R)
    if dy > -40:
        k = (dy + 40) / (R + 40)
        period = 34
        gap = 2 + k * 16
        if (dy + 40) % period < gap:
            continue
    half = math.sqrt(R * R - dy * dy)
    out += [f"fill '{mix('#fede5d', '#ff2a6d', t)}'", f"rectangle {CX - half:.1f},{y} {CX + half:.1f},{y + 1}"]

# Montañas: siluetas oscuras con el filo en cian
def ridge(base, amp, step, color, edge):
    pts = [(0, HORIZON)]
    x = 0
    while x <= W:
        d = abs(x - CX) / CX
        h = base + amp * d * random.uniform(0.5, 1.0)
        pts.append((x, HORIZON - h))
        x += step * random.uniform(0.6, 1.4)
    pts.append((W, HORIZON - base))
    pts.append((W, HORIZON))
    poly = " ".join(f"{px:.0f},{py:.0f}" for px, py in pts)
    out.extend([f"fill '{color}'", "stroke none", f"polygon {poly}"])
    line = " ".join(f"{px:.0f},{py:.0f}" for px, py in pts[1:-1])
    out.extend(["fill none", f"stroke '{edge}'", "stroke-width 2", f"polyline {line}", "stroke none"])

ridge(10, 230, 90, "#2a1150", "rgba(54,249,246,0.35)")
ridge(4, 120, 60, "#160a33", "rgba(54,249,246,0.8)")

# Suelo y cuadrícula en perspectiva
out += ["fill '#0b0420'", f"rectangle 0,{HORIZON} {W},{H}"]
for i in range(1, 26):
    z = i / 25
    y = HORIZON + (H - HORIZON) * z ** 2.2
    a = 0.25 + 0.7 * z
    out += [f"stroke 'rgba(255,126,219,{a:.2f})'", f"stroke-width {1 + 2 * z:.1f}", f"line 0,{y:.1f} {W},{y:.1f}"]
for i in range(-30, 31):
    xb = CX + i * 140
    out += [f"stroke 'rgba(255,126,219,0.7)'", "stroke-width 2", f"line {CX + i * 6},{HORIZON} {xb},{H}"]

# Línea del horizonte brillante
for w, a in ((14, 0.08), (8, 0.18), (4, 0.4), (2, 1.0)):
    out += [f"stroke 'rgba(54,249,246,{a})'", f"stroke-width {w}", f"line 0,{HORIZON} {W},{HORIZON}"]

print("\n".join(out))
