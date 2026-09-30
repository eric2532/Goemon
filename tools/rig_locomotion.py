"""Rig/animation-only update of existing kai.blend. Never edits mesh or materials.
Run Blender --background assets/blender/characters/kai.blend --python tools/rig_locomotion.py
"""
import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[1]
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
# Preserve old region membership before replacing only armature/weights.
regions={}
for o in bpy.data.objects:
 if o.type=='MESH':
  if 'source_weight_regions' in o:
   regions[o.name]=list(o['source_weight_regions'])
  else:
   regions[o.name]=[max(v.groups,key=lambda g:g.weight).group for v in o.data.vertices]
   regions[o.name]=[o.vertex_groups[i].name for i in regions[o.name]]
   o['source_weight_regions']=regions[o.name]
rig.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for b in list(rig.data.edit_bones):rig.data.edit_bones.remove(b)
# Blender coordinates: Z up, +Y forward. Bone Y axes follow the actual limb.
J={'Root':((0,0,0),(0,0,.2),None),'Pelvis':((0,0,.966),(0,0,1.08),'Root'),
'Spine':((0,0,1.04),(0,0,1.19),'Pelvis'),
'SpineMid':((0,0,1.19),(0,0,1.34),'Spine'),
'Chest':((0,0,1.34),(0,0,1.449),'SpineMid'),
'Neck':((0,0,1.449),(0,0,1.54),'Chest'),
'Head':((0,0,1.54),(0,0,1.9),'Neck'),
'Sash':((0,-.339,.932),(0,-.339,1.032),'Pelvis')}
for side,sign in [('L',-1),('R',1)]:
 J['Clavicle_'+side]=((0,0,1.36),(sign*.406665,0,1.304718),'Chest')
 J['Arm_'+side]=((sign*.406665,0,1.304718),(sign*.80,0,1.304718),'Clavicle_'+side)
 J['Forearm_'+side]=((sign*.80,0,1.304718),(sign*1.09,0,1.304718),'Arm_'+side)
 J['Hand_'+side]=((sign*1.09,0,1.304718),(sign*1.36,0,1.304718),'Forearm_'+side)
 J['Leg_'+side]=((sign*.254166,0,.96583),(sign*.30,0,.49),'Pelvis')
 J['Shin_'+side]=((sign*.30,0,.49),(sign*.315,0,.185),'Leg_'+side)
 J['Foot_'+side]=((sign*.315,0,.185),(sign*.315,.36,.10),'Shin_'+side)
for name,(h,t,parent) in J.items():
 b=rig.data.edit_bones.new(name);b.head=h;b.tail=t
 if parent:b.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True
# Reweight existing vertices only. Foot islands stay rigid; joint rings blend.
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
for o in bpy.data.objects:
 if o.type!='MESH':continue
 old=regions[o.name];o.vertex_groups.clear()
 for name in J:o.vertex_groups.new(name=name)
 for v,region in zip(o.data.vertices,old):
  x,y,z=v.co;weights={}
  # Re-running this tool is supported after the first rig update.
  if region in ('Root','Pelvis','Spine','Sash'):
   levels=[('Pelvis',.96),('Spine',1.09),('SpineMid',1.23),('Chest',1.38)]
   if z<=levels[0][1]:weights={'Pelvis':1}
   elif z>=levels[-1][1]:weights={'Chest':1}
   else:
    for (a,lo),(b,hi) in zip(levels,levels[1:]):
     if lo<=z<=hi:
      t=smooth(lo,hi,z);weights={a:1-t,b:t};break
  elif region=='Head':weights={'Head':1}
  elif region.startswith(('Arm_','Forearm_','Hand_')):
   side='L' if x<0 else 'R';a=abs(x)
   elbow=smooth(.72,.87,a);wrist=smooth(1.055,1.125,a)
   shoulder=smooth(.39,.54,a)
   weights={'Clavicle_'+side:(1-shoulder)*(1-elbow),'Arm_'+side:shoulder*(1-elbow)*(1-wrist),'Forearm_'+side:elbow*(1-wrist),'Hand_'+side:wrist}
  else:
   side='L' if x<0 else 'R'
   # Existing shoe topology sits below .277; preserve its exact rigid shape.
   if z<.28:weights={'Foot_'+side:1}
   else:
    knee=smooth(.36,.59,z);hip=smooth(.82,1.05,z)
    weights={'Shin_'+side:1-knee,'Leg_'+side:knee*(1-hip),'Pelvis':knee*hip}
  for name,w in weights.items():
   if w>0:o.vertex_groups[name].add([v.index],w,'REPLACE')
