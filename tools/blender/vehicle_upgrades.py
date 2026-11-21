# Mastery upgrades: run by export_vehicles.py (exec, same globals) after the paint split and before the export.
# Each upgrade n of a vehicle owns a zone of its model. The stock geometry in that zone is cut out of <Id>_Body and
# <Id>_Paint into <Id>_Z<n> and <Id>_Z<n>_Paint (shown while the upgrade is off), and the rebuilt zone is
# <Id>_U<n> (palette-textured) plus <Id>_U<n>_Paint (painted panels), shown while it is on. Upgrades that swap the
# wheels add a full set <Id>_U<n>W_<Corner><n>. Zones of one vehicle never overlap, so any mix of upgrades fits.
# Coordinates here are each vehicle's own frame in studs: x = its left (+), y = its front (-), z = up, origin = the
# middle of its Body + wheels footprint on the ground (place() puts it at (slot * SPACING, 0, 0)).
# Config/Upgrades lists the same upgrades (ids, numbers); keep the two in step.

UP_DONE = []  # (vid, n, tris) for the report


def slot_of(vid):
    return Vector((vehicles.index(vid) * SPACING, 0, 0))


class Kit:
    """The new pieces of one upgrade, each one colour: a palette rgb, or "paint" for the car's paint colour."""

    def __init__(self, vid):
        self.vid = vid
        self.o = slot_of(vid)
        self.tex, self.paint, self.wheels = [], [], []
        self.stock = {}
        for ob in bpy.data.objects:
            if ob.name.startswith(vid + "_Wheel_"):
                lo, hi = bounds([ob])
                self.stock[ob.name[len(vid) + 7:]] = (ob, (lo + hi) / 2 - self.o, (hi.z - lo.z) / 2, hi.x - lo.x)

    def _obj(self, bm, colour):
        me = bpy.data.meshes.new("up")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("up", me)
        scene.collection.objects.link(ob)
        me.transform(Matrix.Translation(self.o))
        finish(ob)
        if colour == "paint":
            self.paint.append(ob)
        else:
            paint(ob, C.get(colour, colour) if isinstance(colour, str) else colour)
            self.tex.append(ob)
        return ob

    def _prism(self, pts, a0, a1, plane, colour):
        bm = bmesh.new()

        def v(p, a):
            if plane == "yz":
                return bm.verts.new((a, p[0], p[1]))
            if plane == "xy":
                return bm.verts.new((p[0], p[1], a))
            return bm.verts.new((p[0], a, p[1]))

        lo = [v(p, a0) for p in pts]
        hi = [v(p, a1) for p in pts]
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        # each cap filled as triangles on its own (so concave outlines like a curved splitter come out right,
        # and thin pieces don't fill across from one cap to the other)
        for ring in (lo, hi):
            bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False,
                                    edges=[bm.edges.get((ring[i], ring[(i + 1) % len(ring)])) for i in range(len(ring))])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._obj(bm, colour)

    def yz(self, pts, x0, x1, colour, mirror=False):
        self._prism(pts, x0, x1, "yz", colour)
        if mirror:
            self._prism(pts, -x1, -x0, "yz", colour)

    def xy(self, pts, z0, z1, colour, mirror=False):
        self._prism(pts, z0, z1, "xy", colour)
        if mirror:
            self._prism([(-x, y) for x, y in pts], z0, z1, "xy", colour)

    def xz(self, pts, y0, y1, colour):
        self._prism(pts, y0, y1, "xz", colour)

    def box(self, c, s, colour, mirror=False, bevel=0.0):
        for sx in ((1, -1) if mirror else (1,)):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            bmesh.ops.scale(bm, vec=Vector(s), verts=bm.verts)
            bmesh.ops.translate(bm, vec=Vector((c[0] * sx, c[1], c[2])), verts=bm.verts)
            if bevel:
                bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
            self._obj(bm, colour)

    def cyl(self, c, r, depth, axis, colour, r2=None, mirror=False, verts=12):
        """A cylinder (or cone, r at the -axis end, r2 at the +axis end) along X, Y or Z."""
        for sx in ((1, -1) if mirror else (1,)):
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r if r2 is None else r2,
                                  depth=depth)
            if axis == "X":
                bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
            elif axis == "Y":
                bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
            bmesh.ops.translate(bm, vec=Vector((c[0] * sx, c[1], c[2])), verts=bm.verts)
            self._obj(bm, colour)

    def bar(self, a, b, r, colour, mirror=False, verts=8):
        for sx in ((1, -1) if mirror else (1,)):
            pa = Vector((a[0] * sx, a[1], a[2]))
            pb = Vector((b[0] * sx, b[1], b[2]))
            d = pb - pa
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=d.length)
            bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=d.to_track_quat("Z", "Y").to_matrix())
            bmesh.ops.translate(bm, vec=(pa + pb) / 2, verts=bm.verts)
            self._obj(bm, colour)

    def ball(self, c, r, colour):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=r)
        bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
        self._obj(bm, colour)

    def arch(self, corner, gap, thick, x0, x1, colour, mirror=True, seg=8, spread=math.pi):
        """A band over a wheel: a ring sector round its hub (spread radians, centred on straight up), pushed out
        from x0 to x1."""
        _, c, r, _ = self.stock[corner]
        r0, r1 = r + gap, r + gap + thick
        a0 = (math.pi - spread) / 2
        ang = [a0 + spread * i / seg for i in range(seg + 1)]
        for k in range(seg):
            a, b = ang[k], ang[k + 1]
            pts = [(c.y + math.cos(a) * r1, c.z + math.sin(a) * r1), (c.y + math.cos(b) * r1, c.z + math.sin(b) * r1),
                   (c.y + math.cos(b) * r0, c.z + math.sin(b) * r0), (c.y + math.cos(a) * r0, c.z + math.sin(a) * r0)]
            self.yz(pts, x0, x1, colour, mirror)

    def wheelset(self, n, scale=1.0, widen=1.0, only=None):
        """A new set of all the vehicle's wheels (the game swaps the whole set): each stock wheel copied, its
        radius times `scale` (bottom kept on the ground) and its width times `widen` (inner face kept), for the
        corners in `only` (all if None)."""
        for corner, (ob, c, r, w) in self.stock.items():
            s, wd = (scale, widen) if only is None or corner[:2] in only else (1.0, 1.0)
            nw = ob.copy()
            nw.data = ob.data.copy()
            scene.collection.objects.link(nw)
            side = 1 if c.x > 0 else -1
            inner = c.x - side * w / 2
            centre = Vector((inner + side * w * wd / 2, c.y, r * s)) + self.o
            nw.data.transform(Matrix.Diagonal((wd, s, s, 1.0)))
            nw.location = centre
            nw.name = f"{self.vid}_U{n}W_{corner}"
            nw.data.name = nw.name
            self.wheels.append(nw)


