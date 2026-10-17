"""Dragoon's upright regular jump, derived from the approved jump strike."""
import bpy,json,math,shutil,datetime
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
folder=Path(__file__).resolve().parent
source=folder/'Dragoon_Jump_Strike.blend'
backup=folder/('Dragoon_Before_Regular_Jump_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend')
shutil.copy2(source,backup)
bpy.ops.wm.open_mainfile(filepath=str(backup),load_ui=True)
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig']
rest={pb.name:pb.bone.matrix_local.copy() for pb in rig.pose.bones}
def capture(action):
 rig.animation_data.action=bpy.data.actions[action];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
 scene.frame_set(1);bpy.context.view_layer.update()
 return {pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}
poses={n:capture(a) for n,a in [('idle','00_Idle_Approved_Base'),('crouch','Jump_Pose_Crouch'),('air','Jump_Pose_Airborne'),('land','Jump_Pose_Landing')]}
def blend(a,b,t):
 pa,qa,sa=a.decompose();pb,qb,sb=b.decompose()
 return Matrix.LocRotScale(pa.lerp(pb,t),qa.slerp(qb,t),sa.lerp(sb,t))
def mix(a,b,t):return {n:blend(a[n],b[n],t) for n in rest}
def worlds(basis):
 result={}
 for pb in rig.pose.bones:
  n=pb.name;p=pb.parent
  result[n]=result[p.name]@rest[p.name].inverted()@rest[n]@basis[n] if p else rest[n]@basis[n]
 return result
# Extend the legs for push off, then tuck back into the user's asymmetric air pose.
poses['push']=mix(poses['crouch'],poses['air'],.75)
for n in ['Leg_L','Shin_L','Foot_L','Leg_R','Shin_R','Foot_R']:
 poses['push'][n]=blend(poses['crouch'][n],poses['idle'][n],.85)
# A restrained chest lift adds life across the apex without changing the silhouette.
poses['crest']={n:m.copy() for n,m in poses['air'].items()}
for n,angle in [('Chest',-.025),('Neck',.012),('Sash',.045)]:
 p,q,s=poses['crest'][n].decompose();q=q@Quaternion((1,0,0),angle);poses['crest'][n]=Matrix.LocRotScale(p,q,s)
poses['descend']=mix(poses['air'],poses['land'],.32)
for n in ['Leg_L','Shin_L','Foot_L','Leg_R','Shin_R','Foot_R']:
 poses['descend'][n]=blend(poses['air'][n],poses['land'][n],.6)
grips={}
for label,p in poses.items():
 w=worlds(p);grips[label]=w['Hand_R'].inverted()@w['Lance_Control']
# The newly derived push/apex use the original air grip, so the shaft stays in the palm.
for label in ('push','crest'):grips[label]=grips['air'].copy()
anchors=[(1,'crouch'),(12,'crouch'),(20,'push'),(40,'air'),(56,'crest'),(72,'air'),(84,'descend'),(98,'land'),(108,'land'),(140,'idle')]
def smooth(t):
 t=max(0.,min(1.,t));return t*t*t*(10+t*(-15+6*t))
def desired(frame):
 for (fa,la),(fb,lb) in zip(anchors,anchors[1:]):
  if frame<=fb:break
 t=smooth((frame-fa)/(fb-fa));basis=mix(poses[la],poses[lb],t);w=worlds(basis)
 w['Lance_Control']=w['Hand_R']@blend(grips[la],grips[lb],t)
 basis['Lance_Control']=rest['Lance_Control'].inverted()@w['Lance_Control']
 return basis
act=bpy.data.actions['02_Jump'];old=act.copy();old.name='Jump_Before_Dragoon_Specific';old.use_fake_user=True
rig.animation_data.action=act;rig.animation_data.action_slot=act.slots[0]
for l in list(act.layers):act.layers.remove(l)
for m in list(act.pose_markers):act.pose_markers.remove(m)
previous={}
for f in range(1,141):
 scene.frame_set(f)
 basis=desired(f)
 for pb in rig.pose.bones:
  pb.matrix_basis=basis[pb.name];q=pb.rotation_quaternion.copy()
  if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
  pb.rotation_quaternion=q;previous[pb.name]=q.copy()
  for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=f,group=pb.name)
act.use_fake_user=True;act.use_frame_range=True;act.frame_start=1;act.frame_end=140
act['notes']='Dragoon-specific regular jump: approved crouch, extended push-off, upright asymmetric airborne pose, subtle chest lift at apex, upright descent, approved crouched landing, and return to idle. No dive. Separate preview travel stays off the character bones.'
act['airborne_start']=40;act['airborne_end']=72;act['landing_frame']=98;act['duration_seconds']=139/60
for label,f in [('Crouch',1),('PUSH OFF',12),('Leg extension',20),('AIRBORNE — approved',40),('APEX',56),('Upright descent',84),('LAND',98),('Recover',108),('Return to idle',140)]:act.pose_markers.new(label).frame=f
if act.asset_data is None:act.asset_mark()
act.asset_data.description=act['notes']
preview=bpy.data.objects['PREVIEW_Jump_Travel']
prev=preview.animation_data.action.copy();prev.name='PREVIEW_Regular_Jump_Height';preview.animation_data.action=prev;preview.animation_data.action_slot=prev.slots[0]
for l in list(prev.layers):prev.layers.remove(l)
def height(f):
 if f<=12 or f>=98:return 0.
 if f<=56:
  t=(f-12)/44;return 2.4*(1-(1-t)**2)
 if f<=64:return 2.4
 t=(f-64)/34;return 2.4*(1-smooth(t))
for f in range(1,141):
 preview.location=(0,0,height(f));preview.keyframe_insert(data_path='location',frame=f)
for a in (act,prev):
 for l in a.layers:
  for s in l.strips:
   for bag in s.channelbags:
    for fc in bag.fcurves:
     for k in fc.keyframe_points:k.interpolation='LINEAR'
scene.frame_start=1;scene.frame_end=140;scene.render.fps=60;scene.timeline_markers.clear()
scene['regular_jump_guide']=act['notes']
for workspace in bpy.data.workspaces:
 for screen in workspace.screens:
  for area in screen.areas:
   if area.type=='VIEW_3D' and hasattr(area.spaces.active,'region_3d'):
    area.spaces.active.region_3d.view_location=Vector((0,0,2.4));area.spaces.active.region_3d.view_distance=8.5
scene.frame_set(56);bpy.context.view_layer.update()
output=folder/'Dragoon_Regular_Jump.blend';bpy.ops.wm.save_as_mainfile(filepath=str(output))
record={'source':str(backup),'file':str(output),'action':act.name,'frames':140,'fps':60,'seconds':139/60,'anchors':anchors,'airborne_start':40,'airborne_end':72,'landing_frame':98,'has_dive':False}
(folder/'regular_jump_timing.json').write_text(json.dumps(record,indent=2)+'\n')
print('DRAGOON_REGULAR_JUMP_BUILT',json.dumps(record))
