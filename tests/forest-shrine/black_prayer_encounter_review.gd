extends "res://tests/forest-shrine/sokia_cape_review.gd"
## Direct source-group fixtures reuse the live movement/native owner; no rare-spawn grinding.
const NativePrayer=preload("res://scripts/forest/forest_black_prayer.gd")
const PRAYER_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer encounters/"
var prayer_report={"floors":[],"groups":[],"cameras":[],"limits":[]}
func _initialize():
 create_timer(900).timeout.connect(func():printerr("BLACK_PRAYER_NATIVE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRAYER_OUT))
 prayer_report.limits=NativePrayer.source().limits.duplicate()
 prayer_report.limits.append("Camera and direct group placement are fixtures, not proof of original random timing or natural Ruby quest access.")
 prayer_report.limits.append("Ruby's source StandEnemy trigger, NPC6305 item gate and victory16509/return scripts remain separate required restoration work.")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-black-prayer-encounters-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 var old_slain=get_meta(NativePrayer.SLAIN,{}).duplicate(true);var ruby_slain=get_meta(Ruby.SLAIN,{}).duplicate(true)
 for id:int in NativePrayer.FLOORS:await prayer_floor(id)
 check(get_meta(NativePrayer.SLAIN,{})==old_slain,"Source movement fights preserve old static-slot save compatibility")
 check(get_meta(Ruby.SLAIN,{})==ruby_slain,"Ordinary source deaths never unlock Ruby's reward rooms")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Direct source fights preserve saved adventure state")
 prayer_report.checks=checks;prayer_report.failures=errors;prayer_report.goal_complete=false
 var mode="headless" if DisplayServer.get_name()=="headless" else "rendered"
 var file=FileAccess.open(PRAYER_OUT+"native-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(prayer_report,"  "));file.close()
 print("BLACK_PRAYER_NATIVE_RESULT checks=",checks," failures=",errors," groups=",prayer_report.groups.size()," cameras=",prayer_report.cameras.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func prayer_floor(id:int):
 var seed_=41829558;var warp=NativePrayer.stairs(id,seed_)
 var layout:Dictionary=Tour.Indoor.layout(id);layout.seed=seed_
 var started=Time.get_ticks_usec()
 Tour.travel(game,layout,{"arrival":NativePrayer.point(warp[0]+Vector2i.UP),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 var entry_ms=(Time.get_ticks_usec()-started)/1000.
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 clear_enemies();game.model.waves.spawned=2;game.model.waves.dungeon_boss_id=0
 var army=game.army_runtime
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 check(Population.encounters_own(game.model) and game.model.waves.patrol_source==Ruby,"Source/native Ruby bank owns logical floor "+str(id))
 check(kits.cave_sprites==Ruby and not kits.ruby_boss,"Ordinary members retain Ruby bank without boss abilities "+str(id))
 check(army.native.configure_kits(kits),"Existing six-action28-column native timelines configure "+str(id))
 check(game.model.waves.route_state.bits==NativePrayer.walk_mask(id,seed_),"Native route bits retain existing seeded geometry "+str(id))
 var expected_links=NativePrayer.links(id,seed_);var actual_links=game.model.get_meta("falan_links",[])
 check(actual_links.size()==expected_links.size() and range(expected_links.size()).all(func(i):return expected_links[i].keys().all(func(key):return actual_links[i].get(key)==expected_links[i][key])),"All existing stair/endpoints remain exact "+str(id))
 game.model.waves.snow_last=game.player.position/game.model.falan_scale
 for i in 4:game.model.waves.tick(1.,game.player.position)
 check(game.model.enemies.is_empty(),"Stationary stair arrival does not create a static96-actor pool "+str(id))
 var center=prayer_room()
 check(center!=Vector2i(-1,-1),"A room supports a complete native group and normal camera "+str(id))
 if center==Vector2i(-1,-1):return
 await prayer_camera(str(id)+"-normal",id,center)
 var zone:Dictionary=Population.zone_at(id,center)
 var choices:Array=zone.groups if id==NativePrayer.FLOORS[0] else [zone.groups[0]]
 var tested=[]
 for choice in choices:
  var gid:String=choice[0]
  for generation in 2:
   await prayer_group(id,center,zone,gid,2,generation)
  tested.append(gid)
 if id==NativePrayer.FLOORS.back():await prayer_group(id,center,zone,"prayer:15006",6,2)
 prayer_report.floors.append({"runtime_floor":id,"config":301,"floor":NativePrayer.FLOORS.find(id)+1,"level":zone.levels,"groups":tested,"world_entry_ms_including_four_physics_frames":entry_ms,"original_generated_topology":false,"native_bits_sha256":NativePrayer.walk_mask(id,seed_).hex_encode().sha256_text()})
func prayer_room()->Vector2i:
 var candidates=[]
 for y in 4:
  for x in 4:
   var cell=NativePrayer.room_center(Vector2i(x,y));var clear=0
   for dy in range(-4,5):
    for dx in range(-4,5):
     if Tour.Indoor.open_cell(game.model.waves.route_state.bits,NativePrayer.SIZE,cell.x+dx,cell.y+dy):clear+=1
   candidates.append([cell,clear])
 candidates.sort_custom(func(a,b):return a[1]>b[1])
 for candidate in candidates:
  var cell:Vector2i=candidate[0]
  var p=game.model.world_point(NativePrayer.point(cell),.15)
  if not game.army_runtime.native.can_reach(p,p,1.25):continue
  prayer_camera_position(p)
  if DisplayServer.get_name()=="headless" or game.camera_rig.current_distance>=6.:return cell
 return Vector2i(-1,-1)
func prayer_group(id:int,cell:Vector2i,zone:Dictionary,gid:String,count_:int,generation:int):
 clear_enemies();game.model.waves.snow_group_ids.clear()
 game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
 var before=resource_counts();var rng=RandomNumberGenerator.new();rng.seed=341
 var one:Dictionary=zone.duplicate(true);one.groups=[[gid,1]]
 var force={};force["south-count:%s:%s"%[zone.id,gid]]=[count_]
 force["south-member:"+gid]=[1,0] if gid=="prayer:15006" else [0,0]
 var party:Array=Population.group(one,force,rng)
 check(party.size()==count_,"Direct source member count "+gid+" floor"+str(id))
 var point=game.model.world_point(NativePrayer.point(cell),.15)
 prayer_camera_position(point)
 game.model.waves.snow_last=point/game.model.falan_scale;game.model.waves.snow_distance=0.;game.model.waves.spawn_clock=0
 game.model.waves.snow_pending=party.duplicate(true)
 game.model.waves.tick(1.,point);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 var ids=game.model.enemies.keys();var handles=[];var appearances=[]
 check(ids.size()==party.size(),"Existing movement dispatcher realizes complete source party "+gid+" floor"+str(id))
 for enemy in game.model.enemies.values():
  handles.append(game.army_runtime.handles.get(enemy.id,0));appearances.append(101600 if int(enemy.skin)==1 else 101121)
  check(enemy.get("source_dungeon_config")==301 and enemy.get("source_dungeon_floor")==NativePrayer.FLOORS.find(id)+1 and enemy.get("source_encounter")==15001,"Exact source configuration/floor/encounter tags")
  check(enemy.get("source_group")==gid and enemy.get("source_enemy") in ["15003","15004"] and int(enemy.level)==int(zone.levels[0]),"Original source member/group and qualified floor level")
  check(int(enemy.max_hp)==(400 if int(enemy.skin)==1 else 300)*int(enemy.level),"Retained blade/ghost native HP-per-level fit")
 if generation==0 and id==NativePrayer.FLOORS[0] or count_==6:await prayer_camera(str(id)+"-"+gid.replace(":","-")+"-count"+str(count_),id,cell)
 prayer_camera_position(point)
 var army=game.army_runtime;army.record_events=true;army.compact_scene_events=false;army.event_log.clear()
 game.tuning.invincible=false;game.player.max_hp=10000.;game.player.hp=10000.;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
 for tick in 600:
  game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);army.integration_tick(1./60.)
 var contacts=army.event_log.filter(func(event):return event.kind=="external_damage" and event.external_kind==0 and event.source_id in ids)
 var cues=army.event_log.filter(func(event):return event.kind=="status" and event.source_id in ids and event.action_index==606)
 check(not ids.is_empty() and ids.all(func(enemy_id):return contacts.any(func(event):return event.source_id==enemy_id)),"Each source member makes native contact "+gid+" floor"+str(id))
 check(not cues.is_empty(),"Existing original attack audio cues reach presentation "+gid)
 check(not army.event_log.any(func(event):return event.source_id in ids and event.kind=="status" and Ruby.spell_action(int(event.get("action_index",0)))),"Ordinary source party never acquires Ruby boss spells")
 for attempt in 20:
  for handle in handles:
   army.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
  army.dispatch_events();army.sync_compatibility()
  if game.model.enemies.is_empty():break
  army.integration_tick(.1)
 check(game.model.enemies.is_empty(),"Native party death/cleanup completes "+gid)
 check(handles.all(func(handle):return not army.apply_hit(handle,{"amount":1.}).accepted),"Retired source-party handles reject stale hits")
 for i in 2:await process_frame
 var after=resource_counts()
 check(after.native_handles==before.native_handles,"Repeated generation returns handles to baseline")
 var contact_rows=[]
 for enemy_id in ids:contact_rows.append({"id":enemy_id,"contacts":contacts.filter(func(event):return event.source_id==enemy_id).size()})
 prayer_report.groups.append({"runtime_floor":id,"source_group":gid,"level":zone.levels,"appearance_ids":appearances,"generation":generation,"party_size":count_,"contacts":contact_rows,"audio_cues":cues.size(),"cleaned":game.model.enemies.is_empty(),"before":before,"after":after})
func prayer_camera_position(point:Vector3):
 game.player.show();game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation()
 game.player.velocity=Vector3.ZERO;game.player.invuln=0.
 game.camera_rig.yaw=0.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.camera.fov=63.;game.camera_rig.camera.rotation.z=0.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
func prayer_camera(label_:String,id:int,cell:Vector2i):
 if DisplayServer.get_name()=="headless":return
 prayer_camera_position(game.model.world_point(NativePrayer.point(cell),.15))
 game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 var view:Camera3D=game.camera_rig.camera
 check(is_equal_approx(view.fov,63.),"Fixed normal63degree gameplay camera "+label_)
 var shot:Image;var valid=false;var attempts=0
 for attempt in 3:
  attempts=attempt+1;RenderingServer.force_draw();shot=root.get_texture().get_image();valid=capture_ready(shot)
  if valid:break
  var rejected=PRAYER_OUT+"Rejected captures/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rejected))
  if shot!=null and not shot.is_empty():shot.save_png(rejected+label_+"-attempt-%d.png"%attempt)
  for i in 2:await process_frame
 check(valid,"Nonblank gameplay capture "+label_)
 if shot!=null and not shot.is_empty():shot.save_png(PRAYER_OUT+label_+".png")
 prayer_report.cameras.append({"name":label_,"runtime_floor":id,"cell":[cell.x,cell.y],"eye":var_to_str(view.global_position),"rotation":var_to_str(view.global_rotation),"fov":view.fov,"seed":game.model.seed_value,"capture_attempts":attempts,"nonblank":valid})
