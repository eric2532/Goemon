"""Blender -b --factory-startup --python tools/verify_rom_goemon_base.py [-- --pilot]."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/blender/characters/rom_goemon_base'
REPORT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/ROM Goemon Blender Base')
PILOT = '--pilot' in sys.argv
WORKER = '--worker' in sys.argv
FILE = DEST / ('worker.blend' if WORKER else 'master_thief.blend' if PILOT else 'goemon.blend')
if not FILE.exists():
    print('ROM_GOEMON_BASE_RESULT FAIL: editable Blender base is not built:', FILE)
    sys.exit(1)

body = json.loads((ROOT / 'assets/characters/recovered_goemon/body/body.json').read_text())
motion = json.loads((ROOT / 'assets/characters/recovered_goemon/motion.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(FILE))
rig = bpy.data.objects.get('ROM_Goemon_Rig')
assert rig is not None and rig.type == 'ARMATURE', 'Missing editable ROM rig'
parts = [o for o in bpy.data.objects if o.get('rom_part')]
assert {o['rom_part'] for o in parts} == set(body['parts']), 'All thirteen body parts must survive'
assert len(parts) == 13, 'Do not combine or duplicate original body pieces'
assert all(i.packed_file for i in bpy.data.images if i.type == 'IMAGE'), 'Pack textures for portable editing'

def native(values):
    return Matrix(((values[0], values[3], values[6], values[9]),
                   (values[1], values[4], values[7], values[10]),
                   (values[2], values[5], values[8], values[11]), (0, 0, 0, 1)))

conversion = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
idle = motion['clips'][motion['actions']['0']]
rest = dict(zip(idle['pointers'], map(native, idle['frames'][0])))
source_points = [rest[pointer] @ Vector(v['position']) for pointer, p in body['parts'].items() for v in p['vertices']]
low = min(p.y for p in source_points)
height = max(p.y for p in source_points) - low
scale = 3.2206185 / height
conversion = Matrix.Translation((0, 0, -low * scale)) @ Matrix.Diagonal((scale, scale, scale, 1)) @ conversion

for obj in parts:
    original = body['parts'][obj['rom_part']]
    assert len(obj.data.vertices) == len(original['vertices']), obj.name + ': source vertices changed'
    assert len(obj.data.polygons) == sum(len(s['faces']) for s in original['surfaces']), obj.name + ': triangles changed'
    assert obj.data.uv_layers.get('ROM_Raw_ST') is not None, 'Preserve original fixed-point UV records'
    for loop in obj.data.loops:
        expected = original['vertices'][loop.vertex_index]['uv_raw']
        assert max(abs(a - b) for a, b in zip(obj.data.uv_layers['ROM_Raw_ST'].data[loop.index].uv, expected)) < .0001, 'Original S/T UV records changed'
    assert len(obj.vertex_groups) == 1, 'Original parts require rigid single-bone binding'
    assert all(len(v.groups) == 1 and abs(v.groups[0].weight - 1) < 1e-6 for v in obj.data.vertices), 'Do not smooth original joints'

actions = {a.get('rom_action'): a for a in bpy.data.actions if a.get('rom_action') is not None}
assert set(actions) == {int(a) for a in motion['actions']}, 'All original action IDs need selectable Blender actions'
worst = 0.0
samples = 0
errors = []
for action_id, action in sorted(actions.items()):
    rig.animation_data.action = action
    clip = motion['clips'][motion['actions'][str(action_id)]]
    rate = max(.01, float(motion['rates'].get(str(action_id), 1)))
    for index in sorted({0, (clip['frame_count'] - 1) // 2, clip['frame_count'] - 1}):
        frame = 1 + index / rate
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        source = dict(zip(clip['pointers'], map(native, clip['frames'][index])))
        face = body['face']['actions'].get(str(action_id), {})
        pair = face.get('frames', [["0x823f", "0x823f"]])[min(index, len(face.get('frames', [0])) - 1)]
        face_indices = {key:i for i, key in enumerate(sorted(body['face']['textures']))}
        for channel in range(2):
            assert round(rig['rom_face_' + str(channel)]) == face_indices.get(pair[channel], 1), 'Face channel differs from original action frame'
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for obj in parts:
            pointer = obj['rom_part']
            valid = pointer in source and abs(source[pointer].to_3x3().determinant()) > 1e-8
            assert obj.hide_render == (not valid), f'{action_id:X}/{index}: part visibility differs'
            if not valid:
                continue
            expected = conversion @ source[pointer]
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            for vertex, original in zip(mesh.vertices, body['parts'][pointer]['vertices']):
                error = (evaluated.matrix_world @ vertex.co - expected @ Vector(original['position'])).length
                worst = max(worst, error)
                if error >= .001:
                    if '--diagnose' not in sys.argv:raise AssertionError(f'{action_id:X}/{index}/{obj.name}: native vertex error {error}')
                    errors.append(dict(action=action_id, frame=index, part=obj.name, error=error))
            evaluated.to_mesh_clear()
            samples += 1

interpolated_samples = 0
worst_interpolated = 0.0
def check_interpolated(action_id, index, fraction):
    global interpolated_samples, worst_interpolated
    action = actions[action_id];rig.animation_data.action = action
    clip = motion['clips'][motion['actions'][str(action_id)]];rate = max(.01, float(motion['rates'][str(action_id)]))
    frame = 1 + (index + fraction) / rate;bpy.context.scene.frame_set(int(frame), subframe=frame % 1);bpy.context.view_layer.update()
    first = dict(zip(clip['pointers'], map(native, clip['frames'][index])))
    second = dict(zip(clip['pointers'], map(native, clip['frames'][min(index + 1, clip['frame_count'] - 1)])))
    for obj in parts:
        pointer = obj['rom_part']
        if pointer not in first or pointer not in second:continue
        expected = conversion @ first[pointer].lerp(second[pointer], fraction)
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh = evaluated.to_mesh()
        for vertex, original in zip(mesh.vertices, body['parts'][pointer]['vertices']):
            error = (evaluated.matrix_world @ vertex.co - expected @ Vector(original['position'])).length
            worst_interpolated = max(worst_interpolated, error)
            assert error < .001, f'{action_id:X}/{index}/{fraction} fractional native interpolation error {error}'
        evaluated.to_mesh_clear();interpolated_samples += 1

for action_id in [0, 12, 15, 24, 25, 26, 104, 105, 106]:
    clip = motion['clips'][motion['actions'][str(action_id)]]
    for index in sorted({0, max(0, clip['frame_count'] // 2 - 1), max(0, clip['frame_count'] - 2)}):
        for fraction in [.125, .25, .375, .5, .625, .75, .875]:check_interpolated(action_id, index, fraction)
for action_id, index in [(106, 6), (119, 1)]:
    for fraction in [.125, .25, .375, .5, .625, .75, .875]:check_interpolated(action_id, index, fraction)

if PILOT:
    costume = bpy.data.objects.get('MasterThief_Costume')
    assert costume is not None and len(costume.data.vertices) == 162, 'Preserve Master Thief costume topology'
    assert any(o.get('thief_weapon') for o in bpy.data.objects), 'Preserve Master Thief weapon'
    assert all(g.name in rig.data.bones for g in costume.vertex_groups), 'Every costume binding needs a real bone'

if WORKER:
    pickaxe = bpy.data.objects['Pickaxe']
    assert rig.data.bones['Pickaxe_Control'].use_deform, 'Pickaxe control must deform its weighted mesh'
    assert pickaxe.vertex_groups.get('Pickaxe_Control'), 'Pickaxe requires a rigid tool binding'
    grip_values = pickaxe['rom_grip_frame']
    grip_frame = Matrix([grip_values[i:i+4] for i in range(0,16,4)])
    ready = motion['clips'][motion['actions']['104']]
    ready_pose = dict(zip(ready['pointers'], map(native, ready['frames'][0])))
    grip = ready_pose['0x9005868'].inverted() @ ready_pose['0x9002518']
    for action_id in [0, 15, 104]:
        clip = motion['clips'][motion['actions'][str(action_id)]]
        rig.animation_data.action = actions[action_id]
        rate = float(motion['rates'][str(action_id)])
        for index in sorted({0, (clip['frame_count']-1)//2, clip['frame_count']-1}):
            frame = 1 + index / rate
            bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
            bpy.context.view_layer.update()
            source = dict(zip(clip['pointers'], map(native, clip['frames'][index])))
            weapon = conversion @ source.get('0x9002518', source['0x9005868'] @ grip)
            rigid = weapon.to_quaternion().to_matrix().to_4x4();rigid.translation = weapon.translation
            expected = rigid @ grip_frame.inverted()
            evaluated = pickaxe.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            for vertex, original in zip(mesh.vertices, pickaxe.data.vertices):
                error = (evaluated.matrix_world @ vertex.co - expected @ original.co).length
                assert error < .001, f'Worker pickaxe detached at action {action_id}, frame {index}: {error}'
            evaluated.to_mesh_clear()

manifest = json.loads((DEST / 'manifest.json').read_text())
for source, expected in manifest['preserved_sources'].items():
    assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest() == expected, 'Original Blender source changed: ' + source
report = dict(file=str(FILE), actions=len(actions), body_parts=len(parts), sampled_parts=samples,
              interpolated_parts=interpolated_samples, max_vertex_error_metres=worst,
              max_interpolated_vertex_error_metres=worst_interpolated, packed_images=len(bpy.data.images), pilot=PILOT)
if '--diagnose' in sys.argv:
    (REPORT / 'diagnostic-errors.json').write_text(json.dumps(sorted(errors, key=lambda row:row['error'], reverse=True)[:30], indent=2))
    print('ROM_BASE_DIAGNOSE', report)
    sys.exit(1 if errors else 0)
REPORT.mkdir(parents=True, exist_ok=True)
(REPORT / ('worker-verification.json' if WORKER else 'pilot-verification.json' if PILOT else 'base-verification.json')).write_text(json.dumps(report, indent=2))
print('ROM_GOEMON_BASE_RESULT PASS', json.dumps(report))
