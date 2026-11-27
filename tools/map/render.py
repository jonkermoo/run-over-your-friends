"""Turns the city map scan (tools/map/scan.luau, pulled out by tools/map/extract.luau) into the map picture.

Each scan pixel is r, g, b and a height byte ((y + 50) / 2). The picture keeps the real colours, mutes them a
little so they read under the dots, shades slopes from the north-west, and draws a dark edge wherever the
height jumps (building outlines), so the city reads as a map rather than a photo. Pixels whose rays hit
nothing (past the end of the terrain, out beyond the mountains, where nobody can go) are filled outward from
the land next to them, so the picture has no empty corners.

    python tools/map/render.py <rows.hex> <out.png>
"""
import sys

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

# what tools/map/scan.luau writes for a ray that hit nothing: colour 0.08, 0.09, 0.1 and height byte 0
MISS = "14171a00"
FILL_BLUR = 24  # px


def fill_misses(rgb: np.ndarray, hts: np.ndarray, miss: np.ndarray) -> None:
    """Grows the land into the missed pixels one ring at a time, each taking the mean of its filled neighbours."""
    miss = miss.copy()
    while miss.any():
        have = ~miss
        acc = np.zeros(rgb.shape, dtype=np.float64)
        acc_h = np.zeros(hts.shape, dtype=np.float64)
        count = np.zeros(hts.shape, dtype=np.float64)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            src = np.roll(have, (dy, dx), axis=(0, 1))
            # np.roll wraps round: drop what came in over the picture's edge
            if dy == 1:
                src[0, :] = False
            elif dy == -1:
                src[-1, :] = False
            if dx == 1:
                src[:, 0] = False
            elif dx == -1:
                src[:, -1] = False
            acc += np.roll(rgb, (dy, dx), axis=(0, 1)) * src[..., None]
            acc_h += np.roll(hts, (dy, dx), axis=(0, 1)) * src
            count += src
        grow = miss & (count > 0)
        if not grow.any():
            break
        rgb[grow] = acc[grow] / count[grow][:, None]
        hts[grow] = acc_h[grow] / count[grow]
        miss &= ~grow


def main(src: str, out: str) -> None:
    with open(src, encoding="ascii") as f:
        rows = f.read().split("\n")
    n = len(rows)
    rgb = np.zeros((n, n, 3), dtype=np.float64)
    h_arr = np.zeros((n, n), dtype=np.float64)
    miss = np.zeros((n, n), dtype=bool)
    for y, row in enumerate(rows):
        for x in range(n):
            s = row[x * 8 : x * 8 + 8]
            rgb[y, x] = (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
            h_arr[y, x] = int(s[6:8], 16) * 2 - 50
            miss[y, x] = s == MISS
    fill_misses(rgb, h_arr, miss)
    col = Image.fromarray(np.clip(rgb + 0.5, 0, 255).astype(np.uint8), "RGB")
    if miss.any():
        # growing the land outward leaves streaks: soften the filled part, and leave it unshaded (below)
        soft = col.filter(ImageFilter.GaussianBlur(FILL_BLUR))
        col = Image.composite(soft, col, Image.fromarray(miss.astype(np.uint8) * 255, "L"))
    hts = h_arr.tolist()
    filled = miss.tolist()
    col = ImageEnhance.Color(col).enhance(0.85)
    col = ImageEnhance.Brightness(col).enhance(0.9)
    px = col.load()
    shaded = Image.new("RGB", (n, n))
    sp = shaded.load()
    for y in range(n):
        for x in range(n):
            if filled[y][x]:
                sp[x, y] = px[x, y]
                continue
            h = hts[y][x]
            hn = hts[max(0, y - 1)][x]
            hw = hts[y][max(0, x - 1)]
            hs = hts[min(n - 1, y + 1)][x]
            he = hts[y][min(n - 1, x + 1)]
            # slope toward the light (north-west): lit faces brighter, far faces darker
            slope = ((hw - he) + (hn - hs)) / 2
            k = 1 + max(-0.35, min(0.25, -slope * 0.03))
            # a jump of more than a few studs to any side is a wall seen from above: an ink edge
            jump = max(abs(h - hn), abs(h - hw), abs(h - hs), abs(h - he))
            if jump > 6:
                k *= 0.55
            # tall things a touch brighter, so towers stand out from the streets
            k *= 1 + min(0.12, max(0.0, h) / 1500)
            r, g, b = px[x, y]
            sp[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))
    shaded = shaded.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))
    shaded.save(out)
    print("wrote", out, shaded.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
