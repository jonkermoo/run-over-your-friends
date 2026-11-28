# Draw the road UI's icons (black outline, flat traffic colours, full colour: the game doesn't tint them) as
# SVG and render each to a 256 px transparent PNG with macOS `sips` (Core SVG). Only icons are images; every
# panel, button and bar is coded in client/Style.
#   python3 tools/ui/road_icons.py <out_dir>        -> <out_dir>/<name>.svg and <out_dir>/png/<name>.png
import pathlib
import subprocess
import sys

OUT = pathlib.Path(sys.argv[1])
K = "#141414"
Y, R, G, B, P, O, PK = "#ffcc00", "#ff3b30", "#19c24a", "#1f7bff", "#a347ff", "#ff6a13", "#ff4fa3"
DOLLAR = (f'<path d="M28.5 19.5q-1.4-2.6-4.5-2.6-4.2 0-4.2 3.3 0 2.6 4.2 3.3 4.6.8 4.6 4.2 0 3.6-4.6 3.6-3.4 0-4.8-2.8" '
          f'fill="none" stroke="{K}" stroke-width="3" stroke-linecap="round"/><path d="M24 13.5v20" stroke="{K}" stroke-width="2.6" stroke-linecap="round"/>')


def car(body, extra=""):
    return (f'<path d="M4 31v-4.5q0-2 2-2.6l6-1.7 5-6.2q1.6-2 4.2-2h9.6q2.4 0 4 1.8l5 5.6 3.6 1q2.6.8 2.6 3.4V31q0 2-2 2H6q-2 0-2-2z" '
            f'fill="{body}" stroke="{K}" stroke-width="3" stroke-linejoin="round"/>'
            f'<path d="M14.5 22.5l3.8-4.8q.8-1 2-1H24v5.8z" fill="#bfe6ff"/><path d="M27 16.7h3.6q1.2 0 2 .9l4 4.9H27z" fill="#bfe6ff"/>{extra}'
            f'<circle cx="14" cy="33" r="5" fill="{K}"/><circle cx="14" cy="33" r="2" fill="#d9d9d9"/>'
            f'<circle cx="35" cy="33" r="5" fill="{K}"/><circle cx="35" cy="33" r="2" fill="#d9d9d9"/>')


