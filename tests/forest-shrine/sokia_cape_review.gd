extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Direct source groups use existing native dispatch; fixtures do not grind rare outcomes.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
const Regional=preload("res://scripts/forest/forest_university_region.gd")
const Cape=preload("res://scripts/forest/forest_sokia_cape.gd")
const CapeArt=preload("res://scripts/forest/forest_sokia_cape_art.gd")
const CAPE_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape caves/"
var cape_report={"floors":[],"groups":[],"cameras":[],"setup":[],"limits":["Original procedural topology is unavailable; existing room-graph geometry is adapted.","CDungeonReader per-floor levels are a recovered reference-generator interpretation, not verified original server execution.","Native real-time party count/rate/formation/combat remain qualified separately from source membership.","Camera stations are direct fixture placements in the same source walk-bit component; they do not prove live movement through an active formation.","Setup wall time and resource counters are observations from this fixture, not gameplay FPS or smoothness measurements."]}
func _initialize():
 create_timer(900).timeout.connect(func():printerr("SOKIA_CAPE_TIMEOUT");quit(1))
 run.call_deferred()
func gate_contracts():
 var data:Dictionary=Population.cape_data();var actor:Dictionary=data.actors["5243"]
 var context={"items":{},"gold":0,"level":100,"group":1,"seed":341,"external":{},"bags":{},"refills":{},"now":1000000.,"hp":100.,"max_hp":100.}
 var program:Dictionary=data.runtime_scripts[actor.script]
 var session=Events.begin_context(actor,program,context)
 check(session.status=="blocked" and "itemspace" in session.blocker.reason,"Unknown original inventory capacity never grants the source gate")
 context.external.itemspace=0
 session=Events.begin_context(actor,program,context)
 check(session.status=="window" and session.pending.message==21117 and not session.has("destination"),"An explicitly full pure source context retains the original denial")
 context.external.itemspace=1
 session=Events.begin_context(actor,program,context)
 check(session.status=="battle" and session.battle.split("|",true)[9]=="12019","No-item princess branch retains original encounter12019")
 Events.set_item(context.items,18599,1)
 session=Events.begin_context(actor,program,context)
 var choices=[]
 for i in 20:
  if session.status!="window":break
  var answer="YES" if "YES" in session.pending.choices else "NEXT" if "NEXT" in session.pending.choices else "OK"
  choices.append(answer);Events.choose_context(session,answer)
 check(session.status=="warp" and session.destination==[0,15525,21,6],"Original princess confirmations warp across the native barrier")
 check(Events.item_count(session.context.items,18599)==0 and Events.item_count(session.context.items,18600)==1,"Exact original18599 to18600 exchange")
 cape_report.princess_gate={"confirmations":choices,"status":session.status,"landing":session.get("destination",[]),"local_branch_fixture":"Only this pure gate test seeds18599; full15524/15528/15529 quest acquisition is still required.","production_itemspace":actor.itemspace_contract}
