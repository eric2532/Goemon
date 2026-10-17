extends SceneTree
var stage: Node3D
var camera: Camera3D
var models=[]
var failures=0
func check(ok: bool,message: String):
 if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
 stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("cbd4d2")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dce3e0");environment.environment.ambient_light_energy=.7
 stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.5;stage.add_child(light)
 var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,145,0);fill.light_energy=.7;stage.add_child(fill)
 var floor=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(70,35)
 var floor_mat=StandardMaterial3D.new();floor_mat.albedo_color=Color("b8c6c1");floor.material_override=floor_mat;floor.position.y=-.02;stage.add_child(floor)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15;camera.position=Vector3(0,3.6,-30);stage.add_child(camera);camera.look_at(Vector3(0,3.4,0));camera.current=true
 var slugs=["masked_raider","reed_archer","daruma_breaker","lantern_runner","goemon"]
 var xs=[12,6,-1,-7,-12]
 for i in slugs.size():
  var slug=slugs[i];var resource=load("res://assets/"+slug+".glb")
  check(resource is PackedScene,slug+" imports as a usable 3D scene")
  if not resource is PackedScene:continue
  var model=resource.instantiate();stage.add_child(model);model.position.x=xs[i];models.append(model)
  for node in model.find_children("*","MeshInstance3D",true,false):
   if "Hair_Gold" in node.name:node.hide()
   for s in node.mesh.get_surface_count():
    var material=node.mesh.surface_get_material(s)
    check(material!=null,slug+" imports materials")
  var label=Label3D.new();label.text=slug.replace("_"," ").to_upper();label.font_size=64;label.pixel_size=.007;label.position=Vector3(xs[i],-.58,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("23392e");label.outline_modulate=Color("dfe5e2");stage.add_child(label)
 for i in range(8):await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("res://../exported-model-lineup.png")==OK,"Exported lineup capture saves")
  for i in range(4):
   var slug=slugs[i]
   for j in range(models.size()):models[j].visible=j==i
   models[i].position.x=0
   camera.size=7;camera.position=Vector3(7,3.3,-12);camera.look_at(Vector3(0,3,0))
   for frame in range(5):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../"+slug+"-godot-three-quarter.png")
   models[i].position.x=xs[i]
 print("EXPORTED_ENEMY_PREVIEW_RESULT failures=",failures)
 quit(1 if failures else 0)
