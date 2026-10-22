extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func run():
 var stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("cbd4d2")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dce3e0");environment.environment.ambient_light_energy=.7;stage.add_child(environment)
 for spec in [[Vector3(-35,-30,0),1.5],[Vector3(-25,145,0),.7]]:
  var light=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_energy=spec[1];stage.add_child(light)
 var floor=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(100,50)
 var material=StandardMaterial3D.new();material.albedo_color=Color("b8c6c1");floor.material_override=material;floor.position.y=-.03;stage.add_child(floor)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=33;camera.position=Vector3(0,11,-70);camera.far=1000;stage.add_child(camera);camera.look_at(Vector3(0,11,0));camera.current=true
 var specs=[["daruma_massive",0.0,"MASSIVE DARUMA / 4×"],["daruma_previous",23.0,"PREVIOUS DARUMA / 1×"],["goemon",-23.0,"GOEMON"]]
 for spec in specs:
  var resource=load("res://assets/"+spec[0]+".glb")
  if not resource is PackedScene:failures+=1;continue
  var model=resource.instantiate();model.position.x=spec[1];stage.add_child(model)
  for node in model.find_children("*","MeshInstance3D",true,false):
   if "Hair_Gold" in node.name:node.hide()
  var label=Label3D.new();label.text=spec[2];label.position=Vector3(spec[1],-1.5,0);label.font_size=64;label.pixel_size=.017;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("23392e");label.outline_modulate=Color("dfe5e2");stage.add_child(label)
 for i in range(8):await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  if root.get_texture().get_image().save_png("res://../massive-daruma-scale-comparison.png")!=OK:failures+=1
 print("MASSIVE_DARUMA_PREVIEW_RESULT failures=",failures);quit(1 if failures else 0)
