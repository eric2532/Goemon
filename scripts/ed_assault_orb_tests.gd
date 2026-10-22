extends "res://scripts/recovered_leader_projectile_tests.gd"

class World extends Node3D:
 var breakable_buildings=[]
class OrbArena extends Arena:
 var world:Node3D
 var transitioning=false

func orb(at:Vector3,velocity_:Vector3=Vector3.ZERO):
 var node=projectile_script.new();node.game=arena;node.hero=caster;node.position=at;node.velocity=velocity_;node.damage=270;node.cast_stats={"bursts":0}
 node.attack_ticket={"source_hero":weakref(caster),"action":"ed_smoke_assault","chain_enabled":false};arena.add_child(node);node.set_physics_process(false);return node

func run():
 check(ResourceLoader.exists("res://scripts/recovered_ed_assault_orb.gd"),"Ed E has its own recovered bouncing ball and radial fire runtime")
 if failures:print("ED_ASSAULT_ORB_RESULT checks=",checks," failures=",failures);quit(1);return
 projectile_script=load("res://scripts/recovered_ed_assault_orb.gd")
 arena=OrbArena.new();root.add_child(arena);arena.world=World.new();arena.add_child(arena.world)
 caster=Hero.new();caster.character_id=14;arena.player=caster
 var floor_=wall(Vector3(0,-.25,0),Vector3(100,.5,100));await physics_frame;await physics_frame
 var ball=orb(Vector3(0,2.2,0),Vector3(5,-8,0));ball._physics_process(.3)
 check(ball.floor_bounces==1 and ball.velocity.y>0 and not ball.exploded,"Recovered ball bounces off a real floor before its radial burst")
 check(ball.body.texture.resource_path.ends_with("/assault/ball.png") and ball.body.pixel_size*64>3.8,"The airborne ball uses the original ROM sprite at a larger diameter than Ed's standing height")
 var before=ball.position;var age=ball.age;arena.paused=true;ball._physics_process(1)
 check(ball.position==before and ball.age==age,"Pause freezes ball flight and its burst clock")
 arena.paused=false;ball.free()
 var near=target(Vector3(-4,.5,0));near.hp=1000;arena.enemies.append(near)
 var far=target(Vector3(-11,.5,0));far.hp=1000
 var covered=target(Vector3(4,.5,0));covered.hp=1000
 var barrier=wall(Vector3(2,2,0),Vector3(.2,4,6));await physics_frame;await physics_frame
 ball=orb(Vector3(0,1.4,0));ball._explode()
 check(ball.exploded and ball.cast_stats.bursts==1 and ball.flames.size()==8,"One ball burst creates exactly eight outward fire fronts")
 check(near.hp==730 and far.hp==1000 and covered.hp==1000,"Initial area burst deals270 once to a fitted target and respects radius and real cover")
 var headings={}
 for direction in ball.directions:headings[roundi(rad_to_deg(atan2(direction.x,direction.z)))]=true
 check(headings.size()==8 and ball.directions[0].dot(ball.directions[1])>.7 and ball.directions[0].dot(ball.directions[1])<.71,"Outward fire fronts are distributed at the ROM's45-degree intervals")
 check(ball.flames[0].hframes==4 and ball.flames[0].vframes==4,"Each front uses the recovered sixteen-frame fire animation")
 check(is_equal_approx(ball.flames[0].pixel_size*64,7.296),"Outward fire has three times its previous world-space width")
 caster.character_id=15;ball._physics_process(2.9)
 check(far.hp==730 and far.received_ticket==ball.attack_ticket,"Spreading fire reaches an eleven-metre fitted target with Ed's snapshotted damage after switching fighters")
 check(near.hp==730 and covered.hp==1000,"Fire cannot repeat area damage or pass through the wall on an outward spoke")
 check(arena.confirmations[0]==[near,0] and arena.confirmations[1]==[far,14] and arena.sounds.has(["ed_assault_burst",14]),"Explosion feedback retains Ed's source identity before and after switching fighters")
 var bursts=ball.cast_stats.bursts;ball._explode();check(ball.cast_stats.bursts==bursts,"An already bursting ball cannot emit a second set of attacks")
 ball._physics_process(.2);check(not ball.is_queued_for_deletion(),"Outward fire keeps flying beyond the previous three-second limit")
 ball._physics_process(1.5);check(ball.is_queued_for_deletion(),"Extended outward fire expires after four and a half seconds")
 arena.enemies.erase(near);await process_frame;barrier.free();clear_targets()
 var grounded=target(Vector3(0,.5,-11));grounded.hp=1000
 ball=orb(Vector3(0,8,0));ball._explode();var fire_clock=ball.fire_age;var frame=ball.flames[0].frame
 arena.paused=true;ball._physics_process(1);arena.paused=false
 check(ball.fire_age==fire_clock and ball.flames[0].frame==frame,"Pause freezes spreading fire lifetime and animation")
 ball._physics_process(2.9)
 check(grounded.hp==730 and ball.flames[0].global_position.y<2,"An airborne burst sends damaging flames along the ground at the visible sprite height")
 ball.free();clear_targets()
 var uphill=target(Vector3(0,6,-11));uphill.hp=1000
 var incline=wall(Vector3(0,-.2/cos(atan(.5)),0),Vector3(8,.4,32));incline.rotation.x=atan(.5)
 await physics_frame;await physics_frame
 ball=orb(Vector3(0,1.4,0));ball._explode();ball._physics_process(2.9)
 check(uphill.hp==730 and not ball.blocked[0],"Fire follows a walkable incline rising more than five metres and reaches the visible uphill target")
 ball.free();incline.free();clear_targets();await physics_frame
 var sheltered=target(Vector3(0,.5,-11));sheltered.hp=1000
 var low_wall=wall(Vector3(0,1,-3),Vector3(6,2,.2));await physics_frame;await physics_frame
 ball=orb(Vector3(0,1.4,0));ball._explode();ball._physics_process(2.9)
 check(sheltered.hp==1000 and ball.blocked[0],"Floor following cannot lift a fire front over a low vertical wall")
 ball.free();low_wall.free();clear_targets()
 var extended=target(Vector3(0,.5,-16));extended.hp=1000
 var wide=target(Vector3(2.8,.5,-14));wide.hp=1000
 ball=orb(Vector3(0,1.4,0));ball._explode();ball._physics_process(3.1)
 check(extended.hp==730,"Longer fire flight damages a target beyond the previous twelve-metre travel")
 check(wide.hp==730,"The enlarged fire's damaging width reaches a target beside its outward path")
 ball.free();clear_targets()
 ball=orb(Vector3(0,3,0),Vector3(100,0,0));barrier=wall(Vector3(3,3,0),Vector3(.2,6,6));await physics_frame;await physics_frame;ball._physics_process(.1)
 check(ball.exploded and ball.position.x<3,"Fast large balls burst at world cover instead of passing through it")
 arena.playing=false;ball._physics_process(.1);check(ball.is_queued_for_deletion(),"Wave exit removes ongoing fire fronts immediately")
 await process_frame;barrier.free();floor_.free();caster.free();arena.free();await process_frame
 print("ED_ASSAULT_ORB_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
