extends SceneTree
var checks=0
var failures=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS: ",label)
func frames(count:int):
 for i in range(count):await process_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
 game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense");game.encounters.set_physics_process(false)
 game.encounters.update_start_input(0,false);game.encounters.update_start_input(3.1,true);game.encounters._spawn_due(300)
 check(game.enemies.size()==300,"Motion fixture contains 300 real collision actors")
 var origins=[]
 for i in range(game.enemies.size()):
  var e=game.enemies[i];e.set_physics_process(false)
  e.position=Vector3((float(i%12)-5.5)*1.2,.06,140-float(i/12)*1.4)
  e.velocity=Vector3(0,0,2);e.grounded_cached=true;e.stun=0;e.walk_clock=0;e.walk_age=1
  origins.append(e.position)
 await physics_frame
 var ticks=[]
 for step in range(45):
  var sweeps=0
  for e in game.enemies:
   if e.walk_clock<=1.0/60.0:sweeps+=1
   e.walk_motion(1.0/60.0)
  if step>=12:ticks.append(sweeps)
 check(ticks.max()<120,"Ground sweeps are distributed instead of a 300-actor periodic spike")
 print("CROWD_SWEEP_SCHEDULE peak=",ticks.max()," samples=",ticks)
 var min_travel=INF;var max_travel=0.0
 for i in range(game.enemies.size()):
  var travel=game.enemies[i].position.distance_to(origins[i]);min_travel=minf(min_travel,travel);max_travel=maxf(max_travel,travel)
 check(min_travel>1.25 and max_travel<1.6,"All actors retain smooth forward movement at configured speed")
 var e=game.enemies[0];var start=e.position;e.velocity=Vector3(4,0,0);e.stun=.5
 e.walk_motion(1.0/60.0)
 check(e.position.x>start.x and e.walk_clock==0,"Stunned knockback still uses immediate collision movement")
 e.stun=0;e.position=Vector3(0,.06,180);e.velocity=Vector3(0,0,12);e.grounded_cached=true;e.walk_clock=0
 var obstacle=StaticBody3D.new();game.add_child(obstacle)
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(12,5,.3);collider.shape=box;obstacle.add_child(collider);obstacle.position=Vector3(0,2,182)
 await physics_frame
 for i in range(30):e.walk_motion(1.0/60.0)
 check(e.position.z<181.6,"Validated short segments still stop at solid cover")
 game.sound_library.cancel();game.music.stop();game.queue_free();await frames(5)
 print("CROWD_MOTION_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
