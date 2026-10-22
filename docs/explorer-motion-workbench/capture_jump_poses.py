"""Preserve the live session, then sample the user's keyed jump poses."""
import bpy,json,datetime
from pathlib import Path
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/explorer-motion-workbench')
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
action=rig.animation_data.action
assert action.name=='03_Jump' and not bpy.context.screen.is_animation_playing
bpy.context.view_layer.update()
current_frame=scene.frame_current
current={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
def capture():
    return {'basis':{p.name:[list(r) for r in p.matrix_basis] for p in rig.pose.bones},'matrix':{p.name:[list(r) for r in p.matrix] for p in rig.pose.bones}}
live=capture()
snapshot=folder/('Explorer_Jump_User_Poses_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
poses={}
for f in [1,2,current_frame]:
    scene.frame_set(f);bpy.context.view_layer.update();poses[str(f)]=capture()
curves=[fc for l in action.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
keyed={str(f):sorted({fc.data_path.split('"')[1] for fc in curves if 'pose.bones[' in fc.data_path and any(abs(k.co.x-f)<.001 for k in fc.keyframe_points)}) for f in [1,2]}
unkeyed={n:max(abs(current[n][i][j]-poses[str(current_frame)]['basis'][n][i][j]) for i in range(4) for j in range(4)) for n in current}
scene.frame_set(current_frame)
for p in rig.pose.bones:p.matrix_basis=current[p.name]
bpy.context.view_layer.update()
result={'source':str(snapshot),'current_frame':current_frame,'live_pose':live,'poses':poses,'keyed_bones':keyed,'unkeyed_current_changes':unkeyed}
(folder/'jump_user_inputs.json').write_text(json.dumps(result,indent=2)+'\n')
print('EXPLORER_JUMP_INPUTS_OK',json.dumps({'source':str(snapshot),'keys':keyed,'unkeyed':{n:v for n,v in unkeyed.items() if v>1e-5}}))
