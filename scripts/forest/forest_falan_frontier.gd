extends RefCounted
## Align the archived gate streets with the city grid. Gate coordinates face outward.
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const Streets=preload("res://assets/maps/falan/city_street_data.gd")
const CityForts=preload("res://scripts/forest/forest_falan_fortifications.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Kili=preload("res://scripts/forest/forest_kili_art.gd")
const Gates=preload("res://assets/maps/falan/gate_exterior_data.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Entrances=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const Sokia=preload("res://scripts/forest/forest_sokia_scenery.gd")
const EastScenery=preload("res://assets/maps/falan/east_gate_scenery_data.gd")
const Il=preload("res://assets/maps/falan/il_restoration_data.gd")
const IlPaint=preload("res://assets/maps/falan/il_buildings.png")
const Alyut=preload("res://assets/maps/falan/alyut_restoration_data.gd")
const AlyutPaint=preload("res://assets/maps/falan/alyut_buildings.png")
const FRAMES={
 "freyja":Transform2D(Vector2.RIGHT,Vector2.DOWN,Vector2(-141,240)),
 "east_gate":Transform2D(Vector2.LEFT,Vector2.UP,Vector2(-135,-225)),
 "south_gate":Transform2D(Vector2.UP,Vector2.RIGHT,Vector2(168,3)),
}
const INNER_EDGE={"freyja":153.0,"east_gate":159.0,"south_gate":153.0}
const OUTER_EDGE=INNER_EDGE
const OUTSIDE_ARRIVAL={"freyja":Vector2(3,165),"east_gate":Vector2(3,174),"south_gate":Vector2(3,171)}
const CITY_ARRIVAL={"freyja":Vector2(-138,378),"east_gate":Vector2(-138,-372),"south_gate":Vector2(303,0)}
const CITY_INWARD={"freyja":Vector3.FORWARD,"east_gate":Vector3.BACK,"south_gate":Vector3.LEFT}
const ENEMY_EDGE=220.0
const COMBAT_EDGE=243.0
# East and South use the same Freyja tile anchors along the outside trail.
const EAST_TO_SOUTH=Transform2D(Vector2.UP,Vector2.RIGHT,Vector2(-18,-15))
const EAST_TRAIL_EDGE=-153.0
const SOUTH_TRAIL_EDGE=129.0

static func to_city(area:String,p:Vector2)->Vector2:
 var frame:Transform2D=FRAMES[area]
 return frame*p

static func from_city(area:String,p:Vector2)->Vector2:
 var frame:Transform2D=FRAMES[area]
 return frame.inverse()*p

static func outer_plan(model)->Array:
 var plan=_outer_plan(model)
 var area:String=model.terrain.variant
 if Sokia.owns(area):plan.append_array(Sokia.collisions(model,Regions.frame(area).inverse()))
 if Regions.CONNECTED_VILLAGES.has(area):
  plan=plan.filter(func(row):return not Regions.village_contains(area,Vector2(row[2].get_center().x,row[2].get_center().z)))
 return plan

static func prepare_village(model):
 var area:String=model.falan_area
 if not Regions.CONNECTED_VILLAGES.has(area):return
 var village:String=Regions.CONNECTED_VILLAGES[area]
 var view=model.get_meta("joined_village") if model.has_meta("joined_village") else null
 if view==null or view.falan_area!=village:
  # Reuse the scenery/query context without creating another wave or army owner.
  view=model.get_script().new()
  view.falan_area=village;view.seed_value=model.seed_value
  view.terrain=model.FreyjaTerrain.new()
  view.terrain.variant=village;view.terrain.horizontal_scale=2.0
  view.terrain.configure([])
  view.falan_frontier_plan=outer_plan(view)
  for i in view.falan_frontier_plan.size():view.register_archive_obstacle(view.falan_frontier_plan[i][2],i)
  model.set_meta("joined_village",view)
 var placement=Regions.village_transform(village)
 var pose=Transform3D(Basis(Vector3.UP,-placement.get_rotation()),Vector3(placement.origin.x,0,placement.origin.y))
 var index=model.falan_frontier_plan.size()
 for box:AABB in view.scenery_obstacles.values():
  model.register_archive_obstacle(pose*box,index)
  index+=1

static func build_village(parent:Node3D,model):
 var view=model.get_meta("joined_village") if model.has_meta("joined_village") else null
 if view==null:return
 var placement=Regions.village_transform(view.falan_area)
 var root=Node3D.new();root.name="Connected_"+view.falan_area
 root.transform=Transform3D(Basis(Vector3.UP,-placement.get_rotation()),Vector3(placement.origin.x,0,placement.origin.y))
 parent.add_child(root)
 outer_art(root,view)
 Entrances.build(root,view,view.falan_area)
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 tour.build_npcs(root,view,tour.VillageNPCs.AREAS.get(view.falan_area,[]),tour.VillageAtlas)

static func _outer_plan(model)->Array:
 var area:String=model.terrain.variant
 if Gates.EXTERIORS.has(area):
  var exterior:Dictionary=Gates.EXTERIORS[area]
  var plan=scenery_plan(model,exterior.trees)
  for row in exterior.forts:
   var serial:int=row[1]
   var p=Vector3(row[0].x,6.0,row[0].y)
   var source_serial={10640:10641,10641:10640}.get(serial,serial) if area=="south_gate" else serial
   var pose=Transform3D(Basis(Vector3.UP,FRAMES[area].get_rotation()),p)
   plan.append([serial,pose,pose*CityForts.Parts.prepare(source_serial).get_aabb()])
  var offset=from_city(area,Vector2.ZERO)
  var city_pose=Transform3D(Basis(Vector3.UP,FRAMES[area].get_rotation()),Vector3(offset.x,0,offset.y))
  for box in CityForts.obstacles(city_forts(area)):plan.append(["archive_city_fort",Transform3D.IDENTITY,city_pose*box])
  add_cliff_obstacles(model,exterior.rocks,plan)
  if area=="east_gate":
   var coast=[]
   var occupied={}
   for row in plan:
    if row[0] is String and Scenery.is_tree(row[0]):occupied[Vector2(row[1].origin.x,row[1].origin.z)]=true
   for row in Regions.Data.TREES.east_coast:
    var at:Vector2=Regions.coast_to_gate(row[0])
    if occupied.has(at):continue
    occupied[at]=true
    coast.append(["pine" if row[1] in [10058,10064,10072] else "tree",at,1.15 if row[1]>=10085 else .9,fposmod(at.x*4+at.y*11,360)])
   for row in Regions.Sites.PROPS.il_village:
    if row[0]!="tree" and row[1].y<=-57:
     coast.append([row[0],Regions.coast_to_gate(row[1]+Regions.IL_TO_ROAD),row[2],fposmod(row[3]-90,360)])
   plan.append_array(scenery_plan(model,coast))
   add_cliff_obstacles(model,coast_ridges(),plan)
  return plan
 if Regions.Sites.PROPS.has(area):
  if Kili.SOURCE.BUILDINGS.has(area):
   var plan=scenery_plan(model,Kili.SOURCE.BUILDINGS[area])
   var origin:Vector2=Regions.Sites.VILLAGES[area][2]
   for row in Kili.SOURCE.SCENERY[area]:
    if row[1] in range(11230,11266):plan.append(Kili.wall_plan(model,origin+Vector2(row[0])*3.0,row[1]))
   return plan
  var plan=scenery_plan(model,Regions.Sites.PROPS[area])
  add_cliff_obstacles(model,village_gate_ridges(area),plan)
  return plan
 if Regions.Data.REGIONS.has(area):
  var woodland=[]
  for row in ([] if Sokia.owns(area) else Regions.Data.TREES[area]):
   var at:Vector2=row[0]
   var kind="pine" if row[1] in [10058,10064,10072] else "tree"
   var size_=1.15 if row[1]>=10085 else .9
   woodland.append([kind,at,size_,fposmod(at.x*4+at.y*11,360)])
  if area=="south_lakes":
   # The first village buildings appear on both archived sides of the warp.
   for row in Kili.SOURCE.BUILDINGS.venoa:
    var at:Vector2=row[1]
    if row[0]!="tree" and at.x>=6:
     var item=row.duplicate()
     item[1]=at+Regions.VENOA_TO_ROAD
     woodland.append(item)
  elif area=="east_coast":
   for row in Regions.Sites.PROPS.il_village:
    var at:Vector2=row[1]
    if row[0]!="tree" and at.y<=-57:
     woodland.append([row[0],at+Regions.IL_TO_ROAD,row[2],row[3]])
  elif area=="west_lakes":
   for row in Regions.Sites.PROPS.laruka:
    var at:Vector2=row[1]
    if row[0]!="tree" and at.x>=-21 and absf(at.y+18)<=42:
     woodland.append([row[0],at+Regions.LARUKA_TO_ROAD,row[2],row[3]])
  elif area=="north_coast":
   for row in Regions.Sites.PROPS.alyut:
    var at:Vector2=row[1]
    if row[0]!="tree" and at.x>=9 and at.y>=-9:
     woodland.append([row[0],at+Regions.ALYUT_TO_ROAD,row[2],row[3]])
  elif area=="sokia_coast":
   for row in Kili.SOURCE.BUILDINGS.kili:
    if row[1].y<-40 or row[0]=="kili_shop":
     var item=row.duplicate()
     item[1]+=Regions.KILI_TO_ROAD
     woodland.append(item)
  var plan=scenery_plan(model,woodland)
  if Sokia.owns(area):
   for row in Sokia.Data.SCENERY[area]:
    if row[1] in range(11230,11266):plan.append(Kili.wall_plan(model,Regions.frame(area).inverse()*(Vector2(row[0])*3.0),row[1]))
  if area=="south_lakes":
   for row in Kili.SOURCE.SCENERY.venoa:
    var at:Vector2=Regions.Sites.VILLAGES.venoa[2]+Vector2(row[0])*3.0
    if row[1] in range(11252,11266) and at.x>=40 and absf(at.y-Regions.VENOA_GATE.y)<=24:
     plan.append(Kili.wall_plan(model,at+Regions.VENOA_TO_ROAD,row[1]))
  add_cliff_obstacles(model,Regions.Data.RIDGES.get(area,[]),plan)
  return plan
 return []

static func village_gate_ridges(area:String)->Array:
 var region:String
 var offset:Vector2
 var bounds:Rect2
 if area=="laruka":
  region="west_lakes"
  offset=Regions.LARUKA_TO_ROAD
  bounds=Rect2(-28,-69,85,51)
 elif area=="alyut":
  region="north_coast"
  offset=Regions.ALYUT_TO_ROAD
  bounds=Rect2(19,23,70,52)
 else:return []
 var result=[]
 for row in Regions.Data.RIDGES[region]:
  var at:Vector2=row[0]-offset
  if not bounds.has_point(at):continue
  result.append([at,row[1],row[2],row[3],row[4]])
 return result

static func coast_ridges()->Array:
 var result=[]
 var occupied={}
 for row in Gates.EXTERIORS.east_gate.rocks:occupied[[row[0],row[1]]]=true
 for row in Regions.Data.RIDGES.east_coast:
  var at:Vector2=Regions.coast_to_gate(row[0])
  if occupied.has([at,row[1]]):continue
  result.append([at,row[1],Vector2(row[2].y,row[2].x),row[3],row[4]])
 return result

static func add_cliff_obstacles(model,rocks:Array,plan:Array):
 var mouth=Entrances.habaru_opening_bounds(model)
 for row in rocks:
  if not row[4]:continue
  var at:Vector2=row[0]
  var extent=Vector3(row[2].x-.25,row[3]*.85,row[2].y-.25)
  var p=Vector3(at.x,model.surface_height(at.x,at.y)+row[3]*.39,at.y)
  var bounds=AABB(p-extent*.5,extent)
  var pieces=[bounds]
  if mouth.has_volume() and bounds.intersects(mouth):
   var overlap=bounds.intersection(mouth)
   pieces.clear()
   # Keep the cliff around and above the enlarged passage solid.
   for axis in 3:
    var low=bounds
    low.size[axis]=overlap.position[axis]-bounds.position[axis]
    if low.size[axis]>.01:pieces.append(low)
    var high=bounds
    high.position[axis]=overlap.end[axis]
    high.size[axis]=bounds.end[axis]-overlap.end[axis]
    if high.size[axis]>.01:pieces.append(high)
    bounds.position[axis]=overlap.position[axis]
    bounds.size[axis]=overlap.size[axis]
  for piece:AABB in pieces:plan.append(["archive_cliff",Transform3D.IDENTITY,piece])

static func replaces_saved_scenery(area:String,cell:Vector2i,kind:String,size_:float,rotation:float,height:float)->bool:
 if not Gates.EXTERIORS.has(area) or not is_zero_approx(height):return false
 var legacy:Array=Gates.EXTERIORS[area].legacy.get(cell,[])
 return not legacy.is_empty() and legacy[0]==kind and is_equal_approx(legacy[1],size_) and is_equal_approx(legacy[2],rotation)

static func scenery_plan(model,placements:Array)->Array:
 var plan=[]
 for row in placements:
  var at:Vector2=row[1]
  var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  if not model.terrain.disk_clear(p,1.2):continue
  var kind:String=row[0]
  var fitted:bool=row[2] is Vector3
  var scale_:Vector3=row[2] if fitted else Vector3.ONE*float(row[2])*Scenery.visual_scale(kind)
  var pose=Transform3D(Basis(Vector3.UP,deg_to_rad(row[3])).scaled(scale_),p)
  var box:AABB
  if Kili.SHELLS.has(kind) or kind in ["kili_palm","ghana_well"]:box=Kili.bounds(kind,pose)
  elif fitted:box=pose*Scenery.CATALOG[kind].box
  else:
   box=Scenery.bounds(kind,row[2],row[3])
   box.position+=p
  plan.append([kind,pose,box,row[4] if row.size()>4 else 0])
 return plan

static func outer_art(parent:Node3D,model):
 var root=Node3D.new()
 root.name="FreyjaOuterRoads"
 parent.add_child(root)
 var batches={}
 var southern_trees={}
 if model.falan_area=="south_lakes":
  for row in Regions.Data.TREES.south_lakes:southern_trees[row[0]]=row[1]
 var forts=[]
 var kili_boxes=preload("res://scripts/forest/forest_static_boxes.gd").new() if model.falan_area in ["kili","ghana","venoa","south_lakes"] or Sokia.owns(model.falan_area) else null
 for row in model.falan_frontier_plan:
  if row[0] is String and row[0]=="sokia_source_collision":
   Art.solid(root,row[2].get_center(),row[2].size,1,"stone").set_meta("sokia_source_collision",true)
   continue
  if row[0] is int:
   forts.append(row)
   var bounds:AABB=row[2]
   Art.solid(root,bounds.get_center(),bounds.size,1,"stone")
   continue
  var kind:String=row[0]
  if kind=="archive_city_fort":continue # The shared city fort builder owns these physical shapes.
  if kind=="archive_cliff":
   var bounds:AABB=row[2]
   Art.solid(root,bounds.get_center(),bounds.size,1,"stone")
   continue
  var il_at=Vector2(row[1].origin.x,row[1].origin.z)
  var village_art=Alyut if model.falan_area=="alyut" else Il
  if model.falan_area in ["il_village","alyut"] and village_art.BUILDINGS.has(il_at):
   var serial:int=village_art.BUILDINGS[il_at]
   var span:Vector2=village_art.GRAPHICS[serial][2]
   var extent:Vector3=row[2].size
   var rise:Vector2=village_art.PROFILES[serial]
   Kili.Buildings.build(root,row[1].origin,serial,village_art,AlyutPaint if model.falan_area=="alyut" else IlPaint,Vector3(extent.x/span.x,extent.y/((rise.x+rise.y)*.045+2.2),extent.z/span.y))
  elif row.size()>3 and Kili.Buildings.Data.PROFILES.has(row[3]):
   Kili.Buildings.build(root,row[1].origin,row[3])
  elif kind=="coastal_wall":Kili.wall(root,kili_boxes,row[1],row[3])
  elif kili_boxes!=null and Kili.SHELLS.has(kind):Kili.shell(kili_boxes,kind,row[1],row[3])
  else:
   var visual=kind
   var tree_at=Vector2(row[1].origin.x,row[1].origin.z)
   if Scenery.is_tree(kind) and southern_trees.has(tree_at):
    var serial:int=southern_trees[tree_at]
    visual=Assets.crossgate_tree(serial)
   if model.falan_area in ["east_gate","east_coast","north_coast"] and Scenery.is_tree(kind):
    var at:Vector3=row[1].origin
    var source:Vector2=(Regions.frame(model.falan_area)*Vector2(at.x,at.z)/3.0).round()
    visual=EastScenery.TREES.get(source,kind)
   if not batches.has(visual):batches[visual]=[]
   batches[visual].append(row[1])
  var box:AABB=row[2]
  Art.solid(root,box.get_center(),box.size,1,"wood" if kind=="kili_palm" else Scenery.material(kind))
 if kili_boxes!=null:kili_boxes.build(root)
 for kind in batches:
  var first=root.get_child_count()
  var asset=kind if kind.begins_with("res://") else Kili.PALM if kind=="kili_palm" else Kili.WELL if kind=="ghana_well" else Scenery.asset(kind)
  Assets.batch(root,asset,batches[kind],kind.begins_with(Assets.DIR+"crossgate_flora/") or Scenery.wind(kind))
  if model.falan_area in ["kili","ghana","ghana_north_road"] and kind=="wall_piece":
   for index in range(first,root.get_child_count()):
    root.get_child(index).material_override=Kili.wall_material()
 if not forts.is_empty():exterior_forts(root,forts,model.terrain.variant)
 if model.falan_area in ["east_gate","east_coast","north_coast"]:east_scenery(root,model)
 if model.falan_area in ["il_village","alyut"]:il_scenery(root,model)
 var area:String=model.terrain.variant
 var rocks:Array=Regions.Data.RIDGES.get(area,Gates.EXTERIORS.get(area,{}).get("rocks",[]))
 if area=="east_gate":rocks=rocks+coast_ridges()
 if area in ["laruka","alyut"]:rocks=village_gate_ridges(area)
 if not rocks.is_empty():
  var ridges=SurfaceTool.new()
  ridges.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in rocks:
   var at:Vector2=row[0]
   if Regions.village_contains(area,at):continue
   if Entrances.UNDERSEA_MOUTHS.SURROUNDINGS.has(area):
    var source=Regions.frame(area)*at/3.0-Vector2((row[2].x/3.0-1.0)*.5,-(row[2].y/3.0-1.0)*.5)
    if Entrances.undersea_surroundings(area,Vector2i(source.round())):continue
   var y:float=model.surface_height(at.x,at.y)
   if not row[4]:y=maxf(y,model.terrain.WATER_HEIGHT-.35)
   if area=="south_lakes" and row[4]:Entrances.crag_cluster(ridges,Vector3(at.x,y,at.y),row[2],row[3],row[1])
   else:Entrances.ridge(ridges,Vector3(at.x,y,at.y),row[2],row[3],row[1],row[4])
  ridges.generate_normals()
  if area=="south_lakes":ridges.index()
  var cliff=Entrances.cliff_material(false,area=="south_lakes")
  Entrances.cut_habaru_mouth(cliff,model,area)
  Geo.mesh(root,ridges.commit(),Vector3.ZERO,cliff).name="ArchivedGateRidges"

static func il_scenery(parent:Node3D,model):
 var root=Node3D.new()
 root.name="ArchivedAlyutGardens" if model.falan_area=="alyut" else "ArchivedIlGardens"
 parent.add_child(root)
 var batches={}
 var protected:Array[Vector2]=[]
 for link in load("res://scripts/forest/forest_falan_tour.gd").links(model,parent.get_tree()):protected.append(link.at)
 var streets=load("res://scripts/forest/forest_falan_streets.gd")
 for row in (Alyut if model.falan_area=="alyut" else Il).DETAILS:
  var at:Vector2=row[0]
  var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  if not streets.fits(model,p,.8,protected):continue
  if not batches.has(row[1]):batches[row[1]]=[]
  batches[row[1]].append(Transform3D(Basis(Vector3.UP,at.x*.17).scaled(Vector3.ONE*(.45 if row[1]=="mossy_boulder" else 1.5)),p))
 for asset in batches:Assets.batch(root,asset,batches[asset])
 village_frontages(root,model)

static func village_frontages(parent:Node3D,model):
 var root=Node3D.new()
 root.name="VillageFrontages"
 parent.add_child(root)
 var streets=load("res://scripts/forest/forest_falan_streets.gd")
 var goods=load("res://scripts/forest/forest_falan_market_goods.gd")
 var boxes=Court.Boxes.new()
 var wood=Court.Fort.material(Color("87613f"),false)
 var cut=Court.Fort.material(Color("bb945d"),false)
 var stone=Court.Fort.material(Color("b8b49c"))
 var brick=Court.Fort.material(Color("9e6c48"))
 var iron=Geo.mat("495751")
 var protected:Array[Vector2]=[]
 var links:Array=load("res://scripts/forest/forest_falan_tour.gd").links(model,parent.get_tree())
 for link in links:protected.append(link.at)
 for npc in preload("res://assets/maps/falan/freyja_npc_data.gd").AREAS.get(model.falan_area,[]):protected.append(npc[0])
 var services={2001:"Equipment",2002:"Tavern",2010:"Hospital",2012:"Village Chief",2013:"General Store",2014:"Church",
  2401:"General Store",2410:"Hospital",2412:"Village Chief",2420:"Residence",2421:"Nancy's House"}
 var flowers=[]
 var shrubs=[]
 var placements:Array[Vector2]=[]
 for link in links:
  if not services.has(link.get("floor",-1)):continue
  var front=Node3D.new()
  front.name="VillageService_"+str(link.floor)
  root.add_child(front)
  for i in 2:
   for offset in [Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4),Vector2(6,3),Vector2(-6,-3),Vector2(3,6),Vector2(-3,-6)]:
    var at:Vector2=link.at+offset
    var p:Vector3=streets.ground(model,at)
    if not streets.fits(model,p,1.7,protected) or placements.any(func(other):return other.distance_to(at)<3.8):continue
    placements.append(at)
    if i==0:
     goods.signpost(boxes,p,10415,wood,cut,iron)
     var label=Label3D.new()
     label.name="VillageServiceSign"
     label.text=services[link.floor]
     label.font_size=32;label.pixel_size=.014
     label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
     label.modulate=Color("f5db9d")
     label.visibility_range_begin=18
     label.visibility_range_end=45
     label.position=p+Vector3.UP*3
     front.add_child(label)
    elif link.floor in [2001,2013,2401]:
     goods.produce(front,boxes,p,10053,wood,cut)
    else:Court.bench(boxes,p,false,2.75,wood)
    break
 # Garden beds follow the existing house corners, leaving roads and doorways open.
 for row in model.falan_frontier_plan:
  if row[0] not in ["falan_townhouse","falan_shop"]:continue
  var bounds:AABB=row[2]
  for side in [-1,1]:
   var at=Vector2(bounds.get_center().x+side*(bounds.size.x*.5+2.2),bounds.get_center().z+bounds.size.z*.32)
   var p:Vector3=streets.ground(model,at)
   if not streets.fits(model,p,1.8,protected) or placements.any(func(other):return other.distance_to(at)<3.8):continue
   placements.append(at)
   boxes.add(p+Vector3.UP*.28,Vector3(2.7,.56,1.8),brick)
   boxes.add(p+Vector3.UP*.59,Vector3(2.85,.12,1.95),stone)
   shrubs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.65,.38,.48)),p+Vector3.UP*.6))
   for x in [-.85,0,.85]:flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.5),p+Vector3(x,.68,.3)))
 Assets.batch(root,"leafy_shrub",shrubs)
 Assets.batch(root,"flowers_coral",flowers)
 boxes.build(root)
 root.set_meta("placements",placements)

