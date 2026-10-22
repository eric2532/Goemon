extends SceneTree
## Draw batching must not alter any native 60 Hz flight/collision decision.
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
const Flight=preload("res://assets/rogue/scripts/ranger_arrow_flight.gd")
const Effects=preload("res://assets/rogue/scripts/effects.gd")
class FixtureGame extends Node3D:
 var enemies=[]
 var player
class BareHero extends Hero:
 func _ready():pass
class Target extends Ninja:
 func _ready():pass
 func combat_aim_point(_from:Vector3)->Vector3:return global_position
 func combat_contact_point(_from:Vector3)->Vector3:return global_position
class Probe extends "res://scripts/rogue_roster_combat.gd":
 var ordered=[]
 func _ready():set_process(false)
 func tint()->Color:return Color.WHITE
 func hit(e:Dictionary={},amount:float=0,_weapon:String="cutlass",_heavy:bool=false,_direction:Vector3=Vector3.ZERO,_element:String="",_presentation:String=""):
  ordered.append(e.uid);e.node.hp-=amount
var checks=0
var failures=0
var game
var hero
var probe
var fx
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func position_of(pr:Dictionary)->Vector3:
 return pr.presentation.transform.origin if pr.has("presentation") else pr.mesh.position
func make_projectile(kind:String,deferred:bool,power:bool=false,curved:bool=false)->Dictionary:
 var mesh=fx.create_projectile("ranger-power-arrow" if power else ("ranger-arrow" if kind=="arrow" else kind),Color.WHITE)
 game.add_child(mesh);mesh.position=Vector3(0,10,10);mesh.scale=Vector3.ONE*2
 var pr={"mesh":mesh,"vel":Vector3(0,0,-60),"life":2.0,"damage":101 if power else 67,"kind":kind,"power":power,"rangeScale":1.0,"color":Color.WHITE,"visualScale":1.0,"width":.2,"hits":[],"pierce":power or kind=="wave","ticket":{},"weapon":"cutlass","heavy":false,"trailTimer":0.0,"deferPresentation":deferred}
 if kind=="arrow":Flight.attach(pr,1,1.0,curved)
 return pr
func snapshot(pr:Dictionary)->Dictionary:
 return {"position":position_of(pr),"vel":pr.vel,"life":pr.life,"hits":pr.hits.duplicate(),"ordered":probe.ordered.duplicate(),"hp":game.enemies.map(func(e):return e.hp),"flight":pr.get("rangerFlight",{}).duplicate(true),"direction":pr.get("flightDirection",Vector3.ZERO),"clock":pr.get("inkClock",0.0)}
func reset_targets():
 probe.ordered.clear()
 for e in game.enemies:e.hp=10000;e.dead=false
func simulate(kind:String,deferred:bool,power:bool,curved:bool)->Dictionary:
 reset_targets();var pr=make_projectile(kind,deferred,power,curved);var states=[]
 var initial=pr.mesh.transform
 var initial_clock=pr.mesh.get_meta("ink_materials")[0].get_shader_parameter("brush_clock")
 for i in 8:
  Actions.update_projectile(probe,pr,1.0/60);states.append(snapshot(pr))
 if deferred:
  check(pr.mesh.transform==initial,"Eight physics ticks leave the deferred projectile draw transform untouched: "+kind)
  check(pr.mesh.get_meta("ink_materials")[0].get_shader_parameter("brush_clock")==initial_clock,"Eight physics ticks leave deferred pigment uniforms untouched: "+kind)
  if pr.has("rangerTrail"):check(not pr.rangerTrail.node.visible,"A staged army tail stays hidden before presentation")
  if probe.has_method("_present_projectiles"):
   probe.projectiles=[pr];probe._present_projectiles();fx.tick(0)
   check(pr.mesh.position.is_equal_approx(position_of(pr)),"Displayed projectile reaches its final native contact/flight position")
   check(is_equal_approx(pr.mesh.get_meta("ink_materials")[0].get_shader_parameter("brush_clock"),pr.inkClock),"Displayed pigment receives the accumulated 60 Hz clock")
   if pr.has("rangerTrail"):check((pr.rangerTrail.node.transform*Vector3.BACK).distance_to(position_of(pr))<.0001,"Displayed army tail ends at final native contact: "+str([kind,power,curved,pr.rangerTrail.node.transform*Vector3.BACK,position_of(pr)]))
  else:check(false,"Combat exposes its frame presentation flush")
 var result={"states":states,"final":snapshot(pr),"draw":pr.mesh.transform}
 if deferred and pr.has("presentation"):check(pr.mesh.transform.is_equal_approx(pr.presentation.transform),"Display commits the accumulated projectile rotation and original scale")
 probe.projectiles.clear();pr.mesh.queue_free();fx.clear()
 return result
