# The road UI's icons: chunky cartoon stickers, drawn as SVG on a 128 px grid and rendered to 256 px transparent
# PNGs with macOS `sips`. The style rules are in tools/ui/ICON_STYLE.md; this script enforces the ones it can
# (palette, opacity, line widths, one shine, size in the frame) and writes nothing if an icon breaks them.
#   python3 tools/ui/road_icons2.py <out_dir>   -> <out_dir>/<name>.svg, <out_dir>/png/<name>.png
import math
import pathlib
import re
import subprocess
import sys

# ---------------------------------------------------------------- the rules, as numbers

INK = "#161616"  # every outline and inner line
WHITE = "#ffffff"
OUT_W = 12  # the silhouette outline: drawn this wide under the fills, so 6 px of ink shows round the shape
DETAIL_W = 4  # inner lines in ink (windows, ribbon, rims, folds)
SEAM_W = 3  # soft seams in a material's own shade (planks, door lines)
SHINE = 0.6  # the one highlight: white at this opacity, top left
FILL_MIN, FILL_MAX = 100, 124  # the icon's longer side, in grid px, outline included (the grid is 128)
# every colour is one of these materials: base face and its shade (bottom / right, never a gradient)
MATERIALS = {
    "red": ("#ff3b30", "#d62a20"),
    "blue": ("#2e8bff", "#1d66cf"),
    "green": ("#19c24a", "#0e8a30"),
    "gold": ("#ffcc00", "#e0a400"),
    "orange": ("#ff7a1f", "#e8580a"),
    "pink": ("#ff6fb5", "#e0469a"),
    "black": ("#34363b", "#1f2024"),
    "white": ("#ffffff", "#e3e7eb"),
    "metal": ("#d5dbe1", "#a9b1ba"),
    "steel": ("#5c6168", "#43474d"),
    "glass": ("#bfe9ff", "#8fd3f5"),
    "paper": ("#fff1a8", "#f2db78"),
    "wood": ("#c97433", "#8e4a1c"),
}
ALLOWED = {INK, WHITE} | {c for pair in MATERIALS.values() for c in pair}
LINE_WIDTHS = {OUT_W, DETAIL_W, SEAM_W}  # plus the doubled strokes below (a fill width + 2 * DETAIL_W)


def base(m: str) -> str:
    return MATERIALS[m][0]


def shade(m: str) -> str:
    return MATERIALS[m][1]


# ---------------------------------------------------------------- drawing helpers (draw only with these)


def shape(tag: str, color: str, attrs: str) -> str:
    """A part of the silhouette; pass it to outline()."""
    return f'<{tag} {attrs} fill="{color}"/>'


def outline(*shapes: str) -> str:
    """One ink outline round the union of the shapes, then the shapes filled on top."""
    back = "".join(
        re.sub(r'fill="#[0-9a-f]{6}"', f'fill="{INK}"', s).replace(
            "/>", f' stroke="{INK}" stroke-width="{OUT_W}" stroke-linejoin="round"/>'
        )
        for s in shapes
    )
    return back + "".join(shapes)


def line(d: str, w: float = DETAIL_W, c: str = INK) -> str:
    return f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


def seam(d: str, m: str) -> str:
    return line(d, SEAM_W, shade(m))


def piece(tag: str, color: str, attrs: str) -> str:
    """A part inside the outline with its own thin ink edge (windows, bands, plates)."""
    return f'<{tag} {attrs} fill="{color}" stroke="{INK}" stroke-width="{DETAIL_W}" stroke-linejoin="round"/>'


def shine(cx: float, cy: float, rx: float, ry: float, angle: float = -35) -> str:
    """The icon's one highlight, top left."""
    return (
        f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({angle} {cx} {cy})" '
        f'fill="{WHITE}" opacity="{SHINE}"/>'
    )


def doubled(d: str, w: float, c: str) -> str:
    """A thick stroke with an ink edge (handles, the $, the X)."""
    LINE_WIDTHS.update({w, w + 2 * DETAIL_W})
    return line(d, w + 2 * DETAIL_W, INK) + line(d, w, c)


DOLLAR = "M76 50 Q72 42 64 42 Q52 42 52 52 Q52 60 64 62 Q76 64 76 74 Q76 84 64 84 Q54 84 50 76"


