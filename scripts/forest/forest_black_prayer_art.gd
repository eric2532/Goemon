extends RefCounted
## Native cave paint on the shared 3D stairs, walls and rock silhouettes.
const Scenery=preload("res://assets/maps/falan/black_prayer/scenery.gd")
const SceneryAtlas=preload("res://assets/maps/falan/black_prayer/scenery.png")
const PedestalTop=preload("res://assets/maps/falan/black_prayer/pedestal_top.png")
const Carved=preload("res://assets/maps/falan/black_prayer/carvings.gd")
const Carvings=preload("res://scripts/forest/forest_falan_carvings.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Interior=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const Stairs=preload("res://scripts/forest/forest_habaru_stairs.gd")
const Floor=preload("res://assets/maps/falan/black_prayer/floors.png")
const Walls=preload("res://assets/maps/falan/black_prayer/walls.png")
const PalaceWall=preload("res://assets/maps/falan/black_prayer/palace_wall.png")
const Rock=preload("res://assets/maps/falan/black_prayer/rock.png")
const StoneUp=preload("res://assets/maps/falan/black_prayer/stair_17974.png")
const StoneDown=preload("res://assets/maps/falan/black_prayer/stair_17975.png")
const Forms=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
static var stair_materials={}
static var arch_mesh:ArrayMesh
static var scenery_meshes:Dictionary={}
static var native_rock:ShaderMaterial
static var carving_meshes:Dictionary={}
static var silhouettes:Dictionary={}
static var tripod:Mesh
static var court_carving_paint:ShaderMaterial
static var armor_materials:Dictionary={}
static var armor_paint:ShaderMaterial
static var flower_parts:Dictionary={}
static var flower_material:StandardMaterial3D

static func floors(id:int,size:Vector2i)->PackedByteArray:
 if id==Prayer.ENTRY:return Prayer.Data.ENTRANCE_FLOOR.hex_decode()
 var tiles=PackedByteArray()
 tiles.resize(size.x*size.y*2)
 for i in size.x*size.y:tiles.encode_u16(i*2,Prayer.Data.GROUND_TILE)
 return tiles

static func walls(id:int,size:Vector2i)->PackedByteArray:
 if id==Prayer.ENTRY:return Prayer.Data.ENTRANCE_WALLS.hex_decode()
 var tiles=PackedByteArray()
 tiles.resize(size.x*size.y*2)
 for i in size.x*size.y:tiles.encode_u16(i*2,Prayer.Data.MAZE_WALLS[(i*17+i/size.x*13)%Prayer.Data.MAZE_WALLS.size()])
 return tiles

static func stairs(root:Node3D,id:int,run_seed:int):
 if not id in Prayer.FLOORS:return
 for down in [false,true]:
  var serial=17975 if down else 17974
  if not stair_materials.has(serial):
   var stone=StandardMaterial3D.new()
   stone.albedo_texture=StoneDown if down else StoneUp
   stone.uv1_triplanar=true
   stone.uv1_world_triplanar=true
   stone.uv1_scale=Vector3(.67,.95,.67)
   stone.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
   stone.roughness=.94
   stair_materials[serial]=stone
  var cell:Vector2i=Prayer.stairs(id,run_seed)[int(down)]
  Stairs.build(root,id,cell,Prayer.point(cell),serial,stair_materials[serial])
  root.get_node("HabaruStair_%d_%d"%[cell.x,cell.y]).rotation.y=-PI*.5 if down else PI

static func scatter(root:Node3D,id:int,bits:PackedByteArray,run_seed:int):
 if not id in Prayer.FLOORS:return
 var rng=Prayer.rng_for(id,run_seed+317)
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count_=0
 for z in range(3,Prayer.SIZE.y-3,3):
  for x in range(3,Prayer.SIZE.x-3,3):
   var cell=Vector2i(x,z)
   var index=z*Prayer.SIZE.x+x
   if not (bits[index>>3]&(1<<(index&7))):continue
   var edges=Prayer.DIRECTIONS.filter(func(d):
    var next=(z+d.y)*Prayer.SIZE.x+x+d.x
    return not (bits[next>>3]&(1<<(next&7))))
   if edges.is_empty():continue
   if rng.randf()>.48:continue
   var at=Prayer.point(cell)+Vector2(edges[rng.randi_range(0,edges.size()-1)])*1.25
   var serial=15011+rng.randi_range(0,9)
   Forms.ridge(surface,Vector3(at.x,0,at.y),Vector2(.75,.75),.65+(serial-15011)*.13,serial,false)
   count_+=1
 surface.generate_normals()
 if native_rock==null:
  native_rock=ShaderMaterial.new();native_rock.shader=preload("res://scripts/forest/habaru_ceiling.gdshader")
  native_rock.set_shader_parameter("rock_family",0);native_rock.set_shader_parameter("archive_rock",Rock)
  native_rock.set_shader_parameter("is_roof",false);native_rock.set_shader_parameter("original_palette",true)
 var material=native_rock
 var node=Geo.mesh(root,surface.commit(),Vector3.ZERO,material)
 node.name="BlackPrayerNativeRockScatter"
 node.set_meta("source_serials",Vector2i(15011,15020))
 node.set_meta("rock_count",count_)

static func bars(root:Node3D,center:Vector2,serial:int):
 var group=Node3D.new()
 group.name="RubyIronBars"
 group.position=Vector3(center.x,0,center.y)
 group.set_meta("blue_cg_serial",serial)
 root.add_child(group)
 var boxes=Boxes.new()
 var iron=Fort.material(Color("555b5c"))
 var edge=Fort.material(Color("858d8b"))
 for x in [-1.28,1.28]:boxes.add(Vector3(x,4.0,0),Vector3(.18,8,.20),iron)
 for x in range(-4,5):boxes.add(Vector3(x*.29,4.0,0),Vector3(.075,7.8,.09),iron)
 for y in [.4,3.0,6.5,7.8]:boxes.add(Vector3(0,y,0),Vector3(2.75,.13,.16),edge)
 boxes.build(group)

static func arch(root:Node3D,center:Vector2,cell:Vector2i,serial:int,material:Material):
 if arch_mesh==null:arch_mesh=preload("res://scripts/forest/forest_freyja_art.gd").arch_mesh(.60)
 var offset=Vector2(3,0) if serial==17683 else Vector2(0,-3)
 var at=center+offset
 var arch_=Geo.mesh(root,arch_mesh,Vector3(at.x,6.7,at.y),material)
 arch_.name="RubyStoneArch"
 arch_.scale=Vector3(1,.32,.75)
 arch_.rotation.y=PI*.5 if serial==17683 else 0.0
 arch_.set_meta("blue_cg_serial",serial)
 arch_.set_meta("source_cell",cell)

static func turned(paint,at:Vector3,profile:Array,part:String):
 paint.part=part
 for i in 12:
  var a=Vector3(cos(i*TAU/12),0,sin(i*TAU/12))
  var b=Vector3(cos((i+1)*TAU/12),0,sin((i+1)*TAU/12))
  for j in profile.size()-1:
   var low:Vector2=profile[j];var high:Vector2=profile[j+1]
   paint.quad(at+b*low.x+Vector3.UP*low.y,at+b*high.x+Vector3.UP*high.y,at+a*high.x+Vector3.UP*high.y,at+a*low.x+Vector3.UP*low.y)
 for i in range(0,12,2):
  var top:Vector2=profile[-1];var rim=[]
  for j in 3:rim.append(at+Vector3(cos((i+j)*TAU/12)*top.x,top.y,sin((i+j)*TAU/12)*top.x))
  paint.quad(at+Vector3.UP*top.y,rim[0],rim[1],rim[2])

static func royal_chair()->Mesh:
 var key=["royal_chair"]
 if not scenery_meshes.has(key):
  var mesh=Interior.chair(false)
  var index=0
  for part in ["chair_ivory","picture_gilt","chair_red"]:
   var rgb:Array=Scenery.COLORS[part]
   mesh.surface_set_material(index,Fort.material(Color(rgb[0],rgb[1],rgb[2]),false));index+=1
  scenery_meshes[key]=mesh
 return scenery_meshes[key]

# shortcut: Depth and rear paint fit one recovered view; replace them when original 3D evidence is available.
static func silhouette(feature:String)->Mesh:
 if not silhouettes.has(feature):
  var outline=PackedVector2Array()
  for point in Carved.OUTLINES[feature]:outline.append(Vector2(point[0],point[1]))
  var mesh=Shapes.extrude(outline,.10)
  var arrays:Array=mesh.surface_get_arrays(0);var uvs=PackedVector2Array()
  var rect:Rect2i=Carved.FEATURES[feature][0]
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   var pixel=Vector2(rect.position)+Vector2(point.x+.5,.5-point.y)*Vector2(rect.size-Vector2i.ONE)
   uvs.append((pixel+Vector2.ONE*.5)/Carved.ATLAS.get_size())
  arrays[Mesh.ARRAY_TEX_UV]=uvs
  var painted=ArrayMesh.new();painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  silhouettes[feature]=painted
 return silhouettes[feature]

static func carving(root:Node3D,feature:String,point:Vector3,size_:Vector2,yaw:float=0.0,solid:bool=false):
 var axis=Vector3(sin(yaw),0,cos(yaw))
 if solid:
  var body=Geo.mesh(root,silhouette(feature),point,SourceMesh.material(Carved.ATLAS))
  body.name="RubyCarvedSilhouette";body.scale=Vector3(size_.x,size_.y,1);body.rotation.y=yaw
 if not carving_meshes.has(feature):carving_meshes[feature]=Carvings.relief(feature,Carved)
 var node=Geo.mesh(root,carving_meshes[feature],point+axis*(.052 if solid else .006),SourceMesh.material(Carved.ATLAS))
 node.name="RubyNativeCarving";node.scale=Vector3(size_.x,size_.y,1);node.rotation.y=yaw
 node.set_meta("ruby_carving",feature)
 return node

static func chair_back(root:Node3D):
 carving(root,"chair_back",Vector3(.58,1.83,0),Vector2(1.30,1.65),-PI*.5,true)

static func tripod_mesh()->Mesh:
 if tripod==null:
  Parts.prepare_primitives()
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var feet=[Vector3(-.92,.06,.48),Vector3(.92,.06,.48),Vector3(0,.06,-.68)]
  for foot:Vector3 in feet:Parts.rod(tool,Vector3(0,1.92,0),foot,.045)
  Parts.rod(tool,Vector3(0,1.72,0),Vector3(0,2.57,0),.055)
  for y in [1.83,2.23]:Parts.oval(tool,Vector3(0,y,0),Vector3(.17,.11,.17))
  var rgb:Array=Carved.COLORS.tripod_metal
  tool.set_material(Fort.material(Color(rgb[0],rgb[1],rgb[2]),false));tool.index();tripod=tool.commit()
 return tripod

static func ornament(root:Node3D,cell:Vector2i,center:Vector2,serial:int):
 var node=Node3D.new();node.position=Vector3(center.x,0,center.y);root.add_child(node)
 node.name="RubyTripodOrnament" if serial==17680 else "RubyArchedMirror"
 node.set_meta("blue_cg_serial",serial);node.set_meta("source_cell",cell)
 if serial==17680:
  Geo.mesh(node,tripod_mesh(),Vector3.ZERO,null)
  carving(node,"tripod_plate",Vector3(0,2.8,0),Vector2(1.45,1.24),0,true)
 else:carving(node,"arched_mirror",Vector3(0,2.5,0),Vector2(1.70,4.30),0,true)
 return node

static func furniture(root:Node3D,cell:Vector2i,center:Vector2,span:Vector2i,serial:int):
 var key=[serial,span]
 if not scenery_meshes.has(key):
  var paint=SourceMesh.new([],SceneryAtlas,.046)
  paint.tiles=Scenery.TILES
  if serial in [16204,16205]:
   turned(paint,Vector3.ZERO,[Vector2(.92,.08),Vector2(1.08,.30),Vector2(1.06,1.22),Vector2(.90,1.50)],"stool_red" if serial==16204 else "stool_purple")
  elif serial in [16115,16140]:
   var width=span.x*3.0-.7
   var height=1.68 if serial==16115 else 2.18
   paint.part="court_red"
   paint.box(AABB(Vector3(-width*.5,height-.34,-.82),Vector3(width,.30,1.64)))
   paint.part="picture_gilt"
   paint.box(AABB(Vector3(-width*.5-.03,height-.10,-.86),Vector3(width+.06,.12,1.72)))
   for x in [-width*.43,width*.43]:
    for z in [-.62,.62]:paint.box(AABB(Vector3(x-.10,.08,z-.10),Vector3(.20,height-.18,.20)))
   if serial==16115:
    paint.panel(Vector3(-width*.5+.08,height+.03,.78),Vector3(-width*.5+.08,height+.03,-.78),Vector3(width*.5-.08,height+.03,-.78),Vector3(width*.5-.08,height+.03,.78),"court_linen")
   else:
    paint.panel(Vector3(-width*.5+.08,height+.03,.78),Vector3(-width*.5+.08,height+.03,-.78),Vector3(width*.5-.08,height+.03,-.78),Vector3(width*.5-.08,height+.03,.78),"court_red")
    paint.part="court_red"
    paint.box(AABB(Vector3(-width*.5,.48,-.80),Vector3(width,height-.70,1.60)))
    paint.panel(Vector3(-width*.5+.12,.54,.81),Vector3(-width*.5+.12,height-.22,.81),Vector3(width*.5-.12,height-.22,.81),Vector3(width*.5-.12,.54,.81),"cabinet_face")
    for x in [-width*.28,width*.28]:turned(paint,Vector3(x,height,0),[Vector2(.15,0),Vector2(.28,.15),Vector2(.26,.60),Vector2(.10,.75),Vector2(.12,.90)],"vase_blue")
  elif serial==16124:
   pass
  elif serial in [16464,16499]:
   var sides=8 if serial==16464 else 4
   var radius=1.24 if serial==16464 else 1.85
   for i in sides:
    var a=Vector3(cos((i+.5)*TAU/sides),0,sin((i+.5)*TAU/sides))*radius
    var b=Vector3(cos((i+1.5)*TAU/sides),0,sin((i+1.5)*TAU/sides))*radius
    paint.panel(b,b+Vector3.UP*8.5,a+Vector3.UP*8.5,a,"column_"+str(serial))
   paint.part="case_red"
   for i in range(0,sides,2):
    var rim=[]
    for j in 3:rim.append(Vector3(cos((i+j+.5)*TAU/sides)*radius,8.5,sin((i+j+.5)*TAU/sides)*radius))
    paint.quad(Vector3(0,8.5,0),rim[0],rim[1],rim[2])
  elif serial in [16130,16131,16132]:
   var width=2.45 if serial!=16131 else 2.1
   var height=3.3 if serial!=16131 else 2.6
   paint.part="case_red"
   paint.box(AABB(Vector3(-width*.5,.5,-.16),Vector3(width,height,.25)))
   paint.panel(Vector3(-width*.5+.14,.65,.11),Vector3(-width*.5+.14,height+.35,.11),Vector3(width*.5-.14,height+.35,.11),Vector3(width*.5-.14,.65,.11),"picture_"+str(serial))
   paint.part="picture_gilt"
   for x in [-width*.5,width*.5-.13]:paint.box(AABB(Vector3(x,.5,.08),Vector3(.13,height,.17)))
   for y in [.5,height+.37]:paint.box(AABB(Vector3(-width*.5,y,.08),Vector3(width,.13,.17)))
  elif serial in [16100,16128,16129]:
   paint.baked_scale=Vector3.ONE*(1.0 if serial==16100 else .62)
   paint.part="plinth_green" if serial==16100 else "pedestal_lacquer"
   paint.box(AABB(Vector3(-.54,.20,-.44),Vector3(1.08,2.76,.88)))
   for y in [.12,3.02]:
    paint.part="plinth_gilt" if serial==16100 else "pedestal_lacquer"
    paint.box(AABB(Vector3(-.80,y-.12,-.68),Vector3(1.6,.24,1.36)))
    if serial!=16100:
     paint.part="picture_gilt"
     for z in [-.68,.65]:paint.box(AABB(Vector3(-.80,y-.12,z),Vector3(1.6,.035,.03)))
     for x in [-.80,.77]:paint.box(AABB(Vector3(x,y+.085,-.68),Vector3(.03,.035,1.36)))
   paint.part="plinth_gilt" if serial==16100 else "picture_gilt"
   for x in [-.55,.55]:paint.box(AABB(Vector3(x-.04,.25,.45),Vector3(.08,2.64,.07)))
   paint.baked_scale=Vector3.ONE
   if serial!=16100:
    turned(paint,Vector3(0,1.96,0),[Vector2(.18,0),Vector2(.29,.16),Vector2(.35,.55),Vector2(.24,.91),Vector2(.13,1.04)],"pedestal_blue")
    turned(paint,Vector3(0,3.0,0),[Vector2(.13,0),Vector2(.15,.11)],"pedestal_lip")
  else:
   var width=span.x*3.0
   paint.part="case_red"
   paint.box(AABB(Vector3(-width*.5,0,-1.25),Vector3(width,8.0,.28)))
   for x in [-width*.5+.22,width*.5-.22]:paint.box(AABB(Vector3(x-.22,0,-1.25),Vector3(.44,8.0,2.5)))
   for y in [.18,7.82]:paint.box(AABB(Vector3(-width*.5,y-.18,-1.25),Vector3(width,.36,2.5)))
   paint.panel(Vector3(-width*.5+.43,.35,1.02),Vector3(-width*.5+.43,7.65,1.02),
    Vector3(width*.5-.43,7.65,1.02),Vector3(width*.5-.43,.35,1.02),"books_"+str(serial))
   paint.part="case_red"
   for y in [.48,1.68,2.88,4.08,5.28,6.48,7.68]:paint.box(AABB(Vector3(-width*.5+.43,y-.055,.97),Vector3(width-.86,.11,.30)))
   paint.part="case_gilt"
   for x in [-width*.5+.15,width*.5-.15]:paint.box(AABB(Vector3(x-.075,.13,1.255),Vector3(.15,7.74,.06)))
  if serial==16124:scenery_meshes[key]=royal_chair()
  else:
   paint.surface.index()
   scenery_meshes[key]=paint.surface.commit()
   if serial in [16128,16129]:
    scenery_meshes[key].surface_set_material(0,SourceMesh.material(SceneryAtlas,true))
    court_relief("pedestal_"+str(serial),scenery_meshes[key],Transform3D(Basis.IDENTITY,Vector3(0,1.02,.285)),Vector2(.55,1.52))
 var node=Geo.mesh(root,scenery_meshes[key],Vector3(center.x,0,center.y),null if serial in [16124,16128,16129] else SourceMesh.material(SceneryAtlas,true))
 node.name="RubyRoyalStool" if serial in [16204,16205] else "RubyDiningSet" if serial==16115 else "RubyUrnCabinet" if serial==16140 else "RubyRoyalChair" if serial==16124 else "RubyColumn" if serial in [16464,16499] else "RubyFramedPicture" if serial in [16130,16131,16132] else "RubyPedestal" if serial==16100 else "RubyBookcase"
 if serial in [16130,16131,16132]:node.rotation.y=-PI*.5
 if serial==16124:
  node.rotation.y=PI*.5;node.scale=Vector3.ONE*1.15;chair_back(node)
 if serial==16115:
  for side in [-1,1]:
   var chair=Geo.mesh(node,royal_chair(),Vector3(side*span.x*.80,0,-.65),null)
   chair.rotation.y=PI*.5;chair.scale=Vector3.ONE*1.15
   chair.name="OriginalDiningChair";chair_back(chair)
 node.set_meta("blue_cg_serial",serial);node.set_meta("source_cell",cell)
 if serial==16140:carving(node,"cabinet_carving",Vector3(0,1.25,.815),Vector2(span.x*3.0-.94,1.42))
 if serial==16100:
  var ornament=Sprite3D.new()
  ornament.name="OriginalBlueOrnament";ornament.texture=PedestalTop;ornament.pixel_size=.046
  ornament.position=Vector3(0,3.14+PedestalTop.get_height()*.023,0)
  ornament.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
  ornament.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;ornament.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  node.add_child(ornament)
 if serial in [16128,16129]:
  node.name="RubyCarvedVasePedestal"
  node.rotation.y=PI*.5 if serial==16128 else -PI*.5
 return node

static func court_prop(root:Node3D,cell:Vector2i,center:Vector2,serial:int):
 var node=Node3D.new();node.position=Vector3(center.x,0,center.y);root.add_child(node)
 node.name="RubyCurtain" if serial in [16465,16466] else "RubyArmoredStatue"
 node.set_meta("blue_cg_serial",serial);node.set_meta("source_cell",cell)
 var key=["court",serial]
 if not scenery_meshes.has(key):scenery_meshes[key]=curtain(serial) if serial in [16465,16466] else armor(serial)
 Geo.mesh(node,scenery_meshes[key],Vector3.ZERO,null)
 return node

static func curtain_quad(paint,part:String,points:Array,uvs:Array):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 for i in [0,1,2,0,2,3]:
  paint.surface.set_normal(normal);paint.surface.set_uv2(Scenery.TILES[part]);paint.surface.set_uv(uvs[i].clamp(Vector2(.0001,.0001),Vector2(.9999,.9999)))
  paint.surface.add_vertex(points[i])

static func curtain_crown(serial:int,u:float)->float:
 return 7.75-.58*sin(u*PI) if serial==16465 else 7.20+.80*u-.40*sin(u*PI)

static func curtain_point(serial:int,u:float,v:float,side:bool=false)->Vector3:
 var crown=curtain_crown(serial,u)
 if side:crown=(7.75 if serial==16465 else 7.20)-u*.20
 var fold=.13*cos(u*TAU*(3 if side else 8))*(.55+.45*absf(v-.45))
 var y=.16+(1-v)*(crown-1.16)+.06*sin(u*TAU*8)*v
 return Vector3(-2.625-fold,y,.68-u*1.85) if side else Vector3((u-.5)*5.25,y,.68+fold)

static func court_relief(feature:String,mesh:Mesh,pose:Transform3D,size_:Vector2):
 if court_carving_paint==null:
  court_carving_paint=SourceMesh.material(Carved.ATLAS).duplicate()
  court_carving_paint.set_shader_parameter("original_palette",false)
  court_carving_paint.set_shader_parameter("surface_kind",6)
 if not carving_meshes.has(feature):carving_meshes[feature]=Carvings.relief(feature,Carved)
 var arrays:Array=carving_meshes[feature].surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in points.size():
  var p=points[i];var u=p.x+.5
  p=Vector3(p.x*size_.x,p.y*size_.y,p.z)
  if feature.begins_with("curtain_frieze_"):p.y+=curtain_crown(16465 if feature.ends_with("16465") else 16466,u)-.525
  tool.set_uv(uvs[i]);tool.add_vertex(pose*p)
 tool.index();tool.generate_normals();tool.set_material(court_carving_paint);tool.commit(mesh)

# shortcut: The client supplies one view per curtain; canopy depth and the hidden back are fitted.
static func curtain(serial:int)->Mesh:
 var paint=SourceMesh.new([],SceneryAtlas,.046);paint.tiles=Scenery.TILES
 var wide=5.25
 for side in [false,true]:
  for i in 32:
   for j in 16:
    var points=[];var uvs=[]
    for corner:Vector2 in [Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)]:
     var u=(i+corner.x)/32.0;var v=(j+corner.y)/16.0
     points.append(curtain_point(serial,u,v,side));uvs.append(Vector2(u,v))
    curtain_quad(paint,"curtain_side" if side else "curtain_"+str(serial),points,uvs)
 for i in 24:
  var points=[]
  for corner:Vector2 in [Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)]:
   var u=(i+corner.x)/24.0
   var crown=curtain_crown(serial,u)
   points.append(Vector3((u-.5)*(wide+.30),crown-corner.y*1.05,.88))
  var front_a:Vector3=points[1];var front_b:Vector3=points[2]
  curtain_quad(paint,"curtain_canopy",[front_a,front_a+Vector3(0,-.20,-2.08),front_b+Vector3(0,-.20,-2.08),front_b],[Vector2(i/24.0,1),Vector2(i/24.0,0),Vector2((i+1)/24.0,0),Vector2((i+1)/24.0,1)])
  curtain_quad(paint,"curtain_canopy",[front_a-Vector3.UP*.08,front_b-Vector3.UP*.08,front_b+Vector3(0,-.28,-2.08),front_a+Vector3(0,-.28,-2.08)],[Vector2(i/24.0,1),Vector2((i+1)/24.0,1),Vector2((i+1)/24.0,0),Vector2(i/24.0,0)])
 var left_top=7.75 if serial==16465 else 7.20
 curtain_quad(paint,"curtain_frieze_16465",[Vector3(-2.775,left_top-1.25,-1.2),Vector3(-2.775,left_top-.2,-1.2),Vector3(-2.775,left_top,.88),Vector3(-2.775,left_top-1.05,.88)],[Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)])
 paint.surface.index()
 var mesh=paint.finish()
 Parts.prepare_primitives()
 var gold=SurfaceTool.new();gold.begin(Mesh.PRIMITIVE_TRIANGLES)
 var last=Vector3.ZERO
 for i in 25:
  var u=i/24.0
  var crown=curtain_crown(serial,u)
  var next=Vector3((u-.5)*(wide+.30),crown,.88)
  if i>0:
   for y in [0.0,-1.05]:Parts.rod(gold,last+Vector3.UP*y,next+Vector3.UP*y,.055)
  last=next
 for x in [-1,1]:
  var y=7.75 if serial==16465 else 7.20 if x<0 else 8.0
  var a=Vector3(x*(wide+.30)*.5,y-.95,.88);var b=Vector3(a.x,y+.20,a.z)
  Parts.rod(gold,a,b,.055);Parts.oval(gold,b,Vector3(.19,.19,.19))
 var previous_uv=Vector2.ZERO
 for uv:Array in Scenery.CORDS[serial]:
  var sample=Vector2(uv[0],uv[1])
  var p=curtain_point(serial,sample.x,sample.y)+Vector3(0,0,.075)
  if previous_uv!=Vector2.ZERO:
   var steps=maxi(1,ceili(previous_uv.distance_to(sample)*64))
   var previous=curtain_point(serial,previous_uv.x,previous_uv.y)+Vector3(0,0,.075)
   for i in range(1,steps+1):
    var at=previous_uv.lerp(sample,float(i)/steps)
    var next=curtain_point(serial,at.x,at.y)+Vector3(0,0,.075)
    Parts.rod(gold,previous,next,.045);previous=next
  Parts.oval(gold,p,Vector3(.09,.09,.09));previous_uv=sample
 # Existing canopy bars and pleated-panel construction, fitted to the original two-cell prop.
 for i in 12:
  var x=-wide*.5+i*wide/11
  var y=7.50-.55*sin(i/11.0*PI) if serial==16465 else 7.0+.80*i/11.0-.40*sin(i/11.0*PI)
  Parts.rod(gold,Vector3(x,y,-1.2),Vector3(x,y+.20,.80),.045)
 var rgb:Array=Scenery.COLORS.curtain_gold
 gold.set_material(Fort.material(Color(rgb[0],rgb[1],rgb[2]),false));gold.index();gold.commit(mesh)
 court_relief("curtain_frieze_"+str(serial),mesh,Transform3D(Basis.IDENTITY,Vector3(0,0,.88)),Vector2(5.55,1.05))
 return mesh

