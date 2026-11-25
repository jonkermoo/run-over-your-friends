# Draw the Street Sign UI kit (panels, buttons, bolts, insets, bars, the hazard band, the tour bubble) as SVG
# and render each piece to a transparent PNG at 2x with Playwright's Chromium. The game places them as
# 9-slice ImageLabels (client/Style) with live text on top.
#   *_face.png  white with a soft gradient: the game tints it (ImageColor3) to the sign or button colour
#   *_trim_*.png the parts that keep their own colour (dark edge, white or black inner line, rivets, gloss),
#                drawn over the face
#   bubble.png  full colour (the garage tour's callout)
# Slice centres (image px) are in Config/Icons' Kit table; keep both in step.
#   python ui_kit.py <out_dir>
import pathlib
import sys

from playwright.sync_api import sync_playwright

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
INK = "#151515"


def rrect(x, y, w, h, r, **attrs):
    a = " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" {a}/>'


def rivet(cx, cy, r):
    return (
        f'<circle cx="{cx}" cy="{cy + 1}" r="{r + 1.5}" fill="#000" fill-opacity="0.35"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r + 1.2}" fill="#4b5056"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#steel)"/>'
        f'<circle cx="{cx - r * 0.3}" cy="{cy - r * 0.35}" r="{r * 0.38}" fill="#fff" fill-opacity="0.85"/>'
    )


DEFS = (
    "<defs>"
    '<linearGradient id="face" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d2d2d2"/></linearGradient>'
    '<linearGradient id="btn" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#e2e2e2"/></linearGradient>'
    '<linearGradient id="steel" x1="0" y1="0" x2="1" y2="1">'
    '<stop offset="0" stop-color="#f6f7f8"/><stop offset="1" stop-color="#8d959d"/></linearGradient>'
    '<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#fff" stop-opacity="0.38"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
    '<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#fff" stop-opacity="0.22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
    '<linearGradient id="well" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#000" stop-opacity="0.55"/><stop offset="0.35" stop-color="#000" stop-opacity="0.34"/>'
    '<stop offset="1" stop-color="#000" stop-opacity="0.30"/></linearGradient>'
    '<linearGradient id="bodyw" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#fbfbf7"/><stop offset="1" stop-color="#e9e9e2"/></linearGradient>'
    "</defs>"
)


# ---- panels: a sign face. big = 128 px, radius 22, rivets in the corners; small = 96 px, radius 16
def panel(size, r, line_in, line_w, rivets, line):
    s = size
    face = rrect(0, 0, s, s, r, fill="url(#face)")
    trim = (
        # dark edge (darkens whatever colour the face is tinted)
        rrect(1.75, 1.75, s - 3.5, s - 3.5, r - 1.5, fill="none", stroke="#000", stroke_opacity="0.6", stroke_width="3.5")
        # a soft sheen across the top and a shade along the bottom, inside the edge
        + rrect(4, 4, s - 8, s * 0.45, r - 4, fill="url(#sheen)")
        + rrect(line_in, line_in, s - line_in * 2, s - line_in * 2, r - line_in + 2, fill="none", stroke=line,
                stroke_width=line_w)
    )
    if rivets:
        for x, y in ((17, 17), (s - 17, 17), (17, s - 17), (s - 17, s - 17)):
            trim += rivet(x, y, 5.2)
    return face, trim


# ---- buttons: a sign plate 96 px, radius 16, with its own depth drawn in (a darker band along the bottom,
# inside the bounds: nothing hangs under the button)
BTN, BR, LIP = 96, 16, 9


def button(line):
    s = BTN
    face = (
        rrect(0, 0, s, s, BR, fill="#8a8a8a")  # the plate's thickness, seen along the bottom
        + rrect(0, 0, s, s - LIP, BR, fill="url(#btn)")
    )
    trim = (
        rrect(2, 2, s - 4, s - 4, BR - 1.5, fill="none", stroke=INK, stroke_width="4")
        + rrect(5, 5, s - 10, (s - LIP) * 0.42, BR - 5, fill="url(#gloss)")
        + rrect(7, 7, s - 14, s - 14 - LIP, BR - 6, fill="none", stroke=line, stroke_width="3", stroke_opacity="0.92")
        # a hairline where the face meets the thickness
        + f'<path d="M4 {s - LIP - 0.5}H{s - 4}" stroke="#000" stroke-opacity="0.35" stroke-width="1.5"/>'
    )
    return face, trim


