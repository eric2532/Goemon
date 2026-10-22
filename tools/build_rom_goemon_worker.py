"""Fit an editable worker and pickaxe to the approved ROM Blender master."""
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_rom_goemon_base import native
from rom_goemon_blender_materials import math_node
from rom_goemon_thief_palette import linear_hex

DEST = ROOT / 'assets/blender/characters/rom_goemon_base'
SOURCE = DEST / 'goemon.blend'
TARGET = DEST / 'worker.blend'
if TARGET.exists() and '--rebuild-generated' not in sys.argv:
    raise RuntimeError('Do not regenerate over editable worker poses.')
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version = 0
rig = bpy.data.objects['ROM_Goemon_Rig']
motion = json.loads((ROOT / 'assets/characters/recovered_goemon/motion.json').read_text())
manifest = json.loads((DEST / 'manifest.json').read_text())
scale = manifest['source_scale']
idle = motion['clips'][motion['actions']['0']]
rest = dict(zip(idle['pointers'], map(native, idle['frames'][0])))
body = json.loads((ROOT / 'assets/characters/recovered_goemon/body/body.json').read_text())
points = [rest[p] @ Vector(v['position']) for p, part in body['parts'].items() for v in part['vertices']]
axes = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
conversion = Matrix.Translation((0, 0, -min(p.y for p in points) * scale)) @ Matrix.Diagonal((scale, scale, scale, 1)) @ axes
ready_clip = motion['clips'][motion['actions']['104']]
ready = dict(zip(ready_clip['pointers'], map(native, ready_clip['frames'][0])))
grip = ready['0x9005868'].inverted() @ ready['0x9002518']
carry = conversion @ rest['0x9005868'] @ grip
grip_frame = carry.to_quaternion().to_matrix().to_4x4()
grip_frame.translation = carry.translation

def material(name, color, metallic=0):
    mat = bpy.data.materials.new(name);mat.diffuse_color = linear_hex(color);mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = mat.diffuse_color
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = .72
    return mat

wood = material('Worker pickaxe — ash handle', '947142')
iron = material('Worker pickaxe — dark socket', '59656a', .6)
steel = material('Worker pickaxe — steel edges', 'a7b6b5', .65)
straw = material('Worker — woven straw hat', 'c7ad71')
pieces = []
def cylinder(name, a, b, radius1, radius2, mat):
    a = Vector(a);b = Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius1, radius2=radius2, depth=(b-a).length, location=(a+b)*.5)
    obj = bpy.context.object;obj.name = name
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(mat);pieces.append(obj)

cylinder('Pickaxe — handle', (0, 0, -.23), (0, 0, .69), .045, .045, wood)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, .62))
obj = bpy.context.object;obj.name = 'Pickaxe — socket';obj.scale = (.19, .17, .18);obj.data.materials.append(iron);pieces.append(obj)
cylinder('Pickaxe — right blade', (0, 0, .64), (.41, 0, .52), .11, 0, steel)
cylinder('Pickaxe — left blade', (0, 0, .64), (-.37, 0, .52), .10, 0, steel)
bpy.ops.object.select_all(action='DESELECT')
for obj in pieces:obj.select_set(True)
bpy.context.view_layer.objects.active = pieces[0]
bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
pickaxe = bpy.context.object;pickaxe.name = 'Pickaxe'
for v in pickaxe.data.vertices:v.co = grip_frame @ (pickaxe.matrix_world @ v.co)
pickaxe.matrix_world = Matrix.Identity(4)
pickaxe.parent = rig
pickaxe['rom_hand_pointer'] = '0x9005868'
pickaxe['rom_grip_frame'] = [v for row in grip_frame for v in row]

# Keep the body geometry, face, UVs and all original motions exactly intact.
# Only copied clothing materials receive the worker's teal/navy/brass palette.
for obj in [o for o in bpy.data.objects if o.get('rom_part') and o.name != 'ROM_Head']:
    for slot in obj.material_slots:
        mat = slot.material.copy();slot.material = mat;mat.name = 'Worker_' + mat.name
        nodes = mat.node_tree.nodes;links = mat.node_tree.links
        shader = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
        color = shader.inputs['Base Color'].links[0].from_socket
        split = nodes.new('ShaderNodeSeparateColor');links.new(color, split.inputs[0]);r,g,b = split.outputs[:3]
        op = lambda kind,a,b_:math_node(nodes,links,kind,a,b_)
        mul = lambda a,b_:op('MULTIPLY',a,b_)
        gt = lambda a,b_:op('GREATER_THAN',a,b_)
        lt = lambda a,b_:op('LESS_THAN',a,b_)
        masks = [(mul(gt(r,.15),mul(lt(g,.25),gt(r,op('ADD',b,.12)))),'327c72'),
                 (mul(gt(r,.5),mul(gt(g,.25),lt(b,.12))),'ba9959'),
                 (mul(gt(r,.65),mul(gt(g,.65),gt(b,.65))),'293f4a'),
                 (mul(gt(b,.2),mul(lt(r,.1),lt(g,.1))),'ba9959')]
        for mask, shade in masks:
            mix = nodes.new('ShaderNodeMixRGB');links.new(mask,mix.inputs[0]);links.new(color,mix.inputs[1])
            mix.inputs[2].default_value = linear_hex(shade);color = mix.outputs[0]
        links.new(color,shader.inputs['Base Color'])

bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=1.25, radius2=.06, depth=.52, location=(0, -.03, 3.10))
hat = bpy.context.object;hat.name = 'WorkerHat';hat.data.materials.append(straw)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
hat.parent = rig
group = hat.vertex_groups.new(name='Head');group.add(list(range(len(hat.data.vertices))),1,'REPLACE')
mod = hat.modifiers.new('Follow native head', 'ARMATURE');mod.object = rig

# An independent tool bone retains the ROM weapon rotation through the cuts,
# while dropping the Gold Pipe's magical size expansion for an ordinary pickaxe.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
b = rig.data.edit_bones.new('Pickaxe_Control');b.head = grip_frame.translation;b.tail = grip_frame @ Vector((0, .3, 0));b.use_deform = True
b.matrix = grip_frame;b.length = .3
bpy.ops.object.mode_set(mode='OBJECT')
group = pickaxe.vertex_groups.new(name='Pickaxe_Control');group.add(list(range(len(pickaxe.data.vertices))),1,'REPLACE')
mod = pickaxe.modifiers.new('Original Goemon pipe grip', 'ARMATURE');mod.object = rig
control = rig.pose.bones['Pickaxe_Control'];control.rotation_mode = 'QUATERNION'
rest_bone = control.bone.matrix_local.copy()
for action in bpy.data.actions:
    action_id = action.get('rom_action')
    if action_id is None:continue
    clip = motion['clips'][motion['actions'][str(action_id)]]
    rate = max(.01,float(motion['rates'].get(str(action_id),1)))
    rig.animation_data.action = action
    samples = {}
    previous = None
    for step in range((clip['frame_count']-1)*4+1):
        index = step//4;fraction = (step%4)/4
        source = dict(zip(clip['pointers'],map(native,clip['frames'][index])))
        if fraction:
            following = dict(zip(clip['pointers'],map(native,clip['frames'][index+1])))
            source = {p:m.lerp(following[p],fraction) for p,m in source.items()}
        native_tool = source.get('0x9002518', source.get('0x9005868',rest['0x9005868']) @ grip)
        pose = conversion @ native_tool
        rigid = pose.to_quaternion().to_matrix().to_4x4();rigid.translation = pose.translation
        control.matrix_basis = rest_bone.inverted() @ rigid
        q = control.rotation_quaternion.copy()
        if previous:q.make_compatible(previous)
        control.rotation_quaternion = q;previous = q.copy()
        for path,values in [('location',control.location),('rotation_quaternion',q),('scale',control.scale)]:
            for axis,value in enumerate(values):samples.setdefault((path,axis),[]).extend((1+step/4/rate,float(value)))
    for (prop,axis),values in samples.items():
        control.keyframe_insert(prop,index=axis,frame=1,group='Pickaxe_Control')
        curves = [fc for l in action.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
        fc = next(fc for fc in curves if fc.data_path==control.path_from_id(prop) and fc.array_index==axis)
        fc.keyframe_points.clear();fc.keyframe_points.add(len(values)//2);fc.keyframe_points.foreach_set('co',values)
        for key in fc.keyframe_points:key.interpolation='LINEAR'
rig.animation_data.action = next(a for a in bpy.data.actions if a.get('rom_action')==0)
bpy.context.scene.frame_set(1)
bpy.context.scene['description'] = 'Worker on the approved ROM Goemon Blender base. Pickaxe uses native pipe hand and direction. Body source preserved.'
for image in bpy.data.images:
    if image.type=='IMAGE' and not image.packed_file:image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))

# Lightweight runtime equipment, with a canonical local +Y shaft in glTF.
rig.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis = Matrix.Identity(4)
hat.modifiers.clear();hat.vertex_groups.clear();hat.parent = None;hat.matrix_basis = Matrix.Identity(4)
pickaxe.modifiers.clear();pickaxe.vertex_groups.clear();pickaxe.parent = None
for v in pickaxe.data.vertices:v.co = grip_frame.inverted() @ v.co
pickaxe.matrix_basis = grip_frame
bpy.ops.object.select_all(action='DESELECT')
for obj in [hat,pickaxe]:obj.select_set(True)
output = ROOT / 'assets/models/forest/rom_worker_equipment.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
    export_cameras=False,export_lights=False,export_animations=False,export_skins=False,export_extras=True)
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
print('ROM_WORKER_BUILT',str(TARGET),'body master unchanged',flush=True)
