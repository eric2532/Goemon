extends "res://tests/forest-shrine/south_kili_population_test.gd"
const MOUNTAIN_OUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/Mountain population/"
func _initialize():
 create_timer(1500).timeout.connect(func():printerr("SOKIA_MOUNTAIN_POPULATION_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-mountain-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var records=[]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOUNTAIN_OUT))
 var floors=range(13001,13015)+Population.WATER_CAVE
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--floor="):floors=[int(arg.trim_prefix("--floor="))]
 for floor_ in floors:
  print("SOKIA_MOUNTAIN_POPULATION_ENTER ",floor_)
  Tour.travel(game,Tour.Indoor.layout(floor_),{"arrival":Tour.Indoor.safe_point(floor_,Vector2.ZERO),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  game.army_runtime.refresh_navigation(0)
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  check(Population.encounters_own(game.model),"Existing native route owner covers "+str(floor_))
  check(game.model.waves.patrol_source==Population.bank(game.model),"Prepared native bank selected for "+str(floor_))
  clear_enemies();game.model.waves.spawned=2
  var state=game.model.waves.route_state;var by_zone={}
  for y in state.size.y:
   for x in state.size.x:
    if not Tour.Indoor.open_cell(state.bits,state.size,x,y):continue
    var at:Vector2=state.origin+Vector2(x,y)*3.
    var zone=Population.zone_at(floor_,Population.source_cell(game.model,at))
    if zone.is_empty():continue
    if not by_zone.has(int(zone.id)):by_zone[int(zone.id)]=[]
    by_zone[int(zone.id)].append(at)
  for zone_id in by_zone:
   var zone=Population.data().zones.filter(func(z):return int(z.id)==zone_id and int(z.map)==floor_)[0]
   var tested=false;var observed={};var eligible=0
   for point in by_zone[zone_id]:
    if game.model.get_meta("falan_links",[]).any(func(l):return point.distance_squared_to(l.at)<36):continue
    eligible+=1
    game.player.position=game.model.world_point(point,.15);game.model.hero_position=game.player.position
    game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0.
    var groups=[]
    for choice in zone.groups:
     var members=[]
     for member in Population.data().groups[choice[0]].members:members.append([int(member[0]),int(member[1])])
     game.model.waves.snow_pending=members;game.model.waves.spawn_clock=0.
     game.model.waves.tick(1.,game.player.position)
     observed[choice[0]]=maxi(observed.get(choice[0],0),game.model.enemies.size())
     if game.model.enemies.size()!=members.size():clear_enemies();continue
     game.army_runtime.import_arrivals()
     check(game.model.enemies.values().all(func(e):return int(e.get("route_encounter",-1))==zone_id and game.army_runtime.handles.has(e.id)),"Every source group uses the existing native army: "+str(choice[0]))
     groups.append(choice[0]);clear_enemies()
    if groups.size()!=zone.groups.size():continue
    records.append({"map":floor_,"zone":zone_id,"cell":v(Vector2(Population.source_cell(game.model,point))),"groups":groups});tested=true;break
   if not tested:
    var clearance={"navigation":0,"native_small":0,"native_radius":0,"nearby_enemies":0}
    for point in by_zone[zone_id]:
     var at=game.model.world_point(point)
     if game.model.waves.navigation.move_clear(at/game.model.falan_scale,1.18):clearance.navigation+=1
     if game.army_runtime.native.can_reach(at,at,.1):clearance.native_small+=1
     if game.army_runtime.native.can_reach(at,at,1.18):clearance.native_radius+=1
     clearance.nearby_enemies=maxi(clearance.nearby_enemies,game.army_runtime.query_aabb(AABB(at-Vector3(24,12,24)*game.model.falan_scale,Vector3(48,24,48)*game.model.falan_scale),0).size())
    printerr("SOKIA_POOL_GAP map=",floor_," zone=",zone_id," cells=",by_zone[zone_id].size()," eligible=",eligible," maximum_spawned=",observed," clearance=",clearance)
    var nav=game.army_runtime.navigation_data(game.model)
    var at=game.model.world_point(by_zone[zone_id][0]);var blockers=[]
    for i in nav.obstacle_min.size():
     if AABB(nav.obstacle_min[i],nav.obstacle_max[i]-nav.obstacle_min[i]).grow(.1).has_point(at):blockers.append([nav.obstacle_min[i],nav.obstacle_max[i]])
    printerr("SOKIA_POOL_NAV width=",nav.width," spacing=",nav.spacing," origin=",nav.origin," bounds=",nav.bounds_min,"/",nav.bounds_max," point=",at," covered=",nav.covered.size()," blockers=",blockers)
   check(tested,"Every effective native pool spawns on reachable ground: %d/%d"%[floor_,zone_id])
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Existing adventure data preserved")
 var file=FileAccess.open(MOUNTAIN_OUT+"locations.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
 print("SOKIA_MOUNTAIN_POPULATION_RESULT zones=",records.size()," checks=",checks," failures=",errors)
 game.queue_free();await process_frame;quit(1 if errors else 0)
