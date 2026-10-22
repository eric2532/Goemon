"""Hold the user's frame-1 right arm throughout the existing run cycle."""
import bpy,json,datetime,math
from pathlib import Path
from mathutils import Matrix
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/explorer-motion-workbench')
source=json.loads((folder/'run_right_arm_input.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
action=rig.animation_data.action
assert action.name=='02_Run' and scene.frame_current==1
assert not bpy.context.screen.is_animation_playing
arm=['Clavicle_R','Arm_R','Forearm_R','Hand_R']
targets=arm+['Right_Blade_Control']
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
assert max(err(rig.pose.bones[n].matrix_basis,Matrix(source['bones'][n]['basis'])) for n in arm)<1e-5,'Pose changed after capture'
base={n:Matrix(source['bones'][n]['basis']) for n in arm}
hand_blade=Matrix(source['bones']['Hand_R']['matrix']).inverted()@Matrix(source['bones']['Right_Blade_Control']['matrix'])
def signature(a):
    return [(fc.data_path,fc.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
others={a.name:signature(a) for a in bpy.data.actions if a!=action}
backup=action.copy();backup.name='Run_Before_Right_Arm_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S');backup.use_fake_user=True
before={}
for f in range(1,42):
    scene.frame_set(f);bpy.context.view_layer.update()
    before[f]={p.name:p.matrix.copy() for p in rig.pose.bones if p.name not in targets}
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in list(bag.fcurves):
                if any(fc.data_path.startswith('pose.bones["'+n+'"]') for n in targets):bag.fcurves.remove(fc)
previous={}
def key(pb,f):
    q=pb.rotation_quaternion.copy()
    if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
    pb.rotation_quaternion=q;previous[pb.name]=q.copy()
    for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=prop,frame=f,group=pb.name)
for f in range(1,42):
    scene.frame_set(f)
    for n in arm:rig.pose.bones[n].matrix_basis=base[n]
    bpy.context.view_layer.update()
    rig.pose.bones['Right_Blade_Control'].matrix=rig.pose.bones['Hand_R'].matrix@hand_blade
    for n in targets:key(rig.pose.bones[n],f)
    # Preserve the user's separate left-blade adjustment at the loop boundary.
    if f in [1,41]:
        rig.pose.bones['Left_Blade_Control'].matrix_basis=Matrix(source['bones']['Left_Blade_Control']['basis'])
        key(rig.pose.bones['Left_Blade_Control'],f)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                if any(fc.data_path.startswith('pose.bones["'+n+'"]') for n in targets):
                    for k in fc.keyframe_points:k.interpolation='LINEAR'
arm_error=grip_error=other_error=0.;seam=0.;first=None
for f in range(1,42):
    scene.frame_set(f);bpy.context.view_layer.update()
    arm_error=max(arm_error,max(err(rig.pose.bones[n].matrix_basis,base[n]) for n in arm))
    grip=rig.pose.bones['Hand_R'].matrix.inverted()@rig.pose.bones['Right_Blade_Control'].matrix
    grip_error=max(grip_error,err(grip,hand_blade))
    for n,p in before[f].items():
        if n!='Left_Blade_Control':other_error=max(other_error,err(rig.pose.bones[n].matrix,p))
    if f==1:first={p.name:p.matrix.copy() for p in rig.pose.bones}
    if f==41:seam=max(err(p.matrix,first[p.name]) for p in rig.pose.bones)
assert max(arm_error,grip_error,other_error,seam)<1e-4,(arm_error,grip_error,other_error,seam)
assert all(signature(bpy.data.actions[n])==sig for n,sig in others.items()),'Another action changed'
scene.frame_set(1);bpy.context.view_layer.update()
source_error=max(err(rig.pose.bones[n].matrix,Matrix(source['bones'][n]['matrix'])) for n in targets+['Left_Blade_Control'])
assert source_error<1e-4,source_error
scene.frame_start=1;scene.frame_end=40;scene.render.fps=60
action['notes']='User frame-1 right arm held relative to the torso throughout the run. Right blade follows the hand. Left blade endpoint edits preserved.'
report={'frames_checked':41,'arm_basis_error':arm_error,'right_blade_grip_error':grip_error,'other_body_bones_error':other_error,'loop_seam_error':seam,'source_pose_error':source_error,'other_actions_preserved':True,'backup_action':backup.name,'snapshot':source['snapshot'],'arm_bones':arm,'playback_range':[1,40]}
(folder/'run_right_arm_verification.json').write_text(json.dumps(report,indent=2)+'\n')
for p in rig.pose.bones:p.select=False
rig.pose.bones['Arm_R'].select=True;rig.data.bones.active=rig.data.bones['Arm_R']
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':area.type='VIEW_3D'
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Explorer_Run.blend'),copy=True)
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Explorer_Animation_Workbench.blend'))
print('EXPLORER_RUN_RIGHT_ARM_OK',json.dumps(report))
