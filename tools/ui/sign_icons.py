# Draw the Street Sign pictograms (menu signs, touch buttons, chips) as SVG and render them to transparent
# PNGs with Playwright's Chromium. Each pictogram is a white shape whose details are cut out (an SVG mask),
# so the game can tint it (ImageColor3) and the sign colour shows through the cut-outs.
# stop.png is full colour: the stop-sign octagon alert badge (red, white rim, black edge), no words.
#   python sign_icons.py <out_dir>
import pathlib
import sys

from playwright.sync_api import sync_playwright

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 256
W, K = "#fff", "#000"  # inside a mask: white keeps, black cuts


def checks():
    q = ""
    for i in range(4):
        for j in range(3):
            if (i + j) % 2:
                q += f'<rect x="{13 + i * 6.5}" y="{9 + j * 6.67}" width="6.6" height="6.75" fill="{K}"/>'
    return q


# 48x48 boxes; shapes drawn in W with cut-outs in K
SHAPES = {
    "garage": f'<path d="M9 31 12.5 19.5Q13.6 16 17.5 16H30.5Q34.4 16 35.5 19.5L39 31V39H33.5V36H14.5V39H9Z" fill="{W}"/>'
    f'<path d="M15.5 21.5H32.5L34.3 28H13.7Z" fill="{K}"/><circle cx="15.5" cy="31.5" r="2.4" fill="{K}"/>'
    f'<circle cx="32.5" cy="31.5" r="2.4" fill="{K}"/><rect x="20" y="30.5" width="8" height="2.2" rx="1" fill="{K}"/>',
    "store": f'<path d="M10 17H38L36 41H12Z" fill="{W}"/>'
    f'<path d="M17.5 19V14.5Q17.5 8 24 8Q30.5 8 30.5 14.5V19" fill="none" stroke="{W}" stroke-width="3.4"/>'
    # a "$" drawn as an S curve and a bar
    f'<path d="M28 24.5Q27 22.5 24 22.5Q20.5 22.5 20.5 25.5Q20.5 28 24 28.5Q27.8 29 27.8 32Q27.8 35 24 35Q20.8 35 19.8 32.8" '
    f'fill="none" stroke="{K}" stroke-width="2.6" stroke-linecap="round"/>'
    f'<rect x="22.8" y="20" width="2.4" height="17.5" rx="1" fill="{K}"/>',
    "goals": f'<rect x="9.6" y="7" width="3.4" height="35" rx="1.5" fill="{W}"/><path d="M13 9H39V29H13Z" fill="{W}"/>{checks()}',
    "map": f'<path d="M7 13 18 9 30 13 41 9V35L30 39 18 35 7 39Z" fill="{W}"/>'
    f'<path d="M18 9V35M30 13V39" stroke="{K}" stroke-width="2"/>'
    f'<path d="M11 31Q16 22 22 26T37 16" fill="none" stroke="{K}" stroke-width="2.6" stroke-dasharray="3 2.6" stroke-linecap="round"/>',
    "invite": f'<circle cx="17" cy="16" r="6" fill="{W}"/><path d="M6 38Q6 25 17 25Q28 25 28 38Z" fill="{W}"/>'
    f'<circle cx="32" cy="18" r="5" fill="{W}"/><path d="M27 27Q36 24 42 30V38H31Q31 31 27 27Z" fill="{W}"/>',
    "tutorial": f'<circle cx="24" cy="24" r="18" fill="{W}"/>'
    f'<path d="M18.5 19Q18.5 13 24 13Q29.5 13 29.5 18.5Q29.5 21.5 26.5 23Q24 24.3 24 27.5V29" fill="none" stroke="{K}" '
    f'stroke-width="4.2" stroke-linecap="round"/><circle cx="24" cy="34.5" r="2.6" fill="{K}"/>',
    "settings": f'<path d="M33.5 7.5a9 9 0 0 0-9.6 12.2L9.2 34.4a3.6 3.6 0 0 0 5.1 5.1l14.7-14.7a9 9 0 0 0 12.2-9.6l-5.4 5.4-5.3-1.4-1.4-5.3z" fill="{W}"/>'
    f'<circle cx="11.8" cy="37" r="1.6" fill="{K}"/>',
    "boost": f'<path d="M7 11H15L27 24 15 37H7L19 24Z" fill="{W}"/><path d="M21 11H29L41 24 29 37H21L33 24Z" fill="{W}"/>',
    "horn": f'<path d="M6 19H14L29 9V39L14 29H6Z" fill="{W}"/>'
    f'<path d="M34 17Q38 24 34 31M38.5 13Q44.5 24 38.5 35" fill="none" stroke="{W}" stroke-width="3.2" stroke-linecap="round"/>',
    "view": f'<path d="M3 24Q24 4 45 24Q24 44 3 24Z" fill="{W}"/><circle cx="24" cy="24" r="8.5" fill="{K}"/>'
    f'<circle cx="24" cy="24" r="4" fill="{W}"/>',
    "unstuck": f'<g transform="rotate(-28 22 30)"><path d="M9 32 11.5 25Q12.5 23 15 23H29Q31.5 23 32.5 25L35 32V37H9Z" fill="{W}"/>'
    f'<circle cx="15" cy="37" r="3.4" fill="{W}" stroke="{K}" stroke-width="1.6"/>'
    f'<circle cx="29" cy="37" r="3.4" fill="{W}" stroke="{K}" stroke-width="1.6"/></g>'
    f'<path d="M27 7A15 15 0 0 1 40 19" fill="none" stroke="{W}" stroke-width="3.6" stroke-linecap="round"/>'
    f'<path d="M35 18H45L40 26Z" fill="{W}"/>',
    "gift": f'<rect x="9" y="20" width="30" height="20" fill="{W}"/><rect x="7" y="14" width="34" height="7" fill="{W}"/>'
    f'<rect x="22" y="14" width="4" height="26" fill="{K}"/>'
    f'<path d="M24 14Q14 4 13 10Q13 14 24 14Q35 14 35 10Q34 4 24 14Z" fill="none" stroke="{W}" stroke-width="2.6"/>',
}

STOP = (
    '<path d="M7.5 1.2h9l6.3 6.3v9l-6.3 6.3h-9l-6.3-6.3v-9z" fill="#151515"/>'
    '<path d="M7.9 2.4h8.2l5.5 5.5v8.2l-5.5 5.5H7.9l-5.5-5.5V7.9z" fill="#d7262b" stroke="#fff" stroke-width="1.4"/>'
)

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": SIZE, "height": SIZE})
    jobs = {
        name: (
            "0 0 48 48",
            f'<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="48" height="48">{body}</mask></defs>'
            '<rect width="48" height="48" fill="#fff" mask="url(#m)"/>',
        )
        for name, body in SHAPES.items()
    }
    jobs["stop"] = ("0 0 24 24", STOP)
    for name, (box, body) in jobs.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="{box}">{body}</svg>'
        page.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
        page.locator("svg").screenshot(path=str(OUT / f"{name}.png"), omit_background=True)
        print(OUT / f"{name}.png")
    browser.close()
