extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Map Swarm/"
var game
var checks=0
var failures=0
var cfg="/tmp/map-swarm-%d.cfg"%OS.get_process_id()

class EncounterQuery extends Node:
 var checks=0
 func query_aabb(_bounds:AABB,_team:int)->Array:
  checks+=1
  return [1]

func _initialize():
 create_timer(240,true,false,true).timeout.connect(func():printerr("MAP_SWARM_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(count_:int=3):
 for i in count_:await process_frame
func model_checks():
 var model=Model.new();model.reset(42,{},Tour.Regions.layout("east_coast"),false);model.start_wave()
 var waves=model.waves
 for i in 3:waves.enemy_defeated({"id":i})
 check(not waves.swarm_active,"Three map kills leave patrols unalerted")
 waves.spawn_clock=.2;waves.enemy_defeated({"id":4})
 check(not waves.swarm_active,"The fourth map kill no longer starts a swarm")
 waves.invite_map_enemies()
 check(waves.swarm_active,"Food invitation activates the existing swarm owner")
 waves.invite_map_enemies()
 check(is_equal_approx(waves.spawn_clock,1.0),"The pending patrol interval slows fivefold when swarm starts")
 waves.tick_outer_road(1.0,Vector3.ZERO)
 check(is_equal_approx(waves.spawn_clock,1.0),"Swarming outdoor patrol arrivals use the slower interval")
 # Movement checks return before any native query until the longer step is due.
 waves.snow_last=Vector3.ZERO;waves.snow_distance=0.;waves.snow_pending=[]
 waves.tick_map_encounters(Vector3(3,0,0))
 check(waves.snow_distance==3.0,"Swarming movement encounters no longer check after three map units")
 waves.tick_map_encounters(Vector3(6,0,0))
 check(waves.snow_distance==6.0,"Walking continues accumulating toward the longer outdoor swarm encounter check")
 var query=EncounterQuery.new();model.army_runtime=query
 waves.tick_map_encounters(Vector3(12,0,0))
 check(query.checks==0,"Outdoor swarm still waits after twelve units walked")
 waves.tick_map_encounters(Vector3(12.5,0,0))
 check(query.checks==1,"Outdoor swarm checks at twelve and a half units walked")
 model.phase="preparing";model.start_wave()
 check(not waves.swarm_active,"A new run clears the food invitation")
 waves.snow_last=Vector3.ZERO;waves.snow_distance=0.
 waves.tick_map_encounters(Vector3(2,0,0))
 check(query.checks==1,"Outdoor encounters wait after two units walked")
 waves.tick_map_encounters(Vector3(2.5,0,0))
 check(query.checks==2,"Outdoor encounters check at two and a half units walked")
 model.army_runtime=null;query.free()
 model.phase="preparing";waves.enemy_defeated({"id":5})
 check(not waves.swarm_active,"Deaths outside active combat cannot start a swarm")
 model.reset(42,{}, {},false);model.waves.crossgate_pet_test=false;model.start_wave()
 for i in 8:model.waves.enemy_defeated({"id":i})
 check(not model.waves.swarm_active and model.waves.kill_spawn_pending==16,"Arena kills retain their existing reinforcement rules")
 model.reset(42,{},Tour.Regions.layout("east_coast"),false);model.start_wave()
 check(not model.waves.swarm_active,"Entering another map resets the swarm")
func run():
 model_checks()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 set_meta("forest_custom_layout",doc.data)
 set_meta("forest_fighter",preload("res://scripts/rogue_roster.gd").KAZI_ID)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await frames()
 game.settings.forest_level_up_cards=false;game.tuning.invincible=true
 game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var waves=game.model.waves;var army=game.army_runtime
 var loot=game.exploration_loot;loot.set_process(false);loot.clear()
 army.finish_integration()
 for i in waves.patrol_posts.size()+1:waves.tick(12,game.player.position)
 army.import_arrivals();army.sync_compatibility()
 check(not army.external_targets().player_map_swarm,"The native hero target starts without map-wide pursuit")
 var idle_times=[]
 for tick in 120:
  var start=Time.get_ticks_usec();army.step(1.0/60,{"targets":army.external_targets()});idle_times.append(float(Time.get_ticks_usec()-start)/1000.)
 army.dispatch_events();army.sync_compatibility()
 idle_times.sort();print("MAP_SWARM_BEFORE_STEP p95_ms=",idle_times[int(idle_times.size()*.95)]," max_ms=",idle_times[-1])
 # Use the bundled arena for native movement; source-map reset/trigger rules are checked above.
 var candidates=[];var random=RandomNumberGenerator.new();random.seed=48291
 for attempt in 4096:
  var region:Rect2i=game.model.navigation_region
  var cell=Vector2i(random.randi_range(region.position.x,region.end.x-1),random.randi_range(region.position.y,region.end.y-1))
  if game.model.allied_grid.is_point_solid(cell):continue
  var point:Vector3=game.model.point(cell)*game.model.falan_scale
  if not game.model.FalanFrontier.enemy_exposed(game.model,Vector2(point.x,point.z)/game.model.falan_scale):continue
  if not army.native.can_reach(point,point,.7):continue
  if candidates.is_empty():
   game.player.position=point;candidates.append(point)
  elif point.distance_to(game.player.position)>60 and army.native.can_reach(point,game.player.position,.7):
   candidates.append(point)
   if candidates.size()==5:break
 check(candidates.size()==5,"Found an exposed player position and four reachable distant enemy stations")
 if candidates.size()<5:quit(1);return
 var victims=[]
 for i in 4:
  var point:Vector3=game.player.position+Vector3(i*3,0,3)
  point.y=game.model.world_height(point.x,point.z)
  var row:Dictionary=waves.spawn_enemy(Roles.SLIME,point)
  victims.append(row.id)
 for point in candidates.slice(1):waves.spawn_enemy(Roles.SLIME,point)
 army.import_arrivals();army.sync_compatibility()
 for i in victims.size():
  loot.drop_bag=[Loot.MELON_BREAD] if i==3 else [-1]
  army.damage_enemy(victims[i],1000000);army.dispatch_events();army.sync_compatibility()
  check(not waves.swarm_active,"Real native defeat %d cannot trigger a swarm"%(i+1))
 check(not army.external_targets().player_map_swarm,"Four native deaths leave map-wide pursuit disabled")
 var food:Dictionary=loot.slots.filter(func(slot):return slot.active and not slot.chest and slot.kind==Loot.MELON_BREAD)[0]
 food.pos=game.player.position
 loot._process(.01)
 check(food.active and not waves.swarm_active,"The actual melon-bread drop glides before activating")
 loot._process(Loot.CONSUME_TIME)
 check(not food.active and army.external_targets().player_map_swarm,"Eating the native death drop publishes map-wide pursuit")
 var targets:Dictionary=army.external_targets()
 army.native.set_targets(targets)
 var before={}
 for row:Dictionary in game.model.enemies.values():
  var handle:int=army.handles.get(row.id,0)
  if handle!=0:before[handle]=army.unit_state(handle).position
 var times=[]
 for tick in 120:
  var start=Time.get_ticks_usec();army.step(1.0/60,{"targets":targets});times.append(float(Time.get_ticks_usec()-start)/1000.)
 army.dispatch_events();army.sync_compatibility()
 var approaching=0;var distant=0
 for handle in before:
  var state:Dictionary=army.unit_state(handle)
  if state.is_empty():continue
  var from:Vector3=before[handle]
  if from.distance_to(game.player.position)>50.0:
   distant+=1
   if state.position.distance_to(game.player.position)<from.distance_to(game.player.position)-.1:approaching+=1
 check(distant>0 and approaching>0,"Distant map enemies actually move toward the player beyond ordinary patrol alert range")
 print("MAP_SWARM_APPROACH distant=",distant," approaching=",approaching," live=",army.handles.size())
 times.sort();print("MAP_SWARM_NATIVE_STEP p95_ms=",times[int(times.size()*.95)]," max_ms=",times[-1])
 var radar=game.forest_ui.enemy_minimap;radar.refresh()
 check(radar.markers.is_empty(),"Ordinary swarming enemies add no minimap dots")
 if DisplayServer.get_name()!="headless":
  var row:Dictionary=game.model.enemies.values()[0]
  game.camera_rig.camera.global_position=row.pos+Vector3(12,18,20)
  game.camera_rig.camera.look_at(row.pos+Vector3.UP)
  army.latest=army.render_snapshot();army.presentation_dirty=true;army.flush_presentation()
  game.forest_ui.sync();await frames();await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
  root.get_texture().get_image().save_png(REVIEW+"swarm-explore.png")
 game.sound_library.cancel();game.music.stop();game.queue_free();current_scene=null;paused=false
 await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAP_SWARM_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
