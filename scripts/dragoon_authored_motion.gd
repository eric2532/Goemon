extends RefCounted
## Approved Blender poses in place. Collision travel and damage remain game-owned.
const SOURCE="res://assets/animations/dragoon_approved.json"
static var cached: Dictionary={}
var skeleton: Skeleton3D
var indices: Array[int]=[]
var clips: Dictionary={}
var idle_time=0.0
var air_age=0.0
var was_air=false
var was_special=false
var landing_age=100.0
var special_landing=false
var previous_vertical=0.0
var last_clip=""
var last_frame=1.0

func _init(sk: Skeleton3D):
 skeleton=sk
 if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 for name_ in cached.bones:indices.append(sk.find_bone(name_))
 for key in cached.clips:
  var frames: Array=[]
  var weapons: Array[Transform3D]=[]
  for sample in cached.clips[key].frames:
   var globals: Dictionary={}
   var locals: Array[Transform3D]=[]
   for b in indices.size():
    var value=unpack(sample.bones[b])
    value.basis=value.basis*sk.get_bone_global_rest(indices[b]).basis
    globals[indices[b]]=value
   for index in indices:
    var parent=sk.get_bone_parent(index)
    locals.append(globals[parent].affine_inverse()*globals[index] if parent>=0 else globals[index])
   frames.append(locals);weapons.append(unpack(sample.lance))
  clips[key]={"frames":frames,"weapons":weapons}

func unpack(v: Array)->Transform3D:
 return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))

func reset():
 idle_time=0;air_age=0;was_air=false;was_special=false;landing_age=100;special_landing=false;previous_vertical=0;last_clip=""

static func remap_frame(t: float,points: Array)->float:
 for i in range(1,points.size()):
  if t<=points[i][0]:return lerpf(points[i-1][1],points[i][1],clampf(inverse_lerp(points[i-1][0],points[i][0],t),0,1))
 return float(points[-1][1])

func apply(actor,state: Dictionary,delta: float)->bool:
 var airborne=not bool(state.get("grounded",true))
 var vy=float(state.get("vertical",0))
 var travel=state.get("travel")
 var special=travel is Dictionary and travel.get("kind","")=="lance-leap"
 # move_and_collide confirms impact before is_on_floor refreshes next tick.
 if not special and (was_special or special_landing) and float(state.get("landing",0))>0 and vy<=0:airborne=false
 var entered_landing=(was_air or was_special) and not airborne and not special
 if entered_landing:
  landing_age=0;special_landing=was_special
 else:landing_age+=delta
 if airborne and (not was_air or vy>previous_vertical+3):air_age=0
 else:air_age+=delta
 was_air=airborne;was_special=special;previous_vertical=vy
 var attack=state.get("attack")
 var clip=""
 var frame=1.0
 var weight=1.0
 if special:
  clip="jump_strike"
  if travel.get("phase","arc") in ["drop","aimed-drop"]:frame=150
  else:frame=remap_frame(float(travel.get("time",0))/maxf(.01,float(travel.get("duration",.72))),[[0.0,1.0],[.12,20.0],[.4,48.0],[.53,84.0],[.72,114.0],[1.0,150.0]])
 elif float(state.get("roll",0))>0 or state.get("dive")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("drinkGesture",0))>0 or state.get("crouched",false):
  last_clip="";return false
 elif attack is Dictionary and attack.get("style","")=="dragoon-sweep":
  apply_sweep(actor,attack);last_clip="sweep";return true
 elif attack is Dictionary and attack.get("primary",false):
  clip="attack"
  var contact=maxf(.001,float(attack.get("contact",.1)))
  var duration=maxf(contact+.001,float(attack.get("duration",.36)))
  frame=remap_frame(float(attack.get("time",0)),[[0.0,1.0],[contact,7.0],[contact+(duration-contact)*.20,12.0],[contact+(duration-contact)*.43,18.0],[contact+(duration-contact)*.50,20.0],[duration,34.0]])
 elif attack!=null or float(state.get("shot",0))>0:
  last_clip="";return false
 elif airborne:
  clip="jump"
  frame=remap_frame(air_age,[[0.0,1.0],[.07,12.0],[.12,20.0],[.24,40.0],[.30,56.0]]) if vy>=0 else lerpf(72,84,clampf(-vy/20,0,1))
 elif landing_age<(.8 if special_landing else .7):
  clip="jump_strike" if special_landing else "jump"
  var end=228.0 if special_landing else 140.0
  var begin=180.0 if special_landing else 98.0
  frame=minf(end,begin+landing_age*60)
  weight=1.0-smoothstep(.2,4.0,float(state.get("motionSpeed",0)))
 else:
  clip="idle";idle_time=fposmod(idle_time+delta,3.6)
  frame=1+idle_time*60
  weight=1.0-smoothstep(.1,2.2,float(state.get("motionSpeed",0)))
 last_clip=clip;last_frame=frame
 if weight<.001:return false
 sample(actor,clip,frame,weight,float(state.get("meleeVisualScale",1)) if attack is Dictionary and attack.get("primary",false) else 1.0)
 return true

