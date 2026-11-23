# Finishing detail: run by export_vehicles.py (exec, same globals) after the paint split and before the mastery
# upgrades. The pack bodies paint their lamps, tail lamps and number plates as flat palette squares; here each one
# becomes a dark housing with real pieces standing proud of it:
#   <Id>_Lamp   head lamp lenses, one untextured mesh the game lights up (Neon, Config/Vehicles Detail colours)
#   <Id>_Tail   tail lamp lenses, the same in red
#   <Id>_Trim   chrome bezels round the lenses, grille slats, side rubbing strips and the window-line strip
#               (palette-textured; the game gives it a metal finish)
#   <Id>_Plate  the number plates, one quad each, mapped onto this vehicle's cell of the plate sheet
# A piece inside a mastery zone that the upgrade rebuilds from scratch is split off as <Id>_Z<n>_<Kind> after the
# upgrades run (detail_zones below), so it goes when that upgrade is on, like the stock zone it sits on.
# Coordinates: each vehicle's own frame in studs (x = its left (+), y = its front (-), z = up), as in
# vehicle_upgrades.py.

LAMP_RGB = (0.95, 0.95, 0.9)  # palette colour of the lens meshes (they are drawn untextured in game)
HOUSING = (0.11, 0.11, 0.1)
CHROME = (0.86, 0.87, 0.9)
RUBBER = (0.14, 0.14, 0.12)
HEAD_COLS = [(0.81, 0.92, 0.95)]
TAIL_COLS = [(0.47, 0.13, 0.15)]
PLATE_COLS = [(0.96, 0.96, 0.96)]
GRILLE_COLS = [(0.14, 0.14, 0.12)]
LENS_SIDES = 12  # lens and bezel roundness (triangles: 2 * sides + 2 * (sides - 2) per cylinder)

WHITE_LAMP = [(0.92, 0.91, 0.92)]
RED_LAMP = [(0.8, 0.06, 0.07)]
# per vehicle: head / tail lamp style ("twin" round pair, "round" one big round, "bar" a slim inset lens,
# "split" = the lamp faces themselves become the lens, None = none), plate cell on the sheet (column, row), grille
# slats, side rubbing strip (height, half-length from the middle of the wheelbase) and the chrome window-line strip
# (height of the side window's bottom edge). Optional: head_cols / tail_cols (the lamp colours, when not the
# pack's), reach (how far in from each end a "split" lamp may sit, share of the length), plate_at (plates for a
# body with no plate patch: (end +1 rear / -1 front, height, width), laid on the body's surface at its middle)
DETAIL = {
    "Hatchback": dict(head="round", tail="bar", plate=(0, 0), slats=2, strip=(1.55, 2.2), belt=4.25),
    "Sedan": dict(head="twin", tail="twin", plate=(1, 0), slats=3, strip=(1.9, 3.2), belt=4.62),
    "Taxi": dict(head="twin", tail="twin", plate=(2, 0), slats=3, strip=(1.9, 3.2), belt=4.62),
    "Supercar": dict(head="split", head_cols=HEAD_COLS + WHITE_LAMP, tail="bar", plate=(3, 0), slats=0, strip=None,
                     belt=None),
    "Muscle": dict(head=None, tail="round", plate=(0, 1), slats=0, strip=None, belt=None),
    "IceCream": dict(head="round", tail="bar", plate=(1, 1), slats=2, strip=None, belt=None),
    "FireTruck": dict(head="twin", tail="round", plate=(2, 1), slats=3, strip=None, belt=None),
    "Semi": dict(head="twin", tail=None, plate=(3, 1), slats=4, strip=None, belt=None),
    "SemiTrailer": dict(head=None, tail="round", plate=None, slats=0, strip=None, belt=None),
    "Monster": dict(head="round", tail="round", plate=(0, 2), slats=0, strip=None, belt=None),
    "Bulldozer": dict(head="split", head_cols=WHITE_LAMP, tail="split", tail_cols=RED_LAMP, reach=0.25, plate=None,
                      slats=0, strip=None, belt=None),
    "Scooter": dict(head=None, tail="split", tail_cols=RED_LAMP, reach=0.3, plate=(2, 2),
                    plate_at=[(1, 3.0, 0.6)], slats=0, strip=None, belt=None),
    "Roadster": dict(head="split", head_cols=WHITE_LAMP, reach=0.2, tail=None, plate=(0, 3),
                     plate_at=[(1, 2.2, 1.6)], slats=0, strip=None, belt=None),
}
PLATE_GRID = (4, 8)  # columns, rows of 2:1 plates on the 1024 x 1024 sheet
DETAIL_DONE = {}  # vid -> {kind: object}


