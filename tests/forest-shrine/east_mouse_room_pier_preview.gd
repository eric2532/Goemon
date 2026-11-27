extends "res://tests/forest-shrine/east_hourglass_preview.gd"
const Piers=preload("res://scripts/forest/forest_east_mouse_room_piers.gd")
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_east_mouse_room_piers.gd",Piers.ROOT+"data.json","assets/textures/edo/rock.png","assets/maps/original_crossgate/east/catalog.json","scripts/forest/forest_east_room_furniture.gd","scripts/forest/forest_east_fallback_families.gd","scripts/forest/forest_coastal_mesh.gd"])
 root.size=Vector2i(1440,900)
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();var serial=1230127;var mesh=Piers.mesh(serial,Art.data().graphics[str(serial)])
 check(Piers.mesh(serial,Art.data().graphics[str(serial)])==mesh,"One immutable pier mesh reused")
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Single Ball Pier/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node);var bounds=mesh.get_aabb();var target=bounds.get_center()
 for angle in 2:
  camera.position=target+(Vector3(-1,.65,1)if angle==0 else Vector3(1,.7,-1)).normalized()*bounds.size.length()*1.65;camera.look_at(target)
  for frame in 12:await process_frame
  await RenderingServer.frame_post_draw
  var name="ball-pier-"+("normal.png"if angle==0 else "reverse.png");check(root.get_texture().get_image().save_png(output+name)==OK,"Captured source-facing/independent reverse "+name);captures.append(name)
 var vertices=0;var finite=true
 for arrays:Array in mesh.get_meta("east_cpu_arrays"):
  vertices+=arrays[Mesh.ARRAY_VERTEX].size()
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and p.is_finite()
 check(finite and bounds.size.y>2. and vertices>0,"Finite closed moulded pier and round cap")
 check(bounds.size.x<=3. and bounds.size.z<=3. and absf(bounds.position.y)<.01,"Complete pier retains its original one-cell footprint and ground datum")
 var observed_only=true;var painted:Array=mesh.get_meta("east_cpu_arrays")[mesh.get_meta("source_ball_paint_surface")]
 for normal:Vector3 in painted[Mesh.ARRAY_NORMAL]:observed_only=observed_only and normal.dot(Piers.SOURCE_VIEW)>=-.00001
 check(observed_only and not painted[Mesh.ARRAY_VERTEX].is_empty(),"Continuous ball paint stops exactly at original observed hemisphere")
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Private prototype sources remain current")
 var file=FileAccess.open(output+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"vertices":vertices,"bounds":var_to_str(bounds),"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Single1230127ball-capped pier private geometry. Source-facing original atlas paint; independent closed stone back and round cap. No map hook, other10forms or actual room acceptance."},"  "));file.close();print("EAST_MOUSE_PIER_PREVIEW checks=",checks," failures=",failures);quit(failures)
