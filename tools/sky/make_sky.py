# Paint the stylised skybox (6 faces, 1024 px) with numpy, no source images:
#   a saturated blue that runs from a deep zenith to a pale warm horizon, and a few soft cartoon cumulus
#   clouds on each side face, kept inside the face so no cloud is cut at a cube edge (the gradient depends
#   only on height above the horizon, so the faces meet without seams in any order).
#   python make_sky.py <out_dir> [preview.png]
import math, sys
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
N = 1024
rs = np.random.default_rng(20261114)

ZENITH = np.array([38, 124, 232], float)
MID = np.array([96, 178, 247], float)
LOW = np.array([176, 222, 252], float)
HORIZON = np.array([250, 238, 220], float)
BELOW = np.array([168, 200, 226], float)
CLOUD_TOP = np.array([255, 255, 255], float)
CLOUD_BASE = np.array([196, 212, 238], float)

ax = (np.arange(N) + 0.5) / N * 2 - 1
U, V = np.meshgrid(ax, ax)  # V grows downward in the image


def sky_colour(elev):
    """elev in degrees above the horizon, any shape"""
    e = np.clip(elev, 0, 90)[..., None]
    t1 = np.clip(e / 6, 0, 1)
    t2 = np.clip((e - 6) / 22, 0, 1)
    t3 = np.clip((e - 28) / 62, 0, 1) ** 0.8
    c = HORIZON + (LOW - HORIZON) * t1
    c = c + (MID - LOW) * t2
    c = c + (ZENITH - MID) * t3
    below = np.clip(-elev / 12, 0, 1)[..., None]
    return c * (1 - below) + BELOW * below


def side_face(seed):
    r = np.random.default_rng(seed)
    elev = np.degrees(np.arctan2(-V, np.sqrt(1 + U * U)))
    img = sky_colour(elev)
    # clouds: base line height (y in face coords, up is negative), width, bumps
    count = r.integers(4, 7)
    slots = np.linspace(-0.6, 0.6, count) + r.uniform(-0.05, 0.05, count)
    for cu in slots:
        w = r.uniform(0.13, 0.24)
        h = w * r.uniform(0.45, 0.62)
        base = -np.tan(np.radians(r.uniform(3, 26)))
        bumps = r.integers(6, 11)
        mask = np.zeros((N, N))
        for k in range(bumps):
            f = (k + 0.5) / bumps
            x = cu - w / 2 + f * w + r.uniform(-0.02, 0.02)
            bell = math.sin(math.pi * f) ** 0.7
            rad = h * (0.35 + 0.6 * bell) * r.uniform(0.8, 1.1)
            y = base - rad * 0.55
            d = np.sqrt((U - x) ** 2 + (V - y) ** 2)
            mask = np.maximum(mask, np.clip((rad - d) / 0.012, 0, 1))
        # flat bottom with a soft edge
        mask *= np.clip((base - V) / 0.01 + 0.5, 0, 1)
        s = np.clip((base - V) / (h * 1.1), 0, 1)[..., None] ** 0.55
        shade = CLOUD_BASE + (CLOUD_TOP - CLOUD_BASE) * s
        a = (mask * 0.96)[..., None]
        img = img * (1 - a) + shade * a
    return img


def cap_face(up):
    rho = np.sqrt(U * U + V * V)
    elev = np.degrees(np.arctan2(1, rho)) if up else -np.degrees(np.arctan2(1, rho))
    return sky_colour(elev)


def save(name, arr):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(f"{OUT}/{name}.png")
    return im


faces = {
    "sky_ft": side_face(1),
    "sky_bk": side_face(2),
    "sky_lf": side_face(3),
    "sky_rt": side_face(4),
    "sky_up": cap_face(True),
    "sky_dn": cap_face(False),
}
ims = {k: save(k, v) for k, v in faces.items()}

if len(sys.argv) > 2:
    s = 256
    sheet = Image.new("RGB", (s * 4, s * 3), (0, 0, 0))
    place = {"sky_up": (1, 0), "sky_lf": (0, 1), "sky_ft": (1, 1), "sky_rt": (2, 1), "sky_bk": (3, 1), "sky_dn": (1, 2)}
    for k, (cx, cy) in place.items():
        sheet.paste(ims[k].resize((s, s)), (cx * s, cy * s))
    sheet.save(sys.argv[2])