def _slot(vid):
    return Vector((vehicles.index(vid) * SPACING, 0, 0))


def _islands(vid, cols, where):
    """Connected faces of the Body in one of `cols`, as (face indices, centre, normal, lo, hi) in the vehicle
    frame, kept where where(centre, normal, lo, hi) holds."""
    body = bpy.data.objects[vid + "_Body"]
    o = _slot(vid)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    me = body.data
    colour = {f.index: face_colour(me, me.polygons[f.index]) for f in bm.faces}
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen or not any(near(colour[f.index], c) for c in cols):
            continue
        c0 = colour[f.index]
        isl, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen and colour[h.index] == c0:
                        seen.add(h.index)
                        stack.append(h)
        area = sum(g.calc_area() for g in isl) or 1e-9
        cen = sum((g.calc_center_median() * g.calc_area() for g in isl), Vector()) / area - o
        n = sum((g.normal * g.calc_area() for g in isl), Vector())
        n = n.normalized() if n.length > 1e-6 else Vector((0, 0, 1))
        vs = [v.co - o for g in isl for v in g.verts]
        lo = Vector([min(v[i] for v in vs) for i in range(3)])
        hi = Vector([max(v[i] for v in vs) for i in range(3)])
        if where(cen, n, lo, hi):
            out.append(([g.index for g in isl], cen, n, lo, hi))
    bm.free()
    return out


def _recolour_faces(vid, faces, rgb):
    me = bpy.data.objects[vid + "_Body"].data
    uv = uv_for(rgb)
    layer = me.uv_layers.active.data
    for i in faces:
        for li in me.polygons[i].loop_indices:
            layer[li].uv = uv


def _frame(n):
    """Outward normal flattened to the ground plane, the across direction on the face, and up."""
    out = Vector((n.x, n.y, 0))
    out = out.normalized() if out.length > 1e-6 else Vector((0, -1, 0))
    across = Vector((-out.y, out.x, 0))
    return out, across, Vector((0, 0, 1))


def _extent(vid, faces, across):
    """The island's width along `across` (in plan)."""
    me = bpy.data.objects[vid + "_Body"].data
    ds = [me.vertices[v].co.dot(across) for i in faces for v in me.polygons[i].vertices]
    return max(ds) - min(ds)


def _yaw(out):
    """The turn about the vertical that points a piece built facing +y along `out` (flat)."""
    return Matrix.Rotation(math.atan2(-out.x, out.y), 4, "Z")


def _disc(name, r, depth, at, out, rgb):
    """A cylinder of radius r and this depth whose axis runs along `out`, its back face at `at`."""
    o = cyl(name, r, depth, (0, 0, 0), rgb, "Y", LENS_SIDES)
    o.data.transform(_yaw(out))
    o.data.transform(Matrix.Translation(at + out * (depth / 2)))
    return o


def _slab(name, w, h, depth, at, out, rgb, bevel=0.0):
    """A box w across, h high, `depth` deep along `out`, its back face at `at`."""
    o = box(name, (w, depth, h), (0, 0, 0), rgb, bevel)
    o.data.transform(_yaw(out))
    o.data.transform(Matrix.Translation(at + out * (depth / 2)))
    return o