def cut(vid, n, boxes):
    """Cut the stock faces inside any of the boxes (x0, x1, y0, y1, z0, z1; vehicle frame) out of the Body and
    Paint into <vid>_Z<n> and <vid>_Z<n>_Paint, with clean seams along the box sides. A box with a 7th item, a list
    of palette colours, takes only faces of those colours and is not cut along its sides (a separate piece sitting
    on the body, like a hood scoop). Returns the new objects."""
    o = slot_of(vid)
    made = []
    for src, name in ((vid + "_Body", f"{vid}_Z{n}"), (vid + "_Paint", f"{vid}_Z{n}_Paint")):
        ob = bpy.data.objects.get(src)
        if not ob:
            continue
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        for bx in boxes:
            if len(bx) > 6:
                continue
            lo = Vector((bx[0], bx[2], bx[4])) + o
            hi = Vector((bx[1], bx[3], bx[5])) + o
            for axis in range(3):
                for val in (lo[axis], hi[axis]):
                    near_faces = [f for f in bm.faces if all(
                        min(v.co[k] for v in f.verts) <= hi[k] + 0.01 and max(v.co[k] for v in f.verts) >= lo[k] - 0.01
                        for k in range(3) if k != axis)]
                    if not near_faces:
                        continue
                    no = Vector((0, 0, 0))
                    no[axis] = 1
                    co = Vector((0, 0, 0))
                    co[axis] = val
                    geom = list(set(near_faces) | {e for f in near_faces for e in f.edges} | {v for f in near_faces for v in f.verts})
                    bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0005, plane_co=co, plane_no=no)
        bm.to_mesh(me)
        bm.free()

        def inside(c, col):
            p = c - o
            return any(bx[0] <= p.x <= bx[1] and bx[2] <= p.y <= bx[3] and bx[4] <= p.z <= bx[5]
                       and (len(bx) < 7 or any(near(col, k) for k in bx[6])) for bx in boxes)

        piece = split_off(ob, inside, name)
        if piece:
            exported.append(piece)
            made.append(piece)
    return made


def rebuilt(vid, n, zone, keep, deform, build):
    """One upgrade: cut its zone, copy the stock zone into the new piece when `keep` (reshaped by `deform`, a
    function of a vehicle-frame point returning the new point), then add `build`'s new pieces."""
    k = Kit(vid)
    zs = cut(vid, n, zone) if zone else []
    o = k.o
    for z in zs:
        if not keep:
            continue
        cp = z.copy()
        cp.data = z.data.copy()
        scene.collection.objects.link(cp)
        if deform:
            for v in cp.data.vertices:
                v.co = deform(v.co - o) + o
        (k.paint if z.name.endswith("_Paint") else k.tex).append(cp)
    if build:
        build(k)
    for parts, name in ((k.tex, f"{vid}_U{n}"), (k.paint, f"{vid}_U{n}_Paint")):
        if parts:
            ob = join(parts, name) if len(parts) > 1 else parts[0]
            ob.name, ob.data.name = name, name
            finish(ob) if name.endswith("_Paint") else None
            exported.append(ob)
    for w in k.wheels:
        finish(w)
        exported.append(w)
    tris = 0
    for nm in (f"{vid}_U{n}", f"{vid}_U{n}_Paint"):
        ob = bpy.data.objects.get(nm)
        if ob:
            ob.data.calc_loop_triangles()
            tris += len(ob.data.loop_triangles)
    UP_DONE.append((vid, n, tris))


def flare(corners, push, reach, top, inner=2.6):
    """A deform that pushes the body sides out round the wheels (wide arches): full push near each arch, fading to
    nothing `reach` studs along the car, over `top`, and inside `inner` (so the seams with the stock body stay
    closed)."""
    def f(p):
        ax = abs(p.x)
        if ax < inner:
            return p
        wx = min(1.0, (ax - inner) / 0.6)
        best = 0.0
        for cy in corners:
            dy = abs(p.y - cy)
            best = max(best, max(0.0, min(1.0, (reach - dy) / 0.9)))
        wz = max(0.0, min(1.0, (top - p.z) / 0.7))
        return Vector((p.x + math.copysign(push * wx * best * wz, p.x), p.y, p.z))
    return f


def arch_zone(k_corners, reach, top, inner=2.6, width=8):
    """The boxes a flare() deform needs: the body sides round each wheel."""
    out = []
    for cy in k_corners:
        out.append((inner, width, cy - reach, cy + reach, 0, top))
        out.append((-width, -inner, cy - reach, cy + reach, 0, top))
    return out


def wheel_y(vid, corner):
    k = Kit(vid)
    return k.stock[corner][1].y


