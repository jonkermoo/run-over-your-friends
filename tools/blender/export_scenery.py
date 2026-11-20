# Build the scenery meshes (each one MeshPart in game, one colour) and export them in one FBX for Roblox.
# blender -b --factory-startup --python export_scenery.py -- <out.fbx> [preview.png]
# Meshes (Blender units; the game sets each MeshPart's Size, so only the shape matters):
#   Crown      a tree's crown: a main ball, two side lumps and a top lump in one mesh (Greenery.tree)
#   Blooms     a row of flower heads for a flower bed, 10 x 4 footprint (Greenery.flowerBed)
#   Belt       a long strip of tree crowns on trunks for the woods round the map's edge (OutskirtsKit)
#   Pine       a conifer: trunk and three stacked cones (forests)
# Roblox (x, y, z) = Blender (-x, z, y); the shapes are symmetric enough that only up matters.
import bpy, bmesh, sys, math, random
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
preview = args[1] if len(args) > 1 else None
rng = random.Random(20261110)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)


def ico(bm, centre, radius, subdiv=3, squash=1.0):
    m = Matrix.Translation(Vector(centre)) @ Matrix.Diagonal((radius, radius, radius * squash, 1))
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0, matrix=m)


def cone(bm, base, radius, height, segs=10):
    m = Matrix.Translation(Vector(base) + Vector((0, 0, height / 2)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=0.0, depth=height, matrix=m)


def cyl(bm, base, radius, height, segs=8):
    m = Matrix.Translation(Vector(base) + Vector((0, 0, height / 2)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=height, matrix=m)


def finish(name, bm, x_offset, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (x_offset, 0, 0)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(f"{name}: {tris} tris")
    assert tris < 20000
    return ob


# Crown: main ball 1 across at the origin; Greenery.tree places lumps at 0.4 out, 0.1/0.2 down (size 0.65)
# and a top lump 0.52 across 0.38 up, all as shares of the main ball's size
bm = bmesh.new()
ico(bm, (0, 0, 0), 0.5)
ico(bm, (0.4, 0, -0.1), 0.325)
ico(bm, (-0.4, 0, -0.2), 0.325)
ico(bm, (0, 0, 0.38), 0.26)
finish("Crown", bm, 0)

# Blooms: two staggered rows of small heads across a 10 x 4 bed, sitting just above the soil
bm = bmesh.new()
for row, y in ((0, -0.7), (1, 0.7)):
    for k in range(7):
        x = -5 + (k + 0.5 + row * 0.5) * 10 / 7.5
        ico(bm, (x, y + rng.uniform(-0.3, 0.3), rng.uniform(0.5, 0.9)), rng.uniform(0.55, 0.75), subdiv=2)
finish("Blooms", bm, 4)

# Belt: 200 long, crowns 18-34 across on short trunks, two staggered rows, up to ~40 tall
bm = bmesh.new()
x = -100.0
while x < 100:
    for row in (-1, 1):
        r = rng.uniform(9, 17)
        h = rng.uniform(6, 12)
        cx = x + rng.uniform(-3, 3)
        cy = row * rng.uniform(4, 10)
        cyl(bm, (cx, cy, 0), 1.2, h + r * 0.5, segs=6)
        ico(bm, (cx, cy, h + r * 0.6), r, subdiv=2, squash=1.1)
    x += rng.uniform(14, 20)
# faceted like the low-poly set below: each vertex pushed in or out a little (its own stream, so the layout
# of the strip above stays the same), drawn flat
facet = random.Random(7)
for v in bm.verts:
    if v.co.z > 4:
        v.co += Vector((facet.uniform(-0.9, 0.9), facet.uniform(-0.9, 0.9), facet.uniform(-0.9, 0.9)))
finish("Belt", bm, 12, smooth=False)

# Pine: 1 tall (trunk to tip), three cones
bm = bmesh.new()
cyl(bm, (0, 0, 0), 0.035, 0.25, segs=6)
cone(bm, (0, 0, 0.15), 0.28, 0.4)
cone(bm, (0, 0, 0.38), 0.22, 0.35)
cone(bm, (0, 0, 0.6), 0.15, 0.4)
finish("Pine", bm, 16, smooth=False)

# ---- the chunky low-poly set (map redo, greenery): faceted, flat-shaded shapes. Their own random stream, so
# the meshes above keep their exact shapes. Every new mesh is about 1 tall or 1 across; the game scales it.
lp = random.Random(20261120)


def lump(bm, centre, radius, squash=1.0, jitter=0.12, subdiv=1):
    """A faceted lump: an icosphere with its vertices pushed in and out a little."""
    m = Matrix.Translation(Vector(centre)) @ Matrix.Diagonal((radius, radius, radius * squash, 1))
    geom = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0, matrix=m)
    for v in geom["verts"]:
        d = v.co - Vector(centre)
        v.co = Vector(centre) + d * (1 + lp.uniform(-jitter, jitter))


def blade(bm, base, height, width, lean, turn):
    """A thin three-sided spike leaning out (a grass blade, a palm frond rib): solid, so seen from both sides."""
    bx, by, bz = base
    tip = Vector((bx + math.cos(turn) * lean, by + math.sin(turn) * lean, bz + height))
    w = width / 2
    a = Vector((bx + math.cos(turn + 1.57) * w, by + math.sin(turn + 1.57) * w, bz))
    b = Vector((bx + math.cos(turn - 1.57) * w, by + math.sin(turn - 1.57) * w, bz))
    c = Vector((bx - math.cos(turn) * w * 0.6, by - math.sin(turn) * w * 0.6, bz))
    vs = [bm.verts.new(p) for p in (a, b, c, tip)]
    for f in ((vs[0], vs[1], vs[3]), (vs[1], vs[2], vs[3]), (vs[2], vs[0], vs[3]), (vs[0], vs[2], vs[1])):
        bm.faces.new(f)


def anchors(bm, lo, hi):
    """Two specks at opposite corners: meshes that are placed together (a tuft and its flowers, a palm's trunk
    and leaves) get the same box, so the game puts both at the same CFrame and size."""
    for c in (lo, hi):
        m = Matrix.Translation(Vector(c))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.004, radius2=0.0, depth=0.004, matrix=m)


TUFT_BOX = ((-0.45, -0.45, 0.0), (0.45, 0.45, 1.05))
PALM_BOX = ((-0.45, -0.45, 0.0), (0.6, 0.45, 1.12))

# CrownA/B/C: three tree crowns, 1 across at their widest, bottom at z 0 (the game sits the crown on the trunk)
for name, lumps in (
    ("CrownA", [((0, 0, 0.45), 0.42, 0.95), ((0.28, 0.1, 0.32), 0.28, 0.9), ((-0.26, -0.12, 0.3), 0.27, 0.9), ((0.02, 0.05, 0.72), 0.24, 0.9)]),
    ("CrownB", [((0, 0, 0.5), 0.4, 1.25), ((0.2, -0.18, 0.3), 0.25, 1.0), ((-0.18, 0.2, 0.32), 0.24, 1.0)]),
    ("CrownC", [((0, 0, 0.32), 0.48, 0.65), ((0.3, 0.15, 0.25), 0.25, 0.7), ((-0.3, -0.12, 0.24), 0.24, 0.7), ((0.05, -0.28, 0.28), 0.22, 0.7), ((0, 0.05, 0.5), 0.3, 0.7)]),
):
    bm = bmesh.new()
    for c, r, sq in lumps:
        lump(bm, c, r, squash=sq, jitter=0.08, subdiv=2)
    finish(name, bm, 20 + len(name), smooth=False)

# BushA/B: low faceted bushes, 1 across
for name, lumps in (
    ("BushA", [((0, 0, 0.28), 0.4, 0.75), ((0.3, 0.05, 0.2), 0.24, 0.8), ((-0.28, -0.08, 0.18), 0.22, 0.8)]),
    ("BushB", [((0, 0, 0.22), 0.34, 0.7), ((0.22, 0.2, 0.2), 0.26, 0.8), ((-0.2, 0.18, 0.18), 0.22, 0.8), ((0.05, -0.25, 0.17), 0.2, 0.8)]),
):
    bm = bmesh.new()
    for c, r, sq in lumps:
        lump(bm, c, r, squash=sq, jitter=0.08, subdiv=2)
    finish(name, bm, 30, smooth=False)

# Tuft: a clump of grass blades, 1 tall
bm = bmesh.new()
for k in range(9):
    a = lp.uniform(0, math.pi * 2)
    d = lp.uniform(0, 0.12)
    blade(bm, (math.cos(a) * d, math.sin(a) * d, 0), lp.uniform(0.6, 1.0), 0.09, lp.uniform(0.15, 0.35), a)
anchors(bm, *TUFT_BOX)
finish("Tuft", bm, 34, smooth=False)

# Petals: flower heads for a Tuft (same 1-tall frame): a few small faceted heads at blade tips
bm = bmesh.new()
for k in range(5):
    a = lp.uniform(0, math.pi * 2)
    d = lp.uniform(0.1, 0.3)
    lump(bm, (math.cos(a) * d, math.sin(a) * d, lp.uniform(0.55, 0.85)), 0.08, squash=0.7, jitter=0.05, subdiv=1)
anchors(bm, *TUFT_BOX)
finish("Petals", bm, 36, smooth=False)

# RockA/B/C: faceted rocks, 1 across, half their height below z 0.3 so they sit sunk
for name, sq in (("RockA", 0.6), ("RockB", 0.8), ("RockC", 0.45)):
    bm = bmesh.new()
    lump(bm, (0, 0, 0.25), 0.5, squash=sq, jitter=0.22, subdiv=1)
    finish(name, bm, 38, smooth=False)

# PalmTrunk: a gently bent trunk 1 tall, in ringed sections; PalmLeaves: drooping fronds round its top
bm = bmesh.new()
segs = 6
for k in range(segs):
    t0, t1 = k / segs, (k + 1) / segs
    x0, x1 = 0.12 * t0 * t0, 0.12 * t1 * t1
    m = Matrix.Translation(Vector(((x0 + x1) / 2, 0, (t0 + t1) / 2)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.045 - 0.012 * t0, radius2=0.04 - 0.012 * t1, depth=1 / segs * 1.02, matrix=m)
anchors(bm, *PALM_BOX)
finish("PalmTrunk", bm, 42, smooth=False)
bm = bmesh.new()
for k in range(8):
    a = k / 8 * math.pi * 2 + lp.uniform(-0.2, 0.2)
    # each frond: a flat leaf drooping from the crown: a long thin diamond bent down in two pieces
    top = Vector((0.12, 0, 1.0))
    mid = top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.06))
    end = top + Vector((math.cos(a) * 0.42, math.sin(a) * 0.42, -0.14))
    side = Vector((-math.sin(a), math.cos(a), 0)) * 0.07
    pts = [top, mid + side, end, mid - side]
    up = Vector((0, 0, 0.012))
    vs = [bm.verts.new(p) for p in pts] + [bm.verts.new(p + up) for p in pts]
    bm.faces.new((vs[0], vs[1], vs[2], vs[3]))
    bm.faces.new((vs[7], vs[6], vs[5], vs[4]))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((vs[i], vs[4 + i], vs[4 + j], vs[j]))
