extends "res://scripts/character_projectile.gd"
## Storm Bolt and its attached status art use the existing character lease pool.
const Visual=preload("res://scripts/mountain_king_visual.gd")
var kind="bolt"
var visual:MeshInstance3D
var target:Node3D
var velocity=Vector3.ZERO
var damage=100.0
var age=0.0
var lifetime=4.0
var status_seconds=5.0
var resolved=false
var impact_age=0.0
func _ready():
 visual=Visual.new();add_child(visual);visual.setup(kind);visual.scale=Vector3.ONE*.03
func restart_visual():
 age=0;resolved=false;impact_age=0
 if kind!="bolt" and is_instance_valid(target):global_position=target.combat_bounds().get_center()+Vector3.UP*target.combat_bounds().size.y*.55
 visual.pose("Birth",0)
static func status(caster:Hero,script:Script,key:String,victim:Node3D,seconds:float,ticket:Dictionary):
 var pool=preload("res://scripts/character_projectile_pool.gd").service(caster.game)
 for shot in pool.all.get(pool.key_for(caster,script,key),[]):
  if shot.pool_live and not shot.resolved and shot.target==victim:
   shot.lifetime=maxf(shot.lifetime,shot.age+seconds);return
 pool.launch(caster,script,key,{"kind":key,"target":victim,"lifetime":seconds,"attack_ticket":ticket})
func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 age+=delta
 if kind!="bolt":
  if not resolved and (not is_instance_valid(target) or target.dead or age>=lifetime):resolved=true;impact_age=0;target=null
  if resolved:
   impact_age+=delta;visual.pose("Death",impact_age)
   if impact_age>=3.333:retire()
   return
  global_position=target.combat_bounds().get_center()+Vector3.UP*target.combat_bounds().size.y*.55
  visual.pose("Birth",age) if age<.434 else visual.pose("Stand",age-.434,true)
  return
 if resolved:
  impact_age+=delta;visual.pose("Death",impact_age)
  if impact_age>=1.267:retire()
  return
 if is_instance_valid(target) and not target.dead:
  velocity=(AttackChain.aim_point(target,global_position)-global_position).normalized()*velocity.length()
 var end=global_position+velocity*delta
 var wall=AttackChain.world_ray(self,global_position,end)
 if not wall.is_empty():end=wall.position
 var hit=AttackChain.nearest_contact(game,self,global_position,end,.35*skill_factor("hit_area"))
 if not hit.is_empty():
  hit.enemy.take_hit(damage,velocity.normalized(),false,attack_ticket)
  if not hit.enemy.dead:
   var seconds=3.0 if hit.enemy.variant in [4,17,18] else status_seconds
   if hit.enemy.has_method("apply_stun"):hit.enemy.apply_stun(seconds)
   else:hit.enemy.combat_knockback(Vector3.ZERO,0,seconds)
   status(hero,get_script(),"stun",hit.enemy,3.0 if hit.enemy.variant in [4,17,18] else status_seconds,attack_ticket)
  impact(hit.point);return
 if not wall.is_empty():impact(wall.position);return
 global_position=end
 visual.rotation.y=atan2(-velocity.x,-velocity.z)+PI/2
 visual.pose("Birth",age,true)
 if age>=lifetime:retire()
func impact(point:Vector3):
 global_position=point;resolved=true;target=null;impact_age=0
 game.sound("wc_bolt_hit",.8,false,attack_ticket,33)
 visual.pose("Death",0)
