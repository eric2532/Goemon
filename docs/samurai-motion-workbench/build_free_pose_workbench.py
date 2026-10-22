"""Create a fresh, Pirate-style FK posing file without replacing authored work."""
from pathlib import Path
import hashlib
import json
import struct
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/samurai-weapon-workbench/Samurai_Weapon_Workbench.blend'
OUT = Path(__file__).resolve().parent
TARGET = OUT / 'Samurai_Animation_Workbench.blend'
QA = ROOT / 'build/Other Files/Samurai Pose Editing'
QA.mkdir(parents=True, exist_ok=True)
if TARGET.exists():
    raise RuntimeError('Do not replace user-authored poses; create a separate destination.')
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version = 0
idle = bpy.data.scenes['01 — Idle']
bpy.context.window.scene = idle
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
idle.frame_set(1)
rig = next(o for o in idle.objects if o.type == 'ARMATURE')
bpy.context.view_layer.update()
deform_names = [b.name for b in rig.data.bones if b.use_deform]
desired = {p.name: p.matrix.copy() for p in rig.pose.bones
           if p.name in deform_names or p.name == 'Katana_Control'}
rest = {n: [list(row) for row in rig.data.bones[n].matrix_local] for n in deform_names}

def mesh_digest(mesh):
    h = hashlib.sha256()
    for v in mesh.vertices:
        h.update(struct.pack('<3f', *v.co))
    for p in mesh.polygons:
        h.update(struct.pack('<I', len(p.vertices)))
        for i in p.vertices:
            h.update(struct.pack('<I', i))
    for layer in mesh.uv_layers:
        for uv in layer.data:
            h.update(struct.pack('<2f', *uv.uv))
    return h.hexdigest()

geometry = {m.name: mesh_digest(m) for m in bpy.data.meshes}
rigs = list({o for sc in bpy.data.scenes for o in sc.objects if o.type == 'ARMATURE'})
# Capture the displayed pose before taking away the solvers, then use the actual
# deform bones directly. No body geometry, bone rest transform, or UV is edited.
for r in rigs:
    r.animation_data_clear()
    for p in r.pose.bones:
        for c in list(p.constraints):
            p.constraints.remove(c)
for ob in bpy.data.objects:
    if ob.animation_data:
        ob.animation_data_clear()
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

seen = set()
for r in rigs:
    if r.data.as_pointer() in seen:
        continue
    seen.add(r.data.as_pointer())
    sc = next(sc for sc in bpy.data.scenes if r.name in sc.objects)
    bpy.context.window.scene = sc
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    r.hide_set(False)
    r.select_set(True)
    bpy.context.view_layer.objects.active = r
    bpy.ops.object.mode_set(mode='EDIT')
    for b in list(r.data.edit_bones):
        if not b.use_deform and b.name != 'Katana_Control':
            r.data.edit_bones.remove(b)
    sword = r.data.edit_bones['Katana_Control']
    sword.parent = None
    sword.name = 'Sword_Control'
    bpy.ops.object.mode_set(mode='OBJECT')
    for collection in list(r.data.collections):
        r.data.collections.remove(collection)
    body_collection = r.data.collections.new('Body — pose freely')
    sword_collection = r.data.collections.new('Sword — independent control')
    for b in r.data.bones:
        (body_collection if b.use_deform else sword_collection).assign(b)
        b.hide = False
        b.hide_select = False
        b.color.palette = 'THEME09' if b.name == 'Sword_Control' else 'DEFAULT'
    r.data.display_type = 'STICK'

desired['Sword_Control'] = desired.pop('Katana_Control')
for ob in bpy.data.objects:
    for c in ob.constraints:
        if hasattr(c, 'subtarget') and c.subtarget == 'Katana_Control':
            c.subtarget = 'Sword_Control'
            c.name = 'Follow independent Sword_Control'

guide = '''SAMURAI — FRESH FREE-POSING WORKBENCH / BLENDER REVIEW

This works like Pirate: rotate the real body bones and move the sword separately.
There are no arm or leg IK constraints, pinned feet, poles, or hidden body bones.

Start in 01 — Idle at FRAME 0. Only frame 0 is keyed in each scene.
02 — Run and 03 — Five-hit combo are fresh work areas with the same starting pose.
04 — Katana detail keeps the weapon modeling view.
The previous animations remain in docs/samurai-weapon-workbench/
Samurai_Weapon_Workbench.blend. This file does not replace them.

Arm_L/R rotates the upper arm; Forearm_L/R bends the elbow; Hand_L/R turns the wrist.
Leg_L/R, Shin_L/R, and Foot_L/R pose the legs. Pelvis, Chest, and Head pose the body.
Sword_Control moves/rotates the complete katana independently, like Pirate's sword.
Hands do not automatically follow it; position the hands and grip together.

R rotates; G moves; select an axis X/Y/Z if needed. Work in Pose Mode.
A selects all bones. I inserts a complete pose (Location, Rotation, Scale).
Auto Key is OFF. Insert a key after editing, then Command-S saves this new file.
Model geometry, UVs, original deform-bone rest lengths, and katana size are unchanged.
Blender review only; the playable game is unchanged.
'''
for text in list(bpy.data.texts):
    if 'START HERE' in text.name:
        bpy.data.texts.remove(text)
