extends RefCounted
## Native footprints and paint on shared solid scenery forms.
# shortcut: profiles fit 2D art; replace a form when a matching authored model is available.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const BuildingData=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const BuildingAtlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
const Buildings=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Crags=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const Stairs=preload("res://scripts/forest/forest_habaru_stairs.gd")
const Coastal=preload("res://scripts/forest/forest_coastal_rooms.gd")
const Inn=preload("res://scripts/forest/forest_falan_inn_art.gd")
const Cellar=preload("res://scripts/forest/forest_falan_cellar_art.gd")
const Chamber=preload("res://scripts/forest/forest_falken_chamber_props.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_rooms.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")
const Details=preload("res://scripts/forest/forest_original_map_details.gd")
const Tina=preload("res://scripts/forest/forest_tina_building_details.gd")
const Jenova=preload("res://scripts/forest/forest_jenova_building_details.gd")
const WinterDetails=preload("res://scripts/forest/forest_tina_winter_details.gd")
const Street=preload("res://scripts/forest/forest_tina_street_details.gd")
const CaveEntrance=preload("res://scripts/forest/forest_original_cave_entrance.gd")
const Cliffs=preload("res://scripts/forest/forest_original_cliffs.gd")
const HEIGHT_PER_PIXEL=.045
const WALLS=[15827,15828,15829,15833,15834,17685,17686,17687,17688,17689,17690,17691,17692,17693,17694,17695,17696,17697,17698]
const STAIRS=[12000,12001,12002,12003,13268,13269,13270,13271,17952,17953,17954,17955,17956,17957]
const CUT_FLOOR=[12002,12003,13269,13271,13997,15891,15892,17953,17955,17957,17971,17987]
static var meshes:Dictionary={}
static var stone_materials:Dictionary={}
static var building_material:ShaderMaterial
static var jenova_material:ShaderMaterial
static var mineral_materials:Dictionary={}

static func kind(serial:int,floor_:bool,g:Dictionary)->String:
 if serial<1000 or g.family=="void":return "void"
 if g.get("shore_bank",false):return "bank"
 if serial in range(5000,5009):return "water"
 if floor_ or g.ground:return "floor"
 if serial in Street.STOCKADES:return "detail_palisade"
 if serial in Street.WALLS:return "ruin_wall"
 if serial==10055:return "open_box"
 var detail=Details.kind(serial)
 if serial==17102:return "reliquary"
 if not detail.is_empty():return detail
 if serial in range(10624,10631):return "parapet"
 if serial in [10611,10612]:return "lamp"
 if serial in range(16303,16333):return "channel"
 if serial==16300 or serial in [16294,16296]:return "column"
 if serial==16286:return "obelisk"
 if serial==17680:return "basin"
 if serial==11394:return "gargoyle"
 if serial==15215:return "bone_pile"
 if serial in [17212,17215]:return "display_bench"
 if serial==17213:return "display_cabinet"
 if serial==16583:return "drawers"
 if serial==16555:return "stove"
 if serial==10023:return "spill_barrel"
 if serial==15329:return "gem"
 if serial==10556:return "loose_bottles"
 if serial==11013:return "coast_logs"
 if serial==16929:return "coast_post"
 if serial in range(13500,13540):return "ice"
 if serial in range(17772,17808):return "cave_crag"
 if serial in [11454,11460,11461,11462,11463]:return "logs"
 if serial in [11466,11467,11468,11469]:return "snow_crate"
 if serial in [11464,11481,11482,11483]:return "tub"
 if serial==11465:return "snowman"
 if serial in [11484,11485]:return "rubble"
 if serial in range(12181,12186) or serial in range(12486,12500):return "grass"
 if serial in range(12455,12486):return "fern"
 if serial in range(12197,12202) or serial in range(12423,12429):return "branch"
 if serial in [12187,12188,12411,12412,12431,12432]:return "conifer_shrub"
 if serial in [12189,12192,12193] or serial in range(12437,12442):return "leafy_shrub"
 if serial in range(12194,12197) or serial in range(12413,12420) or serial in range(12429,12431) or serial in range(12442,12455):return "leafy_stems"
 if serial in range(12420,12423) or serial in range(12433,12437):return "stump"
 if serial==12298:return "cactus"
 if serial in range(12202,12385):return "boulder"
 if serial in range(12385,12411):return "snowdrift"
 if serial in [16287,16288,16289,16290,16297,16299,16301,16346]:return "room_wall"
 if serial in STAIRS:return "stairs"
 if serial in range(10050,10100) or serial in range(11600,11625):return "tree"
 if serial in range(11400,11452) or serial in [11015,11083,11084]:return "building"
 if serial in range(12500,13400):return "rock"
 if serial in WALLS or serial in range(10650,10690):return "wall"
 if serial==10428:return "lamp"
 if serial in [10427,10452,10453]:return "planter"
 if serial in range(11625,11711) or serial in range(12160,12181):return "flowers"
 if serial in range(11300,11363):return "pillar"
 if serial in range(17083,17087):return "pillar"
 if serial==17090:return "grille"
 if serial in [10045,10046,16468,16467]:return "beast_passage"
 if serial==17065:return "wall"
 if serial==10456 or serial in range(11363,11391):return "fence"
 if serial in [10466,10467]:return "plant"
 return g.family if not g.family.is_empty() else "prop"

static func append(skin,shape:Mesh,pose:Transform3D=Transform3D.IDENTITY):
 var normals=pose.basis.inverse().transposed()
 for slot in shape.get_surface_count():
  var arrays=shape.surface_get_arrays(slot)
  var indices=arrays[Mesh.ARRAY_INDEX]
  var indexed=indices is PackedInt32Array and not indices.is_empty()
  for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
   var i=indices[j] if indexed else j
   var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i]
   var normal:Vector3=(normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
   if skin.tiles.is_empty():skin.vertex(p,normal)
   else:
    skin.surface.set_normal(normal)
    if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array and not arrays[Mesh.ARRAY_TEX_UV2].is_empty():
     skin.surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][i]);skin.surface.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][i])
    else:
     skin.surface.set_uv(Vector2(p.x,-p.y)/1.5);skin.surface.set_uv2(skin.tiles[skin.part])
    skin.surface.add_vertex(p)


