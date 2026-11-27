extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Direct fixed-map encounter checks do not claim the pending ten-floor approach routes.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const GORGE_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Gorge corridor/"
var gorge_report={"map":15526,"route_status":"Direct fixed-map ambient test; a separate Cape fixture verifies the new305/306 access chains. Source5305 fight and gate remain pending.","native_identity_limit":"Species and level are applied; source enemy/base IDs are retained as evidence, not native stat bindings.","frequency_limit":"Existing real-time movement checks and uniform1–8 party-size bags are adaptations; original probability-ramp/count weights and turn-based formation remain unverified.","contact_survival_fixture":"The test hero receives10000HP so level45–47 contacts can be observed repeatedly without ending the run; production player/enemy stats are unchanged.","groups":[],"cameras":[]}
func corridor_physics()->String:
 var heights=PackedFloat32Array();var shapes=[]
 for y in 20:
  for x in 100:
   var point=Original.source_point(15526,Vector2i(x,y));heights.append(game.model.surface_height(point.x,point.y))
 for node in game.world.find_children("*","CollisionShape3D",true,false):
  var payload:Variant=node.shape.size if node.shape is BoxShape3D else node.shape.get_faces() if node.shape is ConcavePolygonShape3D else node.shape.get_instance_id() if node.shape!=null else null
  shapes.append([node.get_instance_id(),node.transform,payload])
 return var_to_bytes([heights,shapes,game.model.scenery_obstacles,game.model.get_meta("falan_links",[])]).hex_encode().sha256_text()