static func east_scenery(parent:Node3D,model):
 var root=Node3D.new()
 root.name="ArchivedEastGatePlants"
 parent.add_child(root)
 var mask:Image=model.terrain.mask_texture().get_image()
 var origin:Vector2=model.terrain.mask_origin()
 var batches={}
 var protected:Array[Vector2]=[]
 var street_art=load("res://scripts/forest/forest_falan_streets.gd")
 var frame=Regions.frame(model.falan_area).inverse()
 for link in model.get_meta("falan_links",[]):protected.append(link.at)
 for row in EastScenery.DETAILS:
  var at:Vector2=frame*(row[0]*3.0)
  if Regions.village_contains(model.falan_area,at):continue
  var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  if not east_scatter_clear(mask,origin,at):continue
  if not street_art.fits(model,p,1.25,protected):continue
  var asset:String=row[2]
  if not batches.has(asset):batches[asset]=[]
  batches[asset].append(Transform3D(Basis(Vector3.UP,float(row[1])*.71-frame.get_rotation()).scaled(Vector3.ONE*row[3]),p))
 for asset in batches:Assets.batch(root,asset,batches[asset])

static func east_scatter_clear(mask:Image,origin:Vector2,at:Vector2)->bool:
 var pixel=Vector2i(((at-origin)/3.0).round())
 if not Rect2i(Vector2i.ZERO,mask.get_size()).has_point(pixel):return false
 var tile=mask.get_pixelv(pixel)
 return tile.a>.5 and tile.r<.5 and tile.g<.2 and tile.b<.5

