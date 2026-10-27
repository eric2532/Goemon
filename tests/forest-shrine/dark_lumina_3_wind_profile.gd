extends "res://tests/forest-shrine/dark_lumina_3_test.gd"
## Controlled Wind diagnosis: real native troops and prepared player projectiles.
const Shot=preload("res://scripts/dark_lumina_3_projectile.gd")
const EVIDENCE=OUT+"Wind Lag/"
var report=[]
var pool:Node
func stats(values:Array)->Dictionary:
 values.sort()
 return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)],"max":values[-1]}
func measure(label_:String,casting:bool):
 var data={"frame_ms":[],"native_ms":[],"hero_ms":[],"shots_ms":[],"effects_ms":[],"gpu_ms":[],"render_cpu_ms":[],"draws":[],"live_shots":[]}
 var focused=0;var launched=pool.reused;var prepared=pool.created;var misses=pool.misses
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var previous=Time.get_ticks_usec()
 for tick in 540:
  if casting and tick%270==0:game.player.active_ability.start_move(1)
  var start=Time.get_ticks_usec()
  game.army_runtime.native.step(1.0/60);game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility();game.crowd.army.present(game.army_runtime.latest,[])
  var native_end=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  var hero_end=Time.get_ticks_usec();var live=0
  for nodes in pool.all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script()==Shot:shot._physics_process(1.0/60);live+=1
  var shots_end=Time.get_ticks_usec()
  game.crowd.army.presentation.tick(1.0/60)
  var effects_end=Time.get_ticks_usec()
  await process_frame
  var now=Time.get_ticks_usec()
  if now-previous>22000:print("WIND_SPIKE ",JSON.stringify({"phase":label_,"tick":tick,"frame_ms":(now-previous)/1000.0,"native_ms":(native_end-start)/1000.0,"hero_ms":(hero_end-native_end)/1000.0,"shots_ms":(shots_end-hero_end)/1000.0,"live":live}))
  if DisplayServer.get_name()!="headless" and DisplayServer.window_is_focused():focused+=1
  data.frame_ms.append((now-previous)/1000.0);previous=now
  data.native_ms.append((native_end-start)/1000.0);data.hero_ms.append((hero_end-native_end)/1000.0)
  data.shots_ms.append((shots_end-hero_end)/1000.0);data.effects_ms.append((effects_end-shots_end)/1000.0)
  data.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  data.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())
  data.draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));data.live_shots.append(live)
 var row={"label":label_,"focused":focused,"frames":540,"launches":pool.reused-launched,"pool":pool.created,"misses":pool.misses,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources}
 for metric in data:row[metric]=stats(data[metric])
 check(pool.created==prepared and pool.misses==misses,"Profile keeps the prepared projectile workload without pool growth")
 check(row.launches>=22*Finale.WIND_FAN*2 if casting else row.launches==0,"Profile executes both complete Wind barrages")
 report.append(row);print("WIND_PROFILE ",JSON.stringify(row))
 game.player.active_ability.cancel()
 for nodes in pool.all.values():
  for shot in nodes:
   if shot.pool_live:shot.retire()
 game.crowd.army.presentation.effects.clear()
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
 create_timer(180).timeout.connect(func():printerr("WIND_PROFILE_TIMEOUT");quit(1))
 seed(71024);root.size=Vector2i(1280,800);set_meta("forest_painterly_preview",true)
 await setup_fixture()
 root.title="Goemon · Dark Lumina Wind profile";root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true)
 DisplayServer.window_move_to_foreground();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0 if DisplayServer.get_name()=="headless" else 60
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.ui.hide();game.model.phase="wave";game.tuning.invincible=true
 game.player.select_character(30);fresh();game.player.position=ORIGIN+Vector3(0,0,20)
 game.training_dummy.position=ORIGIN+Vector3(100,0,0);game.training_dummy.home=game.training_dummy.position;game.training_dummy.hide()
 for i in 240:
  var row=game.model.waves.spawn_enemy([0,1,3,6,9,16][i%6],ORIGIN+Vector3((i%20-9.5)*2.5,0,-5-(i/20)*2.5))
  row.hp=1000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.native.set_navigation({})
 check(game.army_runtime.enemies.size()==240,"Profile retains all 240 native targets")
 game.camera_rig.camera.position=ORIGIN+Vector3(35,38,65);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,3,-10))
 pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false))
 await measure("idle",false)
 await measure("wind-first",true)
 await measure("wind-repeat",true)
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw();root.get_texture().get_image().save_png(EVIDENCE+"wind-profile.png")
 var label_="profile"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label_=arg.trim_prefix("--label=")
 var result={"checks":checks,"failures":failures,"phases":report,"renderer":RenderingServer.get_video_adapter_name(),"enemies":240,"note":"Controlled fixture; high target HP prevents workload loss. Manual step timing excludes full world logic; first-use and warmed phases are separate. Zero Metal GPU timestamps mean unavailable."}
 FileAccess.open(EVIDENCE+label_+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
