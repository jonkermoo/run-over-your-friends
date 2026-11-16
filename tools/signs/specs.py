# Every sign on the map: the board it covers (studs, width x height), its paint, its emblem and its lettering.
# Ids match src/shared/Config/Signs.luau. `group` only orders the mockup sheet.
from emblems import BLUE, CREAM, INK, LIME, ORANGE, PINK, RED, WHITE, YELLOW

NAVY = "#24306e"
PURPLE = "#8448e0"
GREEN = "#1f9a45"
FOREST = "#2e5c3c"
SKY = "#3aa8ff"


def L(text, fill=WHITE, weight=1.0, font="lucky", **kw):
    return {"text": text, "fill": fill, "weight": weight, "font": font, **kw}


STALL = (9, 2.2)
SHOP = (7, 2.2)
AD = (34, 11)
OFFICE = (60, 8)

SIGNS = {
    # the spawn plaza's four food stalls
    "Stall_HOT DOGS": {"group": "stall", "size": STALL, "emblem_scale": 0.85, "gap": 2, "bg": RED, "pattern": "stripes", "emblem": "hotdog",
                       "emblem_at": "both", "lines": [L("FRANK'S", CREAM, 0.6), L("HOT DOGS", YELLOW)]},
    "Stall_ICE CREAM": {"group": "stall", "size": STALL, "emblem_scale": 0.85, "gap": 2, "bg": PINK, "pattern": "dots", "emblem": "icecream",
                        "emblem_at": "both", "lines": [L("SCOOPS", WHITE, 0.6), L("ICE CREAM", YELLOW)]},
    "Stall_TACOS": {"group": "stall", "size": STALL, "emblem_scale": 0.85, "gap": 2, "bg": ORANGE, "pattern": "stripes", "emblem": "taco",
                    "emblem_at": "both", "lines": [L("TACO", WHITE, 1, tilt=-3), L("LOCO!", YELLOW, 1, tilt=-3)]},
    "Stall_DONUTS": {"group": "stall", "size": STALL, "emblem_scale": 0.85, "gap": 2, "bg": BLUE, "pattern": "dots", "emblem": "donut",
                     "emblem_at": "both", "lines": [L("HOLY", PINK, 0.6), L("DONUTS", WHITE)]},
    # Burger Barn: the hay-loft panel, the tall pole sign, the drive-thru and the menu board
    "BarnLoft": {"group": "barn", "size": (14.4, 6.8), "bg": YELLOW, "pattern": "rays", "trim": RED,
                 "emblem": "burger", "lines": [L("BURGER", RED), L("BARN", WHITE)]},
    "BarnPole": {"group": "barn", "size": (18, 9), "bg": RED, "pattern": "rays", "trim": YELLOW, "rays_at": (100, 100),
                 "emblem": "burger", "emblem_scale": 1.1, "lines": [L("BURGER", YELLOW), L("BARN", WHITE)]},
    "BarnDrive": {"group": "barn", "size": (14, 2.6), "bg": RED, "lane": True, "trim": YELLOW, "emblem": "arrow",
                  "emblem_at": "right", "lines": [L("DRIVE-THRU", WHITE)]},
    "BarnMenu": {"group": "barn", "size": (24, 5), "bg": "#1d1d22", "lane": True, "trim": YELLOW, "emblem": "fries",
                 "emblem_at": "both", "emblem2": "shake",
                 "lines": [L("BURGERS • FRIES • SHAKES", YELLOW), L("SINCE 1987", WHITE, 0.45, "mont")]},
    # the warehouse
    "ParcelPlanet": {"group": "warehouse", "size": (70, 9), "bg": BLUE, "pattern": "dots", "emblem": "parcel",
                     "emblem_scale": 1.15, "lines": [L("PARCEL PLANET", WHITE, wide=0.9)]},
    # downtown offices
    "Office_Synergy Corp": {"group": "office", "size": OFFICE, "bg": NAVY, "emblem": "synergy",
                            "lines": [L("SYNERGY CORP", WHITE, font="mont", wide=0.85)]},
    "Office_Paperclip Inc.": {"group": "office", "size": OFFICE, "bg": "#f4efe2", "trim": RED, "emblem": "paperclip",
                              "lines": [L("PAPERCLIP INC.", RED, font="mont", wide=0.85)]},
    "Office_MegaCorp": {"group": "office", "size": OFFICE, "bg": INK, "pattern": "grid", "trim": YELLOW,
                        "emblem": "megacorp", "lines": [L("MEGACORP", YELLOW, wide=0.8)]},
    "Office_Cubicle & Co.": {"group": "office", "size": OFFICE, "bg": WHITE, "trim": PINK, "emblem": "cube",
                             "lines": [L("CUBICLE & CO.", PINK, wide=0.85)]},
    "Office_Spreadsheet Systems": {"group": "office", "size": OFFICE, "bg": GREEN, "pattern": "grid", "emblem": "spreadsheet",
                                   "lines": [L("SPREADSHEET SYSTEMS", WHITE, font="mont", wide=0.92)]},
    "Office_Big Meeting LLC": {"group": "office", "size": OFFICE, "bg": PURPLE, "emblem": "meeting",
                               "lines": [L("BIG MEETING LLC", YELLOW, wide=0.88)]},
    "Office_Quarterly Partners": {"group": "office", "size": OFFICE, "bg": BLUE, "emblem": "chart",
                                  "lines": [L("QUARTERLY PARTNERS", WHITE, font="mont", wide=0.92)]},
    "Office_Memo Group": {"group": "office", "size": OFFICE, "bg": ORANGE, "emblem": "memo",
                          "lines": [L("MEMO GROUP", WHITE, wide=0.8)]},
    # the high-street shops' hanging signs
    "Shop_SOCK SHOP": {"group": "shop", "size": SHOP, "bg": PINK, "pattern": "stripes", "emblem": "sock",
                       "lines": [L("SOCK SHOP", WHITE)]},
    "Shop_BUN BAKERY": {"group": "shop", "size": SHOP, "bg": "#f6d6a8", "trim": "#7a3f1d", "emblem": "loaf",
                        "lines": [L("BUN BAKERY", "#7a3f1d")]},
    "Shop_BIKE BITS": {"group": "shop", "size": SHOP, "bg": BLUE, "emblem": "wheel", "lines": [L("BIKE BITS", YELLOW)]},
    "Shop_BOOK NOOK": {"group": "shop", "size": SHOP, "bg": GREEN, "emblem": "book", "lines": [L("BOOK NOOK", CREAM)]},
    "Shop_TOY BOX": {"group": "shop", "size": SHOP, "bg": YELLOW, "pattern": "rays", "trim": PINK, "emblem": "gift",
                     "lines": [L("TOY BOX", PINK)]},
    "Shop_PHONE FIX": {"group": "shop", "size": SHOP, "bg": NAVY, "emblem": "phone", "lines": [L("PHONE FIX", LIME)]},
    "Shop_FRESH FRUIT": {"group": "shop", "size": SHOP, "bg": LIME, "pattern": "dots", "emblem": "apple",
                         "lines": [L("FRESH FRUIT", WHITE)]},
    "Shop_HAT HUT": {"group": "shop", "size": SHOP, "bg": ORANGE, "emblem": "hat", "lines": [L("HAT HUT", WHITE)]},
    "Shop_PET PALS": {"group": "shop", "size": SHOP, "bg": PURPLE, "emblem": "bone", "lines": [L("PET PALS", YELLOW)]},
    "Shop_SNACK SHACK": {"group": "shop", "size": SHOP, "bg": RED, "pattern": "stripes", "emblem": "lolly",
                         "lines": [L("SNACK SHACK", YELLOW)]},
    "Shop_LAMP LAND": {"group": "shop", "size": SHOP, "bg": INK, "trim": YELLOW, "emblem": "bulb",
                       "lines": [L("LAMP LAND", YELLOW)]},
    "Shop_CHEESE PLEASE": {"group": "shop", "size": SHOP, "bg": BLUE, "emblem": "cheese",
                           "lines": [L("CHEESE PLEASE", YELLOW)]},
    # billboards (office roofs and the country road): one image per ad
    "Ad_SNAKKO CHIPS": {"group": "ad", "size": AD, "bg": YELLOW, "pattern": "rays", "trim": RED, "rays_at": (110, 100),
                        "emblem": "chips", "lines": [L("SNAKKO", RED, 1.2), L("CHIPS", BLUE, 0.8)]},
    "Ad_DRINK FIZZLE": {"group": "ad", "size": AD, "bg": BLUE, "pattern": "dots", "emblem": "soda",
                        "lines": [L("DRINK", WHITE, 0.6), L("FIZZLE!", YELLOW, 1.2, tilt=-4)]},
    "Ad_SPEED BUMPS R US": {"group": "ad", "size": AD, "bg": CREAM, "pattern": "hazard", "emblem": "bump",
                            "lines": [L("SPEED BUMPS", RED), L("R US", BLUE, 0.8)]},
    "Ad_CLEAN SOCKS DAILY": {"group": "ad", "size": AD, "bg": "#5fd0b0", "pattern": "dots", "emblem": "cleansock",
                             "lines": [L("CLEAN SOCKS", WHITE), L("DAILY!", PINK, 0.8, tilt=-4)]},
    "Ad_TRY THE BARN BURGER": {"group": "ad", "size": AD, "bg": RED, "pattern": "rays", "trim": YELLOW,
                               "rays_at": (110, 100), "emblem": "burger",
                               "lines": [L("TRY THE", CREAM, 0.6), L("BARN BURGER", YELLOW)]},
    "Ad_HONK IF YOU'RE HAPPY": {"group": "ad", "size": AD, "bg": PINK, "pattern": "stripes", "emblem": "honk",
                                "lines": [L("HONK", YELLOW, 1.2, tilt=-4), L("IF YOU'RE HAPPY", WHITE, 0.7)]},
    "Ad_MEGACORP IS HIRING": {"group": "ad", "size": AD, "bg": INK, "pattern": "grid", "trim": YELLOW,
                              "emblem": "hiring", "lines": [L("MEGACORP", YELLOW), L("IS HIRING!", WHITE, 0.7, "mont")]},
    # the hero tower over spawn
    "Hero": {"group": "hero", "size": (64, 13), "bg": INK, "lane": True, "trim": YELLOW, "emblem": "car",
             "emblem_at": "both", "emblem2": "tyre", "emblem_scale": 0.8, "gap": 4,
             "lines": [L("RUN OVER", YELLOW, tilt=-3), L("YOUR FRIENDS", PINK, tilt=-3)]},
    # the country road: gas station, its shop and the motocross gate
    "Gas": {"group": "country", "size": (11, 6), "bg": WHITE, "trim": RED, "emblem": "pump", "emblem_scale": 1.1, "gap": 0,
            "lines": [L("GAS", RED)]},
    "GasPrice": {"group": "country", "size": (9, 3.4), "bg": "#1a1a1e", "trim": "#3a3a40",
                 "lines": [L("REGULAR", WHITE, 0.45, "mont"), L("$2.49", YELLOW)]},
    "Mart": {"group": "country", "size": (12, 2.2), "bg": RED, "emblem": "basket", "emblem_at": "both",
             "lines": [L("MINI MART", WHITE)]},
    "Motocross": {"group": "country", "size": (44, 6), "bg": ORANGE, "pattern": "check", "emblem": "helmet",
                  "emblem_at": "both", "emblem2": "flags", "emblem_scale": 0.85, "lines": [L("MOTOCROSS", WHITE)]},
    # the outskirts: the stunt park gate and the building site's hoardings (a tile repeated along the fence)
    "StuntPark": {"group": "outskirts", "size": (76, 11), "bg": RED, "pattern": "stripes", "trim": YELLOW,
                  "emblem": "ramp", "emblem_at": "both", "emblem2": "tyre", "lines": [L("STUNT PARK", YELLOW, tilt=-3)]},
    "Hoard_MEGACORP TOWER": {"group": "outskirts", "size": (64, 8), "bg": NAVY, "emblem": "megacorp",
                             "emblem_at": "both", "lines": [L("MEGACORP TOWER", YELLOW, wide=0.9)]},
    "Hoard_COMING SOON": {"group": "outskirts", "size": (64, 8), "bg": INK, "lane": True, "trim": YELLOW, "emblem": "crane", "emblem_at": "both", "lines": [L("COMING SOON", YELLOW, wide=0.9)]},
    # the suburbs' entrance boards
    "Suburb_SUNNY VALE": {"group": "suburb", "size": (46, 9), "bg": ORANGE, "pattern": "rays", "rays_at": (110, 120),
                          "trim": YELLOW, "emblem": "sun", "lines": [L("WELCOME TO", CREAM, 0.45, "mont"), L("SUNNY VALE", WHITE)]},
    "Suburb_OAK HOLLOW": {"group": "suburb", "size": (46, 9), "bg": FOREST, "trim": "#a8d86a", "emblem": "oak",
                          "lines": [L("WELCOME TO", CREAM, 0.45, "mont"), L("OAK HOLLOW", CREAM)]},
    "Suburb_SEASIDE": {"group": "suburb", "size": (46, 9), "bg": SKY, "pattern": "dots", "emblem": "wave",
                       "lines": [L("WELCOME TO", WHITE, 0.45, "mont"), L("SEASIDE", YELLOW)]},
}
