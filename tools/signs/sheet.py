# The mockup sheet: every sign drawn on a flat cartoon front of its building or stand, one <section> per page.
import re

from emblems import INK

SKY = "#bfe6ff"
GROUND = "#5b5d63"
Z = 1.45  # scenes drawn at 1.45x


def r(x, y, w, h, fill, sw=3, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{INK}" stroke-width="{sw}" {extra}/>'


def put(svg, x, y, w, h=None, aspect=None):
    # place a built sign (its 0 0 W 200 viewBox) at x, y with width w; height from its own aspect
    m = re.search(r'viewBox="0 0 ([\d.]+) 200"', svg)
    vw = float(m.group(1))
    if h is None:
        h = w * 200 / vw
    inner = svg[svg.index(">") + 1 : svg.rindex("</svg>")]
    return (
        f'<rect x="{x + 3}" y="{y + 3}" width="{w}" height="{h}" fill="{INK}"/>'
        f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="0 0 {vw} 200" preserveAspectRatio="none">{inner}</svg>'
    )


def scene(body, caption, w=420, h=300):
    return (
        f'<figure><svg viewBox="0 0 {w} {h}" width="{w * Z}" height="{h * Z}">'
        f'<rect width="{w}" height="{h}" fill="{SKY}"/><rect y="{h - 34}" width="{w}" height="34" fill="{GROUND}"/>'
        f'<path d="M0,{h - 17} H{w}" stroke="#ffd000" stroke-width="3" stroke-dasharray="18 12"/>'
        f"{body}</svg><figcaption>{caption}</figcaption></figure>"
    )


def stall(sign, colour):
    b = [r(110, 196, 200, 70, "#f4f1e8"), r(110, 196, 200, 14, colour)]
    for k in range(8):
        b.append(r(96 + k * 28.5, 120, 28.5, 26, colour if k % 2 == 0 else "#fafafa", 2))
    b += [r(118, 146, 8, 50, "#46464e", 2), r(294, 146, 8, 50, "#46464e", 2)]
    b.append(put(sign, 100, 66, 220))
    return "".join(b)


def shop(sign, accent):
    b = [r(70, 40, 280, 226, "#c9775a"), r(66, 34, 288, 12, "#e8e2d6")]
    b += [r(100, 150, 120, 80, "#9fd4ff"), r(250, 160, 60, 106, "#6b4a2e")]
    for k in range(7):
        b.append(f'<path d="M{80 + k * 38},128 h38 l-6,22 h-38z" fill="{accent if k % 2 == 0 else "#fafafa"}" '
                 f'stroke="{INK}" stroke-width="2"/>')
    b.append(r(30, 88, 50, 5, "#46464e", 2))
    b.append(put(sign, 10, 96, 150))
    return "".join(b)


def office(sign, ad):
    b = [r(40, 110, 340, 160, "#7d8796"), r(34, 100, 352, 14, "#e8e2d6")]
    for row in range(3):
        for col in range(7):
            b.append(r(56 + col * 46, 160 + row * 34, 34, 24, "#bfe0ff", 2))
    b.append(put(sign, 60, 116, 300))
    b += [r(130, 60, 6, 40, "#46464e", 2), r(284, 60, 6, 40, "#46464e", 2)]
    b.append(put(ad, 110, 6, 200))
    return "".join(b)


def billboard(sign):
    b = [r(140, 170, 10, 96, "#46464e", 2), r(270, 170, 10, 96, "#46464e", 2)]
    b.append(put(sign, 50, 60, 320))
    return "".join(b)


def barn(signs):
    b = [f'<path d="M60,266 V130 L90,80 L150,56 L210,80 L240,130 V266 Z" fill="#c8402c" stroke="{INK}" stroke-width="3"/>']
    b.append(put(signs["BarnLoft"], 112, 92, 76))
    b += [r(118, 186, 64, 80, "#fafafa"), r(56, 160, 188, 8, "#4a4a50", 2)]
    b += [r(250, 140, 150, 8, "#4a4a50", 2), r(392, 148, 6, 118, "#e8e2d6", 2)]
    b.append(put(signs["BarnDrive"], 260, 118, 130))
    b.append(put(signs["BarnMenu"], 270, 180, 120))
    b += [r(470, 120, 10, 146, "#46464e", 2)]
    b.append(put(signs["BarnPole"], 420, 40, 110))
    return "".join(b)


def warehouse(sign):
    b = [r(20, 110, 380, 156, "#a7adb6"), r(14, 100, 392, 12, "#e8e2d6")]
    for k in range(4):
        b.append(r(40 + k * 92, 196, 72, 70, "#d6d9de", 2))
    b.append(put(sign, 34, 124, 352))
    return "".join(b)


def hero(sign):
    b = [r(110, 120, 200, 150, "#3b4a6b"), r(100, 112, 220, 10, "#e8e2d6")]
    for row in range(4):
        for col in range(5):
            b.append(r(124 + col * 38, 140 + row * 30, 26, 20, "#ffe9a0", 2))
    b.append(put(sign, 30, 20, 360))
    return "".join(b)


def gas(signs):
    b = [r(20, 120, 230, 14, "#e8e2d6"), r(20, 132, 230, 8, "#e8383c", 2)]
    b += [r(50, 140, 10, 126, "#e8e2d6", 2), r(210, 140, 10, 126, "#e8e2d6", 2), r(120, 210, 30, 56, "#e8383c")]
    b += [r(330, 140, 12, 126, "#e8383c", 2)]
    b.append(put(signs["Gas"], 286, 36, 100))
    b.append(put(signs["GasPrice"], 296, 92, 80))
    return "".join(b)


def mart(sign):
    b = [r(60, 120, 300, 146, "#e8e2d6"), r(54, 112, 312, 12, "#e8383c")]
    b += [r(90, 180, 140, 70, "#9fd4ff"), r(260, 176, 60, 90, "#6b4a2e")]
    b.append(put(sign, 90, 134, 240))
    return "".join(b)


def gate(sign, colour):
    b = [r(40, 80, 16, 186, colour, 2), r(364, 80, 16, 186, colour, 2)]
    b.append(put(sign, 30, 50, 360))
    return "".join(b)


def hoarding(sign):
    b = [r(0, 170, 420, 96, "#2f3a52")]
    b.append(put(sign, -40, 186, 250))
    b.append(put(sign, 210, 186, 250))
    b += [r(-5, 120, 425, 8, "#ffd000", 2)]
    return "".join(b)


def suburb(sign):
    b = [r(20, 140, 40, 126, "#8f8a80"), r(360, 140, 40, 126, "#8f8a80"), r(14, 132, 52, 10, "#c9c4b8"),
         r(354, 132, 52, 10, "#c9c4b8")]
    b.append(put(sign, 50, 150, 320))
    return "".join(b)


def section(title, figs):
    return f'<section><h1>{title}</h1><div class="grid">{"".join(figs)}</div></section>'


def sheet_html(built, specs, _fit):
    colour = {sid: s["bg"] for sid, s in specs.items()}
    ads = [k for k in built if k.startswith("Ad_")]
    offices = [k for k in built if k.startswith("Office_")]
    shops = [k for k in built if k.startswith("Shop_")]
    stalls = [k for k in built if k.startswith("Stall_")]
    name = lambda k: k.split("_", 1)[-1]  # noqa: E731
    p1 = [scene(stall(built[k], colour[k]), f"Spawn stall: {name(k)}") for k in stalls]
    p1 += [
        scene(barn(built), "Burger Barn: loft, pole sign, drive-thru, menu", 540),
        scene(warehouse(built["ParcelPlanet"]), "Parcel Planet warehouse"),
        scene(hero(built["Hero"]), "Hero tower over spawn"),
    ]
    p2 = [scene(office(built[k], built[ads[i % len(ads)]]), f"Office: {name(k)} (roof ad: {name(ads[i % len(ads)])})")
          for i, k in enumerate(offices)]
    p3 = [scene(shop(built[k], colour[k]), f"Shop: {name(k)}") for k in shops]
    p4 = [scene(billboard(built[k]), f"Billboard: {name(k)}") for k in ads]
    p5 = [
        scene(gas(built), "Gas station pylon"),
        scene(mart(built["Mart"]), "Gas station shop"),
        scene(gate(built["Motocross"], "#ff8a1f"), "Motocross gate"),
        scene(gate(built["StuntPark"], "#e8383c"), "Stunt park gate"),
        scene(hoarding(built["Hoard_MEGACORP TOWER"]), "Building site hoarding (repeats along the fence)"),
        scene(hoarding(built["Hoard_COMING SOON"]), "Building site hoarding, other side"),
    ] + [scene(suburb(built[k]), f"Suburb entrance: {name(k)}") for k in built if k.startswith("Suburb_")]
    style = (
        "<style>body{background:#16161a;font-family:Mont,sans-serif}section{padding:24px;width:1340px;box-sizing:border-box}"
        "h1{font-family:Lucky;color:#ffd000;font-size:40px;margin:0 0 16px;letter-spacing:1px;"
        "text-shadow:3px 3px 0 #000}.grid{display:flex;flex-wrap:wrap;gap:18px}figure{margin:0;background:#26262c;"
        "padding:8px;border:3px solid #000;box-shadow:5px 5px 0 #000}figcaption{color:#fff;font-size:15px;"
        "padding:6px 2px 0}</style>"
    )
    return style + "".join(
        [
            section("1 · Stalls, Burger Barn, warehouse, hero tower", p1),
            section("2 · Offices (name sign + roof billboard)", p2),
            section("3 · High-street shops (hanging signs)", p3),
            section("4 · Billboards", p4),
            section("5 · Country road, outskirts, suburbs", p5),
        ]
    )
