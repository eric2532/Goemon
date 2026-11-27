extends "res://tests/forest-shrine/east_hourglass_preview.gd"
## Asset study only; original map33608is not enrolled by this fixture.
const Statue=preload("res://scripts/forest/forest_east_mouse_statue.gd")
func run():
 var paths=[get_script().resource_path,"tests/forest-shrine/east_hourglass_preview.gd","scripts/forest/forest_east_mouse_statue.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_falan_interior_furniture.gd","scripts/forest/forest_falan_lamps.gd","scripts/forest/forest_stone_fort.gd"]
 for name in["data.json","native.png","body-front.png","staff-front.png","body-material.png","staff-material.png","ground.png","partition-mask.png"]:paths.append(Statue.ROOT+name)
 var hashes=Sources.snapshot(paths);root.size=Vector2i(1440,900)
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("1d0000");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 var mesh=Statue.mesh();check(Statue.mesh()==mesh,"One prepared immutable statue composition");check(int(mesh.get_meta("source_bg_mosaics"))==290,"Every exact bounded source BG placement retained in provenance")
 check(Statue.data().sculpture_source_placements.size()==186,"Exact186single-use BGtuples are isolated from ordinary paving")
 for row:Dictionary in Statue.data().sculpture_source_placements:check(Statue.replaces_background(Vector2i(row.cell[0],row.cell[1]),int(row.graphic)),"Exact sculpture BGtuple retained")
 check(not Statue.replaces_background(Vector2i(224,55),1220759),"Ordinary repeated source paving is never a sculpture replacement")
 await study(stage,camera,mesh,"source-mouse-statue",mesh.get_meta("statue_bounds"))
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Statue/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 for name in captures:DirAccess.rename_absolute(OUT+name,output+name)
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Private sculpture sources remain current")
 var file=FileAccess.open(output+"preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"captures":captures,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private BGstatue depth/back reconstruction with exact native source reference. No map enrollment, navigation, actor, event or actual-gameplay-camera acceptance."},"  "));file.close();print("EAST_MOUSE_STATUE_PREVIEW_RESULT checks=",checks," failures=",failures);quit(failures)
