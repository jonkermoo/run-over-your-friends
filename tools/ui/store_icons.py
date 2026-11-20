# Draw the store's pass and product pictures in the Road Paint style (ink outline, hard ink shadow down-right),
# as SVG rendered to PNGs with Playwright's Chromium, like icons.py.
#   card_<pass>.png     256 px, transparent: the icon on the pass's card in the in-game store (full colour)
#   store_<item>.png    512 px, square poster: the image on the pass's / product's Roblox store page and in
#                       Roblox's buy prompt. Roblox crops pass images to a circle in places, so the drawing stays
#                       inside the middle circle and the background runs to the corners.
# Passes: vip (gold crown), roadster (the red Roadster with its rear jet), doublemoney (cash with a 2x sticker).
# Products: cash1..cash4 (a stack of bills that grows with the pack), starter (a gift box full of cash).
# Words use Luckiest Guy (the game's display font, SIL Open Font License) from Google Fonts.
#   python store_icons.py <out_dir>
import pathlib
import sys

from playwright.sync_api import sync_playwright

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
INK = "#101012"
FONT = "https://fonts.googleapis.com/css2?family=Luckiest+Guy&display=block"


# a shape filled with colour, with an ink outline and a hard ink shadow down-right
def paint(d: str, fill: str, width: float = 6, shadow: float = 6, extra: str = "") -> str:
    return (
        f'<path d="{d}" fill="{INK}" transform="translate({shadow},{shadow})"/>'
        f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{width}" stroke-linejoin="round" {extra}/>'
    )


def word(text: str, x: float, y: float, size: float, fill: str, width: float = 8, shadow: float = 6) -> str:
    style = f"font-family:'Luckiest Guy';font-size:{size}px;text-anchor:middle"
    return (
        f'<text x="{x + shadow}" y="{y + shadow}" style="{style}" fill="{INK}" stroke="{INK}" '
        f'stroke-width="{width}" stroke-linejoin="round">{text}</text>'
        f'<text x="{x}" y="{y}" style="{style}" fill="{fill}" stroke="{INK}" stroke-width="{width}" '
        f'stroke-linejoin="round" paint-order="stroke">{text}</text>'
    )


# ---- drawings, each centred on 0,0 and about 120 units across


def crown() -> str:
    body = "M-46,26 L-52,-28 L-26,-2 L0,-40 L26,-2 L52,-28 L46,26 Z"
    band = "M-47,14 H47 V34 H-47 Z"
    return (
        paint(body, "#ffd000")
        + '<path d="M-40,18 L-44,-12 L-24,6 L0,-26 L24,6 L44,-12 L40,18" fill="none" stroke="#ffe873" '
        'stroke-width="4" stroke-linejoin="round"/>'
        + paint(band, "#e8a800", shadow=0)
        + "".join(
            f'<circle cx="{x}" cy="{y}" r="7" fill="#fff" stroke="{INK}" stroke-width="4"/>'
            for x, y in ((-52, -28), (0, -40), (52, -28))
        )
        + f'<circle cx="0" cy="24" r="7" fill="#ff2e2e" stroke="{INK}" stroke-width="3"/>'
        + "".join(
            f'<path d="M{x},17 L{x + 6},24 L{x},31 L{x - 6},24 Z" fill="#1f6bff" stroke="{INK}" '
            'stroke-width="3" stroke-linejoin="round"/>'
            for x in (-28, 28)
        )
    )


def roadster(flame: bool = True) -> str:
    body = (
        "M-58,14 C-62,6 -60,-2 -54,-6 L-34,-12 C-24,-20 -10,-24 4,-22 C14,-21 22,-16 30,-11 "
        "L52,-6 C60,-4 64,2 63,8 L62,13 C62,16 60,17 57,17 L-55,17 C-57,17 -58,16 -58,14 Z"
    )
    window = "M-30,-12 C-22,-18 -10,-21 2,-20 C12,-19 20,-15 26,-11 L-28,-9 Z"
    out = ""
    if flame:
        out += (
            f'<path d="M-58,0 L-78,4 L-70,8 L-82,12 L-58,12 Z" fill="#ff8a00" stroke="{INK}" stroke-width="4" '
            'stroke-linejoin="round"/>'
            '<path d="M-60,3 L-70,6 L-61,9 Z" fill="#ffe873"/>'
        )
    out += paint(body, "#ff2e2e")
    out += '<path d="M-54,10 L60,10 L59,14 L-55,14 Z" fill="#b81d1d"/>'
    out += f'<path d="{window}" fill="#1d2340" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
    out += '<path d="M-20,-14 C-12,-17 -4,-18 4,-18" fill="none" stroke="#5a6aa8" stroke-width="3"/>'
    out += f'<path d="M50,-3 L60,0 L58,3 L49,1 Z" fill="#fff" stroke="{INK}" stroke-width="2"/>'
    for x in (-34, 36):
        out += (
            f'<circle cx="{x}" cy="15" r="15" fill="{INK}"/>'
            f'<circle cx="{x}" cy="15" r="9" fill="#c8ccd4" stroke="{INK}" stroke-width="2"/>'
            + "".join(
                f'<path d="M{x},15 L{x + 8},15" stroke="#7a7e88" stroke-width="2.5" '
                f'transform="rotate({a} {x} 15)"/>'
                for a in range(0, 360, 60)
            )
            + f'<circle cx="{x}" cy="15" r="3" fill="{INK}"/>'
        )
    return out