# ------------------------------------------------------------------------------------------------- Hatchback
def hatch_1(k):
    k.box((0, -7.75, 1.45), (7.0, 0.9, 1.7), "paint")  # closes the cut nose
    k.yz([(-8.2, 0.55), (-8.75, 0.7), (-8.85, 2.45), (-8.2, 2.65)], -3.55, 3.55, "char")
    k.box((0, -8.85, 1.55), (6.6, 0.12, 0.35), "grey")
    k.bar((2.3, -8.75, 2.5), (2.3, -8.75, 3.65), 0.18, "char", mirror=True)
    k.bar((2.42, -8.75, 3.65), (-2.42, -8.75, 3.65), 0.17, "char")
    k.bar((2.3, -8.75, 3.65), (2.0, -7.0, 3.8), 0.15, "char", mirror=True)
    k.box((0, -6.6, 0.42), (5.0, 2.8, 0.18), "grey")
    k.cyl((1.7, -9.0, 1.25), 0.24, 0.4, "Y", "lamp")
    for x in (0.9, 2.6):
        k.cyl((x, -8.9, 2.1), 0.26, 0.1, "Y", "pale", mirror=True)


def hatch_2(k):
    k.wheelset(2, widen=1.3)
    for cy in (k.stock["FL1"][1].y, k.stock["RL1"][1].y):
        k.box((3.95, cy + (1.7 if cy < 0 else -1.7), 0.75), (0.5, 0.1, 0.9), "black", mirror=True)  # mud flaps
    k.box((3.85, -0.2, 0.72), (0.5, 6.2, 0.45), "paint", mirror=True)  # sills
    k.box((4.12, -0.2, 0.62), (0.06, 6.0, 0.16), "black", mirror=True)


def hatch_3(k):
    k.yz([(-1.0, 6.2), (-1.0, 6.45), (0.8, 6.95), (1.6, 6.95), (1.6, 6.2)], -0.9, 0.9, "paint")
    k.box((0, 0.6, 6.7), (1.4, 0.08, 0.35), "black")
    k.box((0, -1.55, 6.5), (5.0, 0.55, 0.6), "black", bevel=0.05)
    for x in (0.75, 2.0):
        k.cyl((x, -1.86, 6.5), 0.22, 0.12, "Y", "pale", mirror=True)
    k.yz([(5.2, 6.1), (5.2, 6.35), (7.3, 6.6), (7.45, 6.32)], -3.4, 3.4, "paint")
    k.yz([(5.3, 5.0), (7.45, 5.0), (7.45, 6.7), (5.3, 6.45)], 3.4, 3.55, "black", mirror=True)


# ------------------------------------------------------------------------------------------------- Scooter
def scoot_1(k):
    k.yz([(-3.85, 3.0), (-3.45, 5.4), (-3.15, 5.75), (-2.1, 5.55), (-2.5, 3.0), (-3.2, 2.55)], -0.8, 0.8, "paint")
    k.yz([(-3.45, 5.4), (-3.35, 6.15), (-3.05, 6.15), (-3.15, 5.75)], -0.55, 0.55, "screen")
    k.cyl((0.0, -3.72, 4.3), 0.3, 0.2, "Y", "pale")
    k.box((0, -3.0, 2.05), (1.5, 1.2, 0.2), "char")


def scoot_2(k):
    k.bar((-1.05, 1.0, 1.1), (-1.05, 4.7, 1.75), 0.17, "chrome")
    k.bar((-1.4, 1.0, 1.45), (-1.4, 4.7, 2.1), 0.17, "chrome")
    k.cyl((-1.05, 4.78, 1.76), 0.22, 0.3, "Y", "black")
    k.cyl((-1.4, 4.78, 2.11), 0.22, 0.3, "Y", "black")
    k.box((1.55, 2.4, 3.0), (0.06, 1.4, 0.6), "black", mirror=True)  # cooling slots


def scoot_3(k):
    k.wheelset(3, scale=1.15, widen=1.9)
    for corner in ("FR1", "RR1"):
        k.arch(corner, 0.35, 0.2, -0.85, 0.85, "paint", mirror=False, spread=math.pi * 0.7)


# ------------------------------------------------------------------------------------------------- Shopping Cart
def cart_1(k):
    k.yz([(-4.35, 2.45), (-5.2, 2.85), (-5.35, 5.6), (-4.35, 6.1)], -2.55, 2.55, "mid")
    for z in (3.4, 4.9):
        k.box((0, -5.32, z), (5.2, 0.12, 0.28), "dark")
    for x in (-2.0, -1.0, 0.0, 1.0, 2.0):
        for z in (3.4, 4.9):
            k.ball((x, -5.4, z), 0.09, "light")


def cart_2(k):
    for x, z in ((-0.85, 6.6), (0.0, 7.1), (0.85, 6.6)):
        k.cyl((x, 4.4, z), 0.38, 3.0, "Y", "lamp")
        k.cyl((x, 2.45, z), 0.02, 0.9, "Y", "white", r2=0.38)
        k.cyl((x, 6.1, z), 0.28, 0.5, "Y", "dark", r2=0.45)
        k.yz([(5.2, z), (6.3, z - 0.75), (6.3, z - 0.55), (5.6, z)], x - 0.05, x + 0.05, "yellow")
        k.box((x, 4.4, z + 0.05), (0.8, 0.08, 0.8), "white")
    k.box((0, 4.6, 6.75), (2.6, 0.35, 1.2), "black")


def cart_3(k):
    k.wheelset(3, scale=1.9, widen=1.7)
    for corner, (_, c, r, w) in k.stock.items():
        k.bar((c.x + 0.45, c.y, r * 1.9), (c.x + 0.45, c.y, 2.75), 0.12, "mid")
        k.bar((c.x - 0.45, c.y, r * 1.9), (c.x - 0.45, c.y, 2.75), 0.12, "mid")
        k.cyl((c.x, c.y, r * 1.9), 0.18, 1.1, "X", "dark")
        k.box((c.x, c.y, 2.78), (1.2, 0.8, 0.12), "mid")


# ------------------------------------------------------------------------------------------------- Sedan
def sedan_1(k):
    k.bar((1.6, -10.65, 0.8), (1.6, -10.65, 4.1), 0.2, "char", mirror=True)
    for z in (2.2, 3.5):
        k.bar((2.45, -10.7, z), (-2.45, -10.7, z), 0.17, "char")
    k.bar((1.6, -10.65, 3.0), (1.6, -9.4, 3.0), 0.15, "char", mirror=True)
    k.yz([(-10.1, 0.8), (-10.85, 0.95), (-10.85, 1.9), (-10.1, 1.9)], -1.9, 1.9, "char")
    k.cyl((0.9, -10.92, 1.4), 0.22, 0.1, "Y", "lamp", mirror=True)