# shortcut: Native paint and visible plate/shaft proportions are recovered; unseen armor depth is fitted.
static func armor(serial:int)->Mesh:
 Parts.prepare_primitives()
 var plate=SurfaceTool.new();plate.begin(Mesh.PRIMITIVE_TRIANGLES)
 var edge=SurfaceTool.new();edge.begin(Mesh.PRIMITIVE_TRIANGLES)
 var dark=SurfaceTool.new();dark.begin(Mesh.PRIMITIVE_TRIANGLES)
 var pole=SurfaceTool.new();pole.begin(Mesh.PRIMITIVE_TRIANGLES)
 Parts.oval(dark,Vector3(0,1.72,0),Vector3(.82,.85,.58))
 Parts.oval(plate,Vector3(0,2.22,.02),Vector3(1.0,.94,.66))
 Parts.oval(edge,Vector3(0,2.53,.04),Vector3(.94,.16,.67))
 Parts.oval(plate,Vector3(0,1.86,.15),Vector3(.88,.52,.57))
 # Three overlapping fauld/tasset plates preserve the source's pointed skirt and rounded belly.
 for i in 3:
  var outline=PackedVector2Array([Vector2(-.43,.16),Vector2(.43,.16),Vector2(.34,-.12),Vector2(0,-.34),Vector2(-.34,-.12)])
  plate.append_from(Shapes.extrude(outline,.12),0,Transform3D(Basis.IDENTITY,Vector3(0,1.70-i*.14,.30+i*.035)))
 for side in [-1,1]:
  var hip=Vector3(side*.27,1.44,0);var knee=Vector3(side*.31,.83,.02)
  var ankle=Vector3(side*.32,.28,.07)
  Parts.rod(dark,hip,ankle,.14)
  Parts.oval(plate,(hip+knee)*.5,Vector3(.35,.63,.42))
  Parts.oval(edge,knee+Vector3(0,.02,.09),Vector3(.40,.31,.38))
  Parts.oval(plate,(knee+ankle)*.5,Vector3(.32,.57,.34))
  Parts.oval(plate,Vector3(side*.33,.16,.25),Vector3(.43,.29,.77))
  var shoulder=Vector3(side*.60,2.48,0)
  var elbow=Vector3(side*.80,2.00,.10)
  var hand=Vector3(side*.84,1.64,.16)
  if side<0:
   elbow=Vector3(-.81,2.12,.27);hand=Vector3(-1.00,2.17,.44)
  Parts.rod(dark,shoulder,elbow,.16);Parts.rod(dark,elbow,hand,.12)
  for layer in 3:Parts.oval(edge if layer==0 else plate,shoulder+Vector3(side*layer*.025,-layer*.09,.015),Vector3(.62-layer*.035,.27,.69-layer*.02))
  Parts.rod(plate,shoulder-Vector3.UP*.18,elbow,.18)
  Parts.oval(edge,elbow,Vector3(.36,.33,.35))
  for layer in 3:
   var a=elbow.lerp(hand,layer/3.0);var b=elbow.lerp(hand,(layer+1)/3.0)
   Parts.rod(plate,a,b,.155-layer*.01)
   Parts.oval(edge,a,Vector3(.30,.10,.32))
  Parts.oval(plate,hand,Vector3(.28,.32,.29))
  for finger in 4:
   var knuckle=hand+Vector3((finger-1.5)*.048,-.08,.125)
   Parts.rod(edge,knuckle,knuckle+Vector3(0,-.095,-.025),.022)
  for layer in 2:Parts.oval(edge,Vector3(side*.33,.20+layer*.065,.34),Vector3(.40,.055,.42))
 Parts.rod(dark,Vector3.UP*2.54,Vector3.UP*2.75,.16)
 Parts.oval(plate,Vector3(0,2.85,.02),Vector3(.62,.68,.59))
 Parts.oval(edge,Vector3(0,3.00,.03),Vector3(.65,.13,.62))
 Parts.block(dark,Vector3(0,2.77,.318),Vector3(.46,.075,.04))
 Parts.block(plate,Vector3(0,2.72,.354),Vector3(.055,.20,.085))
 Parts.oval(plate,Vector3(0,2.62,.24),Vector3(.49,.29,.35))
 Parts.rod(edge,Vector3(0,2.68,.43),Vector3(0,3.16,.24),.028)
 for side in [-1,1]:
  Parts.rod(edge,Vector3(side*.20,2.74,.37),Vector3(side*.28,2.86,.26),.022)
  for i in 3:Parts.oval(edge,Vector3(side*(.50+i*.08),2.52-i*.09,.29),Vector3(.048,.048,.048))
 for y in [2.55,2.61,2.67]:Parts.oval(edge,Vector3(0,y,0),Vector3(.48,.045,.40))
 Parts.rod(edge,Vector3(0,3.19,0),Vector3(0,3.40,-.01),.07)
 for row in [[Vector3(0,3.43,-.04),Vector3(.20,.28,.22)],[Vector3(0,3.61,-.15),Vector3(.20,.26,.25)],[Vector3(0,3.72,-.28),Vector3(.20,.17,.25)]]:Parts.oval(plate,row[0],row[1])
 # Measured source shaft endpoints relative to the gauntlet, including its high overhang.
 var hand=Vector3(-1.00,2.17,.44)
 var tip=hand+Vector3(-2.10,4.38,0) if serial==16193 else hand+Vector3(.62,5.92,0)
 var axis=(tip-hand).normalized()
 Parts.rod(pole,hand-axis*1.15,tip-axis*.24,.035)
 Parts.rod(edge,tip-axis*.36,tip-axis*.18,.055)
 var blade=PackedVector2Array([Vector2(0,.20),Vector2(.075,-.12),Vector2(0,-.06),Vector2(-.075,-.12)])
 edge.append_from(Shapes.extrude(blade,.025),0,Transform3D(Basis(Quaternion(Vector3.UP,axis)),tip-axis*.12))
 var result=ArrayMesh.new();var yaw=-PI*.5 if serial==16193 else PI*.5
 for row in [[plate,"armor_plate"],[edge,"armor_edge"],[dark,"armor_joint"],[pole,"armor_shaft"]]:
  if row[1]!="armor_plate":row[0].set_material(armor_material(row[1]))
  row[0].index()
  var mesh:Mesh=row[0].commit()
  if row[1]=="armor_plate":
   if armor_paint==null:
    armor_paint=SourceMesh.material(SceneryAtlas,true).duplicate()
    armor_paint.set_shader_parameter("original_palette",false);armor_paint.set_shader_parameter("surface_kind",6)
   var arrays:Array=mesh.surface_get_arrays(0);var uvs=PackedVector2Array();var tiles=PackedVector2Array()
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    var px=78+(point.x*.75-point.z*.66)/.035 if serial==16193 else 24+(-point.x*.75+point.z*.66)/.035
    var py=187-point.y/.035+(point.z*.75+point.x*.66)*.4/.035 if serial==16193 else 247-point.y/.035+(-point.z*.75-point.x*.66)*.4/.035
    uvs.append(Vector2((px-52)/60.0,(py-76)/117.0).clamp(Vector2(.001,.001),Vector2(.999,.999)) if serial==16193 else Vector2(px/52.0,(py-135)/117.0).clamp(Vector2(.001,.001),Vector2(.999,.999)))
    tiles.append(Scenery.TILES["armor_"+str(serial)])
   arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=tiles
   var painted=ArrayMesh.new();painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);painted.surface_set_material(0,armor_paint);mesh=painted
  var rotated=SurfaceTool.new();rotated.begin(Mesh.PRIMITIVE_TRIANGLES)
  rotated.append_from(mesh,0,Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO));rotated.set_material(mesh.surface_get_material(0));rotated.commit(result)
 return result

