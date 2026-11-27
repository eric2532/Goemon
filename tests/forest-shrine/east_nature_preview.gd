extends SceneTree
## Contact assets only; actual original-map camera acceptance is separate.
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Preview/"
var failures=[]
func _initialize():run.call_deferred()
func review_path()->String:return OUT
func selected_ids()->Array:return Nature.data().graphics.keys()
func asset_mesh(serial:int)->Mesh:return Nature.mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
func additional_input_paths()->Array:return []
func page_capacity()->int:return 12
func run():
 var inputs={}
 for path in [get_script().resource_path,"res://tests/forest-shrine/east_nature_preview.gd","res://scripts/forest/forest_east_region_art.gd","res://scripts/forest/forest_east_tree_families.gd","res://scripts/forest/forest_east_nature.gd","res://scripts/forest/forest_coastal_mesh.gd",Nature.ROOT+"data.json",Nature.Base.ROOT+"profiles.json",Nature.Base.ROOT+"surfaces.png"]+additional_input_paths():inputs[path]=FileAccess.get_sha256(path)
 root.size=Vector2i(1440,1050);root.title="Cross Gate · Native Nature Forms"
 Nature.Base.Art.load_east();var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("243039");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dae4e3");environment.environment.ambient_light_energy=.75;stage.add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 var objects=Node3D.new();stage.add_child(objects);var tokens=selected_ids();tokens.sort_custom(func(a,b):return int(a)<int(b))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_path()));var pages=[]
 for start in range(0,tokens.size(),page_capacity()):
  for child in objects.get_children():child.queue_free()
  await process_frame
  var group=tokens.slice(start,mini(start+page_capacity(),tokens.size()));var max_width=0.;var max_height=0.
  for token in group:
   var shape=asset_mesh(int(token));var box=shape.get_aabb();max_width=maxf(max_width,maxf(box.size.x,box.size.z));max_height=maxf(max_height,box.size.y)
  var spacing=10.;var height=5.
  for i in group.size():
   var serial=int(group[i]);var node=MeshInstance3D.new();node.mesh=asset_mesh(serial)
   var box=node.mesh.get_aabb();var fit=minf(6./maxf(box.size.x,box.size.z),5./box.size.y);node.scale=Vector3.ONE*fit
   var at=Vector3((i%4-(mini(4,group.size())-1)*.5)*spacing,0,(i/4-(ceili(group.size()/4.)-1)*.5)*spacing*1.4);node.position=at-Vector3(box.get_center().x,box.position.y,box.get_center().z)*fit;objects.add_child(node)
   var label=Label3D.new();label.text=str(serial);label.font_size=42;label.pixel_size=.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=at+Vector3(0,-.5,0);objects.add_child(label)
  var target=Vector3(0,height*.35,0);camera.size=spacing*(mini(4,group.size())+.4)+height*.7
  for index in 2:
   var eye=Vector3(-1,.75,1).normalized() if index==0 else Vector3(1,.75,-1).normalized();camera.position=target+eye*100;camera.look_at(target);camera.reset_physics_interpolation();root.grab_focus()
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   var path=review_path()+"nature-%02d-%s.png"%[start/page_capacity()+1,"normal" if index==0 else "second"]
   if root.get_texture().get_image().save_png(path)!=OK:failures.append(path)
   pages.append({"path":path,"graphics":group,"angle":"normal" if index==0 else "second"})
 for path in inputs:
  if FileAccess.get_sha256(path)!=inputs[path]:failures.append("Input changed during preview: "+path)
 var file=FileAccess.open(review_path()+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"input_hashes":inputs,"captures":pages,"failures":failures,"graphics":tokens,"scope":"Normalized asset previews (preview-only scale; runtime source dimensions unchanged); source/normal-map camera review required separately."},"  "));file.close()
 print("EAST_NATURE_PREVIEW captures=",pages.size()," failures=",failures.size());quit(failures.size())
