# The cartoon emblems on the signs, each drawn in a box from -50 to 50 with ink outlines. signs.py scales them
# into place and adds the hard ink shadow.
INK = "#101012"
YELLOW = "#ffd000"
PINK = "#ff2e9a"
BLUE = "#1f6bff"
LIME = "#2bdc5a"
RED = "#e8383c"
ORANGE = "#ff8a1f"
WHITE = "#ffffff"
CREAM = "#fff3d6"
TAN = "#e9a85a"
BROWN = "#7a3f1d"
MINT = "#7fe3c4"
GREY = "#c9ccd2"
NAVY = "#24306e"
S = f'stroke="{INK}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"'


def union(shapes: str, fill: str, edge: float = 10) -> str:
    # one outline round several overlapping shapes: drawn thick in ink, then filled on top
    return (
        f'<g fill="{INK}" stroke="{INK}" stroke-width="{edge}" stroke-linejoin="round">{shapes}</g>'
        f'<g fill="{fill}">{shapes}</g>'
    )


def star(cx, cy, r, fill, points=4, inner=0.38):
    import math

    pts = []
    for k in range(points * 2):
        a = math.pi * k / points - math.pi / 2
        rr = r if k % 2 == 0 else r * inner
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" {S}/>'


BURGER = f"""
<path d="M-44,-6 Q-44,-44 0,-44 Q44,-44 44,-6 Z" fill="{TAN}" {S}/>
<g fill="{CREAM}"><ellipse cx="-18" cy="-28" rx="4" ry="2.4" transform="rotate(-20,-18,-28)"/>
<ellipse cx="4" cy="-34" rx="4" ry="2.4"/><ellipse cx="20" cy="-22" rx="4" ry="2.4" transform="rotate(20,20,-22)"/>
<ellipse cx="-4" cy="-20" rx="4" ry="2.4"/></g>
<path d="M-48,-6 q6,10 12,0 q6,10 12,0 q6,10 12,0 q6,10 12,0 q6,10 12,0 q6,10 12,0 q6,10 12,0 q6,10 12,0 V2 H-48Z"
  fill="{LIME}" {S}/>
<path d="M-44,2 H44 L36,14 L26,4 L14,16 L4,4 Z" fill="{YELLOW}" {S}/>
<rect x="-47" y="4" width="94" height="16" rx="8" fill="{BROWN}" {S}/>
<path d="M-44,20 H44 V30 Q44,40 34,40 H-34 Q-44,40 -44,30 Z" fill="{TAN}" {S}/>
"""

SOCK = f"""
<path d="M-18,-46 H16 V8 L36,20 Q50,30 42,42 Q34,52 16,46 L-12,32 Q-20,26 -18,14 Z" fill="{WHITE}" {S}/>
<path d="M-18,-46 H16 V-30 H-18 Z" fill="{PINK}" {S}/>
<path d="M-18,-22 H16 V-14 H-18 Z" fill="{BLUE}" stroke="none"/>
<path d="M20,24 Q34,22 40,30" fill="none" stroke="{INK}" stroke-width="3"/>
"""

MEGA = f"""
<circle r="46" fill="{BLUE}" {S}/>
<path d="M-30,30 V-28 L0,4 L30,-28 V30 H16 V4 L0,20 L-16,4 V30 Z" fill="{YELLOW}" {S}/>
"""

CAR = f"""
<path d="M-48,18 V0 Q-48,-6 -40,-8 L-26,-10 L-12,-30 Q-8,-34 0,-34 H24 Q30,-34 34,-28 L42,-10 Q50,-8 50,0 V18 Z"
  fill="{RED}" {S}/>
<path d="M-8,-26 H6 V-12 H-20 Z M12,-26 H24 L30,-12 H12 Z" fill="{MINT}" {S}/>
<circle cx="-26" cy="20" r="13" fill="{INK}"/><circle cx="-26" cy="20" r="6" fill="{GREY}"/>
<circle cx="28" cy="20" r="13" fill="{INK}"/><circle cx="28" cy="20" r="6" fill="{GREY}"/>
<path d="M-44,-2 H-36" stroke="{YELLOW}" stroke-width="6" stroke-linecap="round"/>
"""

