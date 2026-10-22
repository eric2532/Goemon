extends Node3D
## Source bazooka missile with fitted swept contacts and native capped acceleration.
const Profile=preload("res://scripts/recovered_yae_combat_profile.gd")
var game: Node
var hero: Hero
var kind="bazooka"
var velocity=Vector3.ZERO
var native_acceleration=Vector3.ZERO
var damage=42.0
var damage_scale=1.0
var hit_radius=.18
var blast_radius=1.25
var lifetime=3.0
var age=0.0
var resolved=false
var attack_ticket: Dictionary={}
var hit_targets: Dictionary={}
var ornament: Node3D
var target: WeakRef
var speed=2.7284562
var source_scale=.01515809

func _ready():
 add_to_group("yae_projectiles")
 if kind=="lock_on":damage=32.0
 if is_instance_valid(hero) and is_instance_valid(hero.model) and hero.model.has_method("create_projectile_visual"):
  ornament=hero.model.create_projectile_visual(kind)
  if ornament:add_child(ornament)
 _update_visual()
func _physics_process(delta: float):
 if resolved or is_queued_for_deletion():return
 if not is_instance_valid(game) or not is_instance_valid(hero) or not game.playing:queue_free();return
 if game.paused:return
 var step=minf(delta,maxf(lifetime,0))
 var from=global_position
 if kind=="lock_on" and target!=null and velocity.length()>=speed-.000001:
  var victim=target.get_ref()
  if is_instance_valid(victim) and not victim.dead:
   # Source801F1130 accelerates.6 per native tick, capped by801F1F34 at6.
   var direction=(AttackChain.aim_point(victim,from)-from).normalized()
   #801F1130 replaces actor78/7C/80. Keep this vector below the cap,
   # as801F1F34 does; never reintroduce the original launch force.
   native_acceleration=direction*(.6*30.0*30.0*source_scale)
 if native_acceleration.length_squared()>.000001:
  velocity=(velocity+native_acceleration*step).limit_length(speed)
 var next=from+velocity*step
 age+=step;lifetime-=step
 var ray=PhysicsRayQueryParameters3D.create(from,next,1);ray.hit_from_inside=true
 var wall=get_world_3d().direct_space_state.intersect_ray(ray)
 var end: Vector3=next if wall.is_empty() else wall.position
 var nearest: Ninja=null;var nearest_t=INF;var point=Vector3.ZERO
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
  var hit=AttackChain.segment_contact(enemy,from,end,hit_radius)
  if hit.is_empty() or float(hit.t)>=nearest_t:continue
  var center=from.lerp(end,float(hit.t))
  if not _clear(center,AttackChain.aim_point(enemy,center)):continue
  nearest=enemy;nearest_t=float(hit.t);point=center
 if nearest!=null:global_position=point;explode(point);return
 if not wall.is_empty():global_position=wall.position+wall.normal*.025;explode(global_position);return
 global_position=next
 if lifetime<=0:queue_free();return
 _update_visual()
func _clear(from: Vector3,to: Vector3)->bool:
 if from.distance_squared_to(to)<.000001:return true
 var ray=PhysicsRayQueryParameters3D.create(from,to,1);ray.hit_from_inside=true
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func _damage(enemy: Ninja,point: Vector3):
 if hit_targets.has(enemy.get_instance_id()):return
 hit_targets[enemy.get_instance_id()]=true
 var direction=(point-global_position).normalized()
 if direction.length_squared()<.001:direction=velocity.normalized()
 enemy.take_hit(damage*damage_scale,direction,true,attack_ticket)
 # Ticket ownership survives roster changes; source hero may now wear another body.
 if game.player==hero and not hero.ai_controlled:game.confirm_impact(enemy,point,direction,2,true,17)
 else:game.confirm_ally_impact(enemy,point,direction,2,true,17)
 game.sound("yae_bazooka_impact",.55,false,attack_ticket,17)
func explode(point: Vector3):
 if resolved:return
 global_position=point
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
  var hit=AttackChain.segment_contact(enemy,point,point,blast_radius)
  if hit.is_empty():continue
  var contact: Vector3=hit.point
  if _clear(point,contact):_damage(enemy,contact)
 resolved=true;game.burst(point,Color("ffd874"),22,1.0)
 queue_free()
func _update_visual():
 if not is_instance_valid(ornament):return
 if velocity.length_squared()>.001:ornament.quaternion=Quaternion(Vector3.FORWARD,velocity.normalized())
