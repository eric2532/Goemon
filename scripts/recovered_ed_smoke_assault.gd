extends RefCounted
## Playable adaptation of SC06/016 states9..15: source04 somersault,
## source03 leap, actor2FD/2FF balls and helpers8017ECE0/8017EDA0.
## Three hops, steering, distances and damage are port tuning.
const Orb=preload("res://scripts/recovered_ed_assault_orb.gd")
const HOP=41.0/30.0
const THROW=31.0/30.0
var combat: Node
var clock=0.0
var hop=0
var thrown=false
var balls_fired=0
var cast_stats={"bursts":0}
var bursts: int:
 get:return cast_stats.bursts
var charge: Sprite3D
var start=Vector3.ZERO
var destination=Vector3.ZERO

func begin():
 cancel();clock=0;hop=0;thrown=false;balls_fired=0;cast_stats={"bursts":0}
 _begin_hop()
func _begin_hop():
 var hero=combat.hero
 start=hero.global_position
 var forward=hero.combat_attack_direction();forward.y=0
 if forward.length_squared()<.001:forward=hero.facing
 forward=forward.normalized()
 hero.facing=forward;hero.model.rotation.y=atan2(-forward.x,-forward.z)
 destination=start+(forward*2.0+forward.cross(Vector3.UP)*(4.5 if hop%2==0 else -4.5))*hero.growth_multiplier()
 # Trace downward at the destination; actual travel still uses move_and_slide.
 var ray=PhysicsRayQueryParameters3D.create(destination+Vector3.UP*8,destination-Vector3.UP*30,1)
 ray.exclude=[hero.get_rid()]
 var floor_=hero.get_world_3d().direct_space_state.intersect_ray(ray)
 if not floor_.is_empty():destination.y=floor_.position.y+.05
 combat.clip=hero.model.motion("source_04");_smoke()
 charge=Orb.sprite(hero,preload("res://assets/characters/recovered_leaders/ed/assault/charge.png"),.085)
 charge.add_to_group("ed_assault_charge");_update_charge()
 combat.game.sound("ed_assault_reposition",.5,false,hero.attack_ticket,14)
func advance(step: float):
 var remaining=maxf(0,step)
 while remaining>0 and combat.mode=="smoke_assault":
  var boundary=HOP if hop<3 else 16.0/30.0
  var amount=minf(remaining,maxf(0,boundary-clock))
  clock+=amount;remaining-=amount
  if hop<3:
   _update_charge()
   if clock>=17.0/30.0:combat.clip=combat.hero.model.motion("source_03")
   if not thrown and clock+.000001>=THROW:
    thrown=true;combat.hero.facing=combat.hero.combat_attack_direction()
    combat.hero.model.rotation.y=atan2(-combat.hero.facing.x,-combat.hero.facing.z)
    _release_ball()
    combat.game.sound("ed_assault_leap",.5,false,combat.hero.attack_ticket,14)
  if clock+.000001<boundary:break
  clock=0;hop+=1;thrown=false
  if hop<3:_begin_hop()
  elif hop==3:
   combat.clip=combat.hero.model.motion("source_04")
  else:combat.finish_attack()
func motion_time()->float:
 return clock if hop>=3 or clock<17.0/30.0 else clock-17.0/30.0
func velocity()->Vector3:
 if hop>=3:return Vector3.ZERO
 var u=clampf(clock/HOP,0,1)
 var desired=start.lerp(destination,u)+Vector3.UP*sin(u*PI)*3.5*combat.hero.growth_multiplier()
 # Physics owns collisions, so this cannot teleport through walls or gates.
 return (desired-combat.hero.global_position)/maxf(.0001,combat.hero.get_physics_process_delta_time())
func _smoke():
 var effect=SkySmoke.new();effect.game=combat.game;effect.stomp=true
 effect.position=combat.hero.global_position;effect.add_to_group("ed_assault_smoke");combat.game.add_child(effect)
func _update_charge():
 if not is_instance_valid(charge):return
 charge.global_position=combat._release_origin("R")
 charge.scale=Vector3.ONE*lerpf(.3,1.0,clampf(clock/THROW,0,1))
func _release_ball():
 cancel()
 var hero=combat.hero
 var ball=Orb.new();ball.game=combat.game;ball.hero=hero
 ball.attack_ticket=hero.attack_ticket;ball.cast_stats=cast_stats
 ball.damage=90.0*hero.damage_multiplier();ball.attack_scale=hero.growth_multiplier();ball.range_scale=hero.pickup_multiplier("range")
 ball.velocity=(hero.facing*10.0+Vector3.UP*5.5)*ball.attack_scale
 combat.game.add_child(ball);ball.global_position=combat._release_origin("R")
 ball.global_position.y=maxf(ball.global_position.y,hero.global_position.y+1.5*ball.attack_scale);balls_fired+=1
 combat.game.sound("throw",.6,false,ball.attack_ticket,14)
func cancel():
 if is_instance_valid(charge):charge.free()
 charge=null
