# Draw every vehicle's mastery decals as transparent 1024 px images laid out for the painted parts' decal UVs
# (tools/blender/vehicle_upgrades.py: three bands, each the vehicle's stock length front (left) to back, left side
# at the top, right side in the middle, roof at the bottom). Clear pixels show the paint colour.
# python tools/art/decals.py <decal_boxes.json> <font.ttf> <outdir> [preview.png]
#   <font.ttf>: a bold free font for the race numbers (DejaVu Sans Bold, Bitstream Vera licence)
# Writes <outdir>/<Vehicle>_<Decal>.png. Config/Decals lists the decals and the image ids after upload.
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

boxes_path, font_path, outdir = sys.argv[1:4]
preview = sys.argv[4] if len(sys.argv) > 4 else None
os.makedirs(outdir, exist_ok=True)
BOXES = json.load(open(boxes_path, encoding="utf-8"))
SIZE = 1024
K = 40  # canvas pixels per stud while drawing a band (then fitted into its band)
BAY = {"Hatchback": 1, "Scooter": 2, "Cart": 3, "Sedan": 4, "Taxi": 5, "Muscle": 6, "IceCream": 7, "FireTruck": 8,
       "Semi": 9, "Bulldozer": 10, "Monster": 11, "Supercar": 12, "Roadster": 13}

WHITE = (245, 245, 240, 255)
INK = (24, 24, 28, 255)
YELLOW = (255, 208, 40, 255)
ORANGE = (255, 122, 20, 255)
RED = (214, 40, 30, 255)
GOLD = (222, 176, 60, 255)


