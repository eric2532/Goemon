"""Connect the user's four authored poses, with long airtime and dive.
Writes a separate workbench and keeps the source snapshots and other clips intact.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
inputs=json.loads((folder/'jump_pose_inputs.json').read_text())
bpy.ops.wm.open_mainfile(filepath=inputs['source'],load_ui=True)
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig'];original=rig.animation_data.action
assert original.name=='06_Azure_Leap'
rest={pb.name:pb.bone.matrix_local.copy() for pb in rig.pose.bones}
poses={label:{'basis':{n:Matrix(m) for n,m in inputs['poses'][f]['basis'].items()},'bones':{n:Matrix(m) for n,m in inputs['poses'][f]['bones'].items()}} for f,label in [('0','crouch'),('1','airborne'),('2','dive'),('3','landing')]}
rig.animation_data.action=bpy.data.actions['00_Idle_Approved_Base'];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
scene.frame_set(1);bpy.context.view_layer.update()
poses['idle']={'basis':{pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones},'bones':{pb.name:pb.matrix.copy() for pb in rig.pose.bones}}
for label,pose in poses.items():pose['grip']=pose['bones']['Hand_R'].inverted()@pose['bones']['Lance_Control']


def smooth(t):
 t=max(0.,min(1.,t));return t*t*t*(10+t*(-15+6*t))
def blend(a,b,u):
 pa,qa,sa=a.decompose();pb,qb,sb=b.decompose()
 return Matrix.LocRotScale(pa.lerp(pb,u),qa.slerp(qb,u),sa.lerp(sb,u))
anchors=[(1,'crouch'),(12,'crouch'),(48,'airborne'),(84,'airborne'),(114,'dive'),(150,'dive'),(180,'landing'),(192,'landing'),(228,'idle')]

def segment(frame):
 for (fa,la),(fb,lb) in zip(anchors,anchors[1:]):
  if frame<=fb:return poses[la],poses[lb],smooth((frame-fa)/(fb-fa))
 return poses['idle'],poses['idle'],0.

def desired(frame):
 a,b,u=segment(frame)
 basis={n:blend(a['basis'][n],b['basis'][n],u) for n in rest}
 world={}
 for pb in rig.pose.bones:
  n=pb.name;parent=pb.parent
  world[n]=(world[parent.name]@rest[parent.name].inverted()@rest[n]@basis[n]) if parent else rest[n]@basis[n]
 # Interpolate the lance in the gripping hand's space. This avoids a floating
 # weapon during the large flip from the airborne pose to the lance-down dive.
 world['Lance_Control']=world['Hand_R']@blend(a['grip'],b['grip'],u)
 basis['Lance_Control']=rest['Lance_Control'].inverted()@world['Lance_Control']
 return basis,world

backup=original.copy();backup.name='Jump_Before_Connected_User_Poses';backup.use_fake_user=True
rig.animation_data.action=original;rig.animation_data.action_slot=original.slots[0]
for layer in list(original.layers):original.layers.remove(layer)
for marker in list(original.pose_markers):original.pose_markers.remove(marker)
previous={}
for frame in range(1,229):
 scene.frame_set(frame)
 basis,_=desired(frame)
 for pb in rig.pose.bones:
  pb.matrix_basis=basis[pb.name]
  q=pb.rotation_quaternion.copy()
  if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
  pb.rotation_quaternion=q;previous[pb.name]=q.copy()
  for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)
for l in original.layers:
 for s in l.strips:
  for bag in s.channelbags:
   for fc in bag.fcurves:
    for key in fc.keyframe_points:key.interpolation='LINEAR'
original.use_frame_range=True;original.frame_start=1;original.frame_end=228;original.use_fake_user=True
original['notes']='User poses preserved: frame 0 -> 1/12 crouch; 1 -> 48/84 airborne; 2 -> 114/150 dive; saved unkeyed 3 -> 180/192 landing. Smooth takeoff, long airtime, sustained dive, landing hold, return to approved idle. Preview height is separate on PREVIEW_Jump_Travel.'
original['user_pose_source']=inputs['source'];original['duration_seconds']=227/60
for label,f in [('CROUCH — user 0',1),('Push off',12),('AIRBORNE — user 1',48),('End airborne hold',84),('DIVE — user 2',114),('End long dive',150),('LANDING — user 3',180),('Recover',192),('Return to idle',228)]:original.pose_markers.new(label).frame=f
# Keep one-keyframe pose assets for future manual revisions.
for label in ('crouch','airborne','dive','landing'):
 action=bpy.data.actions.new('Jump_Pose_'+label.title());action.use_fake_user=True
 rig.animation_data.action=action
 for pb in rig.pose.bones:
  pb.matrix_basis=poses[label]['basis'][pb.name]
  for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=1,group=pb.name)
 action.use_frame_range=True;action.frame_start=1;action.frame_end=1;action.asset_mark();action.asset_data.description='Exact user-authored jump strike '+label+' pose; original source '+inputs['source']
rig.animation_data.action=original;rig.animation_data.action_slot=original.slots[0]
# A separate non-deforming parent supplies preview height, without baking game
 # travel into any character bone or changing the authored poses.
preview=bpy.data.objects.new('PREVIEW_Jump_Travel',None);scene.collection.objects.link(preview);preview.empty_display_type='PLAIN_AXES';preview.empty_display_size=.25
preview['notes']='Blender preview height only. Character action stays in place; game owns real jump movement. Remove/mute this object animation for in-place preview/export.'
for name in ('Reference_Rig','Cosplay','Weapon_Cutlass'):
 obj=bpy.data.objects[name];matrix=obj.matrix_world.copy();assert obj.parent is None
 obj.parent=preview;obj.matrix_world=matrix

def height(frame):
 if frame<=12 or frame>=180:return 0.
 if frame<=62:
  t=(frame-12)/50;return 2.5*(1-(1-t)**2)
 if frame<=84:return 2.5
 if frame<=114:return 2.5-.4*smooth((frame-84)/30)
 if frame<=150:
  t=(frame-114)/36;return 2.1-1.4*t*t
 return .7*(1-smooth((frame-150)/30))
for f in range(1,229):
 preview.location=(0,0,height(f));preview.keyframe_insert(data_path='location',frame=f)
preview.animation_data.action.name='PREVIEW_Jump_Height_Only'
for l in preview.animation_data.action.layers:
 for s in l.strips:
  for bag in s.channelbags:
   for fc in bag.fcurves:
    for k in fc.keyframe_points:k.interpolation='LINEAR'
scene.frame_start=1;scene.frame_end=228;scene.render.fps=60;scene.timeline_markers.clear()
scene['jump_strike_guide']=original['notes']
for workspace in bpy.data.workspaces:
 for screen in workspace.screens:
  for area in screen.areas:
   if area.type=='CONSOLE':area.type='VIEW_3D'
   if area.type=='DOPESHEET_EDITOR' and hasattr(area.spaces.active,'mode'):
    area.spaces.active.mode='ACTION';area.spaces.active.show_pose_markers=True
   if area.type=='VIEW_3D' and hasattr(area.spaces.active,'region_3d'):
    area.spaces.active.region_3d.view_location=Vector((0,0,2.3));area.spaces.active.region_3d.view_distance=8.5
for pb in rig.pose.bones:pb.select=False
rig.pose.bones['Chest'].select=True;rig.data.bones.active=rig.data.bones['Chest']
bpy.context.view_layer.objects.active=rig;rig.select_set(True);preview.select_set(False)
scene.frame_set(114);bpy.context.view_layer.update()
output=folder/'Dragoon_Jump_Strike.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output))
record={'file':str(output),'source':inputs['source'],'frames':228,'fps':60,'duration_seconds':227/60,'anchors':anchors,'preview_height_m':2.5,'source_pose3_was_unkeyed':True}
(folder/'jump_strike_timing.json').write_text(json.dumps(record,indent=2)+'\n')
print('JUMP_STRIKE_BUILT',json.dumps(record))
