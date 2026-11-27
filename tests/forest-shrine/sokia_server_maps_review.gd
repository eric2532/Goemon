extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Review-only layouts are enabled only inside this fixture; production gate status is preserved.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const SERVER_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server fixed maps/"
var server_report={"maps":[],"groups":[],"captures":[],"scope":"Direct source-layout and ordinary-group QA. Review-only map discovery is enabled temporarily in this fixture; scripted quest triggers are not activated."}
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("SOKIA_SERVER_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func candidate_cells(id:int)->Array:
 var state=Original.state(id);var rows=[];var center=Vector2(state.size)*.5
 for y in range(2,state.size.y-2):
  for x in range(2,state.size.x-2):
   var cell=Vector2i(x,y);var serial=state.raw.decode_u16(20+(y*state.size.x+x)*2)
   if serial in [0,100]or not Original.open(state.bits,state.size,cell):continue
   if not [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return Original.open(state.bits,state.size,cell+d)):continue
   rows.append(cell)
 rows.sort_custom(func(a,b):return Vector2(a).distance_squared_to(center)<Vector2(b).distance_squared_to(center))
 return rows
func clear_cell(id:int,candidates:Array)->Vector2i:
 for cell in candidates:
  var at=game.model.world_point(Original.source_point(id,cell))
  if not game.army_runtime.native.can_reach(at,at,.6):continue
  if not [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)].all(func(d):
   var other=game.model.world_point(Original.source_point(id,cell+d))
   return game.army_runtime.native.can_reach(at,other,.5)):continue
  return cell
 return candidates[0]
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 var at=Original.source_point(game.model.falan_floor,cell)
 game.player.position=game.model.world_point(at,.15);game.player.velocity=Vector3.ZERO
 game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
 game.world.sync(0.)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.impulse=0.;game.camera_rig.kick_strength=0.;game.camera_rig.kick_age=100.
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=screen_offset
 game.camera_rig.camera.fov=63.;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 game.camera_rig.reset_physics_interpolation();game.camera_rig.camera.reset_physics_interpolation()
 check(is_equal_approx(game.camera_rig.camera.fov,63.),"Normal camera FOV retained: "+label_)
 check(is_zero_approx(game.camera_rig.camera.rotation.z)and is_zero_approx(game.camera_rig.camera.h_offset)and is_zero_approx(game.camera_rig.camera.v_offset),"Fixed camera has no retained hit roll/offset: "+label_)
 if DisplayServer.get_name()=="headless":return
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 RenderingServer.force_draw();root.get_texture().get_image().save_png(SERVER_OUT+label_+".png")
 var camera:Camera3D=game.camera_rig.camera
 server_report.captures.append({"name":label_,"map":game.model.falan_floor,"source_cell":str(cell),"eye":str(camera.global_position),"rotation":str(camera.global_rotation),"fov":camera.fov,"offset":str(Vector2(camera.h_offset,camera.v_offset)),"character_screen_offset":screen_offset,"distance_setting":game.camera_rig.distance,"actual_distance":game.camera_rig.current_distance,"review_only_test_backdrop":true})
