"""Initial Aoi authoring only; subsequent edits belong in the saved .blend."""
import hashlib
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/blender/characters/aoi/aoi.blend'
SOURCES = [ROOT / 'assets/blender/characters/kai.blend',
           ROOT / 'assets/blender/characters/ren_rival.blend']
before = [hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES]
assert not OUT.exists(), 'Use the saved master; initial creation must not overwrite artist edits'
bpy.ops.wm.open_mainfile(filepath=str(SOURCES[0]))
rig = bpy.data.objects['Reference_Rig']
body = bpy.data.objects['Skin']
rests = [b.matrix_local.copy() for b in rig.data.bones]
weights = [[(g.group, g.weight) for g in v.groups] for v in body.data.vertices]
for ob in list(bpy.data.objects):
    if ob not in [rig, body]:
        bpy.data.objects.remove(ob, do_unlink=True)
with bpy.data.libraries.load(str(SOURCES[1]), link=False) as (src, dst):
    dst.objects = ['Hair_Normal']
hair = dst.objects[0]
bpy.context.scene.collection.objects.link(hair)
hair.parent = rig
for modifier in hair.modifiers:
    if modifier.type == 'ARMATURE':
        modifier.object = rig
for vertex in hair.data.vertices:
    vertex.co.x *= .87
    vertex.co.z = 2.35 + (vertex.co.z - 2.35) * .82

# Cross Gate's compact head is smaller than the historical Goemon reference.
pivot = Vector((0, 0, 1.54))
head_index = body.vertex_groups['Head'].index
head = [v for v in body.data.vertices if any(g.group == head_index and g.weight > .5 for g in v.groups)]
for vertex in head + list(hair.data.vertices):
    delta = vertex.co - pivot
    vertex.co = pivot + Vector((delta.x * .72, delta.y * .72, delta.z * .55))
body.data.update()


def material(name, color):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    mat = bpy.data.materials.new('Aoi_' + name)
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*linear, 1)
    bsdf.inputs['Roughness'].default_value = 1
    bsdf.inputs['Specular IOR Level'].default_value = .08
    return mat


red = material('vermilion', 'bb3930')
gold = material('ochre_trim', 'e9ac40')
cream = material('ivory_wraps', 'eee1c1')
indigo = material('sash', '45344d')
leather = material('leather', '654632')
blue = material('cobalt_straps', '334ca1')
wood = material('pipe_wood', '573522')
skin = material('skin', 'f4c990')
for mat in [red, gold, cream, indigo, leather, blue, skin]:
    body.data.materials.append(mat)
slots = {mat.name: i for i, mat in enumerate(body.data.materials)}
for polygon in body.data.polygons:
    group_names = {body.vertex_groups[g.group].name for i in polygon.vertices
                   for g in body.data.vertices[i].groups if g.weight > .3}
    if all(i < 33 for i in polygon.vertices):
        continue
    chosen = red
    if any(n.startswith(('Hand_', 'Neck')) for n in group_names):
        chosen = skin
    elif any(n.startswith('Foot_') for n in group_names):
        chosen = leather
    elif any(n.startswith(('Forearm_', 'Shin_')) for n in group_names):
        chosen = cream
    elif 'Sash' in group_names:
        chosen = indigo
    polygon.material_index = slots[chosen.name]
    polygon.use_smooth = True

