# Build every vehicle mesh for the game and export them in one FBX for Roblox.
# blender -b --factory-startup --python export_vehicles.py -- <pack_dir> <roadster.blend> <out.fbx> [preview.png] [wheels.png] [cabin_dir]
#   (pass "-" to skip a preview; cabin_dir gets one driver's-eye picture per vehicle)
#   <pack_dir>: the extracted "Low Poly City Vehicles Pack" (Pavel 3D, CC BY 4.0), holding BLEND/ and the palette png.
#   <roadster.blend>: the Roadster parts file (simplified here to the pack's flat palette style).
# Every vehicle is exported as <Id>_Body plus <Id>_Wheel_<FL|FR|RL|RR><n> meshes, all textured with the pack palette.
# Front is Blender -Y, left is Blender +X. Units: studs (Blender units = studs after STUDS scaling).
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
pack, roadster_path, out = args[0], args[1], args[2]
preview = args[3] if len(args) > 3 and args[3] != "-" else None
wheel_preview = args[4] if len(args) > 4 and args[4] != "-" else None
cabin_preview = args[5] if len(args) > 5 and args[5] != "-" else None
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


TYRE_RGB, TREAD_RGB = (0.12, 0.12, 0.13), (0.17, 0.17, 0.18)
SILVER, CHROME_RGB, GUN, STEEL_RGB = (0.72, 0.73, 0.75), (0.86, 0.87, 0.9), (0.24, 0.25, 0.27), (0.55, 0.56, 0.58)
WHITE_RGB, NUT = (0.93, 0.93, 0.92), (0.4, 0.4, 0.42)
# rim per vehicle: (look, rim colour, spoke count); vehicles not listed keep their own wheels
WHEEL_STYLE = {
    "Hatchback": ("spokes", SILVER, 6),
    "Sedan": ("spokes", SILVER, 5),
    "Taxi": ("hubcap", STEEL_RGB, 0),
    "Muscle": ("spokes", CHROME_RGB, 5),
    "Supercar": ("twin", SILVER, 5),
    "Roadster": ("aero", SILVER, 10),
    "IceCream": ("hubcap", WHITE_RGB, 0),
    "FireTruck": ("truck", WHITE_RGB, 8),
    "Semi": ("truck", SILVER, 10),
    "SemiTrailer": ("truck", SILVER, 10),
    "Monster": ("offroad", STEEL_RGB, 6),
}


def spun(name, size, centre, angle, offset, rgb):
    """A box at `offset` (y, z) from centre in the wheel's plane, turned `angle` around the axle (X)."""
    o = box(name, size, (0, offset[0], offset[1]), rgb)
    o.data.transform(Matrix.Rotation(angle, 4, "X"))
    o.data.transform(Matrix.Translation(centre))
    return o


def new_wheel(w, style):
    """Swap a wheel's mesh for a tyre with a block tread plus a rim in this vehicle's style, same size and place.
    The rim face goes on the outside (+X on the left side, -X on the right)."""
    look, rim_rgb, spokes = style
    lo, hi = bounds([w])
    c = (lo + hi) / 2
    r = (hi.z - lo.z) / 2
    width = hi.x - lo.x
    out = 1 if c.x > 0 else -1
    chunky = look == "offroad"
    lugs = 14 if chunky else 30
    depth = r * (0.12 if chunky else 0.025)
    # tyre: a cylinder with every other tread face pushed out into a block
    me = bpy.data.meshes.new("tyre")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=lugs * 2, radius1=r - depth, radius2=r - depth, depth=width * 0.94)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.pi / 2, 4, "Y"), verts=bm.verts)
    tread = [f for f in bm.faces if abs(f.normal.x) < 0.5]
    tread.sort(key=lambda f: math.atan2(f.calc_center_median().z, f.calc_center_median().y))
    blocks = tread[::2]
    res = bmesh.ops.extrude_discrete_faces(bm, faces=blocks)
    for f in res["faces"]:
        n = f.normal.copy()
        for v in f.verts:
            v.co += n * depth
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    tyre = bpy.data.objects.new("tyre", me)
    scene.collection.objects.link(tyre)
    paint(tyre, TYRE_RGB)
    parts = [tyre]
    face = c + Vector((out * width * 0.47, 0, 0))
    rim_r = r * (0.55 if chunky else 0.66)
    # dark well behind the rim, then the rim itself on the outside face
    parts.append(cyl("well", rim_r, r * 0.05, face - Vector((out * r * 0.025, 0, 0)), (0.07, 0.07, 0.08), "X", 20))
    if look == "hubcap":
        parts.append(cyl("cap", rim_r * 0.98, r * 0.1, face + Vector((out * r * 0.037, 0, 0)), rim_rgb, "X", 20))
        parts.append(cyl("capRing", rim_r * 0.6, r * 0.125, face + Vector((out * r * 0.05, 0, 0)), GUN, "X", 16))
        parts.append(cyl("capHub", rim_r * 0.25, r * 0.2, face + Vector((out * r * 0.075, 0, 0)), rim_rgb, "X", 10))
    else:
        parts.append(cyl("lip", rim_r, r * 0.1, face - Vector((out * r * 0.03, 0, 0)), rim_rgb, "X", 20))
        parts.append(cyl("barrel", rim_r * 0.86, r * 0.12, face, (0.07, 0.07, 0.08), "X", 20))
        thick = r * (0.1 if look in ("truck", "offroad") else 0.07)
        for i in range(spokes):
            a = i * 2 * math.pi / spokes
            if look == "twin":
                for d in (-0.09, 0.09):
                    parts.append(spun("spoke", (r * 0.1, thick * 0.7, rim_r * 0.82), face + Vector((out * r * 0.075, 0, 0)), a + d, (0, rim_r * 0.45), rim_rgb))
            elif look == "aero":
                parts.append(spun("vane", (r * 0.1, thick * 1.4, rim_r * 0.85), face + Vector((out * r * 0.075, 0, 0)), a + 0.25, (0, rim_r * 0.45), rim_rgb))
            elif look == "truck":
                parts.append(spun("nut", (r * 0.175, r * 0.06, r * 0.06), face + Vector((out * r * 0.125, 0, 0)), a, (0, rim_r * 0.42), NUT))
            else:
                parts.append(spun("spoke", (r * 0.1, thick, rim_r * 0.85), face + Vector((out * r * 0.075, 0, 0)), a, (0, rim_r * 0.45), rim_rgb))
        if look == "truck":
            parts.append(cyl("dish", rim_r * 0.82, r * 0.075, face + Vector((out * r * 0.062, 0, 0)), rim_rgb, "X", 20))
        if look == "offroad":
            for i in range(12):
                a = i * 2 * math.pi / 12
                parts.append(spun("bolt", (r * 0.15, r * 0.04, r * 0.04), face + Vector((out * r * 0.1, 0, 0)), a, (0, rim_r * 0.94), NUT))
        parts.append(cyl("hub", rim_r * 0.24, r * 0.25, face + Vector((out * r * 0.1, 0, 0)), GUN if rim_rgb != GUN else SILVER, "X", 10))
    new = join(parts, "w")
    w.data = new.data
    bpy.data.objects.remove(new)


exported = []
vehicles = []


def place(vid, body, wheels, scale):
    """Scale to studs, centre, name parts, move to this vehicle's slot."""
    if vid in WHEEL_STYLE:
        for w in wheels:
            new_wheel(w, WHEEL_STYLE[vid])
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

# ---- bulldozer (pack units, same density and flat style): a glass cab on a hull between two crawler tracks.
# Each track runs round a front idler and a rear drive sprocket of the same size (the Wheel_ parts) over five
# bottom rollers and two carriers; its link plates are one TrackShoe part the game copies round the loop.
YEL, DARK, STEEL = (0.86, 0.66, 0.16), (0.16, 0.16, 0.17), (0.45, 0.46, 0.48)
TX, TW = 0.72, 0.42  # track centre line and width
TR, TT = 0.25, 0.05  # idler / sprocket radius and the plates' thickness: the plates wrap round at TR + TT / 2
TY = (-0.95, 1.25)  # idler and sprocket along the vehicle (front is -Y)
TZ = TR + TT  # axle height: the plates' underside sits on the ground


def strut(name, a, b, radius, rgb, verts=8):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    o = cyl(name, radius, (b - a).length, (0, 0, 0), rgb, "Z", verts)
    q = (b - a).to_track_quat("Z", "Y")
    o.data.transform(Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())
    return o


parts = []
for s in (1, -1):
    parts += [
        box("rollerFrame", (0.3, TY[1] - TY[0] - 0.2, 0.2), (s * TX, sum(TY) / 2, TZ - 0.02), DARK),
        box("fender", (TW + 0.08, 1.7, 0.05), (s * TX, 0.3, 1.06), YEL, 0.01),
        box("armPush", (0.09, 1.5, 0.11), (s * 1.0, -0.76, 0.36), YEL, 0.02),
        box("trunnion", (0.12, 0.16, 0.16), (s * 0.97, 0.0, 0.36), DARK, 0.02),
        box("bladeSide", (0.06, 0.28, 0.72), (s * 1.0, -1.55, 0.42), YEL),
        strut("liftCyl", (s * 0.42, -0.98, 1.05), (s * 0.55, -1.32, 0.72), 0.045, YEL),
        strut("liftRod", (s * 0.55, -1.32, 0.72), (s * 0.6, -1.44, 0.6), 0.025, (0.85, 0.86, 0.88)),
        box("handrail", (0.03, 0.9, 0.03), (s * 0.5, -0.45, 1.6), DARK),
        box("light", (0.1, 0.06, 0.07), (s * 0.5, 0.22, 2.14), (0.95, 0.95, 0.9)),
        box("lightBack", (0.1, 0.06, 0.07), (s * 0.5, 1.18, 2.14), (0.95, 0.95, 0.9)),
        box("post", (0.07, 0.07, 0.98), (s * 0.56, 0.27, 1.58), YEL),
        box("post", (0.07, 0.07, 0.98), (s * 0.56, 1.13, 1.58), YEL),
        box("doorFrame", (0.04, 0.04, 0.9), (s * 0.57, 0.75, 1.58), YEL),
        box("cabLow", (0.04, 0.86, 0.2), (s * 0.565, 0.7, 1.19), YEL),
    ]
parts += [
    box("hull", (1.0, 2.25, 0.5), (0, 0.12, 0.78), YEL, 0.03),
    box("belly", (0.9, 1.9, 0.12), (0, 0.15, 0.48), DARK),
    box("deck", (1.2, 1.0, 0.06), (0, 0.7, 1.06), DARK),
    box("hood", (0.95, 1.12, 0.4), (0, -0.48, 1.25), YEL, 0.03),
    box("grille", (0.8, 0.04, 0.32), (0, -1.05, 1.22), DARK),
    box("vents", (0.96, 0.5, 0.04), (0, -0.4, 1.46), DARK),
    strut("stack", (0.3, -0.62, 1.4), (0.3, -0.62, 1.95), 0.05, DARK),
    box("rainCap", (0.13, 0.13, 0.03), (0.3, -0.62, 1.97), DARK),
    box("cabLowF", (1.1, 0.04, 0.22), (0, 0.27, 1.2), YEL),
    box("cabLowB", (1.1, 0.04, 0.22), (0, 1.13, 1.2), YEL),
    box("roof", (1.26, 1.04, 0.09), (0, 0.7, 2.1), YEL, 0.02),
    box("roofRim", (1.18, 0.96, 0.04), (0, 0.7, 2.04), DARK),
    box("blade", (2.0, 0.12, 0.62), (0, -1.53, 0.42), YEL, 0.02),
    box("bladeTop", (2.0, 0.1, 0.14), (0, -1.6, 0.78), YEL, 0.02),
    box("bladeEdge", (2.0, 0.16, 0.08), (0, -1.55, 0.04), STEEL),
    box("bladeBack", (1.6, 0.08, 0.44), (0, -1.45, 0.42), DARK),
    box("ripperFrame", (0.7, 0.4, 0.1), (0, 1.48, 0.62), DARK),
    box("ripper", (0.1, 0.12, 0.62), (0, 1.62, 0.36), DARK),
    box("ripperTip", (0.1, 0.14, 0.08), (0, 1.58, 0.07), STEEL),
    strut("ripperCyl", (0, 1.35, 0.95), (0, 1.55, 0.67), 0.04, YEL),
]
body = join(parts, "body")


def idler(x, y):
    p = [cyl("idler", TR, TW * 0.8, (x, y, TZ), STEEL, "X", 18), cyl("flange", TR * 0.9, TW * 0.86, (x, y, TZ), DARK, "X", 18),
         cyl("hub", TR * 0.35, TW * 0.9, (x, y, TZ), DARK, "X", 10)]
    return join(p, "w")


