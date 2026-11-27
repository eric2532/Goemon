extends "res://tests/forest-shrine/east_landmark_review.gd"
const Compound=preload("res://scripts/forest/forest_east_castle_compound.gd")
const ROOF_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Classic Architecture/Castle Compound/"

static func frame_proof(mesh:Mesh,legacy:Mesh)->Dictionary:
 var ratio=.045*Landmarks.Fit.VERTICAL;var checks_=[];var old_bounds=legacy.get_aabb();var bounds=mesh.get_aabb()
 checks_.append([absf(bounds.size.y-old_bounds.size.y*ratio)<.0001,"East castle applies the canonical ownerY to height exactly once"])
 checks_.append([bounds.position.x==old_bounds.position.x and bounds.position.z==old_bounds.position.z and bounds.size.x==old_bounds.size.x and bounds.size.z==old_bounds.size.z,"Every source XZ bound remains exact"])
 checks_.append([mesh.get_meta("owner_y_conversions")==1 and is_equal_approx(mesh.get_meta("canonical_owner_y"),ratio),"The derivative records one canonical owner conversion"])
 var source_slots:Array=mesh.get_meta("east_castle_source_slots");var roofs:Dictionary=mesh.get_meta("east_castle_roof_indices");var arrays_:Array=mesh.get_meta("east_castle_cpu_arrays")
 var seen={};var triangles=0;var legacy_triangles=0;var max_y_error=0.;var xz_exact=true
 for slot in legacy.get_surface_count():
  var a=legacy.surface_get_arrays(slot);var indices=a[Mesh.ARRAY_INDEX];legacy_triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
 for slot in arrays_.size():
  var a:Array=arrays_[slot];var original=legacy.surface_get_arrays(source_slots[slot]);var indices=a[Mesh.ARRAY_INDEX]
  triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
  var mapping:PackedInt32Array=roofs[slot] if roofs.has(slot) else PackedInt32Array(range(original[Mesh.ARRAY_VERTEX].size()))
  checks_.append([mapping.size()==a[Mesh.ARRAY_VERTEX].size(),"Canonical surface preserves its original source vertex mapping "+str(slot)])
  for index in a[Mesh.ARRAY_VERTEX].size():
   var old:Vector3=original[Mesh.ARRAY_VERTEX][mapping[index]];var point:Vector3=a[Mesh.ARRAY_VERTEX][index]
   xz_exact=xz_exact and old.x==point.x and old.z==point.z;max_y_error=maxf(max_y_error,absf(point.y-old.y*ratio))
   if source_slots[slot]==5:seen[mapping[index]]=seen.get(mapping[index],0)+1
 var original=legacy.surface_get_arrays(5);var expected={};var indices=original[Mesh.ARRAY_INDEX]
 for index in (indices if indices is PackedInt32Array and not indices.is_empty() else range(original[Mesh.ARRAY_VERTEX].size())):expected[index]=expected.get(index,0)+1
 checks_.append([xz_exact,"Every individual East castle XZ vertex is bit-exact to the shared master"])
 checks_.append([max_y_error<.00001,"Every East vertex has canonical Y, with no second conversion"])
 checks_.append([seen==expected and triangles==legacy_triangles,"Roof front/back partition preserves all original geometry"])
 var door=90./Landmarks.Fit.VERTICAL*ratio
 checks_.append([absf(door-4.05)<.000001 and absf(door*1.3-5.265)<.000001,"The original90pixel doorway becomes4.05local/5.265world metres"])
 return {"checks":checks_,"owner_y":ratio,"legacy_local_height":old_bounds.size.y,"canonical_local_height":bounds.size.y,"door_pixels":90,"canonical_door_local":door,"canonical_door_world_at1_3":door*1.3,"xz_vertices_bit_exact":xz_exact,"max_y_error":max_y_error,"triangles":triangles}

func run():
 root.size=Vector2i(1200,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOF_OUT))
 var paths=["tests/forest-shrine/east_castle_roof_asset_review.gd","scripts/forest/forest_east_castle_compound.gd","scripts/forest/forest_east_castle_roof.gd","scripts/forest/forest_beast_castle.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/classic_architecture/castle_roof/data.json","assets/maps/original_crossgate/beast-castle.png","assets/maps/original_crossgate/beast-castle-sculpture-surfaces.png","assets/maps/original_crossgate/beast-sculptures.gd","assets/maps/original_crossgate/beast-castle-carvings.gd","assets/maps/original_crossgate/beast-castle-carvings.png"]
 var before=Sources.snapshot(paths);Maps.Art.load_east();var mesh=Compound.mesh();var proof=frame_proof(mesh,Compound.Castle.mesh())
 for row:Array in proof.checks:check(row[0],row[1])
 var viewport=SubViewport.new();viewport.size=Vector2i(720,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage);var world=WorldEnvironment.new();var environment=Environment.new()
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("27313a");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.85;world.environment=environment;stage.add_child(world)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);stage.add_child(light)
 var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node);var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 var native:Dictionary=Maps.Art.data().beast_castle
 for angle in 2:
  var target:Vector3
  if angle==0:
   node.scale.y=1./Compound.Roof.OWNER_Y;var across=(float(native.size[0])*.5-float(native.origin[0]))/(2.*Landmarks.Fit.HORIZONTAL)
   target=Vector3(across,(float(native.origin[1])-float(native.size[1])*.5)/Landmarks.Fit.VERTICAL,across);camera.size=float(native.size[1])/(sqrt(2.)*Landmarks.Fit.HORIZONTAL)*1.14
  else:
   node.scale.y=1.;target=mesh.get_aabb().get_center();camera.size=mesh.get_aabb().size.length()*1.12
  camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.15,-1)).normalized()*120.;camera.look_at(target);camera.current=true
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  check(viewport.get_texture().get_image().save_png(ROOF_OUT+("canonical-castle-source-axis.png" if angle==0 else "canonical-castle-reverse.png"))==OK,"Captured canonical castle asset "+str(angle))
 var changed=Sources.changed(before);check(changed.is_empty(),"Loaded canonical castle sources remain current through asset review")
 var file=FileAccess.open(ROOF_OUT+"roof-asset-review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"frame_proof":proof,"source_hashes":before,"source_changed_during_run":changed,"inferred":Compound.Roof.data().inferred,"scope":"Isolated East castle canonical-height/material asset review; original shared master and all XZ vertices preserved. Actual ordinary doorway and reachable whole-map views remain required."},"  "));file.close()
 print("EAST_CASTLE_ROOF_ASSET_RESULT checks=",checks," failures=",errors);quit(1 if errors else 0)
