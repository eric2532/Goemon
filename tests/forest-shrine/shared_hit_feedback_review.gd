extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Shared Hit Feedback Trial/"
var driver:Node
var runtime
var times=[]
var frame_times=[]
var focused=0
var samples=0
var damage_events=0
var label="before"

func advance(count:int):
 await driver.advance(count,func(dt):
  var started=Time.get_ticks_usec()
  game.player._physics_process(dt)
  runtime.step(dt,{});runtime.dispatch_events();runtime.sync_compatibility()
  runtime.presentation_delta+=dt;runtime.presentation_dirty=true;runtime.flush_presentation()
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(dt)
  game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
  times.append((Time.get_ticks_usec()-started)/1000.0)
  samples+=1
  if DisplayServer.get_name()!="headless":
   frame_times.append(root.get_process_delta_time()*1000)
   if DisplayServer.window_is_focused():focused+=1)

func run():
 create_timer(180).timeout.connect(func():printerr("SHARED_HIT_REVIEW_TIMEOUT");quit(1))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+label))
 var document=load("res://scripts/forest/forest_map_document.gd").new()
 check(document.load_wind_meadow()=="","Review uses bundled Wind Meadow")
 await setup_fixture(document.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.explorer_helpers.set_process(false)
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse();game.music.stop()
 game.training_dummy.collision_layer=0;game.training_dummy.hide();game.enemies.erase(game.training_dummy)
 runtime=game.army_runtime
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.ui.hide()
 game.camera_rig.camera.position=ORIGIN+Vector3(0,3,8)
 game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-4))
 game.impact_confirmed.connect(func(_victim,_strength,_duration):damage_events+=1)
 var cases=[]
 for id in [1,5,7,8,9,10]:
  game.player.select_character(id);fresh()
  runtime.clear();runtime.set_navigation(7000+id,{"width":0});game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  game.crowd.army.presentation.clear()
  for i in 12:
   var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3((i%4-1.5)*.8,0,-2-floori(i/4)*2.0))
   row.hp=100000;row.max_hp=100000
  runtime.import_arrivals();runtime.sync_targets();game.model.update_vision(ORIGIN)
  await advance(2)
  var before=damage_events;var photographed=false;var first_contact=-1
  tap("light_attack")
  for i in 120:
   await advance(1)
   if first_contact<0 and damage_events>before:first_contact=i
   if not photographed and first_contact>=0 and i>=first_contact+2 and DisplayServer.get_name()!="headless":
    if id==1:
     var presentation=game.crowd.army.presentation
     check(presentation.effects.any(func(row):return row.get("contact",false) and row.position.z>ORIGIN.z-1),"Goemon's impact sits on the visible hurtbox surface")
     var saved_flashes=game.settings.get("reduced_flashes",false)
     var before_alpha=presentation.batches.spark.multimesh.get_instance_custom_data(0).g
     game.settings.reduced_flashes=true;presentation.draw_effects()
     check(is_equal_approx(presentation.batches.spark.multimesh.get_instance_custom_data(0).g,before_alpha*.35),"Reduced flashes attenuate the submitted contact burst")
     game.settings.reduced_flashes=saved_flashes;presentation.draw_effects()
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OUT+label+"/fighter-%d.png"%id)==OK,"Save actual native enemy contact for fighter %d"%id)
    photographed=true
  check(damage_events>before,"Fighter %d retains real native enemy damage"%id)
  cases.append({"fighter":id,"confirmed_contacts":damage_events-before})
  await advance(30)
 var presentation=game.crowd.army.presentation
 await advance(60)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 3:
  for i in 36:
   var victim=game.enemies[i%game.enemies.size()]
   victim.take_hit(1,Vector3.FORWARD,i%2==0,{"tower":false,"critical_chance":100 if i%3==0 else 0})
  runtime.flush_presentation();await advance(60)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated native impacts retain no additional nodes/resources")
 times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"cases":cases,"frames":samples,"focused":focused,"step_p95_ms":times[int(times.size()*.95)],"step_max_ms":times[-1],"node_delta":get_node_count()-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"native_effect_capacity":presentation.effect_capacity}
 if not frame_times.is_empty():report.merge({"frame_p95_ms":frame_times[int(frame_times.size()*.95)],"frame_max_ms":frame_times[-1]})
 FileAccess.open(OUT+label+"-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("SHARED_HIT_REVIEW_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
