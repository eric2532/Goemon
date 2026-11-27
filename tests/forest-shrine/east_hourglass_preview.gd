extends SceneTree
## Candidate assets only. Actual Dragon Hourglass rooms are not enrolled yet.
const Hours=preload("res://scripts/forest/forest_east_hourglasses.gd")
const Dragon=preload("res://scripts/forest/forest_east_dragon_hourglass.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/"
var checks=0
var failures=0
var observations=[]
var captures=[]
func _initialize():
 create_timer(240,true,false,true).timeout.connect(func():printerr("EAST_ASSET_PREVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 var source_paths=["scripts/forest/forest_east_hourglasses.gd","scripts/forest/forest_east_dragon_hourglass.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_east_room_furniture.gd","scripts/forest/forest_falan_interior_furniture.gd","scripts/forest/forest_falan_proportions.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/hourglasses/data.json","assets/maps/falan/east_region/dragon_hourglass/data.json"]
 source_paths.append("scripts/forest/forest_east_hourglass_front.gdshader");source_paths.append("scripts/forest/forest_east_hourglass_back.gdshader");source_paths.append(Dragon.ROOT.trim_prefix("res://")+"frieze-tile.png")
 for source in [58000,58001]:
  for suffix in ["-native.png","-ground.png","-form.png"]:source_paths.append(Dragon.ROOT.trim_prefix("res://")+str(source)+suffix)
 for serial in Hours.IDS:source_paths.append(Hours.ROOT.trim_prefix("res://")+str(serial)+"-front.png")
 source_paths.append(get_script().resource_path);source_paths.append("tests/forest-shrine/east_review_sources.gd")
 var hashes=Sources.snapshot(source_paths)
 root.size=Vector2i(1440,900);root.title="Cross Gate · Hourglass Geometry Study"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for serial in Hours.IDS:
  var mesh=Hours.mesh(serial,Art.data().graphics[str(serial)]);check(Hours.mesh(serial,Art.data().graphics[str(serial)])==mesh,"Shared ceremonial mesh "+str(serial));await study(stage,camera,mesh,"ceremonial-"+str(serial),mesh.get_aabb())
 for source in [58000,58001]:
  # The destroyed source has opaque(20,20,20)void behind its native floor.
  # Match that observed backdrop so its exact tile boundary is not mistaken
  # for an invented black apron against this gallery's unrelated grey sky.
  env.environment.background_color=Color8(20,20,20)if source==58001 else Color("243039")
  var mesh=Dragon.mesh(source);check(Dragon.mesh(source)==mesh,"Shared complete source background "+str(source));check(int(mesh.get_meta("source_background_placements"))==(15 if source==58000 else 13),"Every original background component accounted for "+str(source));await study(stage,camera,mesh,"dragon-"+str(source),mesh.get_meta("hourglass_bounds"))
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded source snapshot remains current")
 var file=FileAccess.open(OUT+"preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"captures":captures,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Three ceremonial hourglass meshes plus intact/destroyed Dragon Hourglass candidate compositions. No production hook, route or actual-map camera claim. Visual judgment is separate."},"  "));file.close();print("EAST_HOURGLASS_PREVIEW_RESULT checks=",checks," failures=",failures);quit(failures)
func minimum_study_height()->float:return 2.
func study(stage:Node3D,camera:Camera3D,mesh:Mesh,label:String,bounds:AABB):
 var triangles=0;var finite=true
 for slot in mesh.get_surface_count():
  var arrays:Array=mesh.get_meta("east_cpu_arrays")[slot] if mesh.has_meta("east_cpu_arrays") else mesh.surface_get_arrays(slot)
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and p.is_finite()
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 check(finite and bounds.size.y>minimum_study_height(),"Finite complete depth "+label);check(triangles>0,"Nonempty triangulated construction "+label)
 var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node);var target=bounds.get_center();var distance_=maxf(12.,bounds.size.length()*1.30)
 for angle in 2:
  camera.position=target+(Vector3(-1,.65,1) if angle==0 else Vector3(1,.7,-1)).normalized()*distance_;camera.look_at(target);camera.reset_physics_interpolation();root.grab_focus()
  for frame in 12:await process_frame
  await RenderingServer.frame_post_draw
  var name=label+("-normal.png" if angle==0 else "-second.png");check(root.get_texture().get_image().save_png(OUT+name)==OK,"Captured "+name);captures.append(name)
 observations.append({"label":label,"triangles":triangles,"budget_warning_over_50000":triangles>50000,"surfaces":mesh.get_surface_count(),"bounds":var_to_str(bounds)})
 node.queue_free();await process_frame
