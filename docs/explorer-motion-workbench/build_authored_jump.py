"""Connect the confirmed launch/landing and live airborne poses in Blender."""
import bpy,json,datetime,math
from pathlib import Path
from mathutils import Matrix
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/explorer-motion-workbench')
inputs=json.loads((folder/'jump_user_inputs.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
action=rig.animation_data.action
assert action.name=='03_Jump' and not bpy.context.screen.is_animation_playing
def error(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
assert max(error(p.matrix_basis,Matrix(inputs['live_pose']['basis'][p.name])) for p in rig.pose.bones)<1e-4,'Live pose changed after confirmation'
def signature(a):
    return [(fc.data_path,fc.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
others={a.name:signature(a) for a in bpy.data.actions if a!=action}
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Explorer_Before_Connected_Jump_'+stamp+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
backup=action.copy();backup.name='Jump_Before_Connecting_'+stamp;backup.use_fake_user=True
rest={p.name:p.bone.matrix_local.copy() for p in rig.pose.bones}
poses={'launch':{n:Matrix(v) for n,v in inputs['poses']['1']['basis'].items()},'air':{n:Matrix(v) for n,v in inputs['live_pose']['basis'].items()}}
base_action=bpy.data.actions['00_Idle_Approved_Base']
rig.animation_data.action=base_action;rig.animation_data.action_slot=base_action.slots[0]
scene.frame_set(1);bpy.context.view_layer.update()
poses['idle']={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
def worlds(basis):
    values={}
    for pb in rig.pose.bones:
        n=pb.name;parent=pb.parent
        values[n]=values[parent.name]@rest[parent.name].inverted()@rest[n]@basis[n] if parent else rest[n]@basis[n]
    return values
controls={'R':'Right_Blade_Control','L':'Left_Blade_Control'}
grips={label:{side:worlds(pose)['Hand_'+side].inverted()@worlds(pose)[control] for side,control in controls.items()} for label,pose in poses.items()}
def blend(a,b,t):
    pa,qa,sa=a.decompose();pb,qb,sb=b.decompose()
    return Matrix.LocRotScale(pa.lerp(pb,t),qa.slerp(qb,t),sa.lerp(sb,t))
def smooth(t):
    t=max(0.,min(1.,t));return t*t*t*(10+t*(-15+6*t))
anchors=[(1,'launch'),(7,'launch'),(22,'air'),(43,'air'),(60,'air'),(76,'launch'),(80,'launch'),(91,'idle')]
def desired(frame):
    for (fa,la),(fb,lb) in zip(anchors,anchors[1:]):
        if frame<=fb:break
    amount=smooth((frame-fa)/(fb-fa))
    basis={n:blend(poses[la][n],poses[lb][n],amount) for n in rest}
    global_pose=worlds(basis)
    for side,control in controls.items():
        global_pose[control]=global_pose['Hand_'+side]@blend(grips[la][side],grips[lb][side],amount)
        basis[control]=rest[control].inverted()@global_pose[control]
    return basis, {side:blend(grips[la][side],grips[lb][side],amount) for side in controls}
previous={}
def insert(frame):
    for p in rig.pose.bones:
        q=p.rotation_quaternion.copy()
        if p.name in previous and q.dot(previous[p.name])<0:q.negate()
        p.rotation_quaternion=q;previous[p.name]=q.copy()
        for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(data_path=prop,frame=frame,group=p.name)
for label,name in [('launch','Jump_Pose_Launch_Land'),('air','Jump_Pose_Airborne')]:
    pose_action=bpy.data.actions.new(name);pose_action.use_fake_user=True
    rig.animation_data.action=pose_action
    scene.frame_set(1)
    for p in rig.pose.bones:p.matrix_basis=poses[label][p.name]
    previous={};insert(1)
    pose_action.use_frame_range=True;pose_action.frame_start=1;pose_action.frame_end=1
    pose_action.asset_mark();pose_action.asset_data.description='Exact user-authored Explorer '+label+' pose.'
rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
for layer in list(action.layers):action.layers.remove(layer)
for marker in list(action.pose_markers):action.pose_markers.remove(marker)
previous={}
for frame in range(1,92):
    scene.frame_set(frame)
    basis,_=desired(frame)
    for p in rig.pose.bones:p.matrix_basis=basis[p.name]
    insert(frame)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for k in fc.keyframe_points:k.interpolation='LINEAR'
action.use_fake_user=True;action.use_frame_range=True;action.frame_start=1;action.frame_end=91
if hasattr(action,'use_cyclic'):action.use_cyclic=False
action['notes']='User launch/landing pose at frames 1–7 and 76–80; user airborne pose at 22–60. Smooth transitions, hand-relative blade motion, and return to approved idle at frame 91. In-place movement.'
action['launch_pose_action']='Jump_Pose_Launch_Land';action['air_pose_action']='Jump_Pose_Airborne'
markers={'Launch / landing pose':1,'Push off':7,'Airborne pose':22,'Apex':43,'Descent':60,'Land':76,'Recover':80,'Return to idle':91}
scene.timeline_markers.clear()
for label,frame in markers.items():
    action.pose_markers.new(label).frame=frame
    scene.timeline_markers.new(label,frame=frame)
scene.frame_start=1;scene.frame_end=91;scene.render.fps=60
checks={1:'launch',7:'launch',22:'air',43:'air',60:'air',76:'launch',80:'launch',91:'idle'}
exact_error=grip_error=weapon_error=0.;steps=[];prior=None
for frame in range(1,92):
    scene.frame_set(frame);bpy.context.view_layer.update()
    actual={p.name:p.matrix.copy() for p in rig.pose.bones}
    assert all(math.isfinite(v) for m in actual.values() for row in m for v in row)
    if frame in checks:
        target=worlds(poses[checks[frame]])
        exact_error=max(exact_error,max(error(actual[n],target[n]) for n in actual))
    _,expected_grips=desired(frame)
    for side,control in controls.items():
        grip_error=max(grip_error,error(actual['Hand_'+side].inverted()@actual[control],expected_grips[side]))
        weapon=bpy.data.objects['Weapon_Cutlass' if side=='R' else 'Weapon_Pistol']
        weapon_error=max(weapon_error,error(weapon.matrix_world,rig.matrix_world@actual[control]))
    if prior:steps.append(max((actual[n].translation-prior[n].translation).length for n in actual))
    prior=actual
assert max(exact_error,grip_error,weapon_error)<1e-4,(exact_error,grip_error,weapon_error)
assert max(steps)<.4,max(steps)
assert all(signature(bpy.data.actions[n])==sig for n,sig in others.items()),'Another action changed'
report={'source_inputs':str(folder/'jump_user_inputs.json'),'snapshot':str(snapshot),'backup_action':backup.name,'confirmed_mapping':{'launch_landing':'keyed frame 1','airborne':'captured live frame 3'},'anchors':anchors,'markers':markers,'frames_checked':91,'fps':60,'duration_seconds':1.5,'exact_user_pose_error':exact_error,'blade_grip_error':grip_error,'weapon_follow_error':weapon_error,'max_bone_step_m':max(steps),'idle_run_unchanged':True,'in_place':True}
(folder/'authored_jump_verification.json').write_text(json.dumps(report,indent=2)+'\n')
scene.frame_set(1);bpy.context.view_layer.update()
for p in rig.pose.bones:p.select=False
rig.pose.bones['Chest'].select=True;rig.data.bones.active=rig.data.bones['Chest']
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':area.type='VIEW_3D'
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Explorer_Jump.blend'),copy=True)
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Explorer_Animation_Workbench.blend'))
print('EXPLORER_AUTHORED_JUMP_OK',json.dumps(report))