class Band:
    """One band's canvas in studs: x along the vehicle from its front, y down from its top (sides) or across from
    its left edge (roof). `side` is "left", "right" or "top"."""

    def __init__(self, side, length, height):
        self.side, self.L, self.H = side, length, height
        self.img = Image.new("RGBA", (max(8, int(length * K)), max(8, int(height * K))), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def p(self, x, y):
        return (x * K, y * K)

    def poly(self, pts, fill, outline=None, width=0):
        self.d.polygon([self.p(x, y) for x, y in pts], fill=fill, outline=outline, width=int(width * K) if width else 0)

    def rect(self, x0, y0, x1, y1, fill):
        self.d.rectangle([self.p(x0, y0), self.p(x1, y1)], fill=fill)

    def circle(self, x, y, r, fill, outline=None, width=0):
        self.d.ellipse([self.p(x - r, y - r), self.p(x + r, y + r)], fill=fill, outline=outline,
                       width=int(width * K) if width else 0)

    def line(self, pts, fill, width):
        self.d.line([self.p(x, y) for x, y in pts], fill=fill, width=max(1, int(width * K)), joint="curve")

    def text(self, x, y, size, s, fill, font=None, stroke=None):
        """Text centred on (x, y), `size` studs tall; mirrored on the right side so it reads from that side."""
        f = ImageFont.truetype(font_path, max(8, int(size * K)))
        bb = f.getbbox(s, stroke_width=int(size * K * 0.08) if stroke else 0)
        w, h = bb[2] - bb[0] + 4, bb[3] - bb[1] + 4
        t = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(t).text((2 - bb[0], 2 - bb[1]), s, font=f, fill=fill,
                               stroke_width=int(size * K * 0.08) if stroke else 0, stroke_fill=stroke)
        if self.side == "right":
            t = t.transpose(Image.FLIP_LEFT_RIGHT)
        self.img.alpha_composite(t, (int(x * K - w / 2), int(y * K - h / 2)))


# ---- designs: each takes (band, vehicle id) and draws what goes on that band
def stripes(b, vid):
    if b.side != "top":
        return
    mid = b.H / 2
    for c in (-0.95, 0.95):
        b.rect(0, mid + c - 0.5, b.L, mid + c + 0.5, WHITE)
        b.rect(0, mid + c - 0.62, b.L, mid + c - 0.5, INK)
        b.rect(0, mid + c + 0.5, b.L, mid + c + 0.62, INK)


def number(b, vid):
    if b.side == "top":
        return
    r = min(b.H * 0.2, b.L * 0.11)
    x, y = b.L * 0.5, b.H * 0.55
    b.circle(x, y, r, WHITE, INK, 0.08)
    b.text(x, y, r * 1.1, f"{BAY[vid]:02d}", INK)


def flames(b, vid):
    random.seed(7 + BAY[vid])
    if b.side == "top":
        reach, y0, y1 = b.L * 0.3, b.H * 0.2, b.H * 0.8
    else:
        reach, y0, y1 = b.L * 0.55, b.H * 0.45, b.H * 0.8
    for colour, shrink in ((RED, 0.0), (ORANGE, 0.12), (YELLOW, 0.26)):
        pts = [(0, y0 + (y1 - y0) * shrink)]
        n = 5
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            yy = y0 + (y1 - y0) * (shrink + (1 - 2 * shrink) * (t0 + t1) / 2)
            tip = reach * (1 - shrink) * (0.55 + 0.45 * math.sin(i * 1.7 + 1)) * (1 - 0.15 * abs(i - 2))
            pts.append((tip, yy))
            pts.append((reach * (1 - shrink) * 0.35, y0 + (y1 - y0) * (shrink + (1 - 2 * shrink) * t1)))
        pts.append((0, y1 - (y1 - y0) * shrink))
        b.poly(pts, colour)


def checker(b, vid):
    if b.side == "top":
        return
    cell = max(0.35, b.H * 0.06)
    y = b.H * 0.62
    b.rect(0, y - cell - 0.08, b.L, y + cell + 0.08, INK)
    i = 0
    x = 0.0
    while x < b.L:
        b.rect(x, y - cell if i % 2 else y, x + cell, y if i % 2 else y + cell, WHITE)
        x += cell
        i += 1


# signature decals, one per vehicle
def lightning(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    pts = [(L * 0.15, H * 0.55), (L * 0.55, H * 0.42), (L * 0.5, H * 0.52), (L * 0.88, H * 0.47), (L * 0.42, H * 0.7),
           (L * 0.48, H * 0.6)]
    b.poly(pts, YELLOW, INK, 0.08)


def pizza(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    x, y = L * 0.62, H * 0.5
    b.poly([(x - 1.2, y - 0.8), (x + 1.2, y - 0.8), (x, y + 1.3)], (250, 200, 70, 255))
    b.rect(x - 1.3, y - 1.05, x + 1.3, y - 0.75, (200, 130, 60, 255))
    for dx, dy in ((-0.5, -0.35), (0.45, -0.3), (0.0, 0.35)):
        b.circle(x + dx, y + dy, 0.22, RED)
    for i in range(3):
        b.line([(x + 1.5, y - 0.6 + i * 0.5), (x + 3.0, y - 0.6 + i * 0.5)], WHITE, 0.12)


def mega_mart(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    b.rect(L * 0.2, H * 0.3, L * 0.8, H * 0.55, RED)
    b.text(L * 0.5, H * 0.425, H * 0.14, "MEGA MART", WHITE)


def pinstripe(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    for off, col in ((0.0, GOLD), (0.18, WHITE)):
        pts = [(L * (0.05 + i / 40 * 0.9), H * (0.55 + off * 0.3) + math.sin(i / 40 * math.pi * 2) * H * 0.04)
               for i in range(41)]
        b.line(pts, col, 0.08)


def dice(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    checker(b, vid)
    for i, (x, pips) in enumerate(((0.42, 5), (0.56, 3))):
        cx, cy, s = L * x, H * 0.4, H * 0.1
        b.rect(cx - s, cy - s, cx + s, cy + s, WHITE)
        spots = {5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)]}[pips]
        for dx, dy in spots:
            b.circle(cx + dx * s * 0.5, cy + dy * s * 0.5, s * 0.16, INK)


def thunder(b, vid):
    L, H = b.L, b.H
    if b.side == "top":
        for c in (-1, 1):
            b.poly([(0, H / 2 + c * 0.4), (L * 0.35, H / 2 + c * 1.4), (L * 0.3, H / 2 + c * 0.6)], WHITE, INK, 0.06)
        return
    b.poly([(L * 0.02, H * 0.42), (L * 0.6, H * 0.5), (L * 0.45, H * 0.56), (L * 0.75, H * 0.62), (L * 0.02, H * 0.6)],
           WHITE, INK, 0.08)


def sprinkles(b, vid):
    random.seed(BAY[vid] * 31 + len(b.side))
    cols = [(255, 90, 160, 255), (90, 200, 255, 255), YELLOW, (120, 220, 90, 255), WHITE, (180, 110, 255, 255)]
    n = int(b.L * b.H * 0.9)
    for _ in range(n):
        x, y = random.uniform(0, b.L), random.uniform(0, b.H)
        a = random.uniform(0, math.pi)
        dx, dy = math.cos(a) * 0.22, math.sin(a) * 0.22
        b.line([(x - dx, y - dy), (x + dx, y + dy)], random.choice(cols), 0.12)


def crest(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    cx, cy, s = L * 0.5, H * 0.55, H * 0.13
    b.poly([(cx - s, cy - s), (cx + s, cy - s), (cx + s, cy + s * 0.3), (cx, cy + s * 1.3), (cx - s, cy + s * 0.3)],
           GOLD, INK, 0.1)
    b.text(cx, cy, s * 1.0, "13", INK)


def wings(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    for i in range(6):
        y = H * (0.35 + i * 0.05)
        b.poly([(L * 0.1, H * 0.35), (L * (0.95 - i * 0.08), y), (L * (0.9 - i * 0.08), y + H * 0.04),
                (L * 0.1, H * 0.42)], WHITE if i % 2 == 0 else GOLD)


def hazard(b, vid):
    L, H = b.L, b.H
    if b.side == "top":
        return
    y0, y1 = H * 0.55, H * 0.75
    w = (y1 - y0)
    x = -w
    while x < L:
        b.poly([(x, y1), (x + w * 0.6, y1), (x + w * 1.6, y0), (x + w, y0)], INK)
        x += w * 1.5


def shark(b, vid):
    if b.side == "top":
        return
    L, H = b.L, b.H
    x0, x1, y0, y1 = L * 0.02, L * 0.3, H * 0.45, H * 0.72
    b.poly([(x0, (y0 + y1) / 2), (x1, y0), (x1, y1)], (150, 20, 30, 255))
    n = 6
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        xa, xb = x0 + (x1 - x0) * t0, x0 + (x1 - x0) * t1
        ya = (y0 + y1) / 2 + ((y0 - (y0 + y1) / 2) * t0)
        yb = (y0 + y1) / 2 + ((y0 - (y0 + y1) / 2) * t1)
        b.poly([(xa, ya), (xb, yb), ((xa + xb) / 2, ya + (y1 - y0) * 0.18)], WHITE)
        ya2 = (y0 + y1) / 2 + ((y1 - (y0 + y1) / 2) * t0)
        yb2 = (y0 + y1) / 2 + ((y1 - (y0 + y1) / 2) * t1)
        b.poly([(xa, ya2), (xb, yb2), ((xa + xb) / 2, ya2 - (y1 - y0) * 0.18)], WHITE)
    b.circle(L * 0.33, H * 0.38, H * 0.05, WHITE, INK, 0.05)
    b.circle(L * 0.335, H * 0.38, H * 0.025, INK)


def tricolore(b, vid):
    L, H = b.L, b.H
    cols = [(40, 160, 70, 255), WHITE, (210, 40, 40, 255)]
    if b.side == "top":
        for i, c in enumerate(cols):
            b.rect(0, H / 2 - 0.9 + i * 0.6, L, H / 2 - 0.3 + i * 0.6, c)
        return
    for i, c in enumerate(cols):
        y = H * 0.5 + i * 0.35
        b.poly([(0, y), (L, y - 0.6), (L, y - 0.25), (0, y + 0.35)], c)


def galaxy(b, vid):
    random.seed(99 + len(b.side))
    base = Image.new("RGBA", b.img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    for _ in range(int(b.L * b.H * 0.6)):
        x, y = random.uniform(0, b.L), random.uniform(0, b.H)
        r = random.uniform(0.6, 1.8)
        c = random.choice([(60, 30, 120, 70), (30, 50, 140, 70), (120, 40, 140, 60)])
        d.ellipse([x * K - r * K, y * K - r * K, x * K + r * K, y * K + r * K], fill=c)
    b.img.alpha_composite(base)
    for _ in range(int(b.L * b.H * 1.5)):
        x, y = random.uniform(0, b.L), random.uniform(0, b.H)
        b.circle(x, y, random.uniform(0.03, 0.09), WHITE)


SIGNATURE = {"Hatchback": lightning, "Scooter": pizza, "Cart": mega_mart, "Sedan": pinstripe, "Taxi": dice,
             "Muscle": thunder, "IceCream": sprinkles, "FireTruck": crest, "Semi": wings, "Bulldozer": hazard,
             "Monster": shark, "Supercar": tricolore, "Roadster": galaxy}
DECALS = {"Stripes": stripes, "Number": number, "Flames": flames, "Checker": checker}


def draw(vid, design):
    x0, y0, z0, x1, y1, z1 = BOXES[vid]
    L, W, H = y1 - y0, x1 - x0, z1 - z0
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for side in ("left", "right", "top"):
        b = Band(side, L, W if side == "top" else H)
        design(b, vid)
        # the band's content rows (vehicle_upgrades.decal_uvs: 0.004 margins on u, 0.004 + 0.02 on each band's v)
        base = {"left": 2 / 3, "right": 1 / 3, "top": 0}[side]
        y_top = round((1 - (base + 0.004 + 0.976 / 3)) * SIZE)
        height = round(0.976 / 3 * SIZE)
        out.alpha_composite(b.img.resize((round(SIZE * 0.992), height), Image.LANCZOS), (round(SIZE * 0.004), y_top))
    out.putpixel((int(0.003 * SIZE), SIZE - 1 - int(0.003 * SIZE)), (0, 0, 0, 0))
    return out


names = []
for vid in BAY:
    for name, fn in list(DECALS.items()) + [("Signature", SIGNATURE[vid])]:
        im = draw(vid, fn)
        p = os.path.join(outdir, f"{vid}_{name}.png")
        im.save(p)
        names.append(p)
print("DECALS", len(names), "images in", outdir)
if preview:
    tiles = [Image.open(p) for p in names]
    cols = 5
    sheet = Image.new("RGBA", (cols * 256, math.ceil(len(tiles) / cols) * 256), (90, 110, 160, 255))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t.resize((256, 256)), ((i % cols) * 256, (i // cols) * 256))
    sheet.save(preview)
