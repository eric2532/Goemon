extends SceneTree
const Details=preload("res://scripts/forest/forest_falan_street_details.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan City Details/Planter Recovery/"

func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1200,900)
 var stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("9eae9a")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
 stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);light.shadow_enabled=true;stage.add_child(light)
 var plane=PlaneMesh.new();plane.size=Vector2(30,30);Geo.mesh(stage,plane,Vector3(0,-.02,0),Geo.mat("82927c"))
 var camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(-6,5,7);camera.look_at(Vector3.UP*.85);camera.fov=38
 for serial in [10426,10427,10452,10453]:
  var prop=Node3D.new();stage.add_child(prop)
  Details.place(prop,serial,Vector3.ZERO);Geo.mesh(prop,Details.foliage(serial),Vector3.ZERO,null)
  for facing in [0,1]:
   prop.rotation.y=facing*PI
   for i in 10:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"preview-%d-%d.png"%[serial,facing])
  prop.queue_free();await process_frame
 print("FALAN_PLANTER_PREVIEW_DONE")
 quit()
