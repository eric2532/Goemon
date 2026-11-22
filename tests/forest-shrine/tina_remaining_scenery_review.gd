extends "res://tests/forest-shrine/original_maps_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Tina Recovery/Remaining Details/"
const IDS=[11403,11450,11451,11452,11462,11463,11467,11468,11469,11363,11365,11368,11369,11373,11379,11386]
func run():
 root.size=Vector2i(800,800)
 var stats=[]
 var boundary="--boundary-props" in OS.get_cmdline_user_args()
 var street="--street-props" in OS.get_cmdline_user_args()
 var winter="--winter-props" in OS.get_cmdline_user_args()
 var water="--water-props" in OS.get_cmdline_user_args()
 var marine="--boats-signs" in OS.get_cmdline_user_args()
 var review_root="res://build/Other Files/Asset Toolkit/Tina Recovery/Boats Signs/" if marine else REVIEW
 var ids=[11500,11501,11489,11495,11496,11497,11499] if marine else IDS
 if street:
  review_root="res://build/Other Files/Asset Toolkit/Tina Recovery/Street Props/"
  ids=[10017,10032,10033,10055]+range(11333,11348)
 if water:
  review_root="res://build/Other Files/Asset Toolkit/Tina Recovery/Night Encounters/Scenery/"
  ids=[11464,11481,11482,11483]
 if winter:
  review_root="res://build/Other Files/Asset Toolkit/Tina Recovery/Winter Details/"
  ids=[11460,11461,11465,11484,11485]
 if boundary:
  review_root="res://build/Other Files/Asset Toolkit/Tina Recovery/Stockades and Porches/"
  ids=[11140,11142,11143,11145,11146,11314]
 var baseline="--baseline" in OS.get_cmdline_user_args()
 if (street or boundary) and not baseline:
  var profile=PackedVector2Array([Vector2(-1,0),Vector2(1,0),Vector2(1,2),Vector2(-1,2)])
  for winding in 2:
   profile.reverse()
   var arrays=Original.Forms.Shapes.extrude(profile,.8).surface_get_arrays(0);var outward=true
   for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
    var a:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var b:Vector3=arrays[Mesh.ARRAY_VERTEX][i+1];var c:Vector3=arrays[Mesh.ARRAY_VERTEX][i+2]
    var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
    outward=outward and normal.dot((a+b+c)/3-Vector3.UP)>.01 and (c-a).cross(b-a).normalized().dot(normal)>.99
   check(outward,"Extruded profiles face outward for either outline winding "+str(winding))
 var folder=review_root+("Before/" if baseline else "After/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var stage=Node3D.new();root.add_child(stage)
 var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("d8d1bb");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.8;stage.add_child(world)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=.7;stage.add_child(sun)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
 for serial in ids:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var family=Original.Forms.kind(serial,false,g)
  var mesh=Original.Forms.mesh(serial,family,g,Original.Art.solid_texture(int(g.page)))
  var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node)
  check(mesh==Original.Forms.mesh(serial,family,g,Original.Art.solid_texture(int(g.page))),"Repeated scenery reuses the cached native mesh "+str(serial))
  var valid=true
  var triangles=0
  for surface in mesh.get_surface_count():
   var vertices:PackedVector3Array=mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   var indices=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else vertices.size())/3
   for p:Vector3 in vertices:valid=valid and p.is_finite()
  stats.append({"graphic":serial,"family":family,"triangles":triangles,"surfaces":mesh.get_surface_count()})
  check(valid and mesh.get_aabb().size.y>.01,"Scenery retains finite solid geometry "+str(serial))
  if not baseline:
   if street or boundary:
    if serial in Original.Forms.Street.WALLS:
     check(family==("detail_palisade" if serial in Original.Forms.Street.STOCKADES else "ruin_wall"),"Source wall section retains its scenery family "+str(serial))
     if serial in Original.Forms.Street.STOCKADES:
      var paint:PackedVector2Array=mesh.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV2];var tiles=Original.Forms.BuildingData.TILES
      check(tiles.tina_hollow_bark in paint and tiles.tina_log_end in paint and tiles.tina_ruin_stone in paint,"Bare stockade keeps distinct bark, end grain and stone depth "+str(serial))
      check(tiles.tina_ruin_snow not in paint,"Bare source stockade does not acquire snow paint "+str(serial))
     var bounds=mesh.get_aabb()
     check(minf(bounds.size.x,bounds.size.z)<=1.61,"Ruined walls retain thin closed depth "+str(serial))
     check(bounds.size.y>1 and bounds.position.y>=-.001,"Wall outlines stand on the original ground datum "+str(serial))
     var material:ShaderMaterial=mesh.surface_get_material(0)
     check(material.get_shader_parameter("base_texture").resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Ruined stone face keeps its original paint "+str(serial))
     var rect=Rect2(Vector2(g.rect[0],g.rect[1]),Vector2(g.rect[2],g.rect[3])).grow(.01);var inside=true
     for uv:Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:inside=inside and rect.has_point(uv*material.get_shader_parameter("base_texture").get_size())
     check(inside,"Wall face UVs remain inside their source graphic "+str(serial))
     var view=Basis.looking_at(Vector3(1,-1.6,-1).normalized()).inverse();var low=Vector2.INF;var high=-low;var uv_low=low;var uv_high=high
     for p:Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
      var projected:Vector3=view*p;var xy=Vector2(projected.x,projected.y);low=low.min(xy);high=high.max(xy)
     for uv:Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:uv_low=uv_low.min(uv);uv_high=uv_high.max(uv)
     var source_size=(uv_high-uv_low)*material.get_shader_parameter("base_texture").get_size();var projected_size=high-low
     check(absf(projected_size.y/projected_size.x-source_size.y/source_size.x)<.01,"Ruined wall face keeps source-view proportions without stretched brick paint "+str(serial))
     var sides=mesh.surface_get_arrays(1);var area=true
     for i in range(0,sides[Mesh.ARRAY_VERTEX].size(),3):
      var a:Vector3=sides[Mesh.ARRAY_VERTEX][i];var b:Vector3=sides[Mesh.ARRAY_VERTEX][i+1];var c:Vector3=sides[Mesh.ARRAY_VERTEX][i+2]
      if (b-a).cross(c-a).length_squared()<.00000001:continue
      var u:Vector2=sides[Mesh.ARRAY_TEX_UV][i];var v:Vector2=sides[Mesh.ARRAY_TEX_UV][i+1];var w:Vector2=sides[Mesh.ARRAY_TEX_UV][i+2]
      area=area and absf((v-u).cross(w-u))>.00000001
     check(area,"Stone ends and coping keep two-dimensional texture area instead of streaks "+str(serial))
    elif serial==11314:
     var material:ShaderMaterial=mesh.surface_get_material(0)
     check(material.get_shader_parameter("base_texture").resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Carved standalone post reuses its own native art")
     var bounds=mesh.get_aabb()
     check(bounds.position.y>=-.001 and bounds.size.y>bounds.size.x*2,"Carved standalone post retains a tall solid shaft and stepped crown")
    elif serial in Original.Forms.Street.BARRELS:
     check(mesh.get_meta("source_barrels")=={10017:1,10032:3,10033:7}[serial],"Barrel grouping retains the visible source count "+str(serial))
     if serial==10033:
      var rows=Original.Forms.Street.BARRELS[serial]
      var lower=Original.Forms.Street.Harbor.point(rows[0][0],0,g)
      var upper=Original.Forms.Street.Harbor.point(rows[1][0],rows[1][4],g)
      check(Vector2(upper.x-lower.x,upper.z-lower.z).length()<.3 and is_equal_approx(upper.y,rows[0][2]),"The upper brown cask rests on the partly hidden green cask")
     var arrays=mesh.surface_get_arrays(1);var facing=true
     for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
      var a:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var b:Vector3=arrays[Mesh.ARRAY_VERTEX][i+1];var c:Vector3=arrays[Mesh.ARRAY_VERTEX][i+2]
      facing=facing and (c-a).cross(b-a).y>0
     check(facing,"Intact source barrel lids have visible closed top faces "+str(serial))
    elif serial==10055:
     check(family=="open_box","The native wooden box is not dispatched as a tree")
     var bounds=mesh.get_aabb();var arrays=mesh.surface_get_arrays(0);var floor=false;var lid=false
     for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
      if arrays[Mesh.ARRAY_NORMAL][i].y<.9:continue
      var p:Vector3=(arrays[Mesh.ARRAY_VERTEX][i]+arrays[Mesh.ARRAY_VERTEX][i+1]+arrays[Mesh.ARRAY_VERTEX][i+2])/3
      if Vector2(p.x-bounds.get_center().x,p.z-bounds.get_center().z).length()>bounds.size.x*.3:continue
      floor=floor or p.y<bounds.size.y*.2;lid=lid or p.y>bounds.size.y*.8
     check(floor and not lid,"Open crate has a recessed floor and no opaque lid")
   if winter:
    check(mesh.get_surface_count()==1,"Winter forms share one cached atlas surface "+str(serial))
    var bounds=mesh.get_aabb()
    check(bounds.position.y>=-.001,"Winter props meet the original ground datum "+str(serial))
    if serial in [11460,11461]:
     check(mesh.get_meta("source_stack_logs")==15,"Firewood retains the rectangular three-row/five-column stack")
     check(mesh.get_meta("source_stack_axis")== (Vector3.BACK if serial==11460 else Vector3.RIGHT),"Stack cut ends retain their native facing "+str(serial))
     var arrays=mesh.surface_get_arrays(0);var snow_low=INF;var wood_high=-INF
     for i in arrays[Mesh.ARRAY_VERTEX].size():
      var tile:Vector2=arrays[Mesh.ARRAY_TEX_UV2][i];var y:float=arrays[Mesh.ARRAY_VERTEX][i].y
      if tile==Original.Forms.BuildingData.TILES.tina_soft_snow:snow_low=minf(snow_low,y)
      elif tile in [Original.Forms.BuildingData.TILES.tina_hollow_bark,Original.Forms.BuildingData.TILES.tina_log_end,Original.Forms.BuildingData.TILES.tina_stack_end_green]:wood_high=maxf(wood_high,y)
     check(snow_low>wood_high-.5,"Snow blankets only the top row instead of every hidden log")
    elif serial==11465:
     check(mesh.get_meta("source_mitten_tip").y>3.9,"Source mitten arm reaches above the snowman's head")
     check(mesh.get_meta("source_face").dot(Vector3(-1,0,1).normalized())>.9,"Snowman face turns toward the native view")
    else:
     check(mesh.get_meta("source_cold_campfire",false) and bounds.size.y<.85,"Cold campfire is low crossed timber and ash, without a rock heap")
   if water:
    if serial in [11482,11483]:
     var axis=Vector3.BACK if serial==11482 else Vector3.RIGHT
     check(mesh.get_meta("source_hollow_log")==axis,"Carved timber trough retains its source axis "+str(serial))
     var arrays=mesh.surface_get_arrays(0);var bounds=mesh.get_aabb();var center=bounds.get_center();var nearest=INF
     var start=center+Vector3.UP*2;var end=center-Vector3.UP*2
     for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
      var hit=Geometry3D.segment_intersects_triangle(start,end,arrays[Mesh.ARRAY_VERTEX][i],arrays[Mesh.ARRAY_VERTEX][i+1],arrays[Mesh.ARRAY_VERTEX][i+2])
      if hit!=null:nearest=minf(nearest,start.distance_to(hit))
     check(nearest>2.0 and nearest<2.5,"Carved timber has a recessed channel with an open top "+str(serial))
    else:
     var arrays=mesh.surface_get_arrays(0);var water_y=-INF;var rim_y=-INF
     for i in arrays[Mesh.ARRAY_VERTEX].size():
      var tile:Vector2=arrays[Mesh.ARRAY_TEX_UV2][i]
      if tile==Original.Forms.BuildingData.TILES.tina_wash_water:water_y=maxf(water_y,arrays[Mesh.ARRAY_VERTEX][i].y)
      if tile in [Original.Forms.BuildingData.TILES.tina_wash_wood,Original.Forms.BuildingData.TILES.tina_pail_wood]:rim_y=maxf(rim_y,arrays[Mesh.ARRAY_VERTEX][i].y)
     check(water_y>0 and water_y<rim_y-.1,"Water stays recessed below the wooden rim "+str(serial))
     if serial==11464:
      check(mesh.get_meta("source_washboard",false) and mesh.get_surface_count()==2,"Laundry tub retains the leaning washboard and its original paint")
      check(mesh.surface_get_material(1).get_shader_parameter("base_texture").resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Washboard paint uses its preserved source atlas")
     else:check(mesh.get_meta("source_water_pail",false) and mesh.get_aabb().size.y>2,"Water pail retains the arched handle")
   if marine:
    var native_slot=1 if serial in Original.Forms.Details.Harbor.BOATS else 0
    var material:ShaderMaterial=mesh.surface_get_material(native_slot)
    var texture:Texture2D=material.get_shader_parameter("base_texture")
    check(texture.resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Boat/sign faces use their own original RGBA source "+str(serial))
    var rect=Rect2(Vector2(g.rect[0],g.rect[1]),Vector2(g.rect[2],g.rect[3])).grow(.01);var bounded=true
    for uv:Vector2 in mesh.surface_get_arrays(native_slot)[Mesh.ARRAY_TEX_UV]:bounded=bounded and rect.has_point(uv*texture.get_size())
    check(bounded,"Boat/sign lettering and paint stay inside the original graphic "+str(serial))
    if serial in Original.Forms.Details.Harbor.BOATS:
     check(mesh.get_aabb().size.z>25 and mesh.get_aabb().size.x>5,"Native long hull is not squeezed into its single-cell anchor "+str(serial))
     check(mesh.get_meta("source_cargo_count")== (2 if serial==11500 else 1),"Source cargo distinguishes the cabin boat from the open boat "+str(serial))
     check(mesh.get_aabb().position.y>=-2.4,"Boat bottoms and mooring poles meet the existing water level "+str(serial))
     var deck=0;var arrays=mesh.surface_get_arrays(0)
     for i in arrays[Mesh.ARRAY_VERTEX].size():
      if is_equal_approx(arrays[Mesh.ARRAY_VERTEX][i].y,.55) and arrays[Mesh.ARRAY_NORMAL][i].y>.99:deck+=1
     check(deck>=9,"Boat decks clear the water plane instead of flickering into it "+str(serial))
    else:
     var axis=Vector3.RIGHT if serial==11497 else Vector3.BACK
     var a=Original.Forms.Details.Harbor.sign_point(Vector2.ZERO,g,axis)
     var b=Original.Forms.Details.Harbor.sign_point(Vector2(20,20),g,axis)
     var projected=Basis.looking_at(Vector3(1,-1.6,-1).normalized()).inverse()*(b-a)
     check(absf(projected.y/projected.x+1)<.003,"Native sign view keeps source proportions instead of a flattened sliver "+str(serial))
     if serial in [11489,11499]:
      var back_leaf=false
      for n:Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:back_leaf=back_leaf or n.dot(Vector3(-1,0,1).normalized())<-.9
      check(back_leaf,"Source leaf clusters remain visible behind the solid tree sign "+str(serial))
     if serial in [11496,11497]:
      var low=INF;var high=-INF
      for p:Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:low=minf(low,p.y);high=maxf(high,p.y)
      check(high-low<40*Original.Forms.Details.Harbor.PIXEL_HEIGHT,"Oval board face remains separate from its post "+str(serial))
   if serial in [11403,11450,11451,11452,11467,11468,11469]:
    check(mesh.get_surface_count()==2,"Original painted faces remain separate from raised structural detail "+str(serial))
    var material:ShaderMaterial=mesh.surface_get_material(1)
    var texture:Texture2D=material.get_shader_parameter("base_texture")
    check(texture.resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Scenery uses its own preserved original paint "+str(serial))
    var rect=Rect2(Vector2(g.rect[0],g.rect[1]),Vector2(g.rect[2],g.rect[3])).grow(.01);var bounded=true
    for uv:Vector2 in mesh.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV]:bounded=bounded and rect.has_point(uv*texture.get_size())
    check(bounded,"Roof, door and crate paint never samples another graphic "+str(serial))
   if serial==11452:
    var arrays=mesh.surface_get_arrays(0);var low=INF;var high=-INF
    for i in arrays[Mesh.ARRAY_VERTEX].size():
     if arrays[Mesh.ARRAY_TEX_UV2][i]!=Original.Forms.BuildingData.TILES.tina_log_end:continue
     low=minf(low,arrays[Mesh.ARRAY_VERTEX][i].y);high=maxf(high,arrays[Mesh.ARRAY_VERTEX][i].y)
    check(high-low<3,"Shelter silhouette fitting keeps the prepared logs round")
   if serial in [11462,11463]:
    var width=float(g.footprint[0] if serial==11462 else g.footprint[1])*3
    check(is_equal_approx(mesh.get_aabb().size.y,width*.17),"Native loose logs form one flat row "+str(serial))
    var axis=Vector3.BACK if serial==11462 else Vector3.RIGHT;var front=0;var back=0
    for normal:Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
     if normal.dot(axis)>.99:front+=1
     if normal.dot(axis)<-.99:back+=1
    check(front==180 and back==180,"Five solid native logs have closed, outward-facing ends "+str(serial))
   if serial in [11363,11369,11373,11379,11386]:
    var bounds=mesh.get_aabb()
    check(bounds.size.y>Original.Forms.source_height(g)-.01,"Fence posts keep their original height "+str(serial))
    if serial in [11363,11379]:check(bounds.size.x<.4 or bounds.size.z<.4,"Straight source fences retain one rail axis "+str(serial))
    if serial in [11369,11386]:check(bounds.size.x<2.1 and bounds.size.z<2.1,"Fence end pieces retain their short source reach "+str(serial))
  if DisplayServer.get_name()!="headless":
   DisplayServer.window_move_to_foreground()
   var center=mesh.get_aabb().get_center();var span=mesh.get_aabb().size.length();camera.size=span*1.05
   for side in [0,1]:
    camera.position=center+Vector3(-1 if side==0 else 1,1.6,1 if side==0 else -1).normalized()*span*2;camera.look_at(center)
    for i in 4:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder+"%d-%d.png"%[serial,side])
  stage.remove_child(node);node.free()
 if not baseline and not marine:
  for pair in [[11363,11378],[11364,11379],[11369,11384],[11371,11386]]:
   check(Original.Forms.Tina.fence_arms(pair[0])==Original.Forms.Tina.fence_arms(pair[1]),"Snow preserves the original connector direction "+str(pair))
 var report=FileAccess.open(review_root+("before-stats.json" if baseline else "after-stats.json"),FileAccess.WRITE)
 report.store_string(JSON.stringify(stats,"  "))
 stage.queue_free();finish()
