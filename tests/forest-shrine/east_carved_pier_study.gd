extends "res://tests/forest-shrine/east_hourglass_preview.gd"
const Carved=preload("res://scripts/forest/forest_east_carved_pier_study.gd")
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_east_carved_pier_study.gd","scripts/forest/forest_east_mouse_room_piers.gd",Carved.Measurements.ROOT+"data.json","scripts/forest/forest_east_room_furniture.gd","scripts/forest/forest_east_fallback_families.gd","scripts/forest/forest_coastal_mesh.gd","assets/materials/forest_stone.gdshader","assets/maps/original_crossgate/east/catalog.json",Carved.MASONRY,Carved.NATIVE_CPU,"assets/maps/original_crossgate/east/carved-cpu-pages/provenance.json","assets/maps/falan/east_region/carved_pier_study/provenance.json"])
 hashes.merge(Sources.snapshot([Carved.MASONRY_CPU,"assets/maps/falan/east_region/carved_pier_study/cpu-provenance.json","tools/prepare_east_carved_pier_masonry.gd"]))
 root.size=Vector2i(1440,900);root.title="Cross Gate · Private carved pier"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();var graphic:Dictionary=Art.data().graphics["1230051"];var model=Carved.mesh(1230051,graphic)
 var gpu_image:Image=Art.page_image(int(graphic.page)).duplicate();var gpu_compressed=gpu_image.is_compressed()
 if gpu_compressed:gpu_image.decompress()
 gpu_image.convert(Image.FORMAT_RGBA8)
 var source_rect:Array=graphic.rect;var gpu_crop=gpu_image.get_region(Rect2i(source_rect[0],source_rect[1],source_rect[2],source_rect[3]));var opaque_diffs=0;var transparent_diffs=0
 for y in Carved.native_image.get_height():
  for x in Carved.native_image.get_width():
   var original_pixel=Carved.native_image.get_pixel(x,y);var runtime_pixel=gpu_crop.get_pixel(x,y)
   if original_pixel==runtime_pixel:continue
   if original_pixel.a>.5:opaque_diffs+=1
   else:transparent_diffs+=1
 print("CARVED_PIXEL_INPUTS gpu_compressed=",gpu_compressed," opaque_diffs=",opaque_diffs," transparent_diffs=",transparent_diffs)
 check(model==Carved.mesh(1230051,graphic),"One immutable carved pier reused")
 var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(Carved.masonry_image.get_data())
 check(Carved.masonry_image.get_meta("source_png_sha256")==FileAccess.get_sha256(Carved.MASONRY) and digest.finish().hex_encode()==Carved.masonry_image.get_meta("rgba_sha256"),"Prepared inferred material retains its exact generated pixels and source identity")
 check(model.get_surface_count()==2 and model.surface_get_material(0)==Carved.stone_surface(),"All opaque stone parts share one surface/material; original observed paint is separate")
 var original=Carved.Fort.material(Color("aaa796"),false);var owned=Carved.stone_surface()
 check(original!=owned and original.shader.code.contains("vec3 p=stone_point*.36;") and not original.shader.code.contains("vertex_stone_tint") and owned.shader==Carved.Source.Paint.SURFACE and owned.get_shader_parameter("base_texture")==load(Carved.MASONRY),"Private inferred material reuses the existing painted shader; shared stone is unchanged")
 var opaque:Array=model.get_meta("east_cpu_arrays")[0];var welded={};var edges={};var positions:PackedVector3Array=opaque[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=opaque[Mesh.ARRAY_INDEX];var triangles=0
 for i in range(0,indices.size(),3):
  var ids=[]
  for j in 3:
   var key=Vector3i((positions[indices[i+j]]*100000.).round())
   if not welded.has(key):welded[key]=welded.size()
   ids.append(welded[key])
  if ids[0]==ids[1] or ids[1]==ids[2] or ids[2]==ids[0]:continue
  triangles+=1
  for pair in [[ids[0],ids[1]],[ids[1],ids[2]],[ids[2],ids[0]]]:
   var key=Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]));edges[key]=int(edges.get(key,0))+1
 check(triangles>100 and edges.values().all(func(count_):return count_==2),"Continuous body is closed after relief displacement; every welded edge has two incident faces")
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Single Carved Pier/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var node=MeshInstance3D.new();node.mesh=model;stage.add_child(node);var bounds=model.get_aabb();var target=bounds.get_center()
 var finite=true;var vertices=0
 for arrays:Array in model.get_meta("east_cpu_arrays"):
  vertices+=arrays[Mesh.ARRAY_VERTEX].size()
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and point.is_finite()
 check(finite and vertices>0,"Finite closed moulded mass")
 # Native drawing overhangs its1cell collision footprint. Verify the actual
 # fitted projection rather than imposing an unrelated3m visual AABB limit.
 var projected=Rect2();var first=true
 var surfaces:Array=model.get_meta("east_cpu_arrays")
 for slot in int(model.get_meta("source_physical_surface_count")):
  var arrays:Array=surfaces[slot]
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   var pixel=Vector2((point.x+point.z)*32./3.,(point.z-point.x)*8.-point.y/.045)
   projected=Rect2(pixel,Vector2.ZERO)if first else projected.expand(pixel);first=false
 var g:Dictionary=Carved.Measurements.data().graphics["1230051"];var expected=Rect2(Vector2(g.origin[0]+g.bounds[0],g.origin[1]+g.bounds[1]),Vector2(g.bounds[2]-g.bounds[0],g.bounds[3]-g.bounds[1]))
 check(bounds.size.y>5. and absf(bounds.position.y)<.01 and projected.position.distance_to(expected.position)<.08 and projected.size.distance_to(expected.size)<.08,"Measured source silhouette and ground datum; original visual overhang retained")
 for angle in 2:
  camera.position=target+(Vector3(-1,.65,1)if angle==0 else Vector3(1,.7,-1)).normalized()*bounds.size.length()*1.4;camera.look_at(target);camera.reset_physics_interpolation()
  for frame in 12:await process_frame
  await RenderingServer.frame_post_draw
  var filename="carved-1230051-"+("normal.png"if angle==0 else"reverse.png")
  check(root.get_texture().get_image().save_png(output+filename)==OK,"Captured "+filename);captures.append(filename)
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Source snapshot current")
 var file=FileAccess.open(output+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"vertices":vertices,"bounds":var_to_str(bounds),"physical_source_projection":var_to_str(projected),"expected_source_projection":var_to_str(expected),"paint_normal_offset_m":.003,"source_stone_patch_centers":model.get_meta("source_stone_patch_centers"),"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private1230051carved-pier silhouette study only. No map/scenery hook, no other four carved forms or actual-map acceptance.","inferred":model.get_meta("inferred_details")},"  "));file.close();print("EAST_CARVED_PIER_STUDY checks=",checks," failures=",failures);quit(failures)
