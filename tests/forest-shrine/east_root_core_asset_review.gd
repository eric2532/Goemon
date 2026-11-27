extends SceneTree
## Private lower-body diagnostic: full source mesh retained, canopy honestly cropped.
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Narrow Core/"
func review_path()->String:return OUT
func root_mesh()->Mesh:return RootTree.mesh()
func input_path()->String:return "res://scripts/forest/forest_east_root_compounds.gd"
func stage_target()->Vector3:return Vector3(-10,7.5,3.6)
func camera_size()->float:return 38.
func reverse_direction()->Vector3:return Vector3(1,.04,-1).normalized()
func input_paths()->Array:
 var result=[input_path(),RootTree.ROOT+"data.json"]
 for name in DirAccess.get_files_at(RootTree.ROOT):
  if name.ends_with(".png"):result.append(RootTree.ROOT+name)
 return result
func _initialize():run.call_deferred()
func run():
 var source=input_path();var source_hash=FileAccess.get_sha256(source);var inputs={}
 for path in input_paths():inputs[path]=FileAccess.get_sha256(path)
 RootTree.Base.Art.load_east();root.size=Vector2i(1300,1000);root.title="Cross Gate · Private Ancient Root Core"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("536566");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("e8e5d7");env.environment.ambient_light_energy=.8;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);stage.add_child(sun)
 var object=MeshInstance3D.new();object.mesh=root_mesh();stage.add_child(object)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;camera.size=camera_size();stage.add_child(camera)
 var target=stage_target();var captures=[];DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_path()))
 for view in["source-face","reverse","clay-reverse"]:
  if view=="clay-reverse":
   var copy=object.mesh.duplicate()
   for slot in copy.get_surface_count():
    var mat=StandardMaterial3D.new();mat.albedo_color=Color.from_hsv(slot/10.,.65,.85);copy.surface_set_material(slot,mat)
   object.mesh=copy
  var direction=Vector3(-1./16.,.045,1./16.).normalized() if view=="source-face" else reverse_direction();camera.position=target+direction*90.;camera.look_at(target);camera.reset_physics_interpolation();root.grab_focus()
  for frame in 16:await process_frame
  await RenderingServer.frame_post_draw
  var path=review_path()+view+".png";root.get_texture().get_image().save_png(path);captures.append(path)
 var failures=[]
 if source_hash!=FileAccess.get_sha256(source):failures.append("Private root source changed during capture")
 for path in inputs:
  if inputs[path]!=FileAccess.get_sha256(path):failures.append("Private root input changed: "+path)
 var f=FileAccess.open(review_path()+"review.json",FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"Lower-trunk private asset diagnostic; full source mesh remains, canopy is cropped bycamera. No gameplay camera or source map altered.","source_sha256":source_hash,"input_hashes":inputs,"captures":captures,"failures":failures},"  "));f.close();print("ROOT_CORE_ASSET captures=",captures.size()," failures=",failures.size());quit(failures.size())
