# Build the road meshes from the road layout (tools/lune/road_layout.luau writes it from Rules/RoadLayout).
#   python build_roads.py <layout.json> <out_dir>
# Needs shapely and numpy. Writes <out_dir>/meshes.json (every mesh's vertices, triangles and UVs in Roblox
# studs, for tools/blender/export_roads.py) and <out_dir>/RoadMeshes.luau (Config/RoadMeshes: where each
# mesh goes in the world).
#
# The road network is one outline: every road's centre line widened, the cul-de-sac bulbs, the inside
# corners rounded. It is cut into 512-stud chunks; each chunk is up to three MeshParts:
#   Asphalt   the surface, one tiling asphalt texture, UVs from world position (seamless across chunks)
#   Concrete  downtown kerbs and the suburb sidewalks, one tiling concrete texture
#   Trim      everything laid on top, from one atlas (Textures: trim.png): lane paint, zebras, stop lines,
#             gutters, tyre wear, the soft verge where roads meet grass, manholes, drains, patches
# Heights: the city, the ring, its stubs and connectors stand on their (invisible) collision parts at 0.10,
# the suburbs on the terrain (-0.19); the feeders ramp between the two just past the ring.
import json, math, random, sys
import numpy as np
import shapely
import shapely.prepared
from shapely.geometry import LineString, Point, Polygon, MultiPolygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union, substring

LAYOUT, OUT = sys.argv[1], sys.argv[2]
L = json.load(open(LAYOUT))
rng = random.Random(20261111)

CELL = 512
TOWN_Y = 0.13  # visual top of roads on parts (collision top 0.10)
SUB_Y = -0.15  # visual top of roads on terrain
TERRAIN_Y = -0.1875
RAMP = 60  # feeders slope from TOWN_Y to SUB_Y over this far past the ring's outer edge
FILLET = 8
T_ASPHALT = 24.0  # studs per asphalt texture tile
T_CONCRETE = 12.0
T_TRIM = 32.0  # studs along per trim atlas width
KERB_W, KERB_H = 1.2, 0.3
GUTTER_W = 1.3
VERGE_W, VERGE_IN = 2.2, 0.7
SUB_ROAD = 26
SUB_VERGE, SUB_WALK, SUB_WALK_H = 3, 6, 0.17

g = L["grid"]
span_x = g["nx"] * g["pitch"] + g["road"]
span_z = g["nz"] * g["pitch"] + g["road"]
KERB_ZONE = box(-span_x / 2 - 8, -span_z / 2 - 8, span_x / 2 + 8, span_z / 2 + 8)
RO = L["ringOuter"]

# ---------------------------------------------------------------- outline
roads = L["roads"]


def road_poly(r):
    return LineString(r["pts"]).buffer(r["width"] / 2, cap_style="flat", join_style="round", quad_segs=8)


road_polys = [road_poly(r) for r in roads]
bulbs = [Point(b[0], b[1]).buffer(b[2], quad_segs=16) for b in L["bulbs"]]
raw = unary_union(road_polys + bulbs)
outline = raw.buffer(FILLET, join_style="round", quad_segs=6).buffer(-FILLET, join_style="round", quad_segs=6)
outline = outline.simplify(0.03)
streets_raw = unary_union([p for p, r in zip(road_polys, roads) if r["kind"] == "street"] + bulbs)
connectors = unary_union([box(c["x"] - c["w"] / 2, c["z"] - c["d"] / 2, c["x"] + c["w"] / 2, c["z"] + c["d"] / 2)
                          for c in L["connectors"]])
INSIDE = unary_union([box(-RO, -RO, RO, RO), connectors.buffer(FILLET + 4, join_style="mitre")])
MID = box(-RO - RAMP, -RO - RAMP, RO + RAMP, RO + RAMP).difference(INSIDE)
INSIDE_P = shapely.prepared.prep(INSIDE)
KERB_P = shapely.prepared.prep(KERB_ZONE)


def height(x, z):
    if INSIDE_P.covers(Point(x, z)):
        return TOWN_Y
    d = max(abs(x), abs(z))
    t = min(max((d - RO) / RAMP, 0.0), 1.0)
    return TOWN_Y + t * (SUB_Y - TOWN_Y)


# ---------------------------------------------------------------- mesh pieces, gathered per chunk and layer
chunks = {}  # (i, j) -> {layer: {"v": [], "uv": [], "f": []}}


def cell_of(x, z):
    return (math.floor(x / CELL), math.floor(z / CELL))


