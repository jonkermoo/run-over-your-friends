# Paint the road textures (1024 px, all tiling) with numpy, no source images:
#   asphalt.png   worn asphalt, 24 studs a tile: grain, stones, tone drift, light cracks and sealed cracks
#   concrete.png  sidewalk slabs, 12 studs a tile (2 x 2 slabs), joints, stains
#   trim.png      the atlas of things laid on the road (build_roads.py BANDS/CELLS): 8 bands of 128 px, each
#                 tiling along its length: white paint, yellow paint, gutter grime, tyre wear, the soft verge,
#                 a row of cells (manhole, drain, three patches, an oil stain), faded white paint
#   python textures.py <out_dir> [preview.png]
import math, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
N = 1024
rs = np.random.default_rng(20261111)


def noise(shape, scale, rough=1.0):
    """tiling fractal noise in [-1, 1]: random spectrum shaped 1/f around `scale` px features"""
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    amp = np.exp(-(f * scale) ** 2 * 0.5) / (f ** rough)
    amp[0, 0] = 0
    spec = (rs.normal(size=shape) + 1j * rs.normal(size=shape)) * amp
    n = np.real(np.fft.ifft2(spec))
    n -= n.mean()
    return n / (np.abs(n).max() + 1e-9)


def aniso(shape, sx, sy):
    """tiling noise stretched along x (streaks)"""
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    amp = np.exp(-((fx * sx) ** 2 + (fy * sy) ** 2) * 0.5)
    amp[0, 0] = 0
    spec = (rs.normal(size=shape) + 1j * rs.normal(size=shape)) * amp
    n = np.real(np.fft.ifft2(spec))
    n -= n.mean()
    return n / (np.abs(n).max() + 1e-9)


def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(f"{OUT}/{name}")


def stamp_line(img_mask, pts, width, value=1.0):
    """draw a polyline into a mask with wrap-round (tiling), soft edges"""
    h, w = img_mask.shape
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for t in np.linspace(0, 1, n):
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = int(math.ceil(width))
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    d = math.hypot(dx, dy)
                    if d <= width:
                        yy, xx = int(y + dy) % h, int(x + dx) % w
                        img_mask[yy, xx] = max(img_mask[yy, xx], value * (1 - d / (width + 0.5)))


def crack(length, start=None, wander=0.35):
    x, y = start if start else (rs.uniform(0, N), rs.uniform(0, N))
    ang = rs.uniform(0, math.tau)
    pts = [(x, y)]
    for _ in range(int(length / 6)):
        ang += rs.normal(0, wander)
        x += math.cos(ang) * 6
        y += math.sin(ang) * 6
        pts.append((x, y))
    return pts


# ------------------------------------------------------------------ asphalt
shape = (N, N)
tone = 61 + 7 * noise(shape, 260) + 4 * noise(shape, 60) + 3 * noise(shape, 12)
grain = rs.normal(0, 6, size=shape)
asphalt = np.stack([tone + grain] * 3, axis=-1)
asphalt[..., 0] -= 2
asphalt[..., 2] += 2
# aggregate: light stones and dark pits a few px across
for count, lo, hi, val in ((5200, 1, 2.2, 38), (2600, 1, 1.8, -30)):
    ys, xs = rs.integers(0, N, count), rs.integers(0, N, count)
    rad = rs.uniform(lo, hi, count)
    for y, x, r in zip(ys, xs, rad):
        ri = int(math.ceil(r))
        for dy in range(-ri, ri + 1):
            for dx in range(-ri, ri + 1):
                if dx * dx + dy * dy <= r * r:
                    asphalt[(y + dy) % N, (x + dx) % N] += val * rs.uniform(0.5, 1.0)
# light cracks, and a couple of tar-sealed ones (wider, darker, a bit glossy)
cm = np.zeros(shape)
for _ in range(7):
    pts = crack(rs.uniform(150, 420))
    stamp_line(cm, pts, 0.9)
    for _ in range(2):  # branches
        k = rs.integers(1, len(pts))
        stamp_line(cm, crack(rs.uniform(30, 90), pts[k], 0.6), 0.7, 0.8)
