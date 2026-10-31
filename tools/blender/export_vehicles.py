# Build every vehicle mesh for the game and export them in one FBX for Roblox.
# blender -b --factory-startup --python export_vehicles.py -- <pack_dir> <roadster.blend> <out.fbx> [preview.png]
#   <pack_dir>: the extracted "Low Poly City Vehicles Pack" (Pavel 3D, CC BY 4.0), holding BLEND/ and the palette png.
#   <roadster.blend>: the Roadster parts file (simplified here to the pack's flat palette style).
# Every vehicle is exported as <Id>_Body plus <Id>_Wheel_<FL|FR|RL|RR><n> meshes, all textured with the pack palette.
# Front is Blender -Y, left is Blender +X. Units: studs (Blender units = studs after STUDS scaling).
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
pack, roadster_path, out = args[0], args[1], args[2]
preview = args[3] if len(args) > 3 else None
palette_path = os.path.join(pack, "city_vehicles_pallete.png")

STUDS = 8.0  # studs per pack unit (pack is ~0.54x real; ~4.3 studs per real metre, as the Roadster test)
SPACING = 60.0  # vehicles sit side by side along X in the export

scene = bpy.context.scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

palette = bpy.data.images.load(palette_path)
PW, PH = palette.size
pix = list(palette.pixels)
CELLS = 32


def srgb(c):
    return c ** (1 / 2.2)


cells = []
for j in range(CELLS):
    for i in range(CELLS):
        x, y = int((i + 0.5) * PW / CELLS), int((j + 0.5) * PH / CELLS)
        k = (y * PW + x) * 4
        cells.append(((i + 0.5) / CELLS, (j + 0.5) / CELLS, pix[k], pix[k + 1], pix[k + 2]))


def uv_for(rgb):
    """UV of the palette cell nearest an sRGB 0-1 colour."""
    best, bd = None, 1e9
    for u, v, r, g, b in cells:
        d = (r - rgb[0]) ** 2 + (g - rgb[1]) ** 2 + (b - rgb[2]) ** 2
        if d < bd:
            best, bd = (u, v), d
    return best


mat = bpy.data.materials.new("Palette")
mat.use_nodes = True
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = palette
mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])


def paint(obj, rgb):
    """Point every face of obj at one palette colour."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new()
    uv = uv_for(rgb)
    layer = me.uv_layers.active.data
    for loop in me.loops:
        layer[loop.index].uv = uv


def finish(obj):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def bake(o):
    """Make the mesh data world-space and the object an identity transform with no parent."""
    o.data = o.data.copy()
    o.data.transform(o.matrix_world)
    o.parent = None
    o.matrix_world = Matrix.Identity(4)


def box(name, size, loc, rgb, bevel=0.0, yaw=0.0):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if yaw:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(yaw, 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    paint(o, rgb)
    return o


def cyl(name, radius, depth, loc, rgb, axis="X", verts=12):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius, depth=depth)
    rot = {"X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X"), "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    paint(o, rgb)
    return o


def wheel(name, radius, width, loc, tyre=(0.13, 0.13, 0.14), hub=(0.6, 0.6, 0.62)):
    t = cyl(name, radius, width, loc, tyre, "X", 14)
    h = cyl(name + "_hub", radius * 0.55, width * 1.06, loc, hub, "X", 10)
    return join([t, h], name)


def join(objs, name):
    ctx = {"active_object": objs[0], "selected_editable_objects": objs, "selected_objects": objs}
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


def load_pack(rel):
    path = os.path.join(pack, "BLEND", rel)
    with bpy.data.libraries.load(path) as (src, dst):
        dst.objects = list(src.objects)
    objs = [o for o in dst.objects if o and o.type == "MESH"]
    for o in objs:
        scene.collection.objects.link(o)
    bpy.context.view_layer.update()
    mats = [o.matrix_world.copy() for o in objs]
    for o, m in zip(objs, mats):
        o.data = o.data.copy()
        o.data.transform(m)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    body = [o for o in objs if not o.name.startswith("Wheel")]
    wheels = [o for o in objs if o.name.startswith("Wheel")]
    return join(body, "body") if len(body) > 1 else body[0], wheels


def bounds(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def scale_wheel(w, factor, push_out=0.0, lift=0.0):
    lo, hi = bounds([w])
    c = (lo + hi) / 2
    side = 1 if c.x > 0 else -1
    m = Matrix.Translation(c + Vector((side * push_out, 0, lift))) @ Matrix.Scale(factor, 4) @ Matrix.Translation(-c)
    w.data.transform(m)


exported = []
vehicles = []


def place(vid, body, wheels, scale):
    """Scale to studs, centre, name parts, move to this vehicle's slot."""
    objs = [body] + wheels
    for o in objs:
        o.data.transform(Matrix.Scale(scale, 4))
    lo, hi = bounds(objs)
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    slot = Vector((len(vehicles) * SPACING, 0, 0))
    vehicles.append(vid)
    for o in objs:
        o.data.transform(Matrix.Translation(shift + slot))
    body.name = vid + "_Body"
    count = {}
    for w in sorted(wheels, key=lambda w: (bounds([w])[0].y, bounds([w])[0].x)):
        wl, wh = bounds([w])
        c = (wl + wh) / 2 - slot
        corner = ("F" if c.y < 0 else "R") + ("L" if c.x > 0 else "R")
        count[corner] = count.get(corner, 0) + 1
        w.name = f"{vid}_Wheel_{corner}{count[corner]}"
        # pivot at the wheel centre so it spins in place
        w.data.transform(Matrix.Translation(-((wl + wh) / 2)))
        w.location = (wl + wh) / 2
    for o in objs:
        o.data.name = o.name
        finish(o)
    exported.extend(objs)
    bpy.context.view_layer.update()
    lo, hi = bounds(objs)
    size = hi - lo
    print(f"VEHICLE {vid:12s} size {size.x:6.2f} x {size.y:6.2f} x {size.z:6.2f} studs  wheels {len(wheels)}")
    return shift