# Rest matrices are unchanged during authoring; pose matrices are solved anatomically.
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
desired={}
def set_matrix(name,m):
 b=rig.data.bones[name];desired[name]=m.copy()
 if b.parent:
  parent=b.parent.name
  rig.pose.bones[name].matrix_basis=rest[name].inverted()@rest[parent]@desired.get(parent,rest[parent]).inverted()@m
 else:rig.pose.bones[name].matrix_basis=rest[name].inverted()@m

def rot(axis,a):return Matrix.Rotation(a,4,axis)
def set_global(name,head,direction,extra=None):
 b=rig.data.bones[name];rdir=(b.tail_local-b.head_local).normalized()
 q=rdir.rotation_difference(Vector(direction).normalized())
 m=q.to_matrix().to_4x4()@rest[name];m.translation=Vector(head)
 if extra is not None:m=extra@m
 set_matrix(name,m)
 return m

def leg(side,hip,ankle,foot_pitch=0):
 knee0=Vector(J['Shin_'+side][0]);hip0=Vector(J['Leg_'+side][0]);ankle0=Vector(J['Foot_'+side][0])
 a=(knee0-hip0).length;b=(ankle0-knee0).length;d=ankle-hip;l=min(d.length,(a+b)*.999);u=d.normalized()
 bend=Vector((0,1,0));bend=(bend-u*bend.dot(u)).normalized()
 along=(a*a-b*b+l*l)/(2*l);knee=hip+u*along+bend*math.sqrt(max(0,a*a-along*along))
 set_global('Leg_'+side,hip,knee-hip);set_global('Shin_'+side,knee,ankle-knee)
 m=rot('X',foot_pitch)@rest['Foot_'+side];m.translation=ankle;set_matrix('Foot_'+side,m)

def cycle(keys,t):
 # Periodic cubic key-pose interpolation: strong silhouettes with smooth arcs.
 t=t%1
 for i in range(len(keys)-1):
  x1,y1=keys[i];x2,y2=keys[i+1]
  if x1<=t<=x2:
   x0,y0=keys[i-1] if i>0 else (keys[-2][0]-1,keys[-2][1])
   x3,y3=keys[i+2] if i+2<len(keys) else (keys[1][0]+1,keys[1][1])
   u=(t-x1)/(x2-x1);m1=(y2-y0)/(x2-x0)*(x2-x1);m2=(y3-y1)/(x3-x1)*(x2-x1)
   return (2*u**3-3*u*u+1)*y1+(u**3-2*u*u+u)*m1+(-2*u**3+3*u*u)*y2+(u**3-u*u)*m2
 return keys[-1][1]
DRIVE=[(0,1),(.10,.90),(.26,0),(.50,-1),(.61,-.92),(.77,0),(1,1)]
REBOUND=[(0,0),(.18,-.055),(.40,.025),(.68,.080),(.86,.045),(1,0)]
def orient(name,position,yaw=0,pitch=0,roll=0):
 m=Matrix.Translation(position)@rot('Z',yaw)@rot('X',pitch)@rot('Y',roll)@rest[name].to_3x3().to_4x4()
 set_matrix(name,m);return m