def sprocket(x, y):
    p = [cyl("disc", TR * 0.8, TW * 0.5, (x, y, TZ), DARK, "X", 18), cyl("hub", TR * 0.4, TW * 0.6, (x, y, TZ), STEEL, "X", 10)]
    # an even tooth count keeps the part's middle on the axle, so it spins in place
    for i in range(12):
        t = spun("tooth", (TW * 0.42, TR * 0.22, TR * 0.32), (x, y, TZ), i * 2 * math.pi / 12, (0, TR * 0.84), STEEL)
        p.append(t)
    for i in range(6):
        p.append(spun("bolt", (TW * 0.66, TR * 0.07, TR * 0.07), (x, y, TZ), i * math.pi / 3, (0, TR * 0.28), (0.3, 0.3, 0.32)))
    return join(p, "w")


wheels = [idler(s * TX, TY[0]) for s in (1, -1)] + [sprocket(s * TX, TY[1]) for s in (1, -1)]
BULL_SHIFT = place("Bulldozer", body, wheels, STUDS)

# ---- scooter
RED, CREAM, BLACK, CHROME = (0.78, 0.2, 0.18), (0.92, 0.88, 0.78), (0.1, 0.1, 0.11), (0.7, 0.71, 0.72)
# Front -Y. The front hub, the fork and the steering column share one raked axis (SCOOT_RAKE degrees from upright,
# through SCOOT_HUB), so the fork stays on the axle when the bars turn; the leg shield sits just behind it.
# Config/Vehicles' Scooter steerTilt must be 90 - SCOOT_RAKE (the weld leans the column by it).
SCOOT_HUB, SCOOT_RAKE, SCOOT_HEAD = Vector((0, -0.42, 0.14)), 10.0, 0.68  # head: pack height of the column top
parts = [
    box("floor", (0.26, 0.29, 0.05), (0, -0.09, 0.22), BLACK, 0.015),
    box("mat", (0.22, 0.25, 0.01), (0, -0.09, 0.248), (0.3, 0.3, 0.32)),
    box("frame", (0.16, 0.5, 0.07), (0, 0.0, 0.16), BLACK, 0.02),
    box("shield", (0.3, 0.05, 0.39), (0, -0.26, 0.445), RED, 0.02),
    box("tunnel", (0.27, 0.08, 0.26), (0, 0.08, 0.365), RED, 0.03),
    box("rearBody", (0.34, 0.46, 0.21), (0, 0.29, 0.395), RED, 0.06),
    box("seat", (0.25, 0.46, 0.07), (0, 0.2, 0.525), BLACK, 0.03),
    box("tailLamp", (0.12, 0.02, 0.05), (0, 0.522, 0.43), (0.75, 0.05, 0.05)),
    cyl("exhaust", 0.025, 0.2, (-0.13, 0.38, 0.17), CHROME, "Y", 8),
]
body = join(parts, "body")
# the handlebars, column, lamp, fork and front mudguard are the Steer part (built with the cabins), so they turn
# together about the raked axis
wheels = [wheel("w", 0.14, 0.08, tuple(SCOOT_HUB)), wheel("w", 0.14, 0.08, (0, 0.42, 0.14))]
SCOOT_SHIFT = place("Scooter", body, wheels, STUDS)

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
CART_SHIFT = place("Cart", body, wheels, STUDS)

# ---- Roadster, simplified to the pack style
with bpy.data.libraries.load(roadster_path) as (src, dst):
    dst.objects = list(src.objects)
DROP = ("Brake", "Interior", "Seat", "Steering", "RearCamera", "Badge", "Marker", "ThirdBrake", "RearviewMirror",
        "ReverseLight")
PAINT, RGLASS, RBLACK, TYRE, RIM = (0.8, 0.12, 0.1), (0.16, 0.22, 0.28), (0.1, 0.1, 0.11), (0.12, 0.12, 0.13), (0.62, 0.63, 0.66)
keep = []
for o in dst.objects:
    # match anywhere in the name: "FrontBadge" and "RearBadge" must go too (no maker's badge on our car)
    if not o or o.type != "MESH" or any(k in o.name for k in DROP):
        continue
    scene.collection.objects.link(o)
    keep.append(o)
bpy.context.view_layer.update()
body_parts, corners = [], {}
for o in keep:
    bake(o)
    n = len(o.data.polygons)
    # big panels keep enough faces that their edges still meet their neighbours' (fewer opens cracks)
    target = 40 if o.name.startswith(("Tire", "Rim", "Taillight", "Headlight", "SideMirror", "RearSpoiler", "TrunkLid", "BodyTrim")) else 220
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

# ---- cabins: see-through glass and a cabin to sit in on every vehicle, detailed enough for a first-person view.
# Each cabin is one <Id>_Interior mesh (seats, dash, gauges, door cards, headliner, floor, pedals...) plus the parts
# the game moves or treats apart: <Id>_Steer (turns with the front wheels; an optional <Id>_SteerPivot marker is
# the point it turns about), <Id>_NeedleSpeed / <Id>_NeedleRev (the client swings them about their middles),
# <Id>_Mirror (shiny faces). Everything here is built in a vehicle's Roblox frame: studs from the model's base
# centre, front -Z, +X to the driver's right; the Roblox point (x, y, z) is Blender (-x, z, y) in its slot.
# Seat spots come from the game's Config/Vehicles; the driver sits on the left.
import re

config = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "shared", "Config", "Vehicles.luau"), encoding="utf-8").read()
SEATS = {m.group(1): tuple(float(v) for v in m.group(2).split(",")) for m in re.finditer(r'id = "(\w+)",.*?seat = \{([^}]*)\}', config, re.S)}
# the steering wheel's lean towards the driver (VehicleBuilder's default unless the row sets steerTilt)
TILTS = {m.group(1): float(m.group(2)) for m in re.finditer(r'id = "(\w+)",(?:(?!id = ").)*?steerTilt = ([\d.]+)', config, re.S)}
STEER_TILT = 22  # Config/Cockpit steerTilt
GAUGE_TILT = 15  # every analogue dial leans back this much; VehicleBuilder turns the needles' welds to match
PANE = (0.14, 0.14, 0.12)  # the pack paints its windows this near-black
SEAT_AT = {}
STEER_PIVOT = {}  # a Steer part's SteerPivot marker, where it has one (the preview leans it about that)
GLASS_FROM = {"FireTruck": 0.28}  # window faces above this share of the height become glass (default 0.4)
ROBLOX = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox (x, y, z) -> Blender (-x, z, y)
UP, DOWN, LEFT, RIGHT, AHEAD, BACK = (0, 1, 0), (0, -1, 0), (-1, 0, 0), (1, 0, 0), (0, 0, -1), (0, 0, 1)

C = {
    "black": (0.12, 0.12, 0.13), "char": (0.2, 0.21, 0.22), "dark": (0.27, 0.27, 0.28), "grey": (0.42, 0.42, 0.43),
    "mid": (0.55, 0.56, 0.58), "light": (0.72, 0.72, 0.73), "pale": (0.85, 0.85, 0.84), "white": (0.95, 0.95, 0.94),
    "chrome": (0.8, 0.8, 0.82), "cream": (0.8, 0.71, 0.58), "tan": (0.64, 0.49, 0.39), "brown": (0.42, 0.25, 0.17),
    "red": (0.59, 0.2, 0.15), "lamp": (0.8, 0.06, 0.07), "orange": (0.91, 0.64, 0.22), "yellow": (0.86, 0.66, 0.16),
    "green": (0.36, 0.55, 0.32), "blue": (0.22, 0.44, 0.69), "screen": (0.13, 0.23, 0.35), "glow": (0.4, 0.6, 0.82),
    "go": (0.44, 0.68, 0.37), "amber": (0.92, 0.64, 0.21), "pink": (0.86, 0.45, 0.58), "mint": (0.45, 0.74, 0.66),
}


def rot(rx=0.0, ry=0.0, rz=0.0):
    """CFrame.Angles in degrees: +rx tips a part's top towards the tail, +ry turns its front to the left."""
    return (Matrix.Rotation(math.radians(rx), 4, "X") @ Matrix.Rotation(math.radians(ry), 4, "Y")
            @ Matrix.Rotation(math.radians(rz), 4, "Z"))


class Kit:
    """One mesh built from painted boxes, cylinders and rings placed in a vehicle's Roblox frame. `frame` is an
    extra Roblox-space transform for everything added (used to bake a part 'untilted' so a weld can tilt it)."""

    def __init__(self, vid, frame=None):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new()
        self.done = self.bm.faces.layers.int.new("done")
        self.base = Matrix.Translation((vehicles.index(vid) * SPACING, 0, 0)) @ ROBLOX
        self.frame = frame or Matrix.Identity(4)

    def _paint(self, rgb):
        uv = uv_for(rgb)
        for f in self.bm.faces:
            if not f[self.done]:
                f[self.done] = 1
                for loop in f.loops:
                    loop[self.uv].uv = uv

    def _m(self, at, r):
        return self.base @ self.frame @ Matrix.Translation(Vector(at)) @ (r or Matrix.Identity(4))

    def box(self, size, at, rgb, bevel=0.0, r=None):
        m = self._m(at, r) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        if bevel > 0:
            edges = list({e for v in res["verts"] for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=min(bevel, min(size) * 0.45), segments=1, affect="EDGES")
        self._paint(rgb)

    def cyl(self, radius, depth, at, rgb, r=None, verts=12, top=None):
        """A cylinder (or cone, with top) along the part's Z: facing the driver unless r turns it."""
        bmesh.ops.create_cone(self.bm, cap_ends=True, segments=verts, radius1=radius,
                              radius2=radius if top is None else top, depth=depth, matrix=self._m(at, r))
        self._paint(rgb)

    def ring(self, radius, thick, at, rgb, r=None, seg=20, side=6, a0=0.0, a1=360.0):
        """A torus round the part's Z (a steering wheel rim facing the driver); a0..a1 degrees for an arc."""
        m = self._m(at, r)
        full = abs(a1 - a0) >= 360
        n = seg if full else seg + 1
        rows = []
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * i / seg)
            c, s = math.cos(a), math.sin(a)
            row = []
            for j in range(side):
                b = 2 * math.pi * j / side
                rr = radius + thick * math.cos(b)
                row.append(self.bm.verts.new(m @ Vector((rr * c, rr * s, thick * math.sin(b)))))
            rows.append(row)
        for i in range(seg if full else seg):
            ra, rb_ = rows[i], rows[(i + 1) % n]
            for j in range(side):
                self.bm.faces.new((ra[j], rb_[j], rb_[(j + 1) % side], ra[(j + 1) % side]))
        if not full:
            self.bm.faces.new(rows[0][::-1])
            self.bm.faces.new(rows[-1])
        self._paint(rgb)

    def make(self, name):
        me = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        self.bm.to_mesh(me)
        self.bm.free()
        o = bpy.data.objects.new(name, me)
        scene.collection.objects.link(o)
        finish(o)
        exported.append(o)
        return o


def cell_colour(rgb):
    """The palette colour paint(obj, rgb) actually lands on."""
    u, v = uv_for(rgb)
    x, y = min(PW - 1, int(u * PW)), min(PH - 1, int(v * PH))
    k = (y * PW + x) * 4
    return tuple(round(c, 2) for c in pix[k:k + 3])


def in_slot(vid, rx, ry, rz):
    return Vector((vehicles.index(vid) * SPACING - rx, rz, ry))


def split_off(obj, test, name):
    """Move the faces where test(centre, colour) holds into a new object called name."""
    me = obj.data
    picked = {p.index for p in me.polygons if test(p.center, face_colour(me, p))}
    if not picked:
        return None
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    keep = bm.copy()
    keep.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in range(len(bm.faces)) if i not in picked], context="FACES")
    bmesh.ops.delete(keep, geom=[keep.faces[i] for i in picked], context="FACES")
    glass = bpy.data.meshes.new(name)
    bm.to_mesh(glass)
    keep.to_mesh(me)
    bm.free()
    keep.free()
    o = bpy.data.objects.new(name, glass)
    scene.collection.objects.link(o)
    finish(o)
    return o


