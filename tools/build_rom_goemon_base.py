"""Blender -b --factory-startup --python tools/build_rom_goemon_base.py.

Original ROM parts stay rigid. Only a uniform normalization and axis conversion
are applied; independent native global matrices are baked onto named bones.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from rom_goemon_blender_materials import material
from rom_goemon_blender_affine import add_correction

DATA = ROOT / 'assets/characters/recovered_goemon'
DEST = ROOT / 'assets/blender/characters/rom_goemon_base'
REPORT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/ROM Goemon Blender Base')
POINTERS = {'Pelvis':'0x9004f48','Chest':'0x9005a28','Head':'0x90050f8',
            'Arm_R':'0x9005498','Forearm_R':'0x90055b8','Arm_L':'0x9005748','Forearm_L':'0x9005868',
            'Leg_R':'0x90047f8','Shin_R':'0x9004ac8','Foot_R':'0x9004930',
            'Leg_L':'0x9004bb0','Shin_L':'0x9004e48','Foot_L':'0x9004cd0'}
PARENTS = {'Pelvis':None,'Chest':'Pelvis','Head':'Chest','Arm_R':'Chest','Arm_L':'Chest',
           'Forearm_R':'Arm_R','Forearm_L':'Arm_L','Leg_R':'Pelvis','Leg_L':'Pelvis',
           'Shin_R':'Leg_R','Shin_L':'Leg_L','Foot_R':'Shin_R','Foot_L':'Shin_L'}
TAILS = {'Pelvis':'Chest','Chest':'Head','Arm_L':'Forearm_L','Arm_R':'Forearm_R',
         'Leg_L':'Shin_L','Leg_R':'Shin_R','Shin_L':'Foot_L','Shin_R':'Foot_R'}
LABELS = {0:'Idle',12:'Walk_Slow',13:'Walk',14:'Jog',15:'Run',24:'Jump',25:'Fall',26:'Land',
          104:'Pipe_Combo_1',105:'Pipe_Combo_2',106:'Pipe_Combo_3',107:'Recover_1',108:'Recover_2',109:'Recover_3',
          124:'Coin_Throw',130:'Golden_Transform',131:'Golden_Recover'}


def native(values):
    return Matrix(((values[0], values[3], values[6], values[9]),
                   (values[1], values[4], values[7], values[10]),
                   (values[2], values[5], values[8], values[11]), (0, 0, 0, 1)))


def hierarchy():
    result = []
    while len(result) < len(PARENTS):
        for name, parent in PARENTS.items():
            if name not in result and (parent is None or parent in result):result.append(name)
    return result


def make_rig(reference, conversion):
    data = bpy.data.armatures.new('ROM_Goemon_Bones');rig = bpy.data.objects.new('ROM_Goemon_Rig', data)
    bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active = rig;rig.select_set(True)
    rig.show_in_front = True;bpy.ops.object.mode_set(mode='EDIT')
    points = {name:(conversion @ reference[pointer]).translation for name, pointer in POINTERS.items()}
    for name in hierarchy():
        bone = data.edit_bones.new(name);bone.head = points[name]
        if name in TAILS:bone.tail = points[TAILS[name]]
        elif name == 'Head':bone.tail = bone.head + Vector((0, 0, .55))
        elif name.startswith('Forearm'):bone.tail = bone.head + Vector((0, .28, -.22))
        else:bone.tail = bone.head + Vector((0, .32, -.05))
        if (bone.tail - bone.head).length < .01:bone.tail = bone.head + Vector((0, 0, .1))
        length = (bone.tail - bone.head).length
        orientation = (conversion @ reference[POINTERS[name]]).to_quaternion().to_matrix().to_4x4()
        orientation.translation = points[name];bone.matrix = orientation;bone.length = length
        # The ROM (and our runtime equipment rig) stores independent global
        # matrices. A synthetic parent hierarchy changes squash/stretch actions.
        bone.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    rig['rom_face_0'] = 1;rig['rom_face_1'] = 1
    for name in POINTERS:rig['rom_visible_' + name] = 1.0
    return rig


def make_part(pointer, source, name, reference, conversion, rig, face):
    transform = conversion @ reference[pointer]
    vertices = [transform @ Vector(v['position']) for v in source['vertices']]
    faces = [tuple(f) for s in source['surfaces'] for f in s['faces']]
    mesh = bpy.data.meshes.new('ROM_' + name);mesh.from_pydata(vertices, [], faces);mesh.update()
    obj = bpy.data.objects.new('ROM_' + name, mesh);bpy.context.collection.objects.link(obj)
    obj['rom_part'] = pointer;obj['source_vertex_count'] = len(vertices)
    obj.parent = rig
    group = obj.vertex_groups.new(name=name);group.add(list(range(len(vertices))), 1.0, 'REPLACE')
    add_correction(obj, rig, name)
    modifier = obj.modifiers.new('Rigid original part', 'ARMATURE');modifier.object = rig
    raw = mesh.uv_layers.new(name='ROM_Raw_ST');display = mesh.uv_layers.new(name='UVMap')
    color = mesh.color_attributes.new(name='ROM_Color', type='FLOAT_COLOR', domain='CORNER')
    polygon_index = 0
    for surface_index, surface in enumerate(source['surfaces']):
        mesh.materials.append(material(surface, DATA / 'body', rig, face['textures']))
        for _ in surface['faces']:
            polygon = mesh.polygons[polygon_index];polygon_index += 1;polygon.material_index = surface_index;polygon.use_smooth = True
            for loop_index in polygon.loop_indices:
                v = source['vertices'][mesh.loops[loop_index].vertex_index];st = v['uv_raw']
                raw.data[loop_index].uv = st
                width, height = surface['texture_size'];su, sv = surface['uv_scale']
                display.data[loop_index].uv = (st[0] * su / 32 / width, 1 - st[1] * sv / 32 / height)
                rgba = v['rgba'];rgb = [1, 1, 1] if surface.get('lit', True) else [c / 255 for c in rgba[:3]]
                color.data[loop_index].color = (*rgb, rgba[3] / 255)
    normal_matrix = transform.to_3x3().inverted().transposed()
    mesh.normals_split_custom_set_from_vertices([(normal_matrix @ Vector(v['normal'])).normalized() for v in source['vertices']])
    mesh.uv_layers.active = display
    for property_ in ['hide_render', 'hide_viewport']:
        driver = obj.driver_add(property_).driver;v = driver.variables.new();v.name = 'visible';v.targets[0].id = rig
        v.targets[0].data_path = '["rom_visible_%s"]' % name;driver.expression = 'visible < 0.5'
    return obj


def bake(rig, body, motion, reference, conversion):
    rig.animation_data_create()
    rest = {name:rig.data.bones[name].matrix_local.copy() for name in POINTERS}
    inverses = {name:(conversion @ reference[pointer]).inverted() for name, pointer in POINTERS.items()}
    face_indices = {key:i for i, key in enumerate(sorted(body['face']['textures']))}
    for action_id, clip_id in sorted(motion['actions'].items(), key=lambda pair:int(pair[0])):
        id_ = int(action_id);clip = motion['clips'][clip_id];rate = max(.01, float(motion['rates'].get(action_id, 1)))
        action = bpy.data.actions.new('ROM_%02X_%s' % (id_, LABELS.get(id_, 'Action')));action.use_fake_user = True
        action['rom_action'] = id_;action['rom_clip'] = clip_id;action['rom_rate'] = rate
        action['rom_bake_subframes'] = 4
        action['rom_frame_count'] = clip['frame_count'];rig.animation_data.action = action
        for pose in rig.pose.bones:pose.rotation_mode = 'QUATERNION';pose.matrix_basis = Matrix.Identity(4)
        face = body['face']['actions'].get(action_id, {})
        targets = {name:rest[name].copy() for name in POINTERS}
        channels = {};previous_quaternions = {}
        def record(path, values, time):
            if isinstance(values, (int, float)):values = [values]
            for axis, value in enumerate(values):channels.setdefault((path, axis), []).extend([time, float(value)])
        for sample in range((clip['frame_count'] - 1) * 4 + 1):
            source_frame = sample / 4;index = int(source_frame);fraction = source_frame - index
            time = 1 + source_frame / rate
            source = dict(zip(clip['pointers'], map(native, clip['frames'][index])))
            if fraction:
                following = dict(zip(clip['pointers'], map(native, clip['frames'][index + 1])))
                source = {p:matrix.lerp(following[p], fraction) for p, matrix in source.items()}
            for name in hierarchy():
                pointer = POINTERS[name];pose = rig.pose.bones[name]
                visible = pointer in source and abs(source[pointer].to_3x3().determinant()) > 1e-8
                rig['rom_visible_' + name] = float(visible)
                path = '["rom_visible_%s"]' % name
                if sample == 0:rig.keyframe_insert(path, frame=time)
                record(path, float(visible), time)
                if visible:targets[name] = conversion @ source[pointer] @ inverses[name] @ rest[name]
                # Native poses are global. Derive local channels from this
                # frame's explicit parent target, never Blender's stale depsgraph.
                pose.matrix_basis = pose.bone.convert_local_to_pose(targets[name], rest[name], invert=True)
                q = pose.rotation_quaternion.copy()
                if name in previous_quaternions:q.make_compatible(previous_quaternions[name])
                pose.rotation_quaternion = q;previous_quaternions[name] = q.copy()
                actual_delta = rest[name] @ pose.matrix_basis @ rest[name].inverted()
                expected_delta = targets[name] @ rest[name].inverted()
                correction = actual_delta.inverted_safe() @ expected_delta
                for row in range(3):
                    for column in range(4):
                        path = '["affine_%s_%d%d"]' % (name, row, column)
                        rig['affine_%s_%d%d' % (name, row, column)] = correction[row][column]
                        if sample == 0:rig.keyframe_insert(path, frame=time)
                        record(path, correction[row][column], time)
                for prop in ['location', 'rotation_quaternion', 'scale']:
                    if sample == 0:pose.keyframe_insert(prop, frame=time, group=name)
                    record('pose.bones["%s"].%s' % (name, prop), getattr(pose, prop), time)
            pair = face.get('frames', [["0x823f", "0x823f"]])[min(index, len(face.get('frames', [0])) - 1)]
            for channel in range(2):
                rig['rom_face_' + str(channel)] = face_indices.get(pair[channel], 1)
                path = '["rom_face_%d"]' % channel
                if sample == 0:rig.keyframe_insert(path, frame=time)
                record(path, rig['rom_face_' + str(channel)], time)
        # Bake spherical matrix interpolation at quarter-source frames. Component
        # quaternion curves alone use normalized lerp and diverge on fast swings.
        # Visibility/face values are discrete selections, never blended PIC IDs.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        # Keyframe insertion merges nearby times for very fast
                        # source actions. Bulk creation preserves every frame.
                        values = channels[(curve.data_path, curve.array_index)]
                        curve.keyframe_points.clear();curve.keyframe_points.add(len(values) // 2)
                        curve.keyframe_points.foreach_set('co', values)
                        for key in curve.keyframe_points:key.interpolation = 'CONSTANT' if curve.data_path.startswith('["rom_') else 'LINEAR'
                        # Points are already sorted and LINEAR/CONSTANT needs
                        # no handle recalculation. update() deduplicates fast
                        # native keys with Blender's0.01-frame merge tolerance.
        print('BAKED', action.name, clip['frame_count'], flush=True)
    idle_action = next(a for a in bpy.data.actions if a.get('rom_action') == 0)
    rig.animation_data.action = idle_action;bpy.context.scene.frame_end = math.ceil(idle_action.frame_range[1]);bpy.context.scene.frame_set(1)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version = 0
    DEST.mkdir(parents=True, exist_ok=True);REPORT.mkdir(parents=True, exist_ok=True)
    body = json.loads((DATA / 'body/body.json').read_text());motion = json.loads((DATA / 'motion.json').read_text())
    idle = motion['clips'][motion['actions']['0']];reference = dict(zip(idle['pointers'], map(native, idle['frames'][0])))
    points = [reference[p] @ Vector(v['position']) for p, part in body['parts'].items() for v in part['vertices']]
    low = min(p.y for p in points);height = max(p.y for p in points) - low;scale = 3.2206185 / height
    axes = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    conversion = Matrix.Translation((0, 0, -low * scale)) @ Matrix.Diagonal((scale, scale, scale, 1)) @ axes
    rig = make_rig(reference, conversion)
    for name, pointer in POINTERS.items():make_part(pointer, body['parts'][pointer], name, reference, conversion, rig, body['face'])
    bake(rig, body, motion, reference, conversion)
    scene = bpy.context.scene;scene.render.fps = 30;scene['rom_source_scale'] = scale
    scene['description'] = 'Original ROM Goemon:13 rigid parts, source textures, named rig and original action IDs. Blender +Y faces forward, +Z up.'
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active = rig
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active;space.shading.type = 'MATERIAL'
            space.region_3d.view_distance = 6;space.region_3d.view_location = Vector((0, 0, 1.5))
            space.region_3d.view_rotation = Vector((-5, -8, -2)).to_track_quat('-Z', 'Y')
            space.region_3d.view_perspective = 'ORTHO'
    preserved = ['assets/blender/characters/kai.blend', 'assets/blender/characters/goemon_cosplay/master-thief.blend',
                 'assets/characters/recovered_goemon/body/body.json', 'assets/characters/recovered_goemon/motion.json']
    manifest = dict(format_version=1, source=body['provenance'], body_parts=13, height_metres=3.2206185,
                    actions=len(motion['actions']), source_scale=scale, pointer_bones=POINTERS,
                    preserved_sources={p:hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in preserved},
                    rig='Independent named bones match native global matrices, including squash/stretch; each body part is bound100% to one bone.',
                    preview='Blender nearest texture sampling; original N64 three-point filter remains a runtime shader. Source UVs, tile modes, images and face selections preserved.')
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(DEST / 'goemon.blend'))
    print('ROM_GOEMON_BASE_BUILT', DEST / 'goemon.blend', flush=True)


if __name__ == '__main__':build()