func direct_group(id:int,cell:Vector2i,key:String,zone:Dictionary):
 var source:Dictionary=Population.data().groups[key];var rng=RandomNumberGenerator.new();rng.seed=id
 var count_=source.members.size()
 var forced={"south-group:%s"%zone.id:[key],"south-count:%s"%zone.id:[count_]}
 forced["south-member:"+key]=[1,0]if count_==2 else[0]
 var party=Population.group(zone,forced,rng)
 check(party.size()==count_,"Direct source group retains its representative members: "+key)
 var record={"map":id,"zone":int(zone.id),"source_group":source.source_group,"source_enemy_ids":source.details.map(func(d):return d.enemy_id),"members":party,"generations":[]}
 for generation in 2:
  clear_enemies();game.model.waves.snow_group_ids.clear();game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
  var at=Original.source_point(id,cell);game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
  game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0;game.model.waves.snow_pending=[];game.model.waves.spawn_clock=0
  for i in 3:game.model.waves.tick(1.,game.player.position)
  check(game.model.enemies.is_empty(),"Standing still never starts an ambient group: "+key)
  game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
  game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  check(game.model.enemies.size()==party.size(),"Normal native dispatch creates the direct source group: "+key)
  var handles=[];var seen=[]
  for enemy in game.model.enemies.values():
   var handle:int=game.army_runtime.handles.get(enemy.id,0);handles.append(handle)
   check(handle!=0 and int(enemy.route_encounter)==int(zone.id)and int(game.army_runtime.unit_state(handle).pose_row)==int(enemy.skin),"One native handle/atlas row/source zone per member: "+key)
   seen.append([int(enemy.skin),int(enemy.level)])
  var expected=party.map(func(m):return[int(Population.data().species[m[0]].skin),int(m[1])])
  check(seen==expected,"Source species and25–27level range reach native presentation: "+key)
  if generation==0:await take_view("%d-group-%s"%[id,source.source_group],cell,PI*.5)
  game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
  game.tuning.invincible=false;game.player.invuln=0.;game.player.max_hp=10000.;game.player.hp=10000.;game.player.model.clear_kagerou_dodge()
  var ids=game.model.enemies.keys();var hp:float=game.player.hp
  for tick in 480:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.)
   game.army_runtime.integration_tick(1./60.)
  var contacts=game.army_runtime.event_log.filter(func(e):return e.kind=="external_damage"and e.external_kind==0 and e.source_id in ids)
  check(ids.all(func(enemy_id):return contacts.any(func(e):return e.source_id==enemy_id)),"Every source member emits ordinary native contact: "+key)
  check(game.player.hp<hp,"Ordinary native contact damages the live hero: "+key)
  for handle in handles:game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
  game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  check(game.model.enemies.is_empty(),"Existing death delivery cleans the complete group: "+key)
  check(handles.all(func(h):return not game.army_runtime.apply_hit(h,{"amount":1.}).accepted),"Retired native handles reject stale hits before reuse: "+key)
  record.generations.append({"generation":generation,"native_members":seen,"contacts":contacts.size(),"player_damaged":game.player.hp<hp,"cleaned":game.model.enemies.is_empty()})
 server_report.groups.append(record)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-server-map-review-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));Original.Art.load_sokia_server();var flags={}
 for id in Original.Art.SOKIA_SERVER_IDS:
  var source:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=source.sokia_visual_only;source.sokia_visual_only=false
 var ordinary_only="--ordinary-only"in OS.get_cmdline_user_args()
 var repair_only="--floor-repair-only"in OS.get_cmdline_user_args()
 var ids=[13509,13512]if ordinary_only else[5005,15549,15556,15560,15562]if repair_only else Original.Art.SOKIA_SERVER_IDS
 if repair_only:ids=ids+ids.duplicate()
 var reviewed={}
 for id in ids:
  var returning=reviewed.has(id);reviewed[id]=true
  print("SOKIA_SERVER_REVIEW_ENTER ",id)
  var candidates=candidate_cells(id);check(not candidates.is_empty(),"Source has an ordinary ground study point: "+str(id))
  if candidates.is_empty():continue
  var previous_features=weakref(game.world.map_features)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Original.source_point(id,candidates[0]),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  check(previous_features.get_ref()==null,"Previous map owner retires its scene before reuse: "+str(id))
  game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  # Study prepared source scenery independently of unrelated RNG loot overlays.
  game.exploration_loot.clear();clear_enemies();game.model.waves.spawned=2
  var cell=clear_cell(id,candidates);var point=Original.source_point(id,cell)
  check(game.world.map_features.get_meta("recovered_source_map")==id,"Existing map owner builds source layout: "+str(id))
  check(Original.Art.pending_page_uploads.is_empty(),"Normal map owner finishes pending source uploads: "+str(id))
  check(Population.encounters_own(game.model),"Source-specific dispatch prevents a generic ambient pool: "+str(id))
  var zone=Population.zone_at(id,cell)
  check(not zone.is_empty()if id in Population.SERVER_ENCOUNTERS else zone.is_empty(),"Ambient table presence/absence stays map-specific: "+str(id))
  server_report.maps.append({"id":id,"study_cell":str(cell),"size":str(Original.state(id).size),"source_flags_available":false,"fixed_ports":game.model.get_meta("falan_links",[]),"source_assessment":Population.server_data().map_assessment[str(id)],"overlay_qualification":"Generic RNG loot cleared for source-art study; source NPC/event restoration is assessed separately. Blocked background100 uses the existing15525/15526 visual-void policy; raw source layers/walk bits are retained."})
  var view_prefix=str(id)+("-finalized-return"if returning else"-finalized-first"if repair_only else"")
  await take_view(view_prefix+"-normal",cell)
  await take_view(view_prefix+"-reverse-normal",cell,PI)
  if repair_only and id==5005 and not returning:await take_view("5005-finalized-house-front",Vector2i(17,21),0.,.1)
  if id in Population.SERVER_ENCOUNTERS:
   check(game.model.waves.patrol_source==preload("res://scripts/forest/crowd/east_region_sprites.gd"),"Existing East bank supplies both exact source actors: "+str(id))
   var bank=Population.bank(game.model);var mesh:QuadMesh=bank.make_mesh()
   var wanted:Array=mesh.get_meta("prepared_pages").duplicate();var other=0
   while other in wanted:other+=1
   preload("res://scripts/forest/crowd/hound_sprites.gd").prepare_pages(bank.ROOT,bank.motions(),[other])
   check(mesh.get_meta("prepared_pages")==[other],"Another East owner can select its own source page table")
   check(Population.bank(game.model)==bank and mesh.get_meta("prepared_pages")==wanted,"Returning restores every source page after another East selection: "+str(id))
   var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
   check(game.army_runtime.native.configure_kits(kits),"Existing native cue/stride contract accepts the reused actors: "+str(id))
   for choice in zone.groups:await direct_group(id,cell,str(choice[0]),zone)
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Direct review leaves saved adventure data unchanged")
 server_report.checks=checks;server_report.failures=errors
 server_report.limitations=["Synthetic client flags are not original server flag evidence.","Per-map source groups/levels/weights are applied through the existing native adaptation; original server count/stat/probability-ramp behavior remains separately unverified.","Camera-only scenery review temporarily enables prepared layouts and clears RNG overlays. It does not activate unknown quest branches or establish complete NPC/event recovery."]
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(SERVER_OUT+"review-"+mode+("-floor-finalized"if repair_only else"")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(server_report,"  ")+"\n");file.close()
 print("SOKIA_SERVER_REVIEW_RESULT maps=",server_report.maps.size()," groups=",server_report.groups.size()," checks=",checks," failures=",errors," captures=",server_report.captures.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