class Fit:
    """Where the inside of a vehicle's shell is, found by casting rays from around the seat: door faces, roof,
    window line and windscreen. Distances are studs in the Roblox frame."""

    def __init__(self, vid, seat, glass):
        self.vid = vid
        self.trees = [("body", tree_of(bpy.data.objects[vid + "_Body"]))]
        if glass:
            self.trees.append(("glass", tree_of(glass)))
        self.base = Matrix.Translation((vehicles.index(vid) * SPACING, 0, 0)) @ ROBLOX
        self.seat = Vector(seat)
        self.eye = self.seat + Vector((0, EYE_UP, -EYE_FWD))

    def hit(self, at, d, far=60.0):
        """(distance, "body" | "glass") to the nearest face from a Roblox point along a Roblox direction."""
        o = self.base @ Vector(at)
        dv = (ROBLOX.to_3x3() @ Vector(d)).normalized()
        best = (far, None)
        for kind, t in self.trees:
            h = t.ray_cast(o, dv, far)
            if h[0] is not None and h[3] < best[0]:
                best = (h[3], kind)
        return best

    def dist(self, at, d, far=60.0):
        return self.hit(at, d, far)[0]

    def side(self, x, y, z, d):
        """The inner face of the shell beside (x, y, z), looking along d (LEFT or RIGHT): its x."""
        return x + d[0] * self.dist((x, y, z), d)

    def inner(self, x, z, d, heights):
        """The innermost of the shell's inner faces beside (x, z) over several heights: a panel standing there
        stays inside a body whose sides curve in (the Roadster's doors)."""
        faces = [self.side(x, y, z, d) for y in heights]
        return max(faces) if d[0] < 0 else min(faces)

    def roof(self, x, z, y0):
        """The underside of the roof above (x, z); an open top (the Roadster's middle) counts as a low roof line."""
        dd, kind = self.hit((x, y0, z), UP, 8)
        return (y0 + dd, kind) if kind else (y0 + 1.6, None)

    def belt(self, x, z, d):
        """The window line beside (x, z): the lowest height where looking sideways meets glass."""
        y = self.seat.y + 0.6
        while y < self.eye.y + 0.8:
            if self.hit((x, y, z), d)[1] == "glass":
                return y
            y += 0.1
        return self.seat.y + 2.3

    def window(self, x, z, d):
        """The bottom of the side window beside (x, z), scanning up from the seat; None if there's no glass."""
        y = self.seat.y
        while y < self.seat.y + 14:
            if self.hit((x, y, z), d)[1] == "glass":
                return y
            y += 0.1
        return None

    def screen(self, x, y):
        """The windscreen's z ahead of (x, y) from the seat (4.5 ahead if nothing is there)."""
        dd, kind = self.hit((x, y, self.seat.z), AHEAD, 20)
        return self.seat.z - (dd if kind else 4.5)


def tree_of(o):
    """A ray-cast tree of an object's faces (objects here have identity transforms)."""
    me = o.data
    return BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])

# what each cabin is made of: seat and insert colours, door cards, dash, the steering wheel, the cluster and the
# centre stack, then extras that suit the vehicle
CABIN = {
    "Hatchback": dict(seat="dark", insert="green", door="dark", dash="char", trim="grey", wheel="round", cluster="twin",
                      stack="radio", shift="manual", rear=True, extras=("bobble",)),
    "Sedan": dict(seat="tan", insert="cream", door="tan", dash="char", trim="chrome", wheel="round", cluster="twin",
                  stack="screen", shift="auto", rear=True, extras=()),
    "Taxi": dict(seat="black", insert="dark", door="dark", dash="char", trim="yellow", wheel="round", cluster="twin",
                 stack="radio", shift="auto", rear=True, extras=("meter", "freshener", "handset")),
    "Muscle": dict(seat="black", insert="red", door="black", dash="black", trim="chrome", wheel="wood", cluster="row3",
                   stack="radio", shift="pistol", rear=False, extras=("dice", "undergauges")),
    "Supercar": dict(seat="black", insert="orange", door="black", dash="black", trim="orange", wheel="sport",
                     cluster="digital", stack="toggles", shift="paddles", rear=False, extras=("carbon",)),
    "Roadster": dict(seat="white", insert="pale", door="char", dash="black", trim="char", wheel="yoke",
                     cluster="small", stack="bigscreen", shift="none", rear=False, extras=()),
    "IceCream": dict(seat="mint", insert="pale", door="pale", dash="grey", trim="pink", wheel="truck", cluster="twin",
                     stack="radio", shift="auto", rear=False, extras=("cone", "freezer", "jingle")),
    "FireTruck": dict(seat="black", insert="char", door="dark", dash="char", trim="red", wheel="truck",
                      cluster="row4", stack="radio", shift="auto", rear=False, extras=("siren", "helmets", "maps")),
    "Semi": dict(seat="brown", insert="tan", door="brown", dash="char", trim="chrome", wheel="truck", cluster="row5",
                 stack="radio", shift="truck", rear=False, extras=("cb", "curtain", "horncord")),
    "Monster": dict(seat="black", insert="orange", door="black", dash="black", trim="orange", wheel="sport",
                    cluster="bigtwin", stack="switches", shift="pistol", rear=False, extras=("cage", "harness",
                                                                                        "extinguisher")),
}


def wheel_kit(vid, centre, radius, kind, trim):
    """The steering wheel, built untilted facing the driver (+Z) about its middle; the weld leans it back."""
    k = Kit(vid, Matrix.Translation(Vector(centre)))
    rim, spoke, hub = C["black"], C["char"], C["char"]
    if kind == "wood":
        rim, spoke, hub = C["brown"], C["chrome"], C["chrome"]
    if kind == "yoke":
        r = radius
        for sx in (-1, 1):
            k.ring(r * 0.55, r * 0.13, (sx * r * 0.45, 0, 0), rim, rot(0, 0, 0), 10, 6, -60 if sx > 0 else 120,
                   60 if sx > 0 else 240)
        k.box((r * 1.5, r * 0.22, r * 0.2), (0, -r * 0.45, 0), rim, r * 0.06)
        k.box((r * 0.8, r * 0.42, r * 0.2), (0, -r * 0.05, 0.02), hub, r * 0.08)
        k.box((r * 1.6, r * 0.14, r * 0.16), (0, 0.0, -0.02), spoke, 0.02)
        return k.make(vid + "_Steer")
    thick = {"sport": 0.14, "truck": 0.08, "wood": 0.1}.get(kind, 0.11)
    k.ring(radius, radius * thick, (0, 0, 0), rim, None, 24, 6)
    if kind == "sport":
        # a coloured band at twelve o'clock and grips stitched on at quarter to three
        k.ring(radius, radius * thick * 1.08, (0, 0, 0), C[trim], None, 2, 6, 84, 96)
        for a in (0, 180):
            k.ring(radius, radius * thick * 1.06, (0, 0, 0), C["dark"], None, 5, 6, a - 25, a + 25)
    k.cyl(radius * 0.3, radius * 0.18, (0, 0, 0.02), hub, None, 14)
    k.box((radius * 0.5, radius * 0.36, radius * 0.1), (0, 0, radius * 0.12), C["black"] if kind != "wood" else C["chrome"], radius * 0.05)
    n = {"truck": 4, "round": 3, "sport": 3, "wood": 3}[kind]
    for i in range(n):
        a = (0, 180, -90)[i] if n == 3 else 45 + 90 * i
        w = radius * (0.24 if kind == "round" else 0.16)
        k.box((radius * 0.72, w, radius * 0.08), (0, 0, 0), spoke, 0.0, rot(0, 0, a) @ Matrix.Translation((radius * 0.6, 0, 0)))
    if kind == "sport":
        # shift paddles behind the spokes
        for sx in (-1, 1):
            k.box((radius * 0.36, radius * 0.5, radius * 0.05), (sx * radius * 0.82, radius * 0.1, -radius * 0.2), C["chrome"], 0.02)
    return k.make(vid + "_Steer")


def needle_kit(vid, name, centre, radius, face):
    """A needle about its own middle (a tail in the dial's colour balances it), untilted and pointing up; the game
    leans its weld back by GAUGE_TILT and swings it about its Z."""
    k = Kit(vid, Matrix.Translation(Vector(centre)))
    k.box((radius * 0.07, radius * 0.85, 0.02), (0, radius * 0.42, 0), C["lamp"])
    k.box((radius * 0.07, radius * 0.85, 0.02), (0, -radius * 0.42, 0), face)
    k.cyl(radius * 0.12, 0.05, (0, 0, 0), C["black"], None, 10)
    return k.make(vid + "_" + name)


def dial(k, at, radius, face, bezel, ticks=9):
    """An analogue dial leaned back GAUGE_TILT: bezel, face and tick marks from 7 o'clock round to 5."""
    r = rot(-GAUGE_TILT)
    k.ring(radius, radius * 0.1, at, bezel, r, 20, 4)
    k.cyl(radius, 0.04, at, face, r, 20)
    mark = C["white"] if face in (C["black"], C["char"]) else C["black"]
    for i in range(ticks):
        a = 135 - 270 * i / (ticks - 1)
        long = i % 2 == 0
        k.box((radius * 0.06, radius * (0.24 if long else 0.14), 0.02), at, mark, 0,
              r @ rot(0, 0, a) @ Matrix.Translation((0, radius * (0.74 if long else 0.79), 0.03)))
    # the red zone at the top end
    k.box((radius * 0.08, radius * 0.2, 0.02), at, C["lamp"], 0, r @ rot(0, 0, -120) @ Matrix.Translation((0, radius * 0.78, 0.03)))


def bucket(k, x, y, z, sp, harness=False, floor=None):
    """A bucket seat: cushion with a front roll and side bolsters, a leaned back with an insert panel, a
    headrest on posts, rails underneath. y is the cushion top, z the cushion's middle."""
    s, ins = C[sp["seat"]], C[sp["insert"]]
    w = 1.9
    k.box((w * 0.66, 0.4, 1.8), (x, y - 0.2, z), s, 0.08)
    k.box((w * 0.6, 0.06, 1.5), (x, y + 0.01, z + 0.05), ins, 0)
    k.box((w * 0.7, 0.42, 0.4), (x, y - 0.12, z - 0.86), s, 0.12)
    for side in (-1, 1):
        k.box((0.3, 0.55, 1.8), (x + side * (w / 2 - 0.15), y - 0.05, z), s, 0.1)
    lean = rot(14)
    back = Vector((x, y + 1.25, z + 1.05))
    k.box((w * 0.7, 2.4, 0.42), back, s, 0.1, lean)
    k.box((w * 0.5, 1.9, 0.05), back + Vector((0, -0.05, -0.23)), ins, 0, lean)
    for side in (-1, 1):
        k.box((0.32, 2.2, 0.6), back + Vector((side * (w / 2 - 0.16), -0.05, -0.12)), s, 0.12, lean)
    head = back + Vector((0, 1.65, 0.35))
    k.box((w * 0.5, 0.7, 0.36), head, s, 0.12, lean)
    for side in (-1, 1):
        k.cyl(0.04, 0.4, head + Vector((side * 0.25, -0.5, 0.05)), C["chrome"], rot(90 - 14), 6)
    for side in (-1, 1):
        k.box((0.12, 0.12, 1.9), (x + side * 0.55, y - 0.48, z + 0.1), C["black"])
    if floor is not None and y - 0.54 > floor + 0.02:
        # a pedestal down to the floor, so a seat in a tall cab doesn't hover
        k.box((1.3, y - 0.48 - floor, 1.4), (x, (y - 0.48 + floor) / 2, z + 0.1), C["black"], 0.04)
    k.box((0.3, 0.06, 0.12), (x - w / 2 - 0.02, y - 0.25, z - 0.4), C["black"], 0.02)
    if harness:
        for side in (-1, 1):
            k.box((0.28, 2.3, 0.04), back + Vector((side * 0.32, -0.1, -0.24)), C[sp["trim"]], 0, lean)
        # lap belt across the cushion and its buckle
        k.box((1.2, 0.04, 0.26), (x, y + 0.03, z - 0.2), C[sp["trim"]])
        k.cyl(0.16, 0.05, (x, y + 0.07, z - 0.2), C["chrome"], rot(90), 12)


def bench(k, xl, xr, y, z, sp, floor):
    s, ins = C[sp["seat"]], C[sp["insert"]]
    w = xr - xl - 0.4
    k.box((w, y - 0.4 - floor, 1.6), ((xl + xr) / 2, (y - 0.4 + floor) / 2, z), C["black"])
    k.box((w, 0.45, 1.8), ((xl + xr) / 2, y - 0.2, z), s, 0.1)
    k.box((w, 2.3, 0.45), ((xl + xr) / 2, y + 1.2, z + 1.05), s, 0.1, rot(12))
    for x in (xl + w * 0.25 + 0.2, xr - w * 0.25 - 0.2):
        k.box((w * 0.36, 1.8, 0.05), (x, y + 1.15, z + 0.8), ins, 0, rot(12))
        k.box((0.95, 0.6, 0.32), (x, y + 2.7, z + 1.4), s, 0.1, rot(12))