static func mesh(serial:int,family:String,g:Dictionary,texture:Texture2D)->Mesh:
 var key=[serial,family]
 if meshes.has(key):return meshes[key]
 if serial in [16193,16196] and family=="armor":
  meshes[key]=Palace.Sculptures.armor(serial)
  return meshes[key]
 if serial in range(10640,10655) or serial in range(10670,10686):
  meshes[key]=fortification(serial,g)
  return meshes[key]
 if serial==10609:
  var model=Houses.shape("falan_townhouse",0)
  var w=maxi(1,int(g.footprint[0]))*3.0;var d=maxi(1,int(g.footprint[1]))*3.0
  var height=source_height(g)
  var pose=Transform3D(Basis(Vector3.UP,PI*.5).scaled(Vector3(w/14.0,height/13.4,d/14.0)),Vector3((w-3)*.5,0,(3-d)*.5))
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(model,0,pose)
  meshes[key]=tool.commit();meshes[key].surface_set_material(0,model.surface_get_material(0))
  return meshes[key]
 var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var skin=Source.new([rect,-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,HEIGHT_PER_PIXEL)
 var w=maxi(1,int(g.footprint[0]))*3.0
 var d=maxi(1,int(g.footprint[1]))*3.0
 var height=source_height(g)
 var center=Vector3((w-3)*.5,0,(3-d)*.5)
 skin.projection_center=center
 if serial in CaveEntrance.IDS:
  meshes[key]=CaveEntrance.mesh(serial,g,height);return meshes[key]
 if family=="rock" and Cliffs.owns(serial):
  meshes[key]=Cliffs.mesh(serial,g);return meshes[key]
 if serial==11314:
  var source_art=preload("res://scripts/forest/forest_original_map_art.gd")
  var native=Source.new([rect,-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(source_art.ROOT+source_art.data().pages[int(g.page)]),HEIGHT_PER_PIXEL)
  var levels=[[0.0,.72],[.55,.72],[.57,1.0],[.65,1.0],[.67,.78],[.77,.78],[.79,.98],[1.0,.04]]
  var left=[[Vector2(13,193),Vector2(36,210)],[Vector2(13,88),Vector2(36,104)],[Vector2(1,77),Vector2(36,101)],[Vector2(1,60),Vector2(36,83)],[Vector2(13,60),Vector2(41,77)],[Vector2(13,39),Vector2(41,56)],[Vector2(1,39),Vector2(41,65)],[Vector2(43,1),Vector2(43,1)]]
  var right=[[Vector2(36,210),Vector2(74,185)],[Vector2(36,104),Vector2(74,79)],[Vector2(36,101),Vector2(87,68)],[Vector2(36,83),Vector2(87,50)],[Vector2(41,77),Vector2(76,54)],[Vector2(41,56),Vector2(76,33)],[Vector2(41,65),Vector2(85,36)],[Vector2(43,1),Vector2(43,1)]]
  Tina.pub_post(native,Vector3.ZERO,float(g.rect[2])*3/128,float(g.rect[3])*.1,Vector2.ZERO,levels,[left,right])
  var paint=native.finish();var fit=building_vertical_fit(paint,g)
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  tool.append_from(paint,0,Transform3D(Basis.IDENTITY.scaled(Vector3(1,fit,1)),center))
  meshes[key]=tool.commit();meshes[key].surface_set_material(0,paint.surface_get_material(0));return meshes[key]
 if serial in WinterDetails.IDS:
  meshes[key]=WinterDetails.mesh(serial,g);return meshes[key]
 if serial in Street.WATER_PROPS:
  meshes[key]=Street.water_prop(serial,g);return meshes[key]
 if serial in Street.WALLS:
  meshes[key]=Street.wall_mesh(serial,g);return meshes[key]
 if serial in Street.BENCHES:
  meshes[key]=Street.bench_mesh(serial,g);return meshes[key]
 if serial in Street.MUSHROOMS:
  meshes[key]=Street.mushrooms_mesh(serial,g);return meshes[key]
 if serial in Street.BARRELS:
  meshes[key]=Street.barrel_mesh(serial,g);return meshes[key]
 if serial==10055:
  meshes[key]=Street.open_box(g);return meshes[key]
 if serial in Details.Harbor.BOATS:
  meshes[key]=Details.Harbor.boat_mesh(serial,g);return meshes[key]
 if serial==11393:
  meshes[key]=Jenova.well(g,HEIGHT_PER_PIXEL);return meshes[key]
 if serial==11452 or serial in Tina.CRATES:
  var source_art=preload("res://scripts/forest/forest_original_map_art.gd")
  var native=Source.new([rect,-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(source_art.ROOT+source_art.data().pages[int(g.page)]),HEIGHT_PER_PIXEL)
  var structural=Source.new([],BuildingAtlas,HEIGHT_PER_PIXEL);structural.tiles=BuildingData.TILES
  if serial==11452:Tina.wood_shelter(native,structural,w,d,height)
  else:Tina.crate(native,structural,serial,w,d,height,Vector3.ZERO)
  var body=structural.finish();var paint=native.finish();var joined=Tina.join(body,paint,Transform3D.IDENTITY)
  var fit=building_vertical_fit(joined,g)
  if serial==11452:
   # Preserve round log cross-sections when fitting the source roof's vertical silhouette.
   var arrays=body.surface_get_arrays(0);var material=body.surface_get_material(0)
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    if arrays[Mesh.ARRAY_TEX_UV2][i] not in [BuildingData.TILES.tina_log_bark,BuildingData.TILES.tina_log_end]:continue
    arrays[Mesh.ARRAY_VERTEX][i].y/=fit
    arrays[Mesh.ARRAY_NORMAL][i]=(arrays[Mesh.ARRAY_NORMAL][i]*Vector3(1,fit,1)).normalized()
   body=ArrayMesh.new();body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);body.surface_set_material(0,material)
  meshes[key]=Tina.join(body,paint,Transform3D(Basis.IDENTITY.scaled(Vector3(1,fit,1)),center))
  return meshes[key]
 if serial in [11462,11463]:
  var timber=Source.new([],BuildingAtlas,HEIGHT_PER_PIXEL);timber.tiles=BuildingData.TILES
  Tina.flat_logs(timber,serial,w,d,center);meshes[key]=timber.finish();return meshes[key]
 if family=="detail_sign":
  meshes[key]=Details.sign_mesh(serial,g)
  return meshes[key]
 if family=="detail_arch" and serial==17683:
  var bounds=Chamber.arch().get_aabb()
  meshes[key]=append_fitted(null,Details.build(serial,family),bounds.size.x,bounds.size.z,bounds.size.y,Vector3(3,bounds.position.y,0))
  return meshes[key]
 if family.begins_with("detail_") and family!="detail_flat_panel":
  var stage=Details.build(serial,family)
  var visible=minf(1,float(g.rect[2])/((w+d)*32.0/3.0))
  w*=visible;d*=visible
  if family in ["detail_downstairs","detail_pit"]:
   center.y=-maxf(1.2,(float(g.origin[1])+float(g.rect[3])-24)*HEIGHT_PER_PIXEL)
   height=-center.y+.06
  var native_fit=family in ["detail_snow_stump","detail_snow_boards","detail_snow_log_deck","detail_snowman","detail_snow_bench","detail_open_trough","detail_cards","detail_tea","detail_armor_stand","detail_pedestal","detail_piano"]
  meshes[key]=append_fitted(null,stage,w,d,height,center,g if native_fit else {},family=="detail_snowman")
  return meshes[key]
 if family in ["coast_picture","coast_hanging","coast_clock","coast_wreath"]:
  height=float(g.rect[3])*HEIGHT_PER_PIXEL
  center.y=maxf(0,-(float(g.origin[1])+float(g.rect[3]))*HEIGHT_PER_PIXEL)
  var shift=(float(g.origin[0])+float(g.rect[2])*.5-(int(g.footprint[0])-int(g.footprint[1]))*16.0)*3.0/64.0
  center+=Vector3(shift,0,shift)
  if family=="coast_picture":
   height=maxf(.15,height-24.0*HEIGHT_PER_PIXEL)
   center.y+=12.0*HEIGHT_PER_PIXEL
  skin.projection_center=center
 if family in ["floor","water","detail_flat_panel"]:
  var level=-2.10 if family=="water" else .035 if family=="detail_flat_panel" else .012
  if family=="water":skin.graphic[1].y+=level/HEIGHT_PER_PIXEL
  skin.quad(Vector3(-1.5,level,1.5-d),Vector3(w-1.5,level,1.5-d),Vector3(w-1.5,level,1.5),Vector3(-1.5,level,1.5))
 elif family=="bank":
  var depth=maxf(.2,(float(g.rect[3])+float(g.origin[1])-24)*HEIGHT_PER_PIXEL)
  # Walkable caps stay at the source ground level; painted rock descends to water.
  skin.box(AABB(Vector3(-1.5,-depth,-1.5),Vector3(3,depth+.018,3)))
 elif family=="building":
  if serial in [11400,11402,11403,11404,11405,11407,11408,11409,11410,11411,11412,11413,11414,11415,11416,11451]:
   height=(-float(g.origin[1])-(int(g.footprint[0])+int(g.footprint[1])-2)*12.0)*HEIGHT_PER_PIXEL
  var shape=Source.new([],BuildingAtlas,HEIGHT_PER_PIXEL)
  shape.tiles=BuildingData.TILES.duplicate()
  for paint in ["green_roof","blue_roof","brown_roof"]:shape.tiles["tina_"+paint]=shape.tiles[paint]
  if serial==11408:
   shape.tiles["trim"]=shape.tiles["tina_trim"]
   shape.tiles["window"]=shape.tiles["tina_snow_bay_window"]
  if serial==11407:shape.tiles["tina_green_roof"]=shape.tiles["tina_green_bay_roof"]
  shape.tiles["round_thatch"]=shape.tiles[roof_paint(serial)]
  shape.tiles["plaster"]=shape.tiles["woodwall"] if serial in [11404,11407,11408,11402,11413,11414] else shape.tiles["plaster"]
  if serial in [11407,11409,11410,11411,11412,11414,11415,11416,11451]:
   shape.tiles["plaster"]=shape.tiles["woodwall"]
   shape.tiles["trim"]=shape.tiles["tina_trim"]
  if serial==11416:
   shape.tiles["door"]=shape.tiles["tina_pub_door"]
   shape.tiles["window"]=shape.tiles["tina_pub_window"]
  if serial==11414:
   shape.tiles["plaster"]=shape.tiles["tina_wood"]
   shape.tiles["round_window"]=shape.tiles["tina_round_window"]
   shape.tiles["door"]=shape.tiles["tina_round_door"]
  if serial in [11402,11413]:shape.tiles["door"]=shape.tiles["round_door"]
  if serial==11402:
   shape.tiles["plaster"]=BuildingData.TILES.plaster
   shape.tiles["round_window"]=shape.tiles["jenova_round_window"]
   shape.tiles["door"]=shape.tiles["jenova_round_door"]
  if serial in [11400,11402,11403,11404,11405]:
   shape.tiles["trim"]=shape.tiles["jenova_trim"]
  if serial==11404:shape.tiles["tina_bay_fence"]=shape.tiles["jenova_trim"]
  var source_art=preload("res://scripts/forest/forest_original_map_art.gd")
  var native=Source.new([rect,-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(source_art.ROOT+source_art.data().pages[int(g.page)]),HEIGHT_PER_PIXEL) if serial in Tina.IDS or serial in Jenova.IDS else null
  var underlay=Source.new([Rect2(0,0,g.rect[2],g.rect[3]),Vector2.ZERO,Vector2.ONE,0],load("res://assets/maps/falan/tina/buildings/%d-main-roof.png"%serial),HEIGHT_PER_PIXEL) if serial in [11404,11407,11408] else null
  building(shape,serial,w,d,height,native,underlay)
  var original=shape.finish()
  if native!=null:
   var roof=native.finish();var base_roof=underlay.finish() if underlay!=null else null;var combined=Tina.join(original,roof,Transform3D.IDENTITY,base_roof)
   var fit=building_vertical_fit(combined,g)
   if serial in Jenova.IDS:fit=maxf(1.0,fit)
   meshes[key]=Tina.join(original,roof,Transform3D(Basis.IDENTITY.scaled(Vector3(1,fit,1)),center),base_roof)
  else:
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(original,0,Transform3D(Basis.IDENTITY,center))
   meshes[key]=tool.commit()
  if building_material==null:
   building_material=Source.material(BuildingAtlas,true).duplicate();building_material.set_shader_parameter("original_palette",true)
  meshes[key].surface_set_material(0,building_material)
  if serial in [11400,11402,11403,11404,11405]:
   if jenova_material==null:
    jenova_material=building_material.duplicate();jenova_material.set_shader_parameter("original_palette",false)
   meshes[key].surface_set_material(0,jenova_material)
  return meshes[key]
 elif family=="beast_passage":
  # shortcut: the visible source contour is exact; the client does not record the gate's depth.
  var outline=PackedVector2Array()
  for pixel in g.solid_outline:
   var x=(float(pixel[0])+g.origin[0])*3.0/32.0-1.5
   var y=((1.5-x)*8.0-(float(pixel[1])+g.origin[1]))*HEIGHT_PER_PIXEL
   outline.append(Vector2(x,y))
  var shape=Shapes.extrude(outline,1.5)
  var arrays=shape.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i]+Vector3.BACK*.75
   skin.projected_vertex(p,arrays[Mesh.ARRAY_NORMAL][i],Vector3(p.x,p.y,1.5))
 elif family=="reliquary":
  var base=height*.70
  skin.box(AABB(center+Vector3(-w*.44,0,-d*.44),Vector3(w*.88,base,d*.88)))
  for y in [base,base+.16,height-.12]:
   for side in [-1,1]:
    skin.box(AABB(center+Vector3(-w*.47,y,side*d*.44-.06),Vector3(w*.94,.12,.12)))
    skin.box(AABB(center+Vector3(side*w*.44-.06,y,-d*.47),Vector3(.12,.12,d*.94)))
  for i in 7:
   for side in [-1,1]:
    skin.box(AABB(center+Vector3((i/6.0-.5)*w*.88-.035,base,side*d*.44-.035),Vector3(.07,height-base,.07)))
    skin.box(AABB(center+Vector3(side*w*.44-.035,base,(i/6.0-.5)*d*.88-.035),Vector3(.07,height-base,.07)))
 elif family=="wall":
  skin.box(AABB(Vector3(-1.5,0,1.5-d),Vector3(w,height,d)))
  if serial in range(10650,10690):
   for i in 3:
    skin.box(AABB(Vector3(-1.5+i*w/3, height,1.5-d),Vector3(w/6,.65,d)))
 elif family=="stairs":
  var stage=Node3D.new()
  var base=12002 if serial==12003 else 17954 if serial==17956 else 17955 if serial==17957 else 13268 if serial==13270 else 13269 if serial==13271 else serial
  Stairs.build(stage,0,Vector2i.ZERO,Vector2.ZERO,base,StandardMaterial3D.new())
  var stair:Node3D=stage.get_child(0)
  if serial==12003:stair.rotation.y=-PI*.5
  for part:MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):append(skin,part.mesh,stair.transform*part.transform)
  stage.free()
 elif family in ["rock","boulder"]:
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  Crags.ridge(tool,center,Vector2(w,d)*(.78 if family=="boulder" else 1.0),height*.85,serial,family=="rock")
  tool.generate_normals();append(skin,tool.commit())
 elif family=="parapet":parapet(skin,serial,w,d,height,center)
 elif family=="room_wall":
  skin.box(AABB(Vector3(-1.5,0,1.5-d),Vector3(w,height,d)))
  for y in [.06,height-.14]:skin.box(AABB(Vector3(-1.54,y,1.46-d),Vector3(w+.08,.14,d+.08)))
 elif family=="column":
  Buildings.kili_round(skin,center,[Vector2(.72,0),Vector2(.72,.17),Vector2(.50,.3),Vector2(.36,.48),Vector2(.29,height*.74),Vector2(.53,height*.78),Vector2(.57,height*.81)])
  if serial==16300:
   Buildings.kili_round(skin,center,[Vector2(.57,height*.81),Vector2(.57,height)])
  else:
   var outline=PackedVector2Array([Vector2(-1.50,height),Vector2(1.50,height),Vector2(1.50,height*.96),Vector2(.91,height*.94),Vector2(.67,height*.89),Vector2(.43,height*.80),Vector2(-.43,height*.80),Vector2(-.67,height*.89),Vector2(-.91,height*.94),Vector2(-1.50,height*.96)])
   append(skin,Shapes.extrude(outline,.8),Transform3D(Basis(Vector3.UP,PI*.5 if serial==16296 else 0),center))
 elif family=="obelisk":
  skin.box(AABB(center+Vector3(-.95,0,-.95),Vector3(1.9,height*.84,1.9)))
  var crown=CylinderMesh.new();crown.radial_segments=4;crown.rings=0;crown.top_radius=0;crown.bottom_radius=1.344;crown.height=height*.16
  append(skin,crown,Transform3D(Basis(Vector3.UP,PI*.25),center+Vector3.UP*height*.92))
 elif family=="channel":channel(skin,serial,g,center)
 elif family in ["ice","gem","cave_crag"]:
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  if family in ["ice","gem"]:
   var frost=load("res://scripts/forest/forest_frostpass_art.gd")
   for i in (5 if family=="gem" else 3):
    var at=Vector3(cos(i*2.4)*w*.23,0,sin(i*2.4)*d*.23) if family=="gem" else Vector3((i-1)*w*.22,0,(i%2)*d*.15)
    frost.ice_blade(tool,center+at,height*(1.0-i*.11),Vector2(w*.22,d*.19),Vector2(.08,-.11),serial+i,.10)
  else:Crags.crag_cluster(tool,center,Vector2(w,d),height,serial)
  tool.generate_normals()
  var model=tool.commit()
  if family in ["ice","gem"]:
   if not mineral_materials.has(family):
    var material=load("res://scripts/forest/forest_frostpass_art.gd").ice_surface(51009,true)
    if family=="gem":
     material.set_shader_parameter("ice_color",Color("6f417d"));material.set_shader_parameter("frost_color",Color("c79bd7"))
    mineral_materials[family]=material
   model.surface_set_material(0,mineral_materials[family]);meshes[key]=model
   return model
  append(skin,model)
 elif family in ["snow_crate","logs","tub","snowman","rubble","snowdrift","stump"]:winter_prop(skin,serial,family,w,d,height,center)
 elif family in ["grass","fern"]:leaves(skin,serial,family,height,center)
 elif family in ["branch","conifer_shrub","leafy_shrub","leafy_stems","cactus"]:small_plant(skin,serial,family,w,d,height,center)
 elif family in ["gargoyle","bone_pile"]:sculpture(skin,family,w,d,height,center)
 elif family=="fence":
  if serial in range(11363,11377) or serial in range(11378,11392):
   var native_fence=Source.new([],BuildingAtlas,HEIGHT_PER_PIXEL);native_fence.tiles=BuildingData.TILES
   Tina.fence(native_fence,serial,height);meshes[key]=native_fence.finish();meshes[key].set_meta("source_fence_arms",Tina.fence_arms(serial));return meshes[key]
  var timber=Source.new([],BuildingAtlas,HEIGHT_PER_PIXEL);timber.tiles=BuildingData.TILES;timber.part="timber"
  var high=height*.88
  timber.box(AABB(Vector3(-.12,0,-.12),Vector3(.24,height,.24)))
  for along_x in ([true,false] if serial in [11389,11390] else [serial not in [11363,11368,11370,11378,11383,11385]]):
   timber.part="timber"
   for y in [.35,.71]:
    timber.box(AABB(Vector3(-1.52,high*y,-.09),Vector3(3.04,.17,.18)) if along_x else AABB(Vector3(-.09,high*y,-1.52),Vector3(.18,.17,3.04)))
   if serial>=11378:
    timber.part="snowroof"
    for y in [.35,.71]:timber.box(AABB(Vector3(-1.54,high*y+.08,-.10),Vector3(3.08,.055,.20)) if along_x else AABB(Vector3(-.10,high*y+.08,-1.54),Vector3(.20,.055,3.08)))
  meshes[key]=timber.finish()
  return meshes[key]
 elif family=="pillar":
  if serial in range(17083,17087):
   Buildings.kili_round(skin,Vector3.ZERO,[Vector2(.65,0),Vector2(.65,.18),Vector2(.53,.23),Vector2(.47,.34),Vector2(.35,.45),Vector2(.35,height-.55),Vector2(.49,height-.40),Vector2(.65,height-.30),Vector2(.65,height)])
  else:
   skin.box(AABB(Vector3(-.90,0,-.90),Vector3(1.8,height*.86,1.8)))
   skin.box(AABB(Vector3(-1.18,0,-1.18),Vector3(2.36,.26,2.36)))
   skin.box(AABB(Vector3(-1.35,height*.82,-1.35),Vector3(2.70,height*.18,2.70)))
 elif family=="planter":
  var high=maxf(.35,height*.68)
  skin.box(AABB(Vector3(-1.3,0,-1.3),Vector3(2.6,high,2.6)))
 elif family=="lamp":append(skin,Lamps.shape(serial))
 elif family in ["coast_rug","coast_picture"]:
  var span=Vector3(w,.04,d) if family=="coast_rug" else Vector3(w*.92,height,.10) if w>=d else Vector3(.10,height,d*.92)
  skin.box(AABB(center+Vector3(-span.x*.5,.025,-span.z*.5),span))
 elif family=="barrel":Buildings.kili_round(skin,center,[Vector2(w*.33,0),Vector2(w*.42,height*.18),Vector2(w*.46,height*.50),Vector2(w*.42,height*.82),Vector2(w*.33,height)])
 elif family=="basin":append(skin,Chamber.maze_basin(),Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*height/1.56),center))
 elif family in ["plant","arena_flower"]:
  append(skin,Shapes.urn_mesh(),Transform3D(Basis.IDENTITY.scaled(Vector3(1.6,1.3,1.6)),center))
  leaves(skin,serial,"fern",maxf(1,height-.9),center+Vector3.UP*.9)
 elif family.begins_with("coast_") or family.begins_with("inn_") or family.begins_with("civic_") or family in ["chair","bench","bed","shelf","rack","table","counter","display_bench","display_cabinet","drawers","stove","spill_barrel","loose_bottles","crate","chest","lectern","moon","finial","grille","rope","bust","armor","brazier","state_bed"]:
  if family in ["coast_hanging","coast_clock","coast_wreath"]:
   w=maxf(.5,float(g.rect[2])*3.0/64.0);d=minf(d,.50)
  else:
   var fit=minf(1,float(g.rect[2])/((w+d)*32.0/3.0))
   w*=fit;d*=fit
  meshes[key]=furnishing(serial,family,w,d,height,center)
  return meshes[key]
 else:
  skin.box(AABB(Vector3(-1.5,0,1.5-d),Vector3(w,height,d)))
 var result=skin.finish()
 if g.has("cap_pixel") and family in ["wall","room_wall"]:
  var arrays=result.surface_get_arrays(0)
  var uv=(Vector2(g.rect[0],g.rect[1])+Vector2(g.cap_pixel[0],g.cap_pixel[1])+Vector2.ONE*.5)/texture.get_size()
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   if arrays[Mesh.ARRAY_NORMAL][i].y>.5:arrays[Mesh.ARRAY_TEX_UV][i]=uv
  var material=result.surface_get_material(0)
  result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(0,material)
 if family=="rock" or family=="wall" and serial in WALLS:
  result=tiled_stone(result,g,texture)
 meshes[key]=result
 return meshes[key]