bpy.data.texts.new('START HERE — Samurai free posing').write(guide)
(OUT / 'START_HERE.txt').write_text(guide)
(OUT / '.gdignore').write_text('\n')
manifest = []
max_error = 0.0
for sc in bpy.data.scenes:
    r = next((o for o in sc.objects if o.type == 'ARMATURE'), None)
    if r is None:
        continue
    bpy.context.window.scene = sc
    sc.frame_start = 0
    sc.frame_set(0)
    sc.timeline_markers.clear()
    sc.timeline_markers.new('Start — your pose', frame=0)
    sc.tool_settings.use_keyframe_insert_auto = False
    # A scene-local absolute keying set makes I record the entire pose, including
    # the independent sword, without relying on UI-only built-in keying sets.
    for old in list(sc.keying_sets):
        sc.keying_sets.remove(old)
    keying = sc.keying_sets.new(idname='SamuraiWholePose', name='Whole Pose')
    for p in r.pose.bones:
        for prop in ['location', 'rotation_quaternion', 'scale']:
            keying.paths.add(r, p.path_from_id(prop), group_method='NAMED', group_name=p.name)
    sc.keying_sets.active = keying
    sc['posing_guide'] = 'Free FK body, independent Sword_Control. Start at frame 0; A then I records the full pose.'
    r.show_in_front = True
    r.hide_viewport = False
    r.hide_set(False)
    for p in r.pose.bones:
        p.rotation_mode = 'QUATERNION'
        p.lock_location = (False,) * 3
        p.lock_rotation = (False,) * 3
        p.lock_rotation_w = False
        p.lock_rotations_4d = False
        p.lock_scale = (False,) * 3
        p.lock_ik_x = p.lock_ik_y = p.lock_ik_z = False
        b = p.bone
        p.matrix_basis = b.convert_local_to_pose(
            desired[p.name], b.matrix_local,
            parent_matrix=desired[p.parent.name] if p.parent else Matrix.Identity(4),
            parent_matrix_local=b.parent.matrix_local if b.parent else Matrix.Identity(4),
            invert=True)
    bpy.context.view_layer.update()
    for p in r.pose.bones:
        max_error = max(max_error, max(abs(p.matrix[i][j] - desired[p.name][i][j])
                                     for i in range(4) for j in range(4)))
    action = bpy.data.actions.new(sc.name[:2] + '_' + ('Idle' if sc == idle else 'Run' if 'Run' in sc.name else 'Five_Hit_Combo'))
    r.animation_data_create()
    r.animation_data.action = action
    for p in r.pose.bones:
        for prop in ['location', 'rotation_quaternion', 'scale']:
            p.keyframe_insert(data_path=prop, frame=0, group=p.name)
        p.select = p.name == 'Chest'
    r.data.bones.active = r.data.bones['Chest']
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = sc.frame_end
    action['fresh_start'] = True
    for ob in sc.objects:
        ob.select_set(ob == r)
    sc.view_layers[0].objects.active = r
    manifest.append({'scene': sc.name, 'action': action.name, 'keys': [0], 'bones': len(r.pose.bones)})

assert max_error < 1e-4, max_error
assert geometry == {m.name: mesh_digest(m) for m in bpy.data.meshes}
assert rest == {n: [list(row) for row in rig.data.bones[n].matrix_local] for n in deform_names}
bpy.context.window.scene = idle
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                s = area.spaces.active
                s.shading.type = 'MATERIAL'
                s.overlay.show_overlays = True
                s.overlay.show_bones = True
                s.overlay.show_extras = False
                s.overlay.show_relationship_lines = False
                s.region_3d.view_location = Vector((0, 0, 1.25))
                s.region_3d.view_distance = 4.4
                s.region_3d.view_rotation = Vector((-.35, 1, -.14)).to_track_quat('-Z', 'Y')
                s.region_3d.view_perspective = 'ORTHO'
            if area.type == 'DOPESHEET_EDITOR':
                s = area.spaces.active
                s.mode = 'ACTION'
                s.show_region_ui = False
                s.show_pose_markers = True
                s.dopesheet.show_only_selected = False
if 'Animation' in bpy.data.workspaces:
    bpy.context.window.workspace = bpy.data.workspaces['Animation']
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
assert source_hash == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
(QA / 'free-pose-build.json').write_text(json.dumps({
    'source': str(SOURCE), 'source_sha256': source_hash, 'target': str(TARGET),
    'source_unchanged': True, 'geometry_unchanged': True, 'rest_bones_unchanged': True,
    'maximum_starting_pose_matrix_error': max_error, 'scenes': manifest,
    'geometry': geometry, 'rest': rest,
}, indent=2))
print('SAMURAI_FREE_POSE_SAVED', str(TARGET), 'initial pose error', max_error, flush=True)
