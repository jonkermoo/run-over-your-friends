# The Money Truck event's armoured bank van (Config/Events MoneyTruck.Vehicle = "BankVan"): the Pavel 3D pack's
# police box truck (CC BY 4.0) restyled the way export_vehicles.py restyles the pack cars, textured with the pack
# palette: its blue and white panels become the armour Paint (an untextured part the game colours from Config),
# the police light bar an amber beacon, plus our own gold band down each side and round vault doors (gold ring,
# steel door, bolts, spoked handle wheel) on the back and both sides of the vault box.
# blender -b --factory-startup --python export_bank_van.py -- <pack_dir> <out.fbx> [preview.png|-] [pieces.blend|-]
#   <pack_dir>: the extracted "Low Poly City Vehicles Pack" (BLEND/ and the palette png), as for export_vehicles.py.
#   pieces.blend keeps every added piece as its own object, for check_overlap.py.
# Parts: Body (palette textured), Paint, Trim (gold; both coloured by client/EventProps from Config), and
# Wheel_<FL|FR|RL|RR><n> (textured). Front is Blender -Y, left +X; studs at STUDS per pack unit, as the pack cars.
import bpy, bmesh, sys, math, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
pack, out = args[0], os.path.abspath(args[1])
preview = os.path.abspath(args[2]) if len(args) > 2 and args[2] != "-" else None
pieces_path = os.path.abspath(args[3]) if len(args) > 3 and args[3] != "-" else None
STUDS = 8.0  # studs per pack unit (export_vehicles.py)

scene = bpy.context.scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

palette = bpy.data.images.load(os.path.join(pack, "city_vehicles_pallete.png"))
PW, PH = palette.size
pix = list(palette.pixels)
CELLS = 32
cells = []
for j in range(CELLS):
    for i in range(CELLS):
        x, y = int((i + 0.5) * PW / CELLS), int((j + 0.5) * PH / CELLS)
        k = (y * PW + x) * 4
        cells.append(((i + 0.5) / CELLS, (j + 0.5) / CELLS, pix[k], pix[k + 1], pix[k + 2]))


def uv_for(rgb):
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
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])


def flat(name, rgb, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = 0.4
    return m


# preview colours of the untextured parts (in game they come from Config/Events MoneyTruck)
PAINT_MAT = flat("Paint", (0.033, 0.075, 0.042))
TRIM_MAT = flat("Trim", (1.0, 0.55, 0.02), 0.7)


def paint(obj, rgb):
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new()
    uv = uv_for(rgb)
    for loop in me.loops:
        me.uv_layers.active.data[loop.index].uv = uv


def face_colour(me, poly):
    uv = me.uv_layers.active.data[poly.loop_start].uv
    x, y = min(PW - 1, int(uv.x * PW)), min(PH - 1, int(uv.y * PH))
    k = (y * PW + x) * 4
    return tuple(round(c, 2) for c in pix[k:k + 3])


def near(c, ref):
    return max(abs(a - b) for a, b in zip(c, ref)) < 0.02


def recolour(obj, test, rgb):
    me = obj.data
    uv = uv_for(rgb)
    layer = me.uv_layers.active.data
    for p in me.polygons:
        if test(p.center, face_colour(me, p)):
            for li in p.loop_indices:
                layer[li].uv = uv


def split_off(obj, test, name):
    me = obj.data
    picked = {p.index for p in me.polygons if test(p.center, face_colour(me, p))}
    bm = bmesh.new()
    bm.from_mesh(me)
    keep = bm.copy()
    bm.faces.ensure_lookup_table()
    keep.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in range(len(bm.faces)) if i not in picked], context="FACES")
    bmesh.ops.delete(keep, geom=[keep.faces[i] for i in picked], context="FACES")
    part = bpy.data.meshes.new(name)
    bm.to_mesh(part)
    keep.to_mesh(me)
    bm.free()
    keep.free()
    o = bpy.data.objects.new(name, part)
    scene.collection.objects.link(o)
    return o


