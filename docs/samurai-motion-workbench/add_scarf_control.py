"""Add one freely poseable scarf bone to the current workbench, preserving edits.

Run inside the open Blender document. Does not reload or regenerate its actions.
"""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import struct
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / 'build/Other Files/Samurai Pose Editing'
TARGET = ROOT / 'docs/samurai-motion-workbench/Samurai_Animation_Workbench.blend'

def matrix_list(m):
    return [list(row) for row in m]

def difference(a, b):
    return max(abs(a[i][j] - b[i][j]) for i in range(4) for j in range(4))

def action_snapshot():
    result = {}
    for action in bpy.data.actions:
        result[action.name] = {fc.data_path + ':' + str(fc.array_index):
            [[*k.co, *k.handle_left, *k.handle_right, k.interpolation] for k in fc.keyframe_points]
            for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves
            if 'Scarf_Control' not in fc.data_path}
    return result

def geometry_snapshot():
    result = {}
    for mesh in bpy.data.meshes:
        h = hashlib.sha256()
        for v in mesh.vertices:
            h.update(struct.pack('<3f', *v.co))
        for p in mesh.polygons:
            h.update(struct.pack('<I', len(p.vertices)))
            for v in p.vertices:
                h.update(struct.pack('<I', v))
        for layer in mesh.uv_layers:
            for uv in layer.data:
                h.update(struct.pack('<2f', *uv.uv))
        result[mesh.name] = h.hexdigest()
    return result