EMBLEMS = {
    # ---- the spawn plaza's food stalls
    "hotdog": f"""<g transform="rotate(-18)">
<rect x="-44" y="-14" width="88" height="30" rx="15" fill="{TAN}" {S}/>
<rect x="-52" y="-16" width="104" height="20" rx="10" fill="#c8402c" {S}/>
<path d="M-38,-6 l7,-6 l7,6 l7,-6 l7,6 l7,-6 l7,6 l7,-6 l7,6 l7,-6 l7,6" fill="none" stroke="{YELLOW}"
  stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M-44,0 Q0,24 44,0 V8 Q44,24 30,26 H-30 Q-44,24 -44,8 Z" fill="{TAN}" {S}/></g>""",
    "icecream": f"""
<path d="M-24,-2 L24,-2 L0,52 Z" fill="{TAN}" {S}/>
<path d="M-12,8 L8,30 M-2,-2 L14,16 M10,-2 L18,6 M12,8 L-6,30 M2,-2 L-14,16" stroke="#b97a35" stroke-width="3"/>
<circle cx="-13" cy="-12" r="17" fill="{PINK}" {S}/>
<circle cx="13" cy="-12" r="17" fill="{MINT}" {S}/>
<circle cx="0" cy="-30" r="17" fill="{CREAM}" {S}/>
<path d="M2,-47 Q6,-56 14,-58" fill="none" stroke="{INK}" stroke-width="3"/>
<circle cx="2" cy="-46" r="6.5" fill="{RED}" {S}/>
<g fill="{WHITE}"><circle cx="-18" cy="-16" r="3"/><circle cx="-5" cy="-35" r="3"/></g>""",
    "taco": f"""
<path d="M-46,-8 q9,-16 18,-2 q9,-16 18,-2 q9,-16 18,-2 q9,-16 18,-2 q9,-16 20,0 Z" fill="{LIME}" {S}/>
<circle cx="-20" cy="-14" r="6" fill="{RED}" {S}/><circle cx="12" cy="-16" r="6" fill="{RED}" {S}/>
<path d="M-48,-10 A48,44 0 0 0 48,-10 Z" fill="{YELLOW}" {S}/>
<g fill="{ORANGE}"><circle cx="-24" cy="6" r="3"/><circle cx="2" cy="16" r="3"/><circle cx="22" cy="4" r="3"/>
<circle cx="-8" cy="24" r="3"/><circle cx="16" cy="22" r="3"/></g>""",
    "donut": f"""
<path d="M-46,0 a46,46 0 1 0 92,0 a46,46 0 1 0 -92,0 Z M-14,0 a14,14 0 1 0 28,0 a14,14 0 1 0 -28,0 Z"
  fill-rule="evenodd" fill="{TAN}" {S}/>
<path d="M-38,4 Q-42,-30 -10,-38 Q22,-44 36,-18 Q46,6 34,22 Q24,30 28,36 Q8,46 -10,36 Q-20,28 -30,30 Q-40,22 -38,4 Z
  M-17,0 a17,17 0 1 0 34,0 a17,17 0 1 0 -34,0 Z" fill-rule="evenodd" fill="{PINK}" {S}/>
<g stroke-width="5" stroke-linecap="round">
<path d="M-26,-14 l6,-4" stroke="{YELLOW}"/><path d="M-4,-30 l7,2" stroke="{WHITE}"/><path d="M20,-22 l4,6" stroke="{BLUE}"/>
<path d="M26,4 l6,2" stroke="{YELLOW}"/><path d="M8,24 l-6,4" stroke="{LIME}"/><path d="M-22,18 l-4,-6" stroke="{BLUE}"/>
<path d="M-30,-2 l0,7" stroke="{WHITE}"/><path d="M14,-34 l6,0" stroke="{LIME}"/></g>""",
    # ---- Burger Barn
    "burger": BURGER,
    "fries": f"""
<g {S}><rect x="-26" y="-48" width="9" height="50" fill="{YELLOW}" transform="rotate(-10)"/>
<rect x="-12" y="-52" width="9" height="54" fill="{YELLOW}"/><rect x="2" y="-50" width="9" height="52" fill="{YELLOW}" transform="rotate(6)"/>
<rect x="14" y="-44" width="9" height="46" fill="{YELLOW}" transform="rotate(14)"/></g>
<path d="M-32,-8 L32,-8 L24,48 L-24,48 Z" fill="{RED}" {S}/>
<path d="M-14,12 Q0,26 14,12" fill="none" stroke="{WHITE}" stroke-width="6" stroke-linecap="round"/>""",
    "shake": f"""
<rect x="2" y="-56" width="8" height="40" fill="{RED}" {S} transform="rotate(14)"/>
<path d="M-24,-14 Q-28,-34 -8,-34 Q0,-46 10,-34 Q30,-34 24,-14 Z" fill="{CREAM}" {S}/>
<circle cx="0" cy="-42" r="6" fill="{RED}" {S}/>
<path d="M-26,-14 H26 L18,48 H-18 Z" fill="{PINK}" {S}/>
<path d="M-24,2 H24 M-22,18 H22" stroke="{WHITE}" stroke-width="5"/>""",
    "barn": f"""
<path d="M-44,46 V-6 L-30,-34 L0,-48 L30,-34 L44,-6 V46 Z" fill="{RED}" {S}/>
<path d="M-30,-34 L0,-48 L30,-34" fill="none" stroke="{WHITE}" stroke-width="5"/>
<rect x="-18" y="8" width="36" height="38" fill="{WHITE}" {S}/>
<path d="M-18,8 L18,46 M18,8 L-18,46" stroke="{INK}" stroke-width="4"/>
<rect x="-10" y="-26" width="20" height="18" fill="{YELLOW}" {S}/>""",
    "arrow": f"""<path d="M-46,-16 H6 V-38 L48,0 L6,38 V16 H-46 Z" fill="{YELLOW}" {S}/>""",
    # ---- Parcel Planet
    "parcel": f"""
<ellipse cx="0" cy="4" rx="54" ry="16" fill="none" stroke="{INK}" stroke-width="16" transform="rotate(-18)"/>
<ellipse cx="0" cy="4" rx="54" ry="16" fill="none" stroke="{YELLOW}" stroke-width="7" transform="rotate(-18)"/>
<path d="M-30,-18 L0,-32 L30,-18 L0,-4 Z" fill="#f2c27a" {S}/>
<path d="M-30,-18 L0,-4 V36 L-30,22 Z" fill="{TAN}" {S}/>
<path d="M30,-18 L0,-4 V36 L30,22 Z" fill="#c98642" {S}/>
<path d="M-15,-25 L15,-11 V6" fill="none" stroke="{BLUE}" stroke-width="6"/>
<path d="M44,-6 A54,16 0 0 1 -18,26" fill="none" stroke="{INK}" stroke-width="16" transform="rotate(-18)"/>
<path d="M44,-6 A54,16 0 0 1 -18,26" fill="none" stroke="{YELLOW}" stroke-width="7" transform="rotate(-18)"/>""",
    # ---- offices
    "synergy": f"""
<path d="M-38,-6 A38,38 0 0 1 26,-28" fill="none" stroke="{INK}" stroke-width="20"/>
<path d="M-38,-6 A38,38 0 0 1 26,-28" fill="none" stroke="{BLUE}" stroke-width="10"/>
<path d="M14,-44 L44,-34 L22,-10 Z" fill="{BLUE}" {S}/>
<path d="M38,6 A38,38 0 0 1 -26,28" fill="none" stroke="{INK}" stroke-width="20"/>
<path d="M38,6 A38,38 0 0 1 -26,28" fill="none" stroke="{LIME}" stroke-width="10"/>
<path d="M-14,44 L-44,34 L-22,10 Z" fill="{LIME}" {S}/>""",
    "paperclip": f"""<g transform="rotate(28)" fill="none" stroke-linecap="round">
<path d="M10,-30 V22 a10,10 0 0 1 -20,0 V-34 a16,16 0 0 1 32,0 V28 a22,22 0 0 1 -44,0 V-14" stroke="{INK}" stroke-width="16"/>
<path d="M10,-30 V22 a10,10 0 0 1 -20,0 V-34 a16,16 0 0 1 32,0 V28 a22,22 0 0 1 -44,0 V-14" stroke="{GREY}" stroke-width="7"/></g>""",
    "megacorp": MEGA,
    "cube": f"""
<path d="M0,-46 L40,-24 L0,-2 L-40,-24 Z" fill="{YELLOW}" {S}/>
<path d="M-40,-24 L0,-2 V46 L-40,24 Z" fill="{PINK}" {S}/>
<path d="M40,-24 L0,-2 V46 L40,24 Z" fill="{BLUE}" {S}/>
<path d="M-20,-35 L20,-13 M20,-35 L-20,-13" stroke="{INK}" stroke-width="3"/>""",
    "spreadsheet": f"""
<rect x="-44" y="-40" width="88" height="80" rx="6" fill="{WHITE}" {S}/>
<path d="M-44,-34 Q-44,-40 -38,-40 H38 Q44,-40 44,-34 V-22 H-44 Z" fill="{LIME}" {S}/>
<path d="M-44,-4 H44 M-44,14 H44 M-16,-22 V40 M14,-22 V40" stroke="{INK}" stroke-width="3"/>
<rect x="14" y="-4" width="30" height="18" fill="{YELLOW}" stroke="{INK}" stroke-width="4"/>
<path d="M-36,32 L-18,20 L0,26 L30,-2" fill="none" stroke="{PINK}" stroke-width="7" stroke-linecap="round"/>""",
    "meeting": f"""
<path d="M-48,-30 Q-48,-44 -34,-44 H8 Q22,-44 22,-30 V-6 Q22,8 8,8 H-22 L-36,22 V8 Q-48,8 -48,-6 Z" fill="{YELLOW}" {S}/>
<path d="M-10,-6 Q-10,-20 4,-20 H36 Q50,-20 50,-6 V18 Q50,32 36,32 V46 L22,32 H4 Q-10,32 -10,18 Z" fill="{PINK}" {S}/>
<g fill="{INK}"><circle cx="8" cy="6" r="5"/><circle cx="20" cy="6" r="5"/><circle cx="32" cy="6" r="5"/></g>""",
    "chart": f"""
<rect x="-42" y="12" width="16" height="32" fill="{BLUE}" {S}/>
<rect x="-18" y="-4" width="16" height="48" fill="{LIME}" {S}/>
<rect x="6" y="-20" width="16" height="64" fill="{YELLOW}" {S}/>
<rect x="30" y="-36" width="16" height="80" fill="{PINK}" {S}/>
<path d="M-46,0 L-14,-24 L4,-12 L34,-44" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M-46,0 L-14,-24 L4,-12 L34,-44" fill="none" stroke="{WHITE}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M20,-50 L44,-54 L40,-30 Z" fill="{WHITE}" {S}/>""",
    "memo": f"""
<path d="M-40,-40 H40 V22 L22,40 H-40 Z" fill="{YELLOW}" {S} transform="rotate(-6)"/>
<path d="M40,22 H22 V40 Z" fill="#d9a800" {S} transform="rotate(-6)"/>
<g transform="rotate(-6)" stroke="{INK}" stroke-width="4" stroke-linecap="round">
<path d="M-28,-18 H26 M-28,-2 H26 M-28,14 H10"/></g>
<circle cx="-2" cy="-40" r="8" fill="{RED}" {S}/>""",
    # ---- the high-street shops
    "sock": SOCK,
    "loaf": f"""
<path d="M-46,14 Q-50,-28 -10,-30 Q0,-40 12,-30 Q50,-30 46,14 V30 Q46,38 38,38 H-38 Q-46,38 -46,30 Z" fill="{TAN}" {S}/>
<path d="M-24,-14 L-14,6 M-4,-18 L6,4 M16,-16 L26,4" stroke="#b97a35" stroke-width="6" stroke-linecap="round"/>
<path d="M-38,22 H38" stroke="#c98642" stroke-width="4"/>""",
    "wheel": f"""
<circle r="46" fill="{INK}"/>
<circle r="30" fill="{GREY}" {S}/>
<path d="M0,-28 V28 M-28,0 H28 M-20,-20 L20,20 M20,-20 L-20,20" stroke="{INK}" stroke-width="3"/>
<circle r="8" fill="{RED}" {S}/>
<g stroke="#46464e" stroke-width="4"><path d="M0,-44 V-36 M0,44 V36 M-44,0 H-36 M44,0 H36"/></g>""",
    "book": f"""
<path d="M-48,-30 H48 V40 H-48 Z" fill="{BLUE}" {S}/>
<path d="M0,-30 Q-22,-42 -44,-34 V32 Q-22,24 0,34 Z" fill="{WHITE}" {S}/>
<path d="M0,-30 Q22,-42 44,-34 V32 Q22,24 0,34 Z" fill="{WHITE}" {S}/>
<path d="M-36,-18 Q-20,-24 -8,-18 M-36,-4 Q-20,-10 -8,-4 M-36,10 Q-20,4 -8,10 M8,-18 Q20,-24 36,-18 M8,-4 Q20,-10 36,-4"
  fill="none" stroke="{INK}" stroke-width="3"/>""",
    "gift": f"""
<path d="M0,-28 Q-30,-56 -30,-32 Q-30,-24 0,-28 Q30,-56 30,-32 Q30,-24 0,-28" fill="{YELLOW}" {S}/>
<rect x="-38" y="-10" width="76" height="54" fill="{PINK}" {S}/>
<rect x="-44" y="-28" width="88" height="20" fill="{PINK}" {S}/>
<path d="M-8,-28 H8 V44 H-8 Z" fill="{YELLOW}" {S}/>""",
    "phone": f"""
<rect x="-26" y="-48" width="52" height="96" rx="10" fill="{INK}"/>
<rect x="-19" y="-38" width="38" height="68" rx="3" fill="{BLUE}"/>
<path d="M-12,-30 L4,-8 L-4,0 L12,24" fill="none" stroke="{WHITE}" stroke-width="3"/>
<circle cy="39" r="4" fill="{GREY}"/>
<g transform="rotate(-35)"><rect x="-40" y="-11" width="80" height="22" rx="11" fill="{TAN}" {S}/>
<rect x="-12" y="-11" width="24" height="22" fill="#f2c27a" {S}/>
<g fill="#b97a35"><circle cx="-26" cy="-4" r="2"/><circle cx="-26" cy="4" r="2"/><circle cx="26" cy="-4" r="2"/><circle cx="26" cy="4" r="2"/></g></g>""",
    "apple": f"""
<path d="M2,-30 Q2,-44 12,-50" fill="none" stroke="{BROWN}" stroke-width="7" stroke-linecap="round"/>
<path d="M6,-36 Q24,-56 40,-42 Q24,-28 6,-36 Z" fill="{LIME}" {S}/>
<path d="M0,-26 C-30,-44 -52,-10 -40,18 C-30,44 -12,48 0,40 C12,48 30,44 40,18 C52,-10 30,-44 0,-26Z" fill="{RED}" {S}/>
<ellipse cx="-22" cy="-6" rx="6" ry="11" fill="{WHITE}" opacity="0.8" transform="rotate(20,-22,-6)"/>""",
    "hat": f"""
<ellipse cx="0" cy="26" rx="50" ry="14" fill="#3346a8" {S}/>
<path d="M-28,24 V-36 Q-28,-44 -20,-44 H20 Q28,-44 28,-36 V24 Z" fill="#3346a8" {S}/>
<rect x="-28" y="4" width="56" height="13" fill="{PINK}" {S}/>
<path d="M-18,-34 V-4" stroke="#6f84ff" stroke-width="6" stroke-linecap="round"/>""",
    "bone": union(
        '<rect x="-30" y="-10" width="60" height="20"/><circle cx="-32" cy="-11" r="13"/><circle cx="-32" cy="11" r="13"/>'
        '<circle cx="32" cy="-11" r="13"/><circle cx="32" cy="11" r="13"/>',
        WHITE,
    ).replace("<g", '<g transform="rotate(-25)"', 2),
    "lolly": f"""
<rect x="-4" y="6" width="8" height="48" rx="3" fill="{WHITE}" {S}/>
<circle cy="-14" r="34" fill="{PINK}" {S}/>
<path d="M0,-14 m0,-4 a4,4 0 1 1 -4,6 a10,10 0 1 1 14,-10 a16,16 0 1 1 -24,14 a22,22 0 1 1 32,-20"
  fill="none" stroke="{WHITE}" stroke-width="6" stroke-linecap="round"/>""",
    "bulb": f"""
<g stroke="{INK}" stroke-width="5" stroke-linecap="round"><path d="M-46,-22 L-38,-20 M46,-22 L38,-20 M-36,-48 L-30,-42 M36,-48 L30,-42 M0,-58 V-52"/></g>
<path d="M0,-46 C26,-46 38,-26 30,-6 C26,4 16,10 16,22 H-16 C-16,10 -26,4 -30,-6 C-38,-26 -26,-46 0,-46Z" fill="{YELLOW}" {S}/>
<path d="M-8,20 V0 L0,-12 L8,0 V20" fill="none" stroke="{ORANGE}" stroke-width="4"/>
<rect x="-17" y="22" width="34" height="10" fill="{GREY}" {S}/><rect x="-14" y="32" width="28" height="10" fill="{GREY}" {S}/>
<path d="M-8,42 H8 L4,50 H-4 Z" fill="{INK}"/>""",
    "cheese": f"""
<path d="M-48,-4 L44,-36 L48,-4 Z" fill="#ffe680" {S}/>
<path d="M-48,-4 H48 V34 H-48 Z" fill="{YELLOW}" {S}/>
<g fill="#e0a800" {S}><circle cx="-26" cy="12" r="7"/><circle cx="8" cy="20" r="9"/><circle cx="32" cy="6" r="5"/></g>
<ellipse cx="18" cy="-12" rx="6" ry="3" fill="#e0a800"/>""",
    # ---- roadside ads
    "chips": f"""
<path d="M-32,-44 L32,-44 L28,-36 Q38,0 28,36 L32,44 H-32 L-28,36 Q-38,0 -28,-36 Z" fill="{RED}" {S}/>
<path d="M-32,-44 l6,6 l6,-6 l6,6 l6,-6 l6,6 l6,-6 l6,6 l6,-6 l6,6 l6,-6 M-32,44 l6,-6 l6,6 l6,-6 l6,6 l6,-6 l6,6 l6,-6 l6,6 l6,-6 l6,6"
  fill="none" stroke="{INK}" stroke-width="3"/>
<path d="M-18,-6 Q-20,-24 0,-24 Q20,-22 18,-2 Q14,18 -2,16 Q-18,14 -18,-6Z" fill="{YELLOW}" {S}/>
<path d="M-8,-10 Q0,-4 8,-12" fill="none" stroke="#d9a800" stroke-width="3"/>""",
    "soda": f"""
<rect x="-24" y="-42" width="48" height="88" rx="9" fill="{BLUE}" {S}/>
<ellipse cx="0" cy="-42" rx="22" ry="6" fill="{GREY}" {S}/>
<path d="M-24,-2 Q0,-18 24,-2 V12 Q0,-4 -24,12 Z" fill="{WHITE}" {S}/>
<g fill="{WHITE}" {S}><circle cx="36" cy="-26" r="6"/><circle cx="44" cy="-44" r="4"/><circle cx="-38" cy="-30" r="5"/><circle cx="-34" cy="-50" r="3"/></g>""",
    "bump": f"""
<path d="M-52,36 Q-30,36 -20,8 Q-8,-20 0,-20 Q8,-20 20,8 Q30,36 52,36 Z" fill="{YELLOW}" {S}/>
<g fill="{INK}"><path d="M-30,30 L-20,8 L-12,8 L-22,30Z M-4,30 L4,-18 L12,-14 L4,30Z M20,30 L14,8 L22,8 L30,30Z"/></g>
<path d="M-52,38 H52" stroke="{INK}" stroke-width="6"/>
<g transform="translate(-6,-42) scale(0.45) rotate(-12)">{CAR}</g>
<path d="M-40,-42 h-12 M-38,-30 h-8" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>""",
    "cleansock": SOCK
    + star(-36, -30, 13, YELLOW)
    + star(40, -36, 10, WHITE)
    + star(34, -4, 7, YELLOW),
    "honk": f"""
<circle r="42" fill="{YELLOW}" {S}/>
<g fill="{INK}"><ellipse cx="-14" cy="-12" rx="6" ry="9"/><ellipse cx="14" cy="-12" rx="6" ry="9"/></g>
<path d="M-24,8 Q0,36 24,8 Z" fill="{RED}" {S}/>
<path d="M48,-18 Q56,0 48,18 M-48,-18 Q-56,0 -48,18" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>""",
    "hiring": MEGA
    + f"""<g transform="translate(26,26) scale(0.5)"><rect x="-38" y="-24" width="76" height="52" rx="6" fill="{BROWN}" {S}/>
<path d="M-14,-24 V-36 H14 V-24" fill="none" stroke="{INK}" stroke-width="7"/><rect x="-6" y="-4" width="12" height="10" fill="{YELLOW}" {S}/></g>""",
    # ---- the country road: gas station, mart, motocross
    "pump": f"""
<path d="M24,-20 H36 Q42,-20 42,-14 V28 Q42,40 32,36" fill="none" stroke="{INK}" stroke-width="6"/>
<rect x="-30" y="-44" width="54" height="86" rx="6" fill="{RED}" {S}/>
<rect x="-20" y="-34" width="34" height="26" rx="3" fill="{WHITE}" {S}/>
<path d="M-12,-26 H6 M-12,-18 H0" stroke="{INK}" stroke-width="4"/>
<rect x="-36" y="40" width="66" height="8" fill="{INK}"/>
<path d="M-4,4 Q-14,18 -4,26 Q6,18 -4,4Z" fill="{YELLOW}" {S}/>""",
    "basket": f"""
<path d="M-30,-14 Q-30,-46 0,-46 Q30,-46 30,-14" fill="none" stroke="{INK}" stroke-width="12"/>
<path d="M-30,-14 Q-30,-46 0,-46 Q30,-46 30,-14" fill="none" stroke="{GREY}" stroke-width="5"/>
<circle cx="-16" cy="-22" r="12" fill="{RED}" {S}/><rect x="0" y="-38" width="16" height="30" fill="{LIME}" {S}/>
<path d="M-48,-14 H48 L38,40 H-38 Z" fill="{BLUE}" {S}/>
<path d="M-24,-6 L-20,32 M0,-6 V32 M24,-6 L20,32 M-44,6 H44 M-42,20 H42" stroke="{WHITE}" stroke-width="4"/>""",
    "flags": f"""
<g transform="rotate(-24)"><rect x="-3" y="-46" width="6" height="96" fill="{GREY}" {S}/>
<path d="M3,-46 H46 V-10 H3 Z" fill="url(#check)" {S}/></g>
<g transform="scale(-1,1) rotate(-24)"><rect x="-3" y="-46" width="6" height="96" fill="{GREY}" {S}/>
<path d="M3,-46 H46 V-10 H3 Z" fill="url(#check)" {S}/></g>""",
    "helmet": f"""
<path d="M-44,10 Q-46,-44 4,-44 Q46,-44 46,0 L46,16 H8 L-6,32 H-36 Q-44,32 -44,10 Z" fill="{ORANGE}" {S}/>
<path d="M2,-12 H46 V12 H8 Z" fill="{INK}"/>
<path d="M-40,-14 Q-20,-36 20,-30" fill="none" stroke="{WHITE}" stroke-width="8" stroke-linecap="round"/>
<path d="M-40,-14 Q-20,-36 20,-30" fill="none" stroke="{INK}" stroke-width="2"/>
<path d="M30,-34 L52,-30 L46,-18 L28,-22 Z" fill="{YELLOW}" {S}/>""",
    # ---- the outskirts
    "ramp": f"""
<path d="M-50,40 L40,-8 V40 Z" fill="{RED}" {S}/>
<path d="M-26,40 L40,4 M0,40 L40,18" stroke="{WHITE}" stroke-width="5"/>
{star(-14, -26, 24, YELLOW, 5, 0.45)}
<path d="M18,-40 l12,-6 M24,-26 l14,-2" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>""",
    "crane": f"""
<rect x="-40" y="-44" width="10" height="92" fill="{YELLOW}" {S}/>
<path d="M-40,-44 H48 V-34 H-40 Z" fill="{YELLOW}" {S}/>
<path d="M-36,-36 L-32,40 M-32,-40 L-36,30" stroke="{INK}" stroke-width="3"/>
<path d="M30,-34 V2" stroke="{INK}" stroke-width="4"/>
<path d="M22,2 H38 V10 Q38,24 28,24 Q20,24 20,16" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
<rect x="-6" y="24" width="38" height="24" fill="{ORANGE}" {S}/>""",
    # ---- the suburbs
    "sun": f"""
<g stroke="{INK}" stroke-width="5" stroke-linecap="round">
<path d="M0,-50 V-38 M-36,-36 L-28,-28 M36,-36 L28,-28 M-50,0 H-40 M50,0 H40"/></g>
<circle cy="-2" r="28" fill="{YELLOW}" {S}/>
<path d="M-52,46 Q-30,4 0,22 Q24,0 52,30 V46 Z" fill="{LIME}" {S}/>
<path d="M-52,46 Q-10,22 30,46 Z" fill="#1aa043" {S}/>""",
    "oak": f"""
<path d="M-8,46 L-6,8 Q-20,0 -26,-4 M-6,8 L6,46 M2,6 Q14,0 20,-4" fill="none" stroke="{INK}" stroke-width="5"/>
<path d="M-12,48 L-6,4 H6 L12,48 Z" fill="{BROWN}" {S}/>
""" + union(
        '<circle cx="-24" cy="-12" r="22"/><circle cx="24" cy="-12" r="22"/><circle cx="0" cy="-30" r="24"/>'
        '<circle cx="0" cy="0" r="22"/><circle cx="-6" cy="-14" r="20"/>',
        "#2fae4e",
    ) + f"""<g fill="#7a3f1d"><ellipse cx="-20" cy="-4" rx="4" ry="5"/><ellipse cx="18" cy="-22" rx="4" ry="5"/></g>""",
    "wave": f"""
<circle cx="24" cy="-24" r="16" fill="{YELLOW}" {S}/>
<path d="M-52,40 V8 Q-48,-34 -6,-34 Q24,-34 28,-8 Q14,-20 0,-12 Q-12,-2 4,10 Q20,20 52,8 V40 Z" fill="{BLUE}" {S}/>
<path d="M-30,30 Q-20,20 -8,30 Q4,40 18,30 Q30,20 44,28" fill="none" stroke="{WHITE}" stroke-width="5" stroke-linecap="round"/>
<path d="M-4,-24 Q-28,-24 -34,0" fill="none" stroke="{WHITE}" stroke-width="5" stroke-linecap="round"/>
<path d="M-34,-44 q6,-6 12,0 q6,-6 12,0" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>""",
    # ---- the game's own name on the hero tower
    "car": CAR,
    "tyre": f"""<circle r="44" fill="{INK}"/><circle r="22" fill="{GREY}" {S}/><circle r="7" fill="{INK}"/>
<g stroke="#46464e" stroke-width="6"><path d="M0,-40 V-28 M0,40 V28 M-40,0 H-28 M40,0 H28 M-28,-28 L-20,-20 M28,28 L20,20 M28,-28 L20,-20 M-28,28 L-20,20"/></g>""",
}
