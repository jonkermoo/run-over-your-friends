# Paint the particle sprites in the UI's cartoon style (white, so each emitter tints them), with numpy:
#   puff.png   a cartoon smoke puff: bumpy round cloud, soft shade underneath, a soft rim
#   star.png   a four-point sparkle with a little glow
#   chunk.png  a broken brick chunk: an uneven block with a dark rim and a lit top edge
#   python sprites.py <out_dir>
import math, sys
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
N = 256
ax = (np.arange(N) + 0.5) / N * 2 - 1
X, Y = np.meshgrid(ax, ax)  # Y grows downward
rs = np.random.default_rng(7)


def save(name, rgb, a, blur=0.8):
    img = np.zeros((N, N, 4), np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    img[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    im.save(f"{OUT}/{name}.png")


# puff: seven overlapping circles
mask = np.zeros((N, N))
for k in range(7):
    a = k / 7 * math.pi * 2
    cx, cy, r = 0.36 * math.cos(a), 0.3 * math.sin(a) + 0.04, 0.38 + 0.06 * rs.random()
    mask = np.maximum(mask, np.clip((r - np.hypot(X - cx, Y - cy)) / 0.03, 0, 1))
mask = np.maximum(mask, np.clip((0.5 - np.hypot(X, Y + 0.05)) / 0.03, 0, 1))
shade = 255 - 60 * np.clip((Y + 0.1) / 0.8, 0, 1)
rgb = np.repeat(shade[..., None], 3, axis=2)
save("puff", rgb, mask * 0.95, 1.2)

# star: an astroid-like four-point sparkle and a soft glow
r = np.abs(X) ** 0.5 + np.abs(Y) ** 0.5
star = np.clip((0.95 - r) / 0.05, 0, 1)
glow = np.clip(1 - np.hypot(X, Y) / 0.45, 0, 1) ** 2 * 0.6
rgb = np.full((N, N, 3), 255.0)
save("star", rgb, np.maximum(star, glow), 0.6)

# chunk: an uneven quad with a dark rim
pts = np.array([[-0.62, -0.5], [0.58, -0.62], [0.66, 0.52], [-0.5, 0.64]]) + rs.uniform(-0.08, 0.08, (4, 2))


def inside(px, py, poly):
    res = np.ones(px.shape, bool)
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        res &= (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1) >= 0
    return res


body = inside(X, Y, pts)
inner = inside(X * 1.16, Y * 1.16, pts)
rgb = np.full((N, N, 3), 235.0)
rgb[body & ~inner] = 120
top = body & (Y < -0.3) & inner
rgb[top] = 255
noise = rs.normal(0, 8, (N, N))
rgb = rgb + noise[..., None] * body[..., None]
save("chunk", rgb, body.astype(float), 0.7)
print("ok")