static func armor_material(part:String)->Material:
 if not armor_materials.has(part):
  var material=ShaderMaterial.new();material.shader=SourceMesh.Paint.SURFACE
  var rgb:Array=Scenery.COLORS[part]
  material.set_shader_parameter("base_color",Color(rgb[0],rgb[1],rgb[2]))
  material.set_shader_parameter("brush_texture",SourceMesh.Paint.BRUSH)
  material.set_shader_parameter("surface_kind",6);material.set_shader_parameter("use_vertex_color",false)
  armor_materials[part]=material
 return armor_materials[part]

static func flower_part(serial:int,variant:int)->Array:
 var key=Vector2i(serial,variant)
 if not flower_parts.has(key):
  var source:Array=Meadow.source(["flowers_coral","flowers_ivory","flowers_blue","leafy_shrub"][variant])
  var native:Dictionary=Scenery.BOUQUETS[serial]
  var petals=native.keys().filter(func(name):return name!="green")
  var rgb:Array=native[petals[variant%petals.size()]];var green:Array=native.green
  var result=[]
  for part in source:
   var arrays:Array=part.mesh.surface_get_arrays(0)
   var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR].duplicate()
   for i in colors.size():
    var old=colors[i];var leaf=old.g>old.r*1.1 and old.g>old.b*1.1
    var tint=green if leaf else rgb
    var shade=clampf(old.g/.26,.75,1.15) if leaf else .80+maxf(old.r,maxf(old.g,old.b))*.20
    colors[i]=Color(tint[0]*shade,tint[1]*shade,tint[2]*shade,1.0)
   arrays[Mesh.ARRAY_COLOR]=colors
   var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   result.append([mesh,part.transform])
  flower_parts[key]=result
 return flower_parts[key]