def bounds(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


pieces = {"Body": [], "Trim": []}  # added pieces, per part


def mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return o


def add(part, o, rgb=None):
    o.name = f"{part}.{len(pieces[part]):02d}"
    if rgb:
        paint(o, rgb)
    pieces[part].append(o)
    return o


def cyl(part, radius, a, b, centre, axis, verts=24, rgb=None):
    """A cylinder on axis ("X" | "Y") from a to b, centred on the other two (horizontal, up) at centre."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius, depth=abs(b - a))
    mid = (a + b) / 2
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
        bmesh.ops.translate(bm, vec=(mid, centre[0], centre[1]), verts=bm.verts)
    else:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
        bmesh.ops.translate(bm, vec=(centre[0], mid, centre[1]), verts=bm.verts)
    return add(part, mesh_obj(part, bm), rgb)


def slab(part, lo, hi, rot=None, pivot=None, rgb=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(hi) - Vector(lo), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(Vector(hi) + Vector(lo)) / 2, verts=bm.verts)
    if rot is not None:
        p = Vector(pivot)
        bmesh.ops.translate(bm, vec=-p, verts=bm.verts)
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
        bmesh.ops.translate(bm, vec=p, verts=bm.verts)
    return add(part, mesh_obj(part, bm), rgb)


# ---- the pack truck, baked to world space
with bpy.data.libraries.load(os.path.join(pack, "BLEND", "Police", "Veh_Police_Truck.blend")) as (src, dst):
    dst.objects = list(src.objects)
objs = [o for o in dst.objects if o and o.type == "MESH"]
for o in objs:
    scene.collection.objects.link(o)
bpy.context.view_layer.update()
for o, m in [(o, o.matrix_world.copy()) for o in objs]:
    o.data = o.data.copy()
    o.data.transform(m)
    o.parent = None
    o.matrix_world = Matrix.Identity(4)
body = next(o for o in objs if not o.name.startswith("Wheel"))
wheels = [o for o in objs if o.name.startswith("Wheel")]
# the pack's tyres sit flush with the body side over the arches (same plane, they flicker): out a hair
for w in wheels:
    cx = sum(v.co.x for v in w.data.vertices) / len(w.data.vertices)
    w.data.transform(Matrix.Translation((0.006 if cx > 0 else -0.006, 0, 0)))

BLUE, WHITE, RED = (0.2, 0.35, 0.62), (0.8, 0.8, 0.78), (0.47, 0.13, 0.15)
LIGHTBAR_WHITE, AMBER, STEEL, DARK = (0.8, 0.82, 0.81), (0.77, 0.48, 0.3), (0.55, 0.56, 0.58), (0.24, 0.25, 0.27)

# where the vault box's sides and back are, and where its blue meets its white (the gold band goes there)
bm = bmesh.new()
bm.from_mesh(body.data)
tree = BVHTree.FromBMesh(bm)
bm.free()


def hit(origin, direction):
    loc, normal, index, _ = tree.ray_cast(Vector(origin), Vector(direction))
    return loc, index


side_x = hit((3, 0.4, 0.8), (-1, 0, 0))[0].x
back_y = hit((0, 4, 0.95), (0, -1, 0))[0].y
box_top = hit((0, 0.4, 4), (0, 0, -1))[0].z
seam = None
prev = None
for k in range(40):
    z = 0.45 + k * 0.025
    loc, idx = hit((3, 0.4, z), (-1, 0, 0))
    col = face_colour(body.data, body.data.polygons[idx]) if loc else None
    if prev is not None and col is not None and near(prev, BLUE) and near(col, WHITE):
        seam = z
        break
    prev = col
assert seam, "no blue/white seam on the box side"
print(f"BOX side x {side_x:.3f} back y {back_y:.3f} top z {box_top:.3f} seam z {seam:.3f}")

# ---- restyle: the police light bar (on the cab roof, ahead of the box) becomes an amber beacon
cab_top = hit((0, -1.3, 4), (0, 0, -1))[0].z
recolour(body, lambda c, col: c.y < -0.98 and c.z > cab_top - 0.2 and (near(col, RED) or near(col, LIGHTBAR_WHITE)), AMBER)

# ---- gold band along each side of the vault box, on the blue/white seam, with a vault door above it
BAND = 0.045  # half height, pack units
DOOR_Y, DOOR_Z = 0.2, (seam + box_top) / 2 - 0.02  # clear above the band
RING, DOOR = 0.31, 0.26
box_front = hit((0.0, -4, box_top - 0.05), (0, 1, 0))[0].y
for s in (1, -1):
    x0, x1 = sorted((s * (side_x - 0.004), s * (side_x + 0.012)))
    slab("Trim", (x0, box_front + 0.06, seam - BAND), (x1, back_y - 0.06, seam + BAND))


def handle(axis, sign, base, centre, r):
    """A vault door's spoked handle wheel standing out from base (on axis) towards sign."""
    cyl("Trim", r * 0.2, base, base + sign * 0.05, centre, axis, verts=12)
    for k in range(3):
        a = k * math.pi / 3
        d0, d1 = 0.01 + k * 0.005, 0.024 + k * 0.005  # each spoke a little further out: no shared planes
        w = r * 0.045
        if axis == "X":
            lo = (min(base + sign * d0, base + sign * d1), centre[0] - r * 0.7, centre[1] - w)
            hi = (max(base + sign * d0, base + sign * d1), centre[0] + r * 0.7, centre[1] + w)
            slab("Trim", lo, hi, Matrix.Rotation(a, 3, "X"), ((lo[0] + hi[0]) / 2, centre[0], centre[1]))
        else:
            lo = (centre[0] - r * 0.7, min(base + sign * d0, base + sign * d1), centre[1] - w)
            hi = (centre[0] + r * 0.7, max(base + sign * d0, base + sign * d1), centre[1] + w)
            slab("Trim", lo, hi, Matrix.Rotation(a, 3, "Y"), (centre[0], (lo[1] + hi[1]) / 2, centre[1]))
    for k in range(6):
        a = k * math.pi / 3
        c = (centre[0] + math.cos(a) * r * 0.7, centre[1] + math.sin(a) * r * 0.7)
        cyl("Trim", r * 0.08, base + sign * 0.005, base + sign * 0.03, c, axis, verts=8)


def vault_door(axis, sign, face, centre, ring_r, door_r):
    """Gold ring sunk a hair into the face, a steel door standing out of it, bolts round its rim, a handle."""
    cyl("Trim", ring_r, face - sign * 0.004, face + sign * 0.012, centre, axis, verts=32)
    out = face + sign * 0.028
    cyl("Body", door_r, face + sign * 0.006, out, centre, axis, verts=32, rgb=STEEL)
    for k in range(10):
        a = (k + 0.5) * math.pi * 2 / 10
        c = (centre[0] + math.cos(a) * door_r * 0.82, centre[1] + math.sin(a) * door_r * 0.82)
        cyl("Trim", door_r * 0.07, out - sign * 0.003, out + sign * 0.012, c, axis, verts=8)
    handle(axis, sign, out - sign * 0.003, centre, door_r)


for s in (1, -1):
    vault_door("X", s, s * side_x, (DOOR_Y, DOOR_Z), RING, DOOR)
# the back: over the pack's rear doors
vault_door("Y", 1, back_y, (0.0, 0.97), 0.3, 0.25)

if pieces_path:
    for o in [body] + wheels + pieces["Body"] + pieces["Trim"]:
        o.data.materials.clear()
        o.data.materials.append(TRIM_MAT if o in pieces["Trim"] else mat)
    bpy.ops.wm.save_as_mainfile(filepath=pieces_path)

# ---- the parts: Paint split off the body, the added steel joined into the body, the gold into Trim


def join(objs, name):
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


paint_part = split_off(body, lambda c, col: near(col, BLUE) or near(col, WHITE), "Paint")
body = join([body] + pieces["Body"], "Body")
trim = join(pieces["Trim"], "Trim")
parts = [body, paint_part, trim]
for o in parts + wheels:
    o.data.transform(Matrix.Scale(STUDS, 4))
lo, hi = bounds([body] + wheels)
shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
for o in parts + wheels:
    o.data.transform(Matrix.Translation(shift))
count = {}
for w in sorted(wheels, key=lambda w: (bounds([w])[0].y, bounds([w])[0].x)):
    wl, wh = bounds([w])
    c = (wl + wh) / 2
    corner = ("F" if c.y < 0 else "R") + ("L" if c.x > 0 else "R")
    count[corner] = count.get(corner, 0) + 1
    w.name = f"Wheel_{corner}{count[corner]}"
    w.data.name = w.name
    w.data.transform(Matrix.Translation(-c))  # pivot at the wheel centre so it spins in place
    w.location = c
for o in [body] + wheels:
    o.data.materials.clear()
    o.data.materials.append(mat)
for o, m in ((paint_part, PAINT_MAT), (trim, TRIM_MAT)):
    o.data.materials.clear()
    o.data.materials.append(m)
bpy.context.view_layer.update()
tris = 0
for o in parts + wheels:
    o.data.calc_loop_triangles()
    n = len(o.data.loop_triangles)
    tris += n
    l, h = bounds([o])
    print(f"PART {o.name:10s} {n:5d} tris  size {h.x - l.x:6.2f} x {h.y - l.y:6.2f} x {h.z - l.z:6.2f}")
    assert n <= 20000 and max(h - l) < 60
print("TRIS", tris)
lo, hi = bounds([body] + wheels)
print(f"SIZE {hi.x - lo.x:.2f} x {hi.y - lo.y:.2f} x {hi.z - lo.z:.2f} studs")

# ---- preview: four views on one sheet
if preview:
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.68, 0.75, 1)
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x, scene.render.resolution_y = 800, 560
    target = Vector((0, 0, (hi.z - lo.z) * 0.45))
    base = os.path.splitext(preview)[0]
    shots = []
    for i, (az, el) in enumerate(((-130, 18), (-50, 22), (50, 15), (130, 25))):
        a, e = math.radians(az), math.radians(el)
        cam.location = target + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e))) * 72
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{base}_{i}.png"
        bpy.ops.render.render(write_still=True)
        shots.append(f"{base}_{i}.png")
    imgs = [bpy.data.images.load(p) for p in shots]
    W, H = imgs[0].size
    sheet = bpy.data.images.new("sheet", W * 2, H * 2)
    px = [0.0] * (W * 2 * H * 2 * 4)
    for k, im in enumerate(imgs):
        src_px = list(im.pixels)
        ox, oy = (k % 2) * W, (1 - k // 2) * H
        for row in range(H):
            d = ((oy + row) * W * 2 + ox) * 4
            px[d:d + W * 4] = src_px[row * W * 4:(row + 1) * W * 4]
    sheet.pixels = px
    sheet.filepath_raw = preview
    sheet.file_format = "PNG"
    sheet.save()
    for p in shots:
        os.remove(p)
    print("PREVIEW", preview)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)

# ---- export, with a tiny Origin cube at 0 so Roblox keeps positions relative to it
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=0.02)
origin = mesh_obj("Origin", bm)
for o in bpy.data.objects:
    o.select_set(o in parts + wheels + [origin])
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                         global_scale=0.01, axis_forward="-Z", axis_up="Y", apply_unit_scale=True,
                         add_leaf_bones=False, bake_anim=False, path_mode="STRIP")
print("EXPORTED", out)
