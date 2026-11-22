extends "res://tests/forest-shrine/original_maps_test.gd"
const Beast=Original.Beast
const REVIEW="res://build/Other Files/Asset Toolkit/Jenova Beast Recovery/"
const TOWNS=[51004,4001,4002,4008,4009,4010,4011,4012,4013,51006,4021,4022,4099]
var normal_captures=[]

func run():
 if "--visibility-geometry" in OS.get_cmdline_user_args():
  export_castle_geometry();await finish();return
 if "--late-sculptures" not in OS.get_cmdline_user_args() and "--jenova-only" not in OS.get_cmdline_user_args():beast_data_checks()
 if "--data-only" in OS.get_cmdline_user_args():await finish();return
 if "--boundary-profile" in OS.get_cmdline_user_args():profile_boundaries();await finish();return
 if "--details-review" in OS.get_cmdline_user_args():await review_details();await finish();return
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-jenova-beast-test.cfg"
 root.add_child(game);current_scene=game
 root.gui_disable_input=true
 for i in 4:await process_frame
 var saved=Tour.Document.new(false)
 var error=saved.read_file(Tour.Document.MAP_FOLDER.path_join(Tour.Document.saved_filename("Freyja and Falan - Test")))
 check(error.is_empty(),"Existing Falan start map validates: "+error)
 if not error.is_empty():await finish();return
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.model.team_progression.cards_enabled=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;set_meta(Winter.SLAIN,{})
 if "--late-sculptures" in OS.get_cmdline_user_args():
  Tour.travel(game,Original.layout(Original.SHALENA_SOUTH),{"arrival":Original.source_point(Original.SHALENA_SOUTH,Vector2i(136,336)),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  await photograph_beast("castle",game.model.world_point(Original.source_point(Original.SHALENA_SOUTH,Vector2i(135,333))))
  if "--normal-camera" in OS.get_cmdline_user_args():
   var overview=Original.source_point(Original.SHALENA_SOUTH,Vector2i(136,375))
   check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(overview,.15),.5),"Farther normal-camera view stays on the original reachable approach")
   await normal_photograph("castle-overview",overview,0)
   await normal_photograph("castle-approach",Original.source_point(Original.SHALENA_SOUTH,Vector2i(136,352)),0)
   await normal_photograph("castle-approach-turn",Original.source_point(Original.SHALENA_SOUTH,Vector2i(136,352)),PI/6)
   await normal_photograph("castle-entrance",Original.source_point(Original.SHALENA_SOUTH,Vector2i(136,339)),0)
  Tour.travel(game,Original.layout(16512),{"arrival":Original.source_point(16512,Vector2i(26,32)),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  var row=Original.state(16512);var cells:int=row.size.x*row.size.y;var found=[]
  for i in cells:
   var serial:int=row.raw.decode_u16(20+(cells+i)*2)
   if serial not in [16193,16196] or serial in found:continue
   var local=row.origin+Vector2(i%row.size.x,i/row.size.x)*3
   var focus=game.model.world_point(local,3)
   await photograph_beast("armor-"+str(serial),focus)
   if "--normal-camera" in OS.get_cmdline_user_args():
    await normal_photograph("armor-"+str(serial),local+Vector2(0,5),0)
    await normal_photograph("armor-"+str(serial)+"-room-side",local+Vector2(-3 if serial==16193 else 3,5),0)
    await normal_photograph("armor-"+str(serial)+"-turn",local+Vector2(-3 if serial==16193 else 3,5),PI/6)
    await normal_photograph("armor-"+str(serial)+"-inspection",local+Vector2(-3 if serial==16193 else 3,5),-PI/4)
   found.append(serial)
   if found.size()==2:break
  check(found.size()==2,"Both original armor poses are present in the recovered castle room")
  beast_data_checks();await finish();return
 if "--castle-only" in OS.get_cmdline_user_args():
  Tour.travel(game,Original.layout(Original.SHALENA_SOUTH),{"arrival":Original.source_point(Original.SHALENA_SOUTH,Vector2i(136,336)),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  await photograph_beast("castle",game.model.world_point(Original.source_point(Original.SHALENA_SOUTH,Vector2i(135,333))))
  await finish();return
 if "--jenova-only" in OS.get_cmdline_user_args():
  Tour.travel(game,Original.layout(51004),{"arrival":Original.source_point(51004,Vector2i(46,29)),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  await photograph_beast("51004",game.player.position)
  if "--normal-camera" in OS.get_cmdline_user_args():await jenova_street_review()
  await finish();return
 var edge:float=Tour.Frontier.OUTER_EDGE.freyja
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="freyja","Falan west gate opens on foot")
 await position_at(Vector2(-39,419));await position_at(Vector2(-39,421))
 check(Tour.area(game.model)=="west_lakes","Original western approach opens on foot")
 for id in [51001,51002,51003,Original.SHALENA_SOUTH,51004,4001,4002,4001,51004,4008,4009,4021,4009,4022,4009,4008,51004,4010,4011,4010,51004,4012,4013,4012,4099,4012,51004,51006,51004,Original.SHALENA_SOUTH,16510]:
  if not await cross(id):await finish();return
  if id in [51004,16510]:await photograph_beast(str(id),game.player.position)
 for n in Beast.COUNT:
  var id=Beast.FIRST+n
  if not await cross(id):await finish();return
  var next=16511 if n==Beast.COUNT-1 else id+1
  var encounters=Beast.encounters(id,game.model.seed_value)
  check(game.model.enemies.size()==encounters.size() and encounters.size()==24,"Both source species populate the maze")
  for enemy:Dictionary in game.model.enemies.values():
   var expected:Array=encounters[enemy.frostpass_slot.y]
   check(enemy.enemy_name==expected[2] and enemy.level==expected[3],"Source species and dungeon level retained")
   check(game.army_runtime.handles.has(enemy.id),"Maze enemy uses the native lifecycle")
   check(game.army_runtime.native.can_reach(game.player.position,enemy.pos,enemy.footprint),"Native enemy stands in the stair-connected source region")
  game.model.waves.tick_holy_decree()
  check(game.model.enemies.size()==24,"Repeated population does not duplicate maze enemies")
  if n==0:check_bomb_contacts()
  var gate=Original.links(id,game.model.seed_value).filter(func(l):return l.floor==next)[0]
  check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(gate.at,.15),.5),"Native route joins original stairs on beast floor "+str(n+1))
  if n in [0,5,11]:await photograph_beast("maze-%02d"%(n+1),game.player.position)
 if not await cross(16511):await finish();return
 var priest=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor")==16511)[0]
 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(priest.at,.15),.5),"Maze exits into original priest vestibule")
 if not await cross(16511):await finish();return
 var bosses=game.model.enemies.values().filter(func(e):return e.get("boss",false))
 check(bosses.size()==1,"Original named beast uses one native boss")
 if not bosses.is_empty():
  var boss=bosses[0]
  check(boss.enemy_name=="神獸史雷普尼爾" and boss.level==50,"Original boss identity and reference level")
  check(boss.skin==preload("res://scripts/forest/pet_catalog.gd").skin(Beast.BOSS_KEY),"Original 101032 appearance")
  check(game.army_runtime.native.can_reach(game.player.position,boss.pos,boss.footprint),"Boss is reachable past priest barrier")
  await photograph_beast("beast",boss.pos)
  var gate=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("beast_guardian",false))[0]
  var before=game.model
  Tour.enter_link(game,"interior",gate,gate.at)
  check(game.model==before,"Living beast blocks post-boss transfer")
  game.army_runtime.apply_hit(game.army_runtime.handles[boss.id],{"amount":boss.max_hp*4,"direction":Vector3.FORWARD})
  game.army_runtime.dispatch_events()
  check(get_meta(Winter.SLAIN,{}).has(Vector2i(16511,0)),"Native boss death persists route progress")
 for id in [16512,16514,16512,16515,16512,16513,Original.SHALENA_SOUTH,16510]:
  if not await cross(id):await finish();return
  if id in [16512,16513,16514,16515]:await photograph_beast(str(id),game.player.position)
  if id==Original.SHALENA_SOUTH:
   var focus=game.model.world_point(Original.source_point(id,Vector2i(135,333)))
   await photograph_beast("castle",focus)
 check(not game.model.enemies.values().any(func(e):return e.get("boss",false)),"Returning to entrance does not respawn the beast")
 await finish()

