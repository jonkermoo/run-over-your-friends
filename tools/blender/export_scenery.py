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
finish("Belt", bm, 12)

# Pine: 1 tall (trunk to tip), three cones
bm = bmesh.new()
cyl(bm, (0, 0, 0), 0.035, 0.25, segs=6)
cone(bm, (0, 0, 0.15), 0.28, 0.4)
cone(bm, (0, 0, 0.38), 0.22, 0.35)
cone(bm, (0, 0, 0.6), 0.15, 0.4)
finish("Pine", bm, 16, smooth=False)

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
    for name, s, at in (("Crown", 6, -30), ("Blooms", 1.2, -15), ("Belt", 0.25, 5), ("Pine", 14, 35)):
        src = bpy.data.objects[name]
        c = src.copy()
        c.data = src.data
        c.location = (at, 0, 0)
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
