# Draw the map's building and stand signs as brand-style artwork in the Road Paint look (bold cartoon emblems
# with ink outlines, Luckiest Guy lettering with an ink edge and a hard ink shadow down-right, bright paint), as
# SVG rendered to PNG with Playwright's Chromium. Each image has the aspect of the board it covers, so a Decal
# stretched over the board's face shows it undistorted.
#   python signs.py <out_dir>            one PNG per sign (<id>.png) plus signs.json (id -> board size)
#   python signs.py <out_dir> --sheet    also sheet.png, every sign shown on its building or stand
# Fonts come from the Roblox install (content/fonts) unless ROBLOX_FONTS names another folder.
import base64
import glob
import html
import json
import os
import pathlib
import re
import sys

from playwright.sync_api import sync_playwright

from emblems import EMBLEMS, INK
from specs import SIGNS

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
SHEET = "--sheet" in sys.argv


def font_dir() -> pathlib.Path:
    if os.environ.get("ROBLOX_FONTS"):
        return pathlib.Path(os.environ["ROBLOX_FONTS"])
    local = os.environ.get("LOCALAPPDATA", "")
    found = sorted(glob.glob(os.path.join(local, "Roblox", "Versions", "*", "content", "fonts")))
    if not found:
        sys.exit("no Roblox fonts folder found; set ROBLOX_FONTS")
    return pathlib.Path(found[-1])


def face(name: str, file: str) -> str:
    data = base64.b64encode((font_dir() / file).read_bytes()).decode()
    return f"@font-face{{font-family:{name};src:url(data:font/ttf;base64,{data})}}"


FONTS = face("Lucky", "LuckiestGuy-Regular.ttf") + face("Mont", "Montserrat-Black.ttf")

DEFS = f"""<defs>
<filter id="sh" x="-20%" y="-20%" width="140%" height="140%">
  <feOffset in="SourceAlpha" dx="5" dy="5" result="o"/><feFlood flood-color="{INK}"/>
  <feComposite in2="o" operator="in" result="s"/><feMerge><feMergeNode in="s"/><feMergeNode in="SourceGraphic"/></feMerge>
</filter>
<filter id="shs" x="-20%" y="-20%" width="140%" height="140%">
  <feOffset in="SourceAlpha" dx="3" dy="3" result="o"/><feFlood flood-color="{INK}"/>
  <feComposite in2="o" operator="in" result="s"/><feMerge><feMergeNode in="s"/><feMergeNode in="SourceGraphic"/></feMerge>
</filter>
<pattern id="check" width="40" height="40" patternUnits="userSpaceOnUse">
  <rect width="40" height="40" fill="#fff"/><rect width="20" height="20" fill="{INK}"/><rect x="20" y="20" width="20" height="20" fill="{INK}"/>
</pattern>
<pattern id="hazard" width="44" height="44" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
  <rect width="44" height="44" fill="#ffd000"/><rect width="22" height="44" fill="{INK}"/>
</pattern>
</defs>"""

H = 200  # every sign is 200 units tall; its width follows the board's aspect


def tint(hex_colour: str, amount: float) -> str:
    # towards white (amount > 0) or black (amount < 0)
    c = [int(hex_colour[i : i + 2], 16) for i in (1, 3, 5)]
    t = 255 if amount > 0 else 0
    a = abs(amount)
    return "#" + "".join(f"{round(v + (t - v) * a):02x}" for v in c)


