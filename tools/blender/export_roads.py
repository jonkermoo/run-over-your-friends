# Turn the road meshes (tools/roads/build_roads.py: meshes.json, Roblox studs) into one FBX for Roblox, and
# optionally render a textured preview of one spot.
#   blender -b --factory-startup --python export_roads.py -- <meshes.json> <out.fbx> [<tex_dir> <preview.png> x z]
# Roblox (x, y, z) = Blender (-x, z, y). Every object sits at the origin with its vertices round its own box
# centre; the game sets each MeshPart's Size and CFrame from Config/RoadMeshes, so the import scale doesn't
# matter. Vertices are in studs / 20 so the biggest chunk stays far under Roblox's 2,048-stud import limit.
import bpy, json, sys, math

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
preview = args[2:] if len(args) > 2 else None
K = 1 / 20.0

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

data = json.load(open(src))["meshes"]
objs = []
for m in data:
    verts = [(-x * K, z * K, y * K) for x, y, z in m["verts"]]
    me = bpy.data.meshes.new(m["name"])
    me.from_pydata(verts, [], [tuple(f) for f in m["faces"]])
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uv.data[li].uv = m["uvs"][vi]
    me.validate()
    ob = bpy.data.objects.new(m["name"], me)
    bpy.context.scene.collection.objects.link(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    assert tris <= 20000, f"{m['name']} {tris}"
    span = max(m["size"]) * 47.344 * K
    assert span < 1900, f"{m['name']} would import {span} studs"
    objs.append((ob, m))

bpy.ops.export_scene.fbx(filepath=out, use_selection=False, object_types={"MESH"}, mesh_smooth_type="FACE",
                         add_leaf_bones=False, bake_anim=False, path_mode="STRIP")
print("EXPORTED", out, len(objs))

if preview:
    tex, png, px, pz = preview[0], preview[1], float(preview[2]), float(preview[3])
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 1400, 800
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.7, 0.2, 0.8)
    sc.collection.objects.link(sun)
    mats = {}
    for layer, img in (("Asphalt", "asphalt.png"), ("Concrete", "concrete.png"), ("Trim", "trim.png")):
        mat = bpy.data.materials.new(layer)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.9
        ti = nt.nodes.new("ShaderNodeTexImage")
        ti.image = bpy.data.images.load(f"{tex}/{img}")
        nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
        if layer == "Trim":
            nt.links.new(ti.outputs["Alpha"], bsdf.inputs["Alpha"])
        mats[layer] = mat
    # grass under it all, at terrain height
    bpy.ops.mesh.primitive_plane_add(size=2000 * K, location=(-px * K, pz * K, -0.19 * K))
    g = bpy.context.object
    gm = bpy.data.materials.new("Grass")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.3, 0.08, 1)
    g.data.materials.append(gm)
    for ob, m in objs:
        c = m["centre"]
        if abs(c[0] - px) > 700 or abs(c[2] - pz) > 700:
            ob.hide_render = True
            continue
        ob.location = (-c[0] * K, c[2] * K, c[1] * K)
        ob.data.materials.append(mats[m["layer"]])
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 24
    cam.location = (-(px + 60) * K, (pz + 75) * K, 38 * K)
    sc.collection.objects.link(cam)
    con = cam.constraints.new("TRACK_TO")
    tgt = bpy.data.objects.new("T", None)
    tgt.location = (-px * K, pz * K, 0)
    sc.collection.objects.link(tgt)
    con.target = tgt
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    sc.camera = cam
    sc.render.filepath = png
    bpy.ops.render.render(write_still=True)
