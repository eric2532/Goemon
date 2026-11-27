extends "res://tests/forest-shrine/south_kili_route_review.gd"
const Population=preload("res://scripts/forest/forest_south_kili_population.gd")
const VENOA_UNDERSEA_STAGES=[
 ["interior",15592,15592,"維諾亞海底洞窟 維諾亞側1F",Vector2.ZERO,Vector2.ZERO],
 ["interior",15593,15593,"維諾亞海底洞窟2F",Vector2.ZERO,Vector2.ZERO],
 ["interior",15594,15594,"維諾亞海底洞窟 炎之洞窟側1F",Vector2.ZERO,Vector2.ZERO]
]
var results=[]
var npc_count=0
var preserved_count=0
var checks=0
func check(ok:bool,label_:String):
 checks+=1;super.check(ok,label_)
func _initialize():
 create_timer(1500).timeout.connect(func():printerr("SOUTH_KILI_POPULATION_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-south-kili-population-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=341;game.set_process(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Population/"))
 var branch_only="--venoa-undersea" in OS.get_cmdline_user_args()
 var stages=STAGES.filter(func(s):return s[1] in [11001,15003,15004,15005]) + VENOA_UNDERSEA_STAGES if branch_only else STAGES
 for stage in stages:
  print("SOUTH_KILI_POPULATION_ENTER ",stage[0]," ",stage[1])
  var layout=Tour.Indoor.layout(stage[1]) if stage[0]=="interior" else Tour.Regions.layout(stage[0]) if stage[0]!="city" else Tour.outdoor_layout(get_meta("falan_venture"),"city")
  layout.seed=341
  var at:Vector2=stage[4]
  if stage[0] in ["south_lakes","sokia_coast"]:at=Tour.Regions.frame(stage[0]).inverse()*at
  Tour.travel(game,layout,{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  game.army_runtime.refresh_navigation(0)
  if stage[1] in [15003,15004,15005] or stage[1] in Population.VENOA_UNDERSEA:
   var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
   check(game.army_runtime.native.configure_kits(kits),"Undersea original28-column timelines configure native combat on "+str(stage[1]))
  if stage[1]==15004:
   var native_props=preload("res://scripts/forest/forest_coastal_rooms.gd")
   for serial in native_props.Data.NATIVE:
    var shape:Mesh=native_props.native_shape(serial)
    check(shape!=null and shape.get_surface_count()>0,"Native coastal family retains solid geometry without recursive dispatch "+str(serial))
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  var row={"area":stage[0],"floor":stage[1],"title":stage[3],"npcs":[],"zones":[],"links":game.model.get_meta("falan_links",[])}
  var expected=Population.data().npcs.filter(func(n):return n.area==stage[0] and int(n.floor)==stage[1])
  game.explorer_npcs.prepare()
  print("SOUTH_KILI_NPC_CONTEXT ",game.model.falan_area," ",game.model.falan_floor," actors=",game.explorer_npcs.actors.size())
  if not expected.is_empty():
   check(game.explorer_npcs.actors.size()==expected.size(),"No duplicate NPC owners "+str(stage[1])+stage[0])
   for actor in game.explorer_npcs.actors:
    var record:Dictionary=actor.node.get_meta("npc_record")
    check(Population.source_cell(game.model,Vector2(actor.node.position.x,actor.node.position.z))==Vector2i(record.cell[0],record.cell[1]),"Exact original NPC cell "+record.id)
    var talked=false
    for dy in range(-1,2):
     for dx in range(-1,2):
      if dx==0 and dy==0:continue
      var spot=Vector2(actor.node.position.x,actor.node.position.z)+Vector2(dx,dy)*3.
      if not game.model.terrain.disk_clear(Vector3(spot.x,game.model.surface_height(spot.x,spot.y)+.5,spot.y),.4):continue
      game.player.position=game.model.world_point(spot,.15);game.player.reset_physics_interpolation()
      game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
      if game.explorer_npcs.nearest.get("node")!=actor.node:continue
      check(game.explorer_npcs.hint.visible and record.name in game.explorer_npcs.hint.text,"Named F prompt "+record.id)
      var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
      talked=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("id","")=="source:"+record.id
      if talked:
       check(not game.dialogue.body.text.strip_edges().is_empty(),"Source or placeholder dialogue has text "+record.id)
       var reveal=InputEventKey.new();reveal.physical_keycode=KEY_SPACE;reveal.pressed=true;game._input(reveal)
       reveal=reveal.duplicate();reveal.pressed=false;game._input(reveal)
       check(game.dialogue.body.visible_characters>=game.dialogue.body.get_total_character_count(),"Normal Space input reveals the dialogue "+record.id)
       if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless" and not row.has("npc_capture"):
        row.npc_capture=true;game.ui.show()
        var toward=actor.node.global_position-game.player.position
        game.camera_rig.yaw=atan2(-toward.x,-toward.z);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
        game.camera_rig.reset_follow();game.camera_rig.update_camera(1.,true)
        for i in 4:await process_frame
        RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+"Population/npc-"+str(stage[1])+"-"+stage[0]+".png")
       game.explorer_npcs.finish();break
     if talked:break
    check(talked,"Normal F input talks at source location "+record.id+" "+record.name)
    npc_count+=1
    if record.get("existing_placement",false):preserved_count+=1
    row.npcs.append({"id":record.id,"name":record.name,"cell":record.cell,"talked":talked,"existing_placement":record.get("existing_placement",false)})
  if stage[1]==15003:
   check(row.links.any(func(l):return l.to=="freyja_door" and l.get("floor")==15004),"B2 descends to original Kili-side floor")
   check(row.links.any(func(l):return l.to=="freyja_door" and l.get("floor")==15005),"B2 returns through original Freyja-side floor")
   check(not row.links.any(func(l):return l.to=="freyja_outside"),"B2 has no route-skipping exterior shortcut")
  if Population.encounters_own(game.model):
   clear_enemies()
   if stage[1] in Population.VENOA_UNDERSEA:
    for repeat in 4:game.model.waves.tick(1.,game.player.position)
    check(game.model.enemies.is_empty(),"Venoa Undersea source owner suppresses old fixed patrol pool "+str(stage[1]))
    check(game.model.waves.patrol_source==Undersea,"Venoa Undersea reuses native undersea bank "+str(stage[1]))
   if stage[1]==15003:
    game.model.waves.spawned=0
    game.model.waves.tick(1.,game.model.world_point(Undersea.BOSS_AT))
    check(game.model.enemies.is_empty(),"Source15003 no longer duplicates random Oznik groups with a fixed-position boss")
   if stage[1]==11001:
    game.model.waves.spawned=0
    game.model.waves.tick_venoa_bears([])
    game.army_runtime.import_arrivals()
    var bosses=game.model.enemies.values().filter(func(e):return e.get("boss",false))
    check(bosses.size()==1,"Existing special boss retained "+str(stage[1]))
    check(game.model.enemies.size()==1,"Existing bear boss count retained")
    for e in game.model.enemies.values():check(game.army_runtime.handles.has(e.id),"Special encounter remains native")
    var ids=game.model.enemies.keys()
    for repeat in 5:
     game.model.waves.tick_venoa_bears([])
    check(game.model.enemies.keys()==ids,"Repeated boss ticks cannot duplicate special groups")
    clear_enemies()
   game.model.waves.spawned=2
   var state=game.model.waves.route_state;var by_zone={}
   for y in state.size.y:
    for x in state.size.x:
     var cell=Vector2i(x,y)
     if not Tour.Indoor.open_cell(state.bits,state.size,x,y):continue
     var point:Vector2=state.origin+Vector2(cell)*3.
     if not Population.encounter_scope(game.model,point):continue
     var source=Population.source_cell(game.model,point)
     var map_id=stage[1] if stage[0]=="interior" else stage[2]
     var zone=Population.zone_at(map_id,source)
     if zone.is_empty():continue
     if not by_zone.has(int(zone.id)):by_zone[int(zone.id)]=[]
     by_zone[int(zone.id)].append(point)
   for zone_id in by_zone:
    var zone=Population.data().zones.filter(func(z):return int(z.id)==zone_id)[0]
    if stage[1] in Population.VENOA_UNDERSEA:
     var bags={};var source_rng=RandomNumberGenerator.new();source_rng.seed=15592
     var sizes={};var appearances={};var levels={}
     for draw in 100:
      var party=Population.group(zone,bags,source_rng)
      sizes[party.size()]=sizes.get(party.size(),0)+1
      for member in party:
       appearances[member[0]]=appearances.get(member[0],0)+1;levels[member[1]]=true
     check(sizes=={1:20,2:20,3:20,4:20,5:20},"Undersea group-size shuffle bag retains documented1–5 bounds")
     check(appearances=={2:150,3:150},"Undersea membership shuffle bag preserves1:1 source weights")
     check(levels=={26:true,27:true},"Undersea level shuffle bag includes both original levels")
    var tested=false
    if stage[0]=="interior":
     var p:Vector2=by_zone[zone_id][by_zone[zone_id].size()/2];var q=game.model.world_point(p)
     print("SOUTH_KILI_CLEARANCE ",stage[1]," at=",p," fit=",game.model.waves.patrol_fits.slice(0,6)," nav=",game.model.waves.navigation.move_clear(q/game.model.falan_scale,1.0)," native=",game.army_runtime.native.can_reach(q,q,.1),"/",game.army_runtime.native.can_reach(q,q,1.0))
    for point in by_zone[zone_id]:
     if game.model.get_meta("falan_links",[]).any(func(l):return point.distance_squared_to(l.at)<144):continue
     game.player.position=game.model.world_point(point,.15);game.model.hero_position=game.player.position
     game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0;game.model.waves.snow_pending=[]
     for i in 3:game.model.waves.tick(1.,game.player.position)
     check(game.model.enemies.is_empty(),"Standing still has no encounters")
     var groups=[]
     for choice in zone.groups:
      var members=[]
      for m in Population.data().groups[choice[0]].members:members.append([int(m[0]),int(m[1])])
      game.model.waves.snow_pending=members;game.model.waves.spawn_clock=0
      game.model.waves.tick(1.,game.player.position)
      if game.model.enemies.size()!=members.size():clear_enemies();continue
      check(game.model.enemies.values().all(func(e):return e.has("route_encounter") and not e.has("patrol_radius")),"Documented group uses native encounters, not roaming posts")
      game.army_runtime.import_arrivals()
      for e in game.model.enemies.values():check(game.army_runtime.handles.has(e.id),"Native imported source group "+choice[0])
      if stage[1] in Population.VENOA_UNDERSEA:
       check(game.model.enemies.values().all(func(e):return e.level in [26,27] and e.skin in [1,2]),"Native Venoa Undersea members retain source species and levels")
      if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless" and not row.has("group_capture"):
       row.group_capture=true
       game.army_runtime.native.step(.016);game.army_runtime.dispatch_events();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
       for child in game.get_children():
        if child is CanvasLayer:child.hide()
       var focus=Vector3.ZERO
       for e in game.model.enemies.values():focus+=e.pos
       focus/=game.model.enemies.size()
       var toward=focus-game.player.position;game.camera_rig.yaw=atan2(-toward.x,-toward.z);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
       game.camera_rig.reset_follow();game.camera_rig.update_camera(1.,true)
       for i in 4:await process_frame
       var camera:Camera3D=game.camera_rig.camera
       row.group_camera={"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov,"seed":game.model.seed_value,"area":game.model.falan_area,"floor":game.model.falan_floor}
       RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+"Population/group-"+str(stage[1])+"-"+stage[0]+".png")
      if stage[1] in Population.VENOA_UNDERSEA:
       for e in game.model.enemies.values().duplicate():game.army_runtime.damage_enemy(e.id,1000000.)
       game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
       check(game.model.enemies.is_empty(),"Native Venoa Undersea fight clears through ordinary death delivery")
      groups.append(choice[0]);clear_enemies()
     if groups.size()!=zone.groups.size():continue
     row.zones.append({"id":zone_id,"cell":v(Vector2(Population.source_cell(game.model,point))),"groups":groups})
     tested=true;break
    check(tested,"Every reachable source pool installed at an actual location "+str(zone_id))
   if not row.zones.is_empty():
    var zone=Population.data().zones.filter(func(z):return int(z.id)==int(row.zones[0].id))[0]
    var point:Vector2=by_zone[int(zone.id)][by_zone[int(zone.id)].size()/2]
    game.player.position=game.model.world_point(point,.15)
    game.model.waves.snow_last=game.player.position/game.model.falan_scale-Vector3(3.01,0,0);game.model.waves.snow_distance=0;game.model.waves.snow_pending=[];game.model.waves.spawn_clock=0
    var p=int(zone.probability[0]);game.model.waves.snow_bags["probability:%s"%zone.id]=[p];game.model.waves.snow_bags["check:%s:%d"%[zone.id,p]]=[true]
    game.model.waves.tick(1.,game.player.position)
    check(not game.model.waves.snow_pending.is_empty() or not game.model.enemies.is_empty(),"Walked tile dispatches weighted source encounter")
    clear_enemies()
  else:
   clear_enemies()
   for i in 4:game.model.waves.tick(1.,game.player.position)
   check(game.model.enemies.is_empty(),"City and Kili stay safe")
  results.append(row)
  var f=FileAccess.open(REVIEW+("venoa-undersea-locations.json" if branch_only else "population-locations.json"),FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "));f.close()
 if not branch_only:
  check(npc_count==19,"All nineteen route source interactions checked")
  check(preserved_count==11,"All eleven existing placements retained")
 print("SOUTH_KILI_POPULATION_RESULT maps=",results.size()," npcs=",npc_count," preserved=",preserved_count," checks=",checks," failures=",errors)
 game.queue_free();await process_frame;quit(1 if errors else 0)
func clear_enemies():
 for e in game.model.enemies.values().duplicate():
  if game.army_runtime.handles.has(e.id):game.army_runtime.despawn(game.army_runtime.handles[e.id])
  game.model.enemies.erase(e.id)
 game.model.waves.snow_pending=[]