static func source_height(g:Dictionary)->float:
 var span=maxi(1,int(g.footprint[0]))+maxi(1,int(g.footprint[1]))
 var visible=minf(1,float(g.rect[2])/(span*32.0))
 var ground_span=(span-2)*12.0+span*12.0*visible
 return maxf(.15,(-float(g.origin[1])-ground_span)*HEIGHT_PER_PIXEL)

static func append_fitted(skin,stage:Node3D,w:float,d:float,height:float,center:Vector3,native_graphic:Dictionary={},preserve_volume:bool=false)->Mesh:
 var parts=[];var bounds=AABB();var first=true
 for node in stage.find_children("*","GeometryInstance3D",true,false):
  var pose:Transform3D=node.transform;var parent=node.get_parent()
  while parent!=stage:pose=parent.transform*pose;parent=parent.get_parent()
  var model:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
  var poses=[Transform3D.IDENTITY]
  if node is MultiMeshInstance3D:
   poses.clear()
   for i in node.multimesh.instance_count:poses.append(node.multimesh.get_instance_transform(i))
  for instance:Transform3D in poses:
   var transform_=pose*instance;var box=transform_*model.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
   parts.append([model,transform_,node.material_override])
 assert(not parts.is_empty(),"Recovered furnishing must contain solid geometry")
 var fit=Vector3(w/maxf(.01,bounds.size.x),height/maxf(.01,bounds.size.y),d/maxf(.01,bounds.size.z))
 var transform_=Transform3D(Basis.IDENTITY.scaled(fit),center-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*fit)
 if not native_graphic.is_empty():
  # Fit the projected silhouette, not the collision rectangle surrounding it.
  var vertices=PackedVector3Array();var low=INF;var high=-INF
  for part in parts:
   for slot in part[0].get_surface_count():
    for p:Vector3 in part[0].surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]:
     p=part[1]*p;vertices.append(p);low=minf(low,p.x+p.z);high=maxf(high,p.x+p.z)
  var scale_=float(native_graphic.rect[2])*3.0/32.0/maxf(.01,high-low)
  var origin=center-Vector3(bounds.get_center().x,0,bounds.get_center().z)*scale_
  var shift=((float(native_graphic.origin[0])+float(native_graphic.rect[2])*.5)*3.0/32.0-origin.x-origin.z-(low+high)*.5*scale_)*.5
  origin+=Vector3(shift,0,shift)
  var vertical=INF
  for p:Vector3 in vertices:
   var y=p.y-bounds.position.y
   if y<.0001:continue
   var at=p*scale_+origin
   vertical=minf(vertical,((at.z-at.x)*8-float(native_graphic.origin[1]))*HEIGHT_PER_PIXEL/y)
  assert(vertical>0 and is_finite(vertical),"Recovered profile must fit above the source ground anchor")
  # Round snowballs retain their volume instead of inheriting sprite-height compression.
  if preserve_volume:vertical=scale_
  fit=Vector3(scale_,vertical,scale_);origin.y=center.y-bounds.position.y*vertical
  transform_=Transform3D(Basis.IDENTITY.scaled(fit),origin)
 var tools={}
 for part in parts:
  if skin!=null:append(skin,part[0],transform_*part[1]);continue
  var model:Mesh=part[0]
  for slot in model.get_surface_count():
   var material:Material=part[2] if part[2]!=null else model.surface_get_material(slot)
   if material is ShaderMaterial and material.has_meta("armor_source_frame"):
    material=material.duplicate()
    # Keep the preparation transform available with the headless dummy renderer too.
    var source_frame:Transform3D=material.get_meta("armor_source_frame")*(transform_*part[1]).affine_inverse()
    material.set_shader_parameter("armor_source_frame",source_frame);material.set_meta("armor_source_frame",source_frame)
   if not tools.has(material):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tools[material]=tool
   # Mixing indexed primitives with raw profile triangles drops the raw faces.
   var source=SurfaceTool.new();source.create_from(model,slot);source.deindex()
   tools[material].append_from(source.commit(),0,transform_*part[1])
 stage.free()
 if skin!=null:return null
 var result=ArrayMesh.new()
 for material in tools:
  tools[material].index()
  var part=tools[material].commit()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,material)
 return result