func cross(target:int)->bool:
 print("JENOVA_BEAST_ROOM ",target)
 var choices=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor")==target)
 if not choices.is_empty():
  check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(choices[0].at,.15),.5),"Native walking path reaches source door %d → %d"%[game.model.falan_floor,target])
 var reached=await super.cross(target)
 if reached and Original.owns(target):
  var row=Original.state(target,game.model.seed_value)
  for slot in game.exploration_loot.slots:
   if not slot.active or not slot.chest:continue
   var local=Vector2(slot.pos.x,slot.pos.z)/game.model.falan_scale
   var cell=Vector2i(((local-row.origin)/3).round())
   check(Original.open(row.bits,row.size,cell),"Recovered-area chest stays on original walkable ground")
 return reached

func beast_data_checks():
 var round_parts=Original.Forms.Tina
 var level=[1,0,175,65]
 for step in 17:
  var angle=PI*.5+PI*.5*step/16.0
  check(round_parts.round_pixel(angle,level,142,114,true).is_equal_approx(round_parts.round_pixel(angle,level,142,114)),"Circular town walls preserve the native visible hemisphere")
 check(round_parts.round_pixel(PI/4,level,142,114,true).is_equal_approx(round_parts.round_pixel(3*PI/4,level,142,114)),"Circular rear walls mirror interior source paint instead of stretching transparent silhouette edges")
 check(round_parts.hip_point(Vector2(1,1),Vector2(1.04,0),10,12,6,5,Vector3.ZERO,Vector3(-1,0,-1)).is_equal_approx(round_parts.hip_point(Vector2(1,1),Vector2(1.04,0),10,12,6,5,Vector3.ZERO)),"An offset roof peak preserves the original eave footprint")
 var route=[51001,51002,51003,Original.SHALENA_SOUTH,16510]
 for n in Beast.COUNT:route.append(Beast.FIRST+n)
 route.append_array([16511,16512,16513])
 for seed_ in [0,1,341,90824]:
  var paths={}
  for n in Beast.COUNT:
   var id=Beast.FIRST+n;var row=Original.state(id,seed_);var path=Original.path_for(id,seed_)
   check(not paths.has(path),"Shuffle bag does not repeat a cached layout")
   paths[path]=true
   check(row.raw==Original.Art.raw_map(path),"Original maze cells preserved verbatim")
   check(row.raw==Original.state(id,seed_).raw,"Run seed preserves stair identity on return")
   check(connected(id,Original.point(id,Beast.stair(id,seed_,true),seed_),Original.point(id,Beast.stair(id,seed_,false),seed_),seed_),"Original maze stairs are connected")
   var encounters=Beast.encounters(id,seed_)
   check(encounters.size()==24,"Source maze roster has reachable patrol ground")
   check(encounters.all(func(e):return e[3]>=35 and e[3]<=37),"Original dungeon level range")
  check(Original.states.keys().filter(func(key):return Beast.owns(key.x)).size()<=Beast.COUNT,"Maze snapshots are bounded to the current run")
  check(Beast.runs.size()==1,"Shuffle-bag cache retains one run")
  for i in route.size()-1:
   check(Original.links(route[i],seed_).any(func(l):return l.get("floor")==route[i+1]),"Route reaches %d with seed %d"%[route[i+1],seed_])
  for id in route+TOWNS+[16514,16515]:
   var row=Original.state(id,seed_)
   for link in Original.links(id,seed_):
    var cell=Vector2i(((link.at-row.origin)/3).round())
    check(Original.open(row.bits,row.size,cell),"Source gate uses open original ground")
    if link.to!="freyja_door":continue
    var target=Original.state(link.floor,seed_)
    var arrival=Vector2i(((link.arrival-target.origin)/3).round())
    check(Original.open(target.bits,target.size,arrival),"Arrival uses open original ground %d → %d"%[id,link.floor])
 check(Original.crop(Original.SHALENA_SOUTH).has_point(Vector2i(135,333)),"Original castle gate included in playable Shalena")
 check(connected(Original.SHALENA_SOUTH,Original.source_point(Original.SHALENA_SOUTH,Vector2i(196,443)),Original.source_point(Original.SHALENA_SOUTH,Vector2i(135,334))),"Sea cave connects to original castle approach")
 check(connected(51004,Original.source_point(51004,Vector2i(25,39)),Original.source_point(51004,Vector2i(70,18))),"Complete Jenova streets connect west and east gates")
 var well_graphic:Dictionary=Original.Art.data().graphics["11393"]
 var well=Original.Forms.mesh(11393,"detail_well",well_graphic,Original.Art.solid_texture(int(well_graphic.page)))
 check(well.get_meta("native_well",false),"Town well uses the recovered shingle roof and three leaning supports")
 check(is_equal_approx(well.get_aabb().end.y,134*Original.Forms.HEIGHT_PER_PIXEL),"Well uses gameplay scenery height instead of the reference-camera height scale")
 var roof_paint=well.surface_get_material(1).get_shader_parameter("base_texture").get_image()
 var opaque=true
 for uv:Vector2 in well.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV]:
  var pixel=(uv*Vector2(roof_paint.get_size())).floor()
  if roof_paint.get_pixel(int(pixel.x),int(pixel.y)).a<.99:opaque=false
 check(opaque,"Solid well shingles never inherit holes from the sprite's transparent background")
 var center=Original.Forms.Jenova.Harbor.point(Vector2(65,137),0,well_graphic)
 var bottom=-INF
 var ceiling=false
 var roof_height=82*Original.Forms.HEIGHT_PER_PIXEL
 for surface in well.get_surface_count():
  var arrays=well.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  for i in range(0,vertices.size(),3):
   var hit=Geometry3D.segment_intersects_triangle(center+Vector3(.15,3,0),center+Vector3(.15,-1,0),vertices[i],vertices[i+1],vertices[i+2])
   if hit is Vector3:bottom=maxf(bottom,hit.y)
   if surface==0:
    var underside=Geometry3D.segment_intersects_triangle(center+Vector3(.15,roof_height-.4,0),center+Vector3(.15,roof_height+.1,0),vertices[i],vertices[i+1],vertices[i+2])
    if underside is Vector3 and underside.y>roof_height-.2 and underside.y<roof_height:ceiling=true
 check(bottom>=0 and bottom<1,"Original well has an open stone rim and a recessed interior")
 check(ceiling,"The well roof has a solid timber underside from the normal low camera")
 var stair:Dictionary=Original.Art.data().graphics["17111"]
 var stair_mesh=Original.Forms.mesh(17111,"floor",stair,load(Original.Art.ROOT+Original.Art.data().pages[int(stair.page)]))
 var uv=stair_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
 check(uv[0]!=uv[1] and uv[1]!=uv[2],"Hidden wall-cap paint never replaces original floor-stair artwork")
 for serial in [10045,10046,16468,16467,17102,16193,16196,11400,11402,11403,11404,11405]:
  var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
  var family=Original.Forms.kind(serial,false,graphic)
  var solid=Original.Forms.mesh(serial,family,graphic,load(Original.Art.ROOT+Original.Art.data().pages[int(graphic.page)]))
  check(solid!=null and solid.get_aabb().size.y>1,"Recovered Jenova/Beast detail has solid geometry: "+str(serial))
  if serial in [11400,11402,11403,11404,11405]:
   var source_apex=(-float(graphic.origin[1])-(int(graphic.footprint[0])+int(graphic.footprint[1])-2)*12.0)*Original.Forms.HEIGHT_PER_PIXEL
   check(solid.get_aabb().end.y>=source_apex-.1,"House height removes the source compound-ground span once: %d (%f vs %f)"%[serial,solid.get_aabb().end.y,source_apex])
   check(solid.get_meta("native_roof",false),"Jenova roofs use fitted native paint rather than a repeated roof tile")
   check(solid.get_surface_count()>=2,"Jenova retains separate solid structure and original painted surfaces")
   for surface in solid.get_surface_count():
    check(solid.surface_get_material(surface).get_shader_parameter("falan_source_projection")!=true,"Jenova never projects a whole building picture onto its walls")
   var w=float(graphic.footprint[0])*3;var d=float(graphic.footprint[1])*3
   var body=Vector3((w-3)*.5+w*.07,0,(3-d)*.5-d*.07)
   if serial==11403:
    var carved_post=false
    for p:Vector3 in solid.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]:
     if p.x<body.x-w*.42-.6 and p.z>body.z+d*.82*.4 and p.y>.5 and p.y<solid.get_aabb().size.y*.45:carved_post=true
    check(carved_post,"Green-roof porch has a solid carved post beyond the painted wall")
   if serial==11402:
    var band=false
    for p:Vector3 in solid.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
     if p.x>(w-3)*.5+w*.48 and p.y>solid.get_aabb().size.y*.3 and p.y<solid.get_aabb().size.y*.5:band=true
    check(band,"Circular building retains raised timber bands around its curved wall")
   if serial==11405:
    var balcony=false
    for p:Vector3 in solid.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
     if p.x<body.x-w*.42-.6 and p.y>.5 and p.y<solid.get_aabb().size.y*.4:balcony=true
    check(balcony,"Original pub balcony has a raised solid floor and railings")
   if serial==11400:
    var false_porch=false
    for p:Vector3 in solid.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
     if p.z>body.z+d*.41+.3 and p.y>solid.get_aabb().size.y*.06 and p.y<solid.get_aabb().size.y*.4:false_porch=true
    check(not false_porch,"Original house porch stays on the entrance side")
   if serial==11404:
    var fence=false
    var corner=Vector2((w-3)*.5-d*.46,(3-d)*.5-w*.46)
    for p:Vector3 in solid.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
     if Vector2(p.x,p.z).distance_to(corner)<.5 and p.y>1:fence=true
    check(fence,"Bay-house courtyard reuses the original-facing solid wooden fence")
    var deck=false
    var arrays=solid.surface_get_arrays(0)
    for i in arrays[Mesh.ARRAY_VERTEX].size():
     if arrays[Mesh.ARRAY_TEX_UV2][i]==Original.Forms.BuildingData.TILES.timber and arrays[Mesh.ARRAY_NORMAL][i].y>.9 and arrays[Mesh.ARRAY_VERTEX][i].y<solid.get_aabb().size.y*.15:deck=true
    check(not deck,"The original courtyard retains open ground instead of an invented wooden deck")
  if serial in [10045,10046,16468,16467]:
   check(family=="beast_passage" and graphic.solid_outline.size()>100,"Passage retains its own native carved outline")
   check(is_equal_approx(solid.get_aabb().size.z,1.5),"Source gate remains a solid carved frame")
 check(Original.Forms.kind(17102,false,Original.Art.data().graphics["17102"])=="reliquary","Original railed reliquary is not replaced by a wall")
 check_armor_sculptures()
 var castle=preload("res://scripts/forest/forest_beast_castle.gd").mesh()
 var finite=true;var count=0;var triangle_count=0
 for surface in castle.get_surface_count():
  var arrays=castle.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  count+=vertices.size()
  triangle_count+=(indices.size() if indices!=null and not indices.is_empty() else vertices.size())/3
  for p in vertices:finite=finite and p.is_finite()
 check(finite,"Castle detail geometry contains only finite positions")
 var castle_art=preload("res://scripts/forest/forest_beast_castle.gd")
 check(castle==castle_art.mesh(),"Castle architecture and carvings share one cached mesh")
 for surface in [0,1,6]:
  check(castle.surface_get_material(surface).get_shader_parameter("falan_source_projection")!=true,"Castle walls and carvings use fitted surfaces, never the whole-building picture")
 for surface in [0,1]:
  var tiles:PackedVector2Array=castle.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV2]
  check(not tiles.has(Vector2(384,128)) and not tiles.has(Vector2(256,256)),"Window and turret pictures never repeat across castle walls")
 check(castle.surface_get_material(6).get_shader_parameter("atlas_tile_pixels")==0.0,"Carved facades carry fitted original UVs without repeating picture tiles")
 check(castle_art.Paint.material(castle_art.CarvingData.ATLAS).get_shader_parameter("original_palette")==true,"Castle lighting does not mutate shared source paint")
 check(castle.surface_get_material(7).get_shader_parameter("stone_color")==load(Original.Art.ROOT+"beast-castle.png").get_image().get_pixel(33,401),"Solid stone sculptures retain the original pale carving palette")
 for feature in castle_art.CarvingData.FEATURES:
  var detail=castle_art.Carvings.relief(feature,castle_art.CarvingData)
  var bounds=detail.get_aabb()
  check(bounds.size.z>.01 and bounds.position.z>=-.001,"Original carved feature has real raised geometry: "+feature)
 var banner_arrays=castle.surface_get_arrays(0)
 for banner:Dictionary in preload("res://scripts/forest/forest_beast_castle.gd").Sculptures.CASTLE_BANNERS:
  var projected=[]
  for i in banner_arrays[Mesh.ARRAY_VERTEX].size():
   if banner_arrays[Mesh.ARRAY_TEX_UV2][i]!=banner.tile:continue
   projected.append(preload("res://scripts/forest/forest_falan_proportions.gd").project(Basis(Vector3.UP,PI*.5)*banner_arrays[Mesh.ARRAY_VERTEX][i])+Vector2(Original.Art.data().beast_castle.origin[0],Original.Art.data().beast_castle.origin[1]))
  check(projected.size()==6,"Each source banner is placed once as two solid-wall triangles")
  check(banner.quad.all(func(pixel):return projected.any(func(p):return p.distance_to(pixel)<.002)),"Separate banner geometry retains all original image corner positions")
  var middle=Vector3.ZERO
  for i in banner_arrays[Mesh.ARRAY_VERTEX].size():
   if banner_arrays[Mesh.ARRAY_TEX_UV2][i]==banner.tile:middle+=banner_arrays[Mesh.ARRAY_VERTEX][i]/6.0
  var inverse=castle_art.prepared_pose.affine_inverse();var at=inverse*middle;at.z=1.19
  var supported=false;var vertices:PackedVector3Array=banner_arrays[Mesh.ARRAY_VERTEX]
  for i in range(0,vertices.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(at,Vector3.FORWARD,inverse*vertices[i],inverse*vertices[i+1],inverse*vertices[i+2])
   if hit is Vector3 and hit.distance_to(at)<.3:supported=true;break
  check(supported,"Recovered banner is supported by its solid entrance tower")
 var castle_source=preload("res://scripts/forest/forest_beast_castle.gd")
 var crown=castle_source.native_floor(Vector2(387.5,512),0,Original.Art.data().beast_castle)+Vector3.UP*(512.0-422.0)/castle_source.Fit.VERTICAL
 var crown_found=false
 for p:Vector3 in castle.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  if p.distance_to(crown)<.01:crown_found=true;break
 check(crown_found,"Original doorway crown is present in the solid front arch")
 var crown_pixel=preload("res://scripts/forest/forest_falan_proportions.gd").project(Basis(Vector3.UP,PI*.5)*crown)+Vector2(Original.Art.data().beast_castle.origin[0],Original.Art.data().beast_castle.origin[1])
 check(crown_pixel.distance_to(Vector2(388,422))<2,"Solid doorway crown agrees with the native source measurement")
 var columns=castle.surface_get_arrays(4)[Mesh.ARRAY_VERTEX]
 var column_uv=castle.surface_get_arrays(4)[Mesh.ARRAY_TEX_UV]
 for i in castle_source.Sculptures.CASTLE_COLUMNS.size():
  var column:Dictionary=castle_source.Sculptures.CASTLE_COLUMNS[i]
  var foot=castle_source.native_floor(Vector2(column.foot[0],column.foot[1]),0,Original.Art.data().beast_castle)
  var bounds=AABB();var started=false
  for vertex in columns.size():
   if floori(column_uv[vertex].x*2)!=i:continue
   if not started:bounds=AABB(columns[vertex],Vector3.ZERO);started=true
   else:bounds=bounds.expand(columns[vertex])
  check(started and Vector2(bounds.get_center().x,bounds.get_center().z).distance_to(Vector2(foot.x,foot.z))<.002,"Each portal column is centered on its measured native footing")
  check(absf(bounds.size.y-(column.foot[1]-column.top[1])/castle_source.Fit.VERTICAL)<.002,"Portal column height follows its native capital and base")
 var canopy=castle.surface_get_arrays(5)
 var canopy_aligned=true
 var canopy_corners=true
 for i in canopy[Mesh.ARRAY_VERTEX].size():
  var pixel=castle_source.Fit.project(Basis(Vector3.UP,PI*.5)*canopy[Mesh.ARRAY_VERTEX][i])+Vector2(Original.Art.data().beast_castle.origin[0],Original.Art.data().beast_castle.origin[1])
  if pixel.distance_to(canopy[Mesh.ARRAY_TEX_UV][i]*castle_source.Sculptures.CASTLE_DEPTH.get_size())>.002:canopy_aligned=false
 check(canopy_aligned,"Canopy paint follows its own solid faces at the measured native image coordinates")
 for row:Dictionary in castle_source.Sculptures.CASTLE_CANOPY+castle_source.Sculptures.CASTLE_HALL.slice(1):
  for pixel:Array in row.pixels:
   var wanted=castle_source.native_floor(Vector2(pixel[0],pixel[1]),row.height,Original.Art.data().beast_castle)
   var found=false
   for p:Vector3 in canopy[Mesh.ARRAY_VERTEX]:
    if p.distance_to(wanted)<.002:found=true;break
   canopy_corners=canopy_corners and found
 check(canopy_corners,"Both original roof structures retain their measured eave and cornice corners")
 var visibility:Dictionary=preload("res://scripts/forest/forest_beast_castle.gd").Sculptures.CASTLE_VISIBILITY
 check(visibility.ready and visibility.mesh_sha256==castle_hash(castle),"Preserved source-camera geometry proof matches the current solid castle")
 check(preload("res://scripts/forest/forest_beast_castle.gd").Sculptures.CASTLE_FOUNDATION.size()==70,"Original castle footing retains all seventy source cells")
 var audit=FileAccess.open(REVIEW+"castle-mesh.json",FileAccess.WRITE)
 audit.store_string(JSON.stringify({"bounds":str(castle.get_aabb()),"source_fragments":71,"surfaces":castle.get_surface_count(),"textures":["beast-castle.png","beast-castle-surfaces.png","beast-castle-sculpture-surfaces.png","beast-castle-door.png","beast-castle-columns.png","beast-castle-carvings.png","beast-castle-carvings-depth.png","beast-castle-mask.png","beast-castle-visibility.png"],"triangles":triangle_count,"vertices":count},"  "))
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 var before=GDScript.new()
 before.source_code=FileAccess.get_file_as_string(dimensions.resource_path).replace(' "beast_maze":[.6],\n',"")
 check(before.reload()==OK,"Baseline dimensions load for preservation comparison")
 for bank in [null,preload("res://scripts/forest/crowd/habaru_sprites.gd"),preload("res://scripts/forest/crowd/zombie_sprites.gd"),preload("res://scripts/forest/crowd/captain_sprites.gd"),preload("res://scripts/forest/crowd/grave_sprites.gd"),preload("res://scripts/forest/crowd/ruby_boss_sprites.gd"),preload("res://scripts/forest/crowd/falken_sprites.gd"),preload("res://scripts/forest/crowd/undersea_sprites.gd"),preload("res://scripts/forest/crowd/falan_frontier_sprites.gd"),preload("res://scripts/forest/crowd/cursed_maze_sprites.gd")]:
  check(dimensions.geometry(bank)==before.geometry(bank),"Existing companion and enemy body geometry is byte-identical")

func check_armor_sculptures():
 var sculpt=Original.Forms.Palace.Sculptures
 var fit=preload("res://scripts/forest/forest_falan_proportions.gd")
 var audit_rows={}
 for serial in [16193,16196]:
  var mesh=sculpt.armor(serial);var row:Array=sculpt.Data.ARMOR[serial]
  check(mesh==sculpt.armor(serial) and mesh.get_surface_count()==3,"Original armor shares its lance, crest, gauntlet and closed four-view body")
  check(is_equal_approx(mesh.get_aabb().size.y,row[5]),"Original armor keeps the established full-lance height")
  check(mesh.surface_get_material(1).get_shader_parameter("armor_source_parts")==true,"Armor shell retains its own four-view paint")
  check(sculpt.Source.material(sculpt.Data.SOLID).get_shader_parameter("armor_source_views")!=true,"Armor paint does not mutate the shared scenery material")
  var furnishing=Original.Forms.furnishing(serial,"armor",4,3,7,Vector3(9,2,-4))
  var original_frame:Transform3D=mesh.surface_get_material(2).get_meta("armor_source_frame")
  var fitted_frame:Transform3D=furnishing.surface_get_material(2).get_meta("armor_source_frame")
  check((original_frame*mesh.surface_get_arrays(2)[Mesh.ARRAY_VERTEX][0]).distance_to(fitted_frame*furnishing.surface_get_arrays(2)[Mesh.ARRAY_VERTEX][0])<.001,"Fitted palace armor preserves its native paint coordinates")
  var arrays=mesh.surface_get_arrays(0);var inverse:Transform3D=mesh.get_meta("sculpture_fit").affine_inverse()
  var aligned=true
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var p=inverse*arrays[Mesh.ARRAY_VERTEX][i]
   var pixel=fit.project(Basis(Vector3.UP,PI*.5)*p)-Vector2(row[1])
   var uv=arrays[Mesh.ARRAY_TEX_UV][i]*sculpt.Data.ATLAS.get_size()-Vector2(row[0].position)
   if pixel.distance_to(uv)>.002:aligned=false;break
  check(aligned,"Original armor paint projects onto its curved surface without shifting source pixels")
  var edges={}
  for surface in 2:
   var surface_arrays=mesh.surface_get_arrays(surface)
   var points:PackedVector3Array=surface_arrays[Mesh.ARRAY_VERTEX]
   var indices=surface_arrays[Mesh.ARRAY_INDEX]
   var indexed=indices!=null and not indices.is_empty()
   for triangle in range(0,indices.size() if indexed else points.size(),3):
    for edge in 3:
     var a=Vector3i((points[indices[triangle+edge] if indexed else triangle+edge]*100000).round())
     var b=Vector3i((points[indices[triangle+(edge+1)%3] if indexed else triangle+(edge+1)%3]*100000).round())
     if a==b:continue
     var key=[a,b] if a<b else [b,a]
     edges[key]=edges.get(key,0)+1
  var closed=edges.values().all(func(n):return n==2)
  if not closed:
   var counts={}
   for n in edges.values():counts[n]=counts.get(n,0)+1
   print("ARMOR_EDGE_COUNTS ",serial," ",counts," example=",edges.keys().filter(func(key):return edges[key]!=2).slice(0,3))
  check(closed,"Every armor surface edge joins its closed 3D shell")
  var triangles=[]
  for surface in mesh.get_surface_count():
   var a=mesh.surface_get_arrays(surface);var indices=a[Mesh.ARRAY_INDEX]
   triangles.append((indices.size() if indices!=null and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3)
  audit_rows[str(serial)]={"triangles_per_surface":triangles,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb()),"solid_voxels":sculpt.Data.CORE.voxels,"source_relief_parts":[2,7],"round_lance":true}
 var audit=FileAccess.open(REVIEW+"armor-mesh.json",FileAccess.WRITE);audit.store_string(JSON.stringify(audit_rows,"  "))

func castle_hash(mesh:Mesh)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
 for surface in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(surface)
  hash.update(arrays[Mesh.ARRAY_VERTEX].to_byte_array())
  if arrays[Mesh.ARRAY_INDEX]!=null:hash.update(arrays[Mesh.ARRAY_INDEX].to_byte_array())
 return hash.finish().hex_encode()

func export_castle_geometry():
 var mesh=preload("res://scripts/forest/forest_beast_castle.gd").mesh();var points=[]
 for surface in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices=arrays[Mesh.ARRAY_INDEX]
  for i in (indices if indices!=null and not indices.is_empty() else range(vertices.size())):
   var p=vertices[i];points.append([p.x,p.y,p.z])
 var file=FileAccess.open(REVIEW+"castle-visibility-geometry.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"mesh_sha256":castle_hash(mesh),"origin":Original.Art.data().beast_castle.origin,"triangles":points}))

func photograph_beast(label:String,focus:Vector3):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.set_process(false)
 var ceilings=[]
 for node:MeshInstance3D in game.world.find_children("*Ceiling*","MeshInstance3D",true,false):
  if node.visible:node.hide();ceilings.append(node)
 var close=label.begins_with("armor-")
 var offset=Vector3(7,8,8) if close else Vector3(30,34,36)
 if label=="castle":
  var castle=game.world.find_child("RecoveredBeastCastle",true,false) as MeshInstance3D
  check(castle!=null,"Recovered castle is present in exploration")
  if castle!=null:
   var bounds=castle.global_transform*castle.mesh.get_aabb()
   focus=bounds.get_center()-Vector3.UP*2
   offset=Vector3(1,1.603567,1).normalized()*bounds.size.length()*1.3
 game.camera_rig.camera.global_position=focus+offset
 game.camera_rig.camera.look_at(focus+Vector3.UP*2)
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(REVIEW+"3d-"+label+".png")
 if close or label in ["castle","51004","16510","16512"]:
  game.camera_rig.camera.global_position=focus+Vector3(-offset.x,offset.y,offset.z)
  game.camera_rig.camera.look_at(focus+Vector3.UP*2)
  for i in 5:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(REVIEW+"3d-"+label+"-source-facing.png")
 for node in ceilings:node.show()
 game.camera_rig.set_process(true)

func jenova_street_review():
 var row=Original.state(51004);var cells:int=row.size.x*row.size.y;var found=[]
 for i in cells:
  var serial:int=row.raw.decode_u16(20+(cells+i)*2)
  if serial not in [11393,11400,11402,11403,11404,11405] or serial in found:continue
  var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
  for approach in [5,11]:
   var ideal=Vector2i(i%row.size.x,i/row.size.x)+Vector2i(int(graphic.footprint[0])/2,approach)
   var best=Vector2i(-1,-1);var distance=INF
   for y in range(ideal.y-4,ideal.y+5):
    for x in range(ideal.x-4,ideal.x+5):
     var cell=Vector2i(x,y)
     if not Original.open(row.bits,row.size,cell):continue
     var at=Original.source_point(51004,cell)
     if not game.army_runtime.native.can_reach(game.player.position,game.model.world_point(at,.15),.5):continue
     if cell.distance_squared_to(ideal)<distance:best=cell;distance=cell.distance_squared_to(ideal)
   check(best.x>=0,"Original town streets reach building "+str(serial))
   if best.x>=0:
    var label="jenova-"+str(serial)+("-approach" if approach==11 else "")
    await normal_photograph(label,Original.source_point(51004,best),0)
    await normal_photograph(label+"-turn",Original.source_point(51004,best),-PI/4)
    if serial==11393 and approach==5:
     var street=Original.source_point(51004,Original.safe_cell(51004,Vector2i(49,60)))
     check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(street,.15),.5),"Well inspection stays on the original reachable street")
     await normal_photograph("jenova-well-side",street,-PI/4)
  found.append(serial)
 check(found.size()==6,"Original Jenova buildings and well appear in the town")

