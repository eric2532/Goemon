extends SceneTree
const Prototype=preload("res://tests/forest-shrine/east_source100_tree_volume_candidate.gd")
const Base=Prototype.Base
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Crown Close Candidate/"
func selected_graphics()->Array:return [10074,10087,10089]
func output_path()->String:return OUT
func candidate_mesh(serial:int)->Mesh:return Prototype.mesh(serial)
func extra_sources()->Array:return []
func candidate_metrics(mesh:Mesh)->Dictionary:return {"crown_projection_error_pixels":mesh.get_meta("crown_source_projection_error",null),"hidden_depth_before_owner_frame":mesh.get_meta("source_camera_depth_only",null)}
func candidate_caption(serial:int)->String:return "Untouched native "+str(serial)+"  |  Private3Dcrown; source wood/front retained"
func _initialize():run.call_deferred()
func run():
 var out=output_path();var paths=[get_script().resource_path,"res://tests/forest-shrine/east_source100_tree_volume_close.gd","res://tests/forest-shrine/east_source100_tree_volume_candidate.gd","res://scripts/forest/forest_east_native_trees.gd","res://scripts/forest/forest_east_tree_families.gd","res://scripts/forest/forest_east_region_art.gd",Prototype.Native.ROOT+"data.json",out+"source.json"]+extra_sources();var pins={}
 for serial in selected_graphics():
  paths.append(Prototype.Native.ROOT+str(serial)+"-foliage.png");paths.append(Prototype.Native.ROOT+str(serial)+"-branches.png");paths.append(out+str(serial)+"-native.png")
 for path in paths:pins[path]=FileAccess.get_sha256(path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));root.size=Vector2i(1440,960);root.title="Cross Gate · Private Source Crown Study";var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("243039");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dae4e3");environment.environment.ambient_light_energy=.75;stage.add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun);var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 var ui=CanvasLayer.new();stage.add_child(ui);var image=TextureRect.new();image.position=Vector2(16,64);image.size=Vector2(300,430);image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ui.add_child(image)
 var caption=Label.new();caption.position=Vector2(16,16);caption.add_theme_font_size_override("font_size",20);ui.add_child(caption)
 var node=MeshInstance3D.new();stage.add_child(node);var records=[];var failures=[]
 for serial in selected_graphics():
  node.mesh=candidate_mesh(serial)
  if node.mesh==null:push_error("Private crown construction failed for "+str(serial));quit(1);return
  var bounds=node.mesh.get_aabb();var target=bounds.get_center();camera.size=bounds.size.y*1.25;image.texture=ImageTexture.create_from_image(Image.load_from_file(out+str(serial)+"-native.png"));caption.text=candidate_caption(serial)
  for angle in 3:
   var direction=Vector3(-1,.72,1)if angle==0 else Vector3(1,.72,-1)if angle==1 else Vector3(1,.35,1)
   camera.position=target+direction.normalized()*80.;camera.look_at(target);camera.reset_physics_interpolation();root.grab_focus()
   for i in 12:await process_frame
   await RenderingServer.frame_post_draw
   var path=out+"%d-%s.png"%[serial,["source-facing","reverse","grazing"][angle]]
   if root.get_texture().get_image().save_png(path)!=OK:failures.append(path)
   records.append({"graphic":serial,"angle":["source-facing","reverse","grazing"][angle],"path":path,"physical_bounds":var_to_str(bounds),"native_front_image_sha256":FileAccess.get_sha256(out+str(serial)+"-native.png"),"candidate_metrics":candidate_metrics(node.mesh),"source_front_plane_extent":Prototype.Native.data().graphics[str(serial)].visible,"scope":"Close normalized studio/physical-owner-axis study only; no field ground or gameplay-camera acceptance."})
 var changed=[]
 for path in pins:
  if pins[path]!=FileAccess.get_sha256(path):changed.append(path)
 failures.append_array(changed);var file=FileAccess.open(out+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"captures":records,"source_hashes":pins,"source_changed":changed,"failures":failures,"canonical_unchanged":true,"scope":"PRIVATE source crown variations; exact native art/wood remain canonical. Rear mass and depth are inferred. No map, collision or Native runtime changed."},"  "));file.close();print("EAST13_CROWN_CLOSE captures=",records.size()," failures=",failures.size());quit(failures.size())
