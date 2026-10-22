"""Run in the user's open Blender; preserve approved idle frame 0 exactly."""
import bpy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT=Path('/Users/eric/Desktop/Projects_Codex/Sonic')
QA=ROOT/'build/Other Files/Pirate Weapons/Motion'
QA.mkdir(parents=True,exist_ok=True)
EXPECTED=ROOT/'docs/pirate-motion-workbench/Pirate_Animation_Workbench.blend'
assert Path(bpy.data.filepath)==EXPECTED,'Unexpected live Blender file; stopped without changes'
assert not bpy.context.screen.is_animation_playing,'Stop playback before copying the live pose'
idle_scene=bpy.context.scene
assert idle_scene.name=='01 — Idle','Expected the Idle scene'
idle_rig=next(ob for ob in idle_scene.objects if ob.type=='ARMATURE')
assert idle_rig.animation_data.action.name=='01_Idle','Expected the approved Idle action'
# Preserve all live data, then evaluate the exact frame the user specified.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(EXPECTED))
idle_scene.frame_set(0);bpy.context.view_layer.update()
live_basis={p.name:p.matrix_basis.copy() for p in idle_rig.pose.bones}
bpy.context.view_layer.update()

def find_root(scene,prefix):
    return next(ob for ob in scene.objects if ob.type=='EMPTY' and (ob.name==prefix or ob.name.startswith(prefix+'.')))

live_grips={s:(idle_rig.matrix_world@idle_rig.pose.bones['Hand_'+s].matrix).inverted()@find_root(idle_scene,n).matrix_world
            for s,n in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]}

def signature(action):
    return [(fc.data_path,fc.array_index,[(list(k.co),list(k.handle_left),list(k.handle_right),k.interpolation) for k in fc.keyframe_points])
            for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]

before={a.name:signature(a) for a in bpy.data.actions}
payload={'file':bpy.data.filepath,'scene':idle_scene.name,'frame':idle_scene.frame_current,
         'active_action':idle_rig.animation_data.action.name,
         'basis':{n:[list(row) for row in m] for n,m in live_basis.items()},
         'hand_grips':{s:[list(row) for row in m] for s,m in live_grips.items()}}
(QA/'user-idle-frame-0.json').write_text(json.dumps(payload,indent=2)+'\n')
for action in bpy.data.actions:action.use_fake_user=True
source_action=idle_rig.animation_data.action
idle_action=bpy.data.actions['01_Idle']
error=lambda a,b:max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
assert max(error(p.matrix_basis,live_basis[p.name]) for p in idle_rig.pose.bones)<1e-5,'Idle pose changed'
idle_action['user_approved_frame']=0
idle_action['user_idle_capture']='build/Other Files/Pirate Weapons/Motion/user-idle-frame-0.json'

jump_scene=bpy.data.scenes['02 — Jump'];bpy.context.window.scene=jump_scene
rig=next(ob for ob in jump_scene.objects if ob.type=='ARMATURE')
data=json.loads((ROOT/'assets/animations/explorer_approved.json').read_text())
source_path=ROOT/data['source']
assert hashlib.sha256(source_path.read_bytes()).hexdigest()==data['source_sha256'],'Explorer export is stale'
names=data['bones'];rest={n:rig.data.bones[n].matrix_local.copy() for n in names}
for n in names:
    assert error(rest[n],idle_rig.data.bones[n].matrix_local)<1e-6,'Incompatible rest skeleton'
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));ci=c.inverted()

def unpack(v):
    return Matrix.LocRotScale(Vector(v[:3]),Quaternion((v[6],v[3],v[4],v[5])),Vector(v[7:10]))

def sample_basis(sample):
    poses={}
    for n,v in zip(names,sample['bones']):
        m=ci@unpack(v)@c;translation=m.translation.copy()
        m=(m.to_3x3()@rest[n].to_3x3()).to_4x4();m.translation=translation
        poses[n]=m
    result={}
    for n in names:
        parent=rig.data.bones[n].parent
        result[n]=rest[n].inverted()@rest[parent.name]@poses[parent.name].inverted()@poses[n] if parent else rest[n].inverted()@poses[n]
    return result