func normal_photograph(label:String,at:Vector2,yaw:float):
 if DisplayServer.get_name()=="headless":return
 await position_at(at)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance()
 for i in 30:await process_frame
 await RenderingServer.frame_post_draw
 check(is_equal_approx(game.camera_rig.pitch,game.COMBAT_CAMERA_PITCH),"Normal camera keeps the game's default pitch")
 check(is_equal_approx(game.camera_rig.distance,game.ViewPreferences.CAMERA_DEFAULT),"Normal camera keeps the game's default distance")
 check(root.get_texture().get_image().save_png(REVIEW+"normal-"+label+".png")==OK,"Captured actual normal exploration camera")
 normal_captures.append({"shot":label,"yaw":yaw,"pitch":game.camera_rig.pitch,"distance":game.camera_rig.distance,"collision_distance":game.camera_rig.current_distance,"fov":game.camera_rig.camera.fov,"camera":str(game.camera_rig.camera.global_position),"player":str(game.player.position)})
 var audit=FileAccess.open(REVIEW+"normal-camera-captures.json",FileAccess.WRITE);audit.store_string(JSON.stringify(normal_captures,"  "))

func check_bomb_contacts():
 var sprites=preload("res://scripts/forest/crowd/beast_maze_sprites.gd")
 var roles=preload("res://scripts/forest/forest_enemy_roles.gd")
 var probe=ClassDB.instantiate("GoemonCrowdRuntime");probe.configure(64,2000)
 check(probe.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)),"Original bomb attack tables configure the native owner")
 probe.set_navigation(game.army_runtime.navigation_data(game.model))
 var at:Vector3=game.model.enemies.values()[0].pos
 for direction in 8:
  var yaw=direction*TAU/8;var target=at+Vector3(sin(yaw),0,cos(yaw))*1.6
  var targets:Dictionary=game.army_runtime.external_targets()
  targets.positions[0]=target;targets.targetable[0]=1
  targets.minimum[0]+=target-game.player.position;targets.maximum[0]+=target-game.player.position
  probe.set_targets(targets)
  var handle:int=probe.spawn(6000+direction,0,roles.SLIME,at,3000,.5)
  check(probe.set_pet_skin(handle,0),"Original bomb uses its own attack skin")
  probe.set_pose(handle,at,yaw);probe.set_guard(handle,at,14)
  var hits=[]
  for tick in 1200:
   probe.step(1.0/60)
   hits.append_array(probe.take_events().filter(func(e):return e.kind=="external_damage"))
   if hits.size()>=2:break
  check(hits.size()>=2 and hits.all(func(hit):return is_equal_approx(hit.amount,sprites.STATS.damage)),"Repeated original bomb contacts in facing "+str(direction))
  probe.despawn(handle);probe.take_events()

