extends "res://tests/forest-shrine/east_landmark_review.gd"
const Cottages=preload("res://scripts/forest/forest_east_stilt_compounds.gd")
const STILT_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Stilt Compounds/"

func run():
 create_timer(240).timeout.connect(func():push_error("Stilt prototype source review timed out");quit(2))
 root.size=Vector2i(1200,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STILT_OUT))
 var paths=["tests/forest-shrine/east_stilt_compounds_source_review.gd","scripts/forest/forest_east_stilt_compounds.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_falan_building_shapes.gd","scripts/forest/forest_original_map_art.gd","scripts/forest/forest_tina_harbor_details.gd","assets/maps/falan/east_region/stilt_compounds/data.json","assets/maps/falan/east_region/stilt_compounds/1233284-native.png","assets/maps/falan/east_region/stilt_compounds/1233284-front.png","assets/maps/falan/east_region/landmarks/surfaces.png","assets/maps/falan/east_region/landmarks/surfaces.gd","assets/maps/original_crossgate/building-surfaces.png"]
 var before=Sources.snapshot(paths);Maps.Art.load_east();var spec:Dictionary=Cottages.data().graphics["1233284"]
 var mesh=Cottages.mesh(1233284);check(mesh==Cottages.mesh(1233284),"Private stilt geometry is cached")
 check(mesh.get_meta("owner_y_conversions")==1,"Private stilt geometry has one canonical owner conversion")
 check(mesh.get_meta("source_cell")==Vector2i(108,101),"Candidate retains its exact original FGanchor")
 var triangles=0;var finite=true;var arrays_:Array=mesh.get_meta("east_cpu_arrays")
 for arrays:Array in arrays_:
  triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and point.is_finite()
 check(finite and triangles>100,"Solid curved body, roof, pillars and stair arrays are finite")
 check(mesh.get_aabb().size.y>5 and mesh.get_aabb().size.x>5 and mesh.get_aabb().size.z>5,"Cottage has independently modelled height and depth")
 var viewport=SubViewport.new();viewport.size=Vector2i(720,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage);var world=WorldEnvironment.new();var environment=Environment.new()
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("27313a");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.85;world.environment=environment;stage.add_child(world)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);stage.add_child(light)
 var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node);var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 var captures=[]
 for angle in 2:
  var target:Vector3
  if angle==0:
   node.scale.y=1./Cottages.East.OWNER_Y_SCALE
   var across=(float(spec.size[0])*.5+float(spec.origin[0]))/(2.*Landmarks.Fit.HORIZONTAL)
   target=Vector3(across,(-float(spec.origin[1])-float(spec.size[1])*.5)/Landmarks.Fit.VERTICAL,across);camera.size=float(spec.size[1])/(sqrt(2.)*Landmarks.Fit.HORIZONTAL)*1.14
  else:
   node.scale.y=1.;target=mesh.get_aabb().get_center();camera.size=mesh.get_aabb().size.length()*1.12
  camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.15,-1)).normalized()*120.;camera.look_at(target);camera.current=true
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  var path=STILT_OUT+("1233284-source-axis.png" if angle==0 else "1233284-reverse.png")
  check(viewport.get_texture().get_image().save_png(path)==OK,"Captured measured stilt prototype "+str(angle));captures.append(path)
 var changed=Sources.changed(before);check(changed.is_empty(),"Loaded prototype sources remain current")
 var file=FileAccess.open(STILT_OUT+"prototype-source-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"triangles":triangles,"bounds":str(mesh.get_aabb()),"source_hashes":before,"source_changed_during_run":changed,"captures":captures,"inferred":Cottages.data().inferred,"scope":"One private measured gold-cottage source/reverse study only. No runtime hook, BGunderlay, actual walking or visual acceptance is implied."},"  "));file.close()
 print("EAST_STILT_PROTOTYPE_RESULT checks=",checks," failures=",errors);quit(1 if errors else 0)
