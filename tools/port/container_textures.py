# Paint the shipping-container overlays (RGBA, black and white with alpha, so the part's own colour shows
# through and one set of images serves every container colour), with numpy, no source images:
#   ribs.png    the corrugated wall, tiling sideways (2 ribs a tile), the full height: top and bottom rails,
#               light ridges and dark grooves, a little grime toward the bottom
#   frame.png   laid once over a whole long side: corner posts at both ends, corner castings, an outline
#   door.png    laid once over the door end: frame, two doors with lock bars, cam handles, hinges, castings
#   python container_textures.py <out_dir>
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
rs = np.random.default_rng(20261114)


def save(name, rgb, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(f"{OUT}/{name}.png")


def layer(h, w):
    return np.zeros((h, w, 3)), np.zeros((h, w))


def put(rgb, alpha, mask, value, a):
    """paint `value` (0 black .. 255 white) at opacity `a` where mask is true, over what is there"""
    m = mask.astype(float) * a
    rgb[:] = rgb * (1 - m[..., None]) + value * m[..., None]
    alpha[:] = alpha + m * (1 - alpha)


# ribs: 2 trapezoid ribs across 128 px; full height 256 px
H, W = 256, 128
rgb, al = layer(H, W)
x = (np.arange(W) % 64) / 64.0  # one rib period
X = np.broadcast_to(x, (H, W))
Y = np.broadcast_to((np.arange(H) / H)[:, None], (H, W))
put(rgb, al, (X > 0.05) & (X < 0.38), 255, 0.16)  # outer flat, catches the light
put(rgb, al, (X >= 0.38) & (X < 0.5), 0, 0.32)  # slope into the groove, in shade
put(rgb, al, (X >= 0.5) & (X < 0.88), 0, 0.14)  # the groove
put(rgb, al, (X >= 0.88) | (X <= 0.05), 255, 0.24)  # slope back out, lit
put(rgb, al, (Y < 0.06), 0, 0.42)  # top rail
put(rgb, al, (Y > 0.93), 0, 0.5)  # bottom rail
put(rgb, al, (Y > 0.055) & (Y < 0.07), 255, 0.3)
grime = np.clip((Y - 0.6) / 0.4, 0, 1) * (0.1 + 0.08 * rs.random((H, W)))
put(rgb, al, np.ones((H, W), bool), 40, grime)
save("ribs", rgb, al)

# frame over a long side: 1024 x 256 (the side is about 4 times as long as it is tall)
H, W = 256, 1024
rgb, al = layer(H, W)
xx = np.broadcast_to(np.arange(W)[None, :], (H, W))
yy = np.broadcast_to(np.arange(H)[:, None], (H, W))
post = (xx < 22) | (xx >= W - 22)
put(rgb, al, post, 0, 0.5)
put(rgb, al, ((xx >= 18) & (xx < 22)) | ((xx >= W - 22) & (xx < W - 18)), 255, 0.25)
for cx in (0, W - 30):
    for cy in (0, H - 26):
        box = (xx >= cx) & (xx < cx + 30) & (yy >= cy) & (yy < cy + 26)
        put(rgb, al, box, 0, 0.7)
        hole = (xx >= cx + 9) & (xx < cx + 21) & (yy >= cy + 8) & (yy < cy + 18)
        put(rgb, al, hole, 0, 0.95)
edge = (xx < 3) | (xx >= W - 3) | (yy < 3) | (yy >= H - 3)
put(rgb, al, edge, 0, 0.6)
save("frame", rgb, al)

# door end: 256 x 272 (as wide as tall, near enough)
H, W = 272, 256
rgb, al = layer(H, W)
xx = np.broadcast_to(np.arange(W)[None, :], (H, W))
yy = np.broadcast_to(np.arange(H)[:, None], (H, W))
fr = 16
frame = (xx < fr) | (xx >= W - fr) | (yy < fr + 4) | (yy >= H - fr - 4)
put(rgb, al, frame, 0, 0.45)
inner = ~frame
# the door panels' own horizontal ribs
put(rgb, al, inner & ((yy // 12) % 2 == 0), 0, 0.1)
put(rgb, al, inner & ((yy % 12) == 0), 255, 0.18)
# the split between the doors
put(rgb, al, (xx >= W // 2 - 2) & (xx < W // 2 + 2) & inner, 0, 0.7)
# lock bars: two per door, light steel with a dark shadow line
for bx in (W * 0.2, W * 0.38, W * 0.62, W * 0.8):
    bx = int(bx)
    bar = (xx >= bx - 3) & (xx < bx + 3) & inner
    put(rgb, al, bar, 220, 0.75)
    put(rgb, al, (xx >= bx + 3) & (xx < bx + 5) & inner, 0, 0.5)
    for gy in (int(H * 0.2), int(H * 0.8)):
        put(rgb, al, (xx >= bx - 6) & (xx < bx + 6) & (yy >= gy - 4) & (yy < gy + 4), 30, 0.85)  # guides
    hy = int(H * 0.52)
    put(rgb, al, (xx >= bx) & (xx < bx + 22) & (yy >= hy - 3) & (yy < hy + 3), 210, 0.85)  # cam handle
# hinges down the outer edges
for side in (fr, W - fr - 10):
    for k in range(4):
        hy = int(H * (0.14 + k * 0.24))
        put(rgb, al, (xx >= side) & (xx < side + 10) & (yy >= hy) & (yy < hy + 10), 20, 0.85)
# corner castings
for cx in (0, W - 26):
    for cy in (0, H - 24):
        put(rgb, al, (xx >= cx) & (xx < cx + 26) & (yy >= cy) & (yy < cy + 24), 0, 0.75)
        put(rgb, al, (xx >= cx + 8) & (xx < cx + 18) & (yy >= cy + 7) & (yy < cy + 17), 0, 0.95)
# a small white plate on the right door
put(rgb, al, (xx >= W * 0.56) & (xx < W * 0.72) & (yy >= H * 0.1) & (yy < H * 0.16), 255, 0.8)
save("door", rgb, al)
print("ok")
