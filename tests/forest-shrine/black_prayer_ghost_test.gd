extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Direct native art/contact checks; config301 floor indexes are known, original generated topology is not.
const GhostPrayer=preload("res://scripts/forest/forest_black_prayer.gd")
const GHOST_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer Ghost/"
const SourceQuest=preload("res://scripts/forest/forest_black_prayer_events.gd")
var ghost_report={"scope":"Existing Black Prayer ghost art correction and native reuse; config301 floor indexes known, original generated topology and encounter timing qualified","maps":[],"captures":[]}
var study_skin=2
var study_name="ghost"
var study_out=GHOST_OUT
func _initialize():
 create_timer(600).timeout.connect(func():printerr("BLACK_PRAYER_GHOST_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 if "--blade"in OS.get_cmdline_user_args():
  study_skin=1;study_name="blade";study_out="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer Blade/"
  ghost_report.scope="Coherent original2913 Blade art/native reuse; source placement and generated topology remain separately qualified"
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(study_out))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-black-prayer-ghost-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 game.player.set_auto_attack(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 for floor_ in [GhostPrayer.FLOORS[0],Ruby.ROOM]:await ghost_floor(floor_)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Direct ghost fights preserve saved adventure state")
 ghost_report.checks=checks;ghost_report.failures=errors
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(study_out+"native-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(ghost_report,"  "));file.close()
 print("BLACK_PRAYER_",study_name.to_upper(),"_RESULT maps=",ghost_report.maps.size()," checks=",checks," failures=",errors," captures=",ghost_report.captures.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func ghost_floor(floor_:int):
 var layout=Tour.Indoor.layout(floor_);layout.seed=41829558
 Tour.travel(game,layout,{"arrival":Tour.Indoor.safe_point(floor_,Vector2.ZERO),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 clear_enemies();game.model.waves.spawned=2;game.model.waves.dungeon_boss_id=0
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 check(kits.cave_sprites==Ruby and kits.ruby_boss==(floor_==Ruby.ROOM),"Existing Black Prayer owner keeps palace-only Ruby behavior "+str(floor_))
 check(game.army_runtime.native.configure_kits(kits),"Six-action28-column original cues configure native combat "+str(floor_))
 check(Ruby.motions().actions.map(func(a):return int(a))==[0,3,5,8,10,1] and Ruby.motions().variants.map(func(v):return int(v.id))==[100654,101600,101121],"Ruby, blade and ghost IDs/slots/action contract stay stable")
 check(int(Ruby.motions().variants[2].native_action_sources.get("3",-1))==1,"Transparent original run3 uses the declared offline original walk1 mapping")
 if floor_==Ruby.ROOM:
  await source_palace_party()
  return
 var plan=Tour.Indoor.floor_info(floor_);var size:Vector2i=plan[0]
 var bits=Tour.Indoor.walk_mask(floor_,size,plan[2].hex_decode(),game.model.seed_value)
 var anchors=[]
 for y in range(2,size.y-2):
  for x in range(2,size.x-2):
   if not Tour.Indoor.open_cell(bits,size,x,y):continue
   var at:Vector2=plan[1]+Vector2(x,y)*3.
   anchors.append(at)
 if floor_ in GhostPrayer.FLOORS:
  anchors=[]
  for y in 4:
   for x in 4:anchors.append(GhostPrayer.point(GhostPrayer.room_center(Vector2i(x,y))))
 anchors.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
 var pair=[]
 for at:Vector2 in anchors:
  var hero=game.model.world_point(at,.15);var enemy=game.model.world_point(at+Vector2(3.2,-2.),.15)
  if not game.army_runtime.native.can_reach(hero,enemy,1.25):continue
  ghost_camera(hero)
  if game.camera_rig.current_distance<6.:continue
  pair=[hero,enemy];break
 check(pair.size()==2,"Direct fixture finds clear native ground and normal camera clearance "+str(floor_))
 if pair.is_empty():return
 var row={"actor":study_name,"skin":study_skin,"appearance":int(Ruby.motions().variants[study_skin].id),"runtime_floor":floor_,"original_map_id":floor_ if floor_==Ruby.ROOM else null,"source_dungeon_config":301 if floor_ in GhostPrayer.FLOORS else null,"source_floor_number":GhostPrayer.FLOORS.find(floor_)+1 if floor_ in GhostPrayer.FLOORS else null,"original_generated_topology_verified":false,"hero":var_to_str(pair[0]),"enemy":var_to_str(pair[1]),"generations":[]}
 var army=game.army_runtime
 for generation in 3:
  clear_enemies();army.presentation_events.clear();game.crowd.army.presentation.clear()
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
  var cleared=game.crowd.army.presentation.counts()
  check(cleared.corpses==0 and cleared.labels==0 and cleared.effects==0,"Old corpse/label/effect pools are clear before "+study_name+" study")
  if generation==0 and DisplayServer.get_name()!="headless":await create_timer(.8).timeout
  game.player.show();game.player.max_hp=10000.;game.player.hp=game.player.max_hp;game.player.invuln=0.;game.player.model.clear_kagerou_dodge();game.respawn_left=0
  ghost_camera(pair[0]);game.tuning.invincible=false
  var enemy:Dictionary=game.model.waves.spawn_enemy(Roles.SLIME,pair[1],-1,study_skin)
  army.import_arrivals();army.sync_compatibility()
  var handle:int=army.handles.get(enemy.id,0)
  check(handle!=0 and int(army.unit_state(handle).pose_row)==study_skin,"Corrected original "+study_name+" imports through the existing native slot generation"+str(generation))
  if handle==0:continue
  var targets=army.external_targets()
  check(not army.blocked() and targets.targetable[0]==1 and targets.hp[0]>0 and targets.positions[0]==game.player.position,"Ordinary visible/alive hero is published before native contact")
  army.set_pose(handle,pair[1],-PI*.25)
  if generation==0:
   if study_skin==1:
    for direction in 8:
     army.set_pose(handle,pair[1],(1.-direction)*TAU/8.)
     await ghost_capture(floor_,"idle-direction-%d"%direction)
    army.set_pose(handle,pair[1],-PI*.25)
   await ghost_capture(floor_,"full-body")
  army.record_events=true;army.compact_scene_events=false;army.event_log.clear()
  var hp:float=game.player.hp
  for tick in 480:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.)
   army.integration_tick(1./60.)
   if generation==0 and tick in [48,96]:await ghost_capture(floor_,"native-tick-%03d"%tick)
  var contacts=army.event_log.filter(func(e):return e.kind=="external_damage"and e.source_id==enemy.id and e.external_kind==0)
  var cues=army.event_log.filter(func(e):return e.kind=="status"and e.source_id==enemy.id and e.action_index==606)
  check(not contacts.is_empty(),"Original "+study_name+" attack delivers native contacts generation"+str(generation))
  check(not cues.is_empty(),"Original "+study_name+" audio cue reaches existing presentation")
  var damaged:bool=game.player.hp<hp
  check(damaged,"Ordinary native contact damages the hero with normal accuracy/dodge")
  check(not army.event_log.any(func(e):return e.source_id==enemy.id and e.kind=="status"and Ruby.spell_action(int(e.get("action_index",0)))),study_name+" never acquires Ruby's boss spell repertoire")
  if contacts.is_empty():printerr("BLACK_PRAYER_GHOST_CONTACT_CONTEXT floor=",floor_," target=",targets," native=",army.unit_state(handle))
  army.apply_hit(handle,{"amount":1000000.,"accuracy":100.});army.dispatch_events();army.sync_compatibility()
  check(not army.handles.has(enemy.id) and game.model.enemies.is_empty(),"Ordinary native death retires "+study_name+" before pooled reuse")
  check(not army.apply_hit(handle,{"amount":1.}).accepted,"Retired "+study_name+" handle rejects stale hits")
  row.generations.append({"generation":generation,"native_contacts":contacts.size(),"native_audio_cues":cues.size(),"player_damaged":damaged,"cleaned":game.model.enemies.is_empty()})
 ghost_report.maps.append(row)
func source_palace_party():
 var army=game.army_runtime;var old_state=get_meta(SourceQuest.STATE)if has_meta(SourceQuest.STATE)else null;var old_slain=get_meta(Ruby.SLAIN)if has_meta(Ruby.SLAIN)else null
 game.explorer_npcs.prepare()
 var sprites=game.world.map_features.find_children("*","Sprite3D",true,false).filter(func(node):return node.get_meta("npc_record",{}).get("id","")=="81000")
 check(sprites.size()==1,"Actual source Ruby actor exists for palace representative fight")
 if sprites.size()!=1:return
 var at=Vector2(sprites[0].position.x,sprites[0].position.z);var found=false
 for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
  var point=game.model.world_point(at+offset*3.,.15)
  if not army.native.can_reach(point,point,.6):continue
  ghost_camera(point);game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:81000":found=true;break
 check(found,"Source party starts at a reachable ordinary F station")
 if not found:return
 var input_=InputEventKey.new();input_.physical_keycode=KEY_F;input_.pressed=true;game._input(input_)
 game.model.waves.tick(1.,game.player.position);army.import_arrivals();army.sync_compatibility()
 check(SourceQuest.active(game)and game.model.enemies.size()==10,"Actual F creates the original ten-member party")
 var members=game.model.enemies.values().filter(func(enemy):return int(enemy.skin)==study_skin)
 check(members.size()==(5 if study_skin==1 else 4),"Source party retains every "+study_name+" member")
 if members.is_empty():return
 var enemy:Dictionary=members[0];var handle:int=army.handles.get(enemy.id,0)
 var station=game.model.world_point(Tour.Indoor.floor_info(Ruby.ROOM)[1]+Vector2(24,22)*3.,.15)
 ghost_camera(station);game.player.max_hp=1000000.;game.player.hp=game.player.max_hp;game.player.invuln=0.;game.player.model.clear_kagerou_dodge();game.tuning.invincible=false
 army.record_events=true;army.compact_scene_events=false;army.event_log.clear()
 await ghost_capture(Ruby.ROOM,"source-F-party")
 for tick in 480:
  game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);army.integration_tick(1./60.)
  if tick==48:await ghost_capture(Ruby.ROOM,"source-native-tick-048")
 if not army.event_log.any(func(event):return event.kind=="external_damage"and event.source_id==enemy.id and event.external_kind==0):
  var point:Vector3=army.unit_state(handle).position
  for offset in [Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD]:
   var connected=point+offset*2.8
   if not army.native.can_reach(connected,point,.6):continue
   ghost_camera(connected)
   for tick in 600:
    game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);army.integration_tick(1./60.)
   break
 var contacts=army.event_log.filter(func(event):return event.kind=="external_damage"and event.source_id==enemy.id and event.external_kind==0)
 var cues=army.event_log.filter(func(event):return event.kind=="status"and event.source_id==enemy.id and event.action_index==606)
 check(not contacts.is_empty(),"Source-triggered palace "+study_name+" delivers normal native contacts")
 check(not cues.is_empty(),"Source-triggered palace "+study_name+" delivers original audio cues")
 ghost_report.maps.append({"runtime_floor":Ruby.ROOM,"actor":study_name,"skin":study_skin,"source_encounter":11007,"source_group":11009,"source_trigger":"Actual F on NPC81000","source_enemy":enemy.source_enemy,"native_contacts":contacts.size(),"native_audio_cues":cues.size(),"contact_station":var_to_str(station),"purpose":"Representative source-party contact; isolated art/repeated ordinary death are checked on30101"})
 clear_enemies();army.presentation_events.clear();game.crowd.army.presentation.clear()
 check(game.model.enemies.is_empty()and not army.apply_hit(handle,{"amount":1.}).accepted,"Existing despawn retires source-party fixture handles")
 if old_state==null:remove_meta(SourceQuest.STATE)
 else:set_meta(SourceQuest.STATE,old_state)
 if old_slain==null:remove_meta(Ruby.SLAIN)
 else:set_meta(Ruby.SLAIN,old_slain)
func ghost_camera(point:Vector3):
 game.player.position=point;game.player.reset_physics_interpolation();game.model.hero_position=point
 game.camera_rig.yaw=0.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.impulse=0.;game.camera_rig.kick_strength=0.;game.camera_rig.kick_age=100.;game.camera_rig.camera.fov=63.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
func ghost_capture(floor_:int,label_:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 var camera:Camera3D=game.camera_rig.camera
 check(is_equal_approx(camera.fov,63.),"Rendered ghost uses the normal63degree camera")
 var name_=str(floor_)+"-"+study_name+"-"+label_
 RenderingServer.force_draw();root.get_texture().get_image().save_png(study_out+name_+".png")
 ghost_report.captures.append({"name":name_,"runtime_floor":floor_,"seed":game.model.seed_value,"hero_visible":game.player.visible,"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation),"fov":camera.fov})