def sedan_2(k):
    k.yz([(8.4, 0.55), (10.4, 1.05), (10.4, 1.55), (8.4, 1.35)], -3.3, 3.3, "char")
    for x in (-1.8, 0.0, 1.8):
        k.yz([(8.8, 0.42), (10.4, 0.86), (10.4, 1.1), (8.8, 0.7)], x - 0.06, x + 0.06, "black")
    for x in (1.5, 2.2):
        k.cyl((x, 10.3, 1.2), 0.21, 0.8, "Y", "chrome", mirror=True)
        k.cyl((x, 10.71, 1.2), 0.14, 0.04, "Y", "black", mirror=True)
    k.yz([(8.5, 4.5), (8.5, 4.75), (10.0, 4.95), (10.1, 4.62)], -3.5, 3.5, "paint")


def sedan_3(k):
    k.wheelset(3, widen=1.25)
    k.box((3.9, -0.95, 0.62), (0.4, 7.6, 0.5), "paint", mirror=True)
    k.box((4.13, -0.95, 0.5), (0.06, 7.4, 0.16), "black", mirror=True)


# ------------------------------------------------------------------------------------------------- Taxi
def taxi_1(k):
    k.box((0.0, 0.85, 6.95), (3.6, 4.8, 0.2), "black")
    k.yz([(-1.3, 7.05), (-0.8, 9.6), (2.5, 9.6), (3.0, 7.05)], -1.5, 1.5, "amber")
    k.yz([(-0.95, 7.6), (-0.6, 9.2), (2.3, 9.2), (2.65, 7.6)], 1.5, 1.56, "white", mirror=True)
    k.box((0, 0.85, 9.65), (2.8, 3.0, 0.1), "black")


def taxi_2(k):
    for i in range(9):
        x = -3.2 + i * 0.8
        k.bar((x, -12.2, 0.5), (x * 0.92, -10.35, 3.05), 0.1, "char")
    k.bar((3.3, -12.25, 0.5), (-3.3, -12.25, 0.5), 0.16, "char")
    k.bar((3.1, -10.4, 3.05), (-3.1, -10.4, 3.05), 0.16, "char")
    k.bar((3.3, -12.25, 0.5), (3.0, -10.4, 3.05), 0.16, "char", mirror=True)


def taxi_3(k):
    k.box((3.1, 7.9, 4.85), (0.16, 2.8, 0.26), "chrome", mirror=True)
    for y in (6.8, 7.9, 9.0):
        k.box((0, y, 4.75), (6.4, 0.16, 0.14), "chrome")
    k.box((0, 7.9, 5.17), (4.0, 2.0, 0.5), "brown", bevel=0.06)
    k.box((0, 7.9, 5.45), (0.8, 0.2, 0.12), "black")
    k.yz([(9.3, 4.6), (9.3, 5.25), (9.9, 5.25), (9.9, 4.6)], -0.6, 0.6, "white")
    k.cyl((0, 9.6, 5.45), 0.3, 0.5, "Z", "amber")


# ------------------------------------------------------------------------------------------------- Muscle
def muscle_1(k):
    k.box((0, -6.3, 5.0), (1.9, 2.6, 1.05), "chrome", bevel=0.06)
    k.box((0, -6.3, 4.62), (2.3, 3.0, 0.2), "black")
    k.cyl((0, -7.7, 4.9), 0.55, 0.3, "Y", "dark")
    k.yz([(-7.3, 5.5), (-7.5, 6.55), (-5.3, 6.55), (-4.9, 5.5)], -1.15, 1.15, "black")
    k.box((0, -7.5, 6.1), (1.9, 0.08, 0.6), "dark")


def muscle_2(k):
    k.wheelset(2, widen=1.4, only=("RL", "RR"))
    k.box((4.05, -0.5, 0.82), (0.55, 8.6, 0.55), "paint", mirror=True)
    for y in (-2.5, -0.9, 1.0, 3.0):
        k.cyl((4.36, y, 1.0), 0.08, 0.08, "X", "chrome", mirror=True)


def muscle_3(k):
    # the nose rebuilt as a sloped ram in body colour, with a steel lower plate, a spike and a light bar
    k.yz([(-9.0, 1.4), (-10.9, 1.5), (-11.3, 2.7), (-10.5, 3.9), (-9.0, 4.15)], -3.7, 3.7, "paint")
    k.yz([(-9.0, 0.6), (-11.1, 0.8), (-11.3, 1.55), (-9.0, 1.45)], -3.6, 3.6, "char")
    k.yz([(-11.0, 1.6), (-11.95, 1.9), (-11.95, 2.7), (-11.15, 3.0)], -0.4, 0.4, "chrome")
    k.box((0, -10.95, 3.15), (5.4, 0.08, 0.22), "pale")


# ------------------------------------------------------------------------------------------------- Ice-Cream Truck
def ice_1(k):
    k.box((0, -3.5, 11.15), (2.4, 2.4, 0.5), "white", bevel=0.08)
    k.cyl((0, -3.5, 13.75), 0.25, 4.8, "Z", "tan", r2=2.4)
    k.cyl((0, -3.5, 16.75), 2.75, 1.3, "Z", "pink", r2=2.55)
    k.cyl((0, -3.5, 18.0), 2.55, 1.25, "Z", "cream", r2=1.9)
    k.cyl((0, -3.5, 19.15), 1.9, 1.1, "Z", "pink", r2=1.2)
    k.cyl((0, -3.5, 20.15), 1.2, 0.95, "Z", "cream", r2=0.3)
    k.ball((0, -3.5, 20.9), 0.5, "lamp")


