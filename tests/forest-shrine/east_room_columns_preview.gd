extends SceneTree
## Geometry/material preview only; actual map-camera review is separate.
const Columns=preload("res://scripts/forest/forest_east_room_columns.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Room Columns/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 root.size=Vector2i(1440,900);root.title="Cross Gate · Native Room Columns"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("243039")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dae4e3");environment.environment.ambient_light_energy=.65
 stage.add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.0;stage.add_child(sun)
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/east/catalog.json"))
 var observations=[]
 for index in Columns.IDS.size():
  var serial:int=Columns.IDS[index];var mesh=Columns.mesh(serial,catalog.graphics[str(serial)])
  check(mesh.get_surface_count()==2,"Native front and independent closed body "+str(serial))
  check(is_equal_approx(mesh.get_aabb().size.y,float(Columns.data().graphics[str(serial)].height)),"Physical native height "+str(serial))
  var node=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3((index%6-2.5)*7.,0,(index/6-1)*11.);stage.add_child(node)
  observations.append({"graphic":serial,"bounds":var_to_str(mesh.get_aabb()),"source_rgba_sha256":Columns.data().graphics[str(serial)].source_rgba_sha256})
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var index=0
 for eye in [Vector3(-34,28,50),Vector3(34,28,-50)]:
  camera.position=eye;camera.look_at(Vector3(0,3.8,0));camera.reset_physics_interpolation();root.grab_focus()
  for frame in 12:await process_frame
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(OUT+"columns-"+("normal" if index==0 else "second")+".png")==OK,"Captured geometry preview")
  index+=1
 var file=FileAccess.open(OUT+"preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"columns":observations,"scope":"18 prepared/native column assets only; no actual map-camera or route claim."},"  "));file.close()
 print("EAST_ROOM_COLUMNS_PREVIEW_RESULT checks=",checks," failures=",failures)
 quit(failures)
