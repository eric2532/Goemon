"""Use Explorer's approved idle arms on the equipped pirate Blender draft.

Imported by build_pirate_weapons.py. Only the arm chains and weapon parenting
change; the shared mesh, rest skeleton, face, costume and Explorer stay intact.
"""
import bpy
import json
from pathlib import Path
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[1]
POSE = ROOT / 'docs/explorer-motion-workbench/approved_idle_pose.json'
ARM_BONES = [name + '_' + side for side in ['L', 'R']
             for name in ['Clavicle', 'Arm', 'Forearm', 'Hand']]


def apply_idle_arm_pose(rig, weapon_roots):
    source = json.loads(POSE.read_text())
    bpy.context.view_layer.update()
    grips = {}
    for name, side in [('Weapon_Cutlass', 'R'), ('Weapon_Pistol', 'L')]:
        hand = rig.matrix_world @ rig.pose.bones['Hand_' + side].matrix
        grips[name] = hand.inverted() @ weapon_roots[name].matrix_world
    for name in ARM_BONES:
        rig.pose.bones[name].matrix_basis = Matrix(source[name])
    bpy.context.view_layer.update()
    for name, side in [('Weapon_Cutlass', 'R'), ('Weapon_Pistol', 'L')]:
        ob = weapon_roots[name]
        hand = rig.matrix_world @ rig.pose.bones['Hand_' + side].matrix
        desired = hand @ grips[name]
        ob.parent = rig
        ob.parent_type = 'BONE'
        ob.parent_bone = 'Hand_' + side
        bpy.context.view_layer.update()
        ob.matrix_world = desired
    bpy.context.view_layer.update()
    errors = {name: max(abs(rig.pose.bones[name].matrix_basis[i][j] - source[name][i][j])
                       for i in range(4) for j in range(4)) for name in ARM_BONES}
    assert max(errors.values()) < .00001, errors
    for name, side in [('Weapon_Cutlass', 'R'), ('Weapon_Pistol', 'L')]:
        hand = rig.matrix_world @ rig.pose.bones['Hand_' + side].matrix
        actual = hand.inverted() @ weapon_roots[name].matrix_world
        assert max(abs(actual[i][j] - grips[name][i][j]) for i in range(4) for j in range(4)) < .00001, name
    bpy.context.scene['idle_arm_pose_source'] = str(POSE.relative_to(ROOT))
    bpy.context.scene['idle_arm_pose_max_error'] = max(errors.values())
    return {'source': str(POSE.relative_to(ROOT)), 'copied_bones': ARM_BONES,
            'max_matrix_error': max(errors.values()), 'hand_grips_preserved': True}