def car_cabin(vid, f, glass, sp):
    k, mirror = Kit(vid), Kit(vid)
    sx, sy, sz = f.seat
    ey = f.eye.y
    trim, dash, door = C[sp["trim"]], C[sp["dash"]], C[sp["door"]]
    elbow = sy + 1.3
    xl = f.side(sx, elbow, sz, LEFT) + 0.12
    xr = f.side(-sx, elbow, sz, RIGHT) - 0.12
    belt = min(f.belt(sx, sz, LEFT), ey - 0.4)
    top = min(max(belt - 0.3, sy + 2.25), sy + 2.85)  # dash top, a little under the window line
    zws = f.screen(sx, top + 0.05) + 0.05
    zd = sz - 2.55  # the dash's face towards the driver
    zfire = sz - 4.0
    floor = max(sy - f.dist((sx, sy, sz), DOWN) + 0.05, sy - 1.1)
    zrear = sz + f.dist((sx, sy + 1.5, sz), BACK, 12)  # the cab's back wall (or the rear window)
    roof, _ = f.roof(0, sz, ey)
    w = xr - xl

    def span(zs, ys, pad=0.15):
        """How far a full-width piece can reach either side at these depths and heights and stay inside."""
        lo = max(f.side(sx, y, z, LEFT) for z in zs for y in ys) + pad
        hi = min(f.side(-sx, y, z, RIGHT) for z in zs for y in ys) - pad
        return lo, hi

    def wide(sides, h, d, y, z, rgb, bevel=0.0, r=None):
        k.box((sides[1] - sides[0], h, d), ((sides[0] + sides[1]) / 2, y, z), rgb, bevel, r)

    print(f"FIT {vid} doors {xl:.2f}..{xr:.2f} belt {belt:.2f} dash {top:.2f} screen {zws:.2f} floor {floor:.2f} roof {roof:.2f} eye {ey:.2f}")

    # dash: a top slab out to the windscreen, a face towards the driver, a knee roll, the firewall below
    # it stops short of the windscreen, whose sides sweep down lower than its middle (the Roadster's corners
    # poked through the glass)
    zdash = zws + 0.45
    depth = max(zd - zdash, 0.6)
    ds = span((zdash + 0.2, zdash + depth / 2, zd), (top - 0.85, top - 0.05))
    wide(ds, 0.9, depth, top - 0.45, zdash + depth / 2, dash, 0.12)
    wide((ds[0] + 0.05, ds[1] - 0.05), 0.12, depth * 0.6, top + 0.03, zdash + depth * 0.3, C["black"] if dash != C["black"] else C["char"])
    wide(ds, 0.12, 0.14, top - 0.1, zd + 0.02, trim, 0.03)
    wide(span((zd - 0.15,), (top - 1.75, top - 0.85)), 1.0, 0.5, top - 1.3, zd - 0.15, dash, 0.15, rot(-18))
    wide(span((zfire,), (floor + 0.2, (floor + top) / 2, top - 0.1)), top - floor, 0.3, (top + floor) / 2, zfire, C["black"])
    # a brow over the cluster in front of the driver
    k.box((2.2, 0.14, 0.6), (sx, top + 0.04, zd + 0.1), dash, 0.06)
    k.box((1.95, 0.85, 0.1), (sx, top - 0.4, zd + 0.02), C["black"], 0.03, rot(-GAUGE_TILT))
    cy, cz = top - 0.4, zd + 0.09
    face = C["black"]
    needles = []
    cl = sp["cluster"]
    if cl in ("twin", "bigtwin", "small"):
        r = {"twin": 0.36, "bigtwin": 0.42, "small": 0.3}[cl]
        for i, name in ((-1, "NeedleSpeed"), (1, "NeedleRev")):
            at = (sx + i * r * 1.2, cy, cz)
            dial(k, at, r, face, trim)
            needles.append((name, at, r))
        if cl == "twin":
            for i in (-1, 1):
                dial(k, (sx + i * 0.98, cy - 0.12, cz + 0.02), 0.16, face, C["char"], 5)
    elif cl.startswith("row"):
        n = int(cl[3:])
        gap = 0.62 if n < 5 else 0.55
        for i in range(n):
            gx = sx + (i - (n - 1) / 2) * gap
            dial(k, (gx, cy, cz), 0.25, C["white"] if sp["wheel"] == "wood" else face, trim, 7)
        needles.append(("NeedleSpeed", (sx - gap / 2 if n % 2 == 0 else sx, cy, cz), 0.25))
        if n > 2:
            needles.append(("NeedleRev", (sx + gap / 2 if n % 2 == 0 else sx + gap, cy, cz), 0.25))
        needles = [(nm, (a[0], a[1], a[2]), r) for nm, a, r in needles]
    elif cl == "digital":
        k.box((1.7, 0.7, 0.05), (sx, cy, cz + 0.02), C["screen"], 0, rot(-GAUGE_TILT))
        k.ring(0.28, 0.025, (sx, cy, cz + 0.05), C["orange"], rot(-GAUGE_TILT), 20, 4, -45, 225)
        for i in range(8):
            k.box((0.1, 0.06, 0.02), (sx - 0.68 + i * 0.07, cy + 0.2, cz + 0.06), C["go"] if i < 5 else C["lamp"], 0, rot(-GAUGE_TILT))
        k.box((0.32, 0.4, 0.02), (sx - 0.62, cy - 0.05, cz + 0.06), C["glow"], 0, rot(-GAUGE_TILT))
        k.box((0.32, 0.4, 0.02), (sx + 0.62, cy - 0.05, cz + 0.06), C["glow"], 0, rot(-GAUGE_TILT))
        needles.append(("NeedleSpeed", (sx, cy, cz + 0.05), 0.24))
    for name, at, r in needles:
        # the needle sits just proud of the dial, along its leaned-back face
        n = Vector(at) + (rot(-GAUGE_TILT).to_3x3() @ Vector((0, 0, 0.06)))
        needle_kit(vid, name, n, r, face if cl != "row3" else C["white"])

    # the steering column and its stalks; the wheel itself is the Steer part
    tilt = TILTS.get(vid, STEER_TILT)
    radius = {"truck": 1.0, "yoke": 0.8}.get(sp["wheel"], 0.75)
    wc = Vector((sx, sy + 1.95, sz - 1.45))
    col = Vector((0, -math.sin(math.radians(tilt)), -math.cos(math.radians(tilt))))
    length = max(0.6, (wc.z - zd + 0.4) / math.cos(math.radians(tilt)))
    k.box((0.42, 0.42, length), wc + col * (0.25 + length / 2), C["black"], 0.1, rot(-tilt))
    for side in (-1, 1):
        k.box((0.5, 0.06, 0.06), wc + col * 0.4 + Vector((side * 0.42, 0.05, 0)), C["char"], 0.02, rot(-tilt) @ rot(0, 0, side * -8))
    wheel_kit(vid, wc, radius, sp["wheel"], sp["trim"])

    # centre stack: vents, radio or screen, climate knobs and a hazard button
    stack_z = zd - 0.1
    k.box((1.4, top - floor - 0.2, 0.5), (0, (top + floor) / 2 - 0.15, stack_z - 0.1), dash, 0.08)
    for vx in (-0.35, 0.35):
        k.box((0.55, 0.3, 0.06), (vx, top - 0.35, stack_z + 0.17), C["black"], 0.02)
        for i in range(3):
            k.box((0.5, 0.03, 0.04), (vx, top - 0.44 + i * 0.09, stack_z + 0.21), C["grey"], 0)
    for vx in (xl + 0.45, xr - 0.45):
        k.cyl(0.18, 0.06, (vx, top - 0.35, zd + 0.05), C["black"], None, 12)
        k.cyl(0.08, 0.08, (vx, top - 0.35, zd + 0.07), C["grey"], None, 8)
    st = sp["stack"]
    sy0 = top - 0.95
    if st in ("radio", "switches", "toggles"):
        k.box((1.1, 0.42, 0.06), (0, sy0, stack_z + 0.17), C["black"], 0.02)
        k.box((0.6, 0.12, 0.02), (0, sy0 + 0.07, stack_z + 0.21), C["amber"] if st == "radio" else C["go"])
        for kx in (-0.42, 0.42):
            k.cyl(0.08, 0.08, (kx, sy0, stack_z + 0.22), C["chrome"], None, 8)
    if st == "screen":
        k.box((1.1, 0.62, 0.06), (0, sy0 + 0.1, stack_z + 0.17), C["black"], 0.03)
        k.box((0.98, 0.5, 0.02), (0, sy0 + 0.1, stack_z + 0.21), C["screen"])
        k.box((0.4, 0.2, 0.02), (-0.2, sy0 + 0.18, stack_z + 0.22), C["glow"])
    if st == "bigscreen":
        # a landscape screen standing up out of the dash middle
        k.box((1.8, 1.0, 0.08), (0, top - 0.1, zd + 0.15), C["black"], 0.04, rot(-12))
        k.box((1.68, 0.88, 0.03), (0, top - 0.1, zd + 0.2), C["screen"], 0, rot(-12))
        k.box((0.8, 0.42, 0.02), (0.38, top - 0.02, zd + 0.22), C["glow"], 0, rot(-12))
        k.box((0.5, 0.12, 0.02), (-0.5, top - 0.38, zd + 0.27), C["go"], 0, rot(-12))
    if st in ("switches", "toggles"):
        for i in range(5):
            tx = -0.48 + i * 0.24
            k.box((0.14, 0.14, 0.04), (tx, sy0 - 0.38, stack_z + 0.18), C["black"])
            k.cyl(0.025, 0.16, (tx, sy0 - 0.36, stack_z + 0.24), C["chrome"], rot(-30), 6)
            k.box((0.1, 0.05, 0.02), (tx, sy0 - 0.23, stack_z + 0.21), C["lamp"] if i == 0 else C["amber"])
    for i, kx in enumerate((-0.4, 0, 0.4)):
        k.cyl(0.11, 0.1, (kx, sy0 - 0.62, stack_z + 0.2), C["char"], None, 12)
        k.cyl(0.03, 0.02, (kx, sy0 - 0.56, stack_z + 0.26), C["lamp"] if i == 0 else C["blue"] if i == 2 else C["white"], None, 6)
    k.box((0.16, 0.1, 0.03), (0, sy0 + 0.33, stack_z + 0.2), C["lamp"])
    # glovebox on the passenger side
    k.box((1.6, 0.55, 0.05), (-sx * 0.95, top - 0.75, zd - 0.12), dash, 0.04)
    k.box((0.36, 0.06, 0.05), (-sx * 0.95, top - 0.55, zd - 0.08), C["chrome"])

    # console between the seats: shifter, cup holders, handbrake, armrest
    con_top = sy + 0.55
    k.box((1.05, con_top - floor, sz + 1.0 - (zd - 0.2)), (0, (con_top + floor) / 2, (sz + 1.0 + zd - 0.2) / 2), dash, 0.08)
    k.box((1.1, 0.25, 1.2), (0, con_top + 0.12, sz + 0.5), C[sp["seat"]], 0.1)
    for cz in (sz - 1.15, sz - 0.75):
        k.cyl(0.16, 0.03, (-0.22, con_top + 0.01, cz), C["black"], rot(90), 10)
    sh = sp["shift"]
    gx, gz = 0.12, sz - 1.7
    if sh == "manual":
        k.cyl(0.18, 0.2, (gx, con_top + 0.05, gz), C["black"], rot(90), 8, 0.08)
        k.cyl(0.035, 0.7, (gx, con_top + 0.4, gz), C["chrome"], rot(90), 6)
        k.cyl(0.13, 0.22, (gx, con_top + 0.78, gz), C["black"], rot(90), 10, 0.1)
    elif sh == "auto":
        k.box((0.45, 0.05, 0.8), (gx, con_top + 0.02, gz), C["black"], 0.02)
        for i in range(4):
            k.box((0.06, 0.02, 0.06), (gx + 0.17, con_top + 0.05, gz - 0.25 + i * 0.16), C["white"] if i else C["lamp"])
        k.cyl(0.04, 0.5, (gx, con_top + 0.27, gz), C["chrome"], rot(90), 6)
        k.box((0.18, 0.3, 0.26), (gx, con_top + 0.6, gz), C["black"], 0.06)
    elif sh == "pistol":
        k.cyl(0.04, 1.0, (gx, con_top + 0.5, gz), C["chrome"], rot(80), 6)
        k.box((0.14, 0.4, 0.24), (gx, con_top + 1.0, gz - 0.06), C[sp["trim"]] if sp["trim"] != "chrome" else C["brown"], 0.05, rot(-10))
    elif sh == "truck":
        k.cyl(0.04, 1.6, (-0.3 if sx < 0 else 0.3, con_top + 0.75, sz - 1.4), C["chrome"], rot(80), 6)
        k.cyl(0.14, 0.3, (-0.3 if sx < 0 else 0.3, con_top + 1.55, sz - 1.55), C["black"], rot(90), 10)
    if sh != "pistol" and sh != "truck":
        k.box((0.12, 0.14, 0.9), (0.38, con_top + 0.12, sz - 0.4), C["black"], 0.04, rot(-12))

    # pedals and a footrest
    pedals = (-0.45, 0.0, 0.45) if sh in ("manual", "pistol") else (-0.15, 0.35)
    for px in pedals:
        k.box((0.32 if px != 0.35 else 0.22, 0.55, 0.06), (sx + px, floor + 0.7, zfire + 0.55), C["dark"], 0.02, rot(60))
        k.box((0.06, 0.06, 1.0), (sx + px, floor + 1.0, zfire + 0.3), C["black"], 0, rot(30))
    k.box((0.4, 0.06, 0.7), (sx - 0.95, floor + 0.35, zfire + 0.5), C["dark"], 0, rot(50))

    # door cards fitted along the doors, with armrest, handle, pull and speaker
    z0, z1 = zws + 0.6, sz + 1.6
    steps = max(2, int((z1 - z0) / 0.8))
    for side, x0, d in ((-1, sx, LEFT), (1, -sx, RIGHT)):
        for i in range(steps):
            za, zb = z0 + (z1 - z0) * i / steps, z0 + (z1 - z0) * (i + 1) / steps
            zc = (za + zb) / 2
            # stop just under the window line, so the top cap can't show through the seam above it
            bl = min(f.belt(x0, zc, d), ey - 0.3) - 0.15
            xd = f.inner(x0, zc, d, (floor + 0.3, elbow, bl - 0.1)) - side * 0.15
            k.box((0.14, bl - floor, zb - za + 0.04), (xd, (bl + floor) / 2, zc), door, 0)
            k.box((0.24, 0.16, zb - za + 0.04), (xd - side * 0.05, bl - 0.04, zc), trim if sp["trim"] in ("chrome", "grey") else C["black"], 0.03)
        xd = f.inner(x0, sz - 0.4, d, (floor + 0.3, elbow)) - side * 0.15
        k.box((0.4, 0.2, 1.7), (xd - side * 0.22, sy + 1.25, sz - 0.4), C[sp["seat"]], 0.07)
        k.box((0.1, 0.14, 0.5), (xd - side * 0.08, sy + 1.6, sz - 1.6), C["chrome"], 0.03)
        k.cyl(0.32, 0.06, (xd - side * 0.08, floor + 0.75, sz - 1.9), C["black"], rot(0, 90), 12)
        k.cyl(0.25, 0.07, (xd - side * 0.08, floor + 0.75, sz - 1.9), C["grey"], rot(0, 90), 12)
        if side < 0:
            for i in range(2):
                k.box((0.14, 0.04, 0.16), (xd - side * 0.4, sy + 1.37, sz - 0.9 + i * 0.22), C["black"], 0.02)

    # headliner strips under the roof wherever it is solid, kept dark and inside the shell (pale strips showed
    # through the glass and poked out of the thin roof's curved edges), sun visors and a dome light
    zr0 = f.screen(0, ey + 0.4)
    zr = zr0
    half = w / 2 - 0.35
    strips = []  # (z, underside) of each strip
    while zr < min(zrear - 0.3, sz + 2.8):
        z = zr + 0.25
        # as wide as the solid roof above reaches (glass or the roof's curved edge ends it), pressed up under it;
        # probing just off the middle, as some roofs (the Roadster's) are two halves with a seam down the centre
        reach_, ys = 0.0, []
        x = 0.25
        while x <= half:
            pair = [f.roof(sx_, z_, ey) for sx_ in (-x, x) for z_ in (z - 0.27, z + 0.27)]
            if not all(kind == "body" and h - ey < 4 for h, kind in pair):
                break
            ys += [h for h, _ in pair]
            reach_ = x
            x += 0.5
        if reach_ >= 0.25:
            y = min(ys)
            k.box((2 * reach_, 0.1, 0.55), (0, y - 0.07, z), C["char"], 0)
            strips.append((z, y - 0.12))
        zr += 0.5

    def liner(z):
        """The headliner's underside nearest z, or None where there is none (glass or open roof)."""
        near_ = [st for st in strips if abs(st[0] - z) < 0.4]
        return min(near_, key=lambda st: abs(st[0] - z))[1] if near_ else None

    ry = liner(zr0 + 0.75) or ey + 1.0
    if sp["wheel"] not in ("sport", "yoke") and liner(zr0 + 0.65):
        for vx in (sx, -sx):
            k.box((1.2, 0.08, 0.45), (vx, liner(zr0 + 0.65) - 0.05, zr0 + 0.65), C["dark"], 0.03, rot(-6))
    if liner(sz):
        k.box((0.45, 0.06, 0.25), (0, liner(sz) - 0.03, sz), C["grey"], 0.02)
    mz = f.screen(0.25, ry - 0.5) + 0.35
    hang = liner(mz)
    if hang:
        # the rear-view mirror hangs from the headliner; an open top (the Roadster's middle) has none
        ry = hang
        k.box((0.08, 0.35, 0.08), (0, ry - 0.17, mz), C["black"])
        k.box((1.3, 0.4, 0.16), (0, ry - 0.52, mz + 0.05), C["black"], 0.05)
        mirror.box((1.18, 0.3, 0.02), (0, ry - 0.52, mz + 0.14), C["pale"])

    # floor: carpet, a mat on each side and the tunnel
    zback = min(sz + (4.6 if sp["rear"] else 2.0), zrear)
    if "freezer" in sp["extras"]:
        zback = sz + 6.0  # the van's floor runs back under the freezer
    # as wide as the shell at floor level, which can be narrower than at the elbows
    fl = f.inner(sx, sz, LEFT, (floor + 0.3,)) + 0.1
    fr = f.inner(-sx, sz, RIGHT, (floor + 0.3,)) - 0.1
    k.box((fr - fl, 0.1, zback - zfire), ((fl + fr) / 2, floor, (zback + zfire) / 2), C["black"], 0)
    for vx in (sx, -sx):
        k.box((1.5, 0.04, 1.9), (vx, floor + 0.07, zfire + 1.3), C["char"], 0.02)
    wall = (xl, xr)
    if sp["rear"] and f.dist((sx, sy + 1, sz + 1.6), BACK) > 3.5:
        bl_, br_ = span((sz + 2.6, sz + 4.4), (sy, sy + 1.3, sy + 2.6))
        bench(k, bl_ - 0.2, br_ + 0.2, sy, sz + 3.3, sp, floor)
    else:
        # a parcel shelf / back wall behind the seats
        zw = min(sz + 2.2, zrear - 0.15)
        wall = span((zw,), (floor + 0.2, (floor + top) / 2, top))
        wide(wall, top - floor, 0.2, (top + floor) / 2, zw, C["black"])

    bucket(k, sx, sy + 0.175, sz, sp, "harness" in sp["extras"], floor)
    bucket(k, -sx, sy + 0.175, sz, sp, "harness" in sp["extras"], floor)
    cabin_extras(k, vid, f, sp, dict(xl=xl, xr=xr, top=top, zd=zd, zws=zws, floor=floor, roof=roof, ry=ry, mz=mz, w=w, belt=belt,
                                     zrear=zrear, liner=liner, wall=wall, span=span))
    k.make(vid + "_Interior")
    mirror.make(vid + "_Mirror")


