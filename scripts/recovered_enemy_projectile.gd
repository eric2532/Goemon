extends "res://scripts/character_projectile.gd"
## Prepared source sprites and swept contacts share the character pool.
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Visuals=preload("res://assets/characters/ally_crowd/visuals.res")
var kind="soldier"
var velocity=Vector3.ZERO
var damage=25.0
var lifetime=100.0/30
var aim=Vector3.ZERO
var target:WeakRef
var visual:MeshInstance3D
var tail_a:MeshInstance3D
var tail_b:MeshInstance3D
var age=0.0
func _ready():
 if kind=="dark_lumina":Dark.prepare()
 visual=MeshInstance3D.new();visual.mesh=Dark.meshes.fire if kind=="dark_lumina" else Visuals.get_meta("meshes").bullet0
 visual.scale=Vector3.ONE if kind=="dark_lumina" else Vector3.ONE/3.0;add_child(visual)
 if kind=="dark_lumina":
  tail_a=MeshInstance3D.new();tail_a.mesh=visual.mesh;tail_a.scale=Vector3.ONE*.7;add_child(tail_a)
  tail_b=MeshInstance3D.new();tail_b.mesh=visual.mesh;tail_b.scale=Vector3.ONE*.45;add_child(tail_b)
func restart_visual():
 age=0
 if kind=="soldier":visual.mesh=Visuals.get_meta("meshes").bullet0
 if velocity.length_squared()>.001:basis=Basis(Quaternion(Vector3.BACK,velocity.normalized()))
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
 else:visual.mesh=Visuals.get_meta("meshes")["bullet%d"%posmod(floori(age*30),16)]
 var from=global_position;var next=from+velocity*minf(delta,lifetime);lifetime-=delta
 var wall=AttackChain.world_ray(self,from,next)
 var end:Vector3=next if wall.is_empty() else wall.position
 var contact=AttackChain.nearest_contact(game,self,from,end,(Dark.FIRE_RADIUS if dark else .576)*skill_factor("hit_area"))
 if not contact.is_empty():
  contact.enemy.take_hit(damage,velocity.normalized(),false,attack_ticket)
  if hero.ai_controlled:game.confirm_ally_impact(contact.enemy,contact.point,velocity.normalized(),0,true,Dark.PLAYER if dark else 21,not dark)
  else:game.confirm_impact(contact.enemy,contact.point,velocity.normalized(),0,true,Dark.PLAYER if dark else 21,not dark)
 if not contact.is_empty() or not wall.is_empty() or lifetime<=0:
  if dark and game.get("crowd")!=null:
   game.crowd.army.presentation.dark_sound(end,"fire_impact",true);game.crowd.army.presentation.add_effect("dark-impact",end,.53,1)
  retire();return
 global_position=next