static func flower_cluster(tool:SurfaceTool,serial:int,variant:int,pose:Transform3D,root:Vector3):
 for part in flower_part(serial,variant):
  var arrays:Array=part[0].surface_get_arrays(0)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
  var normal_pose=(pose*part[1]).basis.inverse().transposed()
  for i in indices:
   var local:Vector3=part[1]*points[i];var point=pose*local
   var stem=clampf(local.y/.32,0,1)
   point=(root+Vector3(local.x*.15,0,local.z*.15)).lerp(point,stem)
   tool.set_color(colors[i]);tool.set_normal((normal_pose*normals[i]).normalized());tool.add_vertex(point)

static func bouquet(mesh:Mesh,serial:int,at:Vector3=Vector3.ZERO):
 var flowers=SurfaceTool.new();flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count_=3 if serial==16223 else 12 if serial==16232 else 9
 var root=at+Vector3.UP*(.50 if serial==16223 else .76 if serial==16218 else .78 if serial==16219 else .48)
 for i in count_:
  var angle=i*TAU/count_
  var radius=.10 if serial==16223 else .24 if serial==16218 else .28 if i<6 and serial==16232 else .55
  var y=.72 if serial==16223 else .95+.85*(.5+.5*sin(angle)) if serial==16218 else 1.10 if serial==16232 and i<6 else .70 if serial==16232 else 1.0+.6*(.5+.5*cos(angle))
  var scale_=1.30 if serial==16223 else 1.10
  var pose=Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_),at+Vector3(cos(angle)*radius,y,sin(angle)*radius))
  flower_cluster(flowers,serial,i%3,pose,root)
 var leaf_scale=Vector3(.23,.40,.22) if serial==16223 else Vector3(.24,.75,.24) if serial==16218 else Vector3(.55,.60,.45) if serial==16219 else Vector3(.65,.55,.55)
 var leaf_y=.45 if serial==16223 else .60 if serial==16218 else .25 if serial==16219 else .05
 flower_cluster(flowers,serial,3,Transform3D(Basis.IDENTITY.scaled(leaf_scale),at+Vector3.UP*leaf_y),root)
 if flower_material==null:
  flower_material=StandardMaterial3D.new();flower_material.vertex_color_use_as_albedo=true
  flower_material.vertex_color_is_srgb=true;flower_material.cull_mode=BaseMaterial3D.CULL_DISABLED;flower_material.roughness=.94
 flowers.set_material(flower_material);flowers.index();flowers.commit(mesh)