def cabin_extras(k, vid, f, sp, g):
    sx, sy, sz = f.seat
    top, zd, zws = g["top"], g["zd"], g["zws"]
    ex = sp["extras"]
    if "meter" in ex:
        # taxi meter on the dash top by the passenger
        k.box((0.9, 0.42, 0.55), (-sx * 0.55, top + 0.21, zd - 0.6), C["black"], 0.05)
        k.box((0.7, 0.16, 0.02), (-sx * 0.55, top + 0.26, zd - 0.32), C["lamp"])
    hy = g["ry"] - 0.95  # just under the mirror housing
    if ("freshener" in ex or "dice" in ex) and g["liner"](g["mz"]):
        k.cyl(0.015, 0.45, (0, hy + 0.2, g["mz"] + 0.05), C["white"], rot(90), 4)
    if "freshener" in ex and g["liner"](g["mz"]):
        for i, s in enumerate((0.36, 0.28, 0.2)):
            k.box((s, 0.16, 0.03), (0, hy - 0.4 - i * 0.12, g["mz"] + 0.05), C["green"], 0.01)
    if "dice" in ex and g["liner"](g["mz"]):
        for dx in (-0.14, 0.14):
            k.box((0.22, 0.22, 0.22), (dx, hy - 0.42, g["mz"] + 0.05), C["white"] if dx < 0 else C["lamp"], 0.05, rot(20, 30 if dx < 0 else -20))
    if "bobble" in ex:
        k.cyl(0.12, 0.25, (-sx * 0.6, top + 0.13, zd - 0.5), C["black"], rot(90), 10)
        k.cyl(0.025, 0.25, (-sx * 0.6, top + 0.35, zd - 0.5), C["grey"], rot(90), 4)
        k.box((0.32, 0.32, 0.32), (-sx * 0.6, top + 0.62, zd - 0.5), C["yellow"], 0.12)
    if "handset" in ex:
        k.box((0.4, 0.55, 0.25), (-sx * 0.1 + 0.55, top - 1.25, zd - 0.1), C["black"], 0.05)
        k.box((0.18, 0.5, 0.16), (0.55, top - 1.2, zd + 0.1), C["char"], 0.05)
    if "undergauges" in ex:
        for i in range(3):
            dial(k, (-0.35 + i * 0.35, top - 1.55, zd + 0.05), 0.14, C["white"], C["chrome"], 5)
    if "carbon" in ex:
        k.box((g["w"] - 0.2, 0.06, 0.4), (0, top - 0.98, zd + 0.0), C["char"], 0)
    if "cone" in ex:
        k.cyl(0.18, 0.5, (-sx * 0.55, top + 0.25, zd - 0.6), C["tan"], rot(-90), 10, 0.02)
        k.box((0.36, 0.3, 0.36), (-sx * 0.55, top + 0.6, zd - 0.6), C["pink"], 0.14)
        k.box((0.3, 0.25, 0.3), (-sx * 0.55, top + 0.82, zd - 0.6), C["white"], 0.12)
    if "jingle" in ex:
        k.cyl(0.2, 0.15, (0.2, top - 1.0, zd + 0.1), C["lamp"], None, 14)
    if "freezer" in ex:
        # the back of the van: a freezer counter with tubs and a rack of cones
        zf = sz + 3.0
        k.box((g["w"] - 0.3, 2.6, 2.4), (0, g["floor"] + 1.3, zf + 1.3), C["white"], 0.08)
        for i in range(4):
            k.box((0.7, 0.1, 0.7), (-1.2 + i * 0.8, g["floor"] + 2.62, zf + 1.3), (C["pink"], C["cream"], C["brown"], C["mint"])[i], 0.05)
        k.box((2.2, 0.3, 0.45), (0, g["floor"] + 2.75, zf + 0.35), C["pink"], 0.04)
        for i in range(5):
            k.cyl(0.11, 0.45, (-0.8 + i * 0.4, g["floor"] + 3.05, zf + 0.35), C["tan"], rot(-90), 8, 0.02)
    if "siren" in ex:
        k.box((1.6, 0.6, 0.45), (0, top + 0.25, zd - 0.9), C["black"], 0.05)
        for i in range(6):
            k.box((0.16, 0.16, 0.04), (-0.6 + i * 0.24, top + 0.32, zd - 0.66), C["lamp"] if i < 3 else C["amber"], 0.02)
            k.cyl(0.025, 0.14, (-0.6 + i * 0.24, top + 0.14, zd - 0.6), C["chrome"], rot(-30), 6)
    if "helmets" in ex:
        # on pegs on the back wall, behind the seats
        zw = min(sz + 2.2, g["zrear"] - 0.15)
        for i, x in enumerate((g["wall"][0] + 0.8, g["wall"][1] - 0.8)):
            hz, hy_ = zw - 0.72, top - 0.45
            k.box((0.1, 0.1, 0.62), (x, hy_ + 0.2, zw - 0.36), C["chrome"])
            k.cyl(0.45, 0.6, (x, hy_ + 0.3, hz), C["yellow"] if i else C["black"], rot(90), 12, 0.38)
            k.cyl(0.62, 0.06, (x, hy_, hz), C["yellow"] if i else C["black"], rot(90), 14)
    if "maps" in ex:
        k.box((0.9, 0.12, 0.7), (-sx * 0.7, top + 0.06, zd - 1.0), C["blue"], 0.02, rot(0, 15))
    if "cb" in ex:
        k.box((1.6, 0.4, 0.8), (0, g["roof"] - 0.3, sz - 1.2), C["char"], 0.06)
        k.box((0.9, 0.18, 0.02), (0, g["roof"] - 0.35, sz - 0.79), C["amber"])
        k.cyl(0.08, 0.06, (0.6, g["roof"] - 0.35, sz - 0.78), C["chrome"], None, 8)
    if "curtain" in ex:
        # pleats across the sleeper opening, as wide as the cab is where they hang
        zc = min(sz + 2.4, g["zrear"] - 0.2)
        lo_, hi_ = g["span"]((zc,), (sy, (sy + g["roof"]) / 2, g["roof"] - 0.5))
        pw = (hi_ - lo_) / 9
        for i in range(9):
            x = lo_ + pw * (i + 0.5)
            k.box((pw + 0.04, g["roof"] - sy - 0.5, 0.1), (x, (g["roof"] - 0.4 + sy) / 2, zc + (0.08 if i % 2 else 0)), C["brown"], 0)
    if "horncord" in ex:
        k.cyl(0.02, 1.4, (g["xl"] + 1.2, g["roof"] - 0.7, sz - 0.8), C["white"], rot(90), 4)
        k.box((0.12, 0.22, 0.12), (g["xl"] + 1.2, g["roof"] - 1.45, sz - 0.8), C["black"], 0.04)
    if "cage" in ex:
        # a hoop just inside the back wall, bars forward under the roof, all inside the cab
        zh = g["zrear"] - 0.55
        cy_ = g["liner"](zh) or g["roof"] - 0.3
        hw = g["w"] / 2 - 0.9  # clear of side glass that leans in at the top
        for side in (-1, 1):
            x = side * hw
            k.cyl(0.11, cy_ - g["floor"], (x, (cy_ + g["floor"]) / 2, zh), C[sp["trim"]], rot(90), 8)
            k.cyl(0.11, 3.4, (x, cy_ - 0.12, zh - 1.7), C[sp["trim"]], None, 8)
        k.cyl(0.11, 2 * hw, (0, cy_ - 0.12, zh), C[sp["trim"]], rot(0, 90), 8)
    if "net" in ex:
        xw = g["xl"] - 0.02
        for i in range(5):
            k.box((0.03, 0.03, 2.4), (xw, g["belt"] + 0.15 + i * 0.25, sz - 0.6), C["black"])
        for i in range(8):
            k.box((0.03, 1.1, 0.03), (xw, g["belt"] + 0.65, sz - 1.7 + i * 0.32), C["black"])
    if "extinguisher" in ex:
        k.cyl(0.2, 0.9, (0, g["floor"] + 0.55, sz + 0.0 - 1.2), C["lamp"], rot(90), 10)


