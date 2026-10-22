"""Read-only saved-file checks; deliberately never saves a Blender file."""
from pathlib import Path
import bpy, hashlib, json, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT / 'assets/blender/characters/goemon_cosplay/samurai.blend'
TARGET = OUT / 'Samurai_Weapon_Workbench.blend'
BODY = ['Skin', 'Hair_Normal', 'Costume_samurai', 'ScarfTail_Geometry']

def digest(ob):
    data = {
        'vertices': [list(v.co) for v in ob.data.vertices],
        'faces': [list(p.vertices) for p in ob.data.polygons],
        'uvs': [[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
        'groups': [[(g.group, g.weight) for g in v.groups] for v in ob.data.vertices],
    }
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()

def bones():
    return {b.name: [list(row) for row in b.matrix_local]
            for b in bpy.data.objects['Reference_Rig'].data.bones}

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
original_body = {n: digest(bpy.data.objects[n]) for n in BODY}
original_bones = bones()
bpy.ops.wm.open_mainfile(filepath=str(TARGET))
assert original_body == {n: digest(bpy.data.objects[n]) for n in BODY}
assert original_bones == bones()
blade = bpy.data.objects['Katana_Blade — enlarged maroon steel']
assert math.isclose(max(v.co.z for v in blade.data.vertices), 1.6980989620685578, abs_tol=1e-6)
assert blade['blade_length_multiplier'] == 1.55
sheath = bpy.data.objects['Sheath_MATCHED_SIZE — fitted to enlarged katana']
design = bpy.data.objects['Katana_Design — grip origin + original blade axis']
assert sheath.parent is None
shell = bpy.data.objects['Sheath_Shell — fitted katana profile']
# Close only the mouth in a temporary BVH to verify the real inner sleeve.
verts = [v.co.copy() for v in shell.data.vertices]
faces = [list(p.vertices) for p in shell.data.polygons]+[list(reversed(range(12)))]
inner = BVHTree.FromPolygons(verts, faces)
points = [v.co.copy() for v in blade.data.vertices]
points += [(blade.data.vertices[e.vertices[0]].co+blade.data.vertices[e.vertices[1]].co)/2 for e in blade.data.edges]
minimum_clearance = float('inf')
for p in points:
    native = shell.matrix_local.inverted() @ design.matrix_local @ p
    nearest, normal, index, distance = inner.find_nearest(native)
    assert normal.dot(native-nearest) < -.005, 'Blade intersects scabbard or lacks clearance'
    minimum_clearance = min(minimum_clearance, distance)
assert sheath['internal_tip_clearance'] >= .04
def sheath_world():
    bpy.context.view_layer.update()
    return [[list(ob.matrix_world @ v.co) for v in ob.data.vertices]
            for ob in sorted(sheath.children, key=lambda o:o.name)]
before = sheath_world()
design.scale *= 2
assert before == sheath_world(), 'Sheath changed when katana was enlarged'
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
assert all(math.isfinite(c) for ob in meshes for v in ob.data.vertices for c in v.co)
assert bpy.data.images['REFERENCE — user katana (maroon adaptation)'].packed_file
assert len(bpy.data.scenes) == 2
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert source_hash == 'f6404fcbc1b49d4de36edb81f9a79a8640c9764e1a46fef44d428e23fab59bfa'
report = {
    'saved_blend_opens': True,
    'body_geometry_uvs_weights_unchanged': True,
    'rest_skeleton_unchanged': True,
    'katana_blade_length_multiplier': 1.55,
    'sheath_unchanged_when_katana_scale_doubled': True,
    'blade_vertices_and_edge_midpoints_inside_scabbard': True,
    'minimum_internal_clearance': minimum_clearance,
    'finite_mesh_coordinates': True,
    'reference_packed': True,
    'original_blend_sha256': source_hash,
    'scenes': list(bpy.data.scenes.keys()),
}
(OUT / 'saved-file-verification.json').write_text(json.dumps(report, indent=2))
print('SAVED_FILE_VERIFIED', json.dumps(report), flush=True)
