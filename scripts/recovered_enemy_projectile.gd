extends "res://scripts/character_projectile.gd"
## Prepared source sprites and swept contacts share the character pool.
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Visuals=preload("res://assets/characters/ally_crowd/visuals.res")
const DAGGER_ATLAS=preload("res://assets/characters/crossgate/maze/regular-dagger.png")
const ARROW_ATLAS=preload("res://assets/characters/crossgate/fighters/lancelot/arrow.png")
const WATER_DAGGER_ATLAS=preload("res://assets/characters/crossgate/shin/900050/kunai/projectile.png")
const BOOMERANG_ATLAS=preload("res://assets/characters/crossgate/weapons/boomerang/projectile.png")
const WATER_BOOMERANG_ATLAS=preload("res://assets/characters/crossgate/shin/900050/boomerang/projectile.png")
const THROWN_RANGE=120.0
const THROWN_SPEED=72.0
var dagger_size=0.85
const BladeDance=preload("res://scripts/spells/spell_catalog.gd")
var kind="soldier"
var velocity=Vector3.ZERO
var damage=25.0
var lifetime=100.0/30
var aim=Vector3.ZERO
var target:WeakRef
var visual:MeshInstance3D
var dagger_sprite:Sprite3D
var tail_a:MeshInstance3D
var tail_b:MeshInstance3D
var age=0.0
var impact_sound:AudioStream
var water_wave_scale=1.0
var boomerang_reach=THROWN_RANGE
var boomerang_duration=1.0
var boomerang_origin=Vector3.ZERO
var boomerang_forward=Vector3.FORWARD
var boomerang_side=Vector3.RIGHT
var hit_targets:Dictionary={}
func is_boomerang()->bool:
 return kind=="crossgate_boomerang" or kind=="water_dragon_boomerang"

func boomerang_point(progress:float,home:Vector3)->Vector3:
 var t=clampf(progress,0,1)
 return boomerang_origin+boomerang_forward*boomerang_reach*sin(PI*t)+boomerang_side*boomerang_reach*.23*sin(TAU*t)+(home-boomerang_origin)*t*t*t

func _ready():
 if kind in ["maze_dagger","crossgate_arrow","water_dragon_dagger","crossgate_boomerang","water_dragon_boomerang"]:
  if kind=="maze_dagger":dagger_size=hero.RogueRoster.crossgate_profile(hero.character_id).get("kunai_size",dagger_size)
  dagger_sprite=Sprite3D.new()
  dagger_sprite.texture=BOOMERANG_ATLAS if kind=="crossgate_boomerang" else WATER_BOOMERANG_ATLAS if kind=="water_dragon_boomerang" else WATER_DAGGER_ATLAS if kind=="water_dragon_dagger" else ARROW_ATLAS if kind=="crossgate_arrow" else DAGGER_ATLAS
  dagger_sprite.hframes=8 if kind=="crossgate_boomerang" else 16
  var height=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
  dagger_sprite.pixel_size=height/87.0 if kind in ["crossgate_arrow","water_dragon_dagger","crossgate_boomerang","water_dragon_boomerang"] else height/83.0*2.25*dagger_size
  dagger_sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  dagger_sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  dagger_sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(dagger_sprite)
  return
 if kind=="dark_lumina":Dark.prepare()
 visual=MeshInstance3D.new();visual.mesh=Dark.meshes.fire if kind=="dark_lumina" else Visuals.get_meta("meshes").bullet0
 visual.scale=Vector3.ONE if kind=="dark_lumina" else Vector3.ONE/3.0;add_child(visual)
 if kind=="dark_lumina":
  tail_a=MeshInstance3D.new();tail_a.mesh=visual.mesh;tail_a.scale=Vector3.ONE*.7;add_child(tail_a)
  tail_b=MeshInstance3D.new();tail_b.mesh=visual.mesh;tail_b.scale=Vector3.ONE*.45;add_child(tail_b)
func restart_visual():
 attack_ticket.projectile=true
 age=0
 hit_targets.clear()
 if kind=="water_dragon_boomerang":
  water_wave_scale=hero.model.sprite.pixel_size*hero.model.sprite.global_basis.y.length()*skill_factor("size")/.02
 if is_boomerang():
  boomerang_origin=global_position
  boomerang_forward=velocity.normalized() if not velocity.is_zero_approx() else hero.facing
  boomerang_side=boomerang_forward.cross(Vector3.UP).normalized()
  boomerang_duration=maxf(.3,PI*boomerang_reach/maxf(1,velocity.length()))
  lifetime=boomerang_duration
 if dagger_sprite!=null:
  update_dagger_facing()
  return
 if kind=="soldier":visual.mesh=Visuals.get_meta("meshes").bullet0
 if velocity.length_squared()>.001:basis=Basis(Quaternion(Vector3.BACK,velocity.normalized()))

func update_dagger_facing():
 if is_boomerang():
  dagger_sprite.frame=posmod(-floori(age*24),dagger_sprite.hframes)
  return
 var camera=get_viewport().get_camera_3d()
 if camera==null:
  dagger_sprite.frame=0
  return
 var projection=Vector2(velocity.dot(camera.global_basis.x),-velocity.dot(camera.global_basis.y))
 var frame=posmod(roundi(projection.angle()*16/TAU),16)
 if dagger_sprite.frame!=frame:dagger_sprite.frame=frame
