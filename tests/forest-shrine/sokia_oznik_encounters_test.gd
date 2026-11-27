extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Direct source-group selection avoids grinding for the two rare encounters.
const OZNIK_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Oznik encounters/"
var evidence={"map":15003,"source_zone":5012,"goal_complete":false,"groups":[],"generations":[],"cameras":[],"unverified":["Original probability ramp and party-size weights","Source9067 escape behavior; both variants retain existing native Oznik combat","Original item18404 reward and natural acquisition of18403"]}
func _initialize():
 create_timer(500).timeout.connect(func():printerr("SOKIA_OZNIK_TIMEOUT");quit(1))
 run.call_deferred()
func one_group(zone:Dictionary,gid:String)->Dictionary:
 var result=zone.duplicate(true);result.groups=[[gid,1]];return result
func data_checks()->Dictionary:
 var zone=Population.zone_at(15003,Vector2i(30,30))
 check(int(zone.id)==5012 and zone.groups.map(func(row):return [str(row[0]),int(row[1])])==[["5014",6],["5010",6],["5012",6],["9034",1],["9033",2]],"All source15003 group weights restored")
 var held={"source_item_18403":1};var rng=RandomNumberGenerator.new();rng.seed=15003
 var weights=[]
 for items in [{},held]:
  var allowed=Population.eligible_groups(zone,items);var counts={};var bags={};var total=0
  for choice in allowed:total+=int(choice[1])
  for i in total:
   var gid=Population.Snow.weighted(bags,"source-cycle",allowed,rng);counts[gid]=counts.get(gid,0)+1
  var expected={"5014":6,"5010":6,"5012":6}
  expected["9034" if not items.is_empty() else "9033"]=1 if not items.is_empty() else 2
  check(counts==expected,"One shuffle bag preserves only eligible source weights, held18403="+str(not items.is_empty()))
  weights.append(counts)
 check(Population.group(one_group(zone,"9034"),{},rng).is_empty(),"Required-item group rejects missing18403")
 check(Population.group(one_group(zone,"9033"),{},rng,held).is_empty(),"Forbidden-item group rejects held18403")
 check(Population.group({"id":0,"groups":[],"maximum":0},{},rng).is_empty(),"Empty safe-zone pool draws nothing")
 for gid in ["9033","9034"]:
  var items=held if gid=="9034" else {};var bags={};var sizes={};var valid=true;var identities={}
  for i in 30:
   var party=Population.group(one_group(zone,gid),bags,rng,items);var counts={}
   sizes[party.size()]=sizes.get(party.size(),0)+1
   for member in party:
    var id=str(member[2]);counts[id]=counts.get(id,0)+1;identities[id]=true
    valid=valid and member[3]==gid and (member[1]==40 if member[0]==4 else member[1]>=18 and member[1]<=20)
   valid=valid and counts.get("9068" if gid=="9034" else "9067",0)==1 and counts.get("5013",0)>=1 and counts.get("5015",0)>=1
  check(valid,"Mandatory party keeps one distinct source boss and both escort types: "+gid)
  check(sizes=={3:5,4:5,5:5,6:5,7:5,8:5},"Valid-size shuffle bag stays within source maximum8: "+gid)
  evidence.groups.append({"group":gid,"identities":identities.keys(),"sizes":sizes})
 var shared={};var gates_valid=true
 for i in 80:
  var items=held if i%2 else {};var party=Population.group(zone,shared,rng,items)
  for member in party:
   if member.size()>3:gates_valid=gates_valid and member[3]==("9034" if i%2 else "9033")
 check(gates_valid,"Changing inventory cannot release a stale opposite-gate ticket")
 check(held=={"source_item_18403":1},"Encounter selection preserves quest inventory")
 evidence.weight_cycles=weights
 return zone
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OZNIK_OUT))
 var zone=data_checks()
 if "--data-only" not in OS.get_cmdline_user_args():
  await native_checks(zone)
  check(evidence.get("native_complete",false),"Native fixture reaches every required check without an early script error")
 evidence.checks=checks;evidence.failures=errors;evidence.renderer=DisplayServer.get_name()
 var file=FileAccess.open(OZNIK_OUT+("selection.json" if "--data-only" in OS.get_cmdline_user_args() else "rendered.json" if DisplayServer.get_name()!="headless" else "native.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(evidence,"  "));file.close()
 print("SOKIA_OZNIK_RESULT checks=",checks," failures=",errors)
 if game!=null:game.queue_free();await process_frame
 quit(1 if errors else 0)
func native_checks(zone:Dictionary):
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-oznik-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=15003;game.tuning.invincible=true;game.set_process(false)
 Tour.travel(game,Tour.Indoor.layout(15003),{"arrival":Vector2(57,48),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 clear_enemies();game.model.waves.snow_group_ids.clear();game.model.waves.snow_last=Vector3.INF
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 check(game.army_runtime.native.configure_kits(kits),"Source groups retain existing native undersea combat kits")
 game.player.position=game.model.world_point(Undersea.BOSS_AT,.15)
 for i in 3:game.model.waves.tick(1.,game.player.position)
 check(game.model.enemies.is_empty(),"Old boss location no longer starts a duplicate fixed fight")
 var chart=preload("res://scripts/forest/forest_falan_chart.gd").new();chart.refresh(game.model)
 check(not chart.pins.any(func(pin):return pin.label==Undersea.BOSS_NAME),"Random source boss no longer has an invented fixed-location minimap marker")
 var rng=RandomNumberGenerator.new();rng.seed=18403
 var state=game.model.waves.route_state;var baseline=game.army_runtime.handles.size()
 var locations=[]
 for y in state.size.y:
  for x in state.size.x:
   if not Tour.Indoor.open_cell(state.bits,state.size,x,y):continue
   var point:Vector2=state.origin+Vector2(x,y)*3.
   if int(Population.zone_at(15003,Population.source_cell(game.model,point)).get("id",-1))!=5012:continue
   if game.model.get_meta("falan_links",[]).any(func(link):return point.distance_squared_to(link.at)<144.):continue
   var clearance=0
   for dy in range(-4,5):
    for dx in range(-4,5):
     if Tour.Indoor.open_cell(state.bits,state.size,x+dx,y+dy):clearance+=1
   locations.append([point,clearance])
 locations.sort_custom(func(a,b):return a[1]>b[1])
 for gid in ["9033","9034"]:
  for repeat in 3:
   game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
   if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
   game.exploration_loot.clear();game.player.clear_food_buffs()
   game.tuning.invincible=true;game.player.max_hp=10000.;game.player.hp=10000.
   var items={"source_item_18403":1} if gid=="9034" else {}
   set_meta("university_quest_items",items)
   var forced={"south-count:%s:%s"%[zone.id,gid]:[int(zone.maximum)]} if repeat==2 else {}
   var party=Population.group(one_group(zone,gid),forced,rng,items)
   if repeat==2:check(party.size()==int(zone.maximum),"Direct native boundary uses all eight source party slots: "+gid)
   var spawned_party=false;var center=Vector2.ZERO
   for location in locations:
    center=location[0]
    game.player.position=game.model.world_point(center,.15);game.model.hero_position=game.player.position
    game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
    game.model.waves.tick(1.,game.player.position)
    if game.model.enemies.size()==party.size():spawned_party=true;break
    clear_enemies();game.model.waves.snow_group_ids.clear()
   check(spawned_party,"Direct source group fits an actual reachable source location: "+gid+" / "+str(repeat))
   if not spawned_party:continue
   game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
   var valid=true;var boss_count=0;var handles=[]
   for enemy in game.model.enemies.values():
    var handle=int(game.army_runtime.handles.get(enemy.id,0));handles.append(handle)
    valid=valid and handle!=0 and enemy.get("source_group","")==gid and int(enemy.route_encounter)==5012 and int(game.army_runtime.unit_state(handle).pose_row)==int(enemy.skin)
    if enemy.get("boss",false):boss_count+=1;valid=valid and enemy.level==40 and enemy.undersea_slot==0 and enemy.max_hp==Undersea.BOSS_HP
   check(valid and boss_count==1,"One native handle, source identity and preserved boss combat per member: "+gid)
   if repeat==0:await capture(gid,center)
   game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
   game.tuning.invincible=false;game.player.invuln=0.;game.player.max_hp=10000.;game.player.hp=game.player.max_hp;game.player.model.clear_kagerou_dodge()
   var living_ids=game.model.enemies.keys();var player_hp:float=game.player.hp
   for tick in 1200:
    game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.)
    game.army_runtime.integration_tick(1./60.)
   var contacts=game.army_runtime.event_log.filter(func(event):return event.kind=="external_damage" and event.external_kind==0 and event.source_id in living_ids)
   check(living_ids.all(func(id):return contacts.any(func(event):return event.source_id==id)),"Every native source member delivers ordinary combat contacts: "+gid)
   check(game.player.hp<player_hp,"Native source party damages the ordinary player: "+gid)
   var missing=living_ids.filter(func(id):return not contacts.any(func(event):return event.source_id==id))
   evidence.generations.append({"group":gid,"generation":repeat,"party":party,"source_cell":v(Vector2(Population.source_cell(game.model,center))),"contacts":contacts.size(),"missing_contact_members":missing.map(func(id):return {"id":id,"source_enemy":game.model.enemies[id].get("source_enemy",""),"state":game.army_runtime.unit_state(game.army_runtime.handles[id])}),"player_damaged":game.player.hp<player_hp})
   var cleanup_attempts=0
   while handles.any(func(handle):return game.army_runtime.valid(handle)) and cleanup_attempts<180:
    for handle in handles:
     if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
    if handles.any(func(handle):return game.army_runtime.valid(handle)):game.army_runtime.integration_tick(1./60.)
    cleanup_attempts+=1
   game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
   check(game.model.enemies.is_empty() and handles.all(func(handle):return not game.army_runtime.valid(handle)),"Death delivery retires the whole party and all native handles: "+gid)
   check(game.army_runtime.handles.size()==baseline,"Repeated source fight preserves native handle count")
   check(get_meta("university_quest_items")==items,"Native fight preserves held-item gate state")
   game.model.waves.snow_group_ids.clear()
 set_meta("university_quest_items",{})
 game.model.waves.snow_pending=Population.group(one_group(zone,"9034"),{},rng,{"source_item_18403":1})
 game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0;game.model.waves.spawn_clock=0
 var bags_before=JSON.stringify(game.model.waves.snow_bags)
 game.model.waves.tick(1.,game.player.position)
 check(game.model.enemies.is_empty() and game.model.waves.snow_pending.is_empty(),"A pending gated party is rejected if its required item disappears before placement")
 check(game.model.waves.snow_distance==0. and JSON.stringify(game.model.waves.snow_bags)==bags_before,"Rejecting a stale pending gate requires fresh walking, without a free standing encounter draw")
 clear_enemies()
 evidence.native_complete=true
func capture(gid:String,center:Vector2):
 if DisplayServer.get_name()=="headless":return
 var focus=Vector3.ZERO
 for enemy in game.model.enemies.values():focus+=enemy.pos
 focus/=game.model.enemies.size()
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 game.player.velocity=Vector3.ZERO
 game.camera_rig.yaw=atan2(-(focus-game.player.position).x,-(focus-game.player.position).z)
 game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.impulse=0.;game.camera_rig.kick_strength=0.;game.camera_rig.kick_age=1.
 game.camera_rig.camera.fov=63.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 5:await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(OZNIK_OUT+gid+"-normal.png")
 var camera:Camera3D=game.camera_rig.camera
 evidence.cameras.append({"group":gid,"source_cell":v(Vector2(Population.source_cell(game.model,center))),"pitch":game.COMBAT_CAMERA_PITCH,"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation),"fov":camera.fov,"seed":game.model.seed_value})