action=bpy.data.actions.new('02_Jump_Explorer');action.use_fake_user=True
rig.animation_data.action=action
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
previous={};targets={}
for index,sample in enumerate(data['clips']['jump']['frames']):
    frame=index+1;jump_scene.frame_set(frame)
    basis=sample_basis(sample)
    # Keep Explorer's launch, airborne and landing poses; recover to the user's idle.
    t=max(0,min(1,(frame-80)/11));weight=t*t*t*(10+t*(-15+6*t))
    for n in names:
        basis[n]=basis[n].lerp(live_basis[n],weight)
        rig.pose.bones[n].matrix_basis=basis[n]
    bpy.context.view_layer.update()
    for side,control in [('R','Sword_Control'),('L','Gun_Control')]:
        rig.pose.bones[control].matrix=rig.pose.bones['Hand_'+side].matrix@live_grips[side]
    bpy.context.view_layer.update()
    targets[frame]={n:rig.pose.bones[n].matrix_basis.copy() for n in names}
    for pb in rig.pose.bones:
        q=pb.rotation_quaternion.copy()
        if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
        pb.rotation_quaternion=q;previous[pb.name]=q.copy()
        for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)
action.use_frame_range=True;action.frame_start=1;action.frame_end=91
markers={'Launch / landing':1,'Push off':7,'Airborne':22,'Apex':43,'Descent':60,'Land':76,'Recover':80,'User idle':91}
jump_scene.timeline_markers.clear()
for label,frame in markers.items():
    jump_scene.timeline_markers.new(label,frame=frame);action.pose_markers.new(label).frame=frame
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for key in fc.keyframe_points:key.interpolation='LINEAR'
jump_scene.frame_start=1;jump_scene.frame_end=91;jump_scene.render.fps=60
jump_scene['clip']='02_Jump_Explorer'
jump_scene['jump_source']='Explorer user-approved jump; in place; returns to pirate user idle at frame 91.'
action.asset_mark();action.asset_data.description=jump_scene['jump_source']

max_pose_error=0;max_grip_error=0
for frame in range(1,92):
    jump_scene.frame_set(frame);bpy.context.view_layer.update()
    max_pose_error=max(max_pose_error,max(error(rig.pose.bones[n].matrix_basis,targets[frame][n]) for n in names))
    for side,prefix in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]:
        hand=rig.matrix_world@rig.pose.bones['Hand_'+side].matrix
        weapon=find_root(jump_scene,prefix)
        max_grip_error=max(max_grip_error,error(hand.inverted()@weapon.matrix_world,live_grips[side]))
assert max(max_pose_error,max_grip_error)<1e-4,(max_pose_error,max_grip_error)
assert all(signature(bpy.data.actions[name])==value for name,value in before.items()),'An existing motion changed'
assert source_action.name=='01_Idle' or signature(source_action)==before[source_action.name]
# Update only the Jump camera and review frame in the open session.
spec=importlib.util.spec_from_file_location('pirate_sizes',ROOT/'tools/pirate_weapon_sizes.py')
sizes=importlib.util.module_from_spec(spec);spec.loader.exec_module(sizes)
center,scale=sizes.fit_camera(jump_scene,sorted({*range(1,92,6),*markers.values()}))
jump_scene.frame_set(22);bpy.context.view_layer.update()
jump_scene.render.filepath=str(QA/'Explorer_Jump_Airborne.png')
bpy.ops.render.render(write_still=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_location=center
            area.spaces.active.region_3d.view_distance=max(5,scale*1.4)
report={'user_idle_frame_0_preserved':True,'original_live_action_preserved':source_action.name,
        'other_actions_unchanged':True,'source':str(source_path),'source_sha256':data['source_sha256'],
        'jump_action':action.name,'frames_checked':91,'body_pose_error':max_pose_error,
        'weapon_hand_grip_error':max_grip_error,'in_place':True,'recovery':'User idle at frame 91',
        'file':str(EXPECTED)}
(QA/'explorer-jump-live-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PIRATE_EXPLORER_JUMP_APPLIED',json.dumps(report))
# Return the console used to run this script to a character view.
if bpy.context.area and bpy.context.area.type=='CONSOLE':
    bpy.context.area.type='VIEW_3D'
    space=bpy.context.area.spaces.active
    space.shading.type='MATERIAL';space.overlay.show_extras=False
    space.region_3d.view_perspective='ORTHO';space.region_3d.view_location=center
    space.region_3d.view_distance=max(5,scale*1.4)
    space.region_3d.view_rotation=Vector((-1,1,-.25)).to_track_quat('-Z','Y')
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.wm.save_as_mainfile(filepath=str(EXPECTED))
