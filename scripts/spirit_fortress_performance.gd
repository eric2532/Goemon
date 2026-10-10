extends SceneTree
var game
var report=[]
var label="probe"
var quality=1
var output_path=""
func _initialize():run.call_deferred()
func stats(a:Array):
 var sum=0.0
 for v in a:sum+=v
 a.sort()
 return {"mean":sum/a.size(),"median":a[a.size()/2],"p95":a[int(a.size()*.95)],"max":a[-1]}
func sample(name:String):
 if "--active" in OS.get_cmdline_user_args():
  game.tuning.freeze_ai=false
  for i in range(game.enemies.size()):
   var actor=game.enemies[i]
   actor.position=Vector3((float(i%12)-5.5)*1.2,.15,190-float(i/12)*1.4)
   actor.velocity=Vector3.ZERO;actor.state="march";actor.defense_waypoint=1
   actor.set_physics_process(true)
 var warm=Time.get_ticks_msec()+2000
 while Time.get_ticks_msec()<warm:await process_frame
 var data={"frame_ms":[],"process_ms":[],"physics_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[],"primitives":[]}
 var last=Time.get_ticks_usec()
 var until=last+3000000
 while Time.get_ticks_usec()<until:
  await process_frame
  var now=Time.get_ticks_usec();data.frame_ms.append((now-last)/1000.0);last=now
  data.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  data.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  data.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())
  data.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  data.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  data.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 var row={"name":name,"label":label,"engine":Engine.get_version_info().string,"quality":quality,"viewport":str(root.size),"render_size":str(root.get_texture().get_size()),"frames":data.frame_ms.size(),"enemies":game.enemies.size()}
 for key in data:row[key]=stats(data[key])
 report.append(row);print("PROFILE ",JSON.stringify(row))
func run():
 if DisplayServer.get_name()=="headless":quit(2);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
  if arg.begins_with("--quality="):quality=int(arg.trim_prefix("--quality="))
 game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
 game.tuning.freeze_ai=true;game.tuning.invincible=true;game.settings.quality=quality
 game.start_mode("defense");game.apply_quality();game.encounters.set_physics_process(false)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,800)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if "--vsync" in OS.get_cmdline_user_args() else DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false);game.camera_rig.set_process_unhandled_input(false)
 game.player.set_physics_process(false)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var fx=game.world.get_node_or_null("SpiritFortressEffects")
 var crowded="--crowd" in OS.get_cmdline_user_args()
 if crowded:
  var s=game.encounters
  s.update_start_input(0,false)
  s.update_start_input(3.1,true)
  var population=300 if "--300" in OS.get_cmdline_user_args() else 180
  s._spawn_due(population)
  assert(game.enemies.size()==population,"Crowd benchmark must contain the requested real actors")
  for i in range(game.enemies.size()):
   var actor=game.enemies[i]
   actor.position=Vector3((float(i%12)-5.5)*1.2,.15,190-float(i/12)*1.4)
   actor.hp=100000;actor.max_hp=100000
   actor.set_physics_process(false)
 var locations=["crowd"] if crowded else ["spawn","shrine"]
 for location in locations:
  game.camera_rig.camera.global_position=Vector3(10,8,210) if location!="shrine" else Vector3(10,8,315)
  game.camera_rig.camera.look_at(Vector3(0,2,195) if location!="shrine" else Vector3(0,2,300))
  if fx:
   var shadow_probe="--shadows" in OS.get_cmdline_user_args()
   var geometries=fx.find_children("*","GeometryInstance3D",true,false)
   var shadows=[]
   for n in geometries:shadows.append(n.cast_shadow)
   for state in (["on","shadowless","on"] if shadow_probe else ["on","off","on"]):
    for i in range(geometries.size()):geometries[i].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if state=="shadowless" else shadows[i]
    fx.apply_quality(quality if state=="on" else 0)
    if state=="shadowless":fx.apply_quality(quality)
    await sample(location+"_"+state)
  else:await sample(location+"_baseline")
 if output_path.is_empty():output_path=ProjectSettings.globalize_path("user://spirit-performance/"+label+".json")
 DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
 FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.sound_library.cancel();game.music.stop();game.queue_free()
 for i in range(5):await process_frame
 quit()