func run():
 game=FixtureGame.new();root.add_child(game)
 hero=BareHero.new();hero.game=game;game.player=hero;game.add_child(hero);hero.set_physics_process(false)
 probe=Probe.new();probe.hero=hero;probe.game=game;game.add_child(probe)
 fx=Effects.new();fx.army_trails=true;game.add_child(fx);probe.fx=fx
 # Reverse insertion order proves that native resolver still sorts contacts.
 for z in [4.0,8.0,6.0]:
  var e=Target.new();e.game=game;e.body_radius=.25;e.position=Vector3(0,10,z);game.add_child(e);e.set_physics_process(false);game.enemies.append(e)
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(0,10,3)
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,8,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall)
 await physics_frame
 for fixture in [["arrow",false,false],["arrow",true,false],["arrow",true,true],["wave",false,false],["star",false,false],["bolt",false,false]]:
  var expected=simulate(fixture[0],false,fixture[1],fixture[2])
  var actual=simulate(fixture[0],true,fixture[1],fixture[2])
  check(actual.draw.is_equal_approx(expected.draw),"Deferred rotation and scale match native spinning/curved projectile presentation")
  actual.erase("draw");expected.erase("draw")
  check(actual==expected,"Deferred presentation preserves every native trajectory, lifetime, hit order and damage step: "+str(fixture))
  check(actual.final.life<=0,"Native continuous enemy/cover collision still ends the shot")
  if fixture[1] or fixture[0]=="wave":check(actual.final.ordered==[game.enemies[1].get_instance_id(),game.enemies[2].get_instance_id(),game.enemies[0].get_instance_id()],"Piercing shots keep near-to-far native target ordering before cover")
  else:check(actual.final.ordered==[game.enemies[1].get_instance_id()],"Nonpiercing shot stops at first native target")
 # Flight must also remain native when it reaches range expiry without victims.
 var targets=game.enemies.duplicate();game.enemies.clear();wall.collision_layer=0
 await physics_frame
 for power in [false,true]:
  var ordinary=make_projectile("arrow",false,power,true)
  var deferred=make_projectile("arrow",true,power,true)
  ordinary.life=.045;deferred.life=.045
  for i in 8:
   Actions.update_projectile(probe,ordinary,1.0/60);Actions.update_projectile(probe,deferred,1.0/60)
   check(snapshot(ordinary)==snapshot(deferred),"Free flight and exact expiry tick match native without enemy or wall contacts")
  ordinary.mesh.queue_free();deferred.mesh.queue_free();fx.clear()
 var live=make_projectile("arrow",true);probe.projectiles=[live]
 for i in 8:Actions.update_projectile(probe,live,1.0/60)
 probe._present_projectiles();var shown=live.mesh.transform
 Actions.update_projectile(probe,live,1.0/60);probe._present_projectiles()
 check(live.mesh.transform==shown and not position_of(live).is_equal_approx(live.mesh.position),"A second flush in the same displayed frame cannot resubmit a staged draw pose")
 await process_frame;await process_frame
 probe._present_projectiles()
 check(live.mesh.position.is_equal_approx(position_of(live)),"The next displayed frame commits the accumulated native position")
 probe.projectiles.clear();live.mesh.queue_free();fx.clear()
 game.enemies=targets
 # Zero lifetime and explicit removal must never resurrect deferred visuals.
 var zero=make_projectile("arrow",true);zero.life=0;var before=zero.mesh.transform
 Actions.update_projectile(probe,zero,1.0/60)
 check(zero.mesh.transform==before and not zero.has("rangerTrail"),"Zero-TTL projectile produces no flight or tail")
 zero.mesh.queue_free()
 var cleared=make_projectile("arrow",true);Actions.update_projectile(probe,cleared,1.0/60);probe.projectiles=[cleared]
 probe._clear_projectiles();fx.clear();fx.tick(0)
 check(probe.projectiles.is_empty() and fx.items.is_empty(),"Clearing staged shots releases trails and cannot recreate presentation")
 var freed=make_projectile("arrow",true);freed.mesh.free();probe.projectiles=[freed]
 if probe.has_method("_present_projectiles"):probe._present_projectiles()
 check(not is_instance_valid(freed.mesh),"Presentation safely ignores an externally freed projectile")
 probe.projectiles.clear()
 # Human shots and other native projectile styles keep normal destruction.
 for unpooled_kind in ["star","wave"]:
  var unpooled=make_projectile(unpooled_kind,true);probe.projectiles=[unpooled];probe._clear_projectiles()
  check(unpooled.mesh.is_queued_for_deletion(),"Unpooled native projectile retires normally: "+unpooled_kind)
 fx.army_trails=false
 var human=make_projectile("arrow",false);probe.projectiles=[human];probe._clear_projectiles();fx.army_trails=true
 check(human.mesh.is_queued_for_deletion(),"Human arrows keep their existing destruction lifecycle")
 check(fx.has_method("recycle_projectile"),"Army arrow visuals can retire without reallocating their native meshes on every volley")
 if fx.has_method("recycle_projectile"):
  var retired=make_projectile("arrow",true);Actions.update_projectile(probe,retired,1.0/60)
  var original=retired.mesh;probe.projectiles=[retired];probe._clear_projectiles()
  check(is_instance_valid(original) and not original.visible and original.get_parent()==fx and not original.is_in_group("rogue_projectiles"),"Retired army arrows leave live projectile discovery and remain hidden in their owning pool")
  var reused=fx.create_projectile("ranger-arrow",Color.WHITE);game.add_child(reused)
  check(reused==original and reused.transform==Transform3D.IDENTITY and reused.visible,"The next matching arrow reuses its native geometry with a clean pose")
  check(is_zero_approx(float(reused.get_meta("ink_materials")[0].get_shader_parameter("brush_clock"))),"A recycled arrow starts with fresh pigment timing")
  reused.position=Vector3(77,8,9);var current=reused.transform
  probe.projectiles=[retired];probe._present_projectiles()
  check(reused.transform==current,"An old flight cannot overwrite a recycled arrow's new pose")
  probe.projectiles.clear();fx.recycle_projectile(reused)
  var separate=[]
  for i in 24:
   var arrow=fx.create_projectile("ranger-arrow",Color.WHITE);game.add_child(arrow);separate.append(arrow)
  for arrow in separate:fx.recycle_projectile(arrow)
  var retained=fx.get_children().filter(func(n):return n.has_meta("army_projectile_owner") and not n.is_queued_for_deletion())
  check(retained.size()<=12,"An army caster retains at most twelve retired arrows after a large volley")
  var other=fx.create_projectile("ranger-power-arrow",Color.GREEN);game.add_child(other)
  check(other not in retained,"Power arrows retain their separate native shape and palette")
  fx.recycle_projectile(other)
  var buffed=fx.create_projectile("ranger-power-arrow",Color.GREEN);game.add_child(buffed)
  check(buffed==other,"A full pool of normal arrows cannot starve reuse after the Ranger switches to power shots")
  fx.recycle_projectile(buffed)
 probe.projectiles.clear();game.queue_free();await process_frame
 print("ARMY_PROJECTILE_PRESENTATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
