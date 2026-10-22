"""Run in the active Blender session, preserving its unsaved current pose."""
import bpy,json,datetime
from pathlib import Path
from mathutils import Matrix
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/dragoon-motion-workbench')
rig=bpy.data.objects['Reference_Rig']
scene=bpy.context.scene
assert rig.animation_data and rig.animation_data.action and rig.animation_data.action.name=='01_Idle', 'Select 01_Idle before running.'
bpy.context.view_layer.update()
frame_before=scene.frame_current
pose={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}
visible={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
weapon=bpy.data.objects['Weapon_Cutlass']
weapon_before=weapon.matrix_world.copy()
others={a.name:a.as_pointer() for a in bpy.data.actions if a!=rig.animation_data.action}
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Dragoon_Before_Idle_Copy_'+stamp+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
action=rig.animation_data.action
backup=action.copy();backup.name='Idle_Backup_'+stamp;backup.use_fake_user=True
# Keep the active action's identity and all other animation clips intact.
for layer in list(action.layers):action.layers.remove(layer)
for frame in (1,217):
    scene.frame_set(frame)
    for pb in rig.pose.bones:
        pb.matrix_basis=pose[pb.name]
        for prop in ('location','rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_axis_angle' if pb.rotation_mode=='AXIS_ANGLE' else 'rotation_euler','scale'):
            pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)
    bpy.context.view_layer.update()
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for key in fc.keyframe_points:key.interpolation='CONSTANT'
action.use_frame_range=True;action.frame_start=1;action.frame_end=217
for marker in list(action.pose_markers):action.pose_markers.remove(marker)
action.pose_markers.new('Your idle pose').frame=1
action.pose_markers.new('Same pose — loop').frame=217
scene.timeline_markers.clear()
scene.frame_start=1;scene.frame_end=217
max_bone_error=0.;max_weapon_error=0.
for frame in range(1,218):
    scene.frame_set(frame);bpy.context.view_layer.update()
    max_bone_error=max(max_bone_error,max(abs(pb.matrix[i][j]-visible[pb.name][i][j]) for pb in rig.pose.bones for i in range(4) for j in range(4)))
    max_weapon_error=max(max_weapon_error,max(abs(weapon.matrix_world[i][j]-weapon_before[i][j]) for i in range(4) for j in range(4)))
assert max_bone_error<.0001 and max_weapon_error<.0001,(max_bone_error,max_weapon_error)
assert all(bpy.data.actions.get(name) and bpy.data.actions[name].as_pointer()==pointer for name,pointer in others.items())
scene.frame_set(1)
report={'source_frame':frame_before,'frames_checked':217,'max_bone_matrix_error':max_bone_error,'max_weapon_matrix_error':max_weapon_error,'snapshot':str(snapshot),'backup_action':backup.name,'result':'current whole-body and lance pose held on every Idle frame'}
(folder/'idle_pose_copy_verification.json').write_text(json.dumps(report,indent=2)+'\n')
(folder/'approved_idle_pose.json').write_text(json.dumps({name:[list(row) for row in mat] for name,mat in pose.items()},indent=2)+'\n')
# Return any console created for this operation to the 3D editing viewport.
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':area.type='VIEW_3D'
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Dragoon_Animation_Workbench.blend'))
print('IDLE_POSE_COPY_OK',json.dumps(report))
