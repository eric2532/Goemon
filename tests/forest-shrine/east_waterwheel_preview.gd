extends "res://tests/forest-shrine/east_hourglass_preview.gd"
## Reuse the asset gallery camera before publishing the private roof correction.
const Wheel=preload("res://scripts/forest/forest_east_waterwheel.gd")
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"tests/forest-shrine/east_hourglass_preview.gd","tests/forest-shrine/east_review_sources.gd","scripts/forest/forest_east_waterwheel.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/landmarks/profiles.json",Wheel.ROOT+"data.json",Wheel.ROOT+"front.png",Wheel.ROOT+"water.png",Wheel.ROOT+"timber.png"])
 root.size=Vector2i(1440,900);root.title="Cross Gate · Waterwheel Study"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var mesh=Wheel.mesh(1238504,Art.data().graphics["1238504"])
 await study(stage,camera,mesh,"waterwheel-1238504",mesh.get_meta("waterwheel_bounds"))
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded wheel sources remain current")
 var file=FileAccess.open(OUT+"waterwheel-preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"captures":captures,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private timber waterwheel construction in asset views; no runtime hook or actual-source-map claim."},"  "));file.close();print("EAST_WATERWHEEL_PREVIEW_RESULT checks=",checks," failures=",failures);quit(failures)
