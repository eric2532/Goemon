extends "res://tests/forest-shrine/black_prayer_encounter_review.gd"
## Direct source stations and actual F/UI callbacks; no synthetic quest-item grants.
const Quest=preload("res://scripts/forest/forest_black_prayer_events.gd")
const ROUTE_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/"
var route_report={"interactions":[],"battles":[],"cameras":[],"limits":[]}
func _initialize():
 create_timer(1800).timeout.connect(func():printerr("BLACK_PRAYER_ROUTE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROUTE_OUT))
 route_report.limits=Quest.data().limits.duplicate()
 route_report.limits.append("Direct map/contact stations exercise live F/UI/native owners; this is not a recording of walking the whole outdoor quest route or waiting61real minutes.")
 route_report.limits.append("Lifecycle seed/same-seed tests replay the existing cleared-ledger marker and reload real maps; no title/new-game UI traversal is claimed.")
 var art_proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer Blade/source-preservation.json"))
 route_report.actor_bank={"motions_sha256":FileAccess.get_sha256(Ruby.ROOT+"motions.json"),"blade_source_key":"original:2913","preservation_proof":"Black Prayer Blade/source-preservation.json"}
 check(route_report.actor_bank.motions_sha256==art_proof.published_files["motions.json"],"Current native/rendered evidence binds the published corrected Blade bank")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-black-prayer-route-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 game.player.set_auto_attack(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 for id:int in NativePrayer.FLOORS:await prayer_floor(id)
 await visit_source(15003,Vector2i(35,8));await interact_source("6302",["OK"])
 check(game.model.falan_floor==15003 and Events.item_count(items(),18420)==0,"No-candle production rock does not transfer or invent an item")
 await visit_source(3208,Vector2i(10,15));await interact_source("6300",["YES","YES","NEXT","YES","OK"])
 check(Events.item_count(items(),18419)==1,"Actual source F confirmations acquire the original letter")
 await visit_source(3350,Vector2i(12,5));await interact_source("6301",["YES","NEXT","OK","OK"],true)
 check(Events.item_count(items(),18419)==0 and Events.item_count(items(),18420)==1,"Production source exchange supplies the candle without a fixture grant")
 check(absf(float(items().get("source_item_birth_18420",0))-Time.get_unix_time_from_system())<5.,"Production GiveItem uses response-time rather than stale dialogue time")
 await visit_source(15003,Vector2i(35,8));await interact_source("6302",["YES"])
 check(game.model.falan_floor==16507 and source_cell()==Vector2i(7,4),"Original candle rock transfer reaches exact16507(7,4)")
 for generation in 2:
  var placed:Array=Quest.generated_npcs(game.run_seed)["6303"]
  await visit_source(int(placed[0]),placed[1]+Vector2i.DOWN);await interact_source("6303",["OK","YES","OK"])
  check(Events.item_count(items(),18421)==1,"Live seeded source NPC supplies the original proof generation"+str(generation))
  await interact_source("6303",["OK"])
  check(Events.item_count(items(),18421)==1,"Repeated source F cannot duplicate held proof")
  await visit_source(16508,Vector2i(24,33))
  check(not game.model.get_meta("falan_links",[]).any(func(link):return link.to=="ruby_gate" or link.get("floor",0) in [3350,3351,3353]),"No free guard or legacy reward shortcut bypasses source actors")
  var pose=game.player.global_transform;pose.origin=game.model.world_point(source_point(Vector2i(24,32)),.32)
  check(game.player.test_move(pose,game.model.world_point(source_point(Vector2i(24,29)),.32)-pose.origin),"Existing player collision still blocks the original barred crossing")
  await interact_source("6305",["YES"])
  check(game.model.falan_floor==16508 and source_cell()==Vector2i(24,29) and Events.item_count(items(),18421)==0,"Actual guard consumes proof and uses exact source landing")
  for i in 3:game.model.waves.tick(1.,game.player.position)
  check(game.model.enemies.is_empty(),"Approach alone no longer starts the original scripted Ruby fight")
  await interact_source("81000",[])
  await ruby_party(generation)
  check(game.model.falan_floor==16509 and source_cell()==Vector2i(24,12),"All ten source deaths use original victory16509(24,12)")
  check(game.model.enemies.is_empty() and game.exploration_loot.slots.all(func(slot):return not slot.active or not slot.chest),"Source-complete victory room has no invented ambient party/chests")
  await route_camera("16509-win-"+str(generation),Vector2i(24,14))
  if generation==0:
   await interact_source("6927",[])
   check(game.model.falan_floor==5011 and source_cell()==Vector2i(8,6),"Live source post-palace actor enters original Shanti room")
   check(game.exploration_loot.slots.all(func(slot):return not slot.active or not slot.chest),"Shanti room has no generic ambient entry chest")
   await route_camera("5011-source-room",Vector2i(8,7));await interact_source("6928",[])
   check(game.model.falan_floor==16509 and source_cell()==Vector2i(32,13),"Shanti return actor uses exact source post-palace landing")
 await interact_source("6309",["NEXT","OK"])
 check(game.model.falan_floor==3354 and source_cell()==Vector2i(8,8),"Fresh candle selects original3354 rather than legacy3353")
 check(Events.item_count(items(),18420)==0 and items().get("source_endevent_3")==1,"Live post-return commits candle consumption and original EndEvent3")
 check(game.exploration_loot.slots.all(func(slot):return not slot.active or not slot.chest),"Source reward room has no generic ambient entry chest")
 await route_camera("3354-source-room",Vector2i(10,10));await interact_source("6311",["YES"])
 check(game.model.falan_floor==3352 and source_cell()==Vector2i(5,9),"Source reward actor reaches original research-room landing")
 await visit_source(3350,Vector2i(12,5));await interact_source("6301",["NEXT","OK"])
 check(items().get("source_nowevent_3")==0 and items().get("source_endevent_3")==0 and Events.item_count(items(),18420)==0,"Natural completion dialogue resets original quest flags without granting a candle")
 await visit_source(3208,Vector2i(10,15));await interact_source("6300",["YES","YES","NEXT","YES","OK"])
 check(Events.item_count(items(),18419)==1,"A completed source quest can naturally begin again")
 await lifecycle_reset()
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Source F/native tests preserve saved adventure data")
 route_report.checks=checks;route_report.failures=errors;route_report.prayer=prayer_report;route_report.goal_complete=false
 var mode="headless" if DisplayServer.get_name()=="headless" else "rendered"
 var file=FileAccess.open(ROUTE_OUT+"native-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(route_report,"  "));file.close()
 print("BLACK_PRAYER_ROUTE_RESULT checks=",checks," failures=",errors," fights=",route_report.battles.size()," interactions=",route_report.interactions.size()," cameras=",route_report.cameras.size()+prayer_report.cameras.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func items()->Dictionary:return get_meta(Events.ITEMS,{})
func source_point(cell:Vector2i)->Vector2:return Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)[1]+Vector2(cell)*3.
func source_cell()->Vector2i:return Vector2i(((Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale-Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)[1])/3.).round())
func freeze_world():
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.player.show();game.player.max_hp=1000000.;game.player.hp=1000000.;game.player.invuln=0.
func visit_source(id:int,cell:Vector2i):
 var layout:Dictionary=Tour.Indoor.layout(id);layout.seed=game.run_seed
 var point:Vector2=Tour.Indoor.floor_info(id,game.run_seed)[1]+Vector2(cell)*3.
 Tour.travel(game,layout,{"arrival":point,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 freeze_world();check(game.model.falan_floor==id,"Existing owner enters source station "+str(id))
func interact_source(id:String,answers:Array,clock_probe:bool=false):
 game.explorer_npcs.prepare()
 var sprites=game.world.map_features.find_children("*","Sprite3D",true,false).filter(func(node):return node.get_meta("npc_record",{}).get("id","")==id)
 check(sprites.size()==1,"One original source actor at its owned location "+id)
 if sprites.size()!=1:return
 var sprite:Sprite3D=sprites[0];var record:Dictionary=sprite.get_meta("npc_record");var at:Vector2=Vector2(sprite.position.x,sprite.position.z)
 var found=false
 for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  var point=game.model.world_point(at+offset*3.,.15)
  if not game.army_runtime.native.can_reach(point,point,.6):continue
  game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation()
  game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+id:found=true;break
 check(found,"Source actor has a reachable ordinary F station "+id)
 if not found:return
 var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
 var session:Dictionary=game.get_meta(Events.SESSION,{})
 check(session.get("actor",{}).get("id","")==id,"Actual F input starts the original actor program "+id)
 var left=answers.duplicate();var windows=[]
 for i in 40:
  session=game.get_meta(Events.SESSION,{})
  if session.get("status","")!="window":break
  windows.append(session.pending.message)
  if clock_probe and int(session.pending.message)==14520:session.context.now-=120.
  var answer=left.pop_front() if not left.is_empty() else "NEXT" if "NEXT" in session.pending.choices else "OK"
  Events.respond(game,int(session.serial),answer)
 check(session.get("status","")!="blocked","Production source program never weakens an unknown guard "+id+" "+str(session.get("blocker",{})))
 route_report.interactions.append({"actor":id,"source":record.source,"runtime_floor":game.model.falan_floor,"cell":record.cell,"template_cell":record.get("template_cell",[]),"windows":windows,"status":session.get("status",""),"destination":session.get("destination",[]),"clock_probe":clock_probe})
 for i in 6:await physics_frame
 freeze_world()
func ruby_party(generation:int):
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==10,"Source F starts all ten mandatory members generation"+str(generation))
 var ids=game.model.enemies.keys();var handles=[];var members=[]
 for enemy in game.model.enemies.values():
  handles.append(game.army_runtime.handles.get(enemy.id,0));members.append({"id":enemy.id,"slot":enemy.ruby_slot,"enemy":enemy.source_enemy,"ai":enemy.source_ai,"skin":enemy.skin})
  check(enemy.source_group=="11009" and int(enemy.source_encounter)==11007 and enemy.source_enemy==Quest.data().boss.native_slots[int(enemy.ruby_slot)],"Distinct source enemy/AI IDs remain tied to existing native slots")
  check(int(enemy.level)==(50 if int(enemy.skin)==0 else 30),"Original Ruby/escort levels stay50/30")
 var before=game.model.enemies.keys()
 Events.source_actor(game,Quest.data().actors["81000"])
 game.model.waves.tick(1.,game.player.position)
 check(game.model.enemies.keys()==before,"Repeated source interaction cannot duplicate an active party")
 await route_camera("16508-source-fight-"+str(generation),Vector2i(24,22))
 var army=game.army_runtime;army.record_events=true;army.compact_scene_events=false;army.event_log.clear();game.tuning.invincible=false
 for cell:Vector2i in [Vector2i(24,12),Vector2i(24,22),Vector2i(24,27)]:
  game.player.position=game.model.world_point(source_point(cell),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
  for tick in 600:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);army.integration_tick(1./60.)
 var direct_stations=[]
 for member in members:
  if army.event_log.any(func(event):return event.kind=="external_damage" and event.external_kind==0 and event.source_id==member.id):continue
  var handle:int=army.handles.get(member.id,0)
  if handle==0:continue
  var point:Vector3=army.unit_state(handle).position
  for offset in [Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD]:
   var station=point+offset*2.8
   if not army.native.can_reach(station,point,.6):continue
   game.player.position=station;game.model.hero_position=station;game.player.reset_physics_interpolation()
   direct_stations.append({"source_enemy":member.enemy,"world":var_to_str(station)})
   for tick in 600:
    game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);army.integration_tick(1./60.)
   break
 var contacts=army.event_log.filter(func(event):return event.kind=="external_damage" and event.external_kind==0 and event.source_id in ids)
 check(ids.all(func(id):return contacts.any(func(event):return event.source_id==id)),"Every mandatory source member delivers native contact")
 game.tuning.invincible=true
 for attempt in 60:
  for handle in handles:army.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
  army.dispatch_events();army.sync_compatibility()
  if game.model.enemies.is_empty():break
  army.integration_tick(.1)
 check(game.model.enemies.is_empty() and get_meta(Ruby.SLAIN,{}).size()==10,"Existing native death owner completes all ten original slots")
 check(handles.all(func(handle):return not army.apply_hit(handle,{"amount":1.}).accepted),"Retired source-party handles reject stale hits")
 for member in members:member.contacts=contacts.filter(func(event):return event.source_id==member.id).size()
 route_report.battles.append({"generation":generation,"members":members,"contacts":contacts.size(),"contact_stations":[[24,12],[24,22],[24,27]],"additional_native_contact_stations":direct_stations,"cleaned":game.model.enemies.is_empty(),"cleanup_counts":resource_counts(),"native_formation":"Existing real-time positions preserved; direct connected contact stations are fixtures."})
 game.model.waves.tick(1.,game.player.position)
 for i in 6:await physics_frame
 freeze_world()
func lifecycle_reset():
 game.run_seed+=1
 await visit_source(16508,Vector2i(24,12));Quest.prepare_run(game)
 check(not has_meta(Quest.STATE) and not has_meta(Ruby.SLAIN),"New seed removes only stale source trigger/slot state")
 Quest.begin(game,Quest.data().actors["81000"],Quest.data().actors["81000"].script)
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==10,"New source seed restores the complete ten-member party")
 var lifecycle={"new_seed":game.run_seed,"fresh_members":game.model.enemies.size()}
 var dead:Dictionary=game.model.enemies.values().filter(func(enemy):return int(enemy.ruby_slot)==6)[0]
 var old_handles=game.army_runtime.handles.values().duplicate()
 for attempt in 20:
  if not game.army_runtime.handles.has(dead.id):break
  game.army_runtime.apply_hit(game.army_runtime.handles[dead.id],{"amount":1000000.,"accuracy":100.});game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
 check(get_meta(Ruby.SLAIN,{}).size()==1,"Partial source battle records one exact existing dead slot")
 lifecycle.partial_dead_slots=get_meta(Ruby.SLAIN,{}).keys()
 await visit_source(16507,Vector2i(7,4));await visit_source(16508,Vector2i(24,12))
 check(old_handles.all(func(handle):return not game.army_runtime.apply_hit(handle,{"amount":1.}).accepted),"Leaving/reentering retires every previous native generation")
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==9 and game.model.enemies.values().all(func(enemy):return int(enemy.ruby_slot)!=6),"Active source reentry resumes exactly the nine surviving slots")
 lifecycle.resumed_members=game.model.enemies.size();lifecycle.old_native_handles=old_handles.size()
 clear_enemies()
 remove_meta(Ruby.SLAIN);Quest.prepare_run(game)
 check(not has_meta(Quest.STATE),"Same-seed existing new-adventure ledger marker clears stale trigger state")
 lifecycle.same_seed_marker_cleared=not has_meta(Quest.STATE);route_report.lifecycle=lifecycle
func route_camera(label_:String,cell:Vector2i):
 if DisplayServer.get_name()=="headless":return
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
 prayer_camera_position(game.model.world_point(source_point(cell),.15))
 game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 var camera:Camera3D=game.camera_rig.camera;check(is_equal_approx(camera.fov,63.),"Normal63degree source route camera "+label_)
 RenderingServer.force_draw();var shot=root.get_texture().get_image();check(capture_ready(shot),"Nonblank source route view "+label_)
 shot.save_png(ROUTE_OUT+label_+".png")
 route_report.cameras.append({"name":label_,"source_floor":game.model.falan_floor,"cell":[cell.x,cell.y],"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation),"fov":camera.fov,"seed":game.model.seed_value})
