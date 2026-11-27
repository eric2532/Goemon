extends "res://tests/forest-shrine/west_snow_route_review.gd"
const Snow=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
var RESTORATION="res://build/Other Files/Asset Toolkit/Snow Region Restoration/"
var results=[]
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--review-root="):RESTORATION=arg.trim_prefix("--review-root=").trim_suffix("/")+"/"
 create_timer(1200).timeout.connect(func():printerr("SNOW_POPULATION_TIMERESTORATION");quit(1))
 run.call_deferred()
func run():
 var review_phase="Before" if "--before" in OS.get_cmdline_user_args() else "After"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESTORATION+review_phase+"/"))
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-snow-population-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=341;game.set_process(false)
 var plan=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Snow Region/boundary.json"))
 review_root=RESTORATION;phase=review_phase
 var cameras=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Snow Region Cleanup/After/cameras.json"))
 for pose in cameras:baseline_poses[pose.name]=pose
 for entry in plan.stages:
  stage=entry.duplicate(true);stage.area="interior"
  var id=int(entry.floor);print("SNOW_POPULATION_ENTER ",id)
  var layout=Original.layout(id);layout.seed=341
  Tour.travel(game,layout,{"arrival":local_point(Vector2(entry.anchor[0],entry.anchor[1])),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  game.paused=false;game.transitioning=false;game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  var row={"floor":id,"npcs":[],"encounters":[],"visuals":[]}
  game.explorer_npcs.prepare()
  var actors=game.explorer_npcs.actors.duplicate()
  check(actors.size()==Snow.data().npcs.filter(func(n):return int(n.floor)==id).size(),"Every documented NPC built "+str(id))
  for actor in actors:
   var record:Dictionary=actor.node.get_meta("snow_record");var at=Original.source_point(id,Vector2i(record.cell[0],record.cell[1]))
   check(Vector2(actor.node.position.x,actor.node.position.z).distance_to(at)<.001,"Exact original NPC anchor "+record.id)
   var candidates=[]
   for y in range(-1,2):
    for x in range(-1,2):
     if x==0 and y==0:continue
     var cell=Vector2i(record.cell[0]+x,record.cell[1]+y)-Original.crop(id).position
     var state=Original.state(id,341)
     if Original.open(state.bits,state.size,cell):candidates.append(Original.point(id,cell,341))
   var talked=false
   for spot in candidates:
    game.player.position=game.model.world_point(spot,.15);game.player.reset_physics_interpolation()
    game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
    if game.explorer_npcs.nearest.get("node")!=actor.node:continue
    check(game.explorer_npcs.hint.visible and record.name in game.explorer_npcs.hint.text,"Working named talk prompt "+record.id)
    var talk_key=InputEventKey.new();talk_key.physical_keycode=KEY_F;talk_key.pressed=true
    game._input(talk_key)
    talked=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("name","")==record.name
    if talked:
     check(is_instance_valid(game.dialogue) and game.explorer_npcs.selected.name==record.name,"Dialogue opens at original location "+record.id)
     if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless" and not row.has("npc_capture") and not record.scenery:
      game.ui.show();row.npc_capture=true
      var toward=actor.node.global_position-game.player.position
      game.camera_rig.yaw=atan2(-toward.x,-toward.z);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
      game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(1.,true)
      for i in 12:await process_frame
      RenderingServer.force_draw()
      root.get_texture().get_image().save_png(RESTORATION+phase+"/npc-"+str(id)+".png")
      game.camera_rig.set_process(false)
     game.explorer_npcs.finish();break
   check(talked,"NPC can be spoken to from original reachable ground "+record.id+" "+record.name)
   row.npcs.append({"id":record.id,"name":record.name,"cell":record.cell,"talked":talked})
  # Every regional pool is drawn at a real reachable location, with no ambient patrol spawns.
  if Snow.owns(id):
   check(game.model.waves.patrol_posts.is_empty() or id==51031,"No regional roaming posts "+str(id))
   var state=Original.state(id,341);var seen={}
   var candidates=[]
   for y in state.size.y:
    for x in state.size.x:
     var candidate=Vector2i(x,y)
     if Original.open(state.bits,state.size,candidate):candidates.append(candidate)
   var center=Vector2i(entry.anchor[0],entry.anchor[1])-Original.crop(id).position
   candidates.sort_custom(func(a,b):return a.distance_squared_to(center)<b.distance_squared_to(center))
   for cell in candidates:
    var source_cell=cell+Original.crop(id).position
    if not Original.open(state.bits,state.size,cell) or not Snow.in_scope(id,source_cell):continue
    var zone=Snow.zone_at(id,source_cell)
    if zone.is_empty() or seen.has(int(zone.id)):continue
    var at=Original.point(id,cell,341)
    if Original.links(id,341).any(func(link):return at.distance_squared_to(link.at)<144):continue
    game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position
    game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0;game.model.waves.snow_pending=[]
    for i in 5:game.model.waves.tick(1.,game.player.position)
    check(game.model.enemies.is_empty(),"Standing still does not trigger encounters")
    var groups=[]
    for choice in zone.groups:
     var members=[]
     for member in Snow.data().groups[choice[0]].members:members.append([int(member[0]),int(member[1])])
     if Snow.data().groups[choice[0]].has("fixed"):members=Snow.data().groups[choice[0]].fixed.duplicate(true)
     game.model.waves.snow_pending=members;game.model.waves.spawn_clock=0
     game.model.waves.tick(1.,game.player.position)
     if game.model.enemies.size()!=members.size():continue
     check(game.model.enemies.values().all(func(e):return not e.has("patrol_radius") and e.has("snow_encounter")),"Native encounter group has no roaming leash")
     game.army_runtime.import_arrivals()
     for enemy in game.model.enemies.values():check(game.army_runtime.handles.has(enemy.id),"Restored group imported by native army")
     if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless" and (choice[0]=="12089" or not row.has("group_capture")):
      game.army_runtime.native.step(.016);game.army_runtime.dispatch_events()
      game.crowd.present_army(game.army_runtime.render_snapshot(),[])
      row.group_capture=true
      hide_canvas(game)
      var focus=Vector3.ZERO
      for enemy in game.model.enemies.values():focus+=enemy.pos
      focus/=game.model.enemies.size()
      var toward=focus-game.player.position
      game.camera_rig.yaw=atan2(-toward.x,-toward.z);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
      game.camera_rig.set_process(true);game.camera_rig.reset_follow()
      for i in 12:await process_frame
      RenderingServer.force_draw()
      root.get_texture().get_image().save_png(RESTORATION+phase+"/group-"+str(id)+("-ice" if choice[0]=="12089" else "")+".png")
      game.camera_rig.set_process(false)
     groups.append(choice[0])
     for enemy in game.model.enemies.values().duplicate():
      if game.army_runtime.handles.has(enemy.id):game.army_runtime.despawn(game.army_runtime.handles[enemy.id])
      game.model.enemies.erase(enemy.id)
     game.model.waves.snow_pending=[]
    if groups.size()!=zone.groups.size():continue
    seen[int(zone.id)]=true;row.encounters.append({"zone":int(zone.id),"cell":[source_cell.x,source_cell.y],"groups":groups})
   var expected={}
   for y in state.size.y:
    for x in state.size.x:
     var cell=Vector2i(x,y);var source_cell=cell+Original.crop(id).position
     if not Original.open(state.bits,state.size,cell) or not Snow.in_scope(id,source_cell):continue
     var zone=Snow.zone_at(id,source_cell)
     if not zone.is_empty():expected[int(zone.id)]=true
   for zone in expected:check(seen.has(zone),"Every reachable encounter pool tested "+str(id)+":"+str(zone))
   if id==51031 and not row.encounters.is_empty():
    var probe_cell=Vector2i(row.encounters[0].cell[0],row.encounters[0].cell[1])-Original.crop(id).position
    var probe_at=Original.point(id,probe_cell,341)
    game.player.position=game.model.world_point(probe_at,.15)
    var far_post=game.model.waves.patrol_posts.filter(func(p):return Vector2(p.x,p.y).distance_to(probe_at)>80)[0]
    var far_at=game.model.world_point(Vector2(far_post.x,far_post.y),.15)
    game.model.waves.spawn_enemy(game.model.waves.Roles.SLIME,far_at,-1,int(far_post.z))
    game.army_runtime.import_arrivals()
    game.model.waves.snow_last=game.player.position/game.model.falan_scale
    game.model.waves.snow_pending=[[0,24]];game.model.waves.spawn_clock=0
    game.model.waves.tick(1.,game.player.position)
    check(game.model.enemies.size()==2,"Distant branch patrol cannot suppress a local encounter")
    game.model.waves.tick(1.,game.player.position)
    check(game.model.enemies.size()==2,"Living encounter group prevents duplicate groups")
    for enemy in game.model.enemies.values().duplicate():
     if game.army_runtime.handles.has(enemy.id):game.army_runtime.despawn(game.army_runtime.handles[enemy.id])
     game.model.enemies.erase(enemy.id)
    game.model.waves.snow_pending=[]
    var close_at=game.player.position+Vector3(6,0,0)*game.model.falan_scale
    var nearby_enemy=game.model.waves.spawn_enemy(game.model.waves.Roles.SLIME,close_at,-1,0)
    game.army_runtime.import_arrivals()
    game.model.waves.snow_pending=[[0,24]];game.model.waves.spawn_clock=0
    game.model.waves.tick(1.,game.player.position)
    check(game.model.enemies.size()==1,"Nearby combat still suppresses additional encounters")
    game.army_runtime.despawn(game.army_runtime.handles[nearby_enemy.id]);game.model.enemies.erase(nearby_enemy.id)
    game.model.waves.snow_pending=[]
    row.distant_patrol_regression=true
   if not row.encounters.is_empty():
    var cell=Vector2i(row.encounters[0].cell[0],row.encounters[0].cell[1])-Original.crop(id).position
    for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
     var next=cell+offset
     if not Original.open(state.bits,state.size,next):continue
     var zone=Snow.zone_at(id,next+Original.crop(id).position)
     if zone.is_empty() or not Snow.in_scope(id,next+Original.crop(id).position):continue
     var old=Original.point(id,cell,341);var new=Original.point(id,next,341)
     game.player.position=game.model.world_point(new,.15)
     game.model.waves.snow_last=Vector3(old.x,.15,old.y);game.model.waves.snow_distance=0;game.model.waves.snow_pending=[]
     var probability=int(zone.probability[0])
     game.model.waves.snow_bags["probability:%s"%zone.id]=[probability]
     game.model.waves.snow_bags["check:%s:%d"%[zone.id,probability]]=[true]
     game.model.waves.tick(1.,game.player.position)
     check(not game.model.enemies.is_empty(),"Walking a source tile invokes the weighted native encounter route "+str(id))
     for enemy in game.model.enemies.values().duplicate():
      if game.army_runtime.handles.has(enemy.id):game.army_runtime.despawn(game.army_runtime.handles[enemy.id])
      game.model.enemies.erase(enemy.id)
     game.model.waves.snow_pending=[]
     break
  else:
   for i in 5:game.model.waves.tick(1.,game.player.position)
   check(game.model.enemies.is_empty(),"Village/campus stays safe "+str(id))
  if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
   hide_canvas(game)
   for pose in cameras:
    if int(pose.floor)!=id or pose.kind!="gameplay":continue
    await gameplay({"key":pose.name.trim_suffix("-play"),"at":pose.cell,"start":pose.cell,"end":[pose.cell[0],pose.cell[1]-1]})
    row.visuals.append(pose.name)
  results.append(row)
  var file=FileAccess.open(RESTORATION+"locations.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
 var camera_file=FileAccess.open(RESTORATION+phase+"/cameras.json",FileAccess.WRITE);camera_file.store_string(JSON.stringify(records,"  "));camera_file.close()
 var bags={};var rng=RandomNumberGenerator.new();rng.seed=341
 var draws=[]
 for i in 6:draws.append(Snow.weighted(bags,"test",[["a",2],["b",1]],rng))
 check(draws.slice(0,3).count("a")==2 and draws.slice(3).count("a")==2,"Weighted shuffle bag refills only when empty")
 print("SNOW_POPULATION_RESULT checks=",checks," failures=",failures," maps=",results.size())
 game.queue_free();await process_frame;quit(1 if failures else 0)
