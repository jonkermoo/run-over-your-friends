# Icon style (the road UI)

Every icon in the game's UI follows these rules, so the set reads as one family. They are drawn by
`tools/ui/road_icons2.py`, which checks the rules it can and writes nothing when an icon breaks one. Panels,
buttons and bars are never images (they are coded in `client/Style`); only icons are.

## Look
- **A chunky cartoon sticker:** simple, rounded shapes, readable at 40 px. One idea per icon; no tiny detail.
- **One outline round the whole silhouette:** ink `#161616`, 6 px showing (drawn 12 wide under the fills with
  `outline()`). Parts inside the outline get thin ink edges (4 px, `piece()` / `line()`), never another thick one.
- **Flat colour from the material list only** (`MATERIALS`): red, blue, green, gold, orange, pink, black,
  white, metal, steel, glass, paper, wood. Each has a base and a shade; no other colours, no gradients.
- **Light from the top left:** the shade colour on the bottom band and the right side; **one** white highlight
  (`shine()`, 60 % opacity) near the top left. Nothing else is see-through.
- **Seams** (planks, door lines, ribbon folds) are 3 px in the material's own shade (`seam()`).
- **Thick symbols** (the $, a check, the X, handles) are a coloured stroke with an ink edge (`doubled()`). A symbol
  made of several strokes is one mark: draw all its ink edges first, then all its colours, so no edge cuts across
  another part (the $'s bar never shows an edge across the S).
- **Upright and front-on or side-on:** cars side-on facing right; nothing tilted except a tool that reads better
  at an angle (the wrench). No text, no drop shadows, no filters.

## Size
- Drawn on a 128 px grid; the view box adds 6 px all round for the outline.
- The icon's longer side, outline included, is 100 to 124 grid px (checked from the render). Wide icons (cars)
  fill the width, tall ones the height.
- Rendered at 256 px, transparent, full colour (the game never tints them), uploaded as Images
  (`tools/ui/upload_images.py`) and named `Road<Name>` in `Config/Icons`. They are preloaded behind the
  loading cover.

## Adding an icon
1. Draw it in `road_icons2.py` with the helpers only (`shape` + `outline`, `piece`, `line`, `seam`, `shine`,
   `doubled`, `base()` / `shade()` colours).
2. Run `python3 tools/ui/road_icons2.py <out_dir>` until it reports every icon within the rules, and look at
   it next to the others on the asphalt colour (`#34363b`).
3. Upload, add its id to `Config/Icons`, and log it in `ASSETS_LICENSES.md`.
