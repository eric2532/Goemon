"""Author the original wall-mounted dragon fire tower and animated flame in Blender.

Run: Blender --background --python tools/build_defense_fire.py [-- --replace]
Godot coordinates are metres, Y up, -Z forward. Native source retains both
asset masters, a looping flame study, materials, lighting and a preview camera.
"""
import bpy
import bmesh
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/blender/defense/Fire_Defense.blend"
OUT = ROOT / "assets/models/defense"
PREVIEW = ROOT / "tests/defense-fire"
if SOURCE.exists() and "--replace" not in sys.argv:
    raise RuntimeError("Authored source exists; open Fire_Defense.blend, or pass --replace to regenerate.")
for path in (SOURCE.parent, OUT, PREVIEW):
    path.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 25


def cv(p):
    return Vector((p[0], -p[2], p[1]))


def linear(value):
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def material(name, color, metal=0.0, rough=.5, emission=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    rgb = tuple(linear(int(color[i:i+2], 16) / 255) for i in (0, 2, 4))
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, alpha)
    bs.inputs["Metallic"].default_value = metal
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Alpha"].default_value = alpha
    bs.inputs["Emission Color"].default_value = (*rgb, 1)
    bs.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        m.surface_render_method = "DITHERED"
    m.diffuse_color = (*rgb, alpha)
    return m


iron = material("Fire tower · indigo iron", "263e45", .75, .43)
bronze = material("Fire tower · aged warm bronze", "c4944f", .7, .35)
dark = material("Fire tower · mouth soot", "191e23", .35, .72)
ember = material("Fire tower · living ember eyes", "ff6b24", .05, .3, 3)
orange = material("Flame · saturated red orange envelope", "ff3f08", 0, .85, .70, .73)
core = material("Flame · warm amber core and sparks", "ffc04b", 0, .65, 1.20)


def collection(name):
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    return col


tower_col = collection("ASSET · Bronze Dragon Fire Tower")
stream_col = collection("ASSET · Animated Flame Stream")
studio_col = collection("STUDIO · Preview Only")


def relink(obj, col):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    col.objects.link(obj)


def finish(obj, name, mat, col=tower_col):
    obj.name = name
    obj.data.materials.append(mat)
    relink(obj, col)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def box(name, point, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=cv(point))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    return finish(obj, name, mat)


def beam(name, start, end, radius, mat, tip=None, sides=10):
    a, b = cv(start), cv(end)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius,
        radius2=radius if tip is None else tip, depth=(b-a).length, location=(a+b)*.5)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (b-a).to_track_quat("Z", "Y")
    return finish(obj, name, mat)


def ellipsoid(name, point, size, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=.5, location=cv(point))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    return finish(obj, name, mat)


