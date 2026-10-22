extends SceneTree
## Detects native materials being repainted, dark-map leakage, and rebuilds on ordinary sync.
var failures=0
var checks=0
func _initialize():
 create_timer(25).timeout.connect(func():printerr("FAIL: environment test timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label_)
func run():
 var environment_script=load("res://scripts/forest/blood_gulch_environment.gd")
 check(environment_script!=null,"Blood Gulch has a dedicated daytime environment adapter")
 if environment_script==null:quit(1);return
 var model=load("res://scripts/forest/forest_model.gd").new()
 var layout={"buildings":[{"kind":"gate","x":0,"z":7,"rotation":0},{"kind":"tower","x":-5,"z":7,"rotation":0}],"roads":[{"x":0,"z":2}],"trees":[],"deposits":[]}
 model.reset(42,{},layout);model.workers.clear()
 var world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world);await process_frame
 var environment:WorldEnvironment
 var sun:DirectionalLight3D
 for node in world.get_children():
  if node is WorldEnvironment:environment=node
  if node is DirectionalLight3D:sun=node
 var baseline=environment.environment
 var sunlight=[sun.rotation,sun.light_color,sun.light_energy]
 # Use an ordinary map first, then the map identity. This isolates style lifecycle
 # checks from the native bake while the real terrain builder gets separate tests.
 model.terrain_source="blood_gulch"
 world.apply_map_environment()
 check(environment.environment.background_mode==Environment.BG_SKY and environment.environment.sky!=null,"Native map presents a daytime sky")
 check(environment.environment.sky.sky_material is ProceduralSkyMaterial,"Native map presents clear blue procedural sky")
 check(environment.environment.ambient_light_energy>=.7 and environment.environment.tonemap_mode==Environment.TONE_MAPPER_LINEAR,"Native map retains bright sky fill without dark filmic compensation")
 var native=Node3D.new();native.name="BloodGulchTerrain";native.set_meta("native_terrain",true);world.map_features.add_child(native)
 var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();var original=StandardMaterial3D.new();mesh.material_override=original;native.add_child(mesh)
 world.set_painterly_preview(true)
 check(mesh.material_override==original,"Painterly treatment preserves native surface materials")
 check(environment.environment.background_mode==Environment.BG_SKY and environment.environment.ambient_light_energy>=.7,"Painterly activation preserves bright native environment")
 var bright=environment.environment
 for i in 4:model.revision+=1;world.sync(0)
 check(environment.environment==bright,"Ordinary world sync retains the environment resource")
 world.set_painterly_preview(false)
 check(environment.environment.background_mode==Environment.BG_SKY,"Painterly disable preserves native daytime")
 model.terrain_source="flat";world.apply_map_environment()
 check(environment.environment==baseline and [sun.rotation,sun.light_color,sun.light_energy]==sunlight,"Leaving Blood Gulch restores exact original environment and sun")
 world.set_painterly_preview(true)
 var painted=environment.environment
 model.terrain_source="blood_gulch";world.apply_map_environment()
 world.set_painterly_preview(false)
 model.terrain_source="flat";world.apply_map_environment()
 check(environment.environment==baseline,"Native to painterly toggle restores the original map baseline")
 world.set_painterly_preview(true)
 check(environment.environment!=baseline and environment.environment.background_mode==painted.background_mode,"Legacy painterly environment can be reapplied after native transitions")
 world.set_painterly_preview(false);world.queue_free();await process_frame
 print("BLOOD_GULCH_ENVIRONMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
