"""Read back the saved workbench and probe the original stuck-limb symptom."""
from pathlib import Path
import hashlib
import json
import struct
import bpy
from mathutils import Quaternion

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / 'build/Other Files/Samurai Pose Editing'
build = json.loads((QA / 'free-pose-build.json').read_text())
bpy.ops.wm.open_mainfile(filepath=build['target'])
checks = []
probes = []

def check(condition, description):
    checks.append({'check': description, 'pass': bool(condition)})
    assert condition, description

def difference(a, b):
    return max(abs(a[i][j] - b[i][j]) for i in range(4) for j in range(4))

def digest(mesh):
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

check(hashlib.sha256(Path(build['source']).read_bytes()).hexdigest() == build['source_sha256'], 'Old workbench remains unchanged')
check(build['geometry'] == {m.name: digest(m) for m in bpy.data.meshes}, 'All geometry, topology and UVs preserved after reopening')
check(bpy.context.scene.name == '01 — Idle' and bpy.context.scene.frame_current == 0, 'Opens at Idle frame 0')
for sc in bpy.data.scenes:
    rig = next((ob for ob in sc.objects if ob.type == 'ARMATURE'), None)
    if not rig:
        continue
    bpy.context.window.scene = sc
    sc.frame_set(0)
    bpy.context.view_layer.update()
    check(sc.frame_start == 0, sc.name + ': starts at zero')
    check(len(rig.pose.bones) == 23, sc.name + ': 22 original bones and one sword control')
    check(build['rest'] == {n: [list(row) for row in rig.data.bones[n].matrix_local] for n in build['rest']}, sc.name + ': original rest transforms preserved')
    check(not any(p.constraints for p in rig.pose.bones), sc.name + ': no pose constraints')
    check(not any(p.bone.hide or p.bone.hide_select for p in rig.pose.bones), sc.name + ': body bones visible and selectable')
    check(not any(any(p.lock_location) or any(p.lock_rotation) or p.lock_rotation_w or any(p.lock_scale) for p in rig.pose.bones), sc.name + ': no transform locks')
    check(rig.data.bones['Sword_Control'].parent is None, sc.name + ': sword independent of body')
    check(sc.keying_sets.active.bl_idname == 'SamuraiWholePose' and len(sc.keying_sets.active.paths) == 69, sc.name + ': I has complete body-and-sword keying set')
    action = rig.animation_data.action
    curves = [f for l in action.layers for st in l.strips for bag in st.channelbags for f in bag.fcurves]
    check(len(curves) == 230 and all(len(f.keyframe_points) == 1 and f.keyframe_points[0].co.x == 0 for f in curves), sc.name + ': only frame 0 keyed')
    names = ['Chest', 'Head'] + [n + '_' + side for side in ['L', 'R'] for n in ['Arm', 'Forearm', 'Hand', 'Leg', 'Shin', 'Foot']]
    for name in names:
        p = rig.pose.bones[name]
        old = p.matrix_basis.copy()
        before = p.matrix.copy()
        p.rotation_quaternion = p.rotation_quaternion @ Quaternion((0, 0, 1), .25)
        bpy.context.view_layer.update()
        change = difference(p.matrix, before)
        probes.append({'scene': sc.name, 'bone': name, 'rotation_response': change})
        check(change > .05, sc.name + ': ' + name + ' responds directly to rotation')
        p.matrix_basis = old
        bpy.context.view_layer.update()
    sword = rig.pose.bones['Sword_Control']
    old = sword.matrix_basis.copy()
    before = sword.matrix.copy()
    hands = {n: rig.pose.bones[n].matrix.copy() for n in ['Hand_L', 'Hand_R']}
    weapon = next(ob for ob in sc.objects if any(getattr(c, 'target', None) == rig and getattr(c, 'subtarget', '') == 'Sword_Control' for c in ob.constraints))
    weapon_before = weapon.matrix_world.copy()
    sword.location.x += .2
    bpy.context.view_layer.update()
    check(difference(sword.matrix, before) > .19, sc.name + ': sword moves freely')
    check(difference(weapon.matrix_world, weapon_before) > .19, sc.name + ': visible katana follows sword control')
    check(all(difference(rig.pose.bones[n].matrix, m) < 1e-6 for n, m in hands.items()), sc.name + ': sword does not pin or force hands')
    sword.matrix_basis = old
    bpy.context.view_layer.update()

sc = bpy.data.scenes['01 — Idle']
bpy.context.window.scene = sc
sc.frame_set(0)
rig = next(ob for ob in sc.objects if ob.type == 'ARMATURE')
bpy.context.view_layer.objects.active = rig
area = next(a for a in bpy.context.screen.areas if a.type == 'VIEW_3D')
region = next(r for r in area.regions if r.type == 'WINDOW')
with bpy.context.temp_override(area=area, region=region, object=rig, active_object=rig):
    result = bpy.ops.anim.keyframe_insert()
check(result == {'FINISHED'}, 'Whole Pose key-insertion operator succeeds')
(QA / 'free-pose-verification.json').write_text(json.dumps({'passed': len(checks), 'failed': 0, 'checks': checks, 'rotation_probes': probes}, indent=2))
print('SAMURAI_FREE_POSE_VERIFIED', len(checks), 'passed, 0 failed', flush=True)
# Render only the fresh idle for visual inspection; never save the probe edits.
sc.render.resolution_x = 760
sc.render.resolution_y = 840
sc.render.resolution_percentage = 100
sc.render.engine = 'CYCLES'
sc.cycles.samples = 16
sc.cycles.use_denoising = True
sc.render.filepath = str(QA / 'free-pose-idle.png')
bpy.ops.render.render(write_still=True)
