extends SceneTree
const Architecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan Architecture/"

func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1440,900)
 var stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("9eae9a")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
 stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);light.shadow_enabled=true;stage.add_child(light)
 var plane=PlaneMesh.new();plane.size=Vector2(100,100);Geo.mesh(stage,plane,Vector3(0,-.02,0),Geo.mat("82927c"))
 var camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(-30,29,30);camera.look_at(Vector3.UP*6);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=34
 for serial in Architecture.Data.GRAPHICS:
  var node=MeshInstance3D.new();node.mesh=Architecture.prepare(serial);stage.add_child(node)
  for side in [0,1]:
   node.rotation.y=PI*side
   for i in 8:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"shape-%d-%d.png"%[serial,side])
  node.queue_free();await process_frame
 print("FALAN_ARCHITECTURE_PREVIEW_DONE")
 quit()
