"""Lengthen the approved core hold 2.5x and add a shoulder-led deeper poke.
Only writes a separate Blender workbench; game assets remain untouched.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
source=json.loads((folder/'deep_strike_source.json').read_text())['file']
bpy.ops.wm.open_mainfile(filepath=source,load_ui=True)
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
original=rig.animation_data.action
assert original.name=='03_Lance_Thrust_1'
rest={pb.name:pb.bone.matrix_local.copy() for pb in rig.pose.bones}
samples={}
for frame in range(1,24):
 scene.frame_set(frame);bpy.context.view_layer.update()
 samples[frame]={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
core=samples[7]
# Reuse the approved core; this is an extension, never a replacement.
reference=bpy.data.actions['Poke_Hit_Approved']
rig.animation_data.action=reference;rig.animation_data.action_slot=reference.slots[0]
scene.frame_set(1);bpy.context.view_layer.update()
core_error=max(abs(pb.matrix[i][j]-core[pb.name][i][j]) for pb in rig.pose.bones for i in range(4) for j in range(4))
assert core_error<1e-4,core_error
rig.animation_data.action=original;rig.animation_data.action_slot=original.slots[0]
scene.frame_set(7);bpy.context.view_layer.update()
# Principal direction of the actual lance mesh, in rig coordinates.
mesh=bpy.data.objects['Weapon_Cutlass_Geometry']
to_rig=rig.matrix_world.inverted()@mesh.matrix_world
vertices=[to_rig@v.co for v in mesh.data.vertices]
center=sum(vertices,Vector())/len(vertices)
axis=Vector((0,1,0))
for _ in range(24):
 nxt=sum(((v-center)*(v-center).dot(axis) for v in vertices),Vector())
 axis=nxt.normalized()
if axis.y<0:axis=-axis
# A lance attack should advance approximately toward the face's forward axis.
assert axis.dot(Vector((0,1,0)))>.5,axis
forward=axis
UP=Vector((0,0,1))
lean_axis=UP.cross(forward).normalized()

children={}
for name in ('Spine','Neck','Clavicle_L','Clavicle_R'):
 names=[]
 for bone in rig.data.bones:
  parent=bone
  while parent:
   if parent.name==name:names.append(bone.name);break
   parent=parent.parent
 children[name]=names

def transform_chain(poses,name,transform):
 for child in children[name]:poses[child]=transform@poses[child]

def turn_chain(poses,name,angle):
 pivot=poses[name].translation
 transform=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,lean_axis)@Matrix.Translation(-pivot)
 transform_chain(poses,name,transform)

ik_error=0.0
segment_error=0.0
max_shoulder=0.0

def extend_pose(base,u):
 global ik_error,segment_error,max_shoulder
 poses={name:mat.copy() for name,mat in base.items()}
 if u<1e-8:return poses
 # A small upper-body lean and protraction make the reach read through the
 # shoulder instead of sliding the shaft through an unmoving hand.
 transform_chain(poses,'Spine',Matrix.Translation(forward*(.055*u)))
 turn_chain(poses,'Spine',.025*u)
 turn_chain(poses,'Neck',-.015*u)
 for side in ('L','R'):
  transform_chain(poses,'Clavicle_'+side,Matrix.Translation(forward*(.070*u)))
 for side in ('L','R'):
  an,bn,hn='Arm_'+side,'Forearm_'+side,'Hand_'+side
  target=base[hn].translation+forward*(.14*u)
  a0,b0,h0=[base[name].translation.copy() for name in (an,bn,hn)]
  upper=(b0-a0).length;lower=(h0-b0).length
  a=poses[an].translation.copy()
  # If the authored elbow is nearly straight, a little extra shoulder
  # protraction preserves its lengths while allowing the exact hand target.
  distance=(target-a).length
  if distance>upper+lower-.001:
   shift=(target-a).normalized()*(distance-(upper+lower-.001))
   transform_chain(poses,'Clavicle_'+side,Matrix.Translation(shift))
   a=poses[an].translation.copy()
  direction=(target-a).normalized();distance=(target-a).length
  assert distance<upper+lower,(side,distance,upper+lower)
  along=(upper*upper+distance*distance-lower*lower)/(2*distance)
  height=math.sqrt(max(0.0,upper*upper-along*along))
  elbow_hint=poses[bn].translation-a
  pole=elbow_hint-direction*elbow_hint.dot(direction)
  if pole.length<1e-6:
   pole=Vector((1 if side=='L' else -1,0,-.3));pole-=direction*pole.dot(direction)
  elbow=a+direction*along+pole.normalized()*height
  old_upper=poses[bn].translation-a
  old_lower=poses[hn].translation-poses[bn].translation
  upper_delta=old_upper.normalized().rotation_difference((elbow-a).normalized()).to_matrix().to_4x4()
  lower_delta=old_lower.normalized().rotation_difference((target-elbow).normalized()).to_matrix().to_4x4()
  am=upper_delta@poses[an];am.translation=a
  bm=lower_delta@poses[bn];bm.translation=elbow
  hm=base[hn].copy();hm.translation=target
  poses[an]=am;poses[bn]=bm;poses[hn]=hm
  segment_error=max(segment_error,abs((elbow-a).length-upper),abs((target-elbow).length-lower))
  ik_error=max(ik_error,(hm.translation-target).length)
  max_shoulder=max(max_shoulder,(a-a0).length)
 poses['Lance_Control']=base['Lance_Control'].copy()
 poses['Lance_Control'].translation+=forward*(.14*u)
 return poses

def smooth(x):
 x=max(0.0,min(1.0,x));return x*x*(3-2*x)

def desired(frame):
 if frame<7:return samples[frame]
 if frame<=12:return core
 if frame<=18:return extend_pose(core,smooth((frame-12)/6.0))
 if frame<=20:return extend_pose(core,1.0)
 return extend_pose(samples[frame-11],1-smooth((frame-20)/14.0))

backup=original.copy();backup.name='Thrust_Before_2_5x_Deep_Poke';backup.use_fake_user=True
for layer in list(original.layers):original.layers.remove(layer)
for marker in list(original.pose_markers):original.pose_markers.remove(marker)
previous={}
for frame in range(1,35):
 scene.frame_set(frame)
 poses=desired(frame)
 for pb in rig.pose.bones:
  parent=pb.parent
  pb.matrix_basis=(rest[pb.name].inverted()@rest[parent.name]@poses[parent.name].inverted()@poses[pb.name]) if parent else rest[pb.name].inverted()@poses[pb.name]
  if pb.rotation_mode=='QUATERNION':
   q=pb.rotation_quaternion.copy()
   if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
   pb.rotation_quaternion=q;previous[pb.name]=q.copy()
  for prop in ('location','rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_euler','scale'):
   pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)
 bpy.context.view_layer.update()
for layer in original.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in bag.fcurves:
    for key in fc.keyframe_points:key.interpolation='LINEAR'
original.use_frame_range=True;original.frame_start=1;original.frame_end=34;original.use_fake_user=True
original['core_hold_start']=7;original['core_hold_end']=12
original['previous_core_hold_end']=9;original['core_hold_duration_multiplier']=2.5
original['deep_extension_frame']=18;original['deep_extension_m']=.14
original['notes']='Frame 1 start; 7–12 exact approved core (2.5x elapsed hold); 13–18 shoulder-led deeper poke; 18–20 deep impact; 21–34 recover. Feet and leg pose stay fixed through both impact stages.'
for label,frame in [('START',1),('CORE HIT — approved',7),('End 2.5x core hold',12),('DEEP POKE + shoulder',18),('Withdraw',20),('Return to start',34)]:original.pose_markers.new(label).frame=frame
# Preserve the deeper contact as another reusable pose asset.
scene.frame_set(18);bpy.context.view_layer.update()
deep=original.copy();deep.name='Poke_Hit_Deep_Extension';deep.use_fake_user=True
# A single-frame action retains the exact evaluated deeper contact.
for layer in list(deep.layers):deep.layers.remove(layer)
rig.animation_data.action=deep
poses=desired(18)
for pb in rig.pose.bones:
 parent=pb.parent
 pb.matrix_basis=(rest[pb.name].inverted()@rest[parent.name]@poses[parent.name].inverted()@poses[pb.name]) if parent else rest[pb.name].inverted()@poses[pb.name]
 for prop in ('location','rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_euler','scale'):pb.keyframe_insert(data_path=prop,frame=1,group=pb.name)
deep.use_frame_range=True;deep.frame_start=1;deep.frame_end=1
if deep.asset_data is None:deep.asset_mark()
deep.asset_data.description='Second impact stage: lance advances 14 cm; shoulders and upper body follow. Approved core stance preserved.'
rig.animation_data.action=original;rig.animation_data.action_slot=original.slots[0]
scene.timeline_markers.clear();scene.frame_start=1;scene.frame_end=34;scene.render.fps=60
# Verify every evaluated frame and the invariant feet/hand grip through impact.
core_error=0.;leg_error=0.;grip_error=0.;deep_error=0.;recover_error=0.;windup_error=0.
hand_grips={s:core['Lance_Control'].inverted()@core['Hand_'+s] for s in ('L','R')}
for frame in range(1,35):
 scene.frame_set(frame);bpy.context.view_layer.update()
 poses={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
 assert all(math.isfinite(v) for mat in poses.values() for row in mat for v in row)
 if frame<=6:
  windup_error=max(windup_error,max(abs(poses[name][i][j]-samples[frame][name][i][j]) for name in poses for i in range(4) for j in range(4)))
 if 7<=frame<=12:
  core_error=max(core_error,max(abs(poses[name][i][j]-core[name][i][j]) for name in poses for i in range(4) for j in range(4)))
 if 7<=frame<=20:
  for name in ('Root','Pelvis','Leg_L','Shin_L','Foot_L','Leg_R','Shin_R','Foot_R'):
   leg_error=max(leg_error,max(abs(poses[name][i][j]-core[name][i][j]) for i in range(4) for j in range(4)))
  for side in ('L','R'):
   grip=poses['Lance_Control'].inverted()@poses['Hand_'+side]
   grip_error=max(grip_error,max(abs(grip[i][j]-hand_grips[side][i][j]) for i in range(4) for j in range(4)))
 if frame==18:deep_error=(poses['Lance_Control'].translation-core['Lance_Control'].translation-forward*.14).length
 if frame==34:recover_error=max(abs(poses[name][i][j]-samples[1][name][i][j]) for name in poses for i in range(4) for j in range(4))
assert max(core_error,leg_error,grip_error,deep_error,recover_error,windup_error,segment_error,ik_error)<1e-4,(core_error,leg_error,grip_error,deep_error,recover_error,windup_error,segment_error,ik_error)
report={'frames':34,'fps':60,'previous_core_hold':[7,9],'new_core_hold':[7,12],'hold_time_multiplier':(12-7)/(9-7),'deep_extension_frame':18,'deep_extension_m':.14,'extension_direction_rig':list(forward),'max_shoulder_advance_m':max_shoulder,'core_pose_error':core_error,'impact_leg_error':leg_error,'hand_grip_error':grip_error,'deep_displacement_error':deep_error,'recovery_error':recover_error,'windup_error':windup_error,'arm_segment_length_error':segment_error,'backup':source,'action':original.name}
(folder/'deep_strike_verification.json').write_text(json.dumps(report,indent=2)+'\n')
scene.frame_set(18);bpy.context.view_layer.update()
for pb in rig.pose.bones:pb.select=False
rig.pose.bones['Chest'].select=True;rig.data.bones.active=rig.data.bones['Chest']
for workspace in bpy.data.workspaces:
 for screen in workspace.screens:
  for area in screen.areas:
   if area.type=='CONSOLE':area.type='VIEW_3D'
   if workspace.name=='Animation' and area.type=='DOPESHEET_EDITOR':area.spaces.active.mode='ACTION';area.spaces.active.show_pose_markers=True
output=folder/'Dragoon_Deep_Strike.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('DRAGOON_DEEP_STRIKE_OK',json.dumps(report))