static func furnishing(serial:int,family:String,w:float,d:float,height:float,center:Vector3)->Mesh:
 var stage=Node3D.new();var boxes=Boxes.new()
 if family in ["display_bench","display_cabinet","drawers","stove","spill_barrel","loose_bottles"]:laboratory(stage,boxes,serial,family,w,d)
 elif family in ["chair","bench","bed","shelf","rack","table","counter","coast_cabinet","coast_display","coast_apothecary","coast_weapons","coast_counter"]:
  var shape:Mesh
  if family=="chair":shape=Furniture.chair()
  elif family=="bench":shape=Furniture.bench(w,d)
  elif family=="bed":shape=Furniture.bed(w,d,-1)
  elif family in ["shelf","rack","coast_apothecary","coast_weapons"]:shape=Furniture.bookcase(d,w,true)
  elif family in ["coast_cabinet","coast_display"]:shape=Furniture.cabinet(d,w,false)
  else:shape=Furniture.desk(w,d,false)
  var node=Geo.mesh(stage,shape,Vector3.ZERO,null)
  if family in ["shelf","rack","coast_cabinet","coast_display","coast_apothecary","coast_weapons"]:node.rotation.y=-PI*.5 if w>=d else PI
 elif family.begins_with("coast_"):Coastal.furnish(stage,boxes,Vector3.ZERO,Vector2(w,d),serial,family,{})
 elif family.begins_with("inn_"):Inn.furnish(stage,boxes,Vector3.ZERO,w,d,w>d,serial,family)
 elif family.begins_with("civic_"):Civic.furnish(stage,boxes,Vector3.ZERO,w>d,maxf(w,d),family,serial)
 elif family in ["armor","brazier","state_bed"]:Palace.furnishing(stage,boxes,Vector3.ZERO,family,serial)
 else:Cellar.furnish(stage,boxes,Vector3.ZERO,family,serial,w>d,maxf(w,d))
 boxes.build(stage)
 return append_fitted(null,stage,w*.84,minf(d*.84,height*.22) if serial in [16193,16196] else d*.84,height,center)

