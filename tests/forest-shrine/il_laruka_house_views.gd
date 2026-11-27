extends SceneTree
## Unobstructed, identical four-corner views of every source building silhouette.
const Art=preload("res://scripts/forest/forest_il_laruka_art.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Il and Laruka/Details/"

func _initialize():
 create_timer(90).timeout.connect(func():printerr("HOUSE_VIEWS_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 root.size=Vector2i(960,900)
 var stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("9baca7")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("e4e6da");environment.environment.ambient_light_energy=.8
 stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=1.2;stage.add_child(light)
 var camera=Camera3D.new();camera.fov=48;stage.add_child(camera)
 var phase="Before" if "--baseline" in OS.get_cmdline_user_args() else "After"
 var folder=REVIEW+phase+"/Models/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var count=0
 for serial in Art.Data.BUILDINGS:
  var house=Node3D.new();stage.add_child(house);Art.build_building(house,Vector3.ZERO,serial)
  var g:Dictionary=Art.Data.GRAPHICS[str(serial)]
  var radius=maxf(g.footprint[0],g.footprint[1])*1.5+12
  var directions=[Vector3(-1,.8,1),Vector3(1,.8,1),Vector3(1,.8,-1),Vector3(-1,.8,-1)]
  for i in directions.size():
   camera.position=directions[i]*radius+Vector3.UP*4;camera.look_at(Vector3.UP*5)
   for frame in 4:await process_frame
   await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png(folder+"%d-%d.png"%[serial,i])==OK)
   count+=1
  house.queue_free();await process_frame
 print("IL_LARUKA_HOUSE_VIEWS captures=",count)
 quit()
