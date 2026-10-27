extends HeroModel
## Selected fighters reuse the army's prepared pose atlas and the boss visual.
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const BOSS_PLAYER_SCALE=1.0
static var meshes={}
var role=0
var combat:Node
var crowd:MultiMeshInstance3D
var skull:Node3D
var resource:Resource
var pose_clock=0.0
var cast_clock=0.0
var cast_owner:Node
var current_clip=""
var current_row=0
var walk_tick=0.0

func _ready():
 body=Node3D.new();add_child(body)
 head=driver("Head",Vector3(0,1.7,0))
 arms.assign([driver("Arm_L",Vector3(-.3,1.2,0)),driver("Arm_R",Vector3(.3,1.2,0))])
 legs.assign([driver("Leg_L",Vector3(-.2,.5,0)),driver("Leg_R",Vector3(.2,.5,0))])
 scarf=driver("Scarf",Vector3.ZERO)
 hair_normal=Node3D.new();body.add_child(hair_normal)
 hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
 pipe=Node3D.new();body.add_child(pipe)
 coin=Node3D.new();body.add_child(coin);coin.hide()
 chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
 locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
 if role==Roles.BOSS:
  skull=preload("res://scripts/forest/skullpion_visual.gd").new();skull.game=get_parent().game;body.add_child(skull)
  skull.scale=Vector3.ONE*BOSS_PLAYER_SCALE;skull.rotation.y=PI
  skull.title.hide();skull.set_process(false)
 else:
  resource=Visual.data(role)
  if not meshes.has(role):meshes[role]=Visual.make_mesh(role)
  crowd=MultiMeshInstance3D.new();crowd.multimesh=MultiMesh.new()
  crowd.multimesh.transform_format=MultiMesh.TRANSFORM_3D;crowd.multimesh.use_custom_data=true
  crowd.multimesh.mesh=meshes[role];crowd.multimesh.instance_count=1
  crowd.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
  crowd.custom_aabb=meshes[role].custom_aabb if role in [Roles.DARK_LUMINA_2,Roles.DARK_LUMINA_3] else resource.get_meta("bounds");body.add_child(crowd)
 animate(0,0,true,0,0,false,0,false)

func bounds()->AABB:
 return AABB(Vector3(-3,0,-4)*Roles.BOSS_SCALE,Roles.BOSS_SIZE) if role==Roles.BOSS else Visual.hurt_bounds(role)

func pose(clip:String,tick:float,loop:bool):
 current_clip=clip
 if skull!=null:skull.pose(clip,tick/30.0,loop);return
 var clips:Dictionary=resource.get_meta("clips")
 var selected:Dictionary=clips.get(clip,clips[resource.get_meta("semantics").idle])
 var index=posmod(floori(tick),int(selected.ticks)) if loop else clampi(floori(tick),0,int(selected.ticks)-1)
 current_row=int(selected.rows[index])
 var color_mode=0.0
 if role==Roles.DARK_LUMINA_3 and is_instance_valid(combat) and combat.is_attacking():
  color_mode=combat.presentation_mode()
 crowd.multimesh.set_instance_custom_data(0,Color(current_row,0,color_mode,0))

func animate(delta:float,speed:float,grounded:bool,vertical:float,_attack:float,_heavy:bool,_combo:int,_dodge:bool):
 pose_clock+=delta;cast_owner=null;cast_clock=0
 locomotion.update(delta,locomotion_velocity,grounded,vertical,0,false)
 body.rotation.y=0
 if skull!=null:skull.effects.tick(delta)
 if is_instance_valid(combat) and not combat.clip.is_empty():
  if role==Roles.BOSS and combat.action==104 and combat.is_attacking() and combat.marker==0:
   pose("Castle_Jump",30*(1-clampf(vertical/combat.LEAP_SPEED,0,1)),false)
  elif role==Roles.BOSS and combat.action==105 and combat.is_attacking():
   # The source buries the tail at 3.7 s; align that pose with the first emergence.
   var time=remap(combat.elapsed,0,1.9,0,3.7) if combat.elapsed<1.9 else remap(combat.elapsed,1.9,combat.duration,3.7,combat.duration)
   pose(combat.clip,time*30,false)
  elif role==Roles.BOSS and combat.action==102 and combat.is_attacking() and combat.elapsed>=1.5:
   body.rotation.y=TAU*clampf((combat.elapsed-1.5)/1.2,0,1);pose("Castle_Idle",0,true)
  else:
   pose(combat.clip,combat.pose_tick,false)
   if role==Roles.DARK_LUMINA_2:body.rotation.y=combat.spin_yaw()
  if skull!=null:skull.ground_body(combat.action if grounded else 104)
  return
 if role==Roles.BOSS:
  if not grounded:
   pose("Castle_Jump",30*(1-clampf(vertical/combat.LEAP_SPEED,0,1)),false);skull.ground_body(104);return
  pose("Castle_Walk" if speed>.1 else "Castle_Idle",pose_clock*30*(Roles.BOSS_MOVE_SPEED if speed>.1 else 1.0),true)
  if is_instance_valid(combat):skull.ground_body(100)
  return
 if role==Roles.DARK_LUMINA_2 and not grounded:
  pose("Source__801f0478",lerpf(22,38,1-clampf(vertical/Roles.Dark.LEAP_SPEED,0,1)),false);return
 if role==Roles.DARK_LUMINA_2 and speed>.1:
  var before=walk_tick
  walk_tick+=delta*speed/Roles.stats(role).stride*Roles.Dark.WALK_TICKS
  if is_instance_valid(combat):
   for step in Roles.Dark.steps_between(before,walk_tick):combat.dark_sound("step")
  pose(resource.get_meta("semantics").walk,walk_tick,true);return
 var semantic:Dictionary=resource.get_meta("semantics")
 var clip:String=semantic.walk if role==1 else semantic.run
 pose(clip if speed>.1 else semantic.idle,pose_clock*30*(maxf(.3,speed/(Roles.stats(role).speed*(Roles.Dark.SCALE if role==Roles.DARK_LUMINA_2 else 1.0))) if speed>.1 else 1),true)

func animate_spell(delta:float,spell:Node):
 body.rotation.y=0
 if spell.controller!=null and spell.controller.get("role")==role and spell.controller.get("clip")!="":
  cast_owner=spell;pose(spell.controller.clip,spell.controller.pose_tick,false)
  if role==Roles.DARK_LUMINA_2:body.rotation.y=spell.controller.spin_yaw()
  return
 if cast_owner!=spell:cast_owner=spell;cast_clock=0
 cast_clock+=delta
 # Reuse this body's attack gesture; the equipped controller still owns every hit.
 var clip="801ade54" if role==Roles.BOSS else str(resource.get_meta("semantics").attack[0])
 pose(clip,cast_clock*30,true)

func sync_skeleton():pass
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass

func _process(delta:float):
 if is_instance_valid(combat) and combat.mode=="dead":
  var before:float=combat.pose_tick;combat.pose_tick+=delta*30
  if role==Roles.DARK_LUMINA_2:
   if before<63 and combat.pose_tick>=63:combat.dark_sound("death_final")
   if before<140 and combat.pose_tick>=140:combat.dark_sound("breakup")
  pose(combat.clip,combat.pose_tick,false)
