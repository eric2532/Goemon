import bpy,json
from pathlib import Path
from mathutils import Matrix
folder=Path(__file__).resolve().parent
source=json.loads((folder/'run_both_arms_input.json').read_text())
report=json.loads((folder/'run_both_arms_verification.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
assert rig.animation_data.action.name=='02_Run'
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def signature(a,exclude=[]):
    return [(fc.data_path,fc.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves if not any(fc.data_path.startswith('pose.bones["'+n+'"]') for n in exclude)]
controls={'R':'Right_Blade_Control','L':'Left_Blade_Control'}
target={s:Matrix(source['bones']['Hand_'+s]['matrix']).inverted()@Matrix(source['bones'][control]['matrix']) for s,control in controls.items()}
arm_error=grip_error=0.;first=None
for f in range(1,42):
    scene.frame_set(f);bpy.context.view_layer.update()
    arm_error=max(arm_error,max(err(rig.pose.bones[n].matrix_basis,Matrix(source['bones'][n]['basis'])) for n in report['arm_bones']))
    for side,control in controls.items():
        grip_error=max(grip_error,err(rig.pose.bones['Hand_'+side].matrix.inverted()@rig.pose.bones[control].matrix,target[side]))
    if f==1:first={p.name:p.matrix.copy() for p in rig.pose.bones}
seam=max(err(p.matrix,first[p.name]) for p in rig.pose.bones)
assert max(arm_error,grip_error,seam)<1e-4
old_run=bpy.data.actions[report['backup_action']]
excluded=report['arm_bones']+['Right_Blade_Control','Left_Blade_Control']
assert signature(old_run,excluded)==signature(bpy.data.actions['02_Run'],excluded)
other_names=['01_Idle','00_Idle_Approved_Base','03_Jump']
current={n:signature(bpy.data.actions[n]) for n in other_names}
with bpy.data.libraries.load(source['snapshot']) as (src,dst):dst.actions=other_names
for a in dst.actions:assert signature(a)==current[a.name.rsplit('.',1)[0]],a.name
result={'frames_checked':41,'arm_pose_error':arm_error,'blade_grip_error':grip_error,'loop_seam_error':seam,'other_run_channels_unchanged':True,'idle_and_jump_unchanged':True,'file':bpy.data.filepath}
(folder/'run_both_arms_saved_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('EXPLORER_RUN_BOTH_ARMS_SAVED_OK',json.dumps(result))