def banknote(x: float, y: float, angle: float, scale: float = 1) -> str:
    return (
        f'<g transform="translate({x},{y}) rotate({angle}) scale({scale})">'
        f'<rect x="-38" y="-19" width="76" height="38" fill="{INK}" transform="translate(4,4)"/>'
        f'<rect x="-38" y="-19" width="76" height="38" fill="#2bdc5a" stroke="{INK}" stroke-width="4"/>'
        '<rect x="-31" y="-12" width="62" height="24" fill="none" stroke="#1aa043" stroke-width="3"/>'
        '<circle r="9" fill="#1aa043"/>'
        f'<text y="5.5" style="font-family:\'Luckiest Guy\';font-size:15px;text-anchor:middle" '
        'fill="#2bdc5a">$</text></g>'
    )


def burst(x: float, y: float, r: float, fill: str) -> str:
    import math

    pts = []
    for i in range(24):
        rr = r if i % 2 == 0 else r * 0.8
        a = math.pi * 2 * i / 24
        pts.append(f"{x + rr * math.cos(a):.1f},{y + rr * math.sin(a):.1f}")
    return paint("M" + " L".join(pts) + " Z", fill, width=4, shadow=4)


def double_money(text_size: float = 38) -> str:
    return (
        banknote(-10, 10, -14, 1.15)
        + banknote(-2, -8, 8, 1.15)
        + burst(30, -24, 34, "#ffd000")
        + word("2x", 31, -24 + text_size * 0.36, text_size, INK, width=0, shadow=0)
    )


def bills(n: int) -> str:
    spots = {
        1: [(0, 0, -10)],
        2: [(-14, 10, -10), (12, -10, 8)],
        3: [(-22, 16, -8), (22, 16, 6), (0, -14, -4)],
        4: [(-24, 26, -6), (24, 26, 6), (-12, 0, 4), (16, 0, -6), (0, -26, 2)],
    }[n]
    return "".join(banknote(x, y, a, 0.95) for x, y, a in spots)


def gift() -> str:
    box = "M-44,-6 H44 V44 H-44 Z"
    lid = "M-50,-22 H50 V-4 H-50 Z"
    return (
        banknote(-16, -30, -24, 0.8)
        + banknote(18, -32, 18, 0.8)
        + paint(box, "#ff2e2e")
        + paint(lid, "#ff2e2e", shadow=4)
        + f'<path d="M-9,-22 H9 V44 H-9 Z" fill="#ffd000" stroke="{INK}" stroke-width="4"/>'
        + f'<path d="M0,-22 C-10,-44 -36,-44 -30,-30 C-26,-22 -10,-22 0,-22 C10,-22 26,-22 30,-30 '
        f'C36,-44 10,-44 0,-22 Z" fill="#ffd000" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
    )


# ---- posters: a coloured square with sun rays, the drawing in the middle circle


def rays(colour: str) -> str:
    import math

    out = ""
    for i in range(16):
        a0 = math.pi * 2 * i / 16
        a1 = a0 + math.pi / 16
        out += (
            f'<path d="M0,0 L{400 * math.cos(a0):.1f},{400 * math.sin(a0):.1f} '
            f'L{400 * math.cos(a1):.1f},{400 * math.sin(a1):.1f} Z" fill="{colour}"/>'
        )
    return out


def poster(bg: str, ray: str, art: str, scale: float, dy: float = 0, under: str = "") -> str:
    return (
        f'<rect x="-256" y="-256" width="512" height="512" fill="{bg}"/>{rays(ray)}'
        f'<circle r="236" fill="none" stroke="{INK}" stroke-opacity="0.18" stroke-width="10"/>'
        f'{under}<g transform="translate(0,{dy}) scale({scale})">{art}</g>'
    )


ROAD = (
    f'<rect x="-256" y="96" width="512" height="160" fill="#26262b"/>'
    f'<rect x="-256" y="96" width="512" height="8" fill="{INK}"/>'
    + "".join(f'<rect x="{x}" y="166" width="54" height="12" fill="#ffd000"/>' for x in range(-250, 256, 96))
)

CARDS = {
    "vip": ("-66 -54 132 132", crown()),
    "roadster": ("-86 -82 152 152", roadster()),
    "doublemoney": ("-62 -64 130 130", double_money()),
}

STORE = {
    "vip": poster("#2a1a4a", "#3b2766", crown() + word("VIP", 0, 88, 40, "#ffd000", 7, 4), 2.5, -36),
    "roadster": poster("#1f6bff", "#4a88ff", roadster(), 3.0, 40, ROAD),
    "doublemoney": poster("#1aa043", "#22c053", double_money(), 2.9, 20),
    "cash1": poster("#1aa043", "#22c053", bills(1), 3.4),
    "cash2": poster("#1aa043", "#22c053", bills(2), 3.0),
    "cash3": poster("#1aa043", "#22c053", bills(3), 2.7),
    "cash4": poster("#1aa043", "#22c053", bills(4), 2.6),
    "starter": poster("#ffd000", "#ffe14d", gift(), 3.0, 10),
}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()

    def render(name: str, size: int, box: str, body: str, transparent: bool):
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{box}">{body}</svg>'
        page.set_viewport_size({"width": size, "height": size})
        page.set_content(
            f'<html><head><link rel="stylesheet" href="{FONT}"></head>'
            f'<body style="margin:0;background:transparent">{svg}</body></html>'
        )
        page.evaluate("document.fonts.load('40px \"Luckiest Guy\"', 'VIP2x$')")
        page.evaluate("document.fonts.ready")
        page.locator("svg").screenshot(path=str(OUT / f"{name}.png"), omit_background=transparent)
        print(OUT / f"{name}.png")

    for name, (box, body) in CARDS.items():
        render(f"card_{name}", 256, box, body, True)
    for name, body in STORE.items():
        render(f"store_{name}", 512, "-256 -256 512 512", body, False)
    browser.close()
