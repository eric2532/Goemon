extends "res://tests/forest-shrine/east_hourglass_preview.gd"
## Only the two still-private giant hourglasses; accepted small forms are unchanged.
func run():
 var paths=[get_script().resource_path,"tests/forest-shrine/east_hourglass_preview.gd","scripts/forest/forest_east_dragon_hourglass.gd","scripts/forest/forest_east_hourglasses.gd","scripts/forest/forest_east_hourglass_front.gdshader","scripts/forest/forest_east_hourglass_back.gdshader","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_coastal_mesh.gd",Dragon.ROOT+"data.json",Dragon.ROOT+"frieze-tile.png"]
 for source in[58000,58001]:
  for suffix in["-native.png","-ground.png","-form.png"]:paths.append(Dragon.ROOT+str(source)+suffix)
 var hashes=Sources.snapshot(paths);root.size=Vector2i(1440,900)
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for source in[58000,58001]:
  env.environment.background_color=Color8(20,20,20) if source==58001 else Color("243039")
  var mesh=Dragon.mesh(source);check(Dragon.mesh(source)==mesh,"Shared complete source background "+str(source));check(int(mesh.get_meta("source_background_placements"))==(15 if source==58000 else 13),"Every original background component accounted for "+str(source));await study(stage,camera,mesh,"dragon-"+str(source),mesh.get_meta("hourglass_bounds"))
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/Giant Opacity/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 for name in captures:DirAccess.rename_absolute(OUT+name,output+name)
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded giant-hourglass source remains current")
 var file=FileAccess.open(output+"preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"observations":observations,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private giant2opacity revision only; no map enrollment, actual room or progression acceptance."},"  "));file.close();print("EAST_DRAGON_HOURGLASS_RESULT checks=",checks," failures=",failures);quit(failures)
