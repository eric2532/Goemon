extends RefCounted
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
const Falan=preload("res://scripts/forest/forest_falan_tour.gd")
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const Market=preload("res://scripts/forest/forest_falan_shopfronts.gd")
const Special=preload("res://scripts/forest/forest_falan_special_exteriors.gd")
const MagicShop=preload("res://scripts/forest/forest_falan_magic_shop.gd")
const Workshop=preload("res://scripts/forest/forest_falan_workshop.gd")
const Architecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
static func pose(world,p:Vector2,scale_:float,angle:float=0)->Transform3D:
 return Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_),Vector3(p.x,world.model.surface_height(p.x,p.y),p.y))
static func trees(world,parent:Node3D):
 parent.set_meta("native_terrain",true)
 var groups={}
 var freyja_crossing=Falan.area(world.model) in ["freyja","east_gate","south_gate"]
 var city_links=Falan.links(world.model,null) if world.model.falan_area=="city" else []
 var shops=Market.match_shops(world.model,city_links)
 var workshop=world.model.falan_area=="city" and Workshop.active(world.model)
 var magic_shop=world.model.falan_area=="city" and MagicShop.active(world.model)
 var sources={"tree":world.model.trees,"rock":world.model.rocks,"props":world.model.props}
 for group in sources:
  for cell in sources[group]:
   var kind:String=world.model.props[cell].kind if group=="props" else group
   var p=Vector2(cell.x*6,cell.y*6)
   if not world.model.scenery_obstacles.has(cell):continue
   var key=Vector2i(floori(p.x/96),floori(p.y/96))
   if not groups.has(key):groups[key]={}
   if not groups[key].has(kind):groups[key][kind]=[]
   var scale_:float=(world.model.trees[cell] if group=="tree" else sources[group][cell].scale)*Scenery.visual_scale(kind)
   if kind=="tree" and is_same(cell,Layout.LANDMARK):scale_*=1.5
   var angle:float=(deg_to_rad(world.model.tree_rotations[cell]) if world.model.tree_rotations.has(cell) else cell.x*.79+cell.y*1.73) if group=="tree" else deg_to_rad(sources[group][cell].rotation)
   groups[key][kind].append([cell,scale_,angle,world.model.scenery_obstacles[cell],shops.get(cell,-1) if group=="props" else -1,workshop and group=="props" and cell in Workshop.MARKERS,magic_shop and group=="props" and cell is Vector2i and cell==MagicShop.ANCHOR])
 # Rebuild only changed 96-metre scenery chunks; terrain and other trees stay put.
 for key in world.scenery_chunks.keys():
  if not groups.has(key):
   var old:Node3D=world.scenery_chunks[key];parent.remove_child(old);old.queue_free();world.scenery_chunks.erase(key)
 for key in groups:
  if world.scenery_chunks.has(key):
   var old:Node3D=world.scenery_chunks[key]
   if old.get_meta("scenery_signature")==groups[key]:continue
   parent.remove_child(old);old.queue_free()
  var chunk=Node3D.new();chunk.name="Scenery_%d_%d"%[key.x,key.y];chunk.set_meta("scenery_signature",groups[key]);parent.add_child(chunk);world.scenery_chunks[key]=chunk
  for kind in groups[key]:
   var poses=[]
   var painted={}
   var recovered={}
   var architecture={}
   for item in groups[key][kind]:
    var cell=item[0];var transform_=pose(world,Vector2(cell.x*6,cell.y*6),item[1],item[2]);transform_.origin.y+=world.model.scenery_heights.get(cell,0)
    if world.model.falan_area=="city" and kind==world.model.props.get(cell,{}).get("kind",""):transform_.origin+=Houses.offset(world.model,cell)
    var civic=world.model.CivicExterior.shell(cell,world.model.props[cell]) if world.model.falan_area=="city" and world.model.props.has(cell) and kind==world.model.props[cell].kind else []
    var house=Houses.family(cell,world.model.props[cell]) if world.model.falan_area=="city" and world.model.props.has(cell) and kind==world.model.props[cell].kind else -1
    var special=Special.spec(world.model,cell) if world.model.falan_area=="city" and kind==world.model.props.get(cell,{}).get("kind","") else []
    if not special.is_empty():Special.build(chunk,world.model,special)
    elif item[5]:
     if cell==Vector2i(-38,26):Workshop.build(chunk,world.model)
    elif item[6]:MagicShop.build(chunk,world.model)
    elif not civic.is_empty():
     world.model.CivicExterior.build(chunk,transform_.origin,civic,true)
     var bodies=world.model.CivicExterior.collision_parts(cell,civic)
     for i in range(1,bodies.size()):
      var body:AABB=bodies[i];body.position+=world.model.scenery_point(cell)
      preload("res://scripts/forest/forest_art.gd").solid(chunk,body.get_center(),body.size,1,"stone")
    elif Houses.source_centered(world.model,cell) and house>=0:
     var record:Array=Architecture.Data.BINDINGS[cell]
     if not architecture.has(record[0]):architecture[record[0]]=[]
     architecture[record[0]].append(Transform3D(Basis(Vector3.UP,PI*.5),transform_.origin))
    elif house>=0:
     if item[4]>0:Market.build(chunk,transform_,item[4])
     if not recovered.has(house):recovered[house]=[]
     recovered[house].append(transform_)
    elif item[4]>0:
     Market.build(chunk,transform_,item[4])
     var roof:Color=Market.PROFILES[item[4]][1]
     if not painted.has(roof):painted[roof]=[]
     painted[roof].append(transform_)
    else:poses.append(transform_)
    var box:AABB=item[3]
    preload("res://scripts/forest/forest_art.gd").solid(chunk,box.get_center(),box.size,1,Scenery.material(kind),Scenery.player_passable(kind)).set_meta("map_scenery_cell",cell)
   if freyja_crossing and kind=="wall_piece":
    for transform_:Transform3D in poses:
     preload("res://scripts/forest/forest_stone_fort.gd").freyja_wall_segment(chunk,transform_)
   else:Assets.batch(chunk,Scenery.asset(kind),poses,Scenery.wind(kind))
   for roof in painted:Assets.batch(chunk,Scenery.asset(kind),painted[roof],false,0.0,Color.WHITE,roof)
   for house in recovered:Houses.batch(chunk,kind,house,recovered[house])
   for serial in architecture:Architecture.batch(chunk,serial,architecture[serial])
 if world.model.falan_area=="city":
  Architecture.build_unmarked(parent,world.model)
  var old=parent.get_node_or_null("ArchivedFalanGardens")
  if old==null or old.get_meta("garden_plan")!=world.model.falan_garden_plan:
   if old!=null:
    parent.remove_child(old)
    old.queue_free()
   world.model.CityGardens.build(parent,world.model)
  var goods=parent.get_node_or_null("ArchivedFalanMarketGoods")
  if goods==null or goods.get_meta("obstacles")!=world.model.scenery_obstacles or goods.get_meta("links")!=city_links:
   if goods!=null:
    parent.remove_child(goods)
    goods.queue_free()
   Market.Goods.build(parent,world.model,city_links,Falan.NPCS.AREAS.city)
 for material in Assets.wind_materials.values():
  if material.get_shader_parameter("canopy")==true and material not in world.fog_materials:world.fog_materials.append(material)
