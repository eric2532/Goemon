extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-event-health-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 game.model.waves.pending=100000000;game.model.waves.spawn_clock=100000000;game.player.position=Vector3(120,0,120)
 var army=game.army_runtime;army.profile_enabled=true;army.collect_stats=true
 for i in 3:
  var row=game.model.waves.spawn_enemy([0,1,3][i],Vector3(-80+i*4,0,-80));row.hp=10000.125;row.max_hp=row.hp
 army.import_arrivals()
 for i in 5:
  army.spawn(-5000-i,1,[11,5,7,8,10][i],Vector3(-80+i,0,-75),50000,.4);army.ally_target(-5000-i)
 army.sync_compatibility();army.native.simulation_profile(true)
 var original_actors=[]
 for id in game.model.enemies:original_actors.append(game.actors[id])
 for tick in 300:
  army.integration_tick(1.0/60)
  var s:Dictionary=army.latest
  for i in s.handles.size():
   if s.teams[i]!=0:continue
   var actor=game.actors.get(s.logical_ids[i])
   check(is_instance_valid(actor) and actor.hp==s.hp[i] and actor.max_hp==10000.125,"Enemy event health remains exact after real autonomous combat")
 # Ninja finishers can kill any ordinary enemy regardless of fixture health.
 for old_actor in original_actors:
  if not army.valid(old_actor.handle):check(old_actor.dead and old_actor.hp<=0,"Autonomous finishers immediately retire health without a publishing write")
 var fresh=game.model.waves.spawn_enemy(0,Vector3(-30,0,100));fresh.hp=10000.125;fresh.max_hp=fresh.hp
 army.import_arrivals();army.sync_compatibility()
 var actor=game.actors[fresh.id];var handle:int=actor.handle
 var hp:float=actor.hp
 army.native.apply_hit(handle,{"amount":.125,"provoke":false});army.dispatch_events()
 check(actor.hp==hp-.125 and game.model.enemies[actor.forest_id].hp==actor.hp,"Queued native damage updates the actor and model before publishing")
 hp=actor.hp;army.apply_hit(handle,{"amount":.375,"provoke":false})
 check(actor.hp==hp-.375,"Synchronous player/tower hits update health immediately")
 army.sync_compatibility();check(actor.hp==army.unit_state(handle).hp,"Pose publication cannot replace exact event health")
 army.apply_hit(handle,{"amount":20000.0,"provoke":false})
 check(actor.dead and actor.hp<=0 and not army.valid(handle),"Lethal damage immediately retires health and collision eligibility")
 var profile:Dictionary=army.native.simulation_profile(false)
 check(profile.facade_health_writes==0 and army.registered_facade_fallbacks==0,"Normal physics performs zero redundant actor health writes")
 check(int(army.observed_counts.get("damage",0))>3 and army.event_gaps==0,"The test exercised genuine autonomous hits without missing events")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 print("ARMY_ENEMY_HEALTH_EVENTS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
