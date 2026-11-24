"""Turns the city map scan (tools/map/scan.luau, pulled out by tools/map/extract.luau) into the map picture.

Each scan pixel is r, g, b and a height byte ((y + 50) / 2). The picture keeps the real colours, mutes them a
little so they read under the dots, shades slopes from the north-west, and draws a dark edge wherever the
height jumps (building outlines), so the city reads as a map rather than a photo.

    python tools/map/render.py <rows.hex> <out.png>
"""
import sys

from PIL import Image, ImageEnhance, ImageFilter


def main(src: str, out: str) -> None:
    with open(src, encoding="ascii") as f:
        rows = f.read().split("\n")
    n = len(rows)
    col = Image.new("RGB", (n, n))
    hts = [[0.0] * n for _ in range(n)]
    px = col.load()
    for y, row in enumerate(rows):
        for x in range(n):
            s = row[x * 8 : x * 8 + 8]
            px[x, y] = (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
            hts[y][x] = int(s[6:8], 16) * 2 - 50
    col = ImageEnhance.Color(col).enhance(0.85)
    col = ImageEnhance.Brightness(col).enhance(0.9)
    px = col.load()
    shaded = Image.new("RGB", (n, n))
    sp = shaded.load()
    for y in range(n):
        for x in range(n):
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
