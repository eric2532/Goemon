extends SceneTree
## Native same-process comparison: identical frozen actors, camera and lighting.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Renderer=preload("res://scripts/forest/ally_rigid_renderer.gd")
const DEFAULT_OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Smooth Gameplay/ally-rigid-native"
var output=DEFAULT_OUT
var renderer
var actors=[]
var report=[]
var failures=0
var camera:Camera3D
func _initialize():
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--out="):output=argument.trim_prefix("--out=")
 create_timer(90).timeout.connect(func():printerr("FAIL: Native instancing profile timed out");quit(1))
 run.call_deferred()
func frames(count:int):
 for i in count:await process_frame
func capture(label_:String):
 await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(output+"/"+label_+".png")
func measure(label_:String,enabled_:bool):
 renderer.set_enabled(enabled_)
 await frames(45)
 var times=[];var sync_times=[];var previous=Time.get_ticks_usec()
 for i in 120:
  await process_frame
  var start=Time.get_ticks_usec()
  if enabled_:renderer.sync()
  sync_times.append((Time.get_ticks_usec()-start)/1000.0)
  var now=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
 times.sort();sync_times.sort()
 var row={"stage":label_,"actors":actors.size(),"median_ms":times[60],"p95_ms":times[114],"sync_median_ms":sync_times[60],"sync_p95_ms":sync_times[114],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
 report.append(row);print("ALLY_RIGID_NATIVE ",JSON.stringify(row))
 await capture(label_)
func run():
 if DisplayServer.get_name()=="headless":printerr("Native renderer required");quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,800);DisplayServer.window_set_size(Vector2i(1280,800));DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 print("ALLY_RIGID_VIEWPORT ",JSON.stringify({"size":str(root.size),"visible":str(root.get_visible_rect().size),"texture":str(root.get_texture().get_size())}))
 var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("435e4e")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("aebfce");env.ambient_light_energy=.58;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=1.05
 var environment=WorldEnvironment.new();environment.environment=env;root.add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-42,0);sun.light_color=Color("ffdaa0");sun.light_energy=1.35;root.add_child(sun)
 var scene=Node3D.new();root.add_child(scene)
 Geo.box(scene,Vector3(0,-.25,0),Vector3(85,.5,85),Geo.mat("73856b"))
 renderer=Renderer.new();scene.add_child(renderer);renderer.set_process(false)
 var kits=["dragoon","ranger","ranger","ranger","ninja","ninja","ninja","ninja","ninja","knight","explorer","explorer"]
 for i in 120:
  var actor=Actor.new();scene.add_child(actor);actor.setup(kits[i%12])
  actor.position=Vector3((i%12-5.5)*3.6,0,(i/12-4.5)*4.1);actor.rotation.y=.3*sin(i)
  for mesh in actor.model.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var pose={"grounded":true,"isPlayer":true}
  if i%4==0:pose.attack={"style":"cutlass","primary":true,"duration":.4,"contact":.12,"time":.12,"index":0}
  actor.animate_pose(pose,.016,i*.13,0)
  renderer.register_actor(actor);actors.append(actor)
 camera=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=51;camera.position=Vector3(0,36,49);camera.look_at(Vector3(0,1,0));camera.current=true
 await measure("native",false)
 await measure("instanced",true)
 await measure("native_restored",false)
 if report[1].draws>=report[0].draws-300:failures+=1;printerr("FAIL: Equipment instancing did not remove the repeated material draws")
 # Close view of all five kits with the same original nodes and material values.
 for i in actors.size():
  actors[i].hide()
 var selected=[0,1,4,9,10]
 for column in selected.size():
  var actor=actors[selected[column]];actor.show();actor.position=Vector3((column-2)*3.2,0,0)
 camera.size=18;camera.position=Vector3(0,7,19);camera.look_at(Vector3(0,1.2,0))
 renderer.set_enabled(false);await frames(6);await capture("close_native")
 renderer.set_enabled(true);await frames(6);await capture("close_instanced")
 # Mix perspective depths and scales to verify that native geometry keeps its
 # individual distance-detail choices while materials use shared identities.
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=55
 camera.position=Vector3(0,4,12);camera.look_at(Vector3(0,1,-15))
 for column in selected.size():
  var actor=actors[selected[column]]
  actor.position=Vector3((column-2)*4,0,-column*11);actor.scale=Vector3.ONE*(1+column*.15)
 renderer.set_enabled(false);await frames(6);await capture("perspective_native")
 renderer.set_enabled(true);await frames(6);await capture("perspective_instanced")
 print("ALLY_RIGID_PERSPECTIVE ",JSON.stringify({"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
 # Private emission and ultimate overlay effects must match while neighbors keep
 # their shared baseline. Capture the same frozen effect states in both modes.
 actors[4].flash_hit(Color.RED,1.1);actors[4].animate_pose({"grounded":true},.016,1.1,0)
 actors[9].animate_pose({"grounded":true,"buffTime":1.0},.016,1.1,0)
 renderer.set_enabled(false);await frames(6);await capture("effects_native")
 renderer.set_enabled(true);await frames(6);await capture("effects_instanced")
 var file=FileAccess.open(output+"/profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 renderer.set_enabled(false);scene.free();environment.free();sun.free();camera.free()
 await process_frame
 print("ALLY_RIGID_NATIVE_RESULT failures=",failures);quit(1 if failures else 0)