func sample(actor,key: String,frame: float,weight: float,weapon_scale: float=1.0):
 var clip: Dictionary=clips[key]
 var t=clampf(frame-1,0,clip.frames.size()-1)
 var a=int(t);var b=mini(a+1,clip.frames.size()-1);var blend=t-a
 # Legacy procedural stances tilt and bounce the whole model. Fade those out
 # because both body and weapon already contain the approved authored pose.
 actor.model.position=actor.model.position.lerp(Vector3.ZERO,weight)
 actor.model.quaternion=actor.model.quaternion.slerp(Quaternion.IDENTITY,weight)
 var before: Dictionary={}
 var posed: Dictionary={}
 for index in indices:before[index]=skeleton.get_bone_global_pose(index)
 for i in indices.size():
  var index=indices[i];var parent=skeleton.get_bone_parent(index)
  var native: Transform3D=before[parent].affine_inverse()*before[index] if parent>=0 else before[index]
  var target: Transform3D=clip.frames[a][i].interpolate_with(clip.frames[b][i],blend)
  var local=native.interpolate_with(target,weight)
  posed[index]=posed[parent]*local if parent>=0 else local
 for index in indices:skeleton.set_bone_global_pose(index,posed[index])
 var lance: Transform3D=clip.weapons[a].interpolate_with(clip.weapons[b],blend)
 lance.basis=lance.basis.scaled(Vector3.ONE*weapon_scale)
 var weapon: Node3D=actor.joints.Weapon_Cutlass.node
 weapon.global_transform=weapon.global_transform.interpolate_with(skeleton.global_transform*lance,weight)

func apply_sweep(actor,attack: Dictionary):
 var progress=clampf(float(attack.get("time",0))/maxf(.001,float(attack.get("duration",.84))),0,1)
 var frame=remap_frame(progress,[[0.0,1.0],[.20,7.0],[.70,18.0],[1.0,34.0]])
 sample(actor,"attack",frame,1.0,float(attack.get("meleeWeaponScale",1)))
 last_frame=frame
 var yaw=remap_frame(progress,[[0.0,0.0],[.19,1.15],[.70,-1.15],[1.0,0.0]])
 var spine=skeleton.find_bone("Spine")
 var pivot=skeleton.get_bone_global_pose(spine).origin
 var turn=Basis(Vector3.UP,yaw)
 var rotation=Transform3D(turn,pivot-turn*pivot)
 var posed: Dictionary={}
 for index in indices:
  var ancestor=index
  while ancestor>=0:
   if ancestor==spine:
    posed[index]=rotation*skeleton.get_bone_global_pose(index);break
   ancestor=skeleton.get_bone_parent(ancestor)
 var weapon: Node3D=actor.joints.Weapon_Cutlass.node
 var lance: Transform3D=skeleton.global_transform.affine_inverse()*weapon.global_transform
 for index in posed:skeleton.set_bone_global_pose(index,posed[index])
 weapon.global_transform=skeleton.global_transform*rotation*lance