static func floral_prop(root:Node3D,cell:Vector2i,center:Vector2,serial:int):
 var key=["floral",serial]
 if not scenery_meshes.has(key):
  var paint=SourceMesh.new([],SceneryAtlas,.046);paint.tiles=Scenery.TILES
  if serial==16223:
   paint.part="mirror_lacquer"
   paint.box(AABB(Vector3(-2.20,.08,-.65),Vector3(4.40,1.30,1.30)))
   paint.part="picture_gilt"
   for y in [.10,1.38]:paint.box(AABB(Vector3(-2.25,y,-.69),Vector3(4.50,.10,1.38)))
   for x in [-2.18,2.10]:paint.box(AABB(Vector3(x,.14,.65),Vector3(.08,1.20,.08)))
   paint.part="mirror_lacquer"
   paint.box(AABB(Vector3(-2.06,1.43,-.53),Vector3(4.12,4.94,.20)))
   paint.panel(Vector3(-1.92,1.55,-.315),Vector3(-1.92,6.25,-.315),Vector3(1.92,6.25,-.315),Vector3(1.92,1.55,-.315),"mirror_glass")
   paint.part="picture_gilt"
   for x in [-2.06,1.96]:paint.box(AABB(Vector3(x,1.43,-.34),Vector3(.10,4.94,.10)))
   for y in [1.43,6.27]:paint.box(AABB(Vector3(-2.06,y,-.34),Vector3(4.12,.10,.10)))
   for x in [-1.58,1.58]:turned(paint,Vector3(x,1.48,.10),[Vector2(.14,0),Vector2(.26,.14),Vector2(.21,.40),Vector2(.12,.50)],"mirror_vase")
  else:
   var profile=[Vector2(.18,0),Vector2(.35,.16),Vector2(.37,.47),Vector2(.18,.70),Vector2(.22,.76)] if serial==16218 else [Vector2(.22,0),Vector2(.46,.20),Vector2(.45,.48),Vector2(.27,.72),Vector2(.31,.78)] if serial==16219 else [Vector2(.38,0),Vector2(.60,.12),Vector2(.63,.38),Vector2(.55,.48)]
   turned(paint,Vector3.ZERO,profile,"flower_pot_"+str(serial))
  var mesh=paint.finish()
  if serial==16223:
   court_relief("mirror_cabinet",mesh,Transform3D(Basis.IDENTITY,Vector3(0,.76,.656)),Vector2(3.85,1.10))
   for x in [-1.58,1.58]:bouquet(mesh,16223,Vector3(x,1.48,.10))
  else:bouquet(mesh,serial)
  scenery_meshes[key]=mesh
 var node=Geo.mesh(root,scenery_meshes[key],Vector3(center.x,0,center.y),null)
 node.name="RubyDressingMirror" if serial==16223 else "RubyNativeBouquet"
 node.set_meta("blue_cg_serial",serial);node.set_meta("source_cell",cell)
 return node
