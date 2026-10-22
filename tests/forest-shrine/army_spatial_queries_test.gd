extends SceneTree
## Shared army broadphases must preserve exact native contact order and damage.
class CountedRaider extends "res://scripts/forest/forest_raider.gd":
 var bounds_calls=0
 var segment_calls=0
 func combat_bounds()->AABB:
  bounds_calls+=1;return super.combat_bounds()
 func combat_segment_contact(from:Vector3,to:Vector3,radius:float)->Dictionary:
  segment_calls+=1;return super.combat_segment_contact(from,to,radius)
class PoseCounter extends Node3D:
 var samples=0
 var observed_attack
 func animate_pose(pose,_delta,_time,_movement):samples+=1;observed_attack=pose.attack
var game
var checks=0
var failures=0
var cfg="user://army-spatial-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false)
 var actors=[]
 for i in 240:
  var point=Vector3((i-1)*1.4,0,60) if i<3 else Vector3(80+(i%24)*3,0,90+int(i/24)*3)
  var e=game.model.waves.spawn_enemy(i%5 if i<3 else 0,point);e.hp=10000;e.max_hp=10000
  var a=CountedRaider.new();a.game=game;a.forest_id=e.id;a.variant=e.variant;a.swarm=true;a.position=point
  game.add_child(a);a.set_physics_process(false);a._sync_fitted_pose();game.actors[e.id]=a;game.enemies.append(a);actors.append(a)
  game.model.visible_cells[game.model.cell_of(point)]=true
 var h=game.explorer_helpers;var u=h.pool[0];var combat=u.active_ability
 u.position=Vector3(0,.1,63);combat.player.pos=u.position;game.player.position=u.position;game.player.select_character(8)
 var visual=PoseCounter.new();game.add_child(visual);var old_visual=combat.visual_actor;combat.visual_actor=visual
 combat.visual_left=0;combat.visual_elapsed=0
 combat._animate(1,0);combat._animate(1,0)
 check(visual.samples==1,"Army cosmetic pose is sampled at most once between rendered frames")
 combat._completed_brush_attack={"style":"thrust"}
 combat._animate(1,0)
 combat._completed_brush_attack=null # A subsequent combat tick retires this transient sample.
 await process_frame
 combat._animate(1,0)
 check(visual.observed_attack!=null and visual.observed_attack.style=="thrust","Completed swing survives skipped poses until its visible sample")
 combat._animate(0,0)
 check(visual.samples==3,"Explicit zero-time gameplay pose requests remain immediate")
 combat.visual_actor=old_visual;visual.queue_free()
 var native=game.player.active_ability
 var expected=native.living(u.position,5).map(func(e):return e.uid)
 for a in actors:a.bounds_calls=0
 for i in 12:
  var actual=combat.living(u.position,5).map(func(e):return e.uid)
  check(actual==expected,"Shared melee broadphase retains fitted nearby contacts and enemy order")
 var calls=0
 for a in actors:calls+=a.bounds_calls
 print("ARMY_SHARED_BOUNDS_CALLS ",calls)
 check(calls<=240,"Twelve melee resolutions share at most one bounds snapshot for 240 enemies")
 check(combat.living().map(func(e):return e.uid)==native.living().map(func(e):return e.uid),"Unbounded native abilities keep all living visible enemies")
 check(h.has_method("projectile_candidates"),"Army has a shared projectile spatial broadphase")
 if h.has_method("projectile_candidates"):
  combat._begin_projectile_queries();native._begin_projectile_queries()
  var segments=[[Vector3(0,1,65),Vector3(0,1,55),.25],[Vector3(-8,1,60),Vector3(8,1,60),1.3],[Vector3(0,30,65),Vector3(0,30,55),.25],[Vector3(0,1,63),Vector3(0,1,63),1.4],[Vector3(90,1,90),Vector3(150,1,115),.25]]
  for s in segments:
   for excluded in [[],[actors[1].get_instance_id()]]:
    var got=combat._segment_candidates(s[0],s[1],s[2],excluded)
    var want=native._segment_candidates(s[0],s[1],s[2],excluded)
    check(got.map(func(c):return c.e.uid)==want.map(func(c):return c.e.uid),"Spatial projectiles retain ordered native victims, giants and hit exclusions")
    for j in mini(got.size(),want.size()):
     check(is_equal_approx(got[j].t,want[j].t) and got[j].e.pos.distance_to(want[j].e.pos)<.0001,"Spatial projectile exact contact and hit time unchanged")
  var ids=h.projectile_candidates(Vector3(-2,0,55),Vector3(2,3,65))
  check(ids.size()<=3,"A nearby arrow examines at most its three nearby enemies, skipping 237 distant foes")
  var history=actors.map(func(a):return a.get_instance_id())
  var empty_us=9223372036854775807;var history_us=empty_us
  for trial in 3:
   var began=Time.get_ticks_usec()
   for i in 1500:combat._segment_candidates(Vector3(50,1,80),Vector3(50,1,81),.05,[])
   empty_us=mini(empty_us,Time.get_ticks_usec()-began)
   began=Time.get_ticks_usec()
   for i in 1500:combat._segment_candidates(Vector3(50,1,80),Vector3(50,1,81),.05,history)
   history_us=mini(history_us,Time.get_ticks_usec()-began)
  check(history_us<empty_us*3+10000,"Empty local projectile cells skip copying long piercing-hit histories")
  print("ARMY_EMPTY_QUERY_TIMING empty_us=",empty_us," history_us=",history_us)
  combat._end_projectile_queries();native._end_projectile_queries()
 actors[0].dead=true;actors[0].hp=0
 check(not combat.living(u.position,5).any(func(e):return e.node==actors[0]),"Death excluded immediately inside shared snapshot")
 game.model.visible_cells.clear()
 check(combat.living(u.position,5).is_empty(),"Fog changes exclude targets immediately inside shared snapshot")
 var isolated_data=game.model.waves.spawn_enemy(0,Vector3(200,0,70))
 var isolated=CountedRaider.new();isolated.game=game;isolated.forest_id=isolated_data.id;isolated.variant=0;isolated.position=isolated_data.pos
 game.add_child(isolated);isolated.set_physics_process(false);game.actors[isolated_data.id]=isolated;game.enemies.append(isolated)
 game.model.visible_cells[game.model.cell_of(isolated.position)]=true
 var thin_box=isolated.combat_bounds();var near_miss=thin_box.get_center();near_miss.x=thin_box.end.x+.25
 combat._begin_projectile_queries();native._begin_projectile_queries()
 var no_hits=combat._segment_candidates(near_miss+Vector3.BACK*3,near_miss-Vector3.BACK*3,.05,[])
 check(no_hits.is_empty() and isolated.segment_calls==0,"Tall narrow enemies reject arrows outside their actual bounds before exact casts")
 var native_miss=native._segment_candidates(near_miss+Vector3.BACK*3,near_miss-Vector3.BACK*3,.05,[])
 check(native_miss.is_empty() and isolated.segment_calls>0,"The pruned near-miss matches the native collision result")
 combat._end_projectile_queries();native._end_projectile_queries()
 var rotated_data=game.model.waves.spawn_enemy(4,Vector3(210,0,70));rotated_data.facing=PI/4
 var rotated=CountedRaider.new();rotated.game=game;rotated.forest_id=rotated_data.id;rotated.variant=4;rotated.position=rotated_data.pos
 game.add_child(rotated);rotated.set_physics_process(false);game.actors[rotated_data.id]=rotated;game.enemies.append(rotated);rotated._sync_fitted_pose()
 game.model.visible_cells[game.model.cell_of(rotated.position)]=true
 var corner=Vector3(rotated.combat_bounds().end.x+.6,2,70-.5/sqrt(2.0))
 combat._begin_projectile_queries();native._begin_projectile_queries()
 var rotated_native=native._segment_candidates(corner,corner+Vector3.UP,.5,[])
 var rotated_army=combat._segment_candidates(corner,corner+Vector3.UP,.5,[])
 check(rotated_native.any(func(c):return c.e.node==rotated),"Native local box expansion reaches past a rotated world AABB")
 check(rotated_army.map(func(c):return c.e.uid)==rotated_native.map(func(c):return c.e.uid),"Army broadphase retains rotated box corner contacts at native projectile widths")
 combat._end_projectile_queries();native._end_projectile_queries()
 game.crowd.low_fidelity=false;h.target_frame=Vector2i(-1,-1);rotated._sync_fitted_pose();h.refresh_targets()
 var detailed_candidates=h.projectile_candidates(corner-Vector3.ONE*.01,corner+Vector3.ONE*.01)
 check(detailed_candidates.any(func(index):return h.projectile_actors[index]==rotated),"Detailed convex enemies retain the original conservative sphere broadphase")
 game.crowd.low_fidelity=true
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ARMY_SPATIAL_QUERIES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