def mesh_object(name, vertices, faces, mat, col=tower_col):
    mesh = bpy.data.meshes.new(name + " geometry")
    mesh.from_pydata([cv(v) for v in vertices], [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    mesh.materials.append(mat)
    return obj


def join_objects(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


# Squat octagonal pedestal and bronze dragon, distinguishable from long cannons.
beam("Octagonal anchored foot", (0, .03, 0), (0, .22, 0), 1.08, iron, sides=8)
beam("Bronze footing inset", (0, .22, 0), (0, .29, 0), .9, bronze, sides=8)
beam("Iron swivel column", (0, .29, 0), (0, .76, 0), .59, iron, .48, sides=8)
beam("Bronze neck collar", (0, .66, 0), (0, .82, 0), .68, bronze, sides=10)
for side in (-1, 1):
    for depth in (-1, 1):
        box("Anchoring bronze cleat", (side*.69, .29, depth*.55), (.23, .15, .27), bronze)
ellipsoid("Iron dragon skull", (0, 1.10, -.42), (1.56, 1.04, 1.70), iron)
ellipsoid("Bronze upper muzzle", (0, 1.28, -1.04), (1.02, .49, 1.05), bronze)
box("Open lower jaw", (0, .80, -1.12), (.95, .15, .92), bronze)
box("Soot-lined open jaw", (0, .92, -1.43), (.66, .31, .06), dark)

# Flattened octagonal nozzle has an actual open ring, rooted at z=-1.60.
vertices, faces = [], []
for depth, rx, ry in ((-1.37,.53,.31),(-1.60,.49,.27),(-1.60,.34,.16),(-1.31,.34,.16)):
    for i in range(10):
        angle = i * math.tau / 10
        vertices.append((math.cos(angle)*rx,1.10+math.sin(angle)*ry,depth))
for ring in range(3):
    for i in range(10):
        faces.append((ring*10+i,ring*10+(i+1)%10,(ring+1)*10+(i+1)%10,(ring+1)*10+i))
mesh_object("Hollow dragon breath nozzle",vertices,faces,bronze)
ellipsoid("Ember throat", (0,1.10,-1.36), (.53,.22,.09), ember)
for side in (-1,1):
    ellipsoid("Angular bronze cheek", (side*.67,1.08,-.26), (.40,.62,.97), bronze)
    beam("Swept dragon horn", (side*.57,1.45,.04), (side*.83,1.90,.38), .17, bronze, .02, sides=6)
    beam("Horn dark socket", (side*.53,1.37,.00), (side*.64,1.59,.13), .20, iron, .14, sides=6)
    ellipsoid("Molten dragon eye", (side*.56,1.37,-.82), (.25,.16,.24), ember)
    beam("Heavy slanted brow", (side*.31,1.54,-.97), (side*.76,1.41,-.62), .11, bronze, .06, sides=6)
    beam("Sculpted jaw fang", (side*.30,1.05,-1.48), (side*.31,.88,-1.49), .075, bronze, .018, sides=5)
    for index in range(3):
        z = -.06 + index*.27
        mesh_object("Dragon cheek flame ridge",[(side*.68,1.01,z-.17),(side*1.03,1.30,z+.06),(side*.68,1.33,z+.10),(side*.77,1.10,z+.14)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],bronze)
for z in (-.46,-.12,.22):
    beam("Raised spine crest", (0,1.47,z), (0,1.75,z+.16), .15, bronze, .01, sides=5)
tower = join_objects(list(tower_col.objects), "BronzeDragonFireTower")
tower["godot_nozzle_position"] = [0.0, 1.1, -1.6]
tower["godot_forward"] = "-Z"
tower["purpose"] = "Wall-mounted directional dragon fire defense; pedestal origin at mount."


# Three separately animated clusters create travelling licks instead of a cone.
# Each cluster contains warm translucent lobes, pale opaque cores and small sparks.
stream_root = bpy.data.objects.new("FireStream", None)
stream_col.objects.link(stream_root)
stream_root["nominal_length_metres"] = 6.0
stream_root["godot_forward"] = "-Z"
stream_root["loop_name"] = "flame_loop"
stream_root["loop_duration_seconds"] = .8


def lobe(name, start, length, width, phase, mat, core_ratio=1.0):
    verts, polys = [], []
    rings, sides = 8, 6
    for ring in range(rings):
        t = ring/(rings-1)
        d = start[2]+length*t
        cx = start[0] + math.sin(t*math.pi*1.55+phase)*width*.80*t
        cy = start[1] + .095*length*t + math.sin(t*math.pi*1.3)*width*.9
        radius = width*(.20+.91*math.sin(math.pi*t)**.7)*(1-t)**.32
        if ring == rings-1:
            radius = .008
        for side in range(sides):
            angle = side*math.tau/sides + t*1.0
            verts.append((cx+math.cos(angle)*radius*core_ratio,cy+math.sin(angle)*radius*.72*core_ratio,-d))
    for ring in range(rings-1):
        for side in range(sides):
            polys.append((ring*sides+side,ring*sides+(side+1)%sides,(ring+1)*sides+(side+1)%sides,(ring+1)*sides+side))
    polys.append(tuple(reversed(range(sides))))
    polys.append(tuple((rings-1)*sides+i for i in range(sides)))
    return mesh_object(name,verts,polys,mat,stream_col)


groups = []
patterns = [
    [((0,0,.0),3.1,.30,.3),((-.20,.17,2.55),3.40,.39,1.2)],
    [((-.10,-.025,.2),4.35,.28,2.5),((.26,.18,3.30),2.60,.35,.2)],
    [((.10,.015,.1),2.7,.24,4.1),((.12,.16,2.2),3.65,.37,3.7)],
]
for index, pattern in enumerate(patterns):
    objects = []
    for number,(start,length,width,phase) in enumerate(pattern):
        objects.append(lobe("Amber lick",start,length,width,phase,orange))
        objects.append(lobe("Pale moving core",start,length*.94,width,phase,core,.38))
    for spark in range(4):
        d = 2.25+spark*.93+index*.14
        x = math.sin(spark*2.8+index)*(.24+spark*.12)
        y = .3+spark*.15+math.cos(spark+index)*.12
        r = .035+spark*.01
        verts = [(x-r,y,-d),(x+r,y,-d),(x,y+r*1.6,-d),(x,y,-d-.23),(x,y-r,-d)]
        objects.append(mesh_object("Travelling ember",verts,[(0,1,2),(0,3,1),(0,2,3),(1,3,2),(0,4,1),(0,3,4),(1,4,3)],core,stream_col))
    obj = join_objects(objects, "FlameLick_%s" % "ABC"[index])
    obj.parent = stream_root
    groups.append(obj)
    obj.rotation_mode = "XYZ"
    for frame in (1,5,9,13,17,21,25):
        angle = (frame-1)/24*math.tau + index*math.tau/3
        obj.location = (math.sin(angle)*.035, math.sin(angle+.4)*.09, math.cos(angle)*.035)
        obj.scale = (1+math.sin(angle)*.15, 1+math.cos(angle)*.035, 1+math.sin(angle+.8)*.20)
        obj.rotation_euler = (.007*math.sin(angle+.4), .025*math.sin(angle), .014*math.cos(angle+.3))
        obj.keyframe_insert("location",frame=frame,group="Travelling flame")
        obj.keyframe_insert("scale",frame=frame,group="Travelling flame")
        obj.keyframe_insert("rotation_euler",frame=frame,group="Travelling flame")
    action = obj.animation_data.action
    action.name = "flame_loop_"+"ABC"[index]
    # NLA tracks with the same name merge into one glTF/Godot animation.
    track = obj.animation_data.nla_tracks.new()
    track.name = "flame_loop"
    track.strips.new(action.name,1,action)
    obj.animation_data.action = None


def triangle_count(obj):
    return sum(len(poly.vertices)-2 for poly in obj.data.polygons)


def export_asset(objects, filename, animated=False):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename), export_format="GLB",
        use_selection=True, export_yup=True, export_cameras=False, export_lights=False,
        export_animations=animated, export_animation_mode="NLA_TRACKS",
        export_force_sampling=True, export_frame_range=True, export_frame_step=1)


export_asset([tower],"fire_tower.glb")
export_asset([stream_root,*groups],"fire_stream.glb",True)
stream_root.location = cv((0,1.1,-1.6))

# Native file opens on an authored flame study, with camera/lighting kept editable.
stone = material("Studio · slate", "334147", .05,.95)
bpy.ops.mesh.primitive_cube_add(size=1,location=cv((0,-.20,0)))
floor=bpy.context.object
floor.scale=(18,18,.3)
finish(floor,"Preview plinth · not exported",stone,studio_col)
bpy.ops.object.camera_add(location=cv((10,6,-12)))
camera=bpy.context.object
camera.name="Preview Camera"
relink(camera,studio_col)
camera.rotation_euler=(cv((0,.7,-2.9))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO"
camera.data.ortho_scale=10
scene.camera=camera
for name,point,energy,size,color in [
    ("Warm key",(1,8,-5),1350,6,(1,.78,.55)),
    ("Cool fill",(-5,4,-1),1100,5,(.52,.73,1)),
    ("Bronze rim",(2,5,5),1500,4,(1,.50,.24))]:
    bpy.ops.object.light_add(type="AREA",location=cv(point))
    light=bpy.context.object
    light.name=name
    relink(light,studio_col)
    light.data.energy=energy
    light.data.shape="DISK"
    light.data.size=size
    light.data.color=color
    light.rotation_euler=(cv((0,1,-1))-light.location).to_track_quat("-Z","Y").to_euler()
scene.world.color=(.12,.16,.19)
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.render.resolution_x=1400
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.view_settings.view_transform="AgX"
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(PREVIEW/"blender-preview.png")
scene.frame_set(8)
scene["authoring_notes"]="Original Blender-authored Edo bronze dragon flamethrower; glTF flame_loop NLA animation uses offset, rotation and scale. Godot -Z forward. Studio excluded from asset exports."
scene["tower_nozzle_godot"]=[0.0,1.1,-1.6]
scene["stream_nominal_length_metres"]=6.0
scene["stream_nominal_end_width_metres"]=1.5
scene["animation_loop"]="flame_loop · frames 1—25 · 30 FPS · 0.8 seconds"
bpy.ops.object.select_all(action="DESELECT")
tower.select_set(True)
bpy.context.view_layer.objects.active=tower
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
metadata={
    "tower":{"file":"assets/models/defense/fire_tower.glb","triangles":triangle_count(tower),"meshes":1,"surfaces":len(tower.data.materials),"nozzle_godot":[0,1.1,-1.6]},
    "stream":{"file":"assets/models/defense/fire_stream.glb","triangles":sum(triangle_count(o) for o in groups),"meshes":len(groups),"surfaces":sum(len(o.data.materials) for o in groups),"length":6,"animation":"flame_loop","duration":.8},
    "source":"assets/blender/defense/Fire_Defense.blend","forward":"Godot -Z"}
(PREVIEW/"asset-metadata.json").write_text(json.dumps(metadata,indent=2)+"\n")
assert metadata["tower"]["triangles"]<4000
assert metadata["stream"]["triangles"]<2000
assert metadata["stream"]["surfaces"]<=6
print("DEFENSE_FIRE_EXPORT",json.dumps(metadata))
bpy.ops.render.render(write_still=True)
