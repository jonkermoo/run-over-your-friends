# Draw the HUD's shape images in the Road Paint style (ink outline, hard ink shadow down-right), as SVG
# rendered to transparent PNGs with Playwright's Chromium. Shapes meant to be tinted by the game
# (ImageColor3) are filled white: the tint colours the fill and the ink stays ink.
#   arrow.png    the guide's block arrow, pointing down, centred so it can turn about the image middle
#   pointer.png  the giant finder's wedge, pointing right
#   pin.png      a push-pin for pinned goals (white head, grey needle)
#   coin.png     a gold $ coin for the cash burst (full colour)
#   bill.png     a green banknote for the cash burst (full colour)
#   sign.png     a diamond warning sign with a "!" for the event chip
#   python icons.py <out_dir>
import pathlib
import sys

from playwright.sync_api import sync_playwright

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 256
INK = "#101012"

SHAPES = {
    "arrow": (
        "-80 -86 160 160",
        f"""<path id="s" d="M-26,-70 H26 V-10 H56 L0,58 L-56,-10 H-26 Z"/>
        <use href="#s" fill="{INK}" transform="translate(6,6)"/>
        <use href="#s" fill="#fff" stroke="{INK}" stroke-width="6" stroke-linejoin="miter"/>""",
    ),
    "pointer": (
        "-44 -42 88 88",
        f"""<path id="s" d="M-29,-28 L29,0 L-29,28 L-17,0 Z"/>
        <use href="#s" fill="{INK}" transform="translate(5,5)"/>
        <use href="#s" fill="#fff" stroke="{INK}" stroke-width="5" stroke-linejoin="miter"/>""",
    ),
    "pin": (
        "-74 -84 148 148",
        f"""<g transform="rotate(25) translate(0,-4)">
        <path id="s" d="M-30,-56 H30 L22,-40 V-6 L40,10 H-40 L-22,-6 V-40 Z"/>
        <use href="#s" fill="{INK}" transform="translate(5,5)"/>
        <path d="M-3,10 H3 L1,58 H-1Z" fill="#46464e" stroke="{INK}" stroke-width="3"/>
        <use href="#s" fill="#fff" stroke="{INK}" stroke-width="5" stroke-linejoin="miter"/></g>""",
    ),
    "coin": (
        "-40 -40 80 80",
        f"""<circle r="30" fill="{INK}" cx="4" cy="4"/>
        <circle r="30" fill="#ffd000" stroke="{INK}" stroke-width="5"/>
        <circle r="20" fill="none" stroke="#c99a00" stroke-width="4"/>
        <path d="M-3,-17 H3 V-13 H9 V-7 H-3 V-3 H7 V3 H9 V13 H3 V17 H-3 V13 H-9 V7 H3 V3 H-7 V-3 H-9 V-13 H-3 Z"
          fill="#8a6500"/>""",
    ),
    "bill": (
        "-46 -46 92 92",
        f"""<g transform="rotate(-12)">
        <rect x="-38" y="-19" width="76" height="38" fill="{INK}" transform="translate(4,4)"/>
        <rect x="-38" y="-19" width="76" height="38" fill="#2bdc5a" stroke="{INK}" stroke-width="4"/>
        <rect x="-31" y="-12" width="62" height="24" fill="none" stroke="#1aa043" stroke-width="3"/>
        <circle r="8" fill="#1aa043"/><circle r="4" fill="#2bdc5a"/></g>""",
    ),
    "sign": (
        "-37 -37 74 74",
        f"""<path id="s" d="M0,-28 L28,0 L0,28 L-28,0Z"/>
        <use href="#s" fill="{INK}" transform="translate(3,3)"/>
        <use href="#s" fill="#fff" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>
        <path d="M0,-21 L21,0 L0,21 L-21,0Z" fill="none" stroke="{INK}" stroke-width="2"/>
        <path d="M-3.5,-14 H3.5 L2,4 H-2 Z M-3.5,8 H3.5 V14 H-3.5 Z" fill="{INK}"/>""",
    ),
}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": SIZE, "height": SIZE})
    for name, (box, body) in SHAPES.items():
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="{box}">'
            f"<defs></defs>{body}</svg>"
        )
        page.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
        page.locator("svg").screenshot(path=str(OUT / f"{name}.png"), omit_background=True)
        print(OUT / f"{name}.png")
    browser.close()