static func laboratory(stage:Node3D,boxes,serial:int,family:String,w:float,d:float):
 var wood=Fort.material(Color("825331"),false);var trim=Fort.material(Color("b88a4c"),false)
 var dark=Fort.material(Color("323c3d"),false);var blue=Fort.material(Color("174f58"),false)
 if family=="display_cabinet":
  var node=Geo.mesh(stage,Furniture.cabinet(d,w,false),Vector3.ZERO,null);node.rotation.y=-PI*.5
 elif family=="drawers":
  boxes.add(Vector3.UP*1.7,Vector3(1.1,3.4,.70),wood)
  for row in 8:
   for column in 3:
    var p=Vector3((column-1)*.35,.23+row*.41,.38)
    boxes.add(p,Vector3(.32,.36,.09),trim)
    boxes.add(p+Vector3(0,0,.06),Vector3(.11,.045,.035),dark)
 elif family=="stove":
  boxes.add(Vector3.UP*.55,Vector3(1.2,1.1,1.2),dark)
  for y in [.10,.95,1.12]:boxes.add(Vector3.UP*y,Vector3(1.30,.09,1.30),trim)
  boxes.add(Vector3(0,.56,.62),Vector3(.75,.66,.04),trim)
  boxes.add(Vector3(0,.56,.65),Vector3(.57,.47,.035),dark)
  Geo.cylinder(stage,Vector3(0,2.76,-.15),.17,3.3,dark)
 elif family=="spill_barrel":
  Coastal.furnish(stage,boxes,Vector3.ZERO,Vector2(w,d),serial,"coast_side_barrel",{})
  Geo.sphere(stage,Vector3(.75,.025,0),Vector3(1.25,.035,1.0),Geo.mat("703da1"))
 elif family=="loose_bottles":
  for i in 2:
   var at=Vector3((i-.5)*.6,0,0)
   var glass=Geo.mat("547744" if i==0 else "ac8a44",.15)
   Geo.cylinder(stage,at+Vector3.UP*.28,.14,.56,glass)
   Geo.cylinder(stage,at+Vector3.UP*.65,.06,.20,glass)
   Geo.cylinder(stage,at+Vector3.UP*.78,.07,.06,trim)
 else:
  var span=Vector3(w*.9,.18,d*.9)
  boxes.add(Vector3.UP*1.22,span,trim)
  boxes.add(Vector3.UP*.74,Vector3(w*.86,.84,d*.86),blue if serial==17215 else wood)
  for x in [-1,1]:
   for z in [-1,1]:Geo.cylinder(stage,Vector3(x*w*.42,.65,z*d*.42),.10,1.30,trim)
  if serial==17215:
   for i in 7:
    var at=Vector3((i-3)*w*.11,1.35,(i%2-.5)*d*.35)
    Geo.cylinder(stage,at,.14,.08,trim)
    Geo.cylinder(stage,at+Vector3.UP*.21,.08,.38,blue if i%2 else dark)
    Geo.cylinder(stage,at+Vector3.UP*.44,.045,.13,trim)
  else:
   for i in 12:
    var at=Vector3((i-5.5)*w*.065,1.53,0)
    boxes.add(at,Vector3(w*.045,.45,d*.67),Fort.material(Color(["53684b","405d6d","806051"][i%3]),false))

static func parapet(skin,serial:int,w:float,d:float,height:float,center:Vector3):
 var stage=Node3D.new();var boxes=Boxes.new();var stone=Fort.material(Color("b5b39d"),false)
 var arch=load("res://scripts/forest/forest_freyja_art.gd").arch_mesh(2.4,stone)
 Court.parapet(stage,boxes,Vector3.UP*5.25,serial,stone,stone,arch)
 boxes.build(stage)
 append_fitted(skin,stage,w,d,height,center)

static func channel(skin,serial:int,g:Dictionary,center:Vector3):
 skin.quad(center+Vector3(-1.5,.035,-1.5),center+Vector3(1.5,.035,-1.5),center+Vector3(1.5,.035,1.5),center+Vector3(-1.5,.035,1.5))
 var edges:Array=g.channel_edges
 for i in 4:
  if not edges[i]:continue
  var axis=Vector3.RIGHT if i<2 else Vector3.BACK
  var at=center+axis*(-1.35 if i%2==0 else 1.35)
  var size_=Vector3(.30,.30,3) if i<2 else Vector3(3,.30,.30)
  skin.box(AABB(at-size_*Vector3(.5,0,.5),size_))
  if serial>=16324 and i<2:
   for j in range(2,4):
    if not edges[j]:continue
    var corner=center+Vector3(-1.28 if i%2==0 else 1.28,0,-1.28 if j%2==0 else 1.28)
    Buildings.kili_round(skin,corner,[Vector2(.28,.28),Vector2(.28,.38),Vector2(.19,.45),Vector2(.19,.74),Vector2(.25,.82),Vector2(.12,.94)])

static func winter_prop(skin,serial:int,family:String,w:float,d:float,height:float,center:Vector3):
 Lamps.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 if family=="snow_crate":
  var size_=Vector3(w*.74,height*.9,d*.74)
  skin.box(AABB(center-size_*Vector3(.5,0,.5),size_))
  for side in [-1,1]:
   for edge in [-1,1]:
    Lamps.block(tool,center+Vector3(side*size_.x*.48,size_.y*.5,edge*size_.z*.48),Vector3(.13,size_.y,.13))
   Lamps.rod(tool,center+Vector3(-size_.x*.44,.08,side*size_.z*.51),center+Vector3(size_.x*.44,size_.y-.08,side*size_.z*.51),.07)
  if serial in [11466,11467]:Lamps.oval(tool,center+Vector3.UP*size_.y,Vector3(size_.x*1.12,height*.20,size_.z*1.12))
 elif family=="logs":
  var along_x=serial in [11454,11461,11463]
  var radius=minf(w,d)*.13
  for row in 3:
   for column in range(3-row):
    var at=center+Vector3((column-(2-row)*.5)*radius*1.85,radius*(1+row*1.65),0)
    if along_x:at=center+Vector3(0,at.y,at.x-center.x)
    var axis=(Vector3.RIGHT*w if along_x else Vector3.BACK*d)*.46
    Lamps.rod(tool,at-axis,at+axis,radius)
    if serial in [11454,11460,11461]:Lamps.oval(tool,at+Vector3.UP*radius*.78,Vector3(w*.94,radius*.64,radius*1.90) if along_x else Vector3(radius*1.90,radius*.64,d*.94))
 elif family=="tub":
  Buildings.kili_round(skin,center,[Vector2(w*.30,0),Vector2(w*.43,height*.88),Vector2(w*.44,height),Vector2(w*.36,height),Vector2(w*.32,height*.67),Vector2(0,height*.67)])
  return
 elif family=="snowman":
  for row in [[.27,.58],[.64,.42],[.9,.28]]:Lamps.oval(tool,center+Vector3.UP*height*row[0],Vector3(w*row[1],height*row[1],d*row[1]))
  for side in [-1,1]:Lamps.rod(tool,center+Vector3(side*w*.16,height*.62,0),center+Vector3(side*w*.40,height*.82,0),.045)
 elif family=="stump":
  Buildings.kili_round(skin,center,[Vector2(w*.32,0),Vector2(w*.21,height*.30),Vector2(w*.18,height*.93),Vector2(w*.23,height),Vector2(0,height)])
  for i in 5:
   var axis=Vector3(cos(i*TAU/5),0,sin(i*TAU/5))
   Lamps.rod(tool,center+axis*w*.11+Vector3.UP*height*.46,center+axis*w*.39+Vector3.UP*.035,.12)
 elif family=="rubble":
  append(skin,Chamber.maze_rubble(),Transform3D(Basis.IDENTITY.scaled(Vector3(w*.6,height,d*.6)),center))
  return
 else:Lamps.oval(tool,center+Vector3.UP*height*.40,Vector3(w*.90,height,d*.90))
 append(skin,tool.commit())

