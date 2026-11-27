extends "res://tests/forest-shrine/east_hourglass_preview.gd"
## Reuse the asset gallery camera before publishing the private roof correction.
const Roof=preload("res://scripts/forest/forest_east_lektal_roof.gd")
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"tests/forest-shrine/east_hourglass_preview.gd","tests/forest-shrine/east_review_sources.gd","scripts/forest/forest_east_lektal_roof.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/landmarks/profiles.json",Roof.ROOT+"data.json",Roof.ROOT+"house-atlas.png",Roof.ROOT+"depth-mask.png",Roof.ROOT+"surfaces.png",Roof.ROOT+"chimney-front.png"])
 root.size=Vector2i(1440,900);root.title="Cross Gate · Lektal Roof Study"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.;stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var mesh=Roof.mesh(1233255,Art.data().graphics["1233255"])
 await study(stage,camera,mesh,"lektal-roof-1233255",mesh.get_aabb())
 # The upper reverse study can hide short walls under the large original eaves;
 # add a low reverse asset view to show the closed body and roof attachment.
 var low=MeshInstance3D.new();low.mesh=mesh;stage.add_child(low)
 camera.position=mesh.get_aabb().get_center()+Vector3(1,.20,-1).normalized()*mesh.get_aabb().size.length()*1.3;camera.look_at(mesh.get_aabb().get_center());camera.reset_physics_interpolation()
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+"lektal-roof-1233255-low-reverse.png")==OK,"Low reverse shows closed house walls");captures.append("lektal-roof-1233255-low-reverse.png");low.free()
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded roof sources remain current")
 var file=FileAccess.open(OUT+"lektal-roof-preview.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"captures":captures,"roof_attachment_proof":Roof.roof_proof,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private reused-house roof attachments in asset views; no runtime hook or actual-source-map claim."},"  "));file.close();print("EAST_LEKTAL_ROOF_PREVIEW_RESULT checks=",checks," failures=",failures);quit(failures)