def add_interior(vid):
    body = bpy.data.objects[vid + "_Body"]
    lo, hi = bounds([body])
    height = hi.z - lo.z
    pane = cell_colour(RGLASS) if vid == "Roadster" else PANE
    cut = GLASS_FROM.get(vid, 0.4)
    glass = split_off(body, lambda c, col: near(col, pane) and c.z - lo.z > height * cut, vid + "_Glass")
    # the cabin is as wide as the windows (the whole vehicle can be far wider: mirrors, giant wheels)
    width = hi.x - lo.x
    if glass:
        exported.append(glass)
        glo, ghi = bounds([glass])
        width = min(width, ghi.x - glo.x)
    _, sy, sz = SEATS[vid]
    sx = -round(width * 0.2, 1)  # left of centre
    if glass and vid not in LOW_CABS:
        # sit high enough to be seen through the side windows (tall cabs)
        sy = max(sy, round(glo.z - lo.z - 2.3, 1))
    f = Fit(vid, (sx, sy, sz), glass)
    sill = f.window(sx, sz, LEFT)
    if sill and f.eye.y < sill and vid not in LOW_CABS:
        # a tall cab: sit up so the eye clears the side window's bottom edge
        sy = round(sy + sill + EYE_SILL - f.eye.y, 1)
        f = Fit(vid, (sx, sy, sz), glass)
    gap = sz - f.screen(sx, f.eye.y)
    if gap > SCREEN_GAP + 0.5:
        sz = round(sz - (gap - SCREEN_GAP), 1)
        f = Fit(vid, (sx, sy, sz), glass)
    back = f.dist((sx, sy + 1.5, sz), BACK, 12)
    if back < SEAT_ROOM:
        # a short cab (the monster truck): move up so the seat back and headrest stay inside
        sz = round(sz - (SEAT_ROOM - back), 1)
        f = Fit(vid, (sx, sy, sz), glass)
    print(f"SEAT {vid} {{ {sx}, {sy}, {sz} }}")
    SEAT_AT[vid] = (sx, sy, sz)
    EYES[vid] = (sx, min(f.eye.y, f.roof(sx, f.eye.z, sy + 1)[0] - EYE_ROOM), f.eye.z)
    car_cabin(vid, f, glass, CABIN[vid])


# the driver's eye for the cabin pictures: above and a little ahead of the seat spot (a seated R15 avatar)
EYE_UP, EYE_FWD, EYE_FOV, EYE_PITCH, EYE_GLASS = 3.2, 0.1, 65, 8, 0.75
EYE_ROOM = 0.45  # the eye stays this far under the roof
EYE_SILL = 1.2  # in a tall cab the eye sits this far above the side window's bottom edge
# low sports cars: the driver sits down on the floor, below the side windows, so a tall avatar's head and hair
# stay under the roof (their seat heights in Config/Vehicles win over the two sit-up rules above)
LOW_CABS = ("Supercar", "Roadster")
DOZER_LIFT = 2.0  # the bulldozer's seat rides this far above its cab floor's usual height (roomy cab)
SEAT_ROOM = 2.3  # studs from the seat spot to the cab's back wall that the seat back needs
SCREEN_GAP = 4.6  # a driver sitting further than this behind the windscreen (vans, trucks) moves up to it
INTERIOR = tuple(CABIN)
EYES = {}
for vid in INTERIOR:
    add_interior(vid)
def mark(vid, name, at):
    """A tiny marker part: the game reads its position (a pivot or a hand grip) and removes it."""
    k = Kit(vid)
    k.box((0.1, 0.1, 0.1), at, C["lamp"])
    return k.make(vid + "_" + name)


def bulldozer_cab():
    """A glass operator's cab: suspension seat between two armrest consoles with joysticks (StickL drives,
    StickR works the blade), a low dash with two dials, pedals; plus the track rollers and one link plate."""
    vid = "Bulldozer"
    R = lambda x, y, z: Vector(roblox_point(Vector((x, y, z)), STUDS, BULL_SHIFT))
    k, gl, mirror = Kit(vid), Kit(vid), Kit(vid)
    a, b = R(0.56, 0.27, 1.09), R(-0.56, 1.13, 2.06)
    x0, x1, z0, z1 = min(a.x, b.x), max(a.x, b.x), min(a.z, b.z), max(a.z, b.z)
    floor, roof = a.y, b.y
    sill = R(0, 0, 1.31).y
    sx, sy, sz = 0.0, round(floor + 1.7 + DOZER_LIFT, 1), round((z0 + z1) / 2 + 0.9, 1)
    SEAT_AT[vid] = (sx, sy, sz)
    EYES[vid] = (sx, sy + EYE_UP, sz - EYE_FWD)
    print(f"SEAT {vid} {{ {sx}, {sy}, {sz} }}")
    # glass all round between the posts
    for z in (z0 + 0.05, z1 - 0.05):
        gl.box((x1 - x0 - 0.5, roof - sill + 0.3, 0.06), (0, (roof + sill - 0.3) / 2, z), PANE)
    for x in (x0 + 0.05, x1 - 0.05):
        gl.box((0.06, roof - sill + 0.3, z1 - z0 - 0.5), (x, (roof + sill - 0.3) / 2, (z0 + z1) / 2), PANE)
    gl.make(vid + "_Glass")
    sp = dict(seat="black", insert="char", trim="yellow")
    k.box((x1 - x0, 0.1, z1 - z0), (0, floor + 0.05, (z0 + z1) / 2), C["dark"])
    k.box((x1 - x0 - 1.0, 0.04, 3.0), (0, floor + 0.12, z0 + 2.0), C["black"], 0.02)
    k.box((x1 - x0 - 0.3, 0.08, z1 - z0 - 0.3), (0, roof - 0.06, (z0 + z1) / 2), C["light"])
    k.box((1.2, sy - floor - 0.4, 1.2), (0, (sy + floor) / 2 - 0.2, sz), C["black"], 0.1)
    bucket(k, sx, sy + 0.175, sz, sp)
    for side in (-1, 1):
        cx = side * 1.25
        k.box((0.75, 0.6, 2.2), (cx, sy + 0.5, sz - 0.4), C["char"], 0.08)
        k.box((0.75, 0.15, 1.1), (cx, sy + 0.86, sz + 0.2), C["black"], 0.05)
        k.cyl(0.2, 0.12, (cx, sy + 0.85, sz - 0.95), C["black"], rot(90), 10)
        stick = Kit(vid)
        base = Vector((cx, sy + 0.9, sz - 0.95))
        stick.cyl(0.05, 0.85, base + Vector((0, 0.42, 0)), C["chrome"], rot(90), 6)
        stick.box((0.24, 0.42, 0.28), base + Vector((0, 1.0, 0)), C["black"], 0.08)
        stick.box((0.08, 0.06, 0.08), base + Vector((0, 1.08, -0.15)), C["lamp"] if side < 0 else C["amber"], 0.02)
        name = "StickL" if side < 0 else "StickR"
        stick.make(vid + "_" + name)
        mark(vid, name + "Pivot", base)
        mark(vid, "Grip" + ("L" if side < 0 else "R"), base + Vector((0, 1.0, 0)))
    # right console: a small screen and buttons; front: a low dash with two dials
    k.box((0.08, 0.6, 0.08), (1.5, sy + 1.1, sz - 1.3), C["black"])
    k.box((0.9, 0.6, 0.08), (1.5, sy + 1.55, sz - 1.3), C["black"], 0.03, rot(0, -35))
    k.box((0.78, 0.48, 0.02), (1.48, sy + 1.55, sz - 1.25), C["screen"], 0, rot(0, -35))
    for i in range(4):
        k.box((0.12, 0.05, 0.12), (1.25, sy + 0.82, sz - 0.1 + i * 0.2), (C["go"], C["amber"], C["lamp"], C["blue"])[i])
    top = sill - 0.2
    dz = z0 + 0.7
    k.box((x1 - x0 - 0.4, top - floor, 0.9), (0, (top + floor) / 2, dz), C["char"], 0.08)
    k.box((2.6, 0.9, 0.1), (0, top - 0.5, dz + 0.47), C["black"], 0.03, rot(-GAUGE_TILT))
    for i, name in ((-1, "NeedleSpeed"), (1, "NeedleRev")):
        at = (i * 0.6, top - 0.5, dz + 0.55)
        dial(k, at, 0.33, C["black"], C["yellow"])
        n = Vector(at) + (rot(-GAUGE_TILT).to_3x3() @ Vector((0, 0, 0.06)))
        needle_kit(vid, name, n, 0.33, C["black"])
    for px, w in ((-0.7, 0.5), (0.5, 0.6)):
        k.box((w, 0.7, 0.08), (px, floor + 0.38, dz + 1.3), C["dark"], 0.02, rot(55))
    k.cyl(0.22, 1.0, (x0 + 0.5, floor + 0.7, z1 - 0.5), C["lamp"], rot(90), 10)
    k.cyl(0.6, 0.5, (x1 - 0.9, roof - 1.0, z1 - 0.7), C["yellow"], rot(90), 12, 0.5)
    k.cyl(0.78, 0.06, (x1 - 0.9, roof - 1.25, z1 - 0.7), C["yellow"], rot(90), 14)
    k.box((1.0, 0.6, 0.6), (x1 - 0.8, floor + 0.4, z1 - 0.6), C["blue"], 0.08)
    k.box((1.1, 0.35, 0.14), (0, roof - 0.35, z0 + 0.35), C["black"], 0.04)
    mirror.box((1.0, 0.27, 0.02), (0, roof - 0.35, z0 + 0.43), C["pale"])
    k.make(vid + "_Interior")
    mirror.make(vid + "_Mirror")
    # running gear: bottom rollers and carriers, each spinning on its own; one link plate the game copies
    for s, side in ((1, "L"), (-1, "R")):
        n = 0
        for i in range(5):
            n += 1
            y = TY[0] + 0.33 + i * (TY[1] - TY[0] - 0.66) / 4
            rk = Kit(vid)
            c = R(s * TX, y, TT + 0.11)
            rk.cyl(0.11 * STUDS, TW * 0.7 * STUDS, c, C["dark"], rot(0, 90), 12)
            rk.cyl(0.13 * STUDS, 0.25, c + Vector((TW * 0.3 * STUDS, 0, 0)), C["dark"], rot(0, 90), 12)
            rk.cyl(0.13 * STUDS, 0.25, c - Vector((TW * 0.3 * STUDS, 0, 0)), C["dark"], rot(0, 90), 12)
            rk.make(f"{vid}_Roller{side}{n}")
        for y in (-0.2, 0.62):
            n += 1
            rk = Kit(vid)
            rk.cyl(0.07 * STUDS, TW * 0.5 * STUDS, R(s * TX, y, TZ + TR - 0.07), C["dark"], rot(0, 90), 10)
            rk.make(f"{vid}_Roller{side}{n}")
    # link plate, at rest on the ground under the left track: a plate with a grouser underneath and two link
    # rails on top, its middle on the loop (the game wraps copies round the idler and sprocket)
    perim = 2 * (TY[1] - TY[0]) * STUDS + 2 * math.pi * (TR + TT / 2) * STUDS
    pitch = perim / round(perim / 1.1)
    t = TT * STUDS
    c = R(TX, (TY[0] + TY[1]) / 2, TT / 2)
    sk = Kit(vid)
    sk.box((TW * STUDS, t * 0.45, pitch - 0.1), c + Vector((0, t * 0.025, 0)), C["dark"], 0.03)
    sk.box((TW * STUDS, t * 0.3, 0.3), c + Vector((0, -t * 0.35, -0.1)), C["dark"], 0.02)
    for x in (-0.9, 0.9):
        sk.box((0.4, t * 0.25, pitch - 0.02), c + Vector((x, t * 0.375, 0)), C["mid"], 0.02)
    sk.make(vid + "_TrackShoe")
    print(f"TRACK {vid} loop {perim:.2f} studs, {round(perim / pitch)} plates of {pitch:.3f} per side")


def towards(a, b):
    """Rotation turning a part's Z to point from a to b."""
    return (Vector(b) - Vector(a)).to_track_quat("Z", "Y").to_matrix().to_4x4()


