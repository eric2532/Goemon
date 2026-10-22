"""Read back the scarf rig and check it without changing the saved document."""
from pathlib import Path
import importlib.util
import json
import bpy
from mathutils import Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / 'build/Other Files/Samurai Pose Editing'
before = json.loads((QA / 'scarf-before.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'docs/samurai-motion-workbench/Samurai_Animation_Workbench.blend'))
spec = importlib.util.spec_from_file_location('scarf_helpers', str(Path(__file__).with_name('add_scarf_control.py')))
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
checks = []

def check(condition, message):
    assert condition, message
    checks.append(message)

check(before['geometry'] == helpers.geometry_snapshot(), 'All geometry and UVs preserved')
check(before['actions'] == helpers.action_snapshot(), 'All existing action curves and handles preserved')
for sc in bpy.data.scenes:
    rig = next((o for o in sc.objects if o.type == 'ARMATURE'), None)
    if rig is None:
        continue
    bpy.context.window.scene = sc
    for n, m in before['poses'][rig.name].items():
        rig.pose.bones[n].matrix_basis = Matrix(m)
    bpy.context.view_layer.update()
    pb = rig.pose.bones['Scarf_Control']
    scarf = next(o for o in sc.objects if o.type == 'EMPTY' and o.name.startswith('ScarfTail'))
    check(before['rest'][rig.name] == {n: helpers.matrix_list(rig.data.bones[n].matrix_local) for n in before['rest'][rig.name]}, sc.name + ': original rest bones preserved')
    check(pb.parent.name == 'Head' and not pb.bone.use_deform, sc.name + ': separate head-attached scarf control')
    check(not pb.constraints and not any(pb.lock_location) and not any(pb.lock_rotation), sc.name + ': freely editable')
    check(not pb.bone.hide and not pb.bone.hide_select, sc.name + ': selectable and visible')
    check(scarf.parent == rig and scarf.parent_bone == 'Scarf_Control', sc.name + ': cloth attached to new bone')
    direction = rig.matrix_world.to_3x3() @ (pb.tail - pb.head)
    check(direction.normalized().dot(scarf.matrix_world.to_3x3().col[1].normalized()) > .9999, sc.name + ': bone follows cloth direction')
    paths = {p.data_path for p in sc.keying_sets.active.paths}
    check(all(pb.path_from_id(prop) in paths for prop in ['location', 'rotation_quaternion', 'scale']), sc.name + ': included in Whole Pose keying')
    old = pb.matrix_basis.copy()
    world = scarf.matrix_world.copy()
    original_bones = {p.name: p.matrix.copy() for p in rig.pose.bones if p != pb}
    pb.rotation_quaternion = Quaternion((1, 0, 0), .3)
    bpy.context.view_layer.update()
    check(helpers.difference(scarf.matrix_world, world) > .1, sc.name + ': rotation moves cloth')
    check(all(helpers.difference(rig.pose.bones[n].matrix, m) < 1e-5 for n, m in original_bones.items()), sc.name + ': scarf posing leaves body and sword unchanged')
    pb.matrix_basis = old
    bpy.context.view_layer.update()
    head = rig.pose.bones['Head']
    old_head = head.matrix_basis.copy()
    head.rotation_quaternion = head.rotation_quaternion @ Quaternion((0, 0, 1), .3)
    bpy.context.view_layer.update()
    check(helpers.difference(scarf.matrix_world, world) > .1, sc.name + ': scarf follows head')
    head.matrix_basis = old_head

(QA / 'scarf-verification.json').write_text(json.dumps({'passed': len(checks), 'failed': 0, 'checks': checks}, indent=2))
print('SCARF_VERIFIED', len(checks), 'passed, 0 failed', flush=True)