def bolt():
    return rivet(16, 15, 9)


def exit_arrow():
    # the exit-sign arrow: a shaft up to the right and an open corner, white so the game tints it
    return (
        '<path d="M10 38 34 14" stroke="#fff" stroke-width="7.5" stroke-linecap="square"/>'
        '<path d="M17 11H37V31" fill="none" stroke="#fff" stroke-width="7.5" stroke-linejoin="miter"/>'
    )


def inset():
    s = 64
    return (
        rrect(0, 0, s, s, 14, fill="url(#well)")
        + rrect(1, 1, s - 2, s - 2, 13, fill="none", stroke="#fff", stroke_opacity="0.16", stroke_width="2")
        + rrect(3, 2, s - 6, 10, 8, fill="#000", fill_opacity="0.18")
    )


def bar_fill():
    s = 32
    return (
        rrect(0, 0, s, s, 8, fill="url(#face)")
        + rrect(2, 2, s - 4, s * 0.42, 6, fill="#fff", fill_opacity="0.55")
    )


def hazard():
    # one 56x28 tile of yellow and black stripes at 45 degrees; repeats seamlessly side by side
    w, h = 56, 28
    out = f'<rect width="{w}" height="{h}" fill="#ffc915"/>'
    for x0 in (-28, 0, 28, 56):
        out += f'<path d="M{x0} {h}L{x0 + h} 0H{x0 + h + 14}L{x0 + 14} {h}Z" fill="{INK}"/>'
    return out


# ---- the tour bubble: 200x180, a yellow title band, a white body, an ink edge and a tail at the bottom
# left pointing down and out
BW, BH, BHEAD, BTAIL = 200, 180, 88, 26


def bubble():
    body_h = BH - BTAIL
    r = 20
    tail = f'M28 {body_h - 4}L14 {BH - 2}L56 {body_h - 4}Z'
    clip = '<clipPath id="bb">' + rrect(4, 4, BW - 8, body_h - 8, r - 3) + "</clipPath>"
    return (
        f"<defs>{clip}</defs>"
        + f'<path d="{tail}" fill="{INK}" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
        + rrect(0, 0, BW, body_h, r, fill=INK)
        + f'<g clip-path="url(#bb)">'
        + f'<rect x="0" y="0" width="{BW}" height="{body_h}" fill="url(#bodyw)"/>'
        + f'<rect x="0" y="0" width="{BW}" height="{BHEAD}" fill="#ffc915"/>'
        + f'<rect x="0" y="0" width="{BW}" height="{BHEAD * 0.45}" fill="#fff" fill-opacity="0.22"/>'
        + f'<rect x="0" y="{BHEAD - 2}" width="{BW}" height="5" fill="{INK}"/>'
        + "</g>"
        + f'<path d="M29 {body_h - 8}L19 {BH - 8}L51 {body_h - 8}Z" fill="#e9e9e2"/>'
    )


big_face, big_light = panel(128, 22, 8, 4.4, True, "#fff")
_, big_dark = panel(128, 22, 8, 4.4, True, INK)
small_face, small_light = panel(96, 16, 6, 3.6, False, "#fff")
_, small_dark = panel(96, 16, 6, 3.6, False, INK)
btn_face, btn_light = button("#fff")
_, btn_dark = button(INK)

JOBS = {
    "panel_face": (128, 128, big_face),
    "panel_trim_light": (128, 128, big_light),
    "panel_trim_dark": (128, 128, big_dark),
    "plate_face": (96, 96, small_face),
    "plate_trim_light": (96, 96, small_light),
    "plate_trim_dark": (96, 96, small_dark),
    "button_face": (BTN, BTN, btn_face),
    "button_trim_light": (BTN, BTN, btn_light),
    "button_trim_dark": (BTN, BTN, btn_dark),
    "bolt": (32, 32, bolt()),
    "exit_arrow": (48, 48, exit_arrow()),
    "inset": (64, 64, inset()),
    "bar_fill": (32, 32, bar_fill()),
    "hazard": (56, 28, hazard()),
    "bubble": (BW, BH, bubble()),
}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(device_scale_factor=1)
    for name, (w, h, body) in JOBS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>'
        page.set_viewport_size({"width": w, "height": h})
        page.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
        page.locator("svg").screenshot(path=str(OUT / f"{name}.png"), omit_background=True)
        print(OUT / f"{name}.png")
    browser.close()
