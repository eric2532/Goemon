"""Build the complete strike around the preserved, user-approved hit pose.
Run in background Blender; only writes a separate review workbench.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
inputs=json.loads((folder/'approved_strike_inputs.json').read_text())
bpy.ops.wm.open_mainfile(filepath=inputs['snapshot'],load_ui=True)
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
start={n:Matrix(m) for n,m in inputs['start']['basis'].items()}
hit={n:Matrix(m) for n,m in inputs['contact']['basis'].items()}
start_global={n:Matrix(m) for n,m in inputs['start']['bones'].items()}
hit_global={n:Matrix(m) for n,m in inputs['contact']['bones'].items()}
rest={pb.name:pb.bone.matrix_local.copy() for pb in rig.pose.bones}
original=rig.animation_data.action
assert original.name=='03_Lance_Thrust_1'
backup=original.copy();backup.name='Thrust_Before_Approved_Core';backup.use_fake_user=True

# Preserve both authored poses as independent reusable actions.
def key_pose(frame):
    for pb in rig.pose.bones:
        for prop in ('location','rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_euler','scale'):
            pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)

def pose_asset(name,poses,note):
    action=bpy.data.actions.new(name);action.use_fake_user=True
    rig.animation_data.action=action
    for pb in rig.pose.bones:pb.matrix_basis=poses[pb.name]
    key_pose(1)
    action.use_frame_range=True;action.frame_start=1;action.frame_end=1
    action.asset_mark();action.asset_data.description=note;action['notes']=note
    return action
start_asset=pose_asset('Poke_Start_Approved',start,'User-defined starting position from frame 1.')
hit_asset=pose_asset('Poke_Hit_Approved',hit,'Core hit pose approved by the user: preserve the arms, leg stance, head and lance together.')
rig.animation_data.action=original
for layer in list(original.layers):original.layers.remove(layer)
for marker in list(original.pose_markers):original.pose_markers.remove(marker)

# Monotone cubic timing gives continuous movement without overshooting either
# authored pose. Arms prepare first; the planted lunge follows through impact.
knots=[(1,0,0,0,0),(3,.05,.40,.10,.65),(5,.40,.78,.50,.95),(7,1,1,1,1),(9,1,1,1,1),(12,.90,.65,.95,.95),(17,.50,.20,.55,.40),(23,0,0,0,0)]
def weight(frame,column):
    xs=[k[0] for k in knots];ys=[k[column] for k in knots]
    slopes=[(ys[i+1]-ys[i])/(xs[i+1]-xs[i]) for i in range(len(xs)-1)]
    tangents=[0.0]
    for i in range(1,len(xs)-1):
        a,b=slopes[i-1],slopes[i]
        if a*b<=0:tangents.append(0.0)
        else:
            h0=xs[i]-xs[i-1];h1=xs[i+1]-xs[i]
            w1=2*h1+h0;w2=h1+2*h0
            tangents.append((w1+w2)/(w1/a+w2/b))
    tangents.append(0.0)
    if frame<=xs[0]:return ys[0]
    if frame>=xs[-1]:return ys[-1]
    i=next(i for i in range(len(xs)-1) if xs[i]<=frame<=xs[i+1])
    h=xs[i+1]-xs[i];t=(frame-xs[i])/h
    return (2*t**3-3*t*t+1)*ys[i]+(t**3-2*t*t+t)*h*tangents[i]+(-2*t**3+3*t*t)*ys[i+1]+(t**3-t*t)*h*tangents[i+1]

def blend(a,b,t):
    la,qa,sa=a.decompose();lb,qb,sb=b.decompose()
    return Matrix.LocRotScale(la.lerp(lb,t),qa.slerp(qb,t),sa.lerp(sb,t))

start_grip_point=start_global['Lance_Control'].inverted()@start_global['Hand_R'].translation
hit_grip_point=hit_global['Lance_Control'].inverted()@hit_global['Hand_R'].translation
previous={}
for frame in range(1,24):
    scene.frame_set(frame)
    body,arms,legs,lance=[weight(frame,column) for column in range(1,5)]
    poses={}
    for pb in rig.pose.bones:
        name=pb.name
        amount=arms if name.startswith(('Clavicle_','Arm_','Forearm_','Hand_')) else legs if name in ('Root','Pelvis') or name.startswith(('Leg_','Shin_','Foot_')) else body
        basis=blend(start[name],hit[name],amount)
        parent=pb.parent
        poses[name]=(poses[parent.name]@rest[parent.name].inverted()@rest[name]@basis) if parent else rest[name]@basis
        pb.matrix_basis=basis
    # The shaft rotates into line before impact; its pivot travels with the hand.
    attachment=min(1.0,max(0.0,(frame-1)/2.0)) if frame<=3 else 1.0 if frame<=17 else max(0.0,(23-frame)/6.0)
    attachment=attachment*attachment*(3-2*attachment)
    grip_point=start_grip_point.lerp(hit_grip_point,attachment)
    _,q0,s0=start_global['Lance_Control'].decompose();_,q1,s1=hit_global['Lance_Control'].decompose()
    weapon_pose=Matrix.LocRotScale(Vector((0,0,0)),q0.slerp(q1,lance),s0.lerp(s1,lance))
    weapon_pose.translation=poses['Hand_R'].translation-weapon_pose.to_3x3()@grip_point
    rig.pose.bones['Lance_Control'].matrix_basis=rest['Lance_Control'].inverted()@weapon_pose
    # Force exact authored endpoints, including all leg and lance components.
    exact=start if frame in (1,23) else hit if frame in (7,8,9) else None
    if exact:
        for pb in rig.pose.bones:pb.matrix_basis=exact[pb.name]
    for pb in rig.pose.bones:
        if pb.rotation_mode=='QUATERNION':
            q=pb.rotation_quaternion.copy()
            if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
            pb.rotation_quaternion=q;previous[pb.name]=q.copy()
    key_pose(frame)
    bpy.context.view_layer.update()
for layer in original.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
original.use_fake_user=True;original.use_frame_range=True;original.frame_start=1;original.frame_end=23
original['approved_core_action']=hit_asset.name
original['approved_start_action']=start_asset.name
original['contact_frame']=7
original['notes']='Frame 1: user start. Frames 7–9: exact approved full-body core hit including leg stance. Frame 23: return to start. This Blender animation is not yet integrated into the game.'
for label,frame in [('START — user pose',1),('Prepare lance',3),('Thrust',5),('HIT — approved core',7),('Hold impact',9),('Withdraw lance',12),('Recover stance',17),('Return to start',23)]:original.pose_markers.new(label).frame=frame
scene.timeline_markers.clear();scene.frame_start=1;scene.frame_end=23;scene.render.fps=60
scene['dragoon_strike_core']='Poke_Hit_Approved: full-body core must remain intact at impact.'

# Fresh verification checks both poses, lunge legs, live weapon, and closed recovery.
max_start_error=0.;max_hit_error=0.;max_end_error=0.;positions=[];contact_leg_error=0.
for frame in range(1,24):
    scene.frame_set(frame);bpy.context.view_layer.update()
    expected=start_global if frame in (1,23) else hit_global if frame in (7,8,9) else None
    if expected:
        error=max(abs(pb.matrix[i][j]-expected[pb.name][i][j]) for pb in rig.pose.bones for i in range(4) for j in range(4))
        if frame==1:max_start_error=error
        elif frame==23:max_end_error=error
        else:max_hit_error=max(max_hit_error,error)
    if frame in (7,8,9):
        contact_leg_error=max(contact_leg_error,max(abs(rig.pose.bones[name].matrix[i][j]-hit_global[name][i][j]) for name in ('Leg_L','Shin_L','Foot_L','Leg_R','Shin_R','Foot_R') for i in range(4) for j in range(4)))
    assert all(math.isfinite(v) for pb in rig.pose.bones for row in pb.matrix for v in row)
    positions.append(list(rig.pose.bones['Lance_Control'].matrix.translation))
assert max(max_start_error,max_hit_error,max_end_error,contact_leg_error)<1e-4,(max_start_error,max_hit_error,max_end_error,contact_leg_error)
report={'action':original.name,'core_pose_action':hit_asset.name,'start_pose_action':start_asset.name,'source_file':inputs['snapshot'],'frames':23,'fps':60,'contact_frame':7,'exact_core_hold':[7,8,9],'start_error':max_start_error,'hit_pose_error':max_hit_error,'leg_pose_error':contact_leg_error,'recovery_error':max_end_error,'all_frames_finite':True}
(folder/'full_strike_verification.json').write_text(json.dumps(report,indent=2)+'\n')
(folder/'DRAGOON_ATTACK_NOTES.txt').write_text(original['notes']+'\n\nCore pose source: '+inputs['snapshot']+'\nPose assets: '+start_asset.name+', '+hit_asset.name+'\n')
scene.frame_set(7);bpy.context.view_layer.update()
for pb in rig.pose.bones:pb.select=False
rig.pose.bones['Chest'].select=True;rig.data.bones.active=rig.data.bones['Chest']
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        for area in screen.areas:
            if area.type=='CONSOLE':area.type='VIEW_3D'
            if area.type=='DOPESHEET_EDITOR' and workspace.name=='Animation':
                area.spaces.active.mode='ACTION';area.spaces.active.show_pose_markers=True
output=folder/'Dragoon_Full_Strike.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('DRAGOON_FULL_STRIKE_OK',json.dumps(report))