face_path = ROOT / 'assets/references/aoi/face.png'
assert face_path.exists(), 'Prepare the original painted face before building'
face = material('painted_face', 'ffffff')
texture = face.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(face_path))
texture.image.pack()
face.node_tree.links.new(texture.outputs['Color'], face.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
body.data.materials.append(face)
for polygon in body.data.polygons:
    if all(i < 33 for i in polygon.vertices):
        if polygon.center.y > .04:
            polygon.material_index = len(body.data.materials) - 1
            for li in polygon.loop_indices:
                p = body.data.vertices[body.data.loops[li].vertex_index].co
                body.data.uv_layers.active.data[li].uv = (.5 + p.x / (.72 * 1.32), .5 + ((p.z - 1.54) / .55 + 1.54 - 1.99) / 1.22)
        else:
            polygon.material_index = slots[skin.name]


def mesh(name, points, faces, mat, bone):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = rig
    data.materials.append(mat)
    data.uv_layers.new(name='UVMap')
    group = ob.vertex_groups.new(name=bone)
    group.add(list(range(len(points))), 1, 'REPLACE')
    modifier = ob.modifiers.new('Shared Goemon rig', 'ARMATURE')
    modifier.object = rig
    for polygon in data.polygons:
        polygon.use_smooth = True
    return ob


def tube(name, start, end, radius, mat, bone, segments=12):
    a, b = Vector(start), Vector(end)
    axis = (b - a).normalized()
    u = axis.cross(Vector((0, 0, 1)))
    if u.length < .01:
        u = axis.cross(Vector((0, 1, 0)))
    u.normalize()
    v = axis.cross(u).normalized()
    points = [tuple(p + radius * (math.cos(i * math.tau / segments) * u +
                                  math.sin(i * math.tau / segments) * v))
              for p in [a, b] for i in range(segments)]
    faces = [(i, (i + 1) % segments, (i + 1) % segments + segments, i + segments)
             for i in range(segments)]
    faces += [tuple(reversed(range(segments))), tuple(range(segments, 2 * segments))]
    return mesh(name, points, faces, mat, bone)


# Fit the collar and waist to the existing torso instead of rebuilding the body.
def band(name, heights, radii, mat, bone):
    n = 24
    points = [(rx * math.sin(i * math.tau / n), .025 + ry * math.cos(i * math.tau / n), z)
              for z, (rx, ry) in zip(heights, radii) for i in range(n)]
    faces = [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, points, faces, mat, bone)


band('Jacket_hem', [1.02, 1.08], [(.407, .40), (.415, .41)], gold, 'Pelvis')
band('Waist_sash', [1.04, 1.15], [(.427, .423), (.434, .429)], indigo, 'Pelvis')
band('Collar', [1.42, 1.53], [(.29, .28), (.26, .26)], gold, 'Neck')
mesh('Crossed_gold_lapel', [(-.26, .37, 1.48), (-.16, .405, 1.49), (.25, .435, 1.12),
                           (.13, .452, 1.12)], [(0, 1, 2, 3)], gold, 'Chest')
mesh('Inner_gold_lapel', [(.22, .39, 1.48), (.29, .37, 1.44), (.015, .46, 1.27),
                         (-.035, .452, 1.32)], [(0, 1, 2, 3)], gold, 'Chest')
for side, sign in [('L', -1), ('R', 1)]:
    tube('Sleeve_gold_' + side, (sign * .73, 0, 1.305), (sign * .79, 0, 1.305), .172, gold, 'Arm_' + side)
    for i in range(3):
        z = .245 + i * .07
        tube('Shin_wrap_' + side + str(i), (sign * .31, 0, z), (sign * .31, 0, z + .035),
             .12 - i * .008, cream, 'Shin_' + side)
    tube('Shoe_strap_' + side, (sign * .315 - .145, .17, .18),
         (sign * .315 + .145, .17, .18), .05, blue, 'Foot_' + side)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(.37, .43, 1.0), scale=(.15, .10, .19))
pouch = bpy.context.object
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
pouch.name = 'Coin_pouch'
pouch.data.materials.append(gold)
group = pouch.vertex_groups.new(name='Pelvis')
group.add(list(range(len(pouch.data.vertices))), 1, 'REPLACE')
world = pouch.matrix_world.copy()
pouch.parent = rig
pouch.matrix_world = world
modifier = pouch.modifiers.new('Shared Goemon rig', 'ARMATURE')
modifier.object = rig

# The length changes along the shaft only; bowl, grip and thickness stay useful.
grip = Vector((1.22, .02, 1.305))
short_length = .95
length = short_length * 4
start = grip + Vector((0, -.20, 0))
end = start + Vector((0, length, 0))
tube('Pipe_shaft', start, end, .052, wood, 'Hand_R')
for y in [-.20, -.02, .18, length - .22]:
    tube('Pipe_brass_band', grip + Vector((0, y, 0)), grip + Vector((0, y + .075, 0)),
         .069, gold, 'Hand_R')
center = end + Vector((0, 0, .02))
n = 16
points = [(center.x + r * math.cos(i * math.tau / n),
           center.y + r * math.sin(i * math.tau / n), center.z + z)
          for r, z in [(.11, -.08), (.17, .12), (.145, .12), (.09, -.01)] for i in range(n)]
faces = [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
         for j in range(3) for i in range(n)]
mesh('Pipe_bowl', points, faces, gold, 'Hand_R')

scene = bpy.context.scene
scene['design'] = 'Original Cross Gate-style pipe adventurer; blue hair, red jacket, gold trim, ivory wraps'
scene['concept_pipe_length'] = short_length
scene['pipe_length'] = length
scene['pipe_length_multiplier'] = 4.0
scene['source_master_hashes'] = str(dict(zip(map(str, SOURCES), before)))
scene['runtime'] = 'Offline sprites only; shared Cross Gate model and combat'
assert all(a == b.matrix_local for a, b in zip(rests, rig.data.bones))
assert weights == [[(g.group, g.weight) for g in v.groups] for v in body.data.vertices]
assert len(rig.data.bones) == 22
assert all(abs(sum(g.weight for g in v.groups) - 1) < .001
           for ob in scene.objects if ob.type == 'MESH' for v in ob.data.vertices)
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = bpy.data.actions['Idle']
scene.frame_set(0)
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
assert before == [hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES]
print('AOI_MASTER_SAVED', OUT)
