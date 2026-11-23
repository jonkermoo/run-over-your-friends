# Draw the number-plate sheet for the vehicles' <Id>_Plate meshes (tools/blender/vehicle_detail.py).
# python tools/art/plates.py <out.png>
# One 1024 x 1024 image: a 4 x 8 grid of 256 x 128 plates, read left to right, top to bottom; vehicle_detail.py's
# DETAIL table names each vehicle's cell (column, row). Text in Montserrat from the Roblox install (SIL OFL 1.1).
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

COLS, ROWS, CW, CH = 4, 8, 256, 128
# (cell text, band colour) in sheet order; None and cells past the list stay blank (the Bulldozer and the Cart
# carry no plate)
PLATES = [
    ("HONK 2U", (61, 140, 92)),
    ("RUN 0VR", (52, 104, 168)),
    ("TAXI 07", (222, 160, 40)),
    ("ZOOM 1", (230, 120, 40)),
    ("V8 BEEF", (176, 58, 46)),
    ("SCOOPS", (219, 112, 147)),
    ("FIRE 13", (190, 40, 36)),
    ("BIG RIG", (90, 96, 110)),
    ("SQUASH", (96, 150, 60)),
    None,
    ("ZIP 50", (176, 58, 46)),
    None,
    ("VOLT 01", (40, 40, 44)),
]
PAPER, INK, EDGE = (244, 241, 230), (28, 30, 38), (60, 62, 70)


def font(name, size):
    if os.environ.get("ROBLOX_FONTS"):
        return ImageFont.truetype(os.path.join(os.environ["ROBLOX_FONTS"], name), size)
    local = os.environ.get("LOCALAPPDATA", "")
    found = sorted(glob.glob(os.path.join(local, "Roblox", "Versions", "*", "content", "fonts", name)))
    return ImageFont.truetype(found[-1], size)


def main(out):
    sheet = Image.new("RGB", (COLS * CW, ROWS * CH), PAPER)
    big = font("Montserrat-Black.ttf", 50)
    small = font("Montserrat-Bold.ttf", 15)
    d = ImageDraw.Draw(sheet)
    for i, cell in enumerate(PLATES):
        if cell is None:
            continue
        text, band = cell
        x0, y0 = (i % COLS) * CW, (i // COLS) * CH
        d.rounded_rectangle((x0 + 3, y0 + 3, x0 + CW - 4, y0 + CH - 4), 14, fill=PAPER, outline=EDGE, width=5)
        d.rounded_rectangle((x0 + 10, y0 + 10, x0 + CW - 11, y0 + 34), 6, fill=band)
        d.text((x0 + CW / 2, y0 + 22), "RUN OVER CITY", font=small, fill=PAPER, anchor="mm")
        d.text((x0 + CW / 2, y0 + 78), text, font=big, fill=INK, anchor="mm")
        for bx in (x0 + 24, x0 + CW - 25):
            d.ellipse((bx - 4, y0 + 104, bx + 4, y0 + 112), fill=EDGE)
    sheet.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