static func small_plant(skin,serial:int,family:String,w:float,d:float,height:float,center:Vector3):
 Lamps.prepare_primitives()
 if family=="conifer_shrub":
  for level in 4:
   var y=height*level*.17;var radius=minf(w,d)*(.34-level*.065)
   Buildings.kili_round(skin,center,[Vector2(radius*.16,y),Vector2(radius,y+height*.04),Vector2(0,y+height*.49)])
  return
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 if family=="leafy_shrub":
  for i in 7:
   var angle=i*2.39996
   var at=center+Vector3(cos(angle)*w*.16,height*(.37+.20*sin(i*2.7)),sin(angle)*d*.16)
   Lamps.oval(tool,at,Vector3(w*.44,height*.64,d*.44))
 elif family=="cactus":
  Lamps.rod(tool,center,center+Vector3.UP*height*.86,w*.14)
  Lamps.oval(tool,center+Vector3.UP*height*.86,Vector3(w*.28,height*.28,d*.28))
  for side in [-1,1]:
   var at=center+Vector3(side*w*.25,height*.48,0)
   Lamps.rod(tool,center+Vector3.UP*height*.48,at,w*.08)
   Lamps.rod(tool,at,at+Vector3.UP*height*.30,w*.08)
 else:
  for i in (4 if family=="branch" else 6):
   var angle=i*2.39996+serial*.31
   var direction=Vector3(cos(angle)*w*.26,0,sin(angle)*d*.26)
   var fork=center+direction*.36+Vector3.UP*height*.50
   var tip=center+direction+Vector3.UP*height*(.74+.18*sin(i*2.7))
   Lamps.rod(tool,center,fork,.045)
   Lamps.rod(tool,fork,tip,.028)
   if family=="branch":
    var twig=fork.lerp(tip,.52)
    Lamps.rod(tool,twig,twig+Vector3(-direction.z,height*.18,direction.x)*.44,.018)
   else:Lamps.oval(tool,tip,Vector3(w*.28,height*.24,d*.28))
 append(skin,tool.commit())

static func sculpture(skin,family:String,w:float,d:float,height:float,center:Vector3):
 Lamps.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 if family=="bone_pile":
  for i in 24:
   var angle=i*2.39996
   var p=center+Vector3(cos(angle)*w*.22*sqrt(i/24.0),height*(.15+.45*absf(sin(i*7.1))),sin(angle)*d*.22*sqrt(i/24.0))
   var axis=Vector3(cos(angle+.7),.35*sin(i*4.7),sin(angle+.7))*.38
   Lamps.rod(tool,p-axis,p+axis,.045)
   for side in [-1,1]:Lamps.oval(tool,p+axis*side,Vector3(.16,.13,.16))
 else:
  Buildings.kili_round(skin,center,[Vector2(w*.36,0),Vector2(w*.36,height*.10),Vector2(w*.26,height*.15)])
  Lamps.oval(tool,center+Vector3(0,height*.43,0),Vector3(w*.38,height*.55,d*.43))
  Lamps.oval(tool,center+Vector3(0,height*.77,d*.10),Vector3(w*.25,height*.26,d*.28))
  Lamps.oval(tool,center+Vector3(0,height*.74,d*.23),Vector3(w*.18,height*.10,d*.23))
  for side in [-1,1]:
   Lamps.rod(tool,center+Vector3(side*w*.11,height*.81,d*.06),center+Vector3(side*w*.18,height*.99,0),.055)
   Lamps.rod(tool,center+Vector3(side*w*.14,height*.38,d*.09),center+Vector3(side*w*.21,height*.17,d*.22),.15)
   Lamps.oval(tool,center+Vector3(side*w*.20,height*.16,d*.27),Vector3(w*.20,height*.12,d*.25))
   Lamps.rod(tool,center+Vector3(side*w*.17,height*.61,d*.04),center+Vector3(side*w*.23,height*.46,d*.28),.12)
   var wing=PackedVector2Array([Vector2(.12,.58),Vector2(.24,.90),Vector2(.56,.87),Vector2(.40,.71),Vector2(.31,.72),Vector2(.23,.55)])
   for i in wing.size():wing[i]*=Vector2(side*w,height)
   append(skin,Shapes.extrude(wing,.10),Transform3D(Basis.IDENTITY,center-Vector3.BACK*d*.14))
 append(skin,tool.commit())

static func leaves(skin,serial:int,family:String,height:float,center:Vector3):
 var fern=family=="fern"
 for i in (9 if fern else 6):
  var angle=i*2.39996+serial*.41
  var out=Vector3(cos(angle),0,sin(angle));var across=out.cross(Vector3.UP)
  var spread=height*(.75 if fern else .40)*(1.0+.18*sin(i*2.3))
  for section in 5:
   var t=section/5.0;var next=(section+1)/5.0
   var a=center+out*spread*t+Vector3.UP*height*sin(t*PI*.72)
   var b=center+out*spread*next+Vector3.UP*height*sin(next*PI*.72)
   var width=spread*(.22 if fern else .045)*sin((t+.08)*PI)
   var next_width=spread*(.22 if fern else .045)*sin(next*PI)
   var thick=Vector3.UP*maxf(.008,width*.13)
   skin.quad(a-across*width,a+thick,b+thick,b-across*next_width)
   skin.quad(a+thick,a+across*width,b+across*next_width,b+thick)
   skin.quad(a+across*width,a-thick,b-thick,b+across*next_width)
   skin.quad(a-thick,a-across*width,b-across*next_width,b-thick)

static func fortification(serial:int,g:Dictionary)->Mesh:
 var stage=Node3D.new();var boxes=Boxes.new()
 var stone=Fort.material(Color("986b4d"));var coping=Fort.material(Color("d7c7a3"),false)
 var quoin=Fort.material(Color("cbb992"),false);var slit=Fort.material(Color("343c35"),false)
 var base=Fort.material(Color("8e8e77"))
 var master_height=18.8
 if serial in range(10670,10686):
  Court.ironwork(boxes,Vector3.ZERO,serial,slit);master_height=3.0
 elif serial in [10640,10641]:
  Court.curtain_wall(boxes,Vector3.ZERO,serial==10641,stone,base,coping,slit);master_height=14.7
 elif serial in range(10642,10646):
  Court.buttress(stage,boxes,Vector3.ZERO,stone,coping,base);master_height=12.8
 elif serial==10646:
  Court.part(boxes,Vector3.ZERO,false,Vector3(0,12.3,0),Vector3(9.4,2.6,4.25),stone)
  for side in [-1,1]:
   for i in 6:Court.part(boxes,Vector3.ZERO,false,Vector3((i-2.5)*1.46,14.08,side*1.87),Vector3(.82,.77,.72),coping)
  master_height=14.5
 else:Court.castle_tower(stage,boxes,Vector3.ZERO,9,17.5,stone,coping,quoin,slit,base)
 boxes.build(stage)
 var width=maxi(1,int(g.footprint[0]))*3.0;var depth=maxi(1,int(g.footprint[1]))*3.0
 var height=source_height(g)
 var visible=minf(9.41,float(g.rect[2])*3.0/64.0)
 var fit=Vector3(visible/9.41,height/master_height,visible/9.41)
 var center=Vector3((width-3)*.5,0,(3-depth)*.5)
 if serial==10646:fit=Vector3(1,height/master_height,1);center=Vector3(3,0,-3)
 if serial in range(10670,10686):fit=Vector3(1,height/master_height,1);center=Vector3.ZERO
 var transform_=Transform3D(Basis.IDENTITY.scaled(fit),center)
 var tools={}
 for node in stage.find_children("*","GeometryInstance3D",true,false):
  var pose:Transform3D=node.transform;var parent=node.get_parent()
  while parent!=stage:pose=parent.transform*pose;parent=parent.get_parent()
  var model:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
  for slot in model.get_surface_count():
   var material:Material=node.material_override if node.material_override!=null else model.surface_get_material(slot)
   if not tools.has(material):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tools[material]=tool
   if node is MultiMeshInstance3D:
    for i in node.multimesh.instance_count:tools[material].append_from(model,slot,transform_*pose*node.multimesh.get_instance_transform(i))
   else:tools[material].append_from(model,slot,transform_*pose)
 var result=ArrayMesh.new()
 for material in tools:
  var mesh=tools[material].commit()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,material)
 stage.free()
 return result


static func roof_paint(serial:int)->String:
 if serial in [11400,11402,11404,11405]:return "orange_roof"
 if serial==11403:return "green_roof"
 if serial==11407:return "tina_green_roof"
 if serial in [11409,11410,11414]:return "tina_blue_roof"
 if serial==11416:return "tina_brown_roof"
 if serial in [11083,11084,11015]:return "plankroof"
 if serial==11451:return "thatch"
 return "snowroof"