func _initialize():
 create_timer(600).timeout.connect(func():printerr("SOKIA_GORGE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GORGE_OUT))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-gorge-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 check(Original.owns(15526),"Existing original-map owner covers the complete source corridor")
 var state=Original.state(15526)
 check(state.size==Vector2i(100,20),"Entire100 by20 source map is retained")
 check(state.raw==Original.Art.raw_map(Original.path_for(15526)),"All original floor/object/flag planes are unchanged")
 var original_bits:PackedByteArray=state.bits.duplicate()
 var shared_profiles=JSON.stringify(preload("res://scripts/forest/forest_original_cliffs.gd").data())
 var shared_paint=preload("res://scripts/forest/forest_original_cliffs.gd").texture()
 Tour.travel(game,Tour.Indoor.layout(15526),{"arrival":Original.source_point(15526,Vector2i(20,7)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 var terrain_proof=corridor_physics()
 clear_enemies();game.model.waves.spawned=2
 check(Population.encounters_own(game.model) and Population.encounter_scope(game.model,Original.source_point(15526,Vector2i(74,4))),"Existing native encounter dispatch owns the fixed corridor and rare strip")
 check(game.model.waves.patrol_source==Population.bank(game.model) and Population.bank(game.model)==preload("res://scripts/forest/crowd/sokia_region_sprites.gd"),"Existing Sokia native actor bank owns both recovered appearances")
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 check(game.army_runtime.native.configure_kits(kits),"Recovered original wolf/ghost cue tables configure existing native combat")
 var source_links:Array=game.model.get_meta("falan_links",[])
 check(source_links.size()==2 and source_links.all(func(link):return int(link.get("floor",-1))in[7305009,7306000])and source_links.any(func(link):return int(link.get("floor",-1))==7305009 and link.at.distance_to(Original.source_point(15526,Vector2i(8,7)))<.01)and source_links.any(func(link):return int(link.get("floor",-1))==7306000 and link.at.distance_to(Original.source_point(15526,Vector2i(91,7)))<.01),"Only the two source config305/306 endpoint links are present; no direct fixed-map shortcut")
 check(game.world.map_features.get_meta("recovered_source_map")==15526,"Existing native-art renderer builds the exact fixed source map")
 var gorge_visual=game.world.map_features.find_child("SokiaGorgeSourceVisuals",true,false)
 check(gorge_visual!=null and int(game.world.map_features.get_meta("sokia_gorge_source_wall_anchors",0))==250,"Existing continuous cliff mass retains all250 original wall anchors")
 check(gorge_visual!=null and gorge_visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Corridor visual recovery creates no collider or navigation owner")
 check(gorge_visual!=null and gorge_visual.get_meta("source_stair_anchors")==[[8.,7.],[91.,7.]],"Both solid stair visuals retain their exact source anchors")
 check(JSON.stringify(preload("res://scripts/forest/forest_original_cliffs.gd").data())==shared_profiles and preload("res://scripts/forest/forest_original_cliffs.gd").texture()==shared_paint,"Local cliff paint/profile context preserves the default shared owner")
 game.explorer_npcs.prepare()
 var loot=game.exploration_loot
 loot.opened_chests["preserved-source-audit-ledger"]=true
 var loot_ledger=JSON.stringify(loot.opened_chests)
 var saved_inventory=JSON.stringify([game.settings.get("chest_swords",[]),game.settings.get("sword_upgrades",{}),game.settings.get("chest_nutrition",{})])
 check(loot.slots.all(func(slot):return not slot.active or not slot.chest),"Source15526 area entry contains no invented generic chest")
 check(loot.spawn_chest(0,game.player.position,"explicit-reward-test"),"Explicit chest reward entry point stays available")
 gorge_report.loot_owner={"node":str(loot.batches[0].get_path()),"script":loot.get_script().resource_path,"texture":loot.CHESTS[0].resource_path,"mesh_size":var_to_str(loot.batches[0].multimesh.mesh.size),"native_row":null,"pre_fix_trace":"east-owner-trace.json","source_policy":"Fixed15526 suppresses generic RNG area-entry chests only; explicit rewards/ledger/inventory remain available."}
 loot.clear();loot.prepare_world()
 check(loot.slots.all(func(slot):return not slot.active or not slot.chest),"Repeated source preparation suppresses only generic area-entry chests")
 check(JSON.stringify(loot.opened_chests)==loot_ledger,"Source chest policy preserves the opened-chest ledger")
 gorge_report.npcs=[]
 for actor in game.explorer_npcs.actors:
  var record:Dictionary=actor.node.get_meta("npc_record",{})
  gorge_report.npcs.append({"id":record.get("id",""),"name":record.get("name",""),"source_cell":record.get("cell",[]),"world_position":var_to_str(actor.node.global_position),"size":var_to_str(actor.node.get_aabb())if actor.node is VisualInstance3D else""})
 var zones=Population.data().zones.filter(func(z):return int(z.map)==15526)
 check(zones.size()==2,"Only the two source-confirmed ambient zones are installed")
 for cell in [Vector2i(74,4),Vector2i(74,5)]:check(int(Population.zone_at(15526,cell).id)==7045,"Rare strip selects source priority10 at "+str(cell))
 for cell in [Vector2i(73,4),Vector2i(75,4),Vector2i(74,3),Vector2i(74,6)]:check(int(Population.zone_at(15526,cell).id)==7044,"Rare strip never leaks beyond its two cells "+str(cell))
 var rng=RandomNumberGenerator.new();rng.seed=15526
 var rare=Population.zone_at(15526,Vector2i(74,4));var bag={};var counts={}
 for i in 16:
  var key=Population.Snow.weighted(bag,"gorge-source-weights",rare.groups,rng)
  counts[key]=counts.get(key,0)+1
 check(counts=={"mountain:7036":5,"mountain:7033":5,"mountain:7035":5,"mountain:7034":1},"One shuffle bag preserves the documented5:5:5:1 zone weights")
 var rare_group:Dictionary=Population.data().groups["mountain:7034"]
 check(rare_group.raw.slice(5,7)==["7027","7026"],"Normal and level1 ghosts retain distinct source enemy IDs")
 var rare_bag={};var rare_levels={}
 for i in 11:
  rare_bag["south-group:%s"%rare.id]=["mountain:7034"];rare_bag["south-count:%s"%rare.id]=[1]
  var member:Array=Population.group(rare,rare_bag,rng)[0]
  rare_levels[member[1]]=rare_levels.get(member[1],0)+1
 check(rare_levels.get(1,0)==1 and rare_levels.values().reduce(func(a,b):return a+b,0)==11,"Rare group membership bag retains ten normal ghosts for one level1 ghost")
 check(rare_levels.keys().all(func(level):return level==1 or level>=45 and level<=47),"Ghost level draws stay inside the original two disjoint ranges")
 gorge_report.rare_member_bag=rare_levels
 await gorge_camera("15526-west-corridor",Vector2i(20,7),Vector2.RIGHT)
 await gorge_camera("15526-east-corridor",Vector2i(85,7),Vector2.LEFT)
 if "--trace-east-only" in OS.get_cmdline_user_args():
  await trace_east_owner();game.queue_free();await process_frame;quit(0);return
 if "--segment-only" in OS.get_cmdline_user_args():
  print("SOKIA_GORGE_SEGMENT_RESULT checks=",checks," failures=",errors);game.queue_free();await process_frame;quit(1 if errors else 0);return
 await gorge_camera("15526-west-stair",Vector2i(11,7),Vector2.LEFT)
 await gorge_camera("15526-east-stair",Vector2i(88,7),Vector2.RIGHT)
 for gid in ["7033","7035","7036","7034"]:
  var zone=rare if gid=="7034" else Population.zone_at(15526,Vector2i(20,7))
  var cell=Vector2i(74,4)if gid=="7034"else Vector2i(20,7)
  var view_cell=Vector2i(75,7)if gid=="7034"else Vector2i(20,8)
  var key="mountain:"+gid;var source:Dictionary=Population.data().groups[key]
  var force={"south-group:%s"%zone.id:[key],"south-count:%s"%zone.id:[2]}
  force["south-member:"+key]=[1,0]if source.members.size()==2 else[0,0]
  var party=Population.group(zone,force,rng)
  check(party.size()==2,"Direct source group keeps the requested complete representative party "+gid)
  if gid=="7034":check(party.any(func(m):return m[1]==1)and party.any(func(m):return m[1]>=45 and m[1]<=47),"Direct rare trigger includes level1 and normal ghost without spawn grinding")
  var row={"source_group":gid,"zone":int(zone.id),"cell":[cell.x,cell.y],"view_cell":[view_cell.x,view_cell.y],"source_enemy_ids":source.raw.slice(5,5+source.members.size()),"members":party,"generations":[]}
  if gid=="7034":await gorge_camera("15526-rare-strip-trigger",cell,Vector2.UP)
  for generation in 2:
   clear_enemies();game.model.waves.snow_group_ids.clear()
   game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
   var at=Original.source_point(15526,cell)
   game.player.position=game.model.world_point(at,.15);game.player.reset_physics_interpolation();game.model.hero_position=game.player.position
   game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0;game.model.waves.snow_pending=[];game.model.waves.spawn_clock=0
   for i in 3:game.model.waves.tick(1.,game.player.position)
   check(game.model.enemies.is_empty(),"Standing still never starts an ambient fight "+gid)
   game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
   game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
   check(game.model.enemies.size()==party.size(),"Direct source group spawns through normal native dispatch "+gid+" generation"+str(generation))
   var handles=[];var observed=[]
   for enemy in game.model.enemies.values():
    check(game.army_runtime.handles.has(enemy.id)and int(enemy.route_encounter)==int(zone.id)and int(game.army_runtime.unit_state(game.army_runtime.handles[enemy.id]).pose_row)==int(enemy.skin),"Recovered member has one native handle, exact atlas row and source zone "+gid)
    handles.append(game.army_runtime.handles.get(enemy.id,0));observed.append([int(enemy.skin),int(enemy.level)])
   var expected=party.map(func(m):return[int(Population.data().species[m[0]].skin),int(m[1])])
   check(observed==expected,"Native presentation retains each source appearance and level "+gid)
   var view_at=game.model.world_point(Original.source_point(15526,view_cell),.15)
   check(game.army_runtime.native.can_reach(game.player.position,view_at,.5),"Full-body fight view stays on reachable original ground after the exact trigger "+gid)
   game.player.position=view_at;game.model.hero_position=view_at;game.player.reset_physics_interpolation()
   if generation==0:await gorge_camera("15526-group-"+gid,view_cell,Vector2.UP)
   game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
   game.tuning.invincible=false;game.player.invuln=0.;game.player.max_hp=10000.;game.player.hp=game.player.max_hp
   game.player.model.clear_kagerou_dodge()
   var living_ids=game.model.enemies.keys();var player_hp:float=game.player.hp
   for tick in 480:
    # The fixed camera freezes player movement; advance its ordinary protection clocks.
    game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.)
    game.army_runtime.integration_tick(1./60.)
   var contacts=game.army_runtime.event_log.filter(func(e):return e.kind=="external_damage"and e.external_kind==0 and e.source_id in living_ids)
   check(living_ids.all(func(id):return contacts.any(func(e):return e.source_id==id)),"Every directly triggered native member delivers original contact events "+gid)
   var player_damaged:bool=game.player.hp<player_hp
   check(player_damaged,"Native contact delivers ordinary player damage "+gid)
   if game.player.hp>=player_hp:printerr("SOKIA_GORGE_DAMAGE_DIAGNOSTIC group=",gid," contacts=",contacts.slice(0,3)," player=",[game.player.hp,game.player.max_hp,game.player.invuln,game.tuning.invincible,game.player.crossgate_combo_protected(),game.player.active_ability.mode])
   if generation==0 and gid in ["7036","7034"]:await gorge_camera("15526-group-"+gid+"-native-contact",view_cell,Vector2.UP)
   for handle in handles:game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
   game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
   check(game.model.enemies.is_empty(),"Ordinary native death delivery clears the entire group "+gid)
   check(handles.all(func(handle):return not game.army_runtime.apply_hit(handle,{"amount":1.}).accepted),"Retired handles reject stale hits before reuse "+gid)
   row.generations.append({"generation":generation,"spawned":observed,"native_contacts":contacts.size(),"player_damaged":player_damaged,"cleaned":game.model.enemies.is_empty()})
  gorge_report.groups.append(row)
 check(Original.state(15526).bits==original_bits,"Native fights preserve every original walk/collision cell")
 check(corridor_physics()==terrain_proof,"Native fights preserve every source terrain height, static collider/obstacle and port")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Direct fixture preserves saved adventure state")
 check(JSON.stringify(loot.opened_chests)==loot_ledger and JSON.stringify([game.settings.get("chest_swords",[]),game.settings.get("sword_upgrades",{}),game.settings.get("chest_nutrition",{})])==saved_inventory,"Source chest policy leaves saved loot/inventory/nutrition untouched")
 gorge_report.checks=checks;gorge_report.failures=errors
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(GORGE_OUT+"verification-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(gorge_report,"  "));file.close()
 print("SOKIA_GORGE_RESULT groups=",gorge_report.groups.size()," checks=",checks," failures=",errors," captures=",gorge_report.cameras.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func gorge_camera(label_:String,cell:Vector2i,toward:Vector2):
 if DisplayServer.get_name()=="headless":return
 var at=Original.source_point(15526,cell)
 game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
 game.army_runtime.native.step(.016);game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 game.camera_rig.yaw=atan2(-toward.x,-toward.y);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 for i in 4:await process_frame
 var camera:Camera3D=game.camera_rig.camera
 check(is_equal_approx(camera.fov,63.),"Fixed view uses the normal gameplay camera "+label_)
 gorge_report.cameras.append({"name":label_,"source_cell":[cell.x,cell.y],"toward":[toward.x,toward.y],"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation),"fov":camera.fov,"floor":15526,"seed":game.model.seed_value})
 RenderingServer.force_draw();root.get_texture().get_image().save_png(GORGE_OUT+label_+".png")
func trace_east_owner():
 var camera:Camera3D=game.camera_rig.camera;var report={"native":[],"nodes":[],"loot":[],"camera":var_to_str(camera.global_transform)}
 for slot in game.exploration_loot.slots:
  if slot.active:report.loot.append({"owner":str(game.exploration_loot.get_path()),"script":game.exploration_loot.get_script().resource_path,"slot":slot,"texture":game.exploration_loot.CHESTS[slot.kind].resource_path if slot.chest else game.exploration_loot.FOODS[slot.kind].resource_path,"native_row":null})
 var snapshot:Dictionary=game.army_runtime.render_snapshot()
 for i in snapshot.get("positions",[]).size():
  report.native.append({"handle":snapshot.handles[i],"id":snapshot.logical_ids[i],"team":snapshot.teams[i],"kind":snapshot.kinds[i],"pose_row":snapshot.pose_rows[i],"position":var_to_str(snapshot.positions[i]),"state":game.army_runtime.unit_state(snapshot.handles[i])})
 for node in game.find_children("*","GeometryInstance3D",true,false):
  if not node.is_visible_in_tree():continue
  var box:AABB=node.global_transform*node.get_aabb();var distance=box.get_center().distance_to(camera.global_position)
  if distance>45 and not box.has_point(camera.global_position):continue
  var row={"path":str(node.get_path()),"class":node.get_class(),"world":var_to_str(node.global_transform),"bounds":var_to_str(box),"metadata":{},"ancestors":[]}
  if node is Sprite3D:
   row.texture=node.texture.resource_path if node.texture!=null else"";row.offset=var_to_str(node.offset);row.pixel_size=node.pixel_size
   if node.texture is AtlasTexture:row.atlas=node.texture.atlas.resource_path;row.region=var_to_str(node.texture.region)
  if node is MultiMeshInstance3D:
   row.instances=node.multimesh.instance_count;row.visible_instances=node.multimesh.visible_instance_count
   var entries=[]
   for i in node.multimesh.instance_count:
    var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
    if pose.origin.distance_to(camera.global_position)<35:entries.append({"index":i,"pose":var_to_str(pose),"custom":var_to_str(node.multimesh.get_instance_custom_data(i))})
   row.near_instances=entries
  for key in node.get_meta_list():row.metadata[str(key)]=var_to_str(node.get_meta(key))
  var ancestor:Node=node
  for i in 7:
   if ancestor==null:break
   row.ancestors.append({"path":str(ancestor.get_path()),"script":ancestor.get_script().resource_path if ancestor.get_script()!=null else""});ancestor=ancestor.get_parent()
  report.nodes.append(row)
 var file=FileAccess.open(GORGE_OUT+"east-owner-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 if DisplayServer.get_name()!="headless":
  for item in [["without-native-army",game.crowd.army],["without-map-features",game.world.map_features],["without-player-model",game.player.model],["without-exploration-loot",game.exploration_loot]]:
   var node:Node3D=item[1];var shown=node.visible;node.hide()
   for i in 4:await process_frame
   RenderingServer.force_draw();root.get_texture().get_image().save_png(GORGE_OUT+"east-diagnostic-"+item[0]+".png");node.visible=shown
   for i in 2:await process_frame
 print("SOKIA_GORGE_OWNER_TRACE native_rows=",report.native.size()," nodes=",report.nodes.size())
