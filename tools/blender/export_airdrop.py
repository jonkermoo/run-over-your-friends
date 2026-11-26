# The Cash Drop event's airdrop (Config/Events CashDrop): a supply crate on a pallet under a striped parachute, all
# our own shapes, in plain colours (each part one colour; the game colours them).
# blender -b --factory-startup --python export_airdrop.py -- <out.fbx> [preview.png|-]
# Uploaded as Open Cloud Model 116843390929995 (group 4725 Studio), 2,268 tris.
# Parts (studs, Blender Z up; the crate's bottom centre at 0, its top at CRATE):
#   Crate         olive drab plank boards on all six faces
#   Crate_Band    dark steel: the core box between the boards, edge bands, corner caps, strap buckles, stencil star
#   Crate_Trim    khaki: two straps over the top, the stencil panels, the pallet under the crate
#   Chute         the canopy's red gores (a scalloped dome, CHUTE across and LIFT tall, inside faces too)
#   Chute_Stripe  the white gores and the vent cap
#   Chute_Lines   the suspension lines from the rim to a link over the crate, and four risers to its top corners
# The Chute parts are separate so the game can hide the canopy once the crate lands.
import bpy, bmesh, sys, math, os
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
out = os.path.abspath(args[0])
preview = os.path.abspath(args[1]) if len(args) > 1 and args[1] != "-" else None

CRATE = 10.0  # crate width and height, pallet included (CrateSize)
CHUTE, LIFT = 36.0, 12.0  # canopy width and height (ChuteSize)
RIM = CRATE + 12.0  # height of the canopy's rim
LINK = CRATE + 2.5  # where the lines meet over the crate
GORES = 12

scene = bpy.context.scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

# preview colours (in game each part is a plain colour)
LOOK = {
    "Crate": (0.11, 0.13, 0.045),
    "Crate_Band": (0.035, 0.037, 0.04),
    "Crate_Trim": (0.45, 0.36, 0.17),
    "Chute": (0.6, 0.02, 0.015),
    "Chute_Stripe": (0.85, 0.85, 0.82),
    "Chute_Lines": (0.3, 0.3, 0.28),
}
bms = {name: bmesh.new() for name in LOOK}


