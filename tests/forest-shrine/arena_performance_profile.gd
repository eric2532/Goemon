extends SceneTree
class Field extends "res://scripts/forest/forest_game.gd":
 func _sync_camera_mouse():
  if is_instance_valid(camera_rig):camera_rig.sync_character_view()
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
func _initialize():
 create_timer(240).timeout.connect(func():printerr("ARENA_PROFILE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var args=OS.get_cmdline_user_args()
 seed(71114)
 var label_="latest"
 for arg in args:
  if arg.begins_with("--label="):label_=arg.trim_prefix("--label=")
 assert(label_.is_valid_filename())
 var size_="Large" if "--large" in args else "Standard"
 var path="res://assets/maps/forest_wind_meadow_large.json" if size_=="Large" else "res://assets/maps/forest_wind_meadow.json"
 if DisplayServer.get_name()=="headless":printerr("This profile requires desktop rendering");quit(2);return
 var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 set_meta("forest_custom_layout",layout)
 set_meta("forest_fighter",34)
 set_meta("forest_painterly_preview",true)
 root.size=Vector2i(1280,800)
 root.title="Goemon · Live Slime Audit · "+size_
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
 DisplayServer.window_move_to_foreground()
 var game=Field.new()
 game.settings_path="user://slime-audit-%d.cfg"%OS.get_process_id()
 root.add_child(game)
 current_scene=game
 game.model.team_progression.cards_enabled=false
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 game.army_runtime.collect_stats=true
 game.tuning.invincible=true
 var army=game.army_runtime
 army.profile_enabled=true
 var viewport=root.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(viewport,true)
 if not game.combat_warmup.complete:await game.combat_warmup.finished
 root.grab_focus()
 var focus_deadline=Time.get_ticks_msec()+20000
 while not DisplayServer.window_is_focused() and Time.get_ticks_msec()<focus_deadline:await process_frame
 if not DisplayServer.window_is_focused():printerr("Slime audit did not receive focus");quit(2);return
 assert(army.navigation_revision==game.model.navigation_revision,"Arena navigation must be prepared before START")
 game.start_wave()
 if "--late-wave" in args:
  game.model.wave=11;game.model.waves.released_waves=11
 var started=Time.get_ticks_usec()
 var previous=started
 var next_print=0.0
 var rows=[]
 var samples=[]
 var kernel_samples=[]
 var spikes=[]
 var phase_totals={}
 var steady_count=0
 army.native.simulation_profile(true)
 while true:
  army.profile_totals.clear()
  await process_frame
  var now=Time.get_ticks_usec()
  var seconds=(now-started)*.000001
  var ms=(now-previous)*.001
  previous=now
  var phase:Dictionary=army.profile_totals
  if seconds>=80:
   steady_count+=1
   for key in phase:phase_totals[key]=float(phase_totals.get(key,0.0))+float(phase[key])
  var live:int=game.model.enemies.size()
  var focused=DisplayServer.window_is_focused()
  var gpu=RenderingServer.viewport_get_measured_render_time_gpu(viewport)
  var render_cpu=RenderingServer.viewport_get_measured_render_time_cpu(viewport)
  samples.append([seconds,ms,live,focused,phase.get("native_step",0.0),phase.get("game_world_tick",0.0),render_cpu,gpu])
  if ms>=50.0 and spikes.size()<60:
   spikes.append({"seconds":seconds,"ms":ms,"live":live,"focused":focused,"phases_ms":phase.duplicate()})
  if seconds>=next_print:
   var kernel:Dictionary=army.native.simulation_profile(army.profile_enabled)
   var bucket={"seconds":seconds,"steps":kernel.steps,"phases_ms":phase.duplicate()}
   for key in ["total_ms","grid_ms","decisions_ms","movement_ms","combat_ms","animation_ms"]:
    bucket[key]=float(kernel[key])/maxi(1,int(kernel.steps))
   for key in ["nav_route_ms","nav_flow_ms","nav_topology_ms"]:
    bucket[key]=float(kernel[key])/maxi(1,int(kernel.steps))
   for key in ["nav_route_hits","nav_waypoints","nav_flow_builds","nav_topology_builds","nav_segments","nav_heights"]:
    bucket[key]=kernel[key]
   kernel_samples.append(bucket)
   next_print+=10
   rows.append([seconds,live,game.model.wave,army.simulation_seconds,Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),OS.get_static_memory_usage()])
   print("SLIME_LIVE ",rows.back())
  if seconds>=110.0:break
 var report={"map":size_,"painterly":game.painterly_preview,"native":army.native!=null,"resolution":[root.size.x,root.size.y],"vsync":DisplayServer.window_get_vsync_mode(),"map_hash":FileAccess.get_sha256(path),"rows":rows,"samples":samples,"spikes":spikes,"native_per_step":kernel_samples,"phase":game.model.phase,"roster_cap":game.model.waves.active_cap(),"frame_columns":["seconds","interval_ms","live","focused","native_ms","world_tick_ms","render_cpu_ms","render_gpu_ms"]}
 var folder=ProjectSettings.globalize_path("res://build/Other Files/Asset Toolkit/Performance Review 2026-11-14/").path_join(label_+"-"+size_)
 DirAccess.make_dir_recursive_absolute(folder)
 report.counts=army.observed_counts;report.event_gaps=army.event_gaps
 report.late_wave="--late-wave" in args
 for key in phase_totals:phase_totals[key]/=maxi(1,steady_count)
 report.steady_phases_ms=phase_totals
 var ui_costs=[]
 for i in 100:
  var ui_start=Time.get_ticks_usec();game.forest_ui.sync();ui_costs.append(Time.get_ticks_usec()-ui_start)
 ui_costs.sort();report.hud_sync_us={"p50":ui_costs[50],"p95":ui_costs[95]}
 var frames=samples.filter(func(s):return s[0]>=80).map(func(s):return s[1])
 report.steady=Metrics.summary(frames);report.steady.frames=frames.size()
 report.failures=[]
 if samples.any(func(s):return not s[3]):report.failures.append("Window lost focus")
 if game.model.phase!="wave" or army.event_gaps!=0:report.failures.append("Battle stopped or lost events")
 if absf(army.simulation_seconds-samples.back()[0])>.5:report.failures.append("Simulation fell behind wall time")
 if report.late_wave and samples.any(func(s):return s[0]>=80 and s[2]!=game.model.waves.active_cap()):report.failures.append("Full enemy population was not maintained")
 if report.steady.p95_ms>25 or report.steady.p99_ms>50:report.failures.append("Steady frame pacing exceeded the existing benchmark limits")
 print("ARENA_PROFILE ",JSON.stringify(report.steady)," native=",JSON.stringify(kernel_samples.back())," hud=",JSON.stringify(report.get("hud_sync_us",{}))," phases=",JSON.stringify(phase_totals))
 FileAccess.open(folder.path_join("live.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
 root.get_texture().get_image().save_png(folder.path_join("live.png"))
 var cfg=game.settings_path
 game.queue_free()
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 if not report.failures.is_empty():printerr(JSON.stringify(report.failures))
 quit(0 if report.failures.is_empty() else 1)