S = 'stroke="#141414" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round"'
ICONS = {
    "car-red": car(R), "car-blue": car(B), "car-yellow": car(Y), "car-pink": car(PK), "car-green": car(G),
    "car-white": car("#f3f5f7"),
    "car-taxi": car(Y, f'<rect x="20.5" y="11" width="8" height="4.4" rx="1" fill="{K}"/>'),
    "car-black": car(K, f'<path d="M20 17v14M26 17v14" stroke="{Y}" stroke-width="2.4"/>'),
    "bag": f'<path d="M9 17h30l-2.6 24.5q-.2 2-2.2 2H13.8q-2 0-2.2-2z" fill="#fff" {S}/><path d="M17 20v-6q0-7 7-7t7 7v6" fill="none" {S}/>'
    + DOLLAR.replace('d="M28.5 19.5', 'transform="translate(0 6)" d="M28.5 19.5').replace('d="M24 13.5', 'transform="translate(0 6)" d="M24 13.5'),
    "flag": f'<path d="M13 8q6.5-3 13 0t13 0v19q-6.5 3-13 0t-13 0z" fill="#fff" {S}/>'
    f'<path d="M13 8q3.2-1.4 6.5-1.3v6.6q-3.3-.1-6.5 1.3zM19.5 13.3q3.3.1 6.5 1.4v6.6q-3.2-1.3-6.5-1.4zM26 8q3.2 1.4 6.5 1.4V16q-3.3 0-6.5-1.3zM32.5 16q3.3 0 6.5-1.4v6.6q-3.2 1.4-6.5 1.4z" fill="{K}"/>'
    f'<path d="M12 6v37" stroke="{K}" stroke-width="3.8" stroke-linecap="round"/>',
    "map": f'<path d="M5 12l12-4 14 4 12-4v28l-12 4-14-4-12 4z" fill="#fff" {S}/><path d="M17 8v28M31 12v28" stroke="{K}" stroke-width="2.4"/>'
    f'<path d="M24 31s-6.5-6.5-6.5-11.5a6.5 6.5 0 0 1 13 0c0 5-6.5 11.5-6.5 11.5z" fill="{R}" stroke="{K}" stroke-width="2.8" stroke-linejoin="round"/><circle cx="24" cy="19.5" r="2.4" fill="#fff"/>',
    "people": f'<circle cx="31" cy="15" r="5.5" fill="{Y}" {S}/><path d="M22 40q0-12 9-12t9 12z" fill="{Y}" {S}/>'
    f'<circle cx="18" cy="17" r="6.5" fill="#fff" {S}/><path d="M6 42q0-14 12-14t12 14z" fill="#fff" {S}/>',
    "wrench": f'<path d="M33.5 7.5a9 9 0 0 0-9.6 12.2L9.2 34.4a3.6 3.6 0 0 0 5.1 5.1l14.7-14.7a9 9 0 0 0 12.2-9.6l-5.4 5.4-5.3-1.4-1.4-5.3z" fill="#fff" {S}/>',
    "gift": f'<rect x="8" y="20" width="32" height="21" rx="1.5" fill="#fff" {S}/><path d="M24 14q-9-10-12-5t12 5q9 0 12-5t-12 5z" fill="{R}" {S}/>'
    f'<rect x="5" y="14" width="38" height="8" rx="1.5" fill="{R}" {S}/><path d="M24 14v27" stroke="{K}" stroke-width="4"/>',
    "coin": f'<circle cx="24" cy="24" r="18" fill="{Y}" stroke="{K}" stroke-width="3.2"/><circle cx="24" cy="24" r="12.5" fill="none" stroke="#e09a00" stroke-width="2.4"/>'
    + DOLLAR.replace('d="M28.5 19.5', 'transform="translate(0 0.5)" d="M28.5 19.5'),
    "cash": f'<rect x="4" y="13" width="36" height="20" rx="1.5" fill="#7fdc8a" {S}/><rect x="8" y="17" width="36" height="20" rx="1.5" fill="{G}" {S}/>'
    f'<circle cx="26" cy="27" r="5" fill="#7fdc8a" stroke="{K}" stroke-width="2.6"/>',
    "trophy": f'<path d="M15 11H9q0 8 7 9M33 11h6q0 8-7 9" fill="none" {S}/><path d="M15 8h18v9q0 9-9 9t-9-9z" fill="{Y}" {S}/>'
    f'<path d="M21 26h6v7h-6z" fill="{Y}" {S}/><rect x="14" y="33" width="20" height="7" rx="1.5" fill="#fff" {S}/>',
    "paint": f'<path d="M24 5q12 14 12 23a12 12 0 0 1-24 0q0-9 12-23z" fill="{PK}" {S}/><path d="M18.5 29a5.5 5.5 0 0 0 5.5 5.5" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
    "star": f'<path d="M24 4l5.9 12.6 13.8 1.7-10.2 9.4 2.7 13.6L24 34.5l-12.2 6.8 2.7-13.6-10.2-9.4 13.8-1.7z" fill="{Y}" {S}/>',
    "bolt": f'<path d="M27 4 10 27h11l-3 17 19-25H26z" fill="{Y}" {S}/>',
    "ticket": f'<path d="M6 14h36v7a3 3 0 0 0 0 6v7H6v-7a3 3 0 0 0 0-6z" fill="#fff" {S}/><path d="M24 17.5l2.2 4.6 5 .6-3.7 3.4 1 5-4.5-2.5-4.5 2.5 1-5-3.7-3.4 5-.6z" fill="{R}" stroke="{K}" stroke-width="2" stroke-linejoin="round"/>',
    "chest": f'<path d="M7 22h34v18H7z" fill="#c97a2b" {S}/><path d="M7 22q0-12 17-12t17 12z" fill="#e0913c" {S}/>'
    f'<path d="M7 22h34" stroke="{K}" stroke-width="3.2"/><rect x="20" y="19" width="8" height="10" rx="1" fill="{Y}" {S}/>',
    "lock": f'<path d="M16 22v-6a8 8 0 0 1 16 0v6" fill="none" stroke="{K}" stroke-width="4"/><rect x="11" y="21" width="26" height="20" rx="2" fill="{Y}" {S}/><circle cx="24" cy="30" r="3" fill="{K}"/>',
    "check": f'<circle cx="24" cy="24" r="18" fill="{G}" stroke="{K}" stroke-width="3.2"/><path d="M15 24.5l6 6 12-13" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
    "stop": f'<path d="M16 3h16l13 13v16L32 45H16L3 32V16z" fill="{R}" stroke="{K}" stroke-width="3.5" stroke-linejoin="round"/>'
    f'<path d="M16.5 7h15l9.5 9.5v15L31.5 41h-15L7 31.5v-15z" fill="none" stroke="#fff" stroke-width="2.4" stroke-linejoin="round"/>'
    f'<path d="M17 17l14 14M31 17L17 31" stroke="#fff" stroke-width="5" stroke-linecap="round"/>',
    "music": f'<path d="M18 34V12l20-5v22" fill="none" stroke="{K}" stroke-width="4" stroke-linejoin="round"/><circle cx="13" cy="35" r="6" fill="{P}" {S}/><circle cx="33" cy="30" r="6" fill="{P}" {S}/>',
    "eye": f'<path d="M3 24Q24 4 45 24Q24 44 3 24Z" fill="#fff" {S}/><circle cx="24" cy="24" r="8" fill="{B}" {S}/><circle cx="24" cy="24" r="3" fill="{K}"/>',
    "seat": f'<path d="M14 6h12q3 0 3 3v19H14z" fill="{O}" {S}/><path d="M10 28h26q3 0 3 3v5H10z" fill="{O}" {S}/><path d="M14 36v6M34 36v6" stroke="{K}" stroke-width="3.6" stroke-linecap="round"/>',
    "crown": f'<path d="M6 36l-2-22 11 9 9-15 9 15 11-9-2 22z" fill="{Y}" {S}/><circle cx="24" cy="29" r="3" fill="{R}" stroke="{K}" stroke-width="2"/>',
    "clock": f'<circle cx="24" cy="24" r="18" fill="#fff" stroke="{K}" stroke-width="3.2"/><path d="M24 13v11l7 5" fill="none" stroke="{K}" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/>',
    "cone": f'<path d="M19 8h10l8 30H11z" fill="{O}" {S}/><path d="M16.5 18h15M14 28h20" stroke="#fff" stroke-width="4"/><rect x="6" y="37" width="36" height="6" rx="1.5" fill="{O}" {S}/>',
    "rocket": f'<path d="M24 4q10 8 10 22l-4 8H18l-4-8q0-14 10-22z" fill="#fff" {S}/><circle cx="24" cy="19" r="4" fill="{B}" stroke="{K}" stroke-width="2.6"/>'
    f'<path d="M14 26l-6 8 8 0M34 26l6 8-8 0" fill="{R}" {S}/><path d="M20 36q4 10 8 0" fill="{O}" {S}/>',
    "pin": f'<path d="M24 44s-12-12-12-21a12 12 0 0 1 24 0c0 9-12 21-12 21z" fill="{R}" {S}/><circle cx="24" cy="23" r="4.5" fill="#fff" stroke="{K}" stroke-width="2.6"/>',
    "vip": f'<path d="M4 14h40v20H4z" fill="{Y}" {S}/><path d="M10 19l4 10 4-10M23 19v10M29 29V19h4a3 3 0 0 1 0 6h-4" fill="none" stroke="{K}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
    "skull": f'<path d="M9 22a15 15 0 0 1 30 0v6l-4 3v7H13v-7l-4-3z" fill="#fff" {S}/><circle cx="18" cy="23" r="4" fill="{K}"/><circle cx="30" cy="23" r="4" fill="{K}"/><path d="M20 38v-4M24 38v-4M28 38v-4" stroke="{K}" stroke-width="2.4"/>',
    "plus": f'<path d="M24 10v28M10 24h28" stroke="{K}" stroke-width="5" stroke-linecap="round"/>',
    "minus": f'<path d="M10 24h28" stroke="{K}" stroke-width="5" stroke-linecap="round"/>',
    "target": f'<circle cx="24" cy="24" r="18" fill="#fff" stroke="{K}" stroke-width="3.2"/><circle cx="24" cy="24" r="11" fill="{R}" stroke="{K}" stroke-width="3"/><circle cx="24" cy="24" r="4" fill="#fff" stroke="{K}" stroke-width="2.4"/>',
}

OUT.mkdir(parents=True, exist_ok=True)
for name, body in ICONS.items():
    (OUT / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="96" height="96">{body}</svg>\n',
        encoding="utf-8")
PNG = OUT / "png"
PNG.mkdir(exist_ok=True)
for name in ICONS:
    subprocess.run(["sips", "-s", "format", "png", "-Z", "256", str(OUT / f"{name}.svg"), "--out", str(PNG / f"{name}.png")],
                   check=True, capture_output=True)
print(len(ICONS), "icons")
