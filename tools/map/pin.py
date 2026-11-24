"""Draws the city map's player marker (Config/CityMap.Pin): a map pin, white so the game tints it (yellow for
friends, white for everyone else), with an ink outline and an ink hole that tinting leaves dark. The pin's tip
is the bottom middle of the square picture, so the game anchors it at (0.5, 1).

    python tools/map/pin.py <out.png>
"""
import math
import sys

from PIL import Image, ImageDraw

SIZE = 256
SS = 4  # drawn this many times bigger, then shrunk, for smooth edges
INK = (16, 16, 18, 255)
WHITE = (255, 255, 255, 255)


def pin(draw: ImageDraw.ImageDraw, cx: float, head_y: float, r: float, tip_y: float, fill) -> None:
    # the round head and the two straight sides down to the tip
    draw.ellipse((cx - r, head_y - r, cx + r, head_y + r), fill=fill)
    # the sides meet the head where tangents from the tip touch it
    d = tip_y - head_y
    a = math.asin(r / d)
    t = math.pi / 2 - a  # angle from straight down to the tangent point, seen from the centre
    lx, ly = cx - r * math.sin(t), head_y + r * math.cos(t)
    rx, ry = cx + r * math.sin(t), head_y + r * math.cos(t)
    draw.polygon([(lx, ly), (rx, ry), (cx, tip_y)], fill=fill)


def main(out: str) -> None:
    n = SIZE * SS
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = n / 2
    edge = 16 * SS
    head_r = 72 * SS
    head_y = (4 * SS) + head_r + edge
    tip_y = n - 2 * SS
    pin(d, cx, head_y, head_r + edge, tip_y, INK)
    pin(d, cx, head_y, head_r, tip_y - edge * 1.6, WHITE)
    hole = 28 * SS
    d.ellipse((cx - hole, head_y - hole, cx + hole, head_y + hole), fill=INK)
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    im.save(out)
    print("wrote", out, im.size)


if __name__ == "__main__":
    main(sys.argv[1])
