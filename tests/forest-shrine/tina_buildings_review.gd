extends "res://tests/forest-shrine/original_maps_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Tina Recovery/Building Review/"
func run():
 var porch_review="--blue-porches" in OS.get_cmdline_user_args()
 var bay_walls="--bay-walls" in OS.get_cmdline_user_args()
 var rounded="--round-buildings" in OS.get_cmdline_user_args()
 var snowy="--snow-buildings" in OS.get_cmdline_user_args()
 var baseline="--baseline" in OS.get_cmdline_user_args()
 var output="res://build/Other Files/Asset Toolkit/Tina Recovery/Snow Buildings/"+("Before/" if baseline else "After/") if snowy else REVIEW
 if rounded:output="res://build/Other Files/Asset Toolkit/Tina Recovery/Round Buildings/"+("Before/" if baseline else "After/")
 if bay_walls:output="res://build/Other Files/Asset Toolkit/Tina Recovery/Bay Walls/"+("Before/" if baseline else "After/")
 if porch_review:output="res://build/Other Files/Asset Toolkit/Tina Recovery/Stockades and Porches/"+("Before/" if baseline else "After/")
 for angle in [0.0,.4,.8,1.2,2.4,3.6,4.9]:
  var pixel=Original.Forms.Tina.round_pixel(angle,[1.0,1.0,100,40],144,128)
  var rear=Original.Forms.Tina.round_pixel(PI*.5-angle,[1.0,1.0,100,40],144,128)
  check(pixel.distance_to(rear)<.001,"Round paint mirrors hidden rear depth without repeating the visible windows")
 check(Original.Forms.Tina.round_pixel(PI*.25,[1,1,100,40],144,128).is_equal_approx(Vector2(272,100)),"Round paint reaches the original right silhouette")
 check(Original.Forms.Tina.round_pixel(PI*1.25,[1,1,100,40],144,128).is_equal_approx(Vector2(16,100)),"Round paint reaches the original left silhouette")
 for serial in ([11407,11408] if bay_walls and not baseline else [11411,11412,11415] if snowy and not baseline else [11409,11410,11416]):
  for face in ["left","right"]:
   var quad:Array=Original.Forms.Tina.crops()["tina_%d_%s"%[serial,face]][1]
   var expected=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
   for i in 4:
    check(Original.Forms.Tina.face_uv(Vector2(quad[i][0],quad[i][1]),quad).distance_to(expected[i])<.0001,"Door and gable landmarks retain the native facade coordinates")
   var corner=Original.Forms.Tina.face_point(Vector2(quad[0][0],quad[0][1]),quad,Vector3.ZERO,10,8,6,face)
   check(corner.distance_to(Vector3(-5.065,6,-4) if face=="left" else Vector3(-5,6,4.065))<.0001,"Native door trim and facade face the same way")
 if porch_review and not baseline:
  for serial in [11409,11410]:
   var porch=Original.Forms.Source.new([],Original.Forms.BuildingAtlas,.045);porch.tiles=Original.Forms.BuildingData.TILES.duplicate();porch.tiles["trim"]=porch.tiles.tina_trim
   var doorway={"face":"left" if serial==11409 else "right","at":Vector3(-6,.5,0) if serial==11409 else Vector3(0,.5,5),"width":3.0}
   Original.Forms.Tina.porch(porch,Vector3.ZERO,12,10,8,doorway,serial)
   var vertices:PackedVector3Array=porch.finish().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var source_side=true;var entrance=true;var low=INF
   for point:Vector3 in vertices:
    source_side=source_side and (point.x< -6.7 if serial==11409 else point.z>5.7)
    entrance=entrance and absf(point.z if serial==11409 else point.x)>=1.3
    low=minf(low,point.y)
   check(source_side,"Blue porch keeps only the railing side shown in the source "+str(serial))
   check(entrance,"Blue porch balusters and posts leave the original doorway open "+str(serial))
   check(low<.04 and low>=0,"Blue porch supports meet the terrain below the deck "+str(serial))
   var g:Dictionary=Original.Art.data().graphics[str(serial)]
   var native=Original.Forms.Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),Vector2.ZERO,Vector2.ONE,0],load(Original.Art.ROOT+Original.Art.data().pages[int(g.page)]),.1)
   var entry=Original.Forms.Tina.door(native,porch,serial,Vector3.ZERO,12,10,8)
   check(entry.at.y>.02 and entry.at.y<2,"Blue house threshold sits above terrain within the source footing "+str(serial))
 if bay_walls and not baseline:
  var row=Original.state(Original.SHALENA_NORTH);var raw:PackedByteArray=row.raw.duplicate()
  var art=Original.Art.new();art.load_map(Original.path_for(Original.SHALENA_NORTH),row.raw,row.size)
  var fills=Original.porch_floors(art.placements,row.raw,row.size)
  check(not fills.is_empty(),"Recovered snowy porch has original missing ground to cover")
  check(row.raw==raw,"Porch floor repair preserves every recorded source byte")
  for fill in fills:
   check(row.raw.decode_u16(20+int(fill[4])*2)==0,"Porch repair covers only unrecorded floor cells")
   check(fill[3]>=1000 and fill[3] not in range(5000,5009),"Porch repair reuses nearby recorded land instead of water")
  for serial in [11407,11408]:
   var porch=Original.Forms.Source.new([],Original.Forms.BuildingAtlas,.045);porch.tiles=Original.Forms.BuildingData.TILES
   Original.Forms.Tina.bay_porch(porch,21,21,serial)
   var arrays=porch.finish().surface_get_arrays(0);var clear=true;var grounded=true
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    grounded=grounded and point.y>=.02 and point.y<2.4 and absf(point.x)<=10.1 and absf(point.z)<=10.1
    if serial==11407 and point.x< -9.2 and absf(point.z-4.2)<1.5:clear=false
    if serial==11408 and point.z>9.2 and absf(point.x+4.83)<1.5:clear=false
   check(clear,"Source-facing porch opening stays clear of the original entrance "+str(serial))
   check(grounded,"Picket fence starts on terrain and stays inside the source footprint "+str(serial))
 root.size=Vector2i(900,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var stage=Node3D.new();root.add_child(stage)
 var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("d8d1bb");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.8;stage.add_child(world)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=.7;stage.add_child(sun)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
 for serial in ([11409,11410] if porch_review else [11407,11408] if bay_walls else [11402,11408,11413,11414] if rounded else [11411,11412,11415] if snowy else [11416] if "--pub" in OS.get_cmdline_user_args() else [11407,11409,11410,11414,11416,11451]):
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var node=MeshInstance3D.new();node.mesh=Original.Forms.mesh(serial,"building",g,Original.Art.solid_texture(int(g.page)));stage.add_child(node)
  var bounds=node.mesh.get_aabb();var center=bounds.get_center();var span=bounds.size.length()
  check(bounds.size.x>1 and bounds.size.z>1 and bounds.size.y>1,"Native building has solid three dimensional geometry "+str(serial))
  camera.position=Vector3(-1,1.6,1)*100;camera.look_at(Vector3.ZERO)
  var view=camera.global_transform.affine_inverse();var low=Vector2.INF;var high=-low
  for surface in node.mesh.get_surface_count():
   for p:Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    var projected:Vector3=view*p;var xy=Vector2(projected.x,projected.y);low=low.min(xy);high=high.max(xy)
  var projected_size=high-low
  if not baseline:check(absf(projected_size.y/projected_size.x-float(g.rect[3])/float(g.rect[2]))<.01,"Reference-view proportions match the original sprite "+str(serial))
  for surface in node.mesh.get_surface_count():
   for p:Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:check(p.is_finite(),"Prepared native building vertex "+str(serial))
  if not baseline:
   var native_paint:ShaderMaterial=node.mesh.surface_get_material(1)
   check(native_paint.get_shader_parameter("base_texture").resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Native architectural paint uses the preserved RGBA atlas "+str(serial))
   var source_rect=Rect2(Vector2(g.rect[0],g.rect[1]),Vector2(g.rect[2],g.rect[3])).grow(.01)
   var inside=true
   for uv:Vector2 in node.mesh.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV]:inside=inside and source_rect.has_point(uv*native_paint.get_shader_parameter("base_texture").get_size())
   check(inside,"Native roof and detail UVs stay in their own original graphic "+str(serial))
   if serial in [11407,11408,11409,11410,11411,11412,11415,11416]:
    check(node.mesh.get_surface_count()==(3 if serial in [11407,11408] else 2) and node.mesh.get_meta("native_roof",false),"Roof reuses the full original art separately from tiled details "+str(serial))
    var arrays=node.mesh.surface_get_arrays(node.mesh.get_surface_count()-1);var valid_roof=true;var roof_vertices=0
    for i in arrays[Mesh.ARRAY_VERTEX].size():
     if arrays[Mesh.ARRAY_VERTEX][i].y<bounds.end.y*.80:continue
     roof_vertices+=1;valid_roof=valid_roof and arrays[Mesh.ARRAY_NORMAL][i].y>0
    check(roof_vertices>0 and valid_roof,"Curved roof faces outward and remains visible "+str(serial))
  if DisplayServer.get_name()!="headless":
   camera.size=span*1.05
   for side in [0,1]:
    camera.position=center+Vector3(-1 if side==0 else 1,1.6,1 if side==0 else -1).normalized()*span*2;camera.look_at(center)
    for i in 4:await process_frame
    DisplayServer.window_move_to_foreground()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"%d-%d.png"%[serial,side])
  stage.remove_child(node);node.free()
 stage.queue_free();finish()