lump(bm, (0.12, 0, 0.98), 0.07, squash=0.8, jitter=0.05)
anchors(bm, *PALM_BOX)
finish("PalmLeaves", bm, 44, smooth=False)

# CropRows: a 1 x 1 tile of six low ridged crop rows (along x), 0.12 tall, flat bottom at z 0
bm = bmesh.new()
for k in range(6):
    y = -0.5 + (k + 0.5) / 6
    for seg in range(4):
        x0 = -0.5 + seg / 4
        m = Matrix.Translation(Vector((x0 + 0.125, y, 0.06))) @ Matrix.Diagonal((0.125, 0.05, 0.06, 1))
        geom = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0, matrix=m)
        for v in geom["verts"]:
            v.co.z = max(v.co.z, 0.0) + lp.uniform(0, 0.02) * (1 if v.co.z > 0.05 else 0)
finish("CropRows", bm, 46, smooth=False)

bpy.ops.export_scene.fbx(
    filepath=out,
    use_selection=False,
    global_scale=0.01,
    apply_unit_scale=True,
    object_types={"MESH"},
    use_mesh_modifiers=True,
    mesh_smooth_type="FACE",  # per-face smoothing flags: balls smooth (like the old Ball parts), pines flat
    add_leaf_bones=False,
)
print("wrote", out)