static func build(world,parent:Node3D):
 var root=Node3D.new();root.name="WindMeadowValley";root.set_meta("native_terrain",true);parent.add_child(root)
 var scale_:float=world.model.terrain_scale
 var field=preload("res://scripts/forest/forest_wind_meadow_terrain.gd")
 var mesh=world.model.terrain.mesh()
 var terrain=MeshInstance3D.new();terrain.mesh=mesh;root.add_child(terrain)
 var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/wind_meadow_ground.gdshader");mat.set_shader_parameter("roads",load(field.asset_path("roads.png",scale_)));mat.set_shader_parameter("map_extent",240*scale_);mat.set_shader_parameter("cliff",preload("res://assets/textures/wind_meadow/cliff_paint.png"));terrain.material_override=mat;world.kai_materials.append(mat);world.attack_materials.append(mat)
 mat.set_shader_parameter("map_scale",world.model.falan_scale)
 mat.set_shader_parameter("castle_stone_texture",preload("res://assets/models/environments/wind_meadow/buildings/wall_section_architecture_paint.png"));mat.set_shader_parameter("castle_half_size",Layout.CASTLE_HALF_SIZE if world.model.raised_castle else 0.0)
 mat.set_shader_parameter("castle_stairs",Vector2(Layout.STAIR_HALF_WIDTH+absf(Layout.CASTLE_GATES[0].x)+3.0,Layout.STAIR_BOTTOM+3.0))
 if world.model.falan_area in ["sokia_coast","sokia_desert","ghana_road","kili"]:mat.set_shader_parameter("use_coastal_sand",true)
 if world.model.falan_area in ["ghana","ghana_north_road"]:mat.set_shader_parameter("use_ghana_palette",true)
 if world.model.map_expansion!=1.0 and world.model.terrain_detail!=world.model.Arena.ID and not Frontier.Sokia.owns(world.model.falan_area):
  var apron=MeshInstance3D.new();var source=load(field.asset_path("terrain.res",scale_));var edge=ArrayMesh.new()
  edge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(1));apron.mesh=edge;apron.scale=Vector3(world.model.map_expansion,1,world.model.map_expansion);apron.material_override=mat;root.add_child(apron)
 var body=StaticBody3D.new();body.name="ValleyTerrainCollision";body.collision_layer=1;body.collision_mask=0;root.add_child(body)
 var shape=CollisionShape3D.new();shape.shape=world.model.terrain.collision();body.add_child(shape)
 load("res://scripts/halo_impact_material.gd").tag_terrain(body,world.model,mesh)
 if world.model.terrain_detail==world.model.Arena.ID:
  world.model.Arena.build(world,root,mat)
  return
 if not world.model.terrain_detail.is_empty() or not world.model.falan_area.is_empty():preload("res://scripts/forest/forest_freyja_art.gd").build(root,mat,world.model.terrain,world.model.falan_scale)
 if world.model.falan_area in ["il_village","alyut"]:
  var grass_tile:Vector2=(Frontier.Il if world.model.falan_area=="il_village" else Frontier.Alyut).GRASS_TILE
  mat.set_shader_parameter("freyja_grass_tile",Vector4(grass_tile.x/255.0,grass_tile.y/255.0,0,1))
  var bounds:Rect2=world.model.terrain.mask_bounds()
  mat.set_shader_parameter("clip_village",true)
  mat.set_shader_parameter("village_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
  if Falan.Regions.private_source_context==null or not Falan.Regions.private_source_context.owns(world.model):
   preload("res://scripts/forest/forest_village_vista.gd").build(root,world.model,mat)
 if Frontier.FRAMES.has(Falan.area(world.model)):
  var venture:Dictionary=world.get_tree().get_meta("falan_venture",{})
  var areas:Dictionary=venture.get("falan_areas",world.model.falan_areas)
  Frontier.city_vista(root,world,areas.get("city",{}),mat)
 if not world.model.falan_frontier_plan.is_empty():
  Frontier.outer_art(root,world.model)
 Frontier.build_village(root,world.model)
 preload("res://scripts/forest/forest_freyja_destination_art.gd").build(root,world.model,Falan.area(world.model))
 if world.model.falan_area=="castle":
  var courtyard=preload("res://scripts/forest/forest_falan_courtyard.gd")
  courtyard.build(root)
  for box in courtyard.obstacles():
   preload("res://scripts/forest/forest_art.gd").solid(root,box.get_center(),box.size,1,"stone")
 Falan.build_markers(root,world.model)
 if Falan.Regions.private_source_context!=null and Falan.Regions.private_source_context.owns(world.model):return
 if world.model.falan_area=="castle":return
 if world.model.falan_area=="city":
  preload("res://scripts/forest/forest_falan_streets.gd").build(root,world.model,Falan.NPCS.AREAS.city)
  var bounds:Rect2=world.model.terrain.mask_bounds()
  mat.set_shader_parameter("clip_village",true)
  mat.set_shader_parameter("village_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
  return
 if Frontier.FRAMES.has(Falan.area(world.model)):
  var bounds:Rect2=world.model.terrain.mask_bounds()
  mat.set_shader_parameter("clip_village",true)
  mat.set_shader_parameter("village_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
  return
 if world.model.falan_area in ["south_lakes","kili","ghana"] or Frontier.Sokia.owns(world.model.falan_area):
  var bounds:Rect2=world.model.terrain.mask_bounds()
  mat.set_shader_parameter("clip_village",true)
  mat.set_shader_parameter("village_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
  return
 if world.model.raised_castle:stairs(root,world)
 var rng=RandomNumberGenerator.new();rng.seed=71023
 var camp_positions=[]
 for camp in world.model.portals:camp_positions.append(Vector2(camp.x*6,camp.z*6))
 var camp_clearance=70.0 if world.model.has_enemy_castles() else 14.0
 var foliage=root
 var reused=false
 if Falan.Regions.Data.REGIONS.has(world.model.falan_area):
  # Keep one outdoor region's deterministic batches while visiting its caves.
  var signature=[world.model.falan_area,scale_,world.model.map_expansion,world.model.raised_castle,
   world.model.terrain.terrain_field(),world.model.terrain.pieces.duplicate(true),
   world.model.occupancy.duplicate(),world.model.roads.duplicate(),camp_positions,camp_clearance]
  var cached:Node3D=world.freyja_foliage
  if is_instance_valid(cached) and cached.get_meta("foliage_signature",[])==signature:
   foliage=cached;foliage.reparent(root,false);foliage.show()
   rng.state=foliage.get_meta("foliage_rng_end");reused=true
  else:
   if is_instance_valid(cached):cached.queue_free()
   foliage=Node3D.new();foliage.name="FreyjaFoliage";root.add_child(foliage)
   foliage.set_meta("foliage_signature",signature);world.freyja_foliage=foliage
 if not reused:
  # Spatial batches let the renderer discard plants outside the camera's lawn.
  for cz in range(int(-6*scale_),int(6*scale_)):
   for cx in range(int(-6*scale_),int(6*scale_)):
    foliage_chunk(world,foliage,cx,cz,rng,camp_positions,camp_clearance)
  if foliage!=root:foliage.set_meta("foliage_rng_end",rng.state)
 scale_*=world.model.map_expansion
 var mountains=[]
 var mountain_base=-4.0 if not world.model.falan_road.is_empty() or Frontier.Regions.Data.RIDGES.has(world.model.falan_area) else 20.0
 for i in 28:
  var angle=i*TAU/28;var radius=rng.randf_range(310,344)*scale_
  mountains.append(Transform3D(Basis(Vector3.UP,angle+rng.randf()).scaled(Vector3.ONE*rng.randf_range(1.6,2.5)),Vector3(cos(angle)*radius,mountain_base,sin(angle)*radius)))
 for i in 20:
  var angle=i*TAU/20;var radius=rng.randf_range(340,460)*scale_
  mountains.append(Transform3D(Basis(Vector3.UP,angle+rng.randf()).scaled(Vector3.ONE*rng.randf_range(1.7,3.3)),Vector3(cos(angle)*radius,-15,sin(angle)*radius)))
 Assets.batch(root,"terraced_mountain",mountains)
 var horizon=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2.ONE*maxf(2400,1200*scale_);horizon.mesh=plane;horizon.position.y=-22;horizon.material_override=mat;root.add_child(horizon)

static func refresh_foliage(world,previous:Dictionary,regions:Array=[]):
 if world.model.falan_area in ["kili","ghana"] or Frontier.Sokia.owns(world.model.falan_area):return
 var root=world.map_features.get_node_or_null("WindMeadowValley")
 if root==null:return
 var archived=root.get_node_or_null("FreyjaFoliage")
 if archived!=null:
  root=archived
  root.remove_meta("foliage_signature")
 var changed=previous.duplicate();changed.merge(world.model.occupancy)
 var chunks={}
 for bounds:Rect2 in regions:
  var area=bounds.grow(2)
  for x in range(floori(area.position.x/36),floori(area.end.x/36)+1):
   for z in range(floori(area.position.y/36),floori(area.end.y/36)+1):chunks[Vector2i(x,z)]=true
 for cell in changed:
  if previous.has(cell)==world.model.occupancy.has(cell):continue
  for x in range(floori((cell.x*6-3)/36.0),floori((cell.x*6+3)/36.0)+1):
   for z in range(floori((cell.y*6-3)/36.0),floori((cell.y*6+3)/36.0)+1):chunks[Vector2i(x,z)]=true
 var camps=[]
 for camp in world.model.portals:camps.append(Vector2(camp.x*6,camp.z*6))
 for key in chunks:
  var chunk=root.get_node_or_null("Foliage_%d_%d"%[key.x,key.y])
  if chunk==null:continue
  var rng=RandomNumberGenerator.new();rng.seed=71023;rng.state=chunk.get_meta("rng_state")
  root.remove_child(chunk);chunk.queue_free()
  foliage_chunk(world,root,key.x,key.y,rng,camps,70.0 if world.model.has_enemy_castles() else 14.0)
static func foliage_chunk(world,root:Node3D,cx:int,cz:int,rng:RandomNumberGenerator,camp_positions:Array,camp_clearance:float):
 var chunk=Node3D.new();chunk.name="Foliage_%d_%d"%[cx,cz];chunk.position=Vector3(cx*36,0,cz*36);root.add_child(chunk)
 chunk.set_meta("rng_state",rng.state)
 var groups={"grass_short":[],"flowers_blue":[],"flowers_ivory":[],"flowers_coral":[],"leafy_shrub":[],"mossy_boulder":[]}
 var roads=foliage_roads(Vector2(cx*36,cz*36),world.model.terrain_scale)
 var camps=[]
 for camp in camp_positions:
  if Rect2(Vector2(cx*36,cz*36),Vector2(36,36)).grow(camp_clearance).has_point(camp):camps.append(camp)
 var area=Falan.area(world.model)
 var gate_district=Frontier.FRAMES.has(area)
 var east_mask:Image=world.model.terrain.mask_texture().get_image() if area in ["east_gate","east_coast","north_coast","south_lakes"] else null
 var frostpass_apron=Rect2()
 if area=="west_lakes" and world.get_tree().get_meta("falan_venture",{}).has("falan_areas"):
  frostpass_apron=Rect2(Falan.Winter.TRAILHEAD-Vector2(3.1,5.3),Vector2(6.2,11.1))
 var crop_plot=Frontier.Regions.TOMATO_PLOT
 var has_crops=area=="east_gate" and Rect2(Vector2(cx*36,cz*36),Vector2(36,36)).intersects(crop_plot)
 for i in 1800:
  var p=Vector2(cx*36+rng.randf_range(0,36),cz*36+rng.randf_range(0,36));var cell:Vector2i=world.model.cell_of(Vector3(p.x,0,p.y))
  if p.length()>191*world.model.terrain_scale or (absf(p.x-6)<53 and absf(p.y-6)<42) or world.model.occupancy.has(cell) or near_foliage_road(p,roads):continue
  if world.model.raised_castle and Layout.castle_height(p)>0:continue
  var blocked=false
  for camp in camps:
   if p.distance_to(camp)<camp_clearance:blocked=true;break
  if blocked:continue
  if Frontier.Regions.village_contains(area,p):continue
  if world.model.falan_area in ["castle","city"] and world.model.terrain.mask_bounds().has_point(p):continue
  if area in ["il_village","alyut"] and not world.model.terrain.mask_bounds().has_point(p):continue
  if (not world.model.terrain_detail.is_empty() or not world.model.falan_area.is_empty()) and (not world.model.terrain.contains(p.x,p.y) or world.model.terrain.bridge_at(p.x,p.y)):continue
  if gate_district and p.y<56.0 and absf(p.x)<164.0:continue
  var h:float=world.model.surface_height(p.x,p.y)
  if absf(h-world.model.surface_height(p.x+1,p.y+1))>.4:continue
  var asset="grass_short"
  var flower=sin(p.x*.055+sin(p.y*.08))*sin(p.y*.066)
  if flower>.65 and rng.randf()<.28:asset=["flowers_blue","flowers_ivory","flowers_coral"][posmod(cx+cz,3)]
  elif i<640 and i%431==0:asset="mossy_boulder"
  elif i<640 and i%199==0:asset="leafy_shrub"
  if asset in ["mossy_boulder","leafy_shrub"] and world.model.roads.has(cell):continue
  var plant_scale=rng.randf_range(.65,1.0) if asset=="grass_short" else rng.randf_range(.75,1.15)
  var yaw=rng.randf()*TAU
  # Keep the surrounding placements stable by taking all scatter draws before clipping the forecourt.
  if frostpass_apron.has_point(p):continue
  if has_crops and crop_plot.has_point(p):continue
  if area=="laruka" and Frontier.IlLaruka.paved(p):continue
  if east_mask!=null and (area in ["east_coast","north_coast","south_lakes"] or p.y>=153.0) and not Frontier.east_scatter_clear(east_mask,world.model.terrain.mask_origin(),p):continue
  var transform_=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*plant_scale),Vector3(p.x,h,p.y));transform_.origin-=chunk.position;groups[asset].append(transform_)
 for asset in groups:Assets.batch(chunk,asset,groups[asset],asset!="mossy_boulder",48 if asset=="grass_short" or asset.begins_with("flowers") else 0)

static func stairs(parent:Node3D,world:Node3D):
 var root=Node3D.new();root.name="CastleSideStairs";root.set_meta("native_terrain",true);parent.add_child(root)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var stone=preload("res://scripts/forest/forest_stone_fort.gd").material(Color("92998c"),false).duplicate()
 stone.set_shader_parameter("use_castle_stone",true);stone.set_shader_parameter("castle_stone_texture",preload("res://assets/models/environments/wind_meadow/buildings/wall_section_architecture_paint.png"))
 world.attack_materials.append(stone)
 var run=.75*Layout.CASTLE_SCALE;var count=roundi((Layout.STAIR_BOTTOM-Layout.STAIR_TOP)/run)
 for i in 4:
  var normal:Vector2=Layout.CASTLE_DIRECTIONS[i];var gate:Vector2=Layout.CASTLE_GATES[i]
  for step in range(-1,count):
   var distance=(Layout.STAIR_INNER+Layout.STAIR_TOP)*.5 if step<0 else Layout.STAIR_TOP+(step+.5)*run
   var p=gate+normal*(distance-Layout.CASTLE_HALF_SIZE)
   var height_=Layout.castle_height(p-normal*run*.5) if step>=0 else Layout.castle_height(p)
   var depth=Layout.STAIR_TOP-Layout.STAIR_INNER if step<0 else run
   var size_=Vector3(Layout.STAIR_HALF_WIDTH*2,height_,depth) if normal.y!=0 else Vector3(depth,height_,Layout.STAIR_HALF_WIDTH*2)
   # Fine treads sit on the shared smooth stair collision, avoiding per-step bumps.
   boxes.add(Vector3(p.x,height_*.5+.025,p.y),size_,stone)
 boxes.build(root)

static func foliage_roads(origin:Vector2,scale_:float)->Array:
 var result=[];var bounds=Rect2(origin,Vector2(36,36))
 for route in Layout.routes(scale_):
  for i in range(1,route.size()):
   var a:Vector2=route[i-1];var delta:Vector2=route[i]-a
   # A segment outside the expanded chunk cannot exclude any of its plants.
   if bounds.intersects(Rect2(a,Vector2.ZERO).expand(route[i]).grow(9)):
    result.append([a,delta,delta.length_squared()])
 return result
static func near_foliage_road(p:Vector2,roads:Array)->bool:
 for road in roads:
  var a:Vector2=road[0];var delta:Vector2=road[1]
  if p.distance_to(a+delta*clampf((p-a).dot(delta)/road[2],0,1))<9:return true
 return false