def mesh(key, layer):
    c = chunks.setdefault(key, {})
    return c.setdefault(layer, {"v": [], "uv": [], "f": []})


def add_face(m, pts, uvs, want):
    """pts: [(x, y, z)], uvs: [(u, v)], want: the normal the face should have (Roblox axes)"""
    a, b, c = (np.array(p) for p in pts[:3])
    n = np.cross(b - a, c - a)
    if np.dot(n, want) < 0:
        pts, uvs = pts[::-1], uvs[::-1]
    base = len(m["v"])
    m["v"].extend(pts)
    m["uv"].extend(uvs)
    for k in range(1, len(pts) - 1):
        m["f"].append((base, base + k, base + k + 1))


UP = (0, 1, 0)


def quad_at(layer, corners, uvs, want=UP, key=None):
    cx = sum(p[0] for p in corners) / len(corners)
    cz = sum(p[2] for p in corners) / len(corners)
    add_face(mesh(key or cell_of(cx, cz), layer), corners, uvs, want)


# trim atlas: 8 bands of 128 px, each tiling along u; v = 1 at the image's top
BANDS = {"white": 0, "yellow": 1, "gutter": 2, "wear": 3, "verge": 4, "cells": 5, "faded": 6}
PAD = 0.06


def band_v(name, t):
    k = BANDS[name]
    return 1 - (k + PAD + t * (1 - 2 * PAD)) / 8


def cell_uv(index, s, t):
    # cells row: 8 squares of 128 px in the "cells" band
    u = (index + 0.05 + s * 0.9) / 8
    return (u, band_v("cells", t))


CELLS = {"manhole": 0, "drain": 1, "patchA": 2, "patchB": 3, "patchC": 4, "stain": 5}


def strip(layer, pts2d, w_in, w_out, y_in, y_out, band, u0=0.0, key=None, lift=0.0):
    """A strip along a polyline: from w_in to w_out off it (to the right of travel), heights by function or
    number, UV u along the line (T_TRIM per atlas width), v across the band (0 at w_in)."""
    n = len(pts2d)
    if n < 2:
        return
    normals = []
    for i in range(n):
        a = np.array(pts2d[max(i - 1, 0)])
        b = np.array(pts2d[min(i + 1, n - 1)])
        d = b - a
        ln = np.hypot(*d)
        if ln < 1e-9:
            normals.append(np.array([0.0, 0.0]))
            continue
        d = d / ln
        normals.append(np.array([d[1], -d[0]]))
    dist = [0.0]
    for i in range(1, n):
        dist.append(dist[-1] + math.dist(pts2d[i - 1], pts2d[i]))
    for i in range(n - 1):
        corners, uvs = [], []
        for (k, w, yv, tv) in ((i, w_in, y_in, 0), (i + 1, w_in, y_in, 0), (i + 1, w_out, y_out, 1), (i, w_out, y_out, 1)):
            p = np.array(pts2d[k]) + normals[k] * w
            y = yv(pts2d[k]) if callable(yv) else yv
            corners.append((float(p[0]), y + lift, float(p[1])))
            uvs.append(((u0 + dist[k]) / T_TRIM, band_v(band, tv)))
        quad_at(layer, corners, uvs, UP, key)


def rect_quad(layer, cx, cz, along, across, dx, dz, uvfun, lift, key=None):
    """a flat rectangle centred (cx, cz), `along` long in direction (dx, dz), `across` wide"""
    px, pz = -dz, dx
    y = height(cx, cz) + lift
    corners, uvs = [], []
    for (s, t) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x = cx + dx * along / 2 * s + px * across / 2 * t
        z = cz + dz * along / 2 * s + pz * across / 2 * t
        corners.append((x, y, z))
        uvs.append(uvfun((s + 1) / 2, (t + 1) / 2))
    quad_at(layer, corners, uvs, UP, key)


def rings_of(geom):
    geoms = geom.geoms if hasattr(geom, "geoms") else [geom]
    for p in geoms:
        if p.is_empty or p.geom_type != "Polygon":
            continue
        p = orient(p, 1.0)  # exterior CCW, holes CW: the polygon is always on the left
        yield list(p.exterior.coords)
        for r in p.interiors:
            yield list(r.coords)


def split_runs(coords, pred):
    """runs of consecutive ring segments whose midpoints satisfy pred"""
    runs, cur = [], []
    for a, b in zip(coords[:-1], coords[1:]):
        if pred(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)):
            if not cur:
                cur = [a]
            cur.append(b)
        elif cur:
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    # a run that wraps round the ring's start
    if len(runs) > 1 and runs[0][0] == coords[0] and runs[-1][-1] == coords[-1]:
        runs[0] = runs[-1][:-1] + runs[0]
        runs.pop()
    return runs


