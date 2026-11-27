extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Art-only native spawns; no source encounter placement, level or quest rule is supplied.
const Blood=preload("res://scripts/forest/crowd/sokia_region_sprites.gd")
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const BLOOD_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Blood Demon/"
var preview_root=BLOOD_OUT
var current_appearance=101211
var art_results={"scope":"Art-only direct native spawns; source encounter rules remain pending","captures":[],"generations":[]}
func _initialize():
 create_timer(600).timeout.connect(func():printerr("BLOOD_DEMON_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-blood-art-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 Tour.travel(game,Tour.Indoor.layout(15526),{"arrival":Original.source_point(15526,Vector2i(60,7)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.model.waves.spawned=2;clear_enemies()
 check(game.model.waves.patrol_source==Blood,"Recovered appearances reuse the existing Sokia native bank")
 check(Blood.NAMES.size()==Blood.motions().variants.size() and int(Blood.motions().variants[7].id)==101211,"Native identities remain stable when appearances are appended")
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 check(game.army_runtime.native.configure_kits(kits),"Original cue table configures existing native combat")
 var at=Original.source_point(15526,Vector2i(60,7))
 var study=[game.model.world_point(at),game.model.world_point(Original.source_point(15526,Vector2i(65,7)))]
 var contact_at=Original.source_point(15526,Vector2i(20,7))
 var pair=[game.model.world_point(contact_at),game.model.world_point(contact_at+Vector2(3.2,0))]
 check(game.army_runtime.native.can_reach(pair[0],pair[1],1.25),"Native contact fixture retains the previously verified original ground")
 art_results.test_backdrop={"map":15526,"contact_hero_source_cell":[20,7],"art_hero_source_cell":[60,7],"full_body_source_cell":[65,7],"near_contact_offset_source_units":[3.2,0],"source_encounter_placement_claimed":false}
 fixed_camera(study[0])
 check(is_equal_approx(game.camera_rig.camera.fov,63.),"Art fixture uses the actual normal63-degree gameplay camera")
 art_results.npc_owners=[]
 for sprite in game.world.find_children("*","Sprite3D",true,false):
  var record:Dictionary=sprite.get_meta("npc_record",{})
  if str(record.get("id",""))!="5305":continue
  var behind:bool=game.camera_rig.camera.is_position_behind(sprite.global_position)
  art_results.npc_owners.append({"id":"5305","source_appearance":record.graphic,"source_cell":record.cell,"world_position":var_to_str(sprite.global_position),"pixel_size":sprite.pixel_size,"global_scale":var_to_str(sprite.global_basis.get_scale()),"behind_art_camera":behind})
  check(behind,"Source NPC5305 stays behind the art camera rather than occluding recovered enemies")
 check(art_results.npc_owners.size()==1,"Art study identifies the actual source NPC5305 visual owner")
 var scripted="--scripted-additions" in OS.get_cmdline_user_args()
 var bosses="--boss-additions" in OS.get_cmdline_user_args()
 var appearances=[100452,100527]if bosses else[101613,101214,101921,101031,101121]if scripted else[101211]
 if bosses:preview_root=BLOOD_OUT.replace("Blood Demon/","Scripted Bosses/")
 if scripted:preview_root=BLOOD_OUT.replace("Blood Demon/","Scripted Enemy Assets/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preview_root))
 var adventure=JSON.stringify(get_meta("falan_venture"))
 for appearance in appearances:
  var skin=-1
  for i in Blood.motions().variants.size():
   if int(Blood.motions().variants[i].id)==appearance:skin=i;break
  check(skin>=0,"Requested original appearance exists without shifting previous IDs "+str(appearance))
  if skin>=0:await preview_appearance(appearance,skin,pair)
 for appearance in appearances:
  var skin=-1
  for i in Blood.motions().variants.size():
   if int(Blood.motions().variants[i].id)==appearance:skin=i;break
  if skin>=0:await preview_art(appearance,skin,study)
 check(JSON.stringify(get_meta("falan_venture"))==adventure,"Art preview does not modify saved adventure state")
 art_results.checks=checks;art_results.failures=errors
 var f=FileAccess.open(preview_root+("native-headless.json"if DisplayServer.get_name()=="headless"else"native-rendered.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(art_results,"  "));f.close()
 print("SOKIA_NATIVE_ART_RESULT checks=",checks," failures=",errors," generations=",art_results.generations.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func preview_appearance(appearance:int,skin:int,pair:Array):
 current_appearance=appearance
 var army=game.army_runtime
 for generation in 3:
  clear_enemies();army.presentation_events.clear();game.crowd.army.presentation.clear()
  game.player.show();fixed_camera(pair[0])
  game.player.model.clear_kagerou_dodge();game.player.invuln=0.;game.player.hp=game.player.max_hp
  # Allow ordinary floating-label tweens to retire between independent art studies.
  if generation==0 and DisplayServer.get_name()!="headless":await create_timer(.8).timeout
  var presentation=game.crowd.army.presentation.counts()
  check(presentation.corpses==0 and presentation.labels==0,"Previous native corpse and label pools are clear before named appearance "+str(appearance))
  var enemy:Dictionary=game.model.waves.spawn_enemy(Roles.SLIME,pair[1],-1,skin)
  army.import_arrivals();army.sync_compatibility()
  check(army.handles.has(enemy.id),"Prepared appearance imports through native lifecycle generation"+str(generation))
  var handle:int=army.handles.get(enemy.id,0)
  if handle==0:continue
  check(int(army.unit_state(handle).pose_row)==skin,"Native presentation selects the requested original atlas row")
  army.set_pose(handle,pair[1],PI);army.record_events=true;army.compact_scene_events=false;army.event_log.clear()
  game.tuning.invincible=false;game.player.invuln=0.;game.player.hp=game.player.max_hp
  var hp:float=game.player.hp
  var before_steps:int=army.simulation_steps
  var context={"blocked":army.blocked(),"phase":game.model.phase,"hero":var_to_str(game.player.position),"respawn_left":game.respawn_left,"external_targets":var_to_str(army.external_targets())}
  for tick in 240:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.)
   army.integration_tick(1./60.)
   if generation==0 and tick in [12,24,36,48]:await blood_capture("native-tick-%03d"%tick)
  var contacts=army.event_log.filter(func(e):return e.kind=="external_damage" and e.source_id==enemy.id)
  if contacts.is_empty() and generation==0:printerr("SOKIA_ART_CONTACT_DIAGNOSTIC appearance=",appearance," context=",context," steps=",army.simulation_steps-before_steps," unit=",army.unit_state(handle))
  check(not contacts.is_empty(),"Original attack delivers native contact events generation"+str(generation))
  var cues=army.event_log.filter(func(e):return e.kind=="status" and e.source_id==enemy.id and e.action_index in [606,612])
  check(not cues.is_empty(),"Original attack emits recovered audio cues")
  art_results.generations.append({"generation":generation,"source_appearance":appearance,"native_contacts":contacts.size(),"native_audio_cues":cues.size(),"player_damaged":game.player.hp<hp})
  # Cleanup must not mistake an ordinary dodge for a retained native handle.
  army.apply_hit(handle,{"amount":1000000.,"accuracy":100.});army.dispatch_events();army.sync_compatibility()
  check(not army.handles.has(enemy.id) and game.model.enemies.is_empty(),"Native death clears its handle and record")
  check(not army.apply_hit(handle,{"amount":1.}).accepted,"Retired handle cannot receive a stale hit")
  clear_enemies()
 check(art_results.generations.any(func(g):return g.source_appearance==appearance and g.player_damaged),"Recovered appearance damages the player through normal native delivery "+str(appearance))
func fixed_camera(point:Vector3):
 game.player.position=point;game.player.reset_physics_interpolation();game.model.hero_position=point
 game.camera_rig.yaw=-PI/2.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
func preview_art(appearance:int,skin:int,study:Array):
 if DisplayServer.get_name()=="headless":return
 current_appearance=appearance
 var army=game.army_runtime
 clear_enemies();army.presentation_events.clear();game.crowd.army.presentation.clear()
 await create_timer(.8).timeout
 fixed_camera(study[0]);game.player.hide()
 var enemy:Dictionary=game.model.waves.spawn_enemy(Roles.SLIME,study[1],-1,skin)
 army.import_arrivals();army.sync_compatibility()
 var handle:int=army.handles.get(enemy.id,0)
 check(handle!=0 and int(army.unit_state(handle).pose_row)==skin,"Separate art-only study imports the exact native row "+str(appearance))
 army.set_pose(handle,study[1],PI/2.);await blood_capture("full-body")
 for direction in range(8):
  army.set_pose(handle,study[1],direction*PI/4.)
  await blood_capture("idle-direction-%d"%direction)
 game.player.show();clear_enemies();army.presentation_events.clear();game.crowd.army.presentation.clear()
func blood_capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 var army=game.army_runtime;army.sync_compatibility();game.crowd.present_army(army.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 var name_=str(current_appearance)+"-"+label_
 RenderingServer.force_draw();root.get_texture().get_image().save_png(preview_root+name_+".png")
 var camera:Camera3D=game.camera_rig.camera
 art_results.captures.append({"name":name_,"source_appearance":current_appearance,"test_backdrop_only":true,"hero_visible":game.player.visible,"floor":game.model.falan_floor,"seed":game.model.seed_value,"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov})