def scooter_cockpit():
    """Handlebars that turn: the fork (legs on the front axle, crown, mudguard), the column, a headset with the lamp
    and a speedo, bars with grips, levers and mirrors (the Steer part, turned about SteerPivot on the raked axis
    through the front hub); a glovebox and hook on the back of the leg shield."""
    vid = "Scooter"
    R = lambda x, y, z: Vector(roblox_point(Vector((x, y, z)), STUDS, SCOOT_SHIFT))
    sx, sy, sz = SEATS[vid]
    tilt = TILTS.get(vid, STEER_TILT)
    assert abs(tilt - (90 - SCOOT_RAKE)) < 1e-6, "Config/Vehicles Scooter steerTilt must be 90 - SCOOT_RAKE"
    # the steering axis, in the Roblox frame: up and back towards the rider, through the front hub
    axis = Vector((0, math.sin(math.radians(tilt)), math.cos(math.radians(tilt))))
    hub_at = R(*SCOOT_HUB)
    reach = (SCOOT_HEAD - SCOOT_HUB.z) * STUDS / axis.y  # hub to the column top, along the axis
    p = hub_at + axis * reach
    STEER_PIVOT[vid] = p
    # grips a little below and ahead of a seated avatar's shoulders (measured in Studio: about 2.1 above the
    # seat spot), far enough out to leave the view clear
    global SCOOT_GRIPS
    SCOOT_GRIPS = Vector((0, sy + 2.05, sz - 1.75))
    # built as it stands, then baked untilted about the pivot so the steering weld can lean it back again
    k = Kit(vid, Matrix.Translation(p) @ rot(tilt))
    along = rot(SCOOT_RAKE)  # a part's Y along the column
    hub = hub_at - p
    on = lambda s: axis * s  # a point on the axis, s studs above the pivot
    # the axle through the wheel, the fork legs either side of it and the crown joining them over the mudguard
    k.cyl(0.12, 1.3, hub, C["chrome"], rot(0, 90), 8)
    crown = -reach + 1.95
    for x in (-0.52, 0.52):
        a, b = on(-reach - 0.12) + Vector((x, 0, 0)), on(crown) + Vector((x, 0, 0))
        k.cyl(0.13, (b - a).length, (a + b) / 2, C["chrome"], towards(a, b), 8)
    k.box((1.3, 0.35, 0.4), on(crown), C["char"], 0.08, along)
    # the column up to the headset (just in front of the leg shield)
    a, b = on(crown), on(0.3)
    k.cyl(0.22, (b - a).length, (a + b) / 2, C["char"], towards(a, b), 8)
    # the front mudguard: an arc of plates over the wheel, from just behind the top round to the front
    radius, steps = 1.42, 6
    for i in range(steps):
        f0, f1 = math.radians(-30 + 100 * i / steps), math.radians(-30 + 100 * (i + 1) / steps)
        f = (f0 + f1) / 2
        k.box((0.7, 0.1, radius * (f1 - f0) * 1.08), hub + Vector((0, math.cos(f), -math.sin(f))) * radius,
              C["black"], 0.02, rot(-math.degrees(f)))
    # the headset over the column: the lamp facing ahead, the speedo facing the rider
    head = on(0.3)
    k.box((1.4, 0.9, 1.0), head, C["char"], 0.22, along)
    k.cyl(0.32, 0.16, head + Vector((0, 0.02, -0.52)), C["pale"], along, 12)
    k.box((0.85, 0.08, 0.55), head + Vector((0, 0.47, 0.12)), C["black"], 0.04, along @ rot(25))
    k.box((0.55, 0.04, 0.3), head + Vector((0, 0.52, 0.14)), C["amber"], 0.02, along @ rot(25))
    bars = SCOOT_GRIPS - p
    for x in (-0.55, 0.55):
        riser = head + Vector((x, 0.35, 0.3))
        k.cyl(0.11, (bars + Vector((x, 0, 0)) - riser).length, (riser + bars + Vector((x, 0, 0))) / 2, C["black"],
              towards(riser, bars + Vector((x, 0, 0))), 8)
    k.cyl(0.12, 2.6, bars, C["black"], rot(0, 90), 8)
    for side in (-1, 1):
        k.cyl(0.19, 0.9, bars + Vector((side * 1.75, 0, 0)), C["char"], rot(0, 90), 10)
        k.box((1.0, 0.08, 0.1), bars + Vector((side * 1.55, 0.05, -0.32)), C["chrome"], 0.03, rot(0, side * 8))
        k.cyl(0.04, 1.3, bars + Vector((side * 1.15, 0.6, 0.0)), C["chrome"], rot(0, 0, side * -25) @ rot(90), 6)
        k.cyl(0.3, 0.08, bars + Vector((side * 1.45, 1.2, 0.05)), C["black"], rot(-10), 12)
        k.cyl(0.25, 0.04, bars + Vector((side * 1.45, 1.2, 0.1)), C["pale"], rot(-10), 12)
    k.make(vid + "_Steer")
    mark(vid, "SteerPivot", p)
    for side, name in ((-1, "GripL"), (1, "GripR")):
        mark(vid, name, p + bars + Vector((side * 1.75, 0, 0)))
    # the back of the leg shield (the body's shield, front face red): a cream panel, glovebox and bag hook
    i = Kit(vid)
    shield = R(0, -0.26 + 0.025, 0.445) + Vector((0, 0, 0.04))
    i.box((2.1, 2.9, 0.08), shield, C["cream"], 0.03)
    i.box((1.0, 0.6, 0.1), shield + Vector((0, 0.6, 0.08)), C["char"], 0.04)
    i.box((0.3, 0.06, 0.06), shield + Vector((0, 0.6, 0.14)), C["chrome"])
    i.box((0.1, 0.35, 0.1), shield + Vector((0, -0.6, 0.1)), C["chrome"], 0.02)
    i.make(vid + "_Interior")
    SEAT_AT[vid] = SEATS[vid]


def cart_cockpit():
    """Silly kit in a shopping cart: a toy steering wheel on a suction stalk (the Steer part), a phone taped to
    the front rail as a speedo, a bike bell, a cushion and a drink in a clip-on holder."""
    vid = "Cart"
    R = lambda x, y, z: Vector(roblox_point(Vector((x, y, z)), STUDS, CART_SHIFT))
    sx, sy, sz = SEATS[vid]
    SEAT_AT[vid] = (sx, sy, sz)
    front = R(0, -0.475, 0.74)
    k = Kit(vid)
    wc = Vector((0, sy + 1.9, sz - 1.8))
    k.cyl(0.12, (front - wc).length, (front + wc) / 2, C["yellow"], towards(wc, front), 8)
    k.cyl(0.45, 0.15, front + Vector((0, 0.0, 0.1)), C["blue"], None, 12)
    t = Kit(vid, Matrix.Translation(wc))
    t.ring(0.7, 0.13, (0, 0, 0), C["yellow"], None, 20, 6)
    t.cyl(0.3, 0.25, (0, 0, 0), C["lamp"], None, 12)
    for a in (90, 210, 330):
        t.box((0.6, 0.18, 0.12), (0, 0, 0), C["lamp"], 0.04, rot(0, 0, a) @ Matrix.Translation((0.45, 0, 0)))
    for i, cc in enumerate(("blue", "go", "amber")):
        a = math.radians(30 + 120 * i)
        t.cyl(0.08, 0.1, (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.14), C[cc], None, 8)
    t.make(vid + "_Steer")
    k.box((0.9, 1.5, 0.12), front + Vector((1.0, 0.25, 0.05)), C["black"], 0.06, rot(-15))
    k.box((0.78, 1.3, 0.02), front + Vector((1.0, 0.27, 0.12)), C["screen"], 0, rot(-15))
    k.box((0.5, 0.3, 0.02), front + Vector((1.0, 0.55, 0.14)), C["go"], 0, rot(-15))
    for dy in (-0.35, 0.55):
        k.box((1.1, 0.2, 0.16), front + Vector((1.0, dy, 0.06)), C["white"], 0, rot(-15))
    k.cyl(0.28, 0.25, front + Vector((-1.4, 0.2, 0.0)), C["chrome"], rot(90), 12, 0.12)
    k.box((2.6, 0.5, 2.6), (sx, sy - 0.075, sz + 0.2), C["pink"], 0.2)
    side = R(-0.31, 0.1, 0.74)
    k.box((0.4, 0.12, 0.3), side + Vector((-0.12, 0.25, 0)), C["black"], 0.03)  # the holder's clip on the rail
    k.cyl(0.3, 0.7, side + Vector((-0.32, 0.0, 0)), C["lamp"], rot(90), 10, 0.36)
    k.cyl(0.04, 0.8, side + Vector((-0.32, 0.6, 0.1)), C["white"], rot(80), 4)
    k.make(vid + "_Interior")


bulldozer_cab()
scooter_cockpit()
cart_cockpit()


for vid in vehicles:
    if vid in SEATS and vid not in EYES:
        sx, sy, sz = SEAT_AT.get(vid, SEATS[vid])
        EYES[vid] = (sx, sy + EYE_UP, sz - EYE_FWD)


# ---- cabins that must not touch their shell: any cabin piece (above the floor) that crosses the body or glass,
# or sits within CLEAR_GAP of it, is dropped, so nothing shows through the shell from outside (the Roadster's
# curved doors and glass roof sit close round its low seat)
CLEAR_SHELL = ("Roadster",)
CLEAR_GAP = 0.06


def clear_shell(vid):
    hull = [tree_of(bpy.data.objects[vid + "_Body"])]
    if vid + "_Glass" in bpy.data.objects:
        hull.append(tree_of(bpy.data.objects[vid + "_Glass"]))
    for part in ("_Interior", "_Mirror"):
        o = bpy.data.objects.get(vid + part)
        if not o or not o.data.vertices:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        low = min(v.co.z for v in bm.verts) + 0.4  # the floor and what sits on it, where nobody sees
        seen, drop = set(), []
        for f0 in bm.faces:
            if f0.index in seen:
                continue
            group, stack = [], [f0]
            while stack:
                f = stack.pop()
                if f.index in seen:
                    continue
                seen.add(f.index)
                group.append(f)
                stack.extend(g for e in f.edges for g in e.link_faces if g.index not in seen)
            verts = list({v.index: v for f in group for v in f.verts}.values())
            if max(v.co.z for v in verts) < low:
                continue
            at = {v.index: i for i, v in enumerate(verts)}
            t = BVHTree.FromPolygons([v.co.copy() for v in verts], [tuple(at[v.index] for v in f.verts) for f in group])
            near_ = any(h.find_nearest(v.co, CLEAR_GAP)[0] is not None for h in hull for v in verts)
            if near_ or any(t.overlap(h) for h in hull):
                drop += group
        print(f"CLEAR {vid}{part}: dropped {len(drop)} of {len(bm.faces)} faces")
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        bm.to_mesh(o.data)
        bm.free()


for vid in CLEAR_SHELL:
    clear_shell(vid)


# ---- paint: each body's painted panels become <Id>_Paint, an untextured mesh the game colours (Config/Paints).
# PAINT lists the palette colours (sRGB 0-1, as face_colour reads them) that count as paint on each vehicle;
# lights, trim, grilles, stripes and liveries are other colours and stay on the textured Body.
PAINT = {
    "Hatchback": [(0.34, 0.49, 0.28)],
    "Sedan": [(0.22, 0.44, 0.69)],
    "Taxi": [(0.91, 0.64, 0.22)],
    "Muscle": [(0.76, 0.27, 0.19)],
    "Supercar": [(0.91, 0.64, 0.22)],
    "IceCream": [(0.8, 0.8, 0.78)],
    "FireTruck": [(0.68, 0.24, 0.16)],
    "Semi": [(0.8, 0.8, 0.78)],
    "Monster": [(0.34, 0.49, 0.28)],
    "Bulldozer": [(0.92, 0.64, 0.21)],
    "Scooter": [(0.76, 0.27, 0.19)],
    "Cart": [(0.72, 0.72, 0.71)],
    "Roadster": [(0.8, 0.06, 0.07)],
}


def survey(obj):
    """Face area per palette colour, biggest first (to choose PAINT colours)."""
    me = obj.data
    area = {}
    for p in me.polygons:
        col = face_colour(me, p)
        area[col] = area.get(col, 0) + p.area
    return sorted(area.items(), key=lambda kv: -kv[1])


for vid in vehicles:
    body = bpy.data.objects[vid + "_Body"]
    total = sum(a for _, a in survey(body)) or 1
    print("SURVEY", vid, " ".join(f"{c}:{a / total:.2f}" for c, a in survey(body)[:8]))
    cols = PAINT.get(vid)
    if cols:
        shell = split_off(body, lambda c, col: any(near(col, k) for k in cols), vid + "_Paint")
        assert shell, f"{vid}: no faces in its PAINT colours"
        exported.append(shell)
        print(f"PAINT {vid} {len(shell.data.polygons)} faces {cols[0]}")

# ---- export
tri = 0
for o in exported:
    o.data.calc_loop_triangles()
    tri += len(o.data.loop_triangles)