if preview:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.render.resolution_x, sc.render.resolution_y = 1200, 500
    world = bpy.data.worlds.new("W")
    world.color = (0.6, 0.7, 0.8)
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.rotation_euler = (0.8, 0.2, 0.6)
    sc.collection.objects.link(sun)
    mat = bpy.data.materials.new("G")
    mat.diffuse_color = (0.25, 0.5, 0.25, 1)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.45, 0.2, 1)
    # show each at a viewable size side by side (preview copies, not exported)
    for name, s, at in (
        ("Crown", 6, -30), ("Blooms", 1.2, -15), ("Belt", 0.25, 5), ("Pine", 14, 35),
        ("CrownA", 10, -45), ("CrownB", 10, -33), ("CrownC", 10, -21), ("BushA", 6, -10), ("BushB", 6, -3),
        ("Tuft", 4, 3), ("Petals", 4, 3), ("RockA", 5, 9), ("RockB", 5, 15), ("RockC", 5, 21),
        ("PalmTrunk", 14, 28), ("PalmLeaves", 14, 28), ("CropRows", 8, 42),
    ):
        src = bpy.data.objects[name]
        c = src.copy()
        c.data = src.data
        c.location = (at, 0 if name in ("Crown", "Blooms", "Belt", "Pine") else -28, 0)
        c.scale = (s, s, s)
        c.data.materials.append(mat)
        sc.collection.objects.link(c)
        src.hide_render = True
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.location = (0, -70, 18)
    cam.rotation_euler = (math.radians(80), 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.filepath = preview
    bpy.ops.render.render(write_still=True)