def ice_2(k):
    k.yz([(-11.4, 0.9), (-13.3, 1.1), (-13.6, 2.2), (-13.3, 3.5), (-11.4, 3.7)], -5.3, 5.3, "pale")
    for x in (-3.0, 0.0, 3.0):
        k.yz([(-13.35, 1.3), (-13.65, 2.2), (-13.35, 3.3)], x - 0.9, x + 0.9, "glow")


def ice_3(k):
    k.box((4.75, 2.25, 7.5), (1.3, 6.5, 5.0), "char", bevel=0.08)
    for y in (0.6, 3.9):
        for z in (6.3, 8.8):
            k.cyl((5.4, y, z), 0.95, 0.1, "X", "dark")
            k.cyl((5.47, y, z), 0.35, 0.1, "X", "grey")
    for x in (2.0, -2.0):
        k.cyl((x, 12.8, 9.6), 0.25, 2.2, "Y", "chrome", r2=0.9)


# ------------------------------------------------------------------------------------------------- Fire Truck
def fire_1(k):
    k.cyl((0, -0.5, 13.25), 1.7, 0.7, "Z", "chrome")
    k.box((0, -0.5, 14.25), (1.6, 2.0, 1.4), "red", bevel=0.08)
    k.bar((0, 0.3, 14.6), (0, -9.0, 17.0), 0.6, "chrome", verts=12)
    k.bar((0, -9.0, 17.0), (0, -10.4, 17.35), 0.42, "black", verts=12)
    k.bar((0, -0.6, 14.9), (0, -5.5, 16.15), 0.3, "char")


def fire_2(k):
    k.yz([(-21.2, 1.2), (-23.3, 1.6), (-23.45, 4.6), (-21.2, 5.0)], -7.0, 7.0, "mid")
    for x in (-5.0, -2.5, 0, 2.5, 5.0):
        k.yz([(-23.3, 1.6), (-23.85, 2.0), (-23.85, 4.2), (-23.4, 4.6)], x - 0.25, x + 0.25, "dark")


def fire_3(k):
    k.box((6.75, 5.0, 7.0), (1.2, 9.0, 6.8), "mid", mirror=True)
    for y in (2.4, 7.6):
        k.cyl((7.7, y, 7.6), 1.6, 0.7, "X", "red", mirror=True, verts=16)
        k.cyl((7.85, y, 7.6), 0.55, 0.9, "X", "char", mirror=True)
    for y in (4.6, 5.5):
        k.cyl((7.4, y, 5.0), 0.35, 0.1, "X", "white", mirror=True)


# ------------------------------------------------------------------------------------------------- Semi
def semi_1(k):
    for x in (2.6, 5.1):
        k.bar((x, -12.5, 0.9), (x, -12.5, 6.8), 0.26, "chrome", mirror=True)
    for z in (3.0, 5.0, 6.8):
        k.bar((5.4, -12.55, z), (-5.4, -12.55, z), 0.22, "chrome")
    k.bar((5.1, -12.5, 6.8), (5.1, -10.4, 7.6), 0.22, "chrome", mirror=True)
    k.yz([(-11.3, 0.7), (-12.7, 0.8), (-12.7, 1.6), (-11.3, 1.6)], -5.6, 5.6, "char")


def semi_2(k):
    k.cyl((5.9, -2.2, 11.0), 0.48, 16.0, "Z", "chrome", mirror=True)
    k.cyl((5.9, -2.2, 19.2), 0.6, 0.5, "Z", "black", r2=0.48, mirror=True)
    k.bar((5.9, -2.2, 8.0), (5.3, -2.2, 8.0), 0.12, "chrome", mirror=True)
    k.yz([(-10.5, 14.1), (-11.7, 14.4), (-11.5, 14.8), (-10.3, 14.75)], -5.2, 5.2, "paint")
    for x in (1.3, 2.5):
        k.cyl((x, -4.5, 15.1), 0.3, 1.8, "Y", "chrome", r2=0.08, mirror=True)


def semi_3(k):
    # on the trailer (its own frame: the coupling end is -y)
    k.box((6.0, -1.15, 2.6), (0.4, 23.0, 2.6), "mid", mirror=True)
    for y in (-10.6, -4.6, 1.4, 7.4):
        k.xy([(6.2, y - 1.2), (7.9, y + 0.8), (7.9, y + 1.3), (6.2, y + 1.0)], 1.4, 3.8, "yellow", mirror=True)


# ------------------------------------------------------------------------------------------------- Bulldozer
# (the stock blade, stack and ripper come from export_vehicles.py; blade_face is shared with it)
def dozer_1(k):
    # a U-blade: a taller, wider curved moldboard with wings swung forward at each end, teeth along the steel
    # cutting edge, ribs behind, a spill guard on top and longer push arms
    k.yz(blade_face(-13.6, 0.3, 9.2, 1.3, 0.6, 0.45), -9.6, 9.6, "paint")
    k.xy([(9.5, -13.4), (12.1, -15.3), (12.4, -14.9), (9.5, -12.95)], 0.3, 8.4, "paint", mirror=True)
    k.xy([(9.4, -13.75), (12.15, -15.75), (12.45, -15.3), (9.4, -13.35)], 0.0, 0.55, "mid", mirror=True)
    k.box((0, -13.45, 0.3), (19.2, 0.55, 0.6), "mid")
    for i in range(9):
        x = -8.0 + i * 2.0
        k.xy([(x - 0.45, -13.65), (x, -14.6), (x + 0.45, -13.65)], 0.05, 0.45, "mid")
    for x in (-8.0, -5.3, -2.65, 0.0, 2.65, 5.3, 8.0):
        k.box((x, -11.4, 4.6), (0.4, 0.9, 7.6), "char")
    for i in range(11):
        x = -8.0 + i * 1.6
        k.bar((x, -13.9, 9.1), (x, -13.9, 11.0), 0.13, "char")
    k.bar((-9.0, -13.9, 11.0), (9.0, -13.9, 11.0), 0.2, "char")
    k.bar((-9.0, -13.9, 9.1), (-9.0, -13.9, 11.0), 0.2, "char")
    k.bar((9.0, -13.9, 9.1), (9.0, -13.9, 11.0), 0.2, "char")
    k.bar((7.8, -11.0, 2.5), (8.3, -12.3, 2.7), 0.45, "paint", mirror=True)
    k.bar((5.0, -9.0, 8.0), (5.8, -12.3, 6.6), 0.36, "paint", mirror=True)