asphalt -= cm[..., None] * 40
sm = np.zeros(shape)
for _ in range(3):
    stamp_line(sm, crack(rs.uniform(250, 500), wander=0.18), 3.2)
asphalt = asphalt * (1 - sm[..., None] * 0.55) + sm[..., None] * 18
save(asphalt, "asphalt.png")

# ------------------------------------------------------------------ concrete
ct = 178 + 6 * noise(shape, 200) + 4 * noise(shape, 30) + rs.normal(0, 4, shape)
yy, xx = np.mgrid[0:N, 0:N]
for sx in (0, 1):
    for sy in (0, 1):
        ct[sy * 512:(sy + 1) * 512, sx * 512:(sx + 1) * 512] += rs.uniform(-7, 7)
joint = np.minimum(np.minimum(xx % 512, 512 - xx % 512), np.minimum(yy % 512, 512 - yy % 512))
ct -= np.clip(1 - joint / 4.0, 0, 1) * 55
stain = np.clip(noise(shape, 90) * 2 - 1.0, 0, 1)
ct -= stain * 22
concrete = np.stack([ct, ct - 1, ct - 4], axis=-1)
save(concrete, "concrete.png")

# ------------------------------------------------------------------ trim atlas (RGBA)
B = 128
atlas = np.zeros((N, N, 4))


def band(k):
    return atlas[k * B:(k + 1) * B]


v = (np.arange(B) / (B - 1))[:, None] * np.ones((1, N))  # 0 at the band's top row
bshape = (B, N)


def paint(colour, wear, fade):
    holes = noise(bshape, 10) * 0.6 + noise(bshape, 3) * 0.4
    alpha = np.clip((holes + 1 - wear * 2) * 3, 0, 1) * fade
    edge = np.clip(np.minimum(v, 1 - v) * 14 + noise(bshape, 4) * 0.4, 0, 1)
    alpha = alpha * edge
    col = np.array(colour)[None, None, :] * (0.92 + 0.08 * noise(bshape, 20)[..., None])
    return np.concatenate([col, alpha[..., None] * 255], axis=-1)


band(0)[:] = paint((236, 236, 230), 0.2, 0.95)
band(1)[:] = paint((228, 178, 46), 0.18, 0.94)
band(6)[:] = paint((222, 222, 216), 0.3, 0.62)
# gutter: grime against the kerb (v = 0), fading out into the road
g = np.clip((1 - v) ** 1.6 * 0.8 + noise(bshape, 12) * 0.15, 0, 1)
band(2)[:] = np.concatenate([np.full((B, N, 3), 26.0), (g * 255)[..., None]], axis=-1)
# tyre wear: two wheel tracks across the strip, streaky along it
tracks = np.exp(-((v - 0.14) / 0.16) ** 2) + np.exp(-((v - 0.86) / 0.16) ** 2)
streak = 0.75 + 0.25 * aniso(bshape, 2, 40)
w = np.clip((tracks * 0.13 + 0.035 * np.exp(-((v - 0.5) / 0.35) ** 2)) * streak, 0, 1)
w *= np.clip(np.minimum(v, 1 - v) * 8, 0, 1)
band(3)[:] = np.concatenate([np.full((B, N, 3), 20.0), (w * 255)[..., None]], axis=-1)
# verge: v = 0 lies 0.7 inside the road edge, the edge at v = 0.24, grass by v = 1
VE = 0.24
n1 = noise(bshape, 6)
n2 = noise(bshape, 30)
edge_line = VE + 0.05 * n2 + 0.025 * n1  # where the asphalt really ends, ragged
inside = v < edge_line
crumb = np.clip((n1 * 0.7 + 0.5 - (v - edge_line) * 6), 0, 1)  # broken bits just past the edge
gravel_a = np.clip(0.85 - (v - edge_line) * 1.6 + n1 * 0.35 + n2 * 0.25, 0, 1)
alpha = np.where(inside, np.clip((v / edge_line) ** 3 * 0.55, 0, 1), np.maximum(crumb, gravel_a * 0.9))
grav = rs.normal(0, 14, (B, N, 1))
dirt = np.array([112, 100, 80])[None, None, :] + grav + 10 * n2[..., None]
asph_c = np.array([62, 63, 66])[None, None, :] + grav * 0.5
col = np.where(inside[..., None], np.array([44, 44, 44])[None, None, :], np.where(crumb[..., None] > 0.5, asph_c, dirt))
band(4)[:] = np.concatenate([col, (alpha * 255)[..., None]], axis=-1)
# cells
cells = band(5)
cy, cx = np.mgrid[0:B, 0:B]
r = np.hypot(cx - B / 2 + 0.5, cy - B / 2 + 0.5) / (B / 2)


