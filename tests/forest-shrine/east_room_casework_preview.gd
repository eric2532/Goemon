extends SceneTree
## Asset study before map activation; original scene routes are not exercised here.
const Fixtures=preload("res://scripts/forest/forest_east_room_casework.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Room Casework/"
var checks=0
var failures=0
func _initialize():
 create_timer(240,true,false,true).timeout.connect(func():printerr("EAST_ASSET_PREVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 var source_paths=["scripts/forest/forest_east_room_furniture.gd","scripts/forest/forest_east_room_casework.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_falan_interior_furniture.gd","scripts/forest/forest_falan_proportions.gd","scripts/forest/forest_falan_lamps.gd","scripts/forest/forest_tina_street_details.gd","scripts/forest/forest_sokia_house_art.gd","scripts/forest/forest_east_village_props.gd","assets/maps/falan/east_region/room_furniture/data.json","assets/maps/falan/east_region/room_casework/data.json","assets/maps/falan/east_region/landmarks/surfaces.gd","assets/maps/falan/east_region/landmarks/surfaces.png","scripts/forest/forest_painterly_surface.gdshader"]
 source_paths.append(get_script().resource_path);source_paths.append("tests/forest-shrine/east_review_sources.gd")
 var source_hashes=Sources.snapshot(source_paths)
 root.size=Vector2i(1440,900);root.title="Cross Gate · Native Casework Study"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var observations=[];var captures=[]
 for page in ceili(Fixtures.IDS.size()/6.):
  var group=Node3D.new();stage.add_child(group)
  for index in range(page*6,mini(page*6+6,Fixtures.IDS.size())):
   var serial:int=Fixtures.IDS[index];var mesh=Fixtures.mesh(serial,Art.data().graphics[str(serial)])
   check(mesh!=null and mesh.get_surface_count()>0,"Native casework fixture "+str(serial))
   check(Fixtures.mesh(serial,Art.data().graphics[str(serial)])==mesh,"Shared prepared mesh "+str(serial))
   var bounds=mesh.get_aabb();var node=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3((index%3-1)*14.,0,((index%6)/3)*15.-7.5)-Vector3(bounds.get_center().x,0,bounds.get_center().z);group.add_child(node)
   var label=Label3D.new();label.text=str(serial);label.position=node.position+Vector3(bounds.get_center().x,bounds.end.y+1.5,bounds.get_center().z);label.font_size=48;label.pixel_size=.015;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;group.add_child(label)
   observations.append({"graphic":serial,"role":Fixtures.data().graphics[str(serial)].role,"bounds":var_to_str(bounds)})
  var angle=0
  for eye in [Vector3(-27,23,39),Vector3(27,23,-39)]:
   camera.position=eye;camera.look_at(Vector3(0,2.5,0));camera.reset_physics_interpolation();root.grab_focus()
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   var name="casework-%02d-%s.png"%[page+1,"normal" if angle==0 else "second"]
   check(root.get_texture().get_image().save_png(OUT+name)==OK,"Captured "+name);captures.append(name);angle+=1
  group.free()
 var changed=Sources.changed(source_hashes)
 check(changed.is_empty(),"Loaded review sources remain current through the capture")
 var file=FileAccess.open(OUT+"preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"fixtures":observations,"captures":captures,"source_hashes":source_hashes,"source_changed_during_run":changed,"scope":"19 asset previews only, before actual map activation/placement verification."},"  "));file.close()
 print("EAST_ROOM_CASEWORK_PREVIEW_RESULT checks=",checks," failures=",failures)
 quit(failures)