def dozer_2(k):
    # turbo diesel: twin stacks with heat shields and flap caps, and a big precleaner bowl between them
    for sx in (1, -1):
        x = 2.4 * sx
        k.cyl((x, -4.92, 14.6), 0.45, 6.4, "Z", "char")
        k.cyl((x, -4.92, 14.0), 0.62, 2.8, "Z", "chrome", verts=14)
        for z in (12.9, 14.0, 15.1):
            k.cyl((x, -4.92, z), 0.66, 0.12, "Z", "char", verts=14)
        k.yz([(-5.5, 17.75), (-4.42, 17.75), (-4.42, 17.95), (-5.35, 18.35)], x - 0.48, x + 0.48, "black")
    k.cyl((0, -3.4, 12.6), 0.8, 1.4, "Z", "char", verts=16)
    k.cyl((0, -3.4, 13.65), 0.95, 0.7, "Z", "mid", verts=16)
    k.cyl((0, -3.4, 14.15), 0.95, 0.3, "Z", "black", r2=0.45, verts=16)
    k.bar((0, -3.4, 12.4), (-1.6, -3.4, 12.0), 0.28, "char")


def dozer_3(k):
    # a three-shank ripper on a wide beam: links back to the hull, two cylinders, curved shanks with steel tips
    k.box((0, 12.7, 5.0), (8.4, 1.1, 2.8), "paint", bevel=0.1)
    k.bar((2.4, 10.4, 6.8), (2.4, 12.2, 6.1), 0.32, "char", mirror=True)
    k.bar((2.4, 10.4, 4.5), (2.4, 12.2, 4.2), 0.32, "char", mirror=True)
    k.bar((1.2, 10.6, 7.9), (1.2, 12.3, 6.4), 0.4, "paint", mirror=True)
    shank = [(12.6, 6.2), (14.2, 6.2), (14.2, 3.4), (13.4, 1.2), (12.1, 0.25), (11.7, 0.9), (12.6, 2.3), (12.9, 4.6)]
    tip = [(12.1, 0.25), (11.0, 0.2), (10.9, 0.5), (11.7, 0.9)]
    for x in (-3.0, 0.0, 3.0):
        k.yz(shank, x - 0.42, x + 0.42, "char")
        k.yz(tip, x - 0.46, x + 0.46, "mid")


# ------------------------------------------------------------------------------------------------- Monster
def monster_1(k):
    k.bar((4.1, 2.8, 8.6), (3.7, 2.8, 13.2), 0.24, "black", mirror=True)
    k.bar((3.7, 2.8, 13.2), (-3.7, 2.8, 13.2), 0.24, "black")
    k.bar((3.7, 2.8, 13.2), (4.1, 11.0, 8.6), 0.22, "black", mirror=True)
    k.bar((3.7, 2.8, 11.2), (-3.7, 2.8, 11.2), 0.2, "black")
    k.box((0, -1.6, 12.75), (7.2, 0.6, 0.6), "black", bevel=0.05)
    for x in (-2.8, -1.4, 0.0, 1.4, 2.8):
        k.cyl((x, -1.95, 12.75), 0.24, 0.12, "Y", "pale")


def monster_2(k):
    k.yz([(-12.2, 3.6), (-14.0, 3.8), (-14.0, 6.2), (-12.2, 6.4)], -6.0, 6.0, "char")
    for i in range(7):
        x = -5.1 + i * 1.7
        k.xy([(x - 0.55, -14.0), (x, -15.3), (x + 0.55, -14.0)], 4.0, 6.0, "mid")


def monster_3(k):
    k.wheelset(3, scale=1.15, widen=1.3)


# ------------------------------------------------------------------------------------------------- Supercar
def super_1(k):
    k.yz([(-9.2, 0.25), (-11.7, 0.25), (-11.7, 0.45), (-9.2, 0.6)], -4.7, 4.7, "black")
    for z in (1.3, 1.9):
        k.xy([(4.3, -9.7), (5.15, -9.1), (5.15, -8.8), (4.3, -8.4)], z, z + 0.12, "black", mirror=True)


def super_2(k):
    k.yz([(8.5, 5.6), (10.6, 5.85), (10.7, 6.15), (8.4, 5.95)], -4.6, 4.6, "black")
    k.yz([(8.2, 5.0), (11.0, 5.0), (11.0, 6.55), (8.2, 6.35)], 4.6, 4.75, "black", mirror=True)
    k.bar((1.6, 9.3, 3.8), (1.6, 9.6, 5.4), 0.14, "chrome", mirror=True)
    k.bar((1.6, 9.6, 5.4), (1.6, 9.2, 5.75), 0.14, "chrome", mirror=True)


def super_3(k):
    k.yz([(2.0, 5.3), (2.0, 5.75), (7.4, 4.8), (7.4, 4.35)], -2.6, 2.6, "paint")
    for i in range(5):
        y = 3.2 + i * 0.85
        z = 5.72 - (y - 2.0) * 0.176
        k.box((0, y, z + 0.04), (4.6, 0.12, 0.12), "black")
    k.cyl((1.3, 2.3, 5.95), 0.45, 1.0, "Y", "black", mirror=True)
    k.cyl((1.3, 1.75, 5.95), 0.5, 0.12, "Y", "chrome", mirror=True)


# ------------------------------------------------------------------------------------------------- Roadster
# The Roadster is one smooth, rounded body (not the pack's flat panels), so its upgrades are thin swept pieces that
# follow its lines: NOSE is its front edge (half width -> y) measured off the stock mesh near the ground.
NOSE = [(0.0, -9.99), (0.5, -9.98), (1.0, -9.93), (1.5, -9.83), (2.0, -9.65), (2.5, -9.37), (3.0, -8.95), (3.5, -8.59),
        (4.0, -8.06)]