def cell(i, rgb, a):
    cells[:, i * B:(i + 1) * B, :3] = rgb
    cells[:, i * B:(i + 1) * B, 3] = np.clip(a, 0, 1) * 255


cn = rs.normal(0, 1, (B, B))
# manhole: a cast-iron lid with a rim and a grid of ribs
lid = 46 + 8 * cn
ribs = ((cx // 10 + cy // 10) % 2 == 0) & (r < 0.78)
lid = np.where(ribs, lid + 14, lid)
lid = np.where((r > 0.8) & (r < 0.9), 70 + 6 * cn, lid)
cell(0, np.stack([lid, lid, lid + 2], -1), np.where(r < 0.9, 1, np.clip((0.97 - r) * 14, 0, 1)) * (r < 0.97))
# drain grate: dark slots in a frame (drawn 2:1, the quad is 2.6 x 1.3)
fx = np.abs(cx - B / 2) / (B / 2)
fy = np.abs(cy - B / 2) / (B / 2)
frame = (fx > 0.84) | (fy > 0.72)
slots = (cx % 12) < 6
gr = np.where(frame, 78 + 6 * cn, np.where(slots, 14 + 4 * cn, 60 + 6 * cn))
cell(1, np.stack([gr, gr, gr], -1), (fx < 0.95) & (fy < 0.9))
# patches: smoother asphalt, darker or lighter, with a sealed border and a ragged edge
for k, base in ((2, 60), (3, 80), (4, 54)):
    pn = rs.normal(0, 1, (B, B))
    edge = np.maximum(fx, fy)
    rag = np.clip((0.93 - edge) * 30 + rs.normal(0, 1.2, (B, B)), 0, 1)
    tone_c = base + 5 * pn
    tone_c = np.where(edge > 0.84, tone_c - 14, tone_c)
    cell(k, np.stack([tone_c, tone_c, tone_c + 2], -1), rag * 0.8)
# oil stain
on = rs.normal(0, 1, (B, B))
cell(5, np.stack([np.full((B, B), 18.0)] * 3, -1), np.clip((1 - r) * 1.3 + on * 0.12, 0, 1) * 0.45)
save(atlas, "trim.png")
print("written", OUT)

if len(sys.argv) > 2:
    # preview: each texture at 256 px with the trim atlas on grey
    a = Image.open(f"{OUT}/asphalt.png").resize((512, 512))
    c = Image.open(f"{OUT}/concrete.png").resize((512, 512))
    t = Image.open(f"{OUT}/trim.png")
    bg = Image.new("RGBA", t.size, (90, 120, 80, 255))
    bg.alpha_composite(t)
    sheet = Image.new("RGB", (2048, 1024), (0, 0, 0))
    sheet.paste(a, (0, 0))
    sheet.paste(c, (0, 512))
    sheet.paste(bg.convert("RGB"), (512, 0))
    tile = Image.open(f"{OUT}/asphalt.png")
    sheet.paste(tile.crop((0, 0, 512, 512)), (1536, 0))
    sheet.save(sys.argv[2])