def densify(pts, step):
    out = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        n = max(1, int(math.dist(a, b) // step))
        for k in range(1, n + 1):
            t = k / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


# ---------------------------------------------------------------- asphalt (surface + a skirt round the edge)
def triangulate_into(geom, layer, yfun, tile, key):
    if geom.is_empty:
        return
    tris = shapely.constrained_delaunay_triangles(geom)
    m = mesh(key, layer)
    for t in tris.geoms:
        cs = list(t.exterior.coords)[:3]
        pts = [(x, yfun(x, z), z) for x, z in cs]
        uvs = [(x / tile, z / tile) for x, z in cs]
        add_face(m, pts, uvs, UP)


bx0, bz0, bx1, bz1 = outline.bounds
for i in range(math.floor(bx0 / CELL), math.floor(bx1 / CELL) + 1):
    for j in range(math.floor(bz0 / CELL), math.floor(bz1 / CELL) + 1):
        cell = box(i * CELL, j * CELL, (i + 1) * CELL, (j + 1) * CELL)
        piece = outline.intersection(cell)
        if piece.is_empty or piece.area < 1:
            continue
        for zone in (INSIDE, MID, None):
            part = piece.intersection(zone) if zone is not None else piece.difference(INSIDE).difference(MID)
            part = part.buffer(0)
            part = shapely.make_valid(part)
            polys = [g for g in (part.geoms if hasattr(part, "geoms") else [part]) if g.geom_type == "Polygon" and g.area > 0.05]
            for pg in polys:
                triangulate_into(pg, "Asphalt", height, T_ASPHALT, (i, j))

for ring in rings_of(outline):
    pts = densify(ring, 40)
    for a, b in zip(pts[:-1], pts[1:]):
        ya, yb = height(*a), height(*b)
        d = (b[0] - a[0], b[1] - a[1])
        ln = math.hypot(*d)
        if ln < 1e-6:
            continue
        out = (d[1] / ln, 0, -d[0] / ln)
        corners = [(a[0], ya, a[1]), (b[0], yb, b[1]), (b[0], ya - 0.35, b[1]), (a[0], ya - 0.35, a[1])]
        uvs = [(0, 0), (ln / T_ASPHALT, 0), (ln / T_ASPHALT, 0.015), (0, 0.015)]
        quad_at("Asphalt", corners, uvs, out)

# ---------------------------------------------------------------- edges: kerbs downtown, soft verges elsewhere
kerb_runs, verge_runs = [], []
for ring in rings_of(outline):
    kerb_runs += split_runs(ring, lambda p: KERB_P.contains(Point(p)))
    verge_runs += split_runs(ring, lambda p: not KERB_P.contains(Point(p)))


def run_normals(pts):
    ns = []
    n = len(pts)
    for k in range(n):
        a, b = pts[max(k - 1, 0)], pts[min(k + 1, n - 1)]
        d = (b[0] - a[0], b[1] - a[1])
        ln = math.hypot(*d) or 1
        ns.append((d[1] / ln, -d[0] / ln))
    return ns


drains = []
for run in kerb_runs:
    pts = densify(run, 30)
    ns = run_normals(pts)
    dist = 0.0
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        na, nb = ns[k], ns[k + 1]
        ln = math.dist(a, b)
        if ln < 1e-6:
            continue
        top = TOWN_Y + KERB_H
        ai = (a[0] + na[0] * KERB_W, a[1] + na[1] * KERB_W)
        bi = (b[0] + nb[0] * KERB_W, b[1] + nb[1] * KERB_W)
        u0, u1 = dist / T_CONCRETE, (dist + ln) / T_CONCRETE
        key = cell_of((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        # top, face to the road, back
        quad_at("Concrete", [(a[0], top, a[1]), (b[0], top, b[1]), (bi[0], top, bi[1]), (ai[0], top, ai[1])],
                [(u0, 0), (u1, 0), (u1, KERB_W / T_CONCRETE), (u0, KERB_W / T_CONCRETE)], UP, key)
        out = (-(na[0] + nb[0]) / 2, 0, -(na[1] + nb[1]) / 2)
        quad_at("Concrete", [(a[0], TOWN_Y - 0.05, a[1]), (b[0], TOWN_Y - 0.05, b[1]), (b[0], top, b[1]), (a[0], top, a[1])],
                [(u0, 0), (u1, 0), (u1, 0.03), (u0, 0.03)], out, key)
        back = (-out[0], 0, -out[2])
        quad_at("Concrete", [(ai[0], 0.0, ai[1]), (bi[0], 0.0, bi[1]), (bi[0], top, bi[1]), (ai[0], top, ai[1])],
                [(u0, 0.1), (u1, 0.1), (u1, 0.13), (u0, 0.13)], back, key)
        dist += ln
    # gutter just inside the kerb
    strip("Trim", pts, 0.0, -GUTTER_W, TOWN_Y + 0.02, TOWN_Y + 0.02, "gutter")
    # a drain every so often
    total = sum(math.dist(p, q) for p, q in zip(pts[:-1], pts[1:]))
    if total > 60:
        line = LineString(pts)
        t = 30.0
        while t < total - 20:
            p = line.interpolate(t)
            q = line.interpolate(min(t + 1, total))
            dx, dz = q.x - p.x, q.y - p.y
            ln = math.hypot(dx, dz) or 1
            dx, dz = dx / ln, dz / ln
            nx_, nz_ = dz, -dx
            drains.append((p.x - nx_ * 0.75, p.y - nz_ * 0.75, dx, dz))
            t += 95

for run in verge_runs:
    pts = densify(run, 20)
    strip("Trim", pts, -VERGE_IN, VERGE_W, lambda p: height(*p) + 0.015, TERRAIN_Y + 0.012, "verge")

for (x, z, dx, dz) in drains:
    rect_quad("Trim", x, z, 2.6, 1.3, dx, dz, lambda s, t: cell_uv(CELLS["drain"], s, t), 0.035)

# ---------------------------------------------------------------- paint
others_cache = {}


def lines_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "LineString":
        return [geom]
    return [g for g in getattr(geom, "geoms", []) if g.geom_type == "LineString"]


def paint_line(line, width, band, lift=0.03, dash=None):
    """paint along a shapely line (already clipped); dash = (length, gap) or None"""
    segs = []
    if dash:
        ln = line.length
        t = 0.0
        while t < ln:
            segs.append(substring(line, t, min(t + dash[0], ln)))
            t += dash[0] + dash[1]
    else:
        segs = [line]
    for s in segs:
        if s.length < 0.5:
            continue
        pts = densify(list(s.coords), 30)
        strip("Trim", pts, -width / 2, width / 2, lambda p: height(*p) + lift, lambda p: height(*p) + lift, band,
              u0=rng.random() * T_TRIM)


def offset_line(pts, off):
    ls = LineString(pts)
    if abs(off) < 1e-9:
        return ls
    o = ls.offset_curve(off, quad_segs=8, join_style="round")
    return o


STYLE = {
    # centre double yellow, lane dash offsets, edge lines, tyre wear offsets
    "ring": dict(yellow=True, dashes=[-22.5, 22.5], edge=True, wear=[-33.75, -11.25, 11.25, 33.75]),
    "stub": dict(yellow=True, dashes=[-16, 16], edge=False, wear=[-11, 11]),
    "connector": dict(yellow=True, dashes=[-20, 20], edge=True, wear=[-30, -10, 10, 30]),
    "feeder": dict(yellow=True, dashes=[], edge=True, wear=[-10, 10]),
    "street": dict(yellow=False, dashes=[], edge=False, wear=[-6.5, 6.5]),
    "town": dict(yellow=False, dashes=[], edge=False, wear=[-11, 11]),
}
keep = outline.buffer(-0.8)
for idx, r in enumerate(roads):
    st = STYLE[r["kind"]]
    near = road_polys[idx].buffer(10).bounds
    others = unary_union([p for k, p in enumerate(road_polys) if k != idx and box(*near).intersects(p)])
    clear = others.buffer(6)
    w = r["width"]
    pts = r["pts"]
    if r["kind"] == "street":
        pts = [tuple(p) for p in pts]
        # streets: smooth the 20-stud polyline a little for the wear lines
    for off in st["wear"]:
        o = offset_line(pts, off)
        clip = o.difference(others.buffer(2)).intersection(keep)
        for ln in lines_of(clip):
            if ln.length > 4:
                strip("Trim", densify(list(ln.coords), 20), -4.5, 4.5, lambda p: height(*p) + 0.012,
                      lambda p: height(*p) + 0.012, "wear", u0=rng.random() * T_TRIM)
    if st["yellow"]:
        for off in (-0.55, 0.55):
            for ln in lines_of(offset_line(pts, off).difference(clear).intersection(keep)):
                paint_line(ln, 0.5, "yellow")
    for off in st["dashes"]:
        for ln in lines_of(offset_line(pts, off).difference(clear).intersection(keep)):
            paint_line(ln, 0.45, "white" if rng.random() < 0.6 else "faded", dash=(14, 30))
    if st["edge"]:
        for off in (-(w / 2 - 2), w / 2 - 2):
            for ln in lines_of(offset_line(pts, off).difference(others.buffer(1.5)).intersection(keep)):
                paint_line(ln, 0.5, "white" if rng.random() < 0.5 else "faded")

# downtown strokes (zebras, stop lines, lane lines) from the layout
for s in L["strokes"]:
    along_x = s["w"] >= s["d"]
    length, width = (s["w"], s["d"]) if along_x else (s["d"], s["w"])
    dx, dz = (1, 0) if along_x else (0, 1)
    band = "yellow" if s["yellow"] else ("white" if rng.random() < 0.65 else "faded")
    u0 = rng.random()
    n = max(1, int(length // 30))
    # long lines in pieces so the wear pattern along them doesn't stretch
    for k in range(n):
        seg = length / n
        cx = s["x"] + dx * (-length / 2 + seg * (k + 0.5))
        cz = s["z"] + dz * (-length / 2 + seg * (k + 0.5))
        uu = u0 + k * seg / T_TRIM
        rect_quad("Trim", cx, cz, seg, width, dx, dz,
                  lambda a, b, uu=uu, seg=seg, band=band: (uu + a * seg / T_TRIM, band_v(band, b)), 0.03)

# ---------------------------------------------------------------- details: manholes, patches, stains
manholes = [tuple(m) for m in L["manholes"]]
for idx, r in enumerate(roads):
    if r["kind"] in ("street", "feeder", "ring", "connector"):
        line = LineString(r["pts"])
        t = 60 + rng.random() * 60
        while t < line.length - 30:
            p = line.interpolate(t)
            q = line.interpolate(min(t + 1, line.length))
            dx, dz = q.x - p.x, q.y - p.y
            ln = math.hypot(dx, dz) or 1
            off = (r["width"] / 4) * (1 if rng.random() < 0.5 else -1)
            manholes.append((p.x + dz / ln * off, p.y - dx / ln * off))
            t += 180 + rng.random() * 120
for (x, z) in manholes:
    if outline.buffer(-3).contains(Point(x, z)):
        rect_quad("Trim", x, z, 4.2, 4.2, 1, 0, lambda s, t: cell_uv(CELLS["manhole"], s, t), 0.036)

inner = outline.buffer(-3)
area = outline.area
count = int(area / 4000)
minx, minz, maxx, maxz = outline.bounds
placed = 0
tries = 0
while placed < count and tries < count * 40:
    tries += 1
    x, z = rng.uniform(minx, maxx), rng.uniform(minz, maxz)
    if not inner.contains(Point(x, z)):
        continue
    kind = rng.choice(["patchA", "patchB", "patchC", "patchA", "stain"])
    a = rng.uniform(5, 13) if kind != "stain" else rng.uniform(3, 6)
    b = rng.uniform(4, 9) if kind != "stain" else rng.uniform(2.5, 5)
    ang = rng.choice([0, math.pi / 2]) + rng.uniform(-0.08, 0.08)
    dx, dz = math.cos(ang), math.sin(ang)
    corner_ok = all(inner.contains(Point(x + dx * a / 2 * s - dz * b / 2 * t, z + dz * a / 2 * s + dx * b / 2 * t))
                    for s in (-1, 1) for t in (-1, 1))
    if not corner_ok:
        continue
    lift = 0.02 if kind != "stain" else 0.013
    rect_quad("Trim", x, z, a, b, dx, dz, lambda s, t, kind=kind: cell_uv(CELLS[kind], s, t), lift)
    placed += 1
print("patches", placed)

# ---------------------------------------------------------------- suburb sidewalks
streets_out = streets_raw.buffer(FILLET, quad_segs=6).buffer(-FILLET, quad_segs=6)
walk = streets_out.buffer(SUB_ROAD * 0 + SUB_VERGE + SUB_WALK, quad_segs=8).difference(outline.buffer(SUB_VERGE, quad_segs=8))
walk = walk.simplify(0.03)
WALK_Y = TERRAIN_Y + SUB_WALK_H
for i in range(math.floor(walk.bounds[0] / CELL), math.floor(walk.bounds[2] / CELL) + 1):
    for j in range(math.floor(walk.bounds[1] / CELL), math.floor(walk.bounds[3] / CELL) + 1):
        piece = walk.intersection(box(i * CELL, j * CELL, (i + 1) * CELL, (j + 1) * CELL))
        if piece.is_empty:
            continue
        for pg in (piece.geoms if hasattr(piece, "geoms") else [piece]):
            if pg.geom_type == "Polygon" and pg.area > 0.5:
                triangulate_into(pg, "Concrete", lambda x, z: WALK_Y, T_CONCRETE, (i, j))
for ring in rings_of(walk):
    pts = densify(ring, 40)
    for a, b in zip(pts[:-1], pts[1:]):
        d = (b[0] - a[0], b[1] - a[1])
        ln = math.hypot(*d)
        if ln < 1e-6:
            continue
        out = (d[1] / ln, 0, -d[0] / ln)
        quad_at("Concrete", [(a[0], WALK_Y, a[1]), (b[0], WALK_Y, b[1]), (b[0], TERRAIN_Y - 0.2, b[1]), (a[0], TERRAIN_Y - 0.2, a[1])],
                [(0, 0), (ln / T_CONCRETE, 0), (ln / T_CONCRETE, 0.03), (0, 0.03)], out)

# ---------------------------------------------------------------- write
meshes = []
config = []
total_tris = 0
for (i, j), layers in sorted(chunks.items()):
    for layer, m in sorted(layers.items()):
        if not m["f"]:
            continue
        v = np.array(m["v"], dtype=float)
        lo, hi = v.min(axis=0), v.max(axis=0)
        if hi[1] - lo[1] < 0.05:  # keep every mesh some thickness (Roblox sizes meshes by their box): a speck
            y = float(lo[1] - 0.05)
            n = len(m["v"])
            m["v"] += [(float(lo[0]), y, float(lo[2])), (float(lo[0]) + 0.01, y, float(lo[2])), (float(lo[0]), y, float(lo[2]) + 0.01)]
            m["uv"] += [(0.0, 0.999)] * 3
            m["f"].append((n, n + 2, n + 1))
            v = np.array(m["v"], dtype=float)
            lo, hi = v.min(axis=0), v.max(axis=0)
        centre = (lo + hi) / 2
        size = hi - lo
        name = f"Road_{i}_{j}_{layer}"
        tris = len(m["f"])
        total_tris += tris
        assert tris <= 20000, f"{name} has {tris} triangles"
        assert max(size) < 700, f"{name} spans {size}"
        meshes.append({"name": name, "layer": layer, "centre": centre.tolist(), "size": size.tolist(),
                       "verts": (v - centre).round(4).tolist(),
                       "uvs": [[round(a, 5), round(b, 5)] for a, b in m["uv"]], "faces": m["f"]})
        config.append((name, layer, centre, size))
json.dump({"meshes": meshes}, open(f"{OUT}/meshes.json", "w"))
print("meshes", len(meshes), "triangles", total_tris, "max", max(len(m["faces"]) for m in meshes))

with open(f"{OUT}/RoadMeshes.luau", "w", newline="\n") as f:
    f.write("--!strict\n-- Generated by tools/roads/build_roads.py from the road layout (Rules/RoadLayout); do not edit by hand.\n")
    f.write("-- Each road mesh: its template in ReplicatedStorage.RoadModels, where its box centre goes, and its size.\n")
    f.write("-- `Hash` is the layout these were built from (a test checks it against the current layout).\n\n")
    f.write("export type Mesh = { name: string, layer: string, at: { number }, size: { number } }\n\n")
    f.write("return table.freeze({\n")
    f.write(f'\tHash = "{L["hash"]}",\n')
    f.write(f"\tTownY = {TOWN_Y},\n\tSuburbY = {SUB_Y},\n")
    f.write(f"\tTerrainY = {TERRAIN_Y}, -- where the island's flat terrain draws its surface\n\tRamp = {RAMP},\n")
    f.write("\tMeshes = table.freeze({\n")
    for name, layer, c, s in config:
        f.write(f'\t\t{{ name = "{name}", layer = "{layer}", at = {{ {c[0]:.4f}, {c[1]:.4f}, {c[2]:.4f} }}, size = {{ {s[0]:.4f}, {s[1]:.4f}, {s[2]:.4f} }} }},\n')
    f.write("\t}) :: { Mesh },\n})\n")