static func exterior_forts(root:Node3D,forts:Array,area:String):
 var groups={}
 for row in forts:
  var serial:int=row[0]
  if area=="south_gate":serial={10640:10641,10641:10640}.get(serial,serial)
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append(Transform3D(Basis(Vector3.UP,FRAMES[area].get_rotation()),row[1].origin))
 for serial in groups:CityForts.Parts.batch(root,serial,groups[serial])

static func city_forts(area:String)->Array:
 if not FRAMES.has(area):return []
 var outside={}
 for row in Gates.EXTERIORS[area].forts:outside[row[0]]=true
 return Streets.FORTIFICATIONS.filter(func(row):
  var at=from_city(area,row[0])
  # The outdoor map already owns the gateway towers and its open entrance beam.
  var inner=36.0 if area=="south_gate" else 60.0
  var entrance=row[1] in [10646,10662] and absf(at.x-3)<=12 and (at.y>=OUTER_EDGE[area]-8.0 or absf(at.y-inner)<=12)
  return not outside.has(at) and not entrance)

static func city_vista(parent:Node3D,model,layout:Dictionary,ground:ShaderMaterial):
 var area:String=model.terrain.variant
 var frame:Transform2D=FRAMES[area]
 var root=Node3D.new()
 root.name="FalanGateDistrict"
 var offset=from_city(area,Vector2.ZERO)
 root.position=Vector3(offset.x,0,offset.y)
 root.rotation.y=frame.get_rotation()
 parent.add_child(root)
 var defenses=city_forts(area)
 if layout.is_empty():
  CityForts.build(root,null,defenses)
  return
 var cached:Dictionary=model.get_meta("city_vista_source",{})
 if cached.get("layout",{})!=layout:
  var view=model.get_script().new();view.reset(model.seed_value,{},layout,false)
  view.waves=null;view.workforce=null;view.ryo=null # This is a scenery/query context, matching connected village views.
  view.set_meta("falan_links",load("res://scripts/forest/forest_falan_tour.gd").links(view,null))
  cached={"layout":layout.duplicate(true),"model":view};model.set_meta("city_vista_source",cached)
 var view=cached.model
 root.set_meta("city_source_model",view)
 var material:ShaderMaterial=ground.duplicate()
 material.set_shader_parameter("use_freyja_surface",false)
 material.set_shader_parameter("city_gate_frame",Vector4.ZERO)
 material.set_shader_parameter("map_frame",root.transform.affine_inverse())
 var bounds:Rect2=FRAMES[area].inverse()*view.terrain.mask_bounds()
 var end:float=model.terrain.bridge_bounds().position.y-9.0
 var crop=Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)
 for mat in [ground,material]:
  mat.set_shader_parameter("adjoining_city_bounds",crop);mat.set_shader_parameter("adjoining_city_end",end)
 material.set_shader_parameter("adjoining_city_layer",true)
 var ground_node=Geo.mesh(root,view.terrain.mesh(),Vector3.ZERO,material);ground_node.name="CompleteFalanGround"
 var freyja_art=load("res://scripts/forest/forest_freyja_art.gd")
 freyja_art.build(root,material,view.terrain,model.falan_scale,false)
 var city_bounds:Rect2=view.terrain.mask_bounds()
 material.set_shader_parameter("clip_village",true)
 material.set_shader_parameter("village_bounds",Vector4(city_bounds.position.x,city_bounds.position.y,city_bounds.end.x,city_bounds.end.y))
 for node in parent.find_children("*","MeshInstance3D",true,false):
  if node.name not in ["FreyjaWater","FalanLilyPond"]:continue
  var mat:ShaderMaterial=node.material_override
  mat.set_shader_parameter("adjoining_city_bounds",crop);mat.set_shader_parameter("adjoining_city_end",end)
  if root.is_ancestor_of(node):
   mat.set_shader_parameter("adjoining_city_layer",true);mat.set_shader_parameter("map_frame",root.transform.affine_inverse())
 CityForts.build(root,material,defenses,func(at):return from_city(area,at).y<end)
 var city_art=load("res://scripts/forest/forest_wind_meadow_art.gd")
 city_art.trees({"model":view,"scenery_chunks":{},"fog_materials":[]},root)
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 preload("res://scripts/forest/forest_falan_streets.gd").build(root,view,tour.NPCS.AREAS.city)
 tour.build_npcs(root,view,tour.NPCS.AREAS.city,tour.ATLAS)
 for body in root.find_children("*","StaticBody3D",true,false):
  if body.has_meta("map_scenery_cell"):body.remove_meta("map_scenery_cell")
