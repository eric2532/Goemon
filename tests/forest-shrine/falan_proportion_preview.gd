extends SceneTree
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Architecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const Special=preload("res://scripts/forest/forest_falan_special_exteriors.gd")
const Workshop=preload("res://scripts/forest/forest_falan_workshop.gd")
const Magic=preload("res://scripts/forest/forest_falan_magic_shop.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan Proportions/"
var stage:Node3D
var camera:Camera3D
var failures=0

func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1440,900)
 stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("596b64");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;stage.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);stage.add_child(light)
 camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT
 camera.size=900.0/(sqrt(2.0)*Fit.HORIZONTAL)
 for serial in Architecture.Data.GRAPHICS:
  var model=Node3D.new();model.rotation.y=PI*.5;stage.add_child(model)
  var node=MeshInstance3D.new();node.mesh=Architecture.prepare(serial);model.add_child(node)
  await capture(model,"house_%d"%serial,Fit.mesh_points(node.mesh))
 for anchor in Special.SPECS:
  var row:Array=Special.SPECS[anchor];var model=MeshInstance3D.new();model.mesh=Special.prepare(row);model.rotation.y=row[7];stage.add_child(model);await capture(model,"special_%d"%row[0],Fit.mesh_points(model.mesh))
 for row in [["special_10301",Workshop.prepare()],["special_10075",Magic.prepare()]]:
  var model=MeshInstance3D.new();model.mesh=row[1];stage.add_child(model);await capture(model,row[0],Fit.mesh_points(model.mesh))
 for anchor in Civic.SHELLS:
  var spec:Array=Civic.SHELLS[anchor]
  Fit.enabled=false;Civic.build(stage,Vector3.ZERO,spec);Fit.enabled=true
  var model:Node3D=stage.get_children()[-1];model.position=Vector3.ZERO
  var raw=Fit.node_points(model);var pose:Transform3D=Fit.Data.FITS["civic_%d"%spec[0]]
  var points:Array[Vector3]=[]
  for p in raw:points.append(pose*p)
  Fit.apply(model,"civic_%d"%spec[0]);await capture(model,"civic_%d"%spec[0],points)
 print("FALAN_PROPORTION_PREVIEW failures=",failures);quit(1 if failures else 0)

func capture(model:Node3D,key:String,points:Array[Vector3]):
 var rect:Rect2=Fit.References.RECTS[key]
 var measured=Fit.projected_bounds(points,Transform3D(model.basis,Vector3.ZERO))
 if measured.position.distance_to(rect.position)>.05 or measured.size.distance_to(rect.size)>.05:failures+=1;printerr("PROPORTION_FAIL ",key," ",measured," != ",rect)
 var center=rect.get_center();var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
 camera.position=at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100);camera.look_at(at)
 for i in 6:await process_frame
 var viewport=Vector2(root.get_visible_rect().size)
 var pixel=camera.unproject_position(model.global_transform*points[0])
 var expected=viewport*.5+Fit.project(model.basis*points[0])-rect.get_center()
 if pixel.distance_to(expected)>.1:failures+=1;printerr("CAMERA_SCALE_FAIL ",key," ",pixel," != ",expected)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+"matched-"+key+".png")
 if DisplayServer.get_name()!="headless":
  var bounds=AABB(model.basis*points[0],Vector3.ZERO)
  for p in points:bounds=bounds.expand(model.basis*p)
  var target=bounds.get_center()
  camera.position=target+Vector3(-100,100*sqrt(2.0)*tan(asin(.75)),-100);camera.look_at(target)
  for i in 6:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+"reverse-"+key+".png")
 print("SOURCE_MATCH ",key," rect=",measured)
 model.queue_free();await process_frame
