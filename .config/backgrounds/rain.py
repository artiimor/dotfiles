# Genera un MVG de ImageMagick con columnas de "lluvia Matrix"
# Uso: python3 rain.py > rain.mvg && magick -size 1920x1080 mvg:rain.mvg wallpaper-hacker.png
# Cambia random.seed() para otra distribución de columnas
import random, sys
random.seed(1337)
W, H, CW, CH = 1920, 1080, 15, 22
font = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
glyphs = "0123456789ABCDEF<>/\\|=+*#$%&"
out = [f"viewbox 0 0 {W} {H}", "fill '#020a02'", f"rectangle 0,0 {W},{H}",
       f"font '{font}'", "font-size 16"]
def esc(c): return c.replace("\\", "\\\\").replace("'", "\\'")
for col in range(W // CW + 1):
    if random.random() < 0.45:   # columnas vacías: que respire
        continue
    for _ in range(random.choice([1, 1, 2])):
        length = random.randint(6, 28)
        head = random.randint(0, H // CH + length)
        bright = random.uniform(0.35, 1.0)
        for k in range(length):
            row = head - k
            if row < 0 or row * CH > H: continue
            t = 1 - k / length          # 1 en la cabeza, 0 en la cola
            a = (t ** 1.6) * bright * 0.55
            if k == 0 and bright > 0.8:
                color = f"rgba(182,255,182,{min(a*1.6,0.9):.3f})"
            else:
                color = f"rgba(0,255,65,{a:.3f})"
            out.append(f"fill '{color}'")
            out.append(f"text {col*CW},{row*CH+CH} '{esc(random.choice(glyphs))}'")
print("\n".join(out))
