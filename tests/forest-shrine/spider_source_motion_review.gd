extends "res://tests/forest-shrine/freyja_trial_review.gd"
## Real source parties, native attack clocks and map reentry; no quest state grants.
const MOTION_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Trial caves/Spider atlas repair/Motion/"
const SEED=41829558
var motion_report={"cases":[],"goal_complete":false}
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("SPIDER_SOURCE_MOTION_TIMEOUT");quit(1))
 run.call_deferred()
func stations(state:Dictionary)->Array:
 var cells=[];var center=Vector2(state.size)*.5
 for y in range(2,state.size.y-2):
  for x in range(2,state.size.x-2):
   var cell=Vector2i(x,y)
   if Original.open(state.bits,state.size,cell)and[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return Original.open(state.bits,state.size,cell+d)):cells.append(cell)
 cells.sort_custom(func(a,b):return Vector2(a).distance_squared_to(center)<Vector2(b).distance_squared_to(center))
 return cells
func fixed_camera():
 var rig=game.camera_rig
 rig.yaw=0.;rig.pitch=1.05;rig.distance=game.ViewPreferences.CAMERA_MAX;rig.character_screen_offset=0.;rig.combat_camera_angle=0
 rig.impulse=0.;rig.kick_strength=0.;rig.kick_age=100.;rig.camera.fov=63.;rig.camera.h_offset=0.;rig.camera.v_offset=0.;rig.camera.rotation.z=0.
 rig.reset_follow();rig.current_distance=rig.combat_distance();rig.update_camera(0.,true)
 rig.reset_physics_interpolation();rig.camera.reset_physics_interpolation()
