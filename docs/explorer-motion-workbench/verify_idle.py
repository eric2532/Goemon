"""Verify the saved idle against the captured user pose and original clips."""
import bpy, json, math
from pathlib import Path
from mathutils import Matrix
folder=Path(__file__).resolve().parent
report=json.loads((folder/'breathing_idle_verification.json').read_text())
approved=json.loads((folder/'approved_idle_pose.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
def use(name,frame):
    action=bpy.data.actions[name]
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    scene.frame_set(frame);bpy.context.view_layer.update()
def error(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def signature(action):
    return [(curve.data_path,curve.array_index,[(tuple(p.co),tuple(p.handle_left),tuple(p.handle_right),p.interpolation) for p in curve.keyframe_points]) for layer in action.layers for strip in layer.strips for bag in strip.channelbags for curve in bag.fcurves]
use('00_Idle_Approved_Base',1)
base={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
assert max(error(rig.pose.bones[n].matrix_basis,Matrix(v)) for n,v in approved.items())<1e-5
weapons={'R':bpy.data.objects['Weapon_Cutlass'],'L':bpy.data.objects['Weapon_Pistol']}
grips={s:(rig.matrix_world@base['Hand_'+s]).inverted()@w.matrix_world for s,w in weapons.items()}
neutral=feet=grip=seam=0.;rise=[]
for frame in range(1,218):
    use('01_Idle',frame)
    poses={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
    assert all(math.isfinite(v) for p in poses.values() for row in p for v in row)
    if frame in [1,109,217]:neutral=max(neutral,max(error(poses[n],base[n]) for n in base))
    for n in ['Root','Pelvis','Leg_L','Shin_L','Foot_L','Leg_R','Shin_R','Foot_R']:feet=max(feet,error(poses[n],base[n]))
    for s,w in weapons.items():grip=max(grip,error((rig.matrix_world@poses['Hand_'+s]).inverted()@w.matrix_world,grips[s]))
    rise.append((poses['Chest'].translation-base['Chest'].translation).length)
    if frame==1:first=poses
    if frame==217:seam=max(error(poses[n],first[n]) for n in poses)
assert max(neutral,feet,grip,seam)<1e-4,(neutral,feet,grip,seam)
assert .003<max(rise)<.025
originals={n:signature(bpy.data.actions[n]) for n in ['02_Run','03_Jump']}
with bpy.data.libraries.load(report['backup_file']) as (src,dst):dst.actions=list(originals)
for action in dst.actions:
    name=action.name.rsplit('.',1)[0]
    assert signature(action)==originals[name],name+' changed'
verified={'frames_checked':217,'user_pose_error':neutral,'planted_feet_error':feet,'blade_grip_error':grip,'loop_seam_error':seam,'max_chest_movement_m':max(rise),'run_jump_unchanged':True,'saved_file':bpy.data.filepath}
(folder/'idle_saved_verification.json').write_text(json.dumps(verified,indent=2)+'\n')
print('EXPLORER_IDLE_SAVED_OK',json.dumps(verified))