def dollar(color: str, dy: float = 0, scale: float = 1.0) -> str:
    t = f'transform="translate(64 {63 + dy}) scale({scale}) translate(-64 -63)"'
    # both ink edges first, then both colours, so the S and its bar read as one mark (no edge across the S)
    LINE_WIDTHS.update({6, 6 + 2 * DETAIL_W})
    ink = line(DOLLAR, 6 + 2 * DETAIL_W) + line("M64 36 V90", 6 + 2 * DETAIL_W)
    return f"<g {t}>" + ink + line(DOLLAR, 6, color) + line("M64 36 V90", 6, color) + "</g>"


def star_path(cx: float, cy: float, r1: float, r2: float) -> str:
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = r1 if i % 2 == 0 else r2
        pts.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


def octagon(cx: float, cy: float, r: float) -> str:
    pts = []
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4
        pts.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


# ---------------------------------------------------------------- cars, side on, facing right


def wheels(xs: tuple, y: float) -> str:
    return "".join(
        f'<circle cx="{x}" cy="{y}" r="15" fill="{INK}"/><circle cx="{x}" cy="{y}" r="7" fill="{base("metal")}"/>'
        for x in xs
    )


def lamps(y: float) -> str:
    return piece("rect", base("gold"), f'x="108" y="{y}" width="8" height="7" rx="2"') + piece(
        "rect", base("red"), f'x="13" y="{y}" width="6" height="7" rx="2"'
    )


def car(m: str, extra: str = "", top: str = "") -> str:
    body = (
        "M12 86 V72 Q12 62 22 60 L36 57 L46 40 Q50 33 58 33 H80 Q88 33 93 40 L104 56 L110 58 "
        "Q118 60 118 70 V86 Q118 94 110 94 H20 Q12 94 12 86 Z"
    )
    return (
        top
        + outline(shape("path", base(m), f'd="{body}"'))
        + f'<path d="M12 80 H118 V86 Q118 94 110 94 H20 Q12 94 12 86 Z" fill="{shade(m)}"/>'
        + piece("path", base("glass"), 'd="M49 56 L55 43 Q57 40 61 40 H66 V56 Z"')
        + piece("path", base("glass"), 'd="M72 40 H80 Q84 40 87 44 L95 56 H72 Z"')
        + seam("M69 60 V80", m)
        + extra
        + shine(40, 64, 18, 3.2, 0)
        + lamps(65)
        + wheels((38, 92), 94)
    )


def van(m: str) -> str:
    body = "M12 88 V44 Q12 30 26 30 H94 Q105 30 109 40 L118 62 V88 Q118 96 110 96 H20 Q12 96 12 88 Z"
    return (
        outline(shape("path", base(m), f'd="{body}"'))
        + f'<path d="M12 80 H118 V88 Q118 96 110 96 H20 Q12 96 12 88 Z" fill="{shade(m)}"/>'
        + "".join(piece("rect", base("glass"), f'x="{x}" y="38" width="22" height="20" rx="4"') for x in (20, 48))
        + piece("path", base("glass"), 'd="M78 38 H98 Q101 38 102 41 L110 60 H78 Z"')
        + shine(44, 66, 22, 3.2, 0)
        + lamps(66)
        + wheels((36, 94), 96)
    )


def roadster() -> str:
    body = (
        "M20 84 V74 Q20 66 28 64 L46 60 L60 46 Q64 42 70 42 H82 Q88 42 92 48 L100 58 L114 62 "
        "Q120 64 120 72 V84 Q120 92 112 92 H28 Q20 92 20 84 Z"
    )
    return (
        outline(
            shape("path", base("orange"), 'd="M22 68 L12 62 L16 73 L11 80 L22 80 Z"'),
            shape("path", base("red"), f'd="{body}"'),
        )
        + f'<path d="M22 71 L15 68 L18 74 L14 78 L22 78 Z" fill="{base("gold")}"/>'
        + f'<path d="M20 80 H120 V84 Q120 92 112 92 H28 Q20 92 20 84 Z" fill="{shade("red")}"/>'
        + piece("path", base("glass"), 'd="M66 58 L72 49 Q74 47 77 47 H82 Q85 47 87 50 L93 58 Z"')
        + seam("M62 64 V82", "red")
        + shine(42, 70, 16, 3, 0)
        + piece("rect", base("gold"), 'x="110" y="68" width="8" height="7" rx="2"')
        + wheels((40, 96), 92)
    )


TAXI_SIGN = outline(shape("rect", base("gold"), 'x="54" y="20" width="24" height="12" rx="3"')) + (
    f'<rect x="58" y="24" width="16" height="4" rx="2" fill="{INK}"/>'
)
CHECKS = "".join(f'<rect x="{14 + i * 8}" y="70" width="8" height="6" fill="{INK}"/>' for i in range(0, 13, 2))
STRIPES = (
    f'<rect x="12" y="66" width="106" height="4" fill="{base("gold")}"/>'
    f'<rect x="12" y="73" width="106" height="4" fill="{base("gold")}"/>'
)

