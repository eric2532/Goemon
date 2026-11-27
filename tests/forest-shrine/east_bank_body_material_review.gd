extends "res://tests/forest-shrine/east_bank_caps_asset_review.gd"
const PRIVATE="res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Body Material Candidate/"

func run():
 var paths=[get_script().resource_path,"tests/forest-shrine/east_bank_caps_asset_review.gd","scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/bank_caps/surfaces.png","assets/textures/edo/rock.png",PRIVATE+"surfaces.png",PRIVATE+"source-contract.json"]
 var before=Fresh.snapshot(paths);var texture=ImageTexture.create_from_image(Image.load_from_file(PRIVATE+"surfaces.png"));var mesh_audit=[]
 for serial in [12528,12503,12527,12515,12502,12510,12529,12504,12522,12516,12534,12506,12517,12518,12535,12505]:
  var mesh=Caps.mesh(serial,4.);var arrays=var_to_bytes(mesh.get_meta("source_surface_arrays_all"));var box=mesh.get_aabb();var native_material=mesh.surface_get_material(1)
  var material:ShaderMaterial=mesh.surface_get_material(0).duplicate();material.set_shader_parameter("base_texture",texture)
  # Isolated review process only: replacing this scoped resource's material
  # does not regenerate/reupload geometry or alter canonical files.
  mesh.surface_set_material(0,material)
  check(var_to_bytes(mesh.get_meta("source_surface_arrays_all"))==arrays and mesh.get_aabb()==box,"Material-only bank geometry remains exact "+str(serial))
  check(mesh.surface_get_material(1)==native_material,"Original native front material remains exact "+str(serial))
  mesh_audit.append({"serial":serial,"bounds":str(box),"same_cpu_geometry":true,"native_front_unchanged":true})
 await gallery()
 var changed=Fresh.changed(before);check(changed.is_empty(),"Loaded material-only review sources stay current")
 var file=FileAccess.open(PRIVATE+"material-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"scope":"Private process-only material trial. Native fronts/grass/cap/body geometry/support are unchanged. Independent hidden body now reuses clean existing Edo rock/soil at1.2m pitch. No canonical asset or runtime owner published; images require independent judgment."},"  "));file.close()
 print("EAST_BANK_BODY_MATERIAL_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func gallery():
 var viewport=SubViewport.new();viewport.size=Vector2i(720,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage);var environment=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("27313a");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.85;environment.environment=settings;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);stage.add_child(light)
 var node=MeshInstance3D.new();stage.add_child(node);var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 for serial in [12503,12502,12510,12529,12504,12522]:
  var mesh=Caps.mesh(serial,4.);node.mesh=mesh
  for angle in 2:
   node.scale.y=1./(.045*9.9777530314) if angle==0 else 1.
   var target=node.transform*mesh.get_aabb().get_center();camera.size=13. if angle==0 else 6.3
   camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.1,-1)).normalized()*60.;camera.look_at(target);camera.current=true
   for i in 6:await process_frame
   await RenderingServer.frame_post_draw
   var path=PRIVATE+str(serial)+("-native-axis.png" if angle==0 else "-reverse.png")
   check(viewport.get_texture().get_image().save_png(path)==OK,"Captured clean bank-body material "+str(serial)+" angle"+str(angle));captures.append(path)