func review_details():
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(1200,1000)
 var stage=Node3D.new();root.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("454f54")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
 environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 stage.add_child(environment)
 var sun=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=.8
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 for serial in [-1,11393,11400,11402,11403,11404,11405,10045,10046,16468,16467,16193,16196,17102]:
  if "--jenova-only" in OS.get_cmdline_user_args() and serial not in [11393,11400,11402,11403,11404,11405]:continue
  if "--sculptures-only" in OS.get_cmdline_user_args() and serial not in [-1,16193,16196]:continue
  var model=MeshInstance3D.new()
  if serial==-1:model.mesh=preload("res://scripts/forest/forest_beast_castle.gd").mesh()
  else:
   var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
   model.mesh=Original.Forms.mesh(serial,Original.Forms.kind(serial,false,graphic),graphic,Original.Art.solid_texture(int(graphic.page)))
  stage.add_child(model)
  var bounds=model.mesh.get_aabb();var center=bounds.get_center();var distance=bounds.size.length()
  camera.size=distance*1.25
  for facing in (3 if "--jenova-only" in OS.get_cmdline_user_args() else 2):
   camera.position=center+(Vector3(-1,1.603567,1) if facing==2 else Vector3(-1 if facing==0 else 1,.8,1)).normalized()*distance*2
   camera.look_at(center)
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(REVIEW+"detail-%d-%d.png"%[serial,facing])==OK,"Captured original detail "+str(serial))
  if serial in [-1,16193,16196]:
   var reference:Rect2
   if serial==-1:
    var data:Dictionary=Original.Art.data().beast_castle
    reference=Rect2(-Vector2(data.origin[0],data.origin[1]),Vector2(data.size[0],data.size[1]))
   else:
    var row:Array=Original.Forms.Palace.Sculptures.Data.ARMOR[serial]
    reference=Rect2(row[1],Vector2(row[0].size))
    model.transform=model.mesh.get_meta("sculpture_fit").affine_inverse()
   var magnification=1 if serial==-1 else 2
   root.size=Vector2i(reference.size)*magnification+Vector2i.ONE*40
   var native_center=reference.get_center();var elevation=20.0 if serial==-1 else 8.0
   var across=native_center.x*3.0/32.0
   var along=(native_center.y+elevation*preload("res://scripts/forest/forest_falan_proportions.gd").VERTICAL)/8.0
   var target=Vector3((across-along)*.5,elevation,(across+along)*.5)
   camera.size=root.size.y/(magnification*sqrt(2.0)*32.0/3.0)
   camera.position=target+Vector3(-1,1.603567,1).normalized()*distance*5;camera.look_at(target)
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(REVIEW+"detail-%d-native-view.png"%serial)==OK,"Captured native sculpture angle")
   root.size=Vector2i(1200,1000)
  stage.remove_child(model);model.free()
 stage.queue_free()

func profile_boundaries():
 var before=GDScript.new()
 before.source_code=FileAccess.get_file_as_string("res://scripts/forest/forest_original_maps.gd").replace('"RecoveredShalenaBoundary_%d"%walls.size()','"RecoveredShalenaBoundary"')
 check(before.reload()==OK,"Previous boundary naming loads for a matched comparison")
 var row=Original.state(Original.SHALENA_SOUTH);var expected=[]
 for source in [before,Original]:
  var stage=Node3D.new();var start=Time.get_ticks_usec()
  var walls=source.boundaries(stage,row.bits,row.size,row.origin)
  print("BEAST_BOUNDARY_PROFILE ","before" if source==before else "after"," milliseconds=",(Time.get_ticks_usec()-start)/1000.0," walls=",walls.size())
  if source==before:expected=walls
  else:
   check(walls==expected,"Unique names preserve every collision boundary byte for byte")
   check(stage.get_child_count()==walls.size(),"All original collision bodies remain present")
  stage.free()
