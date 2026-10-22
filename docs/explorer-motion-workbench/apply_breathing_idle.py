"""Apply a gentle breathing loop to the CURRENT unsaved Blender pose.
Run through Blender's console; never reload the file before capturing the pose.
"""
import bpy, json, math, datetime, hashlib
from pathlib import Path
from mathutils import Matrix, Vector
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/explorer-motion-workbench')
scene=bpy.context.scene
rig=bpy.data.objects['Reference_Rig']
assert rig.animation_data and rig.animation_data.action and rig.animation_data.action.name=='01_Idle', 'Please select 01_Idle.'
assert not bpy.context.screen.is_animation_playing, 'Stop playback before capturing the pose.'
bpy.context.view_layer.update()
source_frame=scene.frame_current
base={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
base_basis={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
weapons={'R':bpy.data.objects['Weapon_Cutlass'],'L':bpy.data.objects['Weapon_Pistol']}
controls={'R':'Right_Blade_Control','L':'Left_Blade_Control'}
base_grips={side:(rig.matrix_world@base['Hand_'+side]).inverted()@weapon.matrix_world for side,weapon in weapons.items()}
original_action=rig.animation_data.action
other_actions={a.name:a.as_pointer() for a in bpy.data.actions if a!=original_action}
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Explorer_Before_Breathing_'+stamp+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
backup=original_action.copy();backup.name='Idle_Before_Breathing_'+stamp;backup.use_fake_user=True

# Preserve the corrected neutral pose as its own editable action as well.
def clear_action(action):
    for layer in list(action.layers):action.layers.remove(layer)
    for marker in list(action.pose_markers):action.pose_markers.remove(marker)

def set_pose(matrices):
    for pb in rig.pose.bones:
        parent=pb.parent
        pb.matrix_basis=(rest[pb.name].inverted()@rest[parent.name]@matrices[parent.name].inverted()@matrices[pb.name]) if parent else rest[pb.name].inverted()@matrices[pb.name]

def insert_keys(frame,previous=None):
    for pb in rig.pose.bones:
        if pb.rotation_mode=='QUATERNION' and previous is not None:
            q=pb.rotation_quaternion.copy()
            if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
            pb.rotation_quaternion=q;previous[pb.name]=q.copy()
        rotation='rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_axis_angle' if pb.rotation_mode=='AXIS_ANGLE' else 'rotation_euler'
        for prop in ('location',rotation,'scale'):pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)

def descendants(name):
    names=[]
    for bone in rig.data.bones:
        ancestor=bone
        while ancestor:
            if ancestor.name==name:names.append(bone.name);break
            ancestor=ancestor.parent
    return names

chains={name:descendants(name) for name in ('Spine','Chest','Neck')}
def turn_chain(poses,name,angle):
    pivot=poses[name].translation
    rotation=Matrix.Rotation(angle,4,'X')
    transform=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)
    for child in chains[name]:poses[child]=transform@poses[child]

def breathing_pose(phase):
    s=math.sin(math.tau*phase)
    poses={name:mat.copy() for name,mat in base.items()}
    for name in chains['Spine']:poses[name].translation+=Vector((0,0,.008*s))
    turn_chain(poses,'Spine',-.006*s)
    turn_chain(poses,'Chest',-.012*s)
    turn_chain(poses,'Neck',.009*s)
    # Both blades retain the user's exact hand-relative position and angle.
    for side,control in controls.items():
        hand='Hand_'+side
        poses[control]=poses[hand]@base[hand].inverted()@base[control]
    return poses

base_action=bpy.data.actions.new('00_Idle_Approved_Base')
base_action.use_fake_user=True
rig.animation_data.action=base_action
scene.frame_set(1);set_pose(base);insert_keys(1)
base_action.use_frame_range=True;base_action.frame_start=1;base_action.frame_end=217
base_action['notes']='User-corrected true idle, captured before breathing at frame '+str(source_frame)
base_action.asset_mark();base_action.asset_data.description=base_action['notes']
rig.animation_data.action=original_action
clear_action(original_action)
previous={}
for f in range(0,217,18):
    scene.frame_set(f+1)
    set_pose(breathing_pose(f/216.0))
    insert_keys(f+1,previous)
    bpy.context.view_layer.update()