def backdrop(spec, W):
    bg = spec["bg"]
    out = [f'<rect width="{W}" height="{H}" fill="{bg}"/>']
    pat = spec.get("pattern")
    if pat == "stripes":
        light = tint(bg, 0.12)
        for x in range(-H, int(W) + H, 36):
            out.append(f'<path d="M{x},{H} L{x + H},0 H{x + H + 16} L{x + 16},{H}Z" fill="{light}"/>')
    elif pat == "rays":
        light = tint(bg, 0.14)
        cx, cy = spec.get("rays_at", (W / 2, H * 0.55))
        r = max(W, H) * 1.2
        import math

        for k in range(0, 24, 2):
            a0, a1 = k * math.pi / 12, (k + 1) * math.pi / 12
            out.append(
                f'<path d="M{cx},{cy} L{cx + r * math.cos(a0)},{cy + r * math.sin(a0)} '
                f'L{cx + r * math.cos(a1)},{cy + r * math.sin(a1)}Z" fill="{light}"/>'
            )
    elif pat == "dots":
        light = tint(bg, 0.12)
        for y in range(10, H, 28):
            for x in range(10 + (y // 28 % 2) * 14, int(W), 28):
                out.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{light}"/>')
    elif pat == "check":
        out.append(f'<rect width="{W}" height="34" fill="url(#check)"/>')
        out.append(f'<rect y="{H - 34}" width="{W}" height="34" fill="url(#check)"/>')
    elif pat == "hazard":
        out.append(f'<rect width="{W}" height="{H}" fill="url(#hazard)"/>')
        out.append(f'<rect x="26" y="26" width="{W - 52}" height="{H - 52}" fill="{bg}" stroke="{INK}" stroke-width="6"/>')
    elif pat == "grid":
        light = tint(bg, 0.1)
        for x in range(0, int(W), 30):
            out.append(f'<path d="M{x},0V{H}" stroke="{light}" stroke-width="3"/>')
        for y in range(0, H, 30):
            out.append(f'<path d="M0,{y}H{W}" stroke="{light}" stroke-width="3"/>')
    band = spec.get("band")
    if band:
        out.append(f'<rect y="{H - 46}" width="{W}" height="46" fill="{band}"/>')
        out.append(f'<path d="M0,{H - 46}H{W}" stroke="{INK}" stroke-width="5"/>')
    # the frame: an ink edge with a thin inner line in the sign's trim colour
    trim = spec.get("trim", "#ffffff")
    out.append(f'<rect x="5" y="5" width="{W - 10}" height="{H - 10}" fill="none" stroke="{INK}" stroke-width="10"/>')
    if spec.get("lane"):
        out.append(
            f'<rect x="18" y="18" width="{W - 36}" height="{H - 36}" fill="none" stroke="{trim}" '
            f'stroke-width="5" stroke-dasharray="26 16"/>'
        )
    else:
        out.append(f'<rect x="17" y="17" width="{W - 34}" height="{H - 34}" fill="none" stroke="{trim}" stroke-width="4"/>')
    return "".join(out)


def emblem(name, cx, cy, size):
    s = size / 110
    return f'<g filter="url(#sh)" transform="translate({cx},{cy}) scale({s})">{EMBLEMS[name]}</g>'


def text_block(line, cx, cy, w, h):
    font = line.get("font", "lucky")
    fill = line.get("fill", "#ffffff")
    stroke = line.get("stroke", INK)
    family = "Lucky" if font == "lucky" else "Mont"
    skew = ' transform="skewX(-10)"' if font == "mont" else ""
    sw = line.get("edge", 7)
    tilt = line.get("tilt", 0)
    t = (
        f'<text x="0" y="0" font-family="{family}" font-size="100" fill="{fill}" stroke="{stroke}" '
        f'stroke-linejoin="round" paint-order="stroke" text-anchor="middle"{skew}>{html.escape(line["text"])}</text>'
    )
    return (
        f'<g filter="url(#{"sh" if h > 40 else "shs"})" transform="rotate({tilt},{cx},{cy})">'
        f'<g class="fit" data-cx="{cx}" data-cy="{cy}" data-w="{w}" data-h="{h}" data-stroke="{sw}">{t}</g></g>'
    )


def build(spec):
    W = H * spec["size"][0] / spec["size"][1]
    pad = 26
    parts = [backdrop(spec, W)]
    lines = spec["lines"]
    pos = spec.get("emblem_at", "left") if spec.get("emblem") else "none"
    weights = [ln.get("weight", 1) for ln in lines]
    if pos == "top":
        es = H * spec.get("emblem_size", 0.5)
        parts.append(emblem(spec["emblem"], W / 2, pad + es / 2, es))
        tx0, tx1, ty0, ty1 = pad, W - pad, pad + es + 4, H - pad
    elif pos in ("left", "both", "right"):
        es = min(H - 2 * pad + 10, W * 0.32) * spec.get("emblem_scale", 1)
        gap = spec.get("gap", 10)
        tx0, tx1, ty0, ty1 = pad, W - pad, pad, H - pad
        if pos in ("left", "both"):
            parts.append(emblem(spec["emblem"], pad + es / 2, H / 2, es))
            tx0 = pad + es + gap
        if pos in ("right", "both"):
            other = spec.get("emblem2", spec["emblem"])
            parts.append(emblem(other, W - pad - es / 2, H / 2, es))
            tx1 = W - pad - es - gap
    else:
        tx0, tx1, ty0, ty1 = pad, W - pad, pad, H - pad
    if spec.get("band"):
        ty1 = min(ty1, H - 50)
    total = sum(weights)
    y = ty0
    for line, wt in zip(lines, weights):
        lh = (ty1 - ty0) * wt / total
        parts.append(text_block(line, (tx0 + tx1) / 2, y + lh / 2, (tx1 - tx0) * line.get("wide", 0.96), lh * 0.95))
        y += lh
    if spec.get("band_text"):
        parts.append(text_block(spec["band_text"], W / 2, H - 23, W * 0.8, 28))
    return W, f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">{DEFS}{"".join(parts)}</svg>'


FIT_JS = """() => {
  for (const g of document.querySelectorAll('g.fit')) {
    const b = g.getBBox();
    const d = g.dataset;
    const s = Math.min(+d.w / b.width, +d.h / b.height);
    g.setAttribute('transform', `translate(${d.cx},${d.cy}) scale(${s}) translate(${-(b.x + b.width / 2)},${-(b.y + b.height / 2)})`);
    for (const t of g.querySelectorAll('text')) t.setAttribute('stroke-width', (+d.stroke * 2) / s);
  }
}"""


def page_html(body: str) -> str:
    return (
        f"<html><head><style>{FONTS} body{{margin:0;background:transparent}} svg{{display:block}}</style></head>"
        f"<body>{body}</body></html>"
    )


def render(page, svg: str, px_w: int, px_h: int, path: pathlib.Path):
    svg = svg.replace("<svg ", f'<svg width="{px_w}" height="{px_h}" ', 1)
    page.set_viewport_size({"width": px_w, "height": px_h})
    page.set_content(page_html(svg))
    page.evaluate("document.fonts.ready")
    page.evaluate(FIT_JS)
    page.locator("svg").first.screenshot(path=str(path))


def fname(sid: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", sid).strip("_")


def pixels(size):
    # the long side 1024 for big boards, 512 for small ones (shop and stall signs)
    long_side = 1024 if max(size) >= 15 else 512
    w, h = size
    if w >= h:
        return long_side, max(16, round(long_side * h / w))
    return max(16, round(long_side * w / h)), long_side


def main():
    index = {}
    built = {}
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        for sid, spec in SIGNS.items():
            _, svg = build(spec)
            pw, ph = pixels(spec["size"])
            render(page, svg, pw, ph, OUT / f"{fname(sid)}.png")
            index[sid] = {"file": fname(sid) + ".png", "size": spec["size"], "px": [pw, ph], "group": spec["group"]}
            built[sid] = svg
            print(OUT / f"{fname(sid)}.png")
        (OUT / "signs.json").write_text(json.dumps(index, indent=1))
        if SHEET:
            from sheet import sheet_html

            html = sheet_html(built, SIGNS, FIT_JS)
            page.set_viewport_size({"width": 1600, "height": 900})
            page.set_content(page_html(html))
            page.evaluate("document.fonts.ready")
            page.evaluate(FIT_JS)
            for k, el in enumerate(page.locator("section").all()):
                el.screenshot(path=str(OUT / f"sheet{k + 1}.png"))
                print(OUT / f"sheet{k + 1}.png")
        browser.close()


main()
