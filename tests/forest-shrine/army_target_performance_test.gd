extends SceneTree
## A swarm may not force a fitted hull query per enemy for each ally decision.
class CountedRaider extends "res://scripts/forest/forest_raider.gd":
 var queries=0
 var bounds_queries=0
 func combat_contact_point(point:Vector3)->Vector3:
  queries+=1;return super.combat_contact_point(point)
 func combat_bounds()->AABB:
  bounds_queries+=1;return super.combat_bounds()
var game
var checks=0
var failures=0
var cfg="user://army-targets-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;game.set_physics_process(false);game.player.set_physics_process(false)
 var actors=[]
 for i in 240:
  var point=Vector3(0,0,57) if i==0 else Vector3(20+(i%24)*3,0,40+floori(i/24.0)*3)
  var data=game.model.waves.spawn_enemy(0,point);data.hp=10000;data.max_hp=10000
  var actor=CountedRaider.new();actor.game=game;actor.forest_id=data.id;actor.variant=0;actor.swarm=true;actor.position=point
  game.add_child(actor);actor.set_physics_process(false);actor._sync_fitted_pose();game.actors[data.id]=actor;game.enemies.append(actor);actors.append(actor)
  game.model.visible_cells[game.model.cell_of(point)]=true
 var h=game.explorer_helpers
 for actor in actors:actor.queries=0
 var correct=true
 for i in 12:correct=correct and h.closest_target(Vector3(i*.01,0,60),48)==actors[0]
 var queries=0
 for actor in actors:queries+=actor.queries
 print("ARMY_TARGET_FITTED_QUERIES ",queries)
 check(correct,"All twelve allies choose the closest real target")
 check(queries>=12 and queries<=24,"Target decisions fit only competitive hulls in a 240-enemy crowd")
 var old_time=9223372036854775807;var new_time=old_time
 for trial in 3:
  var began=Time.get_ticks_usec()
  for i in 1000:reference_target(h,Vector3(0,0,60),48)
  old_time=mini(old_time,Time.get_ticks_usec()-began)
  began=Time.get_ticks_usec()
  for i in 1000:h.closest_target(Vector3(0,0,60),48)
  new_time=mini(new_time,Time.get_ticks_usec()-began)
 check(new_time<old_time*.6,"A nearby target avoids scanning every distant row for every ally decision")
 print("ARMY_TARGET_TIMING reference_us=",old_time," optimized_us=",new_time)
 # A dense guard area must refine competitive contacts, not every nearby hull.
 for i in range(1,80):
  var point=Vector3(5+(i%10)*.7,0,49+floori(i/10.0)*.7)
  game.model.enemies[actors[i].forest_id].pos=point;actors[i].position=point;actors[i]._sync_fitted_pose()
 h.target_frame=Vector2i(-1,-1)
 var guard=h.pool[0];guard.guard_post=Vector3(0,0,60);guard.position=guard.guard_post
 for actor in actors:actor.queries=0
 var guarded=h.closest_guard_target(guard)
 var guard_queries=0
 for actor in actors:guard_queries+=actor.queries
 check(guarded==actors[0],"A dense guard area still selects its nearest enemy")
 check(guard_queries<=6,"A guard refines only competitive enemy hulls instead of the whole nearby crowd")
 print("GUARD_TARGET_FITTED_QUERIES ",guard_queries)
 actors[0].hp=0;actors[0].dead=true
 check(h.closest_target(Vector3(0,0,60),48)!=actors[0],"Cached targeting immediately excludes a killed enemy")
 for actor in actors:actor.bounds_queries=0
 var ranger=h.pool.filter(func(unit):return unit.kit_id==10)[0]
 for i in 12:ranger.active_ability._begin_projectile_queries();ranger.active_ability._end_projectile_queries()
 var bounds_calls=0
 for actor in actors:bounds_calls+=actor.bounds_queries
 print("ARMY_PROJECTILE_BOUND_QUERIES ",bounds_calls)
 check(bounds_calls<=240,"Rangers share one bounds snapshot instead of rebuilding it for each arrow owner")
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ARMY_TARGET_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func reference_target(director,origin:Vector3,max_distance:float=INF):
 director.refresh_targets()
 var best=null;var distance=max_distance*max_distance
 var first=null;var lower=distance
 # Fit the closest box first so input order cannot make every successive
 # enemy trigger another expensive narrow contact query.
 for row in director.target_rows:
  var enemy=row.enemy
  if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0:continue
  var box:AABB=row.bounds
  var gap=origin.distance_squared_to(origin.clamp(box.position,box.end))
  if gap<lower:first=enemy;lower=gap
 if first!=null and director.valid_target(first):
  var gap=origin.distance_squared_to(AttackChain.aim_point(first,origin+Vector3.UP))
  if gap<distance:best=first;distance=gap
 for row in director.target_rows:
  var enemy=row.enemy
  if enemy==first or not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0:continue
  # Bounds give a safe lower distance before paying for a fitted contact hull.
  var box:AABB=row.bounds
  if origin.distance_squared_to(origin.clamp(box.position,box.end))>=distance:continue
  if not director.valid_target(enemy):continue
  var gap=origin.distance_squared_to(AttackChain.aim_point(enemy,origin+Vector3.UP))
  if gap<distance:best=enemy;distance=gap
 return best