def nose_y(x):
    x = min(abs(x), NOSE[-1][0])
    for (x0, y0), (x1, y1) in zip(NOSE, NOSE[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return NOSE[-1][1]


def road_1(k):
    # aero nose: a carbon splitter following the curve of the nose, end plates, two canards each side
    xs = [i * 0.25 for i in range(-16, 17)]
    k.xy([(x, nose_y(x) - 0.6) for x in xs] + [(x, nose_y(x) + 0.5) for x in reversed(xs)], 0.28, 0.42, "black")
    k.yz([(-8.95, 0.28), (-7.95, 0.28), (-7.85, 0.85), (-8.5, 1.0)], 4.02, 4.14, "black", mirror=True)
    k.xy([(3.3, -9.0), (4.15, -8.6), (4.2, -8.35), (3.6, -8.1)], 1.15, 1.24, "black", mirror=True)
    k.xy([(3.5, -8.6), (4.2, -8.2), (4.22, -8.0), (3.75, -7.92)], 1.6, 1.69, "black", mirror=True)


def road_2(k):
    # afterburner: a nozzle set into the rear between the diffuser fins, in a body-coloured shroud, petals round a
    # glowing core
    c = (0, 0, 1.9)
    k.cyl((0, 9.7, c[2]), 0.95, 1.4, "Y", "paint", r2=0.84, verts=20)
    k.cyl((0, 10.45, c[2]), 0.9, 0.12, "Y", "chrome", verts=20)
    k.cyl((0, 10.78, c[2]), 0.82, 0.56, "Y", "char", r2=0.7, verts=20)
    for a in range(8):
        t = a * math.pi / 4
        k.bar((math.cos(t) * 0.82, 10.52, c[2] + math.sin(t) * 0.82), (math.cos(t) * 0.7, 11.04, c[2] + math.sin(t) * 0.7),
              0.045, "black")
    # the open end: a dark lip, then the glow and its white-hot core just proud of it
    k.cyl((0, 11.08, c[2]), 0.7, 0.04, "Y", "black", verts=20)
    k.cyl((0, 11.11, c[2]), 0.56, 0.04, "Y", "orange", verts=20)
    k.cyl((0, 11.14, c[2]), 0.28, 0.04, "Y", "pale", verts=16)


def road_3(k):
    # flight fins: swept wings from the sills with dark flaps and upturned tips, and two small tail fins
    k.xy([(3.6, -1.5), (4.6, -0.4), (5.5, 1.1), (6.2, 2.7), (6.4, 3.8), (6.1, 4.25), (3.6, 4.0)], 1.05, 1.22, "paint",
         mirror=True)
    k.xy([(3.6, 4.0), (6.1, 4.25), (6.0, 4.55), (3.6, 4.35)], 1.08, 1.19, "black", mirror=True)
    k.yz([(2.4, 1.05), (4.4, 1.0), (4.7, 2.3), (3.9, 2.4)], 6.15, 6.32, "black", mirror=True)
    k.yz([(6.6, 3.5), (9.3, 3.4), (9.6, 4.75), (9.0, 4.8)], 2.1, 2.25, "paint", mirror=True)


# ------------------------------------------------------------------------------------------------- the list
# the stock size of each vehicle (Body, Paint and wheels), taken before any cut, for the decal layout below
DECAL_BOX = {}
for vid in vehicles:
    parts = [ob for ob in bpy.data.objects if ob.name in (vid + "_Body", vid + "_Paint") or ob.name.startswith(vid + "_Wheel_")]
    lo, hi = bounds(parts)
    DECAL_BOX[vid] = (lo - slot_of(vid), hi - slot_of(vid))

W = math.inf
UPGRADES = [
    # (vehicle model, n, zone boxes (x0, x1, y0, y1, z0, z1), keep the stock zone, deform, build)
    ("Hatchback", 1, [(-W, W, -W, -7.3, -W, 2.3)], False, None, hatch_1),
    ("Hatchback", 3, [(-4.5, 4.5, -1.6, 5.6, 5.9, W)], True, None, hatch_3),
    ("Scooter", 1, [(-1.5, 1.5, -2.6, -1.6, 1.9, 5.3)], False, None, scoot_1),
    ("Scooter", 2, [(-2.5, 2.5, 0.4, 4.7, 1.5, 4.35)], True,
     lambda p: Vector((0.1 + (p.x - 0.1) * 1.35, 0.4 + (p.y - 0.4) * 1.07, p.z)), scoot_2),
    ("Scooter", 3, [], False, None, scoot_3),
    ("Cart", 1, [(-W, W, -W, -3.95, 2.4, W)], False, None, cart_1),
    ("Cart", 2, [(-W, W, 3.3, W, 5.6, W)], True, None, cart_2),
    ("Cart", 3, [(-W, W, -W, W, -W, 2.55)], False, None, cart_3),
    ("Sedan", 1, [(-W, W, -W, -9.6, -W, 2.4)], True, None, sedan_1),
    ("Sedan", 2, [(-W, W, 8.9, W, -W, 2.4)], True, None, sedan_2),
    ("Taxi", 1, [(-2.5, 2.5, -1.5, 3.5, 6.85, W)], False, None, taxi_1),
    ("Taxi", 2, [(-W, W, -W, -9.6, -W, 2.4)], True, None, taxi_2),
    ("Taxi", 3, [(-W, W, 6.7, 9.4, 4.25, 5.3)], True, None, taxi_3),
    ("Muscle", 1, [(-1.4, 1.4, -7.5, -3.6, 4.2, 5.0, [(0.11, 0.11, 0.1)])], False, None, muscle_1),
    ("Muscle", 3, [(-W, W, -W, -9.0, -W, 4.3)], False, None, muscle_3),
    ("IceCream", 1, [(-3.0, 3.0, -8.0, 2.0, 9.5, W, [(0.67, 0.49, 0.28), (0.72, 0.45, 0.73)])], False, None, ice_1),
    ("IceCream", 2, [(-W, W, -W, -11.0, -W, 3.9)], False, None, ice_2),
    ("IceCream", 3, [(3.5, W, -1.2, 5.6, 4.9, 10.1)], False, None, ice_3),
    ("FireTruck", 1, [(-2.6, 2.6, -3.0, 2.6, 12.95, W)], False, None, fire_1),
    ("FireTruck", 2, [(-W, W, -W, -20.8, -W, 4.2)], False, None, fire_2),
    ("FireTruck", 3, [(6.0, W, 0.4, 9.6, 3.5, 10.5), (-W, -6.0, 0.4, 9.6, 3.5, 10.5)], False, None, fire_3),
    ("Semi", 1, [(-W, W, -W, -10.9, -W, 2.0)], True, None, semi_1),
    ("Semi", 2, [(-5.6, 5.6, -11.0, -1.7, 14.3, W)], True, None, semi_2),
    ("SemiTrailer", 3, [], False, None, semi_3),
    ("Bulldozer", 1, [(-W, W, -W, -11.4, -W, 7.4)], False, None, dozer_1),
    ("Bulldozer", 2, [(-3.2, 3.2, -6.0, -2.0, 11.9, W)], False, None, dozer_2),
    ("Bulldozer", 3, [(-3.2, 3.2, 11.4, W, -W, W), (-3.2, 3.2, 10.3, W, -W, 3.6)], False, None, dozer_3),
    ("Monster", 1, [(-4.2, 4.2, -2.6, 0.4, 12.2, W)], True, None, monster_1),
    ("Monster", 2, [(-W, W, -W, -11.6, 3.4, 6.6)], False, None, monster_2),
    ("Monster", 3, [], False, None, monster_3),
    ("Supercar", 1, [(-W, W, -W, -9.85, -W, 0.5)], False, None, super_1),
    ("Supercar", 2, [(-W, W, 9.3, W, 3.85, W)], False, None, super_2),
    ("Supercar", 3, [(-2.9, 2.9, 1.8, 7.6, 4.3, W)], True, None, super_3),
    ("Roadster", 1, [], False, None, road_1),
    ("Roadster", 2, [], False, None, road_2),
    ("Roadster", 3, [], False, None, road_3),
]

# wide-arch upgrades: the body sides round each wheel pushed out (zone = those sides)
for vid, n, push, reach, top, build in (
    ("Hatchback", 2, 0.6, 2.3, 3.3, hatch_2),
    ("Sedan", 3, 0.3, 2.3, 3.0, sedan_3),
    ("Muscle", 2, 0.65, 2.5, 3.2, muscle_2),
):
    ys = (wheel_y(vid, "FL1"), wheel_y(vid, "RL1"))
    UPGRADES.append((vid, n, arch_zone(ys, reach, top), True, flare(ys, push, reach, top), build))

for vid, n, zone, keep, deform, build in UPGRADES:
    rebuilt(vid, n, zone, keep, deform, build)
for vid, n, tris in UP_DONE:
    print(f"UPGRADE {vid:11s} {n} {tris:6d} tris  zone pieces: "
          f"{','.join(o.name for o in bpy.data.objects if o.name.startswith(f'{vid}_Z{n}'))}")


# ---- decal layout: every painted part (<Id>_Paint, <Id>_Z<n>_Paint, <Id>_U<n>_Paint) gets one fixed UV layout so
# a decal is one transparent image per vehicle (the paint colour shows where it is clear). The image is three
# bands, each spanning the vehicle's stock length from its front (u = 0) to its back (u = 1): the left side
# (v 2/3..1, bottom to top), the right side (v 1/3..2/3, same way round, so the art is drawn mirrored there) and
# the top (v 0..1/3, the vehicle's right edge at the bottom). Faces that look forward, back or down point at
# DECAL_BLANK, a corner pixel every decal leaves clear. tools/art/decals.py draws the images from these numbers.
DECAL_BLANK = (0.003, 0.003)


def decal_uvs(ob, vid):
    lo, hi = DECAL_BOX[vid]
    o = slot_of(vid)
    size = hi - lo
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    layer = me.uv_layers.new(name="Decal").data
    for poly in me.polygons:
        n = poly.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        if az >= ax and az >= ay and n.z > 0:
            band = "top"
        elif ax >= ay and ax >= az:
            band = "left" if n.x > 0 else "right"
        else:
            band = None
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co - o
            u = min(1.0, max(0.0, (p.y - lo.y) / size.y))
            if band == "top":
                v = min(1.0, max(0.0, (p.x - lo.x) / size.x)) / 3
            elif band == "left":
                v = 2 / 3 + min(1.0, max(0.0, (p.z - lo.z) / size.z)) / 3
            elif band == "right":
                v = 1 / 3 + min(1.0, max(0.0, (p.z - lo.z) / size.z)) / 3
            else:
                u, v = DECAL_BLANK
            # keep each band off its neighbours' edge pixels
            if band:
                base = {"top": 0, "right": 1 / 3, "left": 2 / 3}[band]
                v = base + 0.004 + (v - base) * (1 - 0.024)
                u = 0.004 + u * 0.992
            layer[li].uv = (u, v)


for ob in list(exported):
    vid = ob.name.split("_")[0]
    if ob.name.endswith("Paint") and vid in DECAL_BOX:
        decal_uvs(ob, vid)
boxes = {}
for vid in vehicles:
    lo, hi = DECAL_BOX[vid]
    boxes[vid] = [round(c, 3) for c in (*lo, *hi)]
    print(f"DECALBOX {vid} {lo.x:.3f} {lo.y:.3f} {lo.z:.3f} {hi.x:.3f} {hi.y:.3f} {hi.z:.3f}")
# tools/art/decals.py reads this to draw each vehicle's decals to its size
import json
with open(os.path.join(os.path.dirname(os.path.abspath(out)), "decal_boxes.json"), "w", encoding="utf-8") as f:
    json.dump(boxes, f, indent=1)