static func building_vertical_fit(model:Mesh,g:Dictionary)->float:
 var points=PackedVector2Array();var left=INF;var right=-INF
 for surface in model.get_surface_count():
  for p:Vector3 in model.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
   var x=(p.x+p.z)*.70710678;left=minf(left,x);right=maxf(right,x)
   points.append(Vector2((p.x-p.z)*.52981294,p.y*.66226618))
 var target=(right-left)*float(g.rect[3])/float(g.rect[2]);var low=.25;var high=4.0
 # Fit only vertical presentation to the original isometric silhouette; native footprints and anchors stay fixed.
 for iteration in 16:
  var fit=(low+high)*.5;var top=-INF;var bottom=INF
  for p in points:
   var y=p.x+p.y*fit;top=maxf(top,y);bottom=minf(bottom,y)
  if top-bottom<target:low=fit
  else:high=fit
 return (low+high)*.5

static func hip_roof(skin,w:float,d:float,base:float,rise:float,at:Vector3,snow_edge:bool,square:bool=false,pointed:bool=false):
 var roof=skin.part
 if pointed:
  var profiles=[Vector2(1.03,0),Vector2(1.0,.035),Vector2(.018,1)]
  var corners=[Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]
  for level in 2:
   skin.part="snowroof" if snow_edge and level==0 else roof
   for i in 4:
    var a:Vector2=corners[i];var b:Vector2=corners[(i+1)%4];var low:Vector2=profiles[level];var high:Vector2=profiles[level+1]
    skin.quad(at+Vector3(a.x*w*.5*low.x,base+rise*low.y,a.y*d*.5*low.x),at+Vector3(a.x*w*.5*high.x,base+rise*high.y,a.y*d*.5*high.x),at+Vector3(b.x*w*.5*high.x,base+rise*high.y,b.y*d*.5*high.x),at+Vector3(b.x*w*.5*low.x,base+rise*low.y,b.y*d*.5*low.x))
  return
 var profile=[Vector2(1.03,0),Vector2(.97,.14),Vector2(.85,.39),Vector2(.64,.69),Vector2(.35,.91),Vector2(.025,1)]
 if snow_edge:profile.insert(1,Vector2(1.02,.035))
 var rings=[]
 for level:Vector2 in profile:
  var ring=[]
  for edge in 16:
   var angle=-TAU*edge/16.0
   var x=signf(cos(angle))*pow(absf(cos(angle)),.20 if square else .55)*w*.5*level.x
   var z=signf(sin(angle))*pow(absf(sin(angle)),.20 if square else .55)*d*.5*level.x
   ring.append(at+Vector3(x,base+rise*level.y,z))
  rings.append(ring)
 for level in rings.size()-1:
  skin.part="snowroof" if snow_edge and level==0 else roof
  for i in 16:
   var next=(i+1)%16
   skin.quad(rings[level][i],rings[level+1][i],rings[level+1][next],rings[level][next])
 skin.box(AABB(at+Vector3(-.10,base+rise-.02,-.10),Vector3(.20,.35,.20)))

static func round_frame(skin,at:Vector3,radius:float,wall:float):
 skin.part="trim"
 for fraction in [.14,.50,.86]:
  var y=wall*fraction
  Buildings.kili_round(skin,at,[Vector2(radius*1.015,y),Vector2(radius*1.015,y+.12)])
 for i in 12:
  var angle=TAU*i/12
  var p=at+Vector3(cos(angle)*radius,wall*.47,sin(angle)*radius)
  skin.box(AABB(p-Vector3(.09,wall*.43,.09),Vector3(.18,wall*.86,.18)))

