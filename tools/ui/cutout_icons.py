# Cut generated icons (drawn on plain white) out of their background: the white connected to the image's edge
# becomes see-through (white inside the icon's black outline stays), the edge is softened, and the icon is
# cropped, padded to a square and saved at 256 px.
#   python3 tools/ui/cutout_icons.py <in_dir> <out_dir> [--sheet sheet.png]
import argparse
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 256
PAD = 0.06  # of the square, kept clear round the icon
WHITE = 236  # every channel at or over this counts as background white


def cut(path: pathlib.Path) -> Image.Image:
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(np.int32)
    near_white = (a.min(axis=2) >= WHITE).astype(np.uint8) * 255
    # a copy: an image made from a numpy array shares its read-only memory, and flood fills on it do nothing
    mask = Image.fromarray(near_white).copy()
    # flood the background from every edge pixel that is white; the icon's own whites aren't reached
    w, h = mask.size
    for x in range(0, w, 8):
        for y in (0, h - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    for y in range(0, h, 8):
        for x in (0, w - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    bg = (np.asarray(mask) == 128).astype(np.uint8) * 255
    alpha = Image.fromarray(255 - bg).filter(ImageFilter.GaussianBlur(0.8))
    rgba = img.convert("RGBA")
    rgba.putalpha(alpha)
    box = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    if box:
        rgba = rgba.crop(box)
    side = max(rgba.size)
    pad = int(side * PAD)
    square = Image.new("RGBA", (side + pad * 2, side + pad * 2))
    square.paste(rgba, (pad + (side - rgba.width) // 2, pad + (side - rgba.height) // 2))
    return square.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=pathlib.Path)
    ap.add_argument("dst", type=pathlib.Path)
    ap.add_argument("--sheet", type=pathlib.Path)
    args = ap.parse_args()
    args.dst.mkdir(parents=True, exist_ok=True)
    done = []
    for p in sorted(args.src.glob("*.png")):
        out = cut(p)
        out.save(args.dst / p.name)
        done.append((p.stem, out))
    if args.sheet and done:
        cols = 8
        cell = 140
        rows = (len(done) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + 18)), (111, 138, 163))
        d = ImageDraw.Draw(sheet)
        for i, (name, im) in enumerate(done):
            x, y = (i % cols) * cell, (i // cols) * (cell + 18)
            sheet.paste(im.resize((cell - 12, cell - 12)), (x + 6, y + 6), im.resize((cell - 12, cell - 12)))
            d.text((x + 6, y + cell - 4), name, fill=(255, 255, 255))
        sheet.save(args.sheet)
    print(len(done), "icons")


if __name__ == "__main__":
    main()