def add_scarf_control(write_files=True):
    assert Path(bpy.data.filepath) == TARGET, bpy.data.filepath
    QA.mkdir(parents=True, exist_ok=True)
    win = bpy.context.window
    original_scene = win.scene
    original_frame = original_scene.frame_current
    entries = []
    for sc in bpy.data.scenes:
        rig = next((o for o in sc.objects if o.type == 'ARMATURE'), None)
        if rig is None:
            continue
        scarf = next(o for o in sc.objects if o.type == 'EMPTY' and o.name.startswith('ScarfTail'))
        assert 'Scarf_Control' not in rig.data.bones, 'Scarf control already exists'
        entries.append((sc, rig, scarf))
    # Preserve even unkeyed live edits before changing modes or scenes.
    poses = {r.name: {p.name: matrix_list(p.matrix_basis) for p in r.pose.bones} for sc, r, scarf in entries}
    rests = {r.name: {b.name: matrix_list(b.matrix_local) for b in r.data.bones} for sc, r, scarf in entries}
    actions_before = action_snapshot()
    geometry_before = geometry_snapshot()
    backup = QA / ('Samurai before scarf bone ' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.blend')
    if write_files:
        bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
        (QA / 'scarf-before.json').write_text(json.dumps({'backup': str(backup), 'scene': original_scene.name,
            'frame': original_frame, 'poses': poses, 'rest': rests, 'actions': actions_before,
            'geometry': geometry_before}, indent=2))

    def restore_pose(rig):
        for n, m in poses[rig.name].items():
            rig.pose.bones[n].matrix_basis = Matrix(m)

    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    seen = set()
    for sc, rig, scarf in entries:
        win.scene = sc
        restore_pose(rig)
        bpy.context.view_layer.update()
        world = scarf.matrix_world.copy()
        if rig.data.as_pointer() not in seen:
            seen.add(rig.data.as_pointer())
            local = rig.matrix_world.inverted() @ world
            bind = rig.data.bones['Head'].matrix_local @ rig.pose.bones['Head'].matrix.inverted() @ local
            for ob in bpy.context.selected_objects:
                ob.select_set(False)
            rig.select_set(True)
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.mode_set(mode='EDIT')
            bone = rig.data.edit_bones.new('Scarf_Control')
            bone.head = bind.translation
            bone.tail = bind @ Vector((0, 1.3, 0))
            bone.align_roll(bind.to_3x3().col[2])
            bone.parent = rig.data.edit_bones['Head']
            bone.use_connect = False
            bone.use_deform = False
            bpy.ops.object.mode_set(mode='OBJECT')
            collection = rig.data.collections.new('Scarf — rotate from the neck')
            collection.assign(rig.data.bones['Scarf_Control'])
            rig.data.bones['Scarf_Control'].color.palette = 'THEME03'
        restore_pose(rig)
        p = rig.pose.bones['Scarf_Control']
        p.rotation_mode = 'QUATERNION'
        p.matrix_basis = Matrix.Identity(4)
        p.lock_location = p.lock_rotation = p.lock_scale = (False,) * 3
        p.lock_rotation_w = False
        p.bone.hide = p.bone.hide_select = False
        bpy.context.view_layer.update()
        # Keep the existing cloth at its exact world transform while giving it
        # the new bone parent. Its original mesh, UVs and materials stay intact.
        scarf.parent = rig
        scarf.parent_type = 'BONE'
        scarf.parent_bone = 'Scarf_Control'
        bpy.context.view_layer.update()
        scarf.matrix_world = world
        bpy.context.view_layer.update()
        assert difference(scarf.matrix_world, world) < 1e-5
        for prop in ['location', 'rotation_quaternion', 'scale']:
            p.keyframe_insert(data_path=prop, frame=0, group=p.name)
            sc.keying_sets.active.paths.add(rig, p.path_from_id(prop), group_method='NAMED', group_name=p.name)
        # Actual movement probe: scarf rotates while every original bone stays.
        bones_before = {b.name: b.matrix.copy() for b in rig.pose.bones if b.name != p.name}
        scarf_before = scarf.matrix_world.copy()
        p.rotation_quaternion = Quaternion((1, 0, 0), .35)
        bpy.context.view_layer.update()
        response = difference(scarf.matrix_world, scarf_before)
        assert response > .1, response
        assert all(difference(rig.pose.bones[n].matrix, m) < 1e-5 for n, m in bones_before.items())
        p.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        assert difference(scarf.matrix_world, world) < 1e-5
        assert rests[rig.name] == {n: matrix_list(rig.data.bones[n].matrix_local) for n in rests[rig.name]}

    assert actions_before == action_snapshot(), 'Existing keyframes must stay exact'
    assert geometry_before == geometry_snapshot(), 'Geometry and UVs must stay exact'
    for sc, rig, scarf in entries:
        restore_pose(rig)
    win.scene = original_scene
    rig = next(o for o in original_scene.objects if o.type == 'ARMATURE')
    restore_pose(rig)
    bpy.context.view_layer.update()
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    for p in rig.pose.bones:
        p.select = p.name == 'Scarf_Control'
    rig.data.bones.active = rig.data.bones['Scarf_Control']
    bpy.ops.object.mode_set(mode='POSE')
    for sc, r, scarf in entries:
        for name, m in poses[r.name].items():
            assert difference(r.pose.bones[name].matrix_basis, Matrix(m)) < 1e-5
    note = '\nScarf_Control: rotate (R) the trailing scarf from its neck attachment. It follows Head and is included in Whole Pose (I) keying.\n'
    guide = ROOT / 'docs/samurai-motion-workbench/START_HERE.txt'
    if write_files:
        guide.write_text(guide.read_text() + note)
        bpy.data.texts['START HERE — Samurai free posing'].write(note)
        bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    report = {'file': str(TARGET), 'scene': win.scene.name, 'frame': win.scene.frame_current,
        'bone': 'Scarf_Control', 'rigs': [r.name for sc, r, scarf in entries],
        'geometry_unchanged': True, 'existing_keys_unchanged': True, 'live_pose_preserved': True,
        'scarf_rotation_moves_cloth': True, 'original_bones_unaffected': True, 'backup': str(backup)}
    if write_files:
        (QA / 'scarf-control-result.json').write_text(json.dumps(report, indent=2))
    print('SCARF_CONTROL_READY', json.dumps(report), flush=True)

if __name__ == '__main__':
    add_scarf_control()