def roblox_point(p, scale, shift):
    """A pack-unit point on a placed vehicle, in its Roblox model frame (studs, base centre, front -Z)."""
    b = p * scale + shift
    return (round(-b.x, 2), round(b.z, 2), round(b.y, 2))


def face_colour(me, poly):
    """The palette colour a face points at (sRGB 0-1, rounded)."""
    uv = me.uv_layers.active.data[poly.loop_start].uv
    x, y = min(PW - 1, int(uv.x * PW)), min(PH - 1, int(uv.y * PH))
    k = (y * PW + x) * 4
    return tuple(round(c, 2) for c in pix[k:k + 3])


def recolour(obj, test, rgb):
    """Point every face where test(centre, colour) holds at a new palette colour."""
    me = obj.data
    uv = uv_for(rgb)
    layer = me.uv_layers.active.data
    for p in me.polygons:
        if test(p.center, face_colour(me, p)):
            for li in p.loop_indices:
                layer[li].uv = uv


def drop_faces(obj, test):
    """Delete every face where test(centre, colour) holds."""
    me = obj.data
    gone = [p.index for p in me.polygons if test(p.center, face_colour(me, p))]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
    bm.to_mesh(me)
    bm.free()


def top_z(obj, x, y):
    """Height of obj's top surface over (x, y) in plan."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    hit = BVHTree.FromBMesh(bm).ray_cast(Vector((x, y, 50)), Vector((0, 0, -1)))
    bm.free()
    return hit[0].z if hit[0] else 0.0


def split_shells(obj, keep):
    """Copy obj keeping only the loose shells where keep(lo, hi) holds."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen, gone = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        shell, stack = [], [f]
        while stack:
            g = stack.pop()
            if g in seen:
                continue
            seen.add(g)
            shell.append(g)
            stack.extend(h for e in g.edges for h in e.link_faces if h not in seen)
        vs = {v for g in shell for v in g.verts}
        lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
        hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
        if not keep(lo, hi):
            gone.extend(shell)
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    me = bpy.data.meshes.new(obj.name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(obj.name, me)
    scene.collection.objects.link(o)
    return o


# ---- pack vehicles
PACK = [
    ("Hatchback", "Coupes/Veh_Coupe_02_Green.blend"),
    ("Sedan", "Sedans/Veh_Sedan_01_Blue.blend"),
    ("Taxi", "Special/Veh_Taxi.blend"),
    ("Muscle", "Muscle cars/Veh_Muscle_Car_02_Red.blend"),
    ("Supercar", "Sports cars/Veh_Sports_Car_03_Yellow.blend"),
    ("IceCream", "Special/Veh_IceCream_Van.blend"),
    ("FireTruck", "Emergency/Veh_Firetruck_01.blend"),
]
LAMP, GRILLE = (0.81, 0.92, 0.95), (0.14, 0.14, 0.12)
BRIGHT, BLACKP, GREYP = (0.95, 0.95, 0.9), (0.1, 0.1, 0.11), (0.32, 0.32, 0.32)


def near(c, ref):
    return max(abs(a - b) for a, b in zip(c, ref)) < 0.02


def restyle_muscle(body):
    """Our own nose: a light bar over a slatted grille, plus a hood scoop (the pack's twin round lamps and split
    grille read too much like one real 70s car)."""
    red = (0.76, 0.27, 0.19)
    recolour(body, lambda c, col: c.y < -1.3 and near(col, LAMP), red)
    recolour(body, lambda c, col: c.y < -1.3 and 0.28 < c.z < 0.5 and near(col, GRILLE), red)
    hood = top_z(body, 0, -0.85)
    parts = [
        box("nose", (0.9, 0.12, 0.17), (0, -1.4, 0.375), red),
        box("grille", (0.8, 0.03, 0.09), (0, -1.47, 0.355), BLACKP),
        box("slat", (0.76, 0.03, 0.014), (0, -1.48, 0.34), GREYP),
        box("slat", (0.76, 0.03, 0.014), (0, -1.48, 0.37), GREYP),
        box("lightBar", (0.88, 0.03, 0.025), (0, -1.475, 0.43), BRIGHT),
        box("scoop", (0.3, 0.42, 0.06), (0, -0.85, hood + 0.02), BLACKP, 0.02),
    ]
    return join([body] + parts, "body")


def restyle_supercar(body):
    """Our own nose and tail: slim angled light strips, a front splitter and a ducktail in place of the pack's
    flush lamps and tall wing (too close to one real 80s wedge supercar)."""
    yellow = (0.91, 0.64, 0.22)
    recolour(body, lambda c, col: c.y < -1.0 and near(col, LAMP), yellow)
    drop_faces(body, lambda c, col: c.y > 0.95 and c.z > 0.4 and near(col, (0.2, 0.2, 0.2)))
    tail = top_z(body, 0, 1.1)
    parts = [box("splitter", (1.06, 0.14, 0.03), (0, -1.33, 0.07), BLACKP)]
    for side in (1, -1):
        x = side * 0.34
        parts.append(box("lamp", (0.32, 0.05, 0.02), (x, -1.12, top_z(body, x, -1.12) + 0.002), BRIGHT, 0, side * 0.3))
    parts.append(box("duck", (1.04, 0.14, 0.05), (0, 1.12, tail + 0.03), yellow, 0.01))
    parts.append(box("gurney", (1.04, 0.03, 0.04), (0, 1.18, tail + 0.06), BLACKP))
    return join([body] + parts, "body")


RESTYLE = {"Muscle": restyle_muscle, "Supercar": restyle_supercar}
for vid, rel in PACK:
    body, wheels = load_pack(rel)
    if vid in RESTYLE:
        body = RESTYLE[vid](body)
    place(vid, body, wheels, STUDS)

# ---- semi: the pack's rigid tank truck cut into a tractor and a tank trailer that hitches over its drive axle
body, wheels = load_pack("Trucks/Veh_Truck_03_Tank_White.blend")
KINGPIN, BACK = -0.1, 0.5  # pack units along the truck: hitch on the tractor; how far the trailer moves back
FRAME = (0.2, 0.2, 0.2)


def is_rail(lo, hi):
    return lo.y < -1.2 and hi.y > 2 and hi.x - lo.x < 0.15


def is_tractor(lo, hi):
    return hi.y < -1.27 or (hi.y < -0.4 and hi.z < 0.62 and max(abs(lo.x), abs(hi.x)) > 0.6)


cab = split_shells(body, is_tractor)
tank = split_shells(body, lambda lo, hi: not is_tractor(lo, hi) and not is_rail(lo, hi))
bpy.data.objects.remove(body)
drive = [w for w in wheels if w.name.endswith("1") and w.name.startswith("Wheel_R")]
rear = [w for w in wheels if w.name.endswith("2")]
front = [w for w in wheels if w.name.startswith("Wheel_F")]
for w in drive:
    w.data.transform(Matrix.Translation((0, KINGPIN - (bounds([w])[0].y + bounds([w])[1].y) / 2, 0)))
tractor = [cab]
for side in (1, -1):
    tractor.append(box("rail", (0.09, 1.65, 0.13), (side * 0.2, -0.47, 0.585), FRAME))
    tractor.append(box("guard", (0.42, 0.78, 0.05), (side * 0.47, KINGPIN, 0.7), FRAME, 0.01))
tractor.append(box("fifthWheel", (0.6, 0.5, 0.06), (0, KINGPIN, 0.68), (0.15, 0.15, 0.16), 0.02))
tractor_body = join(tractor, "body")
shift = place("Semi", tractor_body, front + drive, STUDS)
print("HITCH Semi", roblox_point(Vector((0, KINGPIN, 0.71)), STUDS, shift))

extra = []
for w in rear:
    c = w.copy()
    c.data = w.data.copy()
    scene.collection.objects.link(c)
    c.data.transform(Matrix.Translation((0, -0.77, 0)))
    extra.append(c)
trailer_wheels = rear + extra
trailer = [tank]
for side in (1, -1):
    trailer.append(box("rail", (0.09, 2.45, 0.13), (side * 0.2, 1.5 - BACK, 0.585), FRAME))
    trailer.append(box("leg", (0.06, 0.06, 0.52), (side * 0.45, 0.45 - BACK, 0.45), FRAME))
    trailer.append(box("foot", (0.14, 0.14, 0.04), (side * 0.45, 0.45 - BACK, 0.19), FRAME))
trailer_body = join(trailer, "body")
for o in [trailer_body] + trailer_wheels:
    o.data.transform(Matrix.Translation((0, BACK, 0)))
shift = place("SemiTrailer", trailer_body, trailer_wheels, STUDS)
print("HITCH SemiTrailer", roblox_point(Vector((0, KINGPIN, 0.71)), STUDS, shift))

# ---- monster truck: the pickup on giant wheels with a lift kit
body, wheels = load_pack("Pickups/Veh_Pickup_02_Green.blend")
wl, wh = bounds(wheels)
r = (wh.z - wl.z) / 2
grow = 2.3
lift = r * (grow - 1)
for w in wheels:
    scale_wheel(w, grow, push_out=0.22, lift=lift)
body.data.transform(Matrix.Translation((0, 0, lift + 0.08)))
bl, bh = bounds([body])
axles = []
for y in (wl.y + r, wh.y - r):
    axles.append(box("axle", (bl.x * -2 + 0.5, 0.12, 0.12), (0, y, r * grow), (0.15, 0.15, 0.16)))
    axles.append(box("shock", (0.1, 0.1, lift + 0.2), (0.45, y, r * grow + lift / 2), (0.85, 0.3, 0.1)))
    axles.append(box("shock", (0.1, 0.1, lift + 0.2), (-0.45, y, r * grow + lift / 2), (0.85, 0.3, 0.1)))
axles.append(box("frame", (0.9, wh.y - wl.y - 2 * r, 0.14), (0, (wl.y + wh.y) / 2, r * grow + 0.05), (0.15, 0.15, 0.16)))
body = join([body] + axles, "body")
place("Monster", body, wheels, STUDS)

# ---- bulldozer (pack units, same density and flat style)
YEL, DARK, STEEL, GLASS = (0.86, 0.66, 0.16), (0.16, 0.16, 0.17), (0.45, 0.46, 0.48), (0.18, 0.26, 0.34)
parts = [
    box("trackL", (0.42, 2.5, 0.55), (0.72, 0.15, 0.3), DARK, 0.06),
    box("trackR", (0.42, 2.5, 0.55), (-0.72, 0.15, 0.3), DARK, 0.06),
    box("hull", (1.5, 2.1, 0.55), (0, 0.2, 0.82), YEL, 0.04),
    box("engine", (1.1, 0.9, 0.35), (0, -0.4, 1.25), YEL, 0.03),
    box("cab", (1.15, 1.0, 0.95), (0, 0.7, 1.58), YEL, 0.03),
    box("glassF", (1.0, 1.04, 0.5), (0, 0.7, 1.7), GLASS),
    box("glassS", (1.2, 0.8, 0.5), (0, 0.7, 1.7), GLASS),
    box("roof", (1.3, 1.15, 0.1), (0, 0.7, 2.1), YEL),
    cyl("exhaust", 0.06, 0.6, (0.38, -0.55, 1.6), DARK, "Z", 8),
    box("blade", (2.0, 0.16, 0.8), (0, -1.5, 0.48), YEL, 0.03),
    box("bladeEdge", (2.0, 0.2, 0.08), (0, -1.5, 0.06), STEEL),
    box("armL", (0.12, 0.8, 0.12), (0.62, -1.05, 0.55), DARK),
    box("armR", (0.12, 0.8, 0.12), (-0.62, -1.05, 0.55), DARK),
    box("ripper", (0.12, 0.5, 0.5), (0, 1.5, 0.45), DARK),
]
body = join(parts, "body")
wheels = [wheel("w", 0.26, 0.44, (s * 0.72, y, 0.28), DARK, STEEL) for s in (1, -1) for y in (-0.9, 1.2)]
place("Bulldozer", body, wheels, STUDS)

# ---- scooter
RED, CREAM, BLACK, CHROME = (0.78, 0.2, 0.18), (0.92, 0.88, 0.78), (0.1, 0.1, 0.11), (0.7, 0.71, 0.72)
parts = [
    box("deck", (0.26, 0.62, 0.08), (0, 0.02, 0.2), BLACK, 0.02),
    box("rearBody", (0.32, 0.42, 0.26), (0, 0.24, 0.36), RED, 0.05),
    box("seat", (0.24, 0.36, 0.08), (0, 0.24, 0.52), BLACK, 0.03),
    box("shield", (0.3, 0.08, 0.5), (0, -0.3, 0.5), RED, 0.03),
    box("column", (0.06, 0.06, 0.42), (0, -0.36, 0.72), CHROME),
    box("bars", (0.5, 0.05, 0.05), (0, -0.36, 0.94), BLACK),
    box("light", (0.12, 0.04, 0.08), (0, -0.39, 0.84), CREAM),
    box("fork", (0.04, 0.04, 0.32), (0, -0.42, 0.28), CHROME),
    box("guard", (0.14, 0.24, 0.04), (0, 0.4, 0.33), RED),
]
body = join(parts, "body")
wheels = [wheel("w", 0.14, 0.08, (0, -0.42, 0.14)), wheel("w", 0.14, 0.08, (0, 0.42, 0.14))]
place("Scooter", body, wheels, STUDS)

# ---- shopping cart (big enough to sit in)
parts = []
W, L, H, Z0 = 0.62, 0.95, 0.42, 0.32
for x in (-W / 2, W / 2):
    for y in (-L / 2, L / 2):
        parts.append(box("post", (0.03, 0.03, H), (x, y, Z0 + H / 2), CHROME))
for z in (Z0, Z0 + H / 2, Z0 + H):
    parts.append(box("railL", (0.03, L, 0.03), (W / 2, 0, z), CHROME))
    parts.append(box("railR", (0.03, L, 0.03), (-W / 2, 0, z), CHROME))
    parts.append(box("railF", (W, 0.03, 0.03), (0, -L / 2, z), CHROME))
    parts.append(box("railB", (W, 0.03, 0.03), (0, L / 2, z), CHROME))
for x in (-0.2, 0, 0.2):
    parts.append(box("barL", (0.02, L, 0.02), (x, 0, Z0), CHROME))
parts.append(box("floor", (W, L, 0.02), (0, 0, Z0 + 0.01), (0.55, 0.56, 0.58)))
parts.append(box("handle", (W + 0.04, 0.05, 0.05), (0, L / 2 + 0.12, Z0 + H + 0.08), RED))
parts.append(box("handleArmL", (0.03, 0.14, 0.12), (W / 2, L / 2 + 0.06, Z0 + H + 0.03), CHROME))
parts.append(box("handleArmR", (0.03, 0.14, 0.12), (-W / 2, L / 2 + 0.06, Z0 + H + 0.03), CHROME))
for x in (-W / 2 + 0.06, W / 2 - 0.06):
    for y in (-L / 2 + 0.06, L / 2 - 0.06):
        parts.append(box("leg", (0.03, 0.03, Z0 - 0.12), (x, y, (Z0 + 0.12) / 2), CHROME))
body = join(parts, "body")
wheels = [wheel("w", 0.07, 0.05, (x, y, 0.07), BLACK, CHROME) for x in (-W / 2 + 0.06, W / 2 - 0.06) for y in (-L / 2 + 0.06, L / 2 - 0.06)]
place("Cart", body, wheels, STUDS)

# ---- Roadster, simplified to the pack style
with bpy.data.libraries.load(roadster_path) as (src, dst):
    dst.objects = list(src.objects)
DROP = ("Brake", "Interior", "Seat", "Steering", "RearCamera", "Badge", "Marker", "ThirdBrake", "RearviewMirror",
        "FenderVent", "ReverseLight")
PAINT, RGLASS, RBLACK, TYRE, RIM = (0.8, 0.12, 0.1), (0.16, 0.22, 0.28), (0.1, 0.1, 0.11), (0.12, 0.12, 0.13), (0.62, 0.63, 0.66)
keep = []
for o in dst.objects:
    if not o or o.type != "MESH" or o.name.startswith(DROP):
        continue
    scene.collection.objects.link(o)
    keep.append(o)
bpy.context.view_layer.update()
body_parts, corners = [], {}
for o in keep:
    bake(o)
    n = len(o.data.polygons)
    target = 40 if o.name.startswith(("Tire", "Rim", "Taillight", "Headlight", "SideMirror", "RearSpoiler", "TrunkLid", "BodyTrim")) else 110
    m = o.modifiers.new("dec", "DECIMATE")
    m.ratio = min(1.0, target / max(n, 1))
    m.use_collapse_triangulate = True
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier="dec")
    names = " ".join(s.material.name.lower() for s in o.material_slots if s.material)
    if o.name.startswith("Tire"):
        col = TYRE
    elif o.name.startswith("Rim"):
        col = RIM
    elif o.name.startswith("Headlight"):
        col = (0.95, 0.95, 0.9)
    elif o.name.startswith("Taillight"):
        col = (0.75, 0.05, 0.05)
    elif "glass" in names and "paint" not in names:
        col = RGLASS
    elif "paint" in names:
        col = PAINT
    else:
        col = RBLACK
    paint(o, col)
    for p in o.data.polygons:
        p.use_smooth = False
    if o.name.startswith(("Tire", "Rim")):
        corners.setdefault(o.name.split("_")[-1], []).append(o)
    else:
        body_parts.append(o)
