extends SceneTree
## Real native textures, vertex widths/colors, emission timing and detached tail
## expiry verify the contrail renderer without substituting a fake data source.
var checks=0
var failures=0
var trails
var data
var container:Node3D
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func meshes()->Array:
 return container.get_children().filter(func(n):return n is MeshInstance3D and n.visible and n.mesh!=null)
func run():
 check(ResourceLoader.exists("res://scripts/halo_effect_trails.gd"),"Native contrail renderer exists")
 if failures:finish();return
 data=load("res://scripts/halo_effect_data.gd").new()
 trails=load("res://scripts/halo_effect_trails.gd").new()
 container=Node3D.new();root.add_child(container);root.add_child(trails)
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,0,20)
 trails.configure(data,container,camera,1)
 var native=data.resolve("weapons\\assault rifle\\bullet.contrail","contrail")
 check(not native.is_empty(),"Real native assault rifle contrail resolves")
 var definition=native.duplicate(true)
 # A deterministic native state interval lets vertex evaluation be measured
 # independently of stochastic duration and source-point movement.
 definition.point_creation.generation_rate=10.0
 definition.point_creation.velocity={"from":0,"to":0}
 definition.point_states=[{"state_duration":{"from":1,"to":1},"state_transition_duration":{"from":0,"to":0},"width":.1,"color_lower_bound":{"a":.2,"r":0,"g":0,"b":1},"color_upper_bound":{"a":1,"r":1,"g":.5,"b":0},"scale_flags":0}]
 definition.flags=3
 trails.start(1,definition,Vector3.ZERO,Vector3.RIGHT)
 trails.move(1,Vector3(3,0,0),Vector3.RIGHT,.3);trails.tick(.3)
 check(trails.live_count()==1,"A moving owner retains one live native trail")
 check(meshes().size()==1,"Same texture ribbons batch into one mesh")
 if not meshes().is_empty():
  var node=meshes()[0];var arrays=node.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
  check(vertices.size()==18,"Ten points per second generates three segments over .3 seconds")
  check(is_equal_approx(vertices[0].distance_to(vertices[1]),.3048),"Ribbon width converts the native .1 Halo-unit state width")
  check(colors[0].r>.99 and absf(colors[0].g-.5)<.005 and colors[0].b<.005 and colors[0].a>.99,"Unscaled native contrail tint uses upper bound rather than per-frame randomness")
  check(node.layers==1,"World trail mesh uses the requested render layer")
  var material=node.material_override
  var texture=material.get_shader_parameter("atlas")
  var frame=data.bitmap_frame(native.rendering.bitmap)
  check(texture==frame.texture,"Ribbon shader binds the original recovered native tracer bitmap")
  if DisplayServer.get_name()!="headless":
   await process_frame;await process_frame
   var capture="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/master-chief-weapons/native-contrail-test.png"
   root.get_texture().get_image().save_png(capture)
 trails.start(2,definition,Vector3(0,1,0),Vector3.RIGHT)
 trails.move(2,Vector3(3,1,0),Vector3.RIGHT,.3);trails.tick(.3)
 check(meshes().size()==1,"Two owners sharing a native texture still use one mesh")
 trails.stop(1);trails.stop(2);trails.tick(1.1)
 check(trails.live_count()==0 and meshes().is_empty(),"Stopped trails expire through their native state lifetimes")
 trails.start(3,definition,Vector3.ZERO,Vector3.RIGHT)
 trails.move(3,Vector3(3,0,0),Vector3.RIGHT,.3);trails.tick(.01)
 trails.clear()
 check(trails.live_count()==0 and meshes().is_empty(),"Clear removes visible geometry and owner state immediately")
 # Actual AR points live only .01-.0125 seconds. A high-frame-rate simulation
 # must retain a dead endpoint until a new point can form a visible segment.
 trails.streak(native,Vector3.ZERO,Vector3(90,0,0))
 var seen=false
 for frame in 40:
  trails.tick(1.0/240.0)
  seen=seen or not meshes().is_empty()
 check(seen,"A native AR tracer produces textured geometry even at 240 Hz")
 trails.tick(.1)
 check(trails.live_count()==0,"Native bullet flight and short point lifespan leave no persistent beam")
 # Rocket rate15/sec and multi-state smoke make a persistent detached ribbon.
 var rocket=data.resolve("weapons\\rocket launcher\\exhaust","contrail")
 trails.start(4,rocket,Vector3.ZERO,Vector3.RIGHT)
 for frame in 30:
  trails.move(4,Vector3(frame*.2,0,0),Vector3.RIGHT,1.0/60.0);trails.tick(1.0/60.0)
 check(not meshes().is_empty(),"Native rocket exhaust renders its original textured ribbon")
 trails.stop(4);trails.tick(4.0)
 check(trails.live_count()==0 and meshes().is_empty(),"Detached rocket exhaust drains completely after final native state")
 trails.clear();trails.free();container.free();camera.free();data=null;finish()
func finish():
 await process_frame;await process_frame
 print("HALO_EFFECT_TRAILS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