func run():
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPE_OUT))
 gate_contracts()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-cape-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var generated=Original.generated()
 var fit_only="--cape-visual-fit" in OS.get_cmdline_user_args()
 cape_report.scope="Fresh first305 floor and both source gates after visual/readback correction" if fit_only else "Both source branches, representative floors and both gates"
 for key in (["cape_descent"] if fit_only else ["cape_descent","cape_ascent"]):
  var logic_start=Time.get_ticks_usec()
  generated.box_count(generated.floor_id(key,1),41829558)
  cape_report.setup.append({"branch":key,"logical_ten_floor_allocation_ms":(Time.get_ticks_usec()-logic_start)/1000.,"state_count":Original.states.size(),"box_allocation_cache_entries":generated.box_allocations.size()})
  var sample_floors=[1] if fit_only else [1,10]
  if not fit_only and not sample_floors.any(func(n):return generated.box_count(generated.floor_id(key,n),41829558)>0):
   for n in range(2,10):
    if generated.box_count(generated.floor_id(key,n),41829558)>0:sample_floors.append(n);break
  for n in sample_floors:
   var id:int=generated.floor_id(key,n);var layout:Dictionary=Tour.Indoor.layout(id);layout.seed=41829558
   var at:Vector2=generated.landing(id,41829558,true)
   var entry_start=Time.get_ticks_usec()
   Tour.travel(game,layout,{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
   for i in 4:await physics_frame
   var entry_ms=(Time.get_ticks_usec()-entry_start)/1000.
   game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
   game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
   game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
   game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
   clear_enemies();game.model.waves.spawned=2
   var row:Dictionary=Original.state(id,game.model.seed_value)
   var ground_batches=game.world.map_features.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.get_meta("original_ground_batch",false))
   check(not ground_batches.is_empty() and ground_batches.all(func(node):return node.mesh.get_surface_count()>0 and node.mesh.surface_get_array_len(0)>0),"Original floor batches contain source vertices "+str(id))
   check(Population.encounters_own(game.model) and game.model.waves.patrol_source==Population.bank(game.model),"Existing source/native encounter ownership "+str(id))
   check(game.world.map_features.get_meta("cape_generated_wall_paint",{}).get("rgba_sha256","")==CapeArt.data().generated_rock_paint.rgba_sha256,"Adapted walls reuse the adjacent original brown cave-family paint "+str(id))
   check(game.model.waves.patrol_source==preload("res://scripts/forest/crowd/sokia_region_sprites.gd") if key=="cape_descent" else game.model.waves.patrol_source==preload("res://scripts/forest/crowd/falan_frontier_sprites.gd"),"Reuses existing matching prepared actor bank "+str(id))
   var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
   check(game.army_runtime.native.configure_kits(kits),"Original native contacts and timelines configure "+str(id))
   var loot=game.exploration_loot
   var chests=loot.slots.filter(func(slot):return slot.active and slot.chest)
   check(chests.size()==generated.box_count(id,game.model.seed_value),"Existing loot owner realizes the whole-branch allocation "+str(id))
   check(game.model.get_meta("falan_links",[]).size()==2,"Exactly two existing floor stair links "+str(id))
   var center=room_cell(row)
   check(center!=Vector2i(-1,-1),"Representative open native room exists "+str(id))
   if center==Vector2i(-1,-1):continue
   await camera("%d-floor-%d-normal"%[generated.SPECS[key].config,n],id,center,Vector2.UP)
   var zone:Dictionary=Population.zone_at(id,center)
   var choices:Array=zone.groups if n==1 else [zone.groups[0]]
   for choice in choices:
    var gid:String=choice[0];var source:Dictionary=Population.data().groups[gid]
    var rng=RandomNumberGenerator.new();rng.seed=341
    var force={"south-group:%s"%zone.id:[gid],"south-count:%s"%zone.id:[2]}
    force["south-member:"+gid]=[1,0] if source.members.size()==2 else [0,0]
    var party:Array=Population.group(zone,force,rng)
    check(party.size()==2,"Direct representative source group "+gid)
    for generation in 2:
     clear_enemies();game.model.waves.snow_group_ids.clear()
     var before_counts=resource_counts()
     game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
     var p=Original.point(id,center,game.model.seed_value)
     game.player.position=game.model.world_point(p,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
     game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0.;game.model.waves.spawn_clock=0
     game.model.waves.snow_pending=party.duplicate(true)
     game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
     check(game.model.enemies.size()==party.size(),"Normal native dispatch spawns the complete source group "+gid)
     var ids=game.model.enemies.keys();var handles=[];var appearances=[]
     for enemy in game.model.enemies.values():
      handles.append(game.army_runtime.handles.get(enemy.id,0));appearances.append(int(Population.data().species[party[appearances.size()][0]].id))
      check(int(enemy.level)==int(zone.levels[0]) and int(enemy.route_encounter)==id,"Source floor level and route tag "+gid)
     if generation==0 and n==1:
      var label_=str(generated.SPECS[key].config)+"-"+gid.replace(":","-")
      await camera(label_+"-fight",id,center,Vector2.UP)
      var station=readable_station(id,[center+Vector2i.DOWN*2,center+Vector2i.DOWN,center+Vector2i.LEFT*2])
      await camera(label_+"-readable",id,station,Vector2.UP)
     # Camera stations are fixture placements; prove contacts at the actual source encounter trigger.
     game.player.position=game.model.world_point(Original.point(id,center,game.model.seed_value),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
     game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
     game.tuning.invincible=false;game.player.invuln=0.;game.player.max_hp=10000.;game.player.hp=game.player.max_hp;game.player.model.clear_kagerou_dodge()
     var hp:float=game.player.hp
     for tick in 600:
      game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
     var contacts=game.army_runtime.event_log.filter(func(e):return e.kind=="external_damage" and e.external_kind==0 and e.source_id in ids)
     check(ids.all(func(enemy_id):return contacts.any(func(event):return event.source_id==enemy_id)),"Each native member delivers original contact events "+gid)
     check(game.player.hp<hp,"Ordinary native player damage "+gid)
     for handle in handles:game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
     game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
     check(game.model.enemies.is_empty(),"Native lifecycle cleans the complete group "+gid)
     check(handles.all(func(handle):return not game.army_runtime.apply_hit(handle,{"amount":1.}).accepted),"Retired native handles reject stale hits "+gid)
     for i in 2:await process_frame
     var after_counts=resource_counts()
     check(after_counts.native_handles==before_counts.native_handles,"Native handle count returns to the same floor baseline "+gid)
     cape_report.groups.append({"floor":id,"source_group":source.source_group,"level":zone.levels,"appearance_ids":appearances,"generation":generation,"contacts":contacts.size(),"cleaned":game.model.enemies.is_empty(),"before":before_counts,"after":after_counts})
   cape_report.floors.append({"floor":id,"config":generated.SPECS[key].config,"number":n,"chests":chests.size(),"levels":zone.levels,"source_topology":false,"world_entry_ms_including_four_physics_frames":entry_ms})
 await scripted_fights()
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Direct fixture preserves existing adventure state")
 cape_report.checks=checks;cape_report.failures=errors;cape_report.goal_complete=false
 var mode="headless" if DisplayServer.get_name()=="headless" else "rendered"
 var file=FileAccess.open(CAPE_OUT+"verification-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(cape_report,"  "));file.close()
 print("SOKIA_CAPE_REVIEW_RESULT checks=",checks," failures=",errors," groups=",cape_report.groups.size()," cameras=",cape_report.cameras.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func scripted_fights():
 cape_report.scripted=[]
 var previous_external:Dictionary=get_meta("east_source_external_state",{}).duplicate(true)
 var without_capacity=previous_external.duplicate(true);without_capacity.erase("itemspace")
 set_meta("east_source_external_state",without_capacity)
 for npc in ["5243","5305"]:
  var actor:Dictionary=Population.cape_data().actors[npc];var id:int=actor.source
  var cell=Vector2i(16,9) if npc=="5243" else Vector2i(43,8)
  var layout:Dictionary=Tour.Indoor.layout(id);layout.seed=41829558
  Tour.travel(game,layout,{"arrival":Original.source_point(id,cell),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  clear_enemies();game.model.waves.spawned=2
  var gate_sprites=game.world.map_features.find_children("*","Sprite3D",true,false).filter(func(sprite):return str(sprite.get_meta("npc_record",{}).get("id",""))==npc)
  check(gate_sprites.size()==1,"One original source gate sprite "+npc)
  if gate_sprites.size()==1:
   var sprite:Sprite3D=gate_sprites[0];var record:Dictionary=sprite.get_meta("npc_record");var rect:Rect2=sprite.texture.region
   check(is_equal_approx(sprite.pixel_size,.043),"Original field NPC pixels and scale preserved "+npc)
   check(is_zero_approx((sprite.offset.y+rect.size.y*.5-float(record.map_body_foot_row))*sprite.pixel_size),"Measured original body feet meet the unchanged source ground anchor "+npc)
   check(record.map_raw_origin==Population.coast_data().art[record.token].origin,"Original archived origin metadata retained separately "+npc)
  if id==15525:
   var physical=physical_snapshot()
   var visual=game.world.map_features.find_child("SokiaCapeSourceVisuals",true,false)
   check(visual!=null and visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Local source recess creates no physical/navigation owner")
   if visual!=null:visual.get_parent().remove_child(visual);visual.free()
   var native_art=Original.Art.new();var row:Dictionary=Original.state(15525);native_art.load_map(Original.path_for(15525),row.raw,row.size)
   CapeArt.build(game.world.map_features,native_art.placements,row)
   check(physical_snapshot()==physical,"Rebuilding source rock/recess preserves every native bit, height, static shape and gate")
   check(game.world.map_features.get_meta("sokia_cape_source_wall_anchors",[]).size()==138,"All138 original fixed wall anchors retained")
   if DisplayServer.get_name()!="headless":await camera("15525-source-gate-readable",id,readable_station(id,[Vector2i(16,12),Vector2i(15,12)]),Vector2.UP)
  game.explorer_npcs.prepare()
  var source_cell=Vector2i(actor.cell[0],actor.cell[1]);var source:Dictionary=Original.state(id)
  for offset in [Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP,Vector2i.RIGHT,Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
   var candidate=source_cell+offset
   if not Original.open(source.bits,source.size,candidate):continue
   game.player.position=game.model.world_point(Original.source_point(id,candidate),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
   if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+npc:cell=candidate;break
  if game.explorer_npcs.nearest.get("record",{}).get("id","")!="source:"+npc:
   printerr("CAPE_F_TRIGGER_DIAGNOSTIC ",{"npc":npc,"player":game.player.position,"hp":game.player.hp,"playing":game.playing,"phase":game.model.phase,"available":game.explorer_npcs.available(),"actors":game.explorer_npcs.actors.map(func(entry):return {"id":entry.record.id,"at":entry.node.global_position,"visible":entry.node.is_visible_in_tree()}),"nearest":game.explorer_npcs.nearest})
  check(game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+npc,"Original source actor has a reachable F trigger "+npc)
  if npc=="5243":await camera("15525-source-gate-normal",id,cell,Vector2.UP)
  var input=InputEventKey.new();input.physical_keycode=KEY_F;input.pressed=true;game._input(input)
  check(game.explorer_npcs.selected.get("id","")=="source:"+npc,"Ordinary F interaction selects source gate "+npc)
  game.explorer_npcs.finish()
  var key=Regional.active(self,id,"interior")
  check(not key.is_empty(),"Original source script starts existing native scripted-fight owner "+npc)
  if key.is_empty():continue
  var battle:Dictionary=get_meta(Regional.BATTLES,{})[key]
  var expected=1 if npc=="5243" else 5
  check(battle.members.size()==expected,"Exact mandatory source boss formation "+npc)
  if npc=="5305":
   var counts={}
   for member in battle.members:counts[member.enemy]=int(counts.get(member.enemy,0))+1
   check(counts=={"12121":1,"12119":2,"12120":2},"Lorens retains one boss and both two-soldier source variants")
  game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  check(game.model.enemies.size()==expected,"Complete source boss group enters normal native handles "+npc)
  var handles=[];var ids=game.model.enemies.keys();var contact_members={}
  for enemy in game.model.enemies.values():
   handles.append(game.army_runtime.handles.get(enemy.id,0))
   var member:Dictionary=battle.members[int(enemy.university_slot)%1000]
   contact_members[enemy.id]={"source_enemy":member.enemy,"appearance":Cape.data().species[int(member.species)].id}
   check(enemy.get("university_battle","")==key,"Scripted source member stays in existing battle lifecycle "+npc)
  await camera("gate-"+npc+"-native-fight",id,cell,Vector2.UP)
  var options=[Vector2i(39,12),Vector2i(40,11),Vector2i(41,10)] if npc=="5305" else [Vector2i(16,12),Vector2i(15,12),Vector2i(16,11)]
  var station=readable_station(id,options)
  await camera("gate-"+npc+"-readable",id,station,Vector2.RIGHT if npc=="5305" else Vector2.UP)
  game.player.position=game.model.world_point(Original.source_point(id,cell),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
  game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
  game.tuning.invincible=false;game.player.invuln=0.;game.player.max_hp=100000.;game.player.hp=game.player.max_hp;game.player.model.clear_kagerou_dodge()
  for tick in 900:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
  var contacts=game.army_runtime.event_log.filter(func(e):return e.kind=="external_damage" and e.external_kind==0 and e.source_id in ids)
  for member_id in contact_members:contact_members[member_id].contacts=contacts.filter(func(event):return event.source_id==member_id).size()
  check(ids.all(func(enemy_id):return contacts.any(func(event):return event.source_id==enemy_id)),"Every scripted member produces original native contacts "+npc)
  for attempt in 20:
   for handle in handles:game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
   game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
   if game.model.enemies.is_empty():break
   game.army_runtime.integration_tick(.1)
  check(game.model.enemies.is_empty() and get_meta(Regional.BATTLES,{})[key].complete,"Existing native deaths complete source gate fight "+npc)
  var spec:Dictionary=Cape.specification(key)
  game.model.waves.tick(1.,game.player.position)
  for i in 6:await physics_frame
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  var actual=Population.source_cell(game.model,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)
  check(actual==Vector2i(spec.win[1],spec.win[2]),"Original victory warp cell "+npc)
  check(game.model.falan_area==("ghana_road" if npc=="5243" else "interior") and game.model.falan_floor==(0 if npc=="5243" else 15526),"Original victory map/owner "+npc)
  if npc=="5305":await camera("15526-original-win-landing",15526,Vector2i(47,7),Vector2.RIGHT)
  cape_report.scripted.append({"npc":npc,"encounter":spec.encounter,"formation":battle.members,"native_contacts":contacts.size(),"contact_members":contact_members,"contact_test_cell":[cell.x,cell.y],"trigger_cell":[cell.x,cell.y],"win":spec.win,"actual_cell":[actual.x,actual.y],"fixture_itemspace":false,"production_itemspace":"Existing unbounded source-quest dictionary; original slot-limit parity unmodeled."})
 set_meta("east_source_external_state",previous_external)
func room_cell(row:Dictionary)->Vector2i:
 for y in range(6,row.size.y-6):
  for x in range(6,row.size.x-6):
   var cell=Vector2i(x,y);var clear=true
   for z in range(-3,4):
    for a in range(-3,4):clear=clear and Original.open(row.bits,row.size,cell+Vector2i(a,z))
   if clear:return cell
 return Vector2i(-1,-1)
func camera(label_:String,id:int,cell:Vector2i,toward:Vector2):
 if DisplayServer.get_name()=="headless":return
 var at=Original.point(id,cell,game.model.seed_value)
 game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
 game.army_runtime.native.step(.016);game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 game.camera_rig.yaw=atan2(-toward.x,-toward.y);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 for i in 4:await process_frame
 var view:Camera3D=game.camera_rig.camera
 check(is_equal_approx(view.fov,63.),"Fixed normal gameplay camera "+label_)
 cape_report.cameras.append({"name":label_,"floor":id,"cell":[cell.x,cell.y],"eye":var_to_str(view.global_position),"rotation":var_to_str(view.global_rotation),"fov":view.fov,"seed":game.model.seed_value})
 var shot:Image;var valid=false;var attempts=0
 for attempt in 3:
  attempts=attempt+1;RenderingServer.force_draw();shot=root.get_texture().get_image();valid=capture_ready(shot)
  if valid:break
  var rejected=CAPE_OUT+"Rejected captures/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rejected))
  if shot!=null and not shot.is_empty():shot.save_png(rejected+label_+"-attempt-%d.png"%attempt)
  for i in 2:await process_frame
 check(valid,"Nonblank captured gameplay image "+label_)
 cape_report.cameras[-1].capture_attempts=attempts;cape_report.cameras[-1].nonblank=valid
 if shot!=null and not shot.is_empty():shot.save_png(CAPE_OUT+label_+".png")
func capture_ready(shot:Image)->bool:
 if shot==null or shot.is_empty():return false
 var samples=0
 for y in range(0,shot.get_height(),maxi(1,shot.get_height()/20)):
  for x in range(0,shot.get_width(),maxi(1,shot.get_width()/32)):
   var color=shot.get_pixel(x,y)
   if maxf(color.r,maxf(color.g,color.b))>.015:samples+=1
 return samples>=8
func resource_counts()->Dictionary:
 return {"native_handles":game.army_runtime.handles.size(),"enemies":game.model.enemies.size(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"texture_memory":int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))}
func readable_station(id:int,candidates:Array)->Vector2i:
 var row:Dictionary=Original.state(id,game.model.seed_value)
 var start=Vector2i(((Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale-row.origin)/3.).round())
 var seen={start:true};var queue=[start];var cursor=0
 while cursor<queue.size():
  var at:Vector2i=queue[cursor];cursor+=1
  for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next:Vector2i=at+step
   if not seen.has(next) and Original.open(row.bits,row.size,next):seen[next]=true;queue.append(next)
 for cell:Vector2i in candidates:
  if Original.open(row.bits,row.size,cell) and seen.has(cell):
   check(true,"Readable camera station remains in the same source walk-bit component")
   return cell
 check(false,"A readable source-connected camera station is required")
 return start
func physical_snapshot()->String:
 var row:Dictionary=Original.state(game.model.falan_floor,game.model.seed_value);var heights=PackedFloat32Array();var shapes=[]
 for y in row.size.y:
  for x in row.size.x:
   var point:Vector2=Original.point(game.model.falan_floor,Vector2i(x,y),game.model.seed_value);heights.append(game.model.surface_height(point.x,point.y))
 for node in game.world.find_children("*","CollisionShape3D",true,false):
  var payload:Variant=node.shape.size if node.shape is BoxShape3D else node.shape.get_faces() if node.shape is ConcavePolygonShape3D else node.shape.get_instance_id() if node.shape!=null else null
  shapes.append([node.get_instance_id(),node.transform,payload])
 return var_to_bytes([row.raw,row.bits,heights,shapes,game.model.scenery_obstacles,game.model.get_meta("falan_links",[])]).hex_encode().sha256_text()