static func building(skin,serial:int,w:float,d:float,height:float,native=null,underlay=null):
 # Native plaster/eave spans differ from the taller pub's wall-to-roof ratio.
 var wall=height*(.47 if serial==11400 else .52 if serial==11404 else .58);var rise=height-wall
 var roof=roof_paint(serial)
 if serial in [11402,11413,11414]:
  var ring=Source.new([],skin.texture,skin.pixel_height);ring.tiles=skin.tiles
  Tina.circular(native,ring,serial,w,d,height)
  if serial==11402:Jenova.round_details(ring,w,height)
  append(skin,ring.finish(),Transform3D(Basis.IDENTITY.scaled(Vector3(1,1,d/w)),Vector3.ZERO))
  return
 if serial in [11450,11451,11083,11084,11015]:
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);Lamps.prepare_primitives()
  if serial==11015:
   for row in 4:
    for column in range(4-row):
     var z=(column-(3-row)*.5)*.67
     Lamps.rod(tool,Vector3(-w*.46,.33+row*.57,z),Vector3(w*.46,.33+row*.57,z),.32)
   append(skin,tool.commit())
   skin.part=roof;Buildings.roof(skin,w,d,height*.72,height*.28,true)
   return
  if serial in [11083,11084]:
   skin.part="stone"
   skin.box(AABB(Vector3(w*.34,0,-d*.48),Vector3(w*.09,wall,d*.96)))
   for i in 6:
    var z=-d*.46+i*d*.92/5
    skin.box(AABB(Vector3(-w*.43,0,z-.12),Vector3(w*.84,wall*.66,.24)))
    skin.box(AABB(Vector3(-w*.45,0,z-.15),Vector3(.3,wall,.3)))
   skin.part=roof;Buildings.roof(skin,w,d,wall,rise,false)
   return
  skin.part="timber"
  skin.box(AABB(Vector3(w*.40,0,-d*.47),Vector3(.20,height*.92 if serial in [11450,11451] else wall,d*.94)))
  for z in [-d*.45,0,d*.45]:
   for x in [-w*.43,w*.43]:
    var post_height=lerpf(wall*.70,height,(x/w+.60)/1.14) if serial in [11450,11451] else wall
    skin.box(AABB(Vector3(x-.13,0,z-.13),Vector3(.26,post_height,.26)))
  skin.box(AABB(Vector3(-w*.43,0,-d*.40),Vector3(w*.18,wall*(.05 if serial in [11450,11451] else .30),d*.80)))
  if serial in [11450,11451]:
   Tina.shelter(native,skin,serial,w,d,wall,height)
  else:
   skin.part=roof
   skin.quad(Vector3(-w*.60,wall*.70,-d*.54),Vector3(w*.54,height,-d*.54),Vector3(w*.54,height,d*.54),Vector3(-w*.60,wall*.70,d*.54))
  skin.part="timber"
  for side in [-1,1]:
   Buildings.kili_round(skin,Vector3(-w*.12,0,side*d*.28),[Vector2(.6,0),Vector2(.74,.3),Vector2(.74,1.0),Vector2(.58,1.3)])
  return
 var round_front=serial in [11404,11407,11408]
 var body=Vector3(w*.07,.0,-d*.07)
 var bw=w*.84;var bd=d*.82
 if serial==11404:body=Vector3(w*.18,0,-d*.04);bw=w*.63;bd=d*.94
 if serial==11408:body.z=-d*.18;bd=d*.60
 if serial==11407:body.x=w*.18;bw=w*.60
 if serial in Tina.ALIGNED_HIPS:
  var profile=Tina.shell_profile(serial,bw,bd)
  bw=profile[0];bd=profile[1];wall=profile[2];rise=profile[3]
 skin.part="plaster"
 skin.box(AABB(body+Vector3(-bw*.5,.42,-bd*.5),Vector3(bw,wall-.42,bd)))
 if serial not in [11400,11403,11405,11407,11408,11409,11410,11411,11412,11415,11416]:Buildings.wall_details(skin,serial,bw,bd,wall,body,not round_front)
 if serial in [11407,11408]:Tina.bay_walls(native,serial,body,bw,bd,wall)
 if serial in [11400,11403,11404,11405,11409,11410,11411,11412,11415,11416]:
  var prefix="tina" if serial in [11409,11410,11411,11412,11415,11416] else "jenova"
  for side in [-1,1]:
   var right=Vector3.RIGHT*bw*.5*side
   var at=body+Vector3(0,wall*.5,side*(bd*.5+.045))
   if native!=null:Tina.facade(native,serial,"right",[at-right-Vector3.UP*wall*.5,at-right+Vector3.UP*wall*.5,at+right+Vector3.UP*wall*.5,at+right-Vector3.UP*wall*.5],"jenova" if serial in Jenova.IDS else "tina")
   else:skin.panel(at-right-Vector3.UP*wall*.5,at-right+Vector3.UP*wall*.5,at+right+Vector3.UP*wall*.5,at+right-Vector3.UP*wall*.5,"%s_%d_right"%[prefix,serial])
   right=Vector3.BACK*bd*.5*-side;at=body+Vector3(side*(bw*.5+.045),wall*.5,0)
   if native!=null:Tina.facade(native,serial,"left",[at-right-Vector3.UP*wall*.5,at-right+Vector3.UP*wall*.5,at+right+Vector3.UP*wall*.5,at+right-Vector3.UP*wall*.5],"jenova" if serial in Jenova.IDS else "tina")
   else:skin.panel(at-right-Vector3.UP*wall*.5,at-right+Vector3.UP*wall*.5,at+right+Vector3.UP*wall*.5,at+right-Vector3.UP*wall*.5,"%s_%d_left"%[prefix,serial])
 if serial==11404:Jenova.facade_details(native,serial,body,bw,bd,wall)
 if serial in [11400,11405]:
  var doorway=Jenova.doorway(native,skin,serial,body,bw,bd,wall)
  Jenova.facade_details(native,serial,body,bw,bd,wall)
  if serial==11400:Jenova.porch(native,skin,body,bw,bd,wall,doorway)
 if serial in [11403,11409,11410,11411,11412,11415,11416]:
  var doorway=Tina.door(native,skin,serial,body,bw,bd,wall)
  Tina.gables(native,serial,body,bw,bd,wall)
  Tina.porch(skin,body,bw,bd,wall,doorway,serial,["left"] if serial in [11403,11409] else ["right"] if serial==11410 else ["left","right"])
  if serial==11403:Jenova.green_details(native,skin,body,bw,bd,wall)
 skin.part="trim"
 for normal:Vector3 in ([Vector3.RIGHT,Vector3.FORWARD] if serial in [11407,11408] else [] if serial in [11400,11403,11404,11405,11409,11410,11411,11412,11415,11416] else [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]):
  var tangent=Vector3.UP.cross(normal)
  var length_=bd if absf(normal.x)>.5 else bw
  var face=body+normal*((bw if absf(normal.x)>.5 else bd)*.5+.03)
  for i in 4:
   var p=face+tangent*((float(i)/3-.5)*length_*.92)
   skin.box(AABB(p+Vector3(-.10,.45,-.10),Vector3(.20,wall-.5,.20)))
 for fraction in ([] if serial in Jenova.IDS or serial in Tina.IDS else [.18,.55,.92]):
  var y=wall*fraction
  for side in [-1,1]:
   skin.box(AABB(body+Vector3(-bw*.5,y,side*bd*.5-.07),Vector3(bw,.14,.14)))
   skin.box(AABB(body+Vector3(side*bw*.5-.07,y,-bd*.5),Vector3(.14,.14,bd)))
 skin.part="stone" if serial in [11400,11403,11405,11415,11416] else "timber"
 if serial in [11409,11410]:
  skin.part="stone"
  skin.box(AABB(body+Vector3(-bw*.5,0,-bd*.5),Vector3(bw,.50,bd)))
  skin.part="timber"
  skin.box(AABB(body+Vector3(-bw*.5-1.20,.34,-bd*.5),Vector3(1.20,.16,bd)) if serial==11409 else AABB(body+Vector3(-bw*.5,.34,bd*.5),Vector3(bw,.16,1.20)))
 elif serial in [11404,11407,11408]:
  skin.part="stone"
  skin.box(AABB(body+Vector3(-bw*.5,0,-bd*.5),Vector3(bw,.50,bd)))
 else:skin.box(AABB(Vector3(-w*.48,0,-d*.48),Vector3(w*.96,.50,d*.96)))
 skin.part=roof
 if native!=null:
  var overhang=1.16 if serial==11404 else 1.09
  var peak_offset=Vector3(-w*.069,0,-d*.081) if serial==11404 else Vector3.ZERO
  Tina.hip(underlay if underlay!=null else native,serial,bw*overhang,bd*overhang,wall,rise,body,Jenova.ROOFS[serial] if Jenova.ROOFS.has(serial) else [],peak_offset)
  if serial in [11409,11410,11411,11412]:
   var peak=body+Vector3.UP*(wall+rise)
   if serial in Tina.ALIGNED_HIPS:peak=Tina.aligned_roof_point(peak,Tina.ROOFS[serial][0],serial,bw,bd,body)
   Tina.finial(skin,peak)
 else:hip_roof(skin,bw*1.09,bd*1.09,wall,rise,body,serial in [11407,11409,11410,11416],serial in [11400,11403,11404,11405,11409,11410,11411,11412,11415,11416])
 if serial in [11400,11405] or serial==11403 and native==null:
  skin.part="trim"
  Buildings.kili_round(skin,body+Vector3.UP*(wall+rise),[Vector2(.28,0),Vector2(.28,.12),Vector2(.15,.22),Vector2(.15,.45),Vector2(.02,.70)])
 if serial in [11415,11416]:Tina.pub_details(native,skin,body,bw,bd,wall,serial)
 if round_front:
  var p=Vector3(-w*(.113 if serial==11404 else .23),0,d*.20)
  var radius=minf(w,d)*(.29 if serial==11404 else .23)
  skin.part="woodwall"
  Buildings.kili_round(skin,p,[Vector2(radius*.97,.4),Vector2(radius,wall*.86)])
  skin.part=roof
  if serial==11404:
   Jenova.bay(native,p,radius,wall,rise)
  elif serial in [11407,11408]:
   Tina.bay(native,p,radius,wall,rise)
   if serial==11407:Tina.finial(skin,p+Vector3.UP*(wall*.91+rise*.62))
  else:Buildings.kili_round(skin,p,[Vector2(radius*1.12,wall*.91),Vector2(radius*1.10,wall*.91+rise*.16),Vector2(radius*.95,wall*.91+rise*.34),Vector2(radius*.65,wall*.91+rise*.51),Vector2(radius*.3,wall*.91+rise*.60),Vector2(.07,wall*.91+rise*.62)])
  if serial==11404:
   Tina.bay_porch(skin,w,d,11407)
   skin.part="stone"
   Buildings.kili_round(skin,p,[Vector2(radius*1.03,0),Vector2(radius*1.03,.25),Vector2(radius*.97,.42)])
   Tina.round_roof(native,p,radius*1.005,radius*1.005,[[1,.4,378,65],[1,wall*.86,251,65]],234,130,true)
   round_frame(skin,p,radius,wall*.86)
   Jenova.round_door(native,skin,p+Vector3(-radius-.10,wall*.31,0),wall*.65*48.0/128,wall*.65*104.0/128)
  elif serial in [11407,11408]:
   Tina.bay_porch(skin,w,d,serial)
   skin.part="stone"
   Buildings.kili_round(skin,p,[Vector2(radius*1.02,0),Vector2(radius*1.02,.42)])
   Tina.round_roof(native,p,radius*1.005,radius*1.005,[[1,.4,345,65],[1,wall*.86,205,65]],226,112)
   if serial==11407:Tina.round_door(native,skin,serial,p+Vector3(-radius-.10,wall*.31,0),wall*.65*48.0/128,wall*.65*104.0/128)
   else:Tina.round_door(native,skin,serial,p+Vector3(0,wall*.34,radius+.10),wall*.68*39.0/97,wall*.68)
 elif serial not in [11400,11403,11405,11409,11410,11411,11412,11415,11416]:
  skin.part="trim"
  for side in [-1,1]:
   for i in 5:
    var z=-d*.43+i*d*.86/4
    skin.box(AABB(Vector3(side*w*.44-.07,.5,z-.07),Vector3(.14,1.0,.14)))
   skin.box(AABB(Vector3(side*w*.44-.10,1.42,-d*.46),Vector3(.20,.16,d*.92)))
 if serial==11405:Jenova.pub_details(native,skin,body,bw,bd,wall)


static func tiled_stone(shape:Mesh,g:Dictionary,texture:Texture2D)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var arrays=shape.surface_get_arrays(0)
 for triangle in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
  var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][triangle]+arrays[Mesh.ARRAY_NORMAL][triangle+1]+arrays[Mesh.ARRAY_NORMAL][triangle+2]).normalized()
  var top=absf(normal.y)>maxf(absf(normal.x),absf(normal.z))
  var tile=Vector2(g.surfaces[3],g.surfaces[4]) if top else Vector2(g.surfaces[1],g.surfaces[2])
  for corner in 3:
   var i=triangle+corner;var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
   var uv=Vector2(p.x,p.z) if top else Vector2(p.z,-p.y) if absf(normal.x)>absf(normal.z) else Vector2(p.x,-p.y)
   tool.set_normal(arrays[Mesh.ARRAY_NORMAL][i]);tool.set_uv(uv/3.0);tool.set_uv2(tile);tool.add_vertex(p)
 var result=tool.commit()
 if not stone_materials.has(texture):
  var material:ShaderMaterial=Source.material(texture,true).duplicate()
  material.set_shader_parameter("original_palette",false)
  stone_materials[texture]=material
 result.surface_set_material(0,stone_materials[texture])
 return result