def pose(name,t):
 desired.clear()
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
 desired['Root']=rest['Root'].copy()
 walk='Walk' in name;run='Run' in name;sprint=name=='Sprint'
 moving=walk or run or sprint
 energy=1.25 if sprint else (1.0 if run else (.32 if walk else 0))
 phase=t*math.tau
 idle=name=='Idle'
 breath=math.sin(phase) if idle else 0.0
 drop=.055 if walk else (.22 if sprint else (.18 if run else .008))
 bob=cycle(REBOUND,t*2)*energy if moving else math.sin(phase)*.006
 if idle:drop=.075;bob=breath*.014
 if name=='Land':drop=.008+math.sin(math.pi*t)*.12
 # Hips initiate; rotation, weight transfer and drive propagate up the torso.
 pelvis_yaw=-cycle(DRIVE,t)*.25*energy
 chest_yaw=cycle(DRIVE,t-.075)*.31*energy
 lean=.36 if sprint else (.25 if run else .035)
 pelvis_pos=rest['Pelvis'].translation+Vector((.075*energy*math.sin(phase-.2),.045*energy+(math.sin(phase-.3)*.003 if idle else cycle(REBOUND,t*2)*.25),-drop+bob))
 pelvis=orient('Pelvis',pelvis_pos,pelvis_yaw,-lean*.25,math.sin(phase-.15)*.07*energy)
 parent='Pelvis'
 for part,yaw,pitch,roll in [
  ('Spine',-cycle(DRIVE,t-.025)*.17*energy,-lean*.50,math.sin(phase-.30)*.055*energy),
  ('SpineMid',-cycle(DRIVE,t-.045)*.04*energy,-lean*.78,math.sin(phase-.45)*.035*energy),
  ('Chest',chest_yaw,-lean+cycle(REBOUND,t*2-.08)*.40,math.sin(phase-.60)*-.05*energy)]:
  pos=desired[parent]@rest[parent].inverted()@rest[part].translation
  if idle:
   pos.z+=math.sin(phase-.12)*.003
   pitch=-.025-math.sin(phase-.2)*.009
  orient(part,pos,yaw,pitch,roll);parent=part
 chest=desired['Chest'];spine=desired['Spine']
 neck_pos=chest@rest['Chest'].inverted()@rest['Neck'].translation
 neck=orient('Neck',neck_pos,chest_yaw*.28,(-.014-math.sin(phase-.30)*.008) if idle else -lean*.68+cycle(REBOUND,t*2-.10)*.12,-math.sin(phase-.65)*.018*energy)
 head_pos=neck@rest['Neck'].inverted()@rest['Head'].translation
 orient('Head',head_pos,chest_yaw*.12+math.sin(phase-.9)*.012*energy,(-.01-math.sin(phase-.42)*.008) if idle else -lean*.48+cycle(REBOUND,t*2-.12)*.12,math.sin(phase-.8)*.018*energy)
 duty=.60 if walk else (.17 if sprint else .26);span=.52 if walk else (1.04 if sprint else .94);lift=.10 if walk else (.40 if sprint else .32)
 direction=Vector((0,1,0))
 if 'Back' in name:direction=Vector((0,-1,0))
 if 'Strafe_L' in name:direction=Vector((-1,0,0))
 if 'Strafe_R' in name:direction=Vector((1,0,0))
 for i,side in enumerate(('L','R')):
  sign=-1 if i==0 else 1;p=(t+i*.5)%1
  if moving:
   if p<duty:fwd=span*(.5-p/duty);up=0
   else:
    u=(p-duty)/(1-duty);fwd=span*(-.5+smooth(0,1,u));up=math.sin(math.pi*u)**.85*lift
  else:fwd=0;up=0
  ankle=Vector(J['Foot_'+side][0])+direction*fwd+Vector((0,0,up))
  hip=pelvis@rest['Pelvis'].inverted()@Vector(J['Leg_'+side][0])
  pitch=-.40*math.sin(math.pi*(p-duty)/(1-duty)) if p>=duty and moving else 0
  leg(side,hip,ankle,pitch)
  # Clavicle motion leads the humerus; each successive joint trails the drive.
  clav='Clavicle_'+side
  clav_pos=chest@rest['Chest'].inverted()@rest[clav].translation
  # Idle opens 4 cm per side; moving poses retain their 2.5 cm opening.
  clav_pos+=chest.to_3x3()@rest['Chest'].to_3x3().inverted()@Vector((sign*(.040 if idle else .025),0,0))
  clav_yaw=chest_yaw+cycle(DRIVE,t-.10)*.12*energy
  clav_pose=orient(clav,clav_pos,clav_yaw,-lean,sign*cycle(DRIVE,t+i*.5-.10)*.045*energy)
  shoulder=clav_pose@rest[clav].inverted()@Vector(J['Arm_'+side][0])
  lag=.025 if i==1 else 0
  drive=cycle(DRIVE,t+i*.5-.12-lag)
  swing=-drive*(1.14 if sprint else (.98 if run else .32))*(.92 if i==1 else 1) if moving else 0
  # Strong rear extension, compact forward drive, continuously changing elbow bend.
  swing*=1.10 if swing<0 else .95
  swing_fore=-cycle(DRIVE,t+i*.5-.17-lag)*(1.14 if sprint else (.98 if run else .32)) if moving else 0
  flex=(.92+.30*(-cycle(DRIVE,t+i*.5-.16))) if run or sprint else (.55 if walk else .22)
  if idle:flex=.64+math.sin(phase-.35)*.035;swing=-.08+math.sin(phase-.25)*.018;swing_fore=swing
  upper_dir=Vector((sign*((.32+breath*.015) if idle else (.10+.07*energy))+direction.x*swing*.25,math.sin(swing)*(direction.y if abs(direction.y)>.1 else .40),-math.cos(swing))).normalized()
  arm_length=.81 if idle else 1.0
  elbow=shoulder+upper_dir*.393335*arm_length
  fore_angle=swing_fore*(direction.y if abs(direction.y)>.1 else .40)+flex
  fore_dir=Vector((sign*(.16 if idle else .05)+direction.x*swing*.20,math.sin(fore_angle),-math.cos(fore_angle))).normalized()
  wrist=elbow+fore_dir*.29*arm_length
  hand_angle=(-cycle(DRIVE,t+i*.5-.21-lag)*(1.14 if sprint else .98)*(direction.y if abs(direction.y)>.1 else .40)+flex) if run or sprint else fore_angle
  hand_dir=Vector((sign*.05,math.sin(hand_angle),-math.cos(hand_angle))).normalized()
  set_global('Arm_'+side,shoulder,elbow-shoulder)
  set_global('Forearm_'+side,elbow,wrist-elbow)
  set_global('Hand_'+side,wrist,hand_dir)
  if idle:
   # Scale each bound limb segment from its anchored joint; keep hands full-size.
   for part in ('Arm_','Forearm_'):
    m=desired[part+side].copy()
    for axis in range(3):m.col[axis]=m.col[axis]*arm_length
    set_matrix(part+side,m)
   set_matrix('Hand_'+side,desired['Hand_'+side])
 if name in ('JumpStart','JumpLoop','Fall','Jump','Land','Hit','Death','Front_Flip'):
  if name=='Land':pass
  elif name=='Death':rig.pose.bones['Root'].rotation_mode='XYZ';rig.pose.bones['Root'].rotation_euler.x=t*-1.5
  elif name=='Front_Flip':rig.pose.bones['Root'].rotation_mode='XYZ';rig.pose.bones['Root'].rotation_euler.x=t*math.tau
  elif name=='Hit':rig.pose.bones['Spine'].rotation_mode='XYZ';rig.pose.bones['Spine'].rotation_euler.x=-math.sin(math.pi*t)*.22
  else:
   for i,side in enumerate(('L','R')):
    hip=pelvis@rest['Pelvis'].inverted()@Vector(J['Leg_'+side][0])
    up=.18 if name in ('JumpStart','JumpLoop','Jump') else .04
    ankle=Vector(J['Foot_'+side][0])+Vector((0,.22 if i==0 else -.12,up if i==0 else up*.5))
    leg(side,hip,ankle,-.12)
    sign=-1 if i==0 else 1
    shoulder=desired['Clavicle_'+side]@rest['Clavicle_'+side].inverted()@Vector(J['Arm_'+side][0])
    upper=Vector((sign*(.35 if name=='Fall' else .24),-.12 if name=='Fall' else .18,-.90)).normalized()
    fore=Vector((sign*.10,.45,-.7)).normalized()
    elbow=shoulder+upper*.393335;wrist=elbow+fore*.29
    set_global('Arm_'+side,shoulder,elbow-shoulder)
    set_global('Forearm_'+side,elbow,wrist-elbow)
    set_global('Hand_'+side,wrist,fore)
 if name.startswith('Attack') or name in ('Heavy','Throw','Charge_Spin'):
  side=-1 if name=='Attack_Right' else 1
  rig.pose.bones['Spine'].rotation_mode='XYZ';rig.pose.bones['Spine'].rotation_euler.z=side*math.sin(t*math.pi)*.55
  if name=='Charge_Spin':rig.pose.bones['Root'].rotation_mode='XYZ';rig.pose.bones['Root'].rotation_euler.z=t*math.tau
clips=['Idle','Walk','Run','Sprint','Back_Walk','Back_Run','Strafe_L_Walk','Strafe_L_Run','Strafe_R_Walk','Strafe_R_Run','JumpStart','JumpLoop','Fall','Land','Attack_Left','Attack_Right','Attack_Finish','Heavy','Charge_Spin','Throw','Jump','Front_Flip','Hit','Death']
rig.animation_data_create()
for name in clips:
 action=bpy.data.actions.new(name);rig.animation_data.action=action
 for frame in range(61):
  pose(name,frame/60)
  for p in rig.pose.bones:
   p.rotation_mode='QUATERNION'
   # Pose matrices set above already decomposed into the current rotation mode.
   p.keyframe_insert('location',frame=frame);p.keyframe_insert('rotation_quaternion',frame=frame);p.keyframe_insert('scale',frame=frame)
 track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,0,action);track.mute=True;action.use_fake_user=True
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.scene.render.fps=60;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=60;bpy.context.scene.frame_set(0)
bpy.context.scene['rig_version']='Locomotion 3: anime full-body rhythm, chest/clavicle/neck overlap; original geometry unchanged'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/kai.blend'))
print('LOCOMOTION_RIG_READY',len(J),'bones',len(clips),'clips; original mesh untouched')