body = join(body_parts, "body")
wheels = [join(v, "w") for v in corners.values()]
for o in [body] + wheels:
    o.data.transform(Matrix.Scale(0.54, 4))  # real size to pack size
place("Roadster", body, wheels, STUDS)

# ---- export
tri = 0
for o in exported:
    o.data.calc_loop_triangles()
    tri += len(o.data.loop_triangles)
print("PARTS", len(exported), "TRIS", tri)
for o in bpy.data.objects:
    o.select_set(o in exported)
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                         add_leaf_bones=False, bake_anim=False, path_mode="STRIP")
print("EXPORTED", out)

if preview:
    for o in list(bpy.data.objects):
        if o not in exported:
            bpy.data.objects.remove(o)
    # preview only (after export): a 7-wide grid, turned to show the front three-quarter
    COLS, G = 7, 34.0
    for o in exported:
        i = vehicles.index(o.name.split("_")[0])
        o.location.x += (i % COLS) * G - i * SPACING
        o.location.y += (i // COLS) * G * 1.2
        o.rotation_euler.z = math.radians(-35)
        o.location = Matrix.Rotation(math.radians(-35), 4, "Z") @ (o.location - Vector(((i % COLS) * G, (i // COLS) * G * 1.2, 0))) + Vector(((i % COLS) * G, (i // COLS) * G * 1.2, 0))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cx, cy = (COLS - 1) * G / 2, G * 0.6
    cam.location = (cx, cy - 150, 150)
    cam.rotation_euler = (math.radians(45), 0, 0)
    cam.data.ortho_scale = COLS * G * 1.05
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 2800
    scene.render.resolution_y = 1100
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", preview)
