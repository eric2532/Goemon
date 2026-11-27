extends "res://tests/forest-shrine/falan_proportion_preview.gd"
const OUT_KIT="res://build/Other Files/Asset Toolkit/Falan City Reconstruction/Visual Continuation/kit-pilot/"
func _initialize():
 root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);root.grab_focus()
 create_timer(300).timeout.connect(func():printerr("FALAN_KIT_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_KIT))
 stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("596b64");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;stage.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);stage.add_child(light)
 camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT
 for serial in [10003,10079,10082,10080,10310,10050,10605]:
  var row:Array=Architecture.Data.GRAPHICS[serial]
  var raw=Architecture.HouseParts.surface_mesh(Architecture.HouseParts.shape("falan_townhouse",row[8],serial),Basis(Vector3.UP,0.0 if row[3]==1 else -PI*.5))
  var pose=Fit.measure(Fit.mesh_points(raw),"house_%d"%serial,Basis(Vector3.UP,PI*.5))
  var model=MeshInstance3D.new();model.mesh=Fit.transformed(raw,pose);model.rotation.y=PI*.5;stage.add_child(model)
  var rect:Rect2=Fit.References.RECTS["house_%d"%serial];var center=rect.get_center()
  var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
  camera.size=900/(sqrt(2.0)*Fit.HORIZONTAL);camera.position=at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100);camera.look_at(at)
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  var im=root.get_texture().get_image();var crop=Rect2i((Vector2(im.get_size())-rect.size)*.5-Vector2.ONE*8,rect.size+Vector2.ONE*16)
  im.get_region(crop).save_png(OUT_KIT+"house_%d.png"%serial)
  var bounds=AABB(model.basis*model.mesh.get_aabb().position,Vector3.ZERO)
  for p:Vector3 in Fit.mesh_points(model.mesh):bounds=bounds.expand(model.basis*p)
  at=bounds.get_center();camera.size=maxf(bounds.size.x+bounds.size.z,bounds.size.y*1.7)*1.05
  camera.position=at+Vector3(-65,35,-65);camera.look_at(at)
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  im=root.get_texture().get_image();im.resize(960,600,Image.INTERPOLATE_LANCZOS);im.save_png(OUT_KIT+"house_%d-rear.png"%serial)
  print("FALAN_KIT_REVIEW ",serial)
  model.queue_free();await process_frame
 quit()
