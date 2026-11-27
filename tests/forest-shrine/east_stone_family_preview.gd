extends SceneTree
## Private material/shape study; original-map camera acceptance remains separate.
const Stone=preload("res://scripts/forest/forest_east_stone_families.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Stone Family Candidate/"
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Stone Family Preview/"
const IDS=[12100,12103,12109,12118,12135,13432,13435,13542,13580,13720,13829,13904,15053,15068,15101,15303,15345,15490,15501,15623,15766,17700,1233290,1233293,1238211,1260054]
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,1000);var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("243039");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dae4e3");environment.environment.ambient_light_energy=.75;stage.add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=48.
 var objects=Node3D.new();stage.add_child(objects);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));var captures=[];var failures=[];var source_hash=FileAccess.get_sha256(FOLDER+"data.json")
 for start in range(0,IDS.size(),9):
  for child in objects.get_children():child.queue_free()
  await process_frame
  var group=IDS.slice(start,mini(start+9,IDS.size()))
  for i in group.size():
   var id:int=group[i]
   if not Stone.data(FOLDER).graphics.has(str(id)):continue
   var mesh:Mesh=Stone.mesh(id,{},FOLDER);var box=mesh.get_aabb();var fit=minf(8./maxf(box.size.x,box.size.z),6./maxf(.1,box.size.y));var at=Vector3((i%3-1)*13,0,(i/3-1)*16)
   var node=MeshInstance3D.new();node.mesh=mesh;node.scale=Vector3.ONE*fit;node.position=at-Vector3(box.get_center().x,box.position.y,box.get_center().z)*fit;objects.add_child(node)
   var label=Label3D.new();label.text="%d · %.2fm"%[id,box.size.y];label.font_size=36;label.pixel_size=.014;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=at+Vector3(0,-.6,0);objects.add_child(label)
  for index in 2:
   var eye=Vector3(-1,.75,1).normalized() if index==0 else Vector3(1,.75,-1).normalized();var target=Vector3(0,2.,0);camera.position=target+eye*100;camera.look_at(target);camera.reset_physics_interpolation()
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   var path=OUT+"stone-%02d-%s.png"%[start/9+1,"front" if index==0 else "second"]
   if root.get_texture().get_image().save_png(path)!=OK:failures.append(path)
   captures.append({"path":path,"source_graphics":group,"angle":"front" if index==0 else "second"})
 if source_hash!=FileAccess.get_sha256(FOLDER+"data.json"):failures.append("Candidate changed during review")
 var file=FileAccess.open(OUT+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"captures":captures,"failures":failures,"source_data_sha256":source_hash,"scope":"Private normalized source-family preview. Captions retain actual runtime heights; preview scale is not map scale. Map enrollment and original reachable camera review remain required."},"  "));file.close()
 print("EAST_STONE_FAMILY_PREVIEW captures=",captures.size()," failures=",failures.size());quit(failures.size())