print("PARTS", len(exported), "TRIS", tri)
for o in exported:
    # a stray piece far from its vehicle (a ray that found nothing) would make Roblox shrink the whole upload
    lo, hi = bounds([o])
    assert max(hi - lo) < 60, f"{o.name} spans {max(hi - lo):.0f} studs"
    n = len(o.data.loop_triangles)
    if n > 8000:
        print("BIG", o.name, n)
    assert n <= 20000, f"{o.name} has {n} triangles (Roblox allows 20,000 per mesh)"
for o in bpy.data.objects:
    o.select_set(o in exported)
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                         add_leaf_bones=False, bake_anim=False, path_mode="STRIP")
print("EXPORTED", out)

if wheel_preview:
    # preview only: one left wheel per vehicle, side on, in a row, same size so the rims compare
    saved = {o: (o.location.copy(), o.scale.copy(), o.hide_render) for o in exported}
    shown = []
    for vid in vehicles:
        ws = sorted((o for o in exported if o.name.startswith(vid + "_Wheel_") and o.name[-2] == "L"), key=lambda o: o.name)
        if ws:
            shown.append(ws[0])
    for o in exported:
        o.hide_render = o not in shown
    for i, o in enumerate(shown):
        lo, hi = bounds([o])
        size = hi.z - lo.z
        o.scale = Vector((1, 1, 1)) * (6.0 / size)
        o.location = Vector((0, (i % 6) * 8.0, -(i // 6) * 8.0))
    cam = bpy.data.objects.new("WheelCam", bpy.data.cameras.new("WheelCam"))
    cam.data.type = "ORTHO"
    rows = (len(shown) + 5) // 6
    cam.location = (60, 5 * 8.0 / 2, -(rows - 1) * 8.0 / 2)
    cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    cam.data.ortho_scale = 6 * 8.0 * 1.05
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 300 * rows + 60
    scene.render.filepath = wheel_preview
    bpy.ops.render.render(write_still=True)
    print("WHEEL PREVIEW", wheel_preview)
    for o, (loc, sc, hid) in saved.items():
        o.location, o.scale, o.hide_render = loc, sc, hid
    bpy.data.objects.remove(cam)

if cabin_preview:
    # preview only: what the driver sees, one picture per vehicle (Roblox vertical FOV, glass as see-through as in
    # first person), lit by a sun and a pale sky
    os.makedirs(cabin_preview, exist_ok=True)
    glass_mat = mat.copy()
    bsdf = glass_mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Alpha"].default_value = 1 - EYE_GLASS
    glass_mat.surface_render_method = "BLENDED"
    for o in exported:
        if o.name.endswith("_Glass"):
            o.data.materials.clear()
            o.data.materials.append(glass_mat)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.9, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(30))
    scene.collection.objects.link(sun)
    ground = box("ground", (2000, 2000, 0.1), (300, 0, -0.05), (0.32, 0.33, 0.34))
    finish(ground)
    cam = bpy.data.objects.new("EyeCam", bpy.data.cameras.new("EyeCam"))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(EYE_FOV)
    cam.data.clip_start = 0.1
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    # lean the steering wheels and needles back as their welds do in the game
    flip = ROBLOX.to_3x3()
    for o in exported:
        vid, _, part = o.name.partition("_")
        lean = TILTS.get(vid, STEER_TILT) if part == "Steer" else GAUGE_TILT if part.startswith("Needle") else 0
        if lean:
            lo, hi = bounds([o])
            c = (lo + hi) / 2
            if part == "Steer" and vid in STEER_PIVOT:
                c = in_slot(vid, *STEER_PIVOT[vid])
            m = (flip @ rot(-lean).to_3x3() @ flip.inverted()).to_4x4()
            o.data.transform(Matrix.Translation(c) @ m @ Matrix.Translation(-c))
    # nothing may sit inside the camera's near plane: report the closest surface to each driver's eye
    trees = {}
    for o in exported:
        if "_Wheel_" not in o.name:  # wheels keep their own origin; the rest are identity-placed
            trees.setdefault(o.name.split("_")[0], []).append(tree_of(o))
    dirs = [Vector((math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b)))
            for a in [i * math.pi / 12 for i in range(24)] for b in [j * math.pi / 12 - math.pi / 2 for j in range(13)]]
    for vid, eye in EYES.items():
        o = in_slot(vid, *eye)
        near_d = min((h[3] for t in trees.get(vid, []) for d in dirs for h in [t.ray_cast(o, d, 5)] if h[0]), default=5)
        print(f"NEAR {vid} closest surface {near_d:.2f} studs from the eye")
    # every cabin must fit its vehicle: no piece sticking out of the shell (looking out sideways, up and ahead
    # from it there must be body or glass) and nothing floating (each piece touches another, and every group of
    # touching pieces touches the body or glass somewhere)
    def islands(o):
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.verts.ensure_lookup_table()
        seen, out = set(), []
        for v in bm.verts:
            if v.index in seen:
                continue
            group, stack = [], [v]
            while stack:
                u = stack.pop()
                if u.index in seen:
                    continue
                seen.add(u.index)
                group.append(u.co.copy())
                stack.extend(e.other_vert(u) for e in u.link_edges if e.other_vert(u).index not in seen)
            out.append(group)
        bm.free()
        return out

    def fit_report(vid):
        hull = [tree_of(bpy.data.objects[vid + "_Body"])]
        if vid + "_Glass" in bpy.data.objects:
            hull.append(tree_of(bpy.data.objects[vid + "_Glass"]))
        cx = vehicles.index(vid) * SPACING
        pieces = []
        for part in ("_Interior", "_Mirror"):
            if vid + part in bpy.data.objects:
                pieces += islands(bpy.data.objects[vid + part])
        boxes = [(Vector([min(c[i] for c in g) for i in range(3)]), Vector([max(c[i] for c in g) for i in range(3)])) for g in pieces]
        # sticking out
        out = []
        blo, bhi = bounds([bpy.data.objects[vid + "_Body"]])
        inner_x = (bhi.x - blo.x) * 0.3
        low = min(c.z for g in pieces for c in g) + 0.2
        for g, (lo_, hi_) in zip(pieces if vid not in ("Scooter", "Cart") else [], boxes):
            for c in g:
                if c.z < low:
                    continue  # the floor's underside, where nobody looks
                side_ = Vector((1 if c.x > cx else -1, 0, 0))
                dirs = (side_, Vector((0, 0, 1)), Vector((0, -1, 0))) if abs(c.x - cx) < inner_x else (side_,)
                # a hair off the middle: a ray straight along a symmetric body's centre seam can slip between faces
                c = c + Vector((0.013, 0.007, 0))
                if not all(any(t.ray_cast(c, d, 40)[0] for t in hull) for d in dirs):
                    out.append((lo_ + hi_) / 2)
                    break
        # floating: groups of touching pieces that never touch the body or glass
        parent = list(range(len(pieces)))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        pad = 0.06
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a_, b_ = boxes[i], boxes[j]
                if all(a_[0][k] - pad <= b_[1][k] and b_[0][k] - pad <= a_[1][k] for k in range(3)):
                    parent[find(i)] = find(j)
        grounded = set()
        for i, g in enumerate(pieces):
            if any(t.find_nearest(c, 0.15)[0] is not None for t in hull for c in g):
                grounded.add(find(i))
        floating = {}
        for i in range(len(pieces)):
            if find(i) not in grounded:
                floating.setdefault(find(i), []).append(i)
        def rb_(v):
            r = ROBLOX.inverted() @ (v - Vector((cx, 0, 0)))
            return f"({r.x:.1f}, {r.y:.1f}, {r.z:.1f})"
        print(f"FIT {vid}: {len(pieces)} pieces, {len(out)} sticking out, {len(floating)} floating groups")
        for c in out[:12]:
            print(f"   out at {rb_(c)}")
        for members in list(floating.values())[:12]:
            lo_ = Vector([min(boxes[i][0][k] for i in members) for k in range(3)])
            hi_ = Vector([max(boxes[i][1][k] for i in members) for k in range(3)])
            print(f"   floating {len(members)} piece(s) at {rb_((lo_ + hi_) / 2)} size {(hi_ - lo_).length:.2f}")
        return len(out), len(floating)

    bad = 0
    for vid in list(CABIN) + ["Bulldozer", "Scooter", "Cart"]:
        o_, f_ = fit_report(vid)
        bad += o_ + f_
    print("FIT TOTAL", bad)
    for vid, (ex, ey, ez) in EYES.items():
        cam.location = in_slot(vid, ex, ey, ez)
        # Blender camera looks down its -Z; point it at the vehicle's front (Blender -Y), tipped down a little
        cam.rotation_euler = (math.radians(90 - EYE_PITCH), 0, math.pi)
        scene.render.filepath = os.path.join(cabin_preview, vid + ".png")
        bpy.ops.render.render(write_still=True)
        cam.rotation_euler = (math.radians(90 - 28), 0, math.pi - math.radians(48))
        scene.render.filepath = os.path.join(cabin_preview, "side", vid + ".png")
        bpy.ops.render.render(write_still=True)
    print("CABIN PREVIEW", cabin_preview)

    # from outside, with the glass as see-through as it is in the game: no cabin piece may show through the body
    bsdf.inputs["Alpha"].default_value = 0.55
    cam.data.angle = math.radians(40)
    for vid in ("Roadster", "Supercar", "Monster", "Semi", "FireTruck", "IceCream", "Hatchback"):
        lo_, hi_ = bounds([bpy.data.objects[vid + "_Body"]])
        mid_ = (lo_ + hi_) / 2
        reach = max(hi_ - lo_)
        for name, off in (("left", Vector((1.0, -0.55, 0.35))), ("right", Vector((-1.0, 0.35, 0.3)))):
            eye_ = mid_ + off * reach * 1.1
            cam.location = eye_
            cam.rotation_euler = (mid_ - eye_).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(cabin_preview, "outside", f"{vid}_{name}.png")
            bpy.ops.render.render(write_still=True)
    bsdf.inputs["Alpha"].default_value = 1 - EYE_GLASS

    # the bulldozer's tracks as the game lays them: link plates copied round the loop past the idler (front)
    # and sprocket (rear), each turned to follow it
    vid = "Bulldozer"
    base = Matrix.Translation((vehicles.index(vid) * SPACING, 0, 0)) @ ROBLOX
    shoe = bpy.data.objects[vid + "_TrackShoe"]
    slo, shi = bounds([shoe])
    rest = base.inverted() @ ((slo + shi) / 2)
    thick = (shi - slo).z  # Blender Z is Roblox Y
    for side in ("L", "R"):
        idl = base.inverted() @ bpy.data.objects[f"{vid}_Wheel_F{side}1"].location
        spr = base.inverted() @ bpy.data.objects[f"{vid}_Wheel_R{side}1"].location
        wl, wh = bounds([bpy.data.objects[f"{vid}_Wheel_F{side}1"]])
        rp = (wh.z - wl.z) / 2 + thick / 2
        length = spr.z - idl.z
        perim = 2 * length + 2 * math.pi * rp
        count = round(perim / 1.1)
        for i in range(count):
            d = i * perim / count
            if d < length:
                at, ang = Vector((idl.x, idl.y - rp, idl.z + d)), 0.0
            elif d < length + math.pi * rp:
                t = (d - length) / rp
                at, ang = Vector((idl.x, spr.y - rp * math.cos(t), spr.z + rp * math.sin(t))), -t
            elif d < 2 * length + math.pi * rp:
                at, ang = Vector((idl.x, idl.y + rp, spr.z - (d - length - math.pi * rp))), -math.pi
            else:
                t = (d - 2 * length - math.pi * rp) / rp
                at, ang = Vector((idl.x, idl.y + rp * math.cos(t), idl.z - rp * math.sin(t))), -math.pi - t
            m = Matrix.Translation(at) @ Matrix.Rotation(ang, 4, "X") @ Matrix.Translation(-rest)
            c = shoe.copy()
            c.matrix_world = base @ m @ base.inverted()
            scene.collection.objects.link(c)
    shoe.hide_render = True
    centre = bounds([bpy.data.objects[vid + "_Body"]])
    mid = (centre[0] + centre[1]) / 2
    cam.data.angle = math.radians(50)
    shots = {
        "dozer_front": (mid + Vector((26, -30, 12)), mid + Vector((0, -2, -2))),
        "dozer_side": (mid + Vector((30, 0, -2)), mid + Vector((6, 0, -5))),
        "dozer_sprocket": (mid + Vector((16, 16, -3)), mid + Vector((6, 9, -6))),
        "dozer_cab": (mid + Vector((-16, -14, 14)), mid + Vector((0, 2, 3))),
    }
    for name, (eye, look) in shots.items():
        cam.location = eye
        cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(cabin_preview, "tracks", name + ".png")
        bpy.ops.render.render(write_still=True)

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
    if os.environ.get("PAINT_PREVIEW"):
        # check which faces became paint: they show purple
        for o in exported:
            if o.name.endswith("_Paint"):
                paint(o, (0.72, 0.45, 0.73))
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", preview)