def _lenses(vid, isl, style, kit, lens_list):
    """Lenses and bezels on one lamp island, its faces turned into the dark housing."""
    faces, cen, n, lo, hi = isl
    out, across, up = _frame(n)
    w = _extent(vid, faces, across)
    h = hi.z - lo.z
    at = cen + _slot(vid)
    if style == "split":
        return faces  # the lamp faces themselves are split off as the lens
    _recolour_faces(vid, faces, HOUSING)
    if style in ("twin", "round"):
        count = 2 if style == "twin" else 1
        r = min(h * 0.42, w / (2.25 * count))
        for i in range(count):
            off = (i - (count - 1) / 2) * (w / count)
            c = at + across * off
            kit.append(_disc("bezel", r * 1.22, 0.06, c, out, CHROME))
            lens_list.append(_disc("lens", r, 0.1, c, out, LAMP_RGB))
    else:  # bar: a slim lens inset in the housing with a chrome lip under it
        lens_list.append(_slab("lens", w * 0.86, h * 0.55, 0.08, at + up * (h * 0.08), out, LAMP_RGB, 0.02))
        kit.append(_slab("lip", w * 0.9, 0.05, 0.05, at - up * (h * 0.32), out, CHROME))
    return []


def _ray_x(tree, o, y, z, side):
    """x of the body's outer side at (y, z) seen from `side` (+1 left, -1 right), or None."""
    hit = tree.ray_cast(o + Vector((side * 20, y, z)), Vector((-side, 0, 0)), 40)
    return None if hit[0] is None else (hit[0] - o).x


def _side_strip(vid, z, half, kit, rgb, tall, proud=0.04):
    """A strip along both sides at height z, `half` studs each way from the middle of the wheelbase, following
    the side in three straight pieces."""
    o = _slot(vid)
    tree = tree_of(bpy.data.objects[vid + "_Body"])
    ws = [bounds([ob])[0].y + bounds([ob])[1].y for ob in bpy.data.objects if ob.name.startswith(vid + "_Wheel_")]
    mid = (sum(ws) / len(ws)) / 2 if ws else 0.0
    ys = [mid - half + i * (2 * half / 3) for i in range(4)]
    for side in (1, -1):
        xs = [_ray_x(tree, o, y, z, side) for y in ys]
        if any(x is None for x in xs):
            continue
        for a in range(3):
            ya, yb = ys[a], ys[a + 1]
            x = side * (max(abs(xs[a]), abs(xs[a + 1])) + proud / 2)
            kit.append(box("strip", (proud, yb - ya, tall), (x, (ya + yb) / 2, z) + o, rgb))


def _plate(vid, isl, cell, plates):
    faces, cen, n, lo, hi = isl
    out, across, up = _frame(n)
    w = _extent(vid, faces, across) - 0.08
    h = (hi.z - lo.z) - 0.08
    if w / h > 2.0:
        w = h * 2.0
    else:
        h = w / 2.0
    _recolour_faces(vid, faces, HOUSING)
    at = cen + _slot(vid) + out * 0.025
    me = bpy.data.meshes.new("plate")
    bm = bmesh.new()
    a = across * (w / 2)
    b = up * (h / 2)
    # wound so the face points along `out`
    vs = [bm.verts.new(at - a - b), bm.verts.new(at + a - b), bm.verts.new(at + a + b), bm.verts.new(at - a + b)]
    f = bm.faces.new(vs)
    f.normal_update()
    if f.normal.dot(out) < 0:
        f.normal_flip()
    uvl = bm.loops.layers.uv.new()
    cols, rows = PLATE_GRID
    u0, v0 = cell[0] / cols, 1 - (cell[1] + 1) / rows
    du, dv = 1 / cols, 1 / rows
    for loop in f.loops:
        p = loop.vert.co - at
        s = 0.5 - p.dot(across) / w * (1 if out.cross(across).z < 0 else -1)
        t = 0.5 + p.z / h
        loop[uvl].uv = (u0 + s * du, v0 + t * dv)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("plate", me)
    scene.collection.objects.link(ob)
    plates.append(ob)