# ---------------------------------------------------------------- the set

ICONS = {
    "car-red": car("red"),
    "car-blue": car("blue"),
    "car-green": car("green"),
    "car-yellow": car("gold"),
    "car-white": car("white"),
    "car-black": car("black", STRIPES),
    "car-taxi": car("gold", CHECKS, TAXI_SIGN),
    "car-pink": van("pink"),
    "roadster": roadster(),
    "coin": (
        outline(shape("circle", shade("gold"), 'cx="64" cy="64" r="52"'))
        + f'<circle cx="64" cy="60" r="47" fill="{base("gold")}"/>'
        + f'<circle cx="64" cy="62" r="36" fill="none" stroke="{shade("gold")}" stroke-width="{DETAIL_W}"/>'
        + dollar(base("gold"), scale=0.8)
        + shine(40, 36, 12, 6, -38)
    ),
    "star": (
        outline(shape("path", shade("gold"), f'd="{star_path(64, 68, 54, 30)}"'))
        + f'<path d="{star_path(64, 65, 48, 27)}" fill="{base("gold")}" stroke="{base("gold")}" '
        f'stroke-width="{2 * SEAM_W}" stroke-linejoin="round"/>'
        + shine(50, 46, 9, 5, -35)
    ),
    "check": (
        outline(shape("circle", shade("green"), 'cx="64" cy="64" r="52"'))
        + f'<circle cx="64" cy="60" r="47" fill="{base("green")}"/>'
        + doubled("M40 64 L57 81 L89 47", 12, WHITE)
        + shine(42, 36, 12, 6, -38)
    ),
    "bag": (
        doubled("M44 50 V36 Q44 16 64 16 Q84 16 84 36 V50", 6, WHITE)
        + outline(shape("path", WHITE, 'd="M24 46 H104 L98 112 Q97 120 89 120 H39 Q31 120 30 112 Z"'))
        + f'<path d="M86 46 H104 L98 112 Q97 120 89 120 H82 Z" fill="{shade("white")}"/>'
        + dollar(base("green"), dy=20, scale=0.78)
    ),
    "flag": (
        '<defs><clipPath id="cloth"><path d="M32 20 C54 8 74 32 110 18 V70 C74 84 54 58 32 70 Z"/></clipPath></defs>'
        + outline(
            shape("rect", base("steel"), 'x="20" y="18" width="10" height="94" rx="5"'),
            shape("path", WHITE, 'd="M32 20 C54 8 74 32 110 18 V70 C74 84 54 58 32 70 Z"'),
            shape("circle", base("gold"), 'cx="25" cy="16" r="8"'),
        )
        + '<g clip-path="url(#cloth)">'
        + "".join(
            f'<rect x="{30 + c * 16}" y="{6 + r * 16}" width="16" height="16" fill="{INK}"/>'
            for r in range(5)
            for c in range(6)
            if (r + c) % 2 == 0
        )
        + "</g>"
        + f'<path d="M32 20 C54 8 74 32 110 18 V70 C74 84 54 58 32 70 Z" fill="none" stroke="{INK}" '
        f'stroke-width="{DETAIL_W}" stroke-linejoin="round"/>'
        + shine(25, 60, 2, 30, 0)
    ),
    "map": (
        outline(shape("path", base("paper"), 'd="M12 32 L44 20 L84 32 L116 20 V100 L84 112 L44 100 L12 112 Z"'))
        + f'<path d="M44 20 L84 32 V112 L44 100 Z" fill="{shade("paper")}"/>'
        + line("M44 20 V100")
        + line("M84 32 V112")
        + seam("M22 92 Q40 78 56 86 T96 76", "wood")
        + outline(shape("path", base("red"), 'd="M64 92 C64 92 40 68 40 50 A24 24 0 0 1 88 50 C88 68 64 92 64 92 Z"'))
        + f'<path d="M64 92 C64 92 76 74 82 60 C86 48 80 34 70 28 C84 30 90 42 88 52 C86 68 64 92 64 92 Z" '
        f'fill="{shade("red")}"/>'
        + piece("circle", WHITE, 'cx="64" cy="50" r="9"')
        + shine(52, 38, 6, 3.5, -40)
    ),
    "people": (
        outline(
            shape("circle", base("gold"), 'cx="86" cy="40" r="17"'),
            shape("path", base("gold"), 'd="M60 106 Q60 70 86 70 Q112 70 112 106 Z"'),
        )
        + f'<path d="M96 72 Q112 78 112 106 H98 Q100 84 96 72 Z" fill="{shade("gold")}"/>'
        + outline(
            shape("circle", WHITE, 'cx="46" cy="46" r="19"'),
            shape("path", WHITE, 'd="M14 114 Q14 76 46 76 Q78 76 78 114 Z"'),
        )
        + f'<path d="M58 79 Q78 86 78 114 H62 Q64 92 58 79 Z" fill="{shade("white")}"/>'
    ),
    "cone": (
        outline(
            shape("rect", shade("orange"), 'x="12" y="98" width="104" height="18" rx="6"'),
            shape("path", base("orange"), 'd="M52 18 Q64 12 76 18 L98 104 H30 Z"'),
        )
        + f'<path d="M76 18 L98 104 H84 L70 18 Z" fill="{shade("orange")}"/>'
        + f'<path d="M43.7 46 L84.3 46 L87.8 60 L40.2 60 Z" fill="{WHITE}"/>'
        + f'<path d="M37.3 72 L90.7 72 L94.1 86 L33.9 86 Z" fill="{WHITE}"/>'
        + shine(50, 34, 3, 12, 14)
    ),
    "wrench": (
        '<g transform="rotate(35 64 64)">'
        + outline(
            shape("rect", base("metal"), 'x="55" y="34" width="18" height="64" rx="6"'),
            shape("path", base("metal"), 'd="M52 4 V22 H76 V4 A24 24 0 1 1 52 4 Z"'),
            shape(
                "path",
                base("metal"),
                'fill-rule="evenodd" d="M64 84 A20 20 0 1 1 63.9 84 Z M64 96 A8 8 0 1 0 64.1 96 Z"',
            ),
        )
        + f'<path d="M66 36 H73 V96 H66 Z" fill="{shade("metal")}"/>'
        + shine(60, 62, 2.5, 18, 0)
        + "</g>"
    ),
    "gift": (
        outline(
            shape("path", base("red"), 'd="M64 40 C46 6 16 14 28 34 C34 44 54 44 64 40 Z"'),
            shape("path", base("red"), 'd="M64 40 C82 6 112 14 100 34 C94 44 74 44 64 40 Z"'),
            shape("rect", WHITE, 'x="22" y="58" width="84" height="56" rx="6"'),
            shape("rect", WHITE, 'x="14" y="40" width="100" height="22" rx="6"'),
        )
        + f'<rect x="22" y="100" width="84" height="14" rx="6" fill="{shade("white")}"/>'
        + seam("M60 38 C50 24 36 22 36 30", "red")
        + seam("M68 38 C78 24 92 22 92 30", "red")
        + piece("rect", base("red"), 'x="56" y="40" width="16" height="74"')
        + line("M14 62 H114")
        + piece("circle", base("red"), 'cx="64" cy="40" r="9"')
        + shine(36, 26, 6, 3, -30)
    ),
    "cash": (
        "".join(
            outline(shape("rect", shade("green"), f'x="14" y="{y}" width="100" height="42" rx="7"'))
            for y in (84, 74, 64)
        )
        + outline(shape("rect", base("green"), 'x="14" y="48" width="100" height="44" rx="7"'))
        + f'<rect x="22" y="55" width="84" height="30" rx="4" fill="none" stroke="{shade("green")}" '
        f'stroke-width="{SEAM_W}"/>'
        + f'<circle cx="64" cy="70" r="13" fill="{shade("green")}"/>'
        + dollar(base("green"), dy=7, scale=0.36)
        + f'<circle cx="30" cy="70" r="4" fill="{shade("green")}"/>'
        + f'<circle cx="98" cy="70" r="4" fill="{shade("green")}"/>'
        + shine(36, 53, 14, 2.5, 0)
    ),
    "chest": (
        outline(
            shape("rect", base("wood"), 'x="12" y="58" width="104" height="54" rx="6"'),
            shape("path", base("wood"), 'd="M12 60 V44 Q12 24 32 24 H96 Q116 24 116 44 V60 Z"'),
        )
        + f'<rect x="12" y="96" width="104" height="16" rx="6" fill="{shade("wood")}"/>'
        + seam("M14 78 H114", "wood")
        + seam("M20 40 H108", "wood")
        + piece("rect", base("gold"), 'x="28" y="24" width="12" height="88"')
        + piece("rect", base("gold"), 'x="88" y="24" width="12" height="88"')
        + piece("rect", base("gold"), 'x="12" y="54" width="104" height="10"')
        + piece("rect", base("gold"), 'x="52" y="50" width="24" height="26" rx="5"')
        + f'<path d="M64 58 a4 4 0 1 1 -0.1 0 Z M62 61 H66 L67 70 H61 Z" fill="{INK}"/>'
        + shine(58, 31, 16, 2.5, 0)
    ),
    "trophy": (
        doubled("M38 32 H24 Q14 32 16 46 Q20 60 40 64", 6, base("gold"))
        + doubled("M90 32 H104 Q114 32 112 46 Q108 60 88 64", 6, base("gold"))
        + outline(
            shape("path", base("gold"), 'd="M34 16 H94 V44 Q94 78 64 80 Q34 78 34 44 Z"'),
            shape("rect", base("gold"), 'x="56" y="78" width="16" height="16"'),
            shape("rect", shade("gold"), 'x="36" y="92" width="56" height="12" rx="4"'),
            shape("rect", shade("gold"), 'x="28" y="104" width="72" height="14" rx="4"'),
        )
        + f'<path d="M78 16 H94 V44 Q94 74 70 79 Q86 66 86 44 V16 Z" fill="{shade("gold")}"/>'
        + shine(48, 40, 4, 15, 0)
    ),
    "target": (
        outline(shape("circle", base("red"), 'cx="64" cy="64" r="54"'))
        + f'<circle cx="64" cy="64" r="41" fill="{WHITE}"/><circle cx="64" cy="64" r="29" fill="{base("red")}"/>'
        + f'<circle cx="64" cy="64" r="17" fill="{WHITE}"/><circle cx="64" cy="64" r="8" fill="{base("red")}"/>'
        + f'<path d="M64 118 A54 54 0 0 0 118 64 H105 A41 41 0 0 1 64 105 Z" fill="{shade("red")}"/>'
        + shine(36, 34, 10, 5, -40)
    ),
    "stop": (
        outline(shape("path", base("red"), f'd="{octagon(64, 64, 56)}"'))
        + f'<path d="{octagon(64, 64, 45)}" fill="none" stroke="{WHITE}" stroke-width="{DETAIL_W}"/>'
        + doubled("M46 46 L82 82 M82 46 L46 82", 11, WHITE)
        + shine(40, 30, 9, 4, -25)
    ),
}