func visit_case(id:int):
 var state=Original.state(id,SEED);var cells=stations(state);check(not cells.is_empty(),"Source owner has a native review station "+str(id))
 var layout=Tour.Indoor.layout(id);layout.seed=SEED
 Tour.travel(game,layout,{"arrival":state.origin+Vector2(cells[0])*3.,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 5:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0);freeze();clear_enemies();game.model.waves.spawned=2
 check(East.owns_model(game.model),"Existing East owner handles source floor "+str(id))
 check(game.model.waves.patrol_posts.is_empty(),"Source encounter owner replaces generic patrols "+str(id))
 return state
func fight_case(id:int,label_:String,earth:bool):
 print("SPIDER_SOURCE_MOTION_ENTER ",label_)
 var state:Dictionary=await visit_case(id);var cells=stations(state)
 if not earth:cells.erase(Vector2i(33,11));cells.push_front(Vector2i(33,11))
 var row={"label":label_,"runtime_map":id,"generations":[],"source_configuration":2 if earth else 0,"source_group":"14001"if earth else"trial:5002"}
 for generation in 2:
  clear_enemies();game.model.waves.snow_group_ids.clear();game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
  game.player.clear_food_buffs();game.player.max_hp=10000.;game.player.hp=10000.;game.tuning.invincible=true
  var party=[];var source_zone={};var chosen=Vector2i.ZERO;var spawned=false;var baseline=game.army_runtime.handles.size()
  for cell in cells:
   source_zone=East.zone_at(id,cell)
   if source_zone.is_empty():continue
   if earth:
    check(int(source_zone.raw[0])==14001 and source_zone.levels==[10,15],"Cow Ghost source config retains its original pool and10–15levels")
    var rng=RandomNumberGenerator.new();rng.seed=SEED+generation
    party=East.group(source_zone,{"east-group:%s"%source_zone.id:["14001"],"east-count:%s"%source_zone.id:[2],"east-member:14001":[0]},rng)
   else:
    if not source_zone.groups.any(func(choice):return choice[0]=="trial:5002"):continue
    party=maximum_party(source_zone,"trial:5002")
   var at=game.model.world_point(state.origin+Vector2(cell)*3.,.15)
   if not game.army_runtime.native.can_reach(at,at,.5):continue
   game.player.position=at;game.player.velocity=Vector3.ZERO;game.model.hero_position=at;game.player.reset_physics_interpolation()
   game.model.waves.snow_last=at/game.model.falan_scale;game.model.waves.snow_distance=0.;game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
   game.model.waves.tick(0.,at)
   if game.model.enemies.size()==party.size():spawned=true;chosen=cell;break
   clear_enemies();game.model.waves.snow_group_ids.clear()
  check(spawned,"Whole original party fits through ordinary native placement "+label_)
  if not spawned:continue
  game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility();game.world.sync(0.);fixed_camera()
  var handles=[];var ids=game.model.enemies.keys();var skins=[]
  for enemy in game.model.enemies.values():
   handles.append(game.army_runtime.handles[enemy.id]);skins.append(int(enemy.skin))
   check(int(enemy.get("snow_encounter",-1))==int(source_zone.id),"Native member retains its source zone "+label_)
  check(skins.all(func(skin):return skin==104)if earth else skins.count(103)==2 and skins.count(186)==2,"Source species reach their existing bank rows "+label_)
  game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
  game.tuning.invincible=false;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
  var frames=[];var started=false;var saw_attack=false
  var folder=MOTION_OUT+label_+"/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
  for tick in 900:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
   if generation>0:continue
   var snapshot:Dictionary=game.army_runtime.render_snapshot();var spider_states=[]
   for index in snapshot.handles.size():
    if snapshot.logical_ids[index]in ids and snapshot.pose_rows[index]in [103,104]:
     var action=int(snapshot.render_actions[index]);saw_attack=saw_attack or action==1
     spider_states.append({"unit":int(snapshot.logical_ids[index]),"skin":int(snapshot.pose_rows[index]),"action":action,"time":float(snapshot.render_time[index]),"direction":int(snapshot.action_indices[index])})
   if saw_attack:started=true
   if started and frames.size()<60 and tick%3==0 and DisplayServer.get_name()!="headless":
    fixed_camera();game.crowd.present_army(snapshot,[])
    for child in game.get_children():
     if child is CanvasLayer:child.hide()
    await process_frame;RenderingServer.force_draw()
    var file=folder+"frame-%03d.png"%frames.size();check(root.get_texture().get_image().save_png(file)==OK,"Native attack frame saved "+label_)
    frames.append({"image":file,"tick":tick,"native_spiders":spider_states})
  var contacts=game.army_runtime.event_log.filter(func(event):return event.kind=="external_damage"and event.external_kind==0 and event.source_id in ids)
  check(ids.all(func(unit):return contacts.any(func(event):return event.source_id==unit)),"Every source member delivers native contact "+label_)
  check(game.player.hp<10000.,"Original native party damages live hero "+label_)
  if generation==0:
   check(saw_attack,"Source spider publishes actual native attack state "+label_)
   if DisplayServer.get_name()!="headless":check(frames.size()==60,"Three seconds of real native attack/recovery are captured "+label_)
  for tick in 180:
   for handle in handles:
    if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
   if handles.all(func(handle):return not game.army_runtime.valid(handle)):break
   game.army_runtime.integration_tick(1./60.)
  game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  check(game.model.enemies.is_empty()and game.army_runtime.handles.size()==baseline,"Repeated source death/pool cleanup returns to baseline "+label_)
  row.generations.append({"generation":generation,"station":str(chosen),"party":party,"skins":skins,"contacts":contacts.size(),"player_damaged":game.player.hp<10000.,"frames":frames})
 motion_report.cases.append(row)
func run():
 root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOTION_OUT))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-spider-motion-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=SEED;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));Original.Art.load_freyja_trial()
 var source:Dictionary=Original.Art.data().maps[Original.path_for(11008)];var flag=source.sokia_visual_only;source.sokia_visual_only=false
 await fight_case(11008,"fire-source",false)
 await fight_case(Original.generated().floor_id("east_2",1),"earth-source",true)
 await fight_case(11008,"fire-reentry",false)
 source.sokia_visual_only=flag;check(JSON.stringify(get_meta("falan_venture"))==saved,"Source motion review preserves saved adventure")
 motion_report.checks=checks;motion_report.failures=errors
 motion_report.qualification="Actual native parties at original source zones; generated Cow Ghost geometry is the existing adaptation, not tile-by-tile source layout proof. Direct shuffle-bag choices avoid rare grinding; no item/job grants. Frame capture is not an FPS benchmark."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered";var file=FileAccess.open(MOTION_OUT+"review-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(motion_report,"  ")+"\n");file.close()
 print("SPIDER_SOURCE_MOTION_RESULT checks=",checks," failures=",errors," cases=",motion_report.cases.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
