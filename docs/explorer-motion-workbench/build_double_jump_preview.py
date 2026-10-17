"""Separate editable tuck/front-flip preview; approved clips remain untouched."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
folder=Path(__file__).resolve().parent
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig']
def signature(a):
    return repr([(fc.data_path,fc.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves])
original={a.name:signature(a) for a in bpy.data.actions}
source=rig.animation_data.action
air_action=bpy.data.actions['03_Jump'];rig.animation_data.action=air_action;rig.animation_data.action_slot=air_action.slots[0]
scene.frame_set(43);bpy.context.view_layer.update()
rest={p.name:p.bone.matrix_local.copy() for p in rig.pose.bones}
air={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
controls={'R':'Right_Blade_Control','L':'Left_Blade_Control'}
grips={s:rig.pose.bones['Hand_'+s].matrix.inverted()@rig.pose.bones[c].matrix for s,c in controls.items()}
def worlds(basis):
    out={}
    for p in rig.pose.bones:
        n=p.name;par=p.parent
        out[n]=out[par.name]@rest[par.name].inverted()@rest[n]@basis[n] if par else rest[n]@basis[n]
    return out
def blend(a,b,t):
    pa,qa,sa=a.decompose();pb,qb,sb=b.decompose()
    return Matrix.LocRotScale(pa.lerp(pb,t),qa.slerp(qb,t),sa.lerp(sb,t))
def smooth(t):
    t=max(0.,min(1.,t));return t*t*t*(10+t*(-15+6*t))
tuck={n:m.copy() for n,m in air.items()}
def bend(n,degrees):
    qrest=rest[n].to_quaternion()
    local=qrest.inverted()@Quaternion((1,0,0),math.radians(degrees))@qrest
    tuck[n]=local.to_matrix().to_4x4()
for n,angle in [('Pelvis',-8),('Spine',-7),('SpineMid',-8),('Chest',-8),('Neck',8),('Head',-20),('Leg_L',115),('Leg_R',115),('Shin_L',-150),('Shin_R',-150),('Foot_L',15),('Foot_R',15)]:bend(n,angle)
def aim(n,direction):
    glob=worlds(tuck);p=rig.pose.bones[n];par=p.parent
    restq=rest[n].to_quaternion();basey=restq@Vector((0,1,0))
    targetq=basey.rotation_difference(Vector(direction).normalized())@restq
    target=Matrix.LocRotScale(glob[n].translation,targetq,Vector((1,1,1)))
    tuck[n]=rest[n].inverted()@rest[par.name]@glob[par.name].inverted()@target
for side,sign in [('L',-1),('R',1)]:
    aim('Arm_'+side,(sign*.16,-.30,-1))
    aim('Forearm_'+side,(-sign*.25,.80,-.30))
    tuck['Hand_'+side]=Matrix.Identity(4)
action=bpy.data.actions.new('04_Double_Jump_Flip_Preview');action.use_fake_user=True
rig.animation_data.action=action
previous={};angles=[];expected={}
pivot=Vector((0,.04,1.18))
for frame in range(1,50):
    scene.frame_set(frame)
    amount=smooth((frame-1)/8) if frame<=9 else 1.-smooth((frame-37)/12)
    amount=max(0.,min(1.,amount))
    angle=-math.tau*smooth((frame-5)/34);angles.append(angle)
    basis={n:blend(air[n],tuck[n],amount) for n in rest}
    spin=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,'X')@Matrix.Translation(-pivot)
    basis['Root']=rest['Root'].inverted()@spin@rest['Root']@basis['Root']
    glob=worlds(basis)
    for side,control in controls.items():
        basis[control]=rest[control].inverted()@glob['Hand_'+side]@grips[side]
    expected[frame]=basis
    for p in rig.pose.bones:
        p.matrix_basis=basis[p.name]
        q=p.rotation_quaternion.copy()
        if p.name in previous and q.dot(previous[p.name])<0:q.negate()
        p.rotation_quaternion=q;previous[p.name]=q.copy()
        for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(data_path=prop,frame=frame,group=p.name)
for l in action.layers:
    for s in l.strips:
        for bag in s.channelbags:
            for fc in bag.fcurves:
                for k in fc.keyframe_points:k.interpolation='LINEAR'
action.use_frame_range=True;action.frame_start=1;action.frame_end=49
action['notes']='BLENDER PREVIEW ONLY: 0.8-second tucked forward 360 somersault for Explorer double jump. Air pose at 1 and 49; tuck at 9; full turn by 39. No gameplay integration yet.'
action.asset_mark();action.asset_data.description=action['notes']
markers={'Air / second jump':1,'Tuck knees':9,'Quarter turn':16,'Upside down':22,'Three-quarter turn':28,'Full 360':39,'Open / airborne':49}
scene.timeline_markers.clear()
for label,frame in markers.items():
    action.pose_markers.new(label).frame=frame;scene.timeline_markers.new(label,frame=frame)
scene.render.fps=60;scene.frame_start=1;scene.frame_end=49
scene.tool_settings.use_keyframe_insert_auto=False
def err(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
grip_error=pose_error=seam_error=0.;maxstep=0.;prior=None
for f in range(1,50):
    scene.frame_set(f);bpy.context.view_layer.update()
    actual={p.name:p.matrix.copy() for p in rig.pose.bones};target=worlds(expected[f])
    pose_error=max(pose_error,max(err(actual[n],target[n]) for n in actual))
    for s,c in controls.items():grip_error=max(grip_error,err(actual['Hand_'+s].inverted()@actual[c],grips[s]))
    if prior:maxstep=max(maxstep,max((actual[n].translation-prior[n].translation).length for n in actual))
    prior=actual
    if f in [1,49]:seam_error=max(seam_error,max(err(actual[n],worlds(air)[n]) for n in actual))
assert max(pose_error,grip_error,seam_error)<1e-4
assert all(signature(bpy.data.actions[n])==sig for n,sig in original.items())
assert abs(angles[-1]-angles[0]+math.tau)<1e-6
report={'preview_only':True,'action':action.name,'frames_checked':49,'fps':60,'duration_seconds':.8,'turn_degrees':360,'direction':'forward somersault','pose_error':pose_error,'blade_grip_error':grip_error,'airborne_endpoint_error':seam_error,'max_bone_step_m':maxstep,'all_existing_actions_preserved':True,'source_snapshot':bpy.data.filepath,'markers':markers}
(folder/'double_jump_preview_verification.json').write_text(json.dumps(report,indent=2)+'\n')
guide=bpy.data.texts.new('DOUBLE JUMP — Flip Preview')
guide.write(action['notes']+'\n\nSpace plays / pauses. Playback 1–49 at 60 fps.\nScrub markers for tuck, inverted pose, full turn, and open.\nApproved idle, run, and regular jump actions are unchanged.\n')
for a in bpy.context.screen.areas:
    if a.type=='CONSOLE':a.type='VIEW_3D'
    if a.type=='VIEW_3D':
        sp=a.spaces.active;sp.region_3d.view_location=Vector((0,0,1.18));sp.region_3d.view_distance=4.7
        direction=Vector((-1,.35,-.10)) if a.x<400 else Vector((-1,1,-.20))
        sp.region_3d.view_rotation=direction.to_track_quat('-Z','Y');sp.region_3d.view_perspective='ORTHO'
        sp.overlay.show_floor=False;sp.overlay.show_axis_x=False;sp.overlay.show_axis_y=False
        if a.x<400:sp.overlay.show_overlays=False
for p in rig.pose.bones:p.select=False
rig.pose.bones['Pelvis'].select=True;rig.data.bones.active=rig.data.bones['Pelvis']
scene.frame_set(9);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Explorer_Double_Jump_Preview.blend'))
print('EXPLORER_DOUBLE_JUMP_PREVIEW_OK',json.dumps(report))