def _plate_on(vid, end, z, w, cell, plates):
    """A plate w wide on the body's surface (bare or painted) at its middle, height z, at the rear (end +1) or
    front (-1)."""
    o = _slot(vid)
    trees = [tree_of(bpy.data.objects[vid + k]) for k in ("_Body", "_Paint") if vid + k in bpy.data.objects]
    h = w / 2
    ys = []
    for dx in (-w / 2, 0, w / 2):
        for dz in (-h / 2, h / 2):
            for tree in trees:
                hit = tree.ray_cast(o + Vector((dx, end * 40, z + dz)), Vector((0, -end, 0)), 80)
                if hit[0] is not None:
                    ys.append((hit[0] - o).y)
    if not ys:
        print(f"DETAIL {vid} no surface for a plate at z {z}")
        return
    y = max(ys) if end > 0 else min(ys)
    out = Vector((0, end, 0))
    me = bpy.data.meshes.new("plate")
    bm = bmesh.new()
    face = [bm.verts.new(Vector((0, y, z)) + o + out * 0.03 + Vector((x * w / 2, 0, k * h / 2)))
            for x, k in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(face)
    f.normal_update()
    if f.normal.dot(out) < 0:
        f.normal_flip()
    uvl = bm.loops.layers.uv.new()
    cols, rows = PLATE_GRID
    u0, v0 = cell[0] / cols, 1 - (cell[1] + 1) / rows
    for loop in f.loops:
        p = loop.vert.co - o
        # read from outside: at the rear (+y) the viewer's right is -x, at the front +x
        s = 0.5 + (-p.x if end > 0 else p.x) / w
        t = 0.5 + (p.z - z) / h
        loop[uvl].uv = (u0 + s / cols, v0 + t / rows)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("plate", me)
    scene.collection.objects.link(ob)
    plates.append(ob)


def add_detail(vid, spec):
    o = _slot(vid)
    body = bpy.data.objects[vid + "_Body"]
    lo_b, hi_b = bounds([body])
    lo_b, hi_b = lo_b - o, hi_b - o
    length = hi_b.y - lo_b.y
    front = lambda c, n, lo, hi: c.y < lo_b.y + 0.2 * length and n.y < -0.3
    rear = lambda c, n, lo, hi: c.y > hi_b.y - 0.2 * length and n.y > 0.3
    reach = spec.get("reach", 0.3)
    near_end = {
        "head": lambda c, n, lo, hi: c.y < lo_b.y + reach * length,
        "tail": lambda c, n, lo, hi: c.y > hi_b.y - reach * length,
    }
    trim, lamps, tails, plates = [], [], [], []
    split_faces = {"Lamp": [], "Tail": []}
    for end, cols, facing, kind, lens_list in (("head", HEAD_COLS, front, "Lamp", lamps),
                                               ("tail", TAIL_COLS, rear, "Tail", tails)):
        style = spec[end]
        if not style:
            continue
        cols = spec.get(end + "_cols", cols)
        # a split lamp may face any way (the Supercar's light strips face up, the Bulldozer's are whole blocks)
        where = near_end[end] if style == "split" else facing
        for isl in _islands(vid, cols, where):
            split_faces[kind] += _lenses(vid, isl, style, trim, lens_list)
    if spec["plate"] and not spec.get("plate_at"):
        for isl in _islands(vid, PLATE_COLS, lambda c, n, lo, hi: abs(c.x) < 0.3 and (front(c, n, lo, hi) or rear(c, n, lo, hi))):
            _plate(vid, isl, spec["plate"], plates)
    for end, z, w in spec.get("plate_at", []):
        _plate_on(vid, end, z, w, spec["plate"], plates)
    if spec["slats"]:
        for faces, cen, n, lo, hi in _islands(vid, GRILLE_COLS, lambda c, n, lo, hi: front(c, n, lo, hi) and abs(c.x) < 0.5):
            out, across, up = _frame(n)
            w = _extent(vid, faces, across)
            h = hi.z - lo.z
            for i in range(spec["slats"]):
                z = (i + 1) / (spec["slats"] + 1) - 0.5
                trim.append(_slab("slat", w - 0.12, 0.06, 0.05, cen + o + up * (z * h), out, CHROME))
    if spec["strip"]:
        _side_strip(vid, spec["strip"][0], spec["strip"][1], trim, RUBBER, 0.22)
    if spec["belt"]:
        _side_strip(vid, spec["belt"], (length * 0.22), trim, CHROME, 0.06, 0.03)
    made = {}
    # the split lamps: every piece is cut from the body as it stands now, then all of them leave it at once (face
    # numbers change once faces go)
    me = body.data
    for kind, faces in split_faces.items():
        if faces:
            ids = set(faces)
            part = bmesh.new()
            part.from_mesh(me)
            part.faces.ensure_lookup_table()
            bmesh.ops.delete(part, geom=[part.faces[i] for i in range(len(part.faces)) if i not in ids], context="FACES")
            pm = bpy.data.meshes.new(vid + "_" + kind)
            part.to_mesh(pm)
            part.free()
            ob = bpy.data.objects.new(vid + "_" + kind, pm)
            scene.collection.objects.link(ob)
            (lamps if kind == "Lamp" else tails).append(ob)
    gone = set(split_faces["Lamp"]) | set(split_faces["Tail"])
    if gone:
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
        bm.to_mesh(me)
        bm.free()
    for parts, kind in ((lamps, "Lamp"), (tails, "Tail"), (trim, "Trim"), (plates, "Plate")):
        if not parts:
            continue
        ob = join(parts, vid + "_" + kind) if len(parts) > 1 else parts[0]
        ob.name = ob.data.name = vid + "_" + kind
        if kind == "Plate":
            ob.data.materials.clear()
        else:
            finish(ob)
        exported.append(ob)
        made[kind] = ob
    DETAIL_DONE[vid] = made
    counts = []
    for kind, ob in made.items():
        ob.data.calc_loop_triangles()
        counts.append(f"{kind} {len(ob.data.loop_triangles)}")
    print(f"DETAIL {vid:10s} " + ", ".join(counts))


for vid, spec in DETAIL.items():
    if vid in vehicles:
        add_detail(vid, spec)


def _key(c):
    return (round(c.x, 4), round(c.y, 4), round(c.z, 4))


def detail_zones():
    """After the upgrades: detail inside a zone the upgrade rebuilds from scratch (keep = False) moves to
    <Id>_Z<n>_<Kind>, so it goes with the stock zone when that upgrade is on."""
    for vid, n, zone, keep, deform, build in UPGRADES:
        if keep or not zone or vid not in DETAIL_DONE:
            continue
        o = _slot(vid)
        def inside(c, zone=zone):
            p = c - o
            return any(bx[0] <= p.x <= bx[1] and bx[2] <= p.y <= bx[3] and bx[4] <= p.z <= bx[5] for bx in zone if len(bx) == 6)
        for kind, ob in list(DETAIL_DONE[vid].items()):
            # whole pieces only (a lens, a bezel, a slat): each goes by its middle, so none is cut at the zone's edge
            picked = set()
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            seen = set()
            for f in bm.faces:
                if f.index in seen:
                    continue
                isl, stack = [], [f]
                seen.add(f.index)
                while stack:
                    g = stack.pop()
                    isl.append(g)
                    for e in g.edges:
                        for h in e.link_faces:
                            if h.index not in seen:
                                seen.add(h.index)
                                stack.append(h)
                mid = sum((g.calc_center_median() for g in isl), Vector()) / len(isl)
                if inside(mid):
                    picked |= {_key(g.calc_center_median()) for g in isl}
            bm.free()
            piece = split_off(ob, lambda c, col, picked=picked: _key(c) in picked, f"{vid}_Z{n}_{kind}")
            if piece:
                if kind == "Plate":
                    piece.data.materials.clear()
                exported.append(piece)
                print(f"DETAILZONE {piece.name} {len(piece.data.polygons)} faces")