def box(part, lo, hi):
    bm = bms[part]
    m = Matrix.Translation((Vector(hi) + Vector(lo)) / 2) @ Matrix.Diagonal((*(Vector(hi) - Vector(lo)), 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def rod(part, a, b, r, sides=4):
    """A thin open prism from a to b (a line)."""
    bm = bms[part]
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    side = d.orthogonal().normalized()
    up = d.cross(side)
    ring = []
    for k in range(sides):
        t = k * math.pi * 2 / sides
        off = (side * math.cos(t) + up * math.sin(t)) * r
        ring.append((bm.verts.new(a + off), bm.verts.new(b + off)))
    for k in range(sides):
        (a0, b0), (a1, b1) = ring[k], ring[(k + 1) % sides]
        bm.faces.new((a0, a1, b1, b0))


# ---- the pallet: three skids, a deck of boards on them
PAL = 1.4  # pallet height
H = CRATE / 2
for x in (-3.9, 0.0, 3.9):
    box("Crate_Trim", (x - 0.6, -H, 0), (x + 0.6, H, 0.9))
for k in range(5):
    y = -H + 0.9 + k * (CRATE - 1.8) / 4
    box("Crate_Trim", (-H, y - 0.8, 0.9), (H, y + 0.8, PAL))

# ---- the crate: a dark core, plank boards on each face standing out of it, steel bands on the edges
C = H - 0.35  # the core's half width
lo_z, hi_z = PAL, CRATE
box("Crate_Band", (-C, -C, lo_z + 0.05), (C, C, hi_z - 0.05))
BOARDS, GAP, T = 4, 0.16, 0.2  # boards a face, gap, how far they stand out
span = (hi_z - 0.7) - (lo_z + 0.7)
for k in range(BOARDS):
    z0 = lo_z + 0.7 + k * span / BOARDS + GAP / 2
    z1 = lo_z + 0.7 + (k + 1) * span / BOARDS - GAP / 2
    box("Crate", (-C + 0.6, -C - T, z0), (C - 0.6, -C, z1))
    box("Crate", (-C + 0.6, C, z0), (C - 0.6, C + T, z1))
    box("Crate", (-C - T, -C + 0.6, z0), (-C, C - 0.6, z1))
    box("Crate", (C, -C + 0.6, z0), (C + T, C - 0.6, z1))
for k in range(BOARDS):  # the lid: boards along X
    span_y = 2 * (C - 0.6)
    y0 = -C + 0.6 + k * span_y / BOARDS + GAP / 2
    y1 = -C + 0.6 + (k + 1) * span_y / BOARDS - GAP / 2
    box("Crate", (-C + 0.6, y0, hi_z - 0.05), (C - 0.6, y1, hi_z + T - 0.05))
# edge bands: twelve bars round the edges, a corner cap over each corner
E = H  # outer half width of the bands
W = 0.75  # band width on each face
for sx in (-1, 1):
    for sy in (-1, 1):
        x0, x1 = sorted((sx * (E - W), sx * E))
        y0, y1 = sorted((sy * (E - W), sy * E))
        box("Crate_Band", (x0, y0, lo_z), (x1, y1, hi_z + 0.15))
for sz, z in ((-1, lo_z), (1, hi_z + 0.15)):
    z0, z1 = sorted((z, z - sz * W))
    for s in (-1, 1):
        y0, y1 = sorted((s * (E - W), s * E))
        box("Crate_Band", (-E + W, y0, z0), (E - W, y1, z1))
        box("Crate_Band", (y0, -E + W, z0), (y1, E - W, z1))
K = 1.1  # corner cap size
for sx in (-1, 1):
    for sy in (-1, 1):
        for z in (lo_z, hi_z + 0.15):
            box("Crate_Band", (sx * (E + 0.12) - K / 2, sy * (E + 0.12) - K / 2, z - K / 2 + (0.3 if z == lo_z else -0.3)),
                (sx * (E + 0.12) + K / 2, sy * (E + 0.12) + K / 2, z + K / 2 + (0.3 if z == lo_z else -0.3)))

# straps: two khaki straps along Y, over the lid and down the front and back, a buckle on each
SW, ST = 0.8, 0.12  # strap width and thickness
top = hi_z + T + 0.05
for x in (-2.4, 2.4):
    box("Crate_Trim", (x - SW / 2, -C - T - ST, top - 0.1), (x + SW / 2, C + T + ST, top + ST))
    for s in (-1, 1):
        y0, y1 = sorted((s * (C + T), s * (C + T + ST)))
        box("Crate_Trim", (x - SW / 2, y0, lo_z + 0.1), (x + SW / 2, y1, top + ST))
        y0, y1 = sorted((s * (C + T + ST), s * (C + T + ST + 0.15)))
        box("Crate_Band", (x - SW / 2 - 0.1, y0, lo_z + 2.6), (x + SW / 2 + 0.1, y1, lo_z + 3.5))

# stencil panels on the two sides (X), a five-point star on each
PZ = (lo_z + hi_z) / 2
for s in (-1, 1):
    face = s * (C + T)
    x0, x1 = sorted((face, face + s * 0.06))
    box("Crate_Trim", (x0, -2.6, PZ - 2.6), (x1, 2.6, PZ + 2.6))
    fx = face + s * 0.1
    pts = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        r = 2.1 if k % 2 == 0 else 0.85
        pts.append(Vector((fx, -s * math.cos(a) * r, PZ + math.sin(a) * r)))
    bm = bms["Crate_Band"]
    centre = bm.verts.new((fx, 0, PZ))
    ring = [bm.verts.new(p) for p in pts]
    for k in range(10):
        bm.faces.new((centre, ring[k], ring[(k + 1) % 10]))

# ---- the canopy: GORES gores, alternating red and white, a dome with a billow in each gore and a scalloped rim
R = CHUTE / 2
ROWS, COLS = 7, 4  # rows rim to vent, columns across a gore
VENT = 0.12  # the vent hole's radius, as a share of R


def canopy(u, v):
    """A point on the canopy: u round (in gores), v from the rim (0) to the vent (1)."""
    a = u * math.pi * 2 / GORES
    f = u - math.floor(u)  # across the gore, 0..1
    bulge = math.sin(f * math.pi)  # 0 on the seams
    t = VENT + (1 - VENT) * (1 - v)  # radius share, 1 at the rim
    ang = math.acos(min(1.0, t))
    z = math.sin(ang) * LIFT * 0.92
    r = t * R * (1 + 0.05 * bulge)
    # the rim is scalloped: between the lines the cloth lifts and tucks in
    sc = bulge * max(0.0, 1 - v * 4)
    z += 1.3 * sc
    r -= 0.8 * sc
    return Vector((math.cos(a) * r, math.sin(a) * r, RIM + z))


for g in range(GORES):
    part = "Chute" if g % 2 == 0 else "Chute_Stripe"
    bm = bms[part]
    for inside in (False, True):
        grid = []
        for i in range(COLS + 1):
            col = []
            for j in range(ROWS + 1):
                p = canopy(g + i / COLS, j / ROWS)
                if inside:  # a hair under the outside, facing in
                    p = p - Vector((p.x, p.y, (p.z - RIM) * 0.3 + 2)).normalized() * 0.12
                col.append(bm.verts.new(p))
            grid.append(col)
        for i in range(COLS):
            for j in range(ROWS):
                f = (grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1])
                bm.faces.new(f if not inside else tuple(reversed(f)))
# a white cap over the vent
bm = bms["Chute_Stripe"]
cap_z = canopy(0, 1).z + 0.5
ring = [canopy(k * GORES / 16, 1) for k in range(16)]
for dz, flip in ((0.0, False), (-0.08, True)):  # top and underside
    centre = bm.verts.new((0, 0, cap_z + 0.4 + dz))
    vs = [bm.verts.new((p.x * 1.15, p.y * 1.15, cap_z + dz)) for p in ring]
    for k in range(16):
        f = (centre, vs[k], vs[(k + 1) % 16])
        bm.faces.new(tuple(reversed(f)) if flip else f)

# ---- suspension lines: one from each seam on the rim to the link, four risers from the link to the lid's corners
link = Vector((0, 0, LINK))
for g in range(GORES):
    rod("Chute_Lines", canopy(g, 0), link, 0.12)
for sx in (-1, 1):
    for sy in (-1, 1):
        rod("Chute_Lines", link, (sx * (E - 0.3), sy * (E - 0.3), hi_z + 0.15), 0.14)
box("Chute_Lines", (-0.35, -0.35, LINK - 0.35), (0.35, 0.35, LINK + 0.35))

# ---- the parts
parts = []
for name, rgb in LOOK.items():
    bm = bms[name]
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 0.6
    if name == "Crate_Band":
        b.inputs["Metallic"].default_value = 0.5
    me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    parts.append(o)


def bounds(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            lo = Vector(map(min, lo, v.co))
            hi = Vector(map(max, hi, v.co))
    return lo, hi


tris = 0
for o in parts:
    o.data.calc_loop_triangles()
    n = len(o.data.loop_triangles)
    tris += n
    l, h = bounds([o])
    print(f"PART {o.name:13s} {n:5d} tris  size {h.x - l.x:6.2f} x {h.y - l.y:6.2f} x {h.z - l.z:6.2f}")
    assert n <= 20000
print("TRIS", tris)
lo, hi = bounds(parts)
print(f"SIZE {hi.x - lo.x:.2f} x {hi.y - lo.y:.2f} x {hi.z - lo.z:.2f} studs")
assert tris < 6000

# ---- preview: one three-quarter view
if preview:
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.68, 0.75, 1)
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x, scene.render.resolution_y = 800, 600
    target = Vector((0, 0, (hi.z + lo.z) * 0.47))
    a, e = math.radians(-55), math.radians(14)
    cam.location = target + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e))) * 82
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", preview)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)

# ---- export, with a tiny Origin cube at 0 (the crate's bottom centre) so Roblox keeps positions relative to it
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=0.02)
me = bpy.data.meshes.new("Origin")
bm.to_mesh(me)
bm.free()
origin = bpy.data.objects.new("Origin", me)
scene.collection.objects.link(origin)
for o in bpy.data.objects:
    o.select_set(o in parts + [origin])
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                         global_scale=0.01, axis_forward="-Z", axis_up="Y", apply_unit_scale=True,
                         add_leaf_bones=False, bake_anim=False, path_mode="STRIP")
print("EXPORTED", out)
