extends "res://tests/forest-shrine/east_hourglass_preview.gd"
## Fixed asset-camera material-owner diagnosis; no runtime shader/material mutation.
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_dragon_hourglass.gd","scripts/forest/forest_east_hourglasses.gd","scripts/forest/forest_east_hourglass_front.gdshader","scripts/forest/forest_east_hourglass_back.gdshader",Dragon.ROOT+"data.json",Dragon.ROOT+"58000-form.png"]
 var hashes=Sources.snapshot(paths);root.size=Vector2i(1440,900)
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 var original=Dragon.mesh(58000);var bounds:AABB=original.get_meta("hourglass_bounds");var target=bounds.get_center()
 camera.position=target+Vector3(1,.7,-1).normalized()*maxf(12.,bounds.size.length()*1.3);camera.look_at(target)
 var hidden=ShaderMaterial.new();hidden.shader=Shader.new();hidden.shader.code="shader_type spatial; void fragment(){discard;}"
 var zero_alpha="--zero-alpha" in OS.get_cmdline_user_args()
 var no_prepass="--no-depth-prepass" in OS.get_cmdline_user_args()
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/"+("Giant No Depth Prepass/" if no_prepass else "Giant Zero Alpha/" if zero_alpha else "Giant Owner Diagnostic/");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var slots=[]
 for slot in original.get_surface_count():
  var material=original.surface_get_material(slot);var shader_path=material.shader.resource_path if material is ShaderMaterial else ""
  slots.append({"slot":slot,"shader":shader_path,"bounds":var_to_str(original.get_aabb()),"maximum_opacity":material.get_shader_parameter("maximum_opacity") if shader_path.ends_with("hourglass_back.gdshader") else null,"glass_color":var_to_str(material.get_shader_parameter("glass_color")) if shader_path.ends_with("hourglass_back.gdshader") else ""})
 for owner in(["no-depth-prepass"] if no_prepass else ["zero-alpha"] if zero_alpha else ["glass","native-paint"]):
  var mesh=original.duplicate();var removed=0
  for slot in mesh.get_surface_count():
   var material=mesh.surface_get_material(slot)
   if not material is ShaderMaterial:continue
   var path=material.shader.resource_path
   if owner=="no-depth-prepass" and path.ends_with("hourglass_back.gdshader"):
    var copy:ShaderMaterial=material.duplicate();var shader=Shader.new();shader.code=material.shader.code.replace("depth_prepass_alpha","depth_draw_never");copy.shader=shader;mesh.surface_set_material(slot,copy);removed+=1
   elif owner=="zero-alpha" and path.ends_with("hourglass_back.gdshader"):
    var copy:ShaderMaterial=material.duplicate();var color:Color=copy.get_shader_parameter("glass_color");color.a=0.;copy.set_shader_parameter("glass_color",color);copy.set_shader_parameter("maximum_opacity",0.);mesh.surface_set_material(slot,copy);removed+=1
   elif (path.ends_with("hourglass_back.gdshader") if owner=="glass" else path.ends_with("hourglass_front.gdshader")) and owner!="zero-alpha":
    mesh.surface_set_material(slot,hidden);removed+=1
  check(removed>0,"Identified exact diagnostic material owner "+owner)
  var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node)
  for frame in 12:await process_frame
  await RenderingServer.frame_post_draw
  var name="intact-reverse-hide-"+owner+".png";check(root.get_texture().get_image().save_png(output+name)==OK,"Captured fixed diagnostic "+owner);captures.append(name)
  node.queue_free();await process_frame
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Diagnostic source remains current")
 var file=FileAccess.open(output+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"surfaces":slots,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Read-only fixed reverse asset-camera diagnosis on duplicate mesh materials. Zero-alpha mode zeros only independent glass fill/rim opacity. No-depth-prepass mode changes only duplicated glass depth mode, retaining original fill/rim alpha, front art and lighting. No original material mutation and no visual acceptance."},"  "));file.close();print("EAST_GIANT_OWNER_DIAGNOSTIC checks=",checks," failures=",failures);quit(failures)