# ---------------------------------------------------------------- checks and output


def check(name: str, svg: str) -> list:
    errors = []
    for c in re.findall(r"#[0-9a-fA-F]{6}", svg):
        if c.lower() not in ALLOWED:
            errors.append(f"{name}: colour {c} is not in MATERIALS")
    for o in re.findall(r'opacity="([0-9.]+)"', svg):
        if float(o) != SHINE:
            errors.append(f"{name}: opacity {o} (only the shine is see-through, at {SHINE})")
    for w in re.findall(r'stroke-width="([0-9.]+)"', svg):
        if float(w) not in LINE_WIDTHS and float(w) != 2 * SEAM_W:
            errors.append(f"{name}: stroke width {w} is not one of the rule widths")
    if svg.count("<ellipse") > 1:
        errors.append(f"{name}: more than one shine")
    if "gradient" in svg.lower() or "<text" in svg or "filter" in svg:
        errors.append(f"{name}: no gradients, filters or text")
    return errors


def filled_size(png: pathlib.Path) -> float:
    """The icon's longer side in grid px, read back from the render (needs Pillow)."""
    from PIL import Image

    im = Image.open(png).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    if not box:
        return 0
    return max(box[2] - box[0], box[3] - box[1]) / im.width * 140  # the view box is 140 wide


def main() -> None:
    out = pathlib.Path(sys.argv[1])
    png = out / "png"
    png.mkdir(parents=True, exist_ok=True)
    errors = []
    for name, body in ICONS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-6 -6 140 140" width="280" height="280">{body}</svg>\n'
        errors += check(name, svg)
        path = out / f"{name}.svg"
        path.write_text(svg, encoding="utf-8")
        target = png / f"{name}.png"
        subprocess.run(
            ["sips", "-s", "format", "png", "-Z", "256", str(path), "--out", str(target)],
            check=True,
            capture_output=True,
        )
        size = filled_size(target)
        if not FILL_MIN <= size <= FILL_MAX:
            errors.append(f"{name}: fills {size:.0f} grid px, want {FILL_MIN}-{FILL_MAX}")
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print(len(ICONS), "icons, all within the style rules")


if __name__ == "__main__":
    main()