# Smooth periodic tangents; the duplicated endpoint closes one 3.6-second cycle.
for layer in original_action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                points=curve.keyframe_points
                for i,key in enumerate(points):
                    prev=points[i-1] if i>0 else points[-2]
                    nex=points[i+1] if i<len(points)-1 else points[1]
                    slope=(nex.co.y-prev.co.y)/36.0
                    key.interpolation='BEZIER'
                    key.handle_left_type='FREE';key.handle_right_type='FREE'
                    key.handle_left=(key.co.x-6,key.co.y-slope*6)
                    key.handle_right=(key.co.x+6,key.co.y+slope*6)
                modifier=curve.modifiers.new('CYCLES');modifier.mode_before='REPEAT';modifier.mode_after='REPEAT'
original_action.use_fake_user=True
original_action.use_frame_range=True;original_action.frame_start=1;original_action.frame_end=217
if hasattr(original_action,'use_cyclic'):original_action.use_cyclic=True
original_action['approved_base_action']=base_action.name
original_action['breathing_period_seconds']=3.6
original_action['notes']='Gentle chest and shoulder breathing on the user-approved idle. Feet planted; both blades follow their hands with their resting angles preserved.'
for label,frame in [('True idle / inhale',1),('Inhale peak',55),('True idle / exhale',109),('Exhale peak',163),('Loop seam',217)]:original_action.pose_markers.new(label).frame=frame
scene.timeline_markers.clear();scene.frame_start=1;scene.frame_end=216;scene.render.fps=60
# Evaluate every frame to verify base preservation, planted feet, and weapon grip.
neutral_error=0.;feet_error=0.;grip_error=0.;chest_rise=[]
first_pose=None;seam_error=0.
for frame in range(1,218):
    scene.frame_set(frame);bpy.context.view_layer.update()
    matrices={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
    if frame in (1,109,217):
        neutral_error=max(neutral_error,max(abs(matrices[name][i][j]-base[name][i][j]) for name in base for i in range(4) for j in range(4)))
    for name in ('Root','Pelvis','Leg_L','Shin_L','Foot_L','Leg_R','Shin_R','Foot_R'):
        feet_error=max(feet_error,max(abs(matrices[name][i][j]-base[name][i][j]) for i in range(4) for j in range(4)))
    for side,weapon in weapons.items():
        grip=(rig.matrix_world@matrices['Hand_'+side]).inverted()@weapon.matrix_world
        grip_error=max(grip_error,max(abs(grip[i][j]-base_grips[side][i][j]) for i in range(4) for j in range(4)))
    chest_rise.append((matrices['Chest'].translation-base['Chest'].translation).length)
    if frame==1:first_pose=matrices
    if frame==217:seam_error=max(abs(matrices[name][i][j]-first_pose[name][i][j]) for name in base for i in range(4) for j in range(4))
assert neutral_error<1e-4 and feet_error<1e-4 and grip_error<1e-4 and seam_error<1e-4,(neutral_error,feet_error,grip_error,seam_error)
assert max(chest_rise)>.003 and max(chest_rise)<.025,max(chest_rise)
assert all(bpy.data.actions.get(name) and bpy.data.actions[name].as_pointer()==pointer for name,pointer in other_actions.items())
(folder/'approved_idle_pose.json').write_text(json.dumps({name:[list(row) for row in mat] for name,mat in base_basis.items()},indent=2)+'\n')
report={'source_frame':source_frame,'backup_file':str(snapshot),'backup_action':backup.name,'base_action':base_action.name,'action':'01_Idle','fps':60,'period_frames':216,'period_seconds':3.6,'key_pose_frames':list(range(1,218,18)),'frames_verified':217,'neutral_pose_error':neutral_error,'feet_error':feet_error,'weapon_grip_error':grip_error,'loop_seam_error':seam_error,'max_chest_displacement_m':max(chest_rise),'other_actions_preserved':True,'weapons_checked':['Weapon_Cutlass','Weapon_Pistol']}
(folder/'breathing_idle_verification.json').write_text(json.dumps(report,indent=2)+'\n')
scene.frame_set(1);bpy.context.view_layer.update()
for pb in rig.pose.bones:pb.select=False
rig.pose.bones['Chest'].select=True;rig.data.bones.active=rig.data.bones['Chest']
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':
        area.type='DOPESHEET_EDITOR' if area.y<100 else 'VIEW_3D'
        if area.type=='DOPESHEET_EDITOR':
            area.spaces.active.mode='ACTION'
            area.spaces.active.show_pose_markers=True
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Explorer_Animation_Workbench.blend'))
print('EXPLORER_BREATHING_IDLE_OK',json.dumps(report))