func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 age+=delta
 var dark=kind=="dark_lumina"
 if dark:
  if age>.4 and lifetime>.53:
   var point=aim;var victim=target.get_ref() if target!=null else null
   if age>.8 and is_instance_valid(victim) and not victim.dead:point=AttackChain.aim_point(victim,global_position)
   var desired=(point-global_position).normalized();var direction=velocity.normalized();var angle=direction.angle_to(desired)
   if angle>.00001:velocity=direction.slerp(desired,minf(1,Dark.FIRE_SPREAD*(2.25 if age>.8 else .75)*delta/angle))*Dark.FIRE_SPEED*skill_factor("travel_speed")
  visual.set_instance_shader_parameter("playback_age",age)
  tail_a.set_instance_shader_parameter("playback_age",maxf(0,age-.08));tail_a.position=Vector3(0,0,-.7)*Dark.FIRE_SCALE
  tail_b.set_instance_shader_parameter("playback_age",maxf(0,age-.16));tail_b.position=Vector3(0,0,-1.3)*Dark.FIRE_SCALE
  basis=Basis(Quaternion(Vector3.BACK,velocity.normalized()))
 elif dagger_sprite!=null:update_dagger_facing()
 else:visual.mesh=Visuals.get_meta("meshes")["bullet%d"%posmod(floori(age*30),16)]
 var from=global_position;var next=from+velocity*minf(delta,lifetime);lifetime-=delta
 var boomerang=is_boomerang()
 if boomerang:
  next=boomerang_point(age/boomerang_duration,hero.auto_aim_origin())
  velocity=(next-from)/maxf(.00001,delta)
 var wall=AttackChain.world_ray(self,from,next)
 var end:Vector3=next if wall.is_empty() else wall.position
 var radius=(dagger_sprite.pixel_size*52 if boomerang else Dark.FIRE_RADIUS if dark else .66*dagger_size if dagger_sprite!=null else .576)*skill_factor("hit_area")
 var contact={} if boomerang else AttackChain.nearest_contact(game,self,from,end,radius) if dagger_sprite==null or target==null else locked_contact(from,end,radius)
 if boomerang:
  for enemy in AttackChain.segment_enemy_candidates(game,from,end,radius):
   if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
   var touch=AttackChain.segment_contact(enemy,from,end,radius)
   if touch.is_empty():continue
   var center=from.lerp(end,float(touch.t))
   if not AttackChain.clear_line(self,center,AttackChain.aim_point(enemy,center)):continue
   hit_targets[enemy.get_instance_id()]=true;touch.enemy=enemy
   damage_contact(touch,dark,hit_targets.size()==1)
 elif not contact.is_empty():damage_contact(contact,dark)
 if not contact.is_empty() or not wall.is_empty() or lifetime<=0:
  if dark and game.get("crowd")!=null:
   game.crowd.army.presentation.dark_sound(end,"fire_impact",true,attack_ticket);game.crowd.army.presentation.add_effect("dark-impact",end,.53,1)
  retire();return
 global_position=next

func damage_contact(contact:Dictionary,dark:bool,primary:bool=true):
 if attack_ticket.has("sure_strike_size"):attack_ticket.impact_point=contact.point
 var connected=contact.enemy.take_hit(damage,velocity.normalized(),false,attack_ticket)!=false
 attack_ticket.erase("impact_point")
 var source=Dark.PLAYER if dark else int(attack_ticket.get("crossgate_sound_source",BladeDance.Roster.MAZE_ID)) if dagger_sprite!=null else 21
 var blade_dance=dagger_sprite!=null and attack_ticket.get("action","")==BladeDance.BLADE_DANCE and game.get("crowd")!=null
 if connected and blade_dance:game.crowd.army.presentation.blade_dance_burst(contact.enemy,contact.point)
 var impact_cue="coin_hit" if kind=="crossgate_arrow" else "cg_dagger_hit" if kind=="maze_dagger" else ""
 var impact_sample:AudioStream=impact_sound if impact_sound!=null else SoundLibrary.CROSSGATE_BOW_SOUNDS.coin_hit if kind=="crossgate_arrow" else null
 var generic_impact=not dark and not blade_dance and kind!="water_dragon_boomerang"
 if connected:
  if kind=="water_dragon_boomerang" and game.get("crowd")!=null:
   game.crowd.army.presentation.water_boomerang_burst(contact.point,hero.model.direction_for(velocity),water_wave_scale)
  if hero.ai_controlled:game.confirm_ally_impact(contact.enemy,contact.point,velocity.normalized(),0,true,source,generic_impact,impact_sample,impact_cue)
  else:
   game.confirm_impact(contact.enemy,contact.point,velocity.normalized(),0,true,source,generic_impact,impact_sample,primary and attack_ticket.get("action","")!="stat_counter",impact_cue)
   if (not primary or attack_ticket.get("action","")=="stat_counter") and impact_sound!=null:game.sound("hit",.65,false,attack_ticket,source,impact_sound)

func locked_contact(from:Vector3,to:Vector3,radius:float)->Dictionary:
 var enemy=target.get_ref()
 if not is_instance_valid(enemy) or enemy.dead:return {}
 var contact=AttackChain.segment_contact(enemy,from,to,radius)
 if contact.is_empty():return {}
 var center=from.lerp(to,float(contact.t))
 if not AttackChain.clear_line(self,center,AttackChain.aim_point(enemy,center)):return {}
 contact.enemy=enemy
 return contact
