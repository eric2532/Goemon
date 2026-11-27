extends "res://tests/forest-shrine/black_prayer_source_route_review.gd"
## Scoped review overrides are test-only. Unknown drop execution never grants an item.
const ACCESS_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape access/"
var access_report={"maps":[],"interactions":[],"battles":[],"cameras":[],"fixture_review_overrides":true,"natural_acquisition_verified":false,"goal_complete":false}
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("CAPE_ACCESS_TIMEOUT");quit(1))
 run.call_deferred()
func point(cell:Vector2i)->Vector2:
 return Original.source_point(game.model.falan_floor,cell) if game.model.falan_area=="interior" else Tour.Regions.frame(game.model.falan_area).inverse()*(Vector2(cell)*3.)
func field_cell()->Vector2i:
 return Population.source_cell(game.model,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)
func field_station(area:String,cell:Vector2i):
 var layout:Dictionary=Tour.Regions.layout(area);layout.seed=game.run_seed
 Tour.travel(game,layout,{"arrival":Tour.Regions.frame(area).inverse()*(Vector2(cell)*3.),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 freeze_world();clear_enemies();game.model.waves.spawned=2
func interact_access(id:String):
 game.explorer_npcs.prepare()
 var sprites=game.world.map_features.find_children("*","Sprite3D",true,false).filter(func(node):return str(node.get_meta("npc_record",{}).get("id",""))==id)
 check(sprites.size()==1,"One source Cape actor at its declared anchor "+id)
 if sprites.size()!=1:return
 var sprite:Sprite3D=sprites[0];var at=Vector2(sprite.position.x,sprite.position.z);var found=false
 for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  var station=game.model.world_point(at+offset*3.,.15)
  if not game.army_runtime.native.can_reach(station,station,.6):continue
  game.player.position=station;game.model.hero_position=station;game.player.reset_physics_interpolation()
  game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+id:found=true;break
 check(found,"Original Cape actor has a native-supported ordinary F station "+id)
 if not found:return
 var input=InputEventKey.new();input.physical_keycode=KEY_F;input.pressed=true;game._input(input)
 if game.explorer_npcs.selected.get("id","")=="source:"+id:game.explorer_npcs.finish()
 var session:Dictionary=game.get_meta(Events.SESSION,{})
 check(str(session.get("actor",{}).get("id",""))==id,"Actual F selects the original Cape event "+id)
 var windows=[]
 for i in 40:
  session=game.get_meta(Events.SESSION,{})
  if session.get("status","")!="window":break
  windows.append(session.pending.message)
  Events.respond(game,int(session.serial),"NEXT" if "NEXT" in session.pending.choices else "YES" if "YES" in session.pending.choices else "OK")
 check(session.get("status","")!="blocked","Known Cape F branch preserves strict guards "+id+" "+str(session.get("blocker",{})))
 access_report.interactions.append({"id":id,"windows":windows,"status":session.get("status",""),"destination":session.get("destination",[])})
 for i in 6:await physics_frame
 freeze_world()
func access_camera(label_:String,cell:Vector2i,yaw:float=0.):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
 prayer_camera_position(game.model.world_point(point(cell),.15))
 game.camera_rig.yaw=yaw;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 var camera:Camera3D=game.camera_rig.camera
 check(is_equal_approx(camera.fov,63.),"Fixed normal 63-degree Cape camera "+label_)
 RenderingServer.force_draw();var shot=root.get_texture().get_image();check(capture_ready(shot),"Nonblank Cape source view "+label_)
 shot.save_png(ACCESS_OUT+label_+".png")
 access_report.cameras.append({"name":label_,"floor":game.model.falan_floor,"area":game.model.falan_area,"cell":[cell.x,cell.y],"fov":camera.fov,"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation)})
func bear_generation(number:int):
 # Existing XP/level-up refresh clamps HP after each kill; restore only fixture contact health.
 game.player.max_hp=1000000.;game.player.hp=1000000.;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
 var actor:Dictionary=Cape.access().actors["5237"]
 var pets=load("res://scripts/forest/pet_catalog.gd");var hounds=load("res://scripts/forest/crowd/hound_sprites.gd")
 var prepared:Array=hounds.meshes[pets.ROOT].get_meta("prepared_pages",[])
 check(pets.motions().skin_pages[135].all(func(page):return prepared.any(func(value):return int(value)==int(page))),"Bear pages are prepared by the existing shared renderer during world setup")
 check(Cape.begin(game,actor,"2|||0|||||0|12021|||||||||"),"Direct source encounter trigger reuses existing native owner")
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 var key=Regional.active(self,game.model.falan_floor,game.model.falan_area);var ids=game.model.enemies.keys();var handles=[]
 print("CAPE_BEAR_CONTEXT ",{"generation":number,"phase":game.model.phase,"playing":game.playing,"hero_hp":game.player.hp,"enemies":game.model.enemies.values().map(func(enemy):return {"id":enemy.id,"skin":enemy.skin,"battle":enemy.get("university_battle","")}),"active":key})
 check(ids.size()==1,"Source 12021 produces its one mandatory Bear")
 if ids.size()!=1:return
 var enemy:Dictionary=game.model.enemies[ids[0]];var member:Dictionary=get_meta(Regional.BATTLES)[key].members[0]
 check(int(enemy.skin)==135 and int(enemy.level)==79 and member.enemy=="12117","Exact source Bear uses companion 135 at level 79")
 handles.append(game.army_runtime.handles[enemy.id])
 game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear();game.tuning.invincible=false
 var origin:Vector3=game.army_runtime.unit_state(handles[0]).position
 for offset in [Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD]:
  var station=origin+offset*2.8
  if not game.army_runtime.native.can_reach(station,origin,.6):continue
  game.player.position=station;game.model.hero_position=station;game.player.reset_physics_interpolation();break
 for tick in 900:
  game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
 var contacts=game.army_runtime.event_log.filter(func(event):return event.kind=="external_damage" and event.external_kind==0 and event.source_id in ids)
 check(not contacts.is_empty(),"Existing native Bear attacks make physical contacts generation "+str(number))
 var body:Vector3=game.army_runtime.unit_state(handles[0]).position;var body_cell=Population.source_cell(game.model,Vector2(body.x,body.z)/game.model.falan_scale)
 var camera_cell=body_cell;var camera_yaw=0.
 for offset in [Vector2i(0,3),Vector2i(-3,0),Vector2i(3,0),Vector2i(0,-3)]:
  var candidate=body_cell+offset;var camera_point=game.model.world_point(point(candidate),.15)
  if not game.army_runtime.native.can_reach(camera_point,body,.6):continue
  camera_cell=candidate;camera_yaw=-atan2(float(-offset.x),float(offset.y));break
 await access_camera(("bear-setup-" if "--bear-only" in OS.get_cmdline_user_args() else "bear-")+str(number)+"-normal",camera_cell,camera_yaw)
 game.tuning.invincible=true
 for attempt in 60:
  for handle in handles:game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
  game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  if game.model.enemies.is_empty():break
  game.army_runtime.integration_tick(.1)
 check(game.model.enemies.is_empty() and get_meta(Regional.BATTLES)[key].complete,"Source Bear reuses native death/cleanup lifecycle")
 check(handles.all(func(handle):return not game.army_runtime.apply_hit(handle,{"amount":1.}).accepted),"Retired Bear handles reject stale hits")
 check(Events.item_count(items(),18598)==0,"Unknown raw drop never creates a production prerequisite")
 print("CAPE_BEAR_CLEANUP ",{"generation":number,"phase":game.model.phase,"playing":game.playing,"hero_hp":game.player.hp,"contacts":contacts.size()})
 access_report.battles.append({"generation":number,"encounter":12021,"group":12099,"enemy":12117,"appearance":101010,"bank":"guard_pets","skin":135,"prepared_pages":prepared,"body_cell":[body_cell.x,body_cell.y],"camera_cell":[camera_cell.x,camera_cell.y],"contacts":contacts.size(),"trigger":"direct representative source encounter; original malformed conversation/default drop unverified","cleanup":game.model.enemies.is_empty()})
 Regional.victory(game)
func no_item_princess():
 await visit_source(15524,Vector2i(16,11));clear_enemies();game.model.waves.spawned=2
 await interact_access("5225")
 var key=Regional.active(self,15524,"interior")
 check(not key.is_empty(),"Actual no-item F5225 starts its original source battle")
 if key.is_empty():return
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 var ids=game.model.enemies.keys();var handles=[]
 check(ids.size()==1,"Source princess party enters the existing native owner")
 for enemy in game.model.enemies.values():
  handles.append(game.army_runtime.handles[enemy.id]);check(int(enemy.level)>=83 and int(enemy.level)<=85,"Original princess level interval remains83–85")
 game.player.max_hp=1000000.;game.player.hp=1000000.;game.player.invuln=0.;game.tuning.invincible=false;game.player.model.clear_kagerou_dodge()
 game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
 for tick in 900:
  game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
 var contacts=game.army_runtime.event_log.filter(func(event):return event.kind=="external_damage" and event.external_kind==0 and event.source_id in ids)
 check(ids.all(func(id):return contacts.any(func(event):return event.source_id==id)),"Every source princess member makes native contacts at the real F station")
 await access_camera("15524-no-item-source-fight",Original.safe_cell(15524,Vector2i(16,11)))
 game.tuning.invincible=true
 for attempt in 60:
  for handle in handles:game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
  game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  if game.model.enemies.is_empty():break
  game.army_runtime.integration_tick(.1)
 check(game.model.enemies.is_empty(),"Existing native death path completes the no-item source fight")
 game.model.waves.tick(1.,game.player.position)
 for i in 6:await physics_frame
 freeze_world()
 check(game.model.falan_area=="ghana_road" and field_cell()==Vector2i(715,35),"No-item princess victory preserves original source300(715,35)")
 check(Events.item_count(items(),18598)==0 and Events.item_count(items(),18599)==0,"No-item fight never invents Cape prerequisites")
 access_report.battles.append({"actor":5225,"encounter":12019,"group":12097,"trigger":"actual ordinary F without18599","contacts":contacts.size(),"victory":[300,715,35]})
func run():
 root.size=Vector2i(1280,800);Original.Art.load_sokia_cape_access()
 var flags={}
 for id:int in Original.Art.SOKIA_CAPE_ACCESS_IDS:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=row.sokia_visual_only;row.sokia_visual_only=false
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-cape-access-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.player.set_auto_attack(false);game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var old_items=items().duplicate(true);set_meta(Events.ITEMS,{})
 if "--princess-only" in OS.get_cmdline_user_args():
  await no_item_princess()
  for id in flags:Original.Art.data().maps[Original.path_for(int(id))].sokia_visual_only=flags[id]
  access_report.checks=checks;access_report.failures=errors;access_report.scope="Actual no-item F5225, native12019contacts and original victory; source map visual acceptance separate"
  var mode="headless" if DisplayServer.get_name()=="headless" else "rendered";var file=FileAccess.open(ACCESS_OUT+"princess-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(access_report,"  "));file.close()
  print("CAPE_PRINCESS_ONLY checks=",checks," failures=",errors)
  game.queue_free();await process_frame;quit(1 if errors else 0);return
 if "--bear-only" in OS.get_cmdline_user_args():
  await field_station("west_lakes",Vector2i(182,101))
  for number in 3:
   if number==1:
    await visit_source(15526,Vector2i(43,8));clear_enemies()
    check("original:2911" in game.model.get_meta("east_enemy_pet_keys",[]),"Existing Lorens setup retains its own companion page owner")
    await field_station("west_lakes",Vector2i(182,101))
   await bear_generation(number)
  access_report.checks=checks;access_report.failures=errors;access_report.scope="Bear setup pages, contacts and West→15526→West reuse; source map/gate review is separate"
  access_report.bank=Cape.access().bear_bank_provenance
  var mode="headless" if DisplayServer.get_name()=="headless" else "rendered";var file=FileAccess.open(ACCESS_OUT+"bear-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(access_report,"  "));file.close()
  print("CAPE_BEAR_ONLY checks=",checks," failures=",errors)
  game.queue_free();await process_frame;quit(1 if errors else 0);return
 var stations={15517:Vector2i(39,15),15520:Vector2i(49,46),15524:Vector2i(16,19),15528:Vector2i(16,23),15529:Vector2i(15,16)}
 for id:int in Original.Art.SOKIA_CAPE_ACCESS_IDS:
  print("CAPE_ACCESS_ENTER ",id)
  await visit_source(id,stations[id]);clear_enemies();game.model.waves.spawned=2
  var state:Dictionary=Original.state(id);var info:Dictionary=Original.Art.data().maps[Original.path_for(id)]
  check(Original.Art.raw_map(Original.path_for(id))==state.raw,"Existing owner consumes exact hybrid source planes "+str(id))
  check(Population.encounters_own(game.model) and not Population.encounter_scope(game.model,point(stations[id])),"No ordinary rows never receive a generic regional enemy pool "+str(id))
  check(game.exploration_loot.slots.all(func(slot):return not slot.active or not slot.chest),"No unsupported ambient entry chests "+str(id))
  var supported=0;var unsupported=[]
  for i in state.size.x*state.size.y:
   var cell=Vector2i(i%state.size.x,i/state.size.x)
   if not Original.open(state.bits,state.size,cell):continue
   var at=game.model.world_point(Original.point(id,cell),.15)
   if game.army_runtime.native.can_reach(at,at,.4):supported+=1
   else:unsupported.append([cell.x,cell.y])
  check(supported>0,"Original source-open cells have actual native support "+str(id))
  var actual=game.world.map_features.find_children("*","Sprite3D",true,false).filter(func(node):return node.get_meta("npc_record",{}).get("dialogue_owner","")=="sokia_cape_access")
  var expected=Cape.access().actors.values().filter(func(actor):return int(actor.source)==id)
  check(actual.size()==expected.size(),"Every scoped source room NPC appears exactly once "+str(id))
  await access_camera(str(id)+"-entry-normal",stations[id])
  var cells=Original.patrols(id,game.model.seed_value,3)
  if not cells.is_empty():await access_camera(str(id)+"-source-normal",cells[cells.size()/2])
  access_report.maps.append({"id":id,"hybrid_sha256":info.restored_sha256,"source_completion":info.source_completion,"native_self_supported_cells":supported,"decoder_open_without_radius04_self_support":unsupported,"declared_npcs":expected.size(),"actual_npcs":actual.size(),"links":game.model.get_meta("falan_links",[])})
 await field_station("west_lakes",Vector2i(182,101))
 for number in 3:await bear_generation(number)
 # The prerequisite is injected only here; the real source F exchange supplies 18599.
 Events.set_item(items(),18598,1);await interact_access("5237")
 check(Events.item_count(items(),18598)==0 and Events.item_count(items(),18599)==1,"Fixture-held 18598 follows original F exchange; natural drop is not claimed")
 await field_station("ghana_road",Vector2i(707,59));await interact_access("5239")
 check(game.model.falan_floor==15524 and field_cell()==Vector2i(16,19),"Original guard reaches exact source cave entrance")
 await access_camera("15524-princess-normal",Original.safe_cell(15524,Vector2i(16,11)))
 await interact_access("5225")
 check(game.model.falan_floor==15528 and field_cell()==Vector2i(16,23),"Original princess reaches exact first hall")
 await access_camera("15528-leaders-normal",Original.safe_cell(15528,Vector2i(15,12)))
 await interact_access("5226")
 check(game.model.falan_floor==15529 and field_cell()==Vector2i(15,16),"Original hall conversation reaches exact second hall")
 await access_camera("15529-leaders-normal",Original.safe_cell(15529,Vector2i(15,12)))
 await interact_access("5240")
 check(game.model.falan_floor==15525 and field_cell()==Vector2i(16,11),"Original second hall reaches existing Cape gate")
 await interact_access("5243")
 check(game.model.falan_floor==15525 and Events.item_count(items(),18599)==0 and Events.item_count(items(),18600)==1,"Existing Cape gate retains exact 18599 to 18600 exchange")
 for id in flags:Original.Art.data().maps[Original.path_for(int(id))].sokia_visual_only=flags[id]
 set_meta(Events.ITEMS,old_items);check(JSON.stringify(get_meta("falan_venture"))==saved,"Review preserves existing adventure state")
 access_report.checks=checks;access_report.failures=errors;access_report.events_sha256=FileAccess.get_sha256("res://assets/maps/falan/sokia/cape/access/events/data.json");access_report.source_limits=Cape.access().limitations
 var mode="headless" if DisplayServer.get_name()=="headless" else "rendered";var file=FileAccess.open(ACCESS_OUT+"native-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(access_report,"  "));file.close()
 print("CAPE_ACCESS_RESULT checks=",checks," failures=",errors," cameras=",access_report.cameras.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
