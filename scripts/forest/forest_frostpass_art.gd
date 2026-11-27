extends RefCounted
const Route=preload("res://scripts/forest/forest_frostpass.gd")
const Rooms=preload("res://scripts/forest/forest_frostpass_interiors.gd")
const Crags=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const FROZEN_SURFACE=preload("res://assets/materials/snow_mountain_ice.gdshader")
const PASSAGE_SHADOW=preload("res://assets/materials/snow_passage_shadow.gdshader")
const FROZEN_PASSAGE_DEPTH=4.15
const CAVE_COLORS=[Color("65747d"),Color("4a718c"),Color("567e9b"),Color("3c6e88"),Color("534b76")]
const WALL_PROFILE=[
 Vector2(-.06,0.0),Vector2(.10,.12),Vector2(.24,.24),Vector2(.33,.06),
 Vector2(.49,.30),Vector2(.54,.48),Vector2(.72,.31),Vector2(.92,.57),
 Vector2(1.0,.94),Vector2(.96,2.24),
]
const CARDINAL=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const TUNNEL_CUT=[
 Vector2(-1.0,-.04),Vector2(-1.0,.49),Vector2(-.84,.75),Vector2(-.44,.93),
 Vector2(.04,1.0),Vector2(.48,.94),Vector2(.82,.73),Vector2(1.0,.48),Vector2(1.0,-.04),
]
const MOUNTAIN_CUT=[
 Vector2(-1.03,-.04),Vector2(-1.01,.41),Vector2(-.88,.70),Vector2(-.48,.92),
 Vector2(.06,1.0),Vector2(.47,.96),Vector2(.88,.69),Vector2(1.02,.43),Vector2(1.04,-.04),
]
const CLIFF_SECTION=[
 Vector2(0,-3.0),Vector2(.30,.30),Vector2(1.82,.39),Vector2(2.58,3.78),
 Vector2(4.10,3.98),Vector2(4.91,6.86),Vector2(6.98,7.20),Vector2(9.54,9.88),
 Vector2(13.7,8.62),Vector2(17,-3.0),
]
const ICE_SPOTS={
 51001:[Vector2i(7,12),Vector2i(24,10),Vector2i(24,13)],
 51002:[Vector2i(8,10),Vector2i(8,13),Vector2i(17,18),Vector2i(22,12)],
 51003:[Vector2i(8,9),Vector2i(19,12),Vector2i(21,14),Vector2i(25,15)],
}
const TRAIL_TREAD=[Vector2(0,34.4),Vector2(0,26),Vector2(-2,22),Vector2(-9,21),Vector2(-12,18),
 Vector2(-12,5),Vector2(-9,1.4),Vector2(11,1.4),Vector2(15,-2),Vector2(15,-16.2),
 Vector2(11,-20),Vector2(0,-20.5),Vector2(-3,-24),Vector2(-3,-34)]
static var tread_texture:ImageTexture

static func trailhead(root:Node3D,model):
 var at=Route.TRAILHEAD
 var base=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
 var backdrop=SurfaceTool.new()
 backdrop.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  var shoulder=base+Vector3(side*5.90,-.9,-3.8)
  Crags.ridge(backdrop,shoulder,Vector2(5.4,8.9),6.2+float(side)*.65,side+3,true,.54)
  Crags.ridge(backdrop,shoulder+Vector3(side*2.5,-.2,1.2),Vector2(4.1,5.6),3.1,side+7,false)
 finish(root,backdrop,Fort.material(Color("667d71"),false),"FrostpassTrailhead")
 var frame=tunnel(root,base+Vector3(0,0,1.8),1.0,Vector2(2.8,4.8),4.9,Color("77877f"),false)
 frame.name="WesternLakesPassage"
 var boxes=Boxes.new()
 var stone=Fort.material(Color("899487"),false)
 for row in range(-5,3):
  var z=at.y+2.9+row*1.05
  for i in 3:
   var x=at.x+(i-1)*1.56
   var y:float=model.surface_height(x,z)
   boxes.add(Vector3(x,y-.06,z),Vector3(1.50,.20,.91),stone)
 for side in [-1,1]:
  var point=at+Vector2(side*3.9,2.4)
  var y:float=model.surface_height(point.x,point.y)
  var post=Vector3(point.x,y,point.y)
  boxes.add(post+Vector3.UP*.34,Vector3(1.20,.68,1.10),stone)
  boxes.add(post+Vector3.UP*.92,Vector3(.82,.49,.82),stone)
  boxes.add(post+Vector3.UP*1.20,Vector3(.99,.17,.98),Fort.material(Color("b2bcaa"),false))
 boxes.build(root)
 var sign=Vector2(at.x-5,at.y+9)
 var foot=Vector3(sign.x,model.surface_height(sign.x,sign.y),sign.y)
 Geo.box(root,foot+Vector3.UP*1.1,Vector3(.2,2.2,.2),Fort.material(Color("795239"),false))
 Geo.box(root,foot+Vector3.UP*2.15,Vector3(3.05,.71,.18),Geo.mat("755242"))
 for y in [1.77,2.53]:
  Geo.box(root,foot+Vector3.UP*y,Vector3(3.13,.11,.24),Geo.mat("a07a50"))
 var label=Label3D.new()
 label.text="莎蓮娜海底洞窟 ↑"
 label.name="FrostpassTrailSign"
 label.font_size=38
 label.pixel_size=.007
 label.position=foot+Vector3(0,2.16,.14)
 root.add_child(label)

static func finish(root:Node3D,surface:SurfaceTool,material:Material,name_:String)->MeshInstance3D:
 surface.generate_normals()
 surface.index()
 var node=Geo.mesh(root,surface.commit(),Vector3.ZERO,material)
 node.name=name_
 return node

static func build(root:Node3D,boxes,id:int,walk:PackedByteArray,run_seed:int,obstacles:Array[AABB])->Dictionary:
 if id==Route.COAST_ROAD:
  university_road(root,boxes,walk)
  return {}
 var furnished={}
 var town=Route.HOUSES.has(id)
 var frozen=id in [Route.SNOW_CAVE,Route.ICE_VAULT]
 var snow=Fort.material(Color("e0eef0"),false)
 var stage=Route.LEVELS.keys().find(id)
 var ground=snow if town else Fort.material(CAVE_COLORS[stage],false)
 var path:ShaderMaterial
 if town:
  path=Fort.material(Color("98aab5"),false).duplicate()
  path.set_shader_parameter("frost_paving",true)
 if town:
  Geo.box(root,Vector3(0,-.40,0),Vector3(117,.55,99),snow).name="Snowfield"
  for i in Route.HOUSES[id].size():
   var lot:Rect2i=Route.HOUSES[id][i]
   house(root,boxes,lot,i,id)
   for z in range(lot.position.y,lot.end.y):
    for x in range(lot.position.x,lot.end.x):furnished[Vector2i(x,z)]=true
  mountains(root,id)
  town_details(root,boxes,id,snow)
  if id==Route.ABANIS or id==Route.UNIVERSITY:highland_square(root,boxes,id,obstacles)
  if id==Route.ABANIS:abanis_streets(root,boxes,snow,obstacles)
 else:
  Geo.box(root,Vector3(0,-.86,0),Vector3(103,.4,85),Fort.material(CAVE_COLORS[stage].darkened(.62),false)).name="CavernBed"
  cave_walls(root,id,walk)
  var rocks:Array=Route.snow_maze(id,run_seed).rocks if frozen else Route.ROCKS[id]
  cave_mass(root,id,walk,rocks)
  if frozen:
   frozen_floor(root,id,walk,mountain_ice(root,id,walk,rocks))
   mountain_woodland(root,id,walk,rocks,run_seed,snow,obstacles)
  else:ice(root,id)
 if not frozen:
  var drift=Fort.material(Color("cfdfeb") if town else CAVE_COLORS[stage].lightened(.17),false)
  for z in Route.SIZE.y:
   for x in Route.SIZE.x:
    var cell=Vector2i(x,z)
    if not open_cell(walk,cell):continue
    var at=Route.point(cell)
    var paved=town and (x in range(10,13) or z in range(11,13) or (x in range(23,26) and z<13))
    if id==Route.ABANIS:
     paved=Route.ABANIS_STREETS.any(func(lane):return lane.has_point(cell))
    elif id==Route.UNIVERSITY:
     paved=Route.UNIVERSITY_WALKS.any(func(lane):return lane.has_point(cell))
    var bank=sin(x*.33+z*.21)*cos(z*.55-x*.71)>(.38 if town else .66)
    boxes.add(Vector3(at.x,-.10,at.y),Vector3(3.0,.20,3.0),path if paved else drift if bank else ground,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 for i in Route.DOORS[id].size():
  var at=Route.point(Route.DOORS[id][i])
  if town:arch(root,boxes,at,id,i)
  else:cave_entry(root,boxes,at,id,i)
 return furnished

static func university_road(root:Node3D,boxes,walk:PackedByteArray):
 var snow=Fort.material(Color("cbdde6"),false)
 var road=Fort.material(Color("a9b6b8"),false).duplicate()
 road.set_shader_parameter("frost_paving",true)
 var land=SurfaceTool.new()
 var rocks=SurfaceTool.new()
 var ice=SurfaceTool.new()
 var banks=SurfaceTool.new()
 for surface in [land,rocks,ice,banks]:surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var trees:Array[Transform3D]=[]
 var lamps:Array[Transform3D]=[]
 var route=Route.COAST_PATH.map(func(cell):return Route.point(cell))
 for z in range(-45,42,3):
  var west=-37.0+39.0*smoothstep(-24.0,32.0,z)+2.3*sin(z*.13)
  var next=-37.0+39.0*smoothstep(-24.0,32.0,z+3)+2.3*sin((z+3)*.13)
  var a=Vector3(west,-.31,z)
  var b=Vector3(next,-.31,z+3)
  Shapes.quad(land,a,Vector3(53,-.31,z),Vector3(53,-.31,z+3),b)
  Crags.face(rocks,a,b,b+Vector3(-1.8,-2.0,0),a+Vector3(-1.8,-2.0,0))
  if z%9==0:
   var floe=Vector2(4.1+1.8*cos(z*.21),3.7+1.4*sin(z*.33))
   Crags.ridge(ice,a+Vector3(-3.8-1.1*cos(z),-2.16,.8),floe,.39,z*17,false)
   Crags.ridge(rocks,a+Vector3(.7,-.65,1.4),Vector2(3.8,4.9),1.06+.39*cos(z*.18),z*19,false)
 finish(root,land,snow,"UniversityRoadSnow")
 finish(root,rocks,Fort.material(Color("758c9a"),false),"UniversityCoastCliffs")
 finish(root,ice,Geo.mat("b8d7df",.10),"UniversityShoreIce")
 var sea=Geo.box(root,Vector3(-31,-2.46,-1.5),Vector3(347,.23,292),Geo.mat("597d92",.12))
 sea.name="UniversityCoastWater"
 sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for row in Route.SIZE.y:
  var edges:Array[int]=[]
  for col in Route.SIZE.x:
   var cell=Vector2i(col,row)
   if not open_cell(walk,cell):continue
   edges.append(col)
   var point=Route.point(cell)
   var paved=false
   for segment in route.size()-1:
    if Geometry2D.get_closest_point_to_segment(point,route[segment],route[segment+1]).distance_squared_to(point)<11.0:
     paved=true
     break
   boxes.add(Vector3(point.x,-.12,point.y),Vector3(3.0,.24,3.0),road if paved else snow,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  if edges.is_empty() or row%2!=0:continue
  for col in [edges.front()-1,edges.back()+1]:
   var cell=Vector2i(col,row)
   if Route.DOORS[Route.COAST_ROAD].any(func(door):return Vector2(door-cell).length_squared()<14.0):continue
   var point=Route.point(cell)
   var heading=.71*row+col
   var inland=col>edges.back()
   var bank=Vector3(point.x+(1.6 if inland else -.65),-.58,point.y)
   Crags.ridge(banks,bank,Vector2(5.1,7.8),.99+.43*absf(sin(heading)),row*23+col,false)
   if inland and row%4==2:
    Crags.ridge(banks,bank+Vector3(7.9,-.58,.70),Vector2(18.9,13.2),4.0+1.55*cos(heading),row*19+col,true,.61)
   var size=.61+.18*absf(sin(heading))
   var base=Vector3(point.x+.70*sin(heading),-.27,point.y+.65*cos(heading))
   trees.append(Transform3D(Basis(Vector3.UP,heading).scaled(Vector3.ONE*size),
    base))
   if row%4==0:
    trees.append(Transform3D(Basis(Vector3.UP,heading+1.45).scaled(Vector3.ONE*.43),base+Vector3(.76,0,2.18)))
   if row%6==2:
    lamps.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.76),Vector3(point.x,-.30,point.y+1.6)))
 finish(root,banks,snow,"UniversityRoadSnowbanks")
 snowy_grove(root,trees)
 Lamps.batch(root,10429,lamps)
 for side in Route.DOORS[Route.COAST_ROAD].size():
  var point=Route.point(Route.DOORS[Route.COAST_ROAD][side])
  arch(root,boxes,point,Route.COAST_ROAD,side)
  var sign=Vector3(point.x+4.0,1.90,point.y)
  signpost(root,sign,"阿巴尼斯村" if side==0 else "魔法大學",side==0)

static func signpost(root:Node3D,at:Vector3,caption:String,reverse:bool=false):
 var oak=Fort.material(Color("745747"),false)
 Geo.box(root,at-Vector3.UP*.92,Vector3(.21,1.94,.27),oak)
 Geo.box(root,at,Vector3(3.12,.69,.20),oak)
 var label=Label3D.new()
 label.name="HighlandRouteSign"+caption
 label.text=caption
 label.position=at+Vector3.BACK*(-.114 if reverse else .114)
 label.rotation.y=PI if reverse else 0.0
 label.font_size=45
 label.pixel_size=.011
 label.modulate=Color("fff0d4")
 root.add_child(label)

static func ice_surface(id:int,wall:bool)->ShaderMaterial:
 var deep=id==Route.ICE_VAULT
 var frost=ShaderMaterial.new()
 frost.shader=FROZEN_SURFACE
 frost.set_shader_parameter("wall_glaze",wall)
 frost.set_shader_parameter("rock_texture",Fort.ROCK)
 frost.set_shader_parameter("ice_color",Color("5c6298" if deep else "487e99"))
 frost.set_shader_parameter("frost_color",Color("a7bce0" if deep else "b4dbe9"))
 return frost

static func frozen_floor(root:Node3D,id:int,walk:PackedByteArray,crystal_pools:PackedVector4Array):
 var floor_surface=SurfaceTool.new()
 floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var corners=[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]
 var touching=[Vector2i.ZERO,Vector2i.LEFT,-Vector2i.ONE,Vector2i.UP]
 for z in Route.SIZE.y:
  for x in Route.SIZE.x:
   var cell=Vector2i(x,z)
   if not open_cell(walk,cell):continue
   for index in [0,1,2,0,2,3]:
    var corner:Vector2i=cell+corners[index]
    var powder=0.0
    for neighbor:Vector2i in touching:
     if not open_cell(walk,corner+neighbor):powder+=.25
    var p=Route.point(corner)-Vector2.ONE*1.5
    floor_surface.set_color(Color(powder,0,0))
    floor_surface.add_vertex(Vector3(p.x,0,p.y))
 var material=ice_surface(id,false)
 material.set_shader_parameter("crystal_pools",crystal_pools)
 material.set_shader_parameter("powder_cover",.98 if id==Route.ICE_VAULT else 1.0)
 var mesh=finish(root,floor_surface,material,"SnowMountainFrozenFloor")
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func mountain_woodland(root:Node3D,id:int,walk:PackedByteArray,rocks:Array,run_seed:int,snow:Material,obstacles:Array[AABB]):
 var stage=Route.LEVELS.keys().find(id)
 var shoulders={}
 var verges={}
 for z in range(1,Route.SIZE.y-1):
  for x in range(1,Route.SIZE.x-1):
   var cell=Vector2i(x,z)
   if rocks.any(func(rock):return rock.grow(1).has_point(cell)):continue
   if Route.DOORS[id].any(func(door):return Vector2(cell-door).length_squared()<14.0):continue
   if open_cell(walk,cell):
    var walls=CARDINAL.filter(func(step):return not open_cell(walk,cell+step))
    if walls.size()==1 and open_cell(walk,cell-walls[0]*2):verges[cell]=walls[0]
    continue
   for step:Vector2i in CARDINAL:
    if not open_cell(walk,cell-step):continue
    var edge=Route.point(cell)-Vector2(step)*1.5
    shoulders[cell]=wall_column(edge,stage,walk)[8]+Vector3(step.x*.26,-.55,step.y*.26)
    break
 var rng=Route.Maze.rng_for(id,run_seed)
 var roots:Array[Vector3]=[]
 var upper:Array[Transform3D]=[]
 var lower:Array[Transform3D]=[]
 var saplings:Array[Transform3D]=[]
 var planted={}
 var drifts=SurfaceTool.new()
 var bark=SurfaceTool.new()
 drifts.begin(Mesh.PRIMITIVE_TRIANGLES)
 bark.begin(Mesh.PRIMITIVE_TRIANGLES)
 Lamps.prepare_primitives()
 for cell:Vector2i in Route.Maze.shuffled(verges.keys(),rng)+Route.Maze.shuffled(shoulders.keys(),rng):
  var low=verges.has(cell)
  if low and lower.size()>=26:continue
  if not low and upper.size()>=14:break
  var out:Vector2=Vector2(verges.get(cell,Vector2i.ZERO))
  var edge=Route.point(cell)+out*1.18
  var at:Vector3=Vector3(edge.x,0.0,edge.y) if low else shoulders[cell]
  if roots.any(func(other):return Vector2(other.x-at.x,other.z-at.z).length_squared()<22.0):continue
  roots.append(at)
  var size=rng.randf_range(.83,1.18) if low else rng.randf_range(.70,1.06)
  if low:
   planted[cell]=true
   lower.append(path_tree(root,drifts,obstacles,cell,out,size,rng))
   var foot=lower.back().origin
   var tangent=Vector3(-out.y,0,out.x)
   for side in [-1,1]:
    var elbow=foot+tangent*(side*.40)+Vector3(-out.x*.28,.36,-out.y*.28)*size
    var tip=foot+tangent*(side*.89)+Vector3(-out.x*.62,.07,-out.y*.62)*size
    Lamps.rod(bark,foot+Vector3.UP*.62*size,elbow,.12*size)
    Lamps.rod(bark,elbow,tip,.066*size)
  else:
   var basis=Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*size)
   upper.append(Transform3D(basis,at))
   Crags.ridge(drifts,at-Vector3.UP*1.07,Vector2(3.3,3.0),1.24,cell.x*23+cell.y*11,false)
 for cell:Vector2i in Route.Maze.shuffled(planted.keys(),rng):
  var side:Vector2i=verges[cell]
  var tangent=Vector2i(side.y,-side.x)
  for neighbor:Vector2i in [cell+tangent,cell-tangent]:
   if planted.has(neighbor) or verges.get(neighbor)!=side:continue
   planted[neighbor]=true
   saplings.append(path_tree(root,drifts,obstacles,neighbor,Vector2(side),rng.randf_range(.36,.55),rng))
   break
  if saplings.size()==14:break
 finish(root,drifts,snow,"SnowMountainWoodlandDrifts")
 Geo.mesh(root,bark.commit(),Vector3.ZERO,Fort.material(Color("58493c"),false)).name="SnowMountainExposedRoots"
 var tint=Color("9caa85" if id==Route.SNOW_CAVE else "899b8c")
 snowy_grove(root,upper,10085,"",tint)
 snowy_grove(root,lower,10088,"",tint)
 snowy_grove(root,saplings,10088,"SnowMountainSaplings",tint)

static func path_tree(root:Node3D,drifts:SurfaceTool,obstacles:Array[AABB],cell:Vector2i,out:Vector2,size:float,rng:RandomNumberGenerator)->Transform3D:
 var edge=Route.point(cell)+out*1.18
 var at=Vector3(edge.x,0.0,edge.y)
 var basis=Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*size)
 basis=Basis(Vector3(-out.y,0.0,out.x),rng.randf_range(.05,.15))*basis
 var trunk_size=Vector3(.44,2.1,.44)*minf(1.0,size/.80)
 var trunk=at+Vector3(-out.x*.06,trunk_size.y*.5,-out.y*.06)
 Art.solid(root,trunk,trunk_size,1,"wood",true).name="SnowMountainPathTrunk%d"%obstacles.size()
 obstacles.append(AABB(trunk-trunk_size*.5,trunk_size))
 var extent=Vector2(2.2,4.6) if out.x!=0.0 else Vector2(4.6,2.2)
 Crags.ridge(drifts,at+Vector3(out.x*.30,-.13,out.y*.30),extent,.43+size*.30,cell.x*23+cell.y*11,false)
 return Transform3D(basis,at)

static func mountain_trail(root:Node3D,boxes,walk:PackedByteArray):
 var ground=SurfaceTool.new()
 var cliffs=SurfaceTool.new()
 ground.begin(Mesh.PRIMITIVE_TRIANGLES)
 cliffs.begin(Mesh.PRIMITIVE_TRIANGLES)
 var half=Vector2.ONE*1.5
 for z in Route.SIZE.y:
  for x in Route.SIZE.x:
   var cell=Vector2i(x,z)
   var at=Route.point(cell)
   var low=at-half
   var high=at+half
   if open_cell(walk,cell):
    var y0=Route.trail_height(low.y)
    var y1=Route.trail_height(high.y)
    var corners=[Vector3(low.x,y0,low.y),Vector3(high.x,y0,low.y),
     Vector3(high.x,y1,high.y),Vector3(low.x,y1,high.y)]
    for index in [0,1,2,0,2,3]:
     var p:Vector3=corners[index]
     ground.set_uv((Vector2(p.x,p.z)-Route.ORIGIN+half)/(Vector2(Route.SIZE)*3.0))
     ground.add_vertex(p)
    for step:Vector2i in CARDINAL:
     if open_cell(walk,cell+step):continue
     var edge=at+Vector2(step)*1.5
     var tangent=Vector2(step.y,-step.x)*1.5
     var a=edge-tangent
     var b=edge+tangent
     var p=Vector3(a.x,Route.trail_height(a.y),a.y)
     var q=Vector3(b.x,Route.trail_height(b.y),b.y)
     Crags.face(cliffs,p,q,q-Vector3.UP*7.0,p-Vector3.UP*7.0)
   elif CARDINAL.any(func(step):return open_cell(walk,cell+step)):
    var relief=sin(x*2.63+z*2.06)
    var rise=lerpf(.22,1.90,smoothstep(-.60,.95,relief))
    var extent=Vector2(4.04,4.56) if z%3!=1 else Vector2(4.40,3.42)
    Crags.ridge(cliffs,Vector3(at.x,Route.trail_height(at.y)-.32,at.y),extent,rise,x*11+z*19,false)
 ground.generate_normals()
 ground.index()
 var snow=Fort.material(Color("ccdce4"),false)
 var floor_mesh=Geo.mesh(root,ground.commit(),Vector3.ZERO,trail_snow(snow),true)
 floor_mesh.name="SnowMountainTrailFloor"
 for body in floor_mesh.get_children():body.set_meta("snow_mountain_ground",true)
 for side in [-1,1]:
  for i in 7:
   var z=34.0-i*12.4
   var x=side*(29.4+3.8*sin(i*1.74+side))
   var height=9.0+5.2*sin(i*1.86+side)+(6 if i>=4 else 0)
   if i%2==0:
    Crags.ridge(cliffs,Vector3(x+side*6.2,Route.trail_height(z)-3.1,z),Vector2(23,24),height,i+side*12,true,.59)
 for i in 5:
  Crags.ridge(cliffs,Vector3(-24.0+i*12.5,8.75,-50.7),Vector2(17,18),13.5+5.0*sin(i*2.3),i+61,true,.55)
 var basin=SurfaceTool.new()
 basin.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(-84,68,8):
  for x in range(-81,80,8):
   var corners:Array[Vector3]=[]
   for offset in [Vector2.ZERO,Vector2(8,0),Vector2(8,8),Vector2(0,8)]:
    var p=Vector2(x,z)+offset
    corners.append(Vector3(p.x,trail_basin_height(p),p.y))
   Crags.face(basin,corners[0],corners[1],corners[2],corners[3])
 finish(root,basin,Fort.material(Color("aabfd1"),false),"SnowMountainBasin")
 var rock=Fort.material(Color("778ba0"),false).duplicate()
 rock.set_shader_parameter("snow_cover",.58)
 finish(root,cliffs,rock,"SnowMountainCliffs")
 alpine_cliffs(root,snow)
 trail_groves(root,walk)
 var first=Route.point(Route.DOORS[Route.TRAIL][0])
 var last=Route.point(Route.DOORS[Route.TRAIL][1])
 for at:Vector2 in [first,last+Vector2(0,4.0)]:
  var y=Route.trail_height(at.y)
  var stone=Fort.material(Color("8498a5"))
  for direction in [-1,1]:
   var summit=at!=first
   var x=at.x+direction*(4.45 if summit else 3.1)
   boxes.add(Vector3(x,y+.38,at.y),Vector3(.98,.88,.96),stone)
   boxes.add(Vector3(x,y+.93,at.y),Vector3(.68,.38,.67),snow)
   var lamp=Vector3(x,y+1.26,at.y)
   if summit:
    var crystal=SurfaceTool.new()
    crystal.begin(Mesh.PRIMITIVE_TRIANGLES)
    ice_blade(crystal,lamp-Vector3.UP*.14,.69,Vector2(.25,.23),Vector2(direction*.05,.027),direction+3)
    finish(root,crystal,Geo.mat("eab251",.12,.44),"SnowMountainAmberMarker%d"%direction)
    Rooms.room_light(root,lamp,Color("ffd07d"),.92,4.0)
   else:boxes.add(lamp,Vector3(.32,.38,.32),Geo.mat("94d4ee",0.0,.60))
 var lip=Vector3(last.x,Route.trail_height(last.y+1.3),last.y+1.3)
 var mouth=tunnel(root,lip,1.0,Vector2(2.55,4.74),4.1,Color("677f94"),false,MOUNTAIN_CUT)
 mouth.name="SnowMountainMouth"
 var collar=mouth.get_node("StoneCollar")
 var frost:ShaderMaterial=collar.material_override.duplicate()
 frost.set_shader_parameter("snow_cover",.71)
 collar.material_override=frost
 var rim=SurfaceTool.new()
 rim.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(1,MOUNTAIN_CUT.size()-1):
  var p:Vector2=MOUNTAIN_CUT[i]
  var x=p.x*2.55
  var y=p.y*4.74+.10
  var height=.25+.19*(1.0+sin(i*2.7))
  var z=.10+.16*sin(i*2.43)
  ice_blade(rim,Vector3(x,y,z),-height,Vector2(.08,.13),Vector2(-.045*x,.08),i*5)
 finish(mouth,rim,Geo.mat("c6e3eb",.14,.09),"SnowMountainRimIce")
 var shoulders=SurfaceTool.new()
 shoulders.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  Crags.ridge(shoulders,Vector3(side*4.88,-.39,-1.65),Vector2(3.94,5.58),4.08 if side<0 else 3.44,11+side,true,.43)
 Crags.ridge(shoulders,Vector3(.39,5.01,-1.67),Vector2(6.16,3.08),1.34,19,false)
 finish(mouth,shoulders,frost,"SnowMountainMouthShoulders")

static func trail_snow(snow:ShaderMaterial)->ShaderMaterial:
 if tread_texture==null:
  var size_=Vector2i(160,128)
  var mask=Image.create_empty(size_.x,size_.y,false,Image.FORMAT_RGB8)
  for row in size_.y:
   for col in size_.x:
    var at=Route.ORIGIN-Vector2.ONE*1.5+(Vector2(col,row)+Vector2.ONE*.5)/Vector2(size_)*Vector2(Route.SIZE)*3.0
    var distance:=INF
    for i in TRAIL_TREAD.size()-1:
     distance=minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,TRAIL_TREAD[i],TRAIL_TREAD[i+1])))
    var feather=.27*sin(at.x*1.44+at.y*.63)+.22*cos(at.x*.68-at.y*1.25)
    var ink=lerpf(.50,.88,smoothstep(.88,3.05,distance+feather))
    mask.set_pixel(col,row,Color(ink,ink,ink))
  tread_texture=ImageTexture.create_from_image(mask)
 var surface:ShaderMaterial=snow.duplicate()
 surface.set_shader_parameter("carved_detail",true)
 surface.set_shader_parameter("detail_texture",tread_texture)
 return surface

static func trail_basin_height(at:Vector2)->float:
 return Route.trail_height(at.y)-5.1-.034*absf(at.x)+1.1*sin(at.x*.23+at.y*.095)

static func trail_groves(root:Node3D,walk:PackedByteArray):
 var trees=[]
 for center:Vector2 in [Vector2(-13,32),Vector2(15,29),Vector2(-22,11),Vector2(3,10),
  Vector2(-20,-4),Vector2(25,-11),Vector2(4,-15),Vector2(-15,-24),Vector2(10,-33)]:
  for i in 3:
   var at=center+[Vector2.ZERO,Vector2(-2.3,2.6),Vector2(2.8,-2.8)][i]
   var cell=Vector2i(((at-Route.ORIGIN)/3.0).round())
   if open_cell(walk,cell):continue
   var size_=[1.43,.86,.52][i]
   var pose=Basis(Vector3.UP,center.x*.43+i*.92).scaled(Vector3.ONE*size_)
   trees.append(Transform3D(pose,Vector3(at.x,trail_basin_height(at)-.56,at.y)))
 snowy_grove(root,trees,10085,"SnowMountainTrailGrove")

static func alpine_cliffs(root:Node3D,snow:Material):
 var faces=SurfaceTool.new()
 var shelves=SurfaceTool.new()
 faces.begin(Mesh.PRIMITIVE_TRIANGLES)
 shelves.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  var last=PackedVector3Array()
  for i in 15:
   var z=43.0-i*6.2
   var grade=Route.trail_height(z)
   var setback=22.9+sin(i*.71+side)*1.65+cos(i*1.73)*.96
   var taper=maxf(.12,smoothstep(0.0,2.0,float(i))*smoothstep(0.0,1.65,14.0-i))
   var relief=(.81+.22*sin(i*.58+side)+.14*cos(i*1.58))*taper
   var column=PackedVector3Array()
   for band in CLIFF_SECTION.size():
    var profile:Vector2=CLIFF_SECTION[band]
    var fissure=sin(i*.86+band*1.17+side)*.83+sin(i*1.97+band*.59)*.62
    var x=(setback+profile.x+fissure*taper)*side
    var y=grade+profile.y*relief+(.78*cos(i*1.33+band*.81)-.33*sin(i*2.37-band))*taper-2.6*(1.0-taper)
    column.append(Vector3(x,y,z+.72*sin(i*1.14+band*1.25)))
   if not last.is_empty():
    for band in CLIFF_SECTION.size()-1:
     var dust=band in [1,3,5,7] and sin(i*.64+band*1.57+side*.38)>-.22
     var mesh=shelves if dust else faces
     if side>0:Crags.face(mesh,last[band],column[band],column[band+1],last[band+1])
     else:Crags.face(mesh,column[band],last[band],last[band+1],column[band+1])
   last=column
 var stone=Fort.material(Color("61768c"),false).duplicate()
 stone.set_shader_parameter("snow_cover",.47)
 finish(root,faces,stone,"SnowMountainCliffFaces")
 finish(root,shelves,snow,"SnowMountainCornices")

static func ice(root:Node3D,id:int):
 var stage=Route.LEVELS.keys().find(id)
 var crystal=CylinderMesh.new()
 crystal.top_radius=.16
 crystal.bottom_radius=.74
 crystal.radial_segments=5
 crystal.rings=0
 var body=Geo.mat("91cbdd",.11,.10)
 var light=Geo.mat("c2eff7",.12,.15)
 for cell:Vector2i in ICE_SPOTS[id]:
  var at=Route.point(cell)
  for i in 4:
   var height=3.0+i*.93+stage*.75
   var node=Geo.mesh(root,crystal,Vector3(at.x+cos(i*2.4)*1.26,height*.5,at.y+sin(i*2.4)*1.26),light if i==3 else body)
   node.scale.y=height
   node.rotation=Vector3(sin(i*2.4)*.21,i,cos(i*2.4)*.21)
   node.name="FrostpassIce"

static func mountain_ice(root:Node3D,id:int,walk:PackedByteArray,lots:Array)->PackedVector4Array:
 var mass=SurfaceTool.new()
 var tips=SurfaceTool.new()
 mass.begin(Mesh.PRIMITIVE_TRIANGLES)
 tips.begin(Mesh.PRIMITIVE_TRIANGLES)
 var deep=id==Route.ICE_VAULT
 var stage=Route.LEVELS.keys().find(id)
 var pools=PackedVector4Array()
 for n in lots.size():
  var lot:Rect2i=lots[n]
  var span=Vector2(lot.size)*3.0
  var center=Route.point(lot.position)+span*.5-Vector2.ONE*1.5
  var base=Vector3(center.x,3.39,center.y)
  var width=Vector2(minf(2.65,span.x*.25),minf(2.15,span.y*.23))
  var top=8.15+(1.05 if n==0 and deep else 0.0)-.82*n
  var axis=Vector2(.74,.44) if deep else Vector2(-1.52,.83)
  var spine=width*Vector2(.82,.72 if deep else .47)
  ice_blade(mass,base,top,spine,axis.rotated(n*.55),n*6+id,.44 if deep else .18)
  for i in 6:
   var spread=Vector2.from_angle(i*1.02+n*.76+(i%2)*.19)
   var size=width*(.39+.11*sin(i*2.4+n))
   var part=spread*width*(.77+(i%3)*.22)
   var foot=base+Vector3(part.x,.94+(i%3)*.34,part.y)
   var height=top*(.43+(i%3)*.15)
   var cap=.30 if deep else .15 if i%3==1 else 0.0
   ice_blade(tips if i%3==1 else mass,foot,height,size,spread*(1.0 if deep else 1.43)+axis*.30,n*13+i*7,cap)
   var chip=base+Vector3(part.x*1.39,1.67,part.y*1.39)
   ice_blade(tips,chip,height*.43,size*.68,spread*.64,n*18+i*3)
  var lamp_at=base+Vector3(.48,2.2,2.65)
  var cast_direction=Vector2.DOWN
  for direction:Vector2i in [Vector2i.LEFT,Vector2i.DOWN]:
   var boundary=center+Vector2(direction)*span*.5
   var nearby=Vector2i(((boundary+Vector2(direction)*1.5-Route.ORIGIN)/3.0).round())
   if not open_cell(walk,nearby):continue
   var ledge=wall_column(boundary,stage,walk)[4]
   cast_direction=Vector2(direction)
   lamp_at=ledge+Vector3(direction.x*.96,1.54,direction.y*.96)
   for i in 3:
    var along=Vector2(direction.y,-direction.x)*(i-.92)*.64
    var shard=ledge+Vector3(along.x,-.40-.13*i,along.y)
    var lean=Vector2(direction)*(.25+.12*i)+along*.52
    ice_blade(tips if i==0 else mass,shard,1.55+.46*i,Vector2(.35,.42),lean,n*17+i,.27 if i!=1 else 0.0)
  pools.append(Vector4(lamp_at.x,lamp_at.z,cast_direction.x,cast_direction.y))
  var fill=Rooms.room_light(root,lamp_at,Color("9eacff" if deep else "84dfff"),1.55,12.0)
  fill.name="SnowMountainCrystalLight%d"%n
 var body=Geo.mat("8076cc" if deep else "528fb7",.10,.06).duplicate()
 body.roughness=.37
 var edges=Geo.mat("bbc5ff" if deep else "a8eaf5",.05,.12).duplicate()
 edges.roughness=.29
 finish(root,mass,body,"SnowMountainIceMass")
 finish(root,tips,edges,"SnowMountainIceTips")
 return pools

static func ice_blade(tool:SurfaceTool,p:Vector3,height:float,width:Vector2,lean:Vector2,serial:int,cap:float=0.0):
 tool.set_smooth_group(-1)
 var rings:Array[PackedVector3Array]=[]
 var turn=serial*.743
 for stage in (4 if cap>0.0 else 3):
  var progress:float=[.0,.24,.75,.98][stage]
  var taper:float=[.86,1.0,.57,cap][stage]
  var ring=PackedVector3Array()
  for i in 6:
   var angle=turn+float(i)*TAU/6.0
   var radial=Vector2(cos(angle),sin(angle))*width*taper*(1.0+.085*sin(i*2.38+serial))
   var at=radial+lean*progress
   var bevel=.045*sin(i*1.7+serial)*float(stage) if stage<3 else .036*cos(angle-turn)
   ring.append(p+Vector3(at.x,height*(progress+bevel),at.y))
  rings.append(ring)
 var point=p+Vector3(lean.x,height,lean.y)
 for i in 6:
  var next=(i+1)%6
  for band in rings.size()-1:
   var lower=rings[band]
   var upper=rings[band+1]
   if height>0.0:Crags.face(tool,lower[i],lower[next],upper[next],upper[i])
   else:Crags.face(tool,lower[next],lower[i],upper[i],upper[next])
  var crown=rings[-1]
  for corner:Vector3 in ([crown[i],crown[next],point] if height>0.0 else [crown[next],crown[i],point]):
   tool.add_vertex(corner)

static func tunnel(root:Node3D,at:Vector3,front:float,opening:Vector2,depth:float,color:Color,cut_stone:bool,profile:Array=TUNNEL_CUT)->Node3D:
 var holder=Node3D.new()
 holder.position=at
 holder.rotation.y=PI if front<0.0 else 0.0
 root.add_child(holder)
 var rim=SurfaceTool.new()
 var jamb=SurfaceTool.new()
 var dark=SurfaceTool.new()
 for surface in [rim,jamb,dark]:
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  surface.set_smooth_group(-1)
 var edge=PackedVector3Array()
 var collar=PackedVector3Array()
 var back=PackedVector3Array()
 for i in profile.size():
  var p:Vector2=profile[i]
  var uneven=0.0 if cut_stone else .16*sin(i*2.43)
  edge.append(Vector3(p.x*opening.x,p.y*opening.y,uneven))
  collar.append(Vector3(p.x*(opening.x+.84),p.y*(opening.y+.76)+absf(p.y)*uneven,-.46+uneven))
  back.append(Vector3(p.x*opening.x*.88,p.y*opening.y*.91,-depth+uneven))
 for i in edge.size()-1:
  var a=edge[i]
  var b=edge[i+1]
  var c=collar[i]
  var d=collar[i+1]
  var joint=.022 if cut_stone else 0.0
  Crags.face(rim,c.lerp(d,joint),d.lerp(c,joint),b.lerp(a,joint),a.lerp(b,joint))
  var c_back=Vector3(c.x*.97,c.y*.97,-depth)
  var d_back=Vector3(d.x*.97,d.y*.97,-depth)
  Crags.face(rim,d,c,c_back,d_back)
  Crags.face(rim,d_back,c_back,back[i],back[i+1])
  Crags.face(jamb,a,b,back[i+1],back[i])
  for p in [back[i],back[i+1],Vector3(0,opening.y*.44,-depth-.02)]:dark.add_vertex(p)
 for p in [back[-1],back[0],Vector3(0,opening.y*.44,-depth-.02)]:dark.add_vertex(p)
 finish(holder,rim,Fort.material(color,false),"StoneCollar")
 finish(holder,jamb,Fort.material(color.darkened(.36),false),"TunnelReveal")
 var shadow=Geo.mat("152330").duplicate()
 shadow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 shadow.cull_mode=BaseMaterial3D.CULL_DISABLED
 finish(holder,dark,shadow,"TunnelShade")
 return holder

static func cave_entry(root:Node3D,boxes,at:Vector2,id:int,side:int):
 var toward_arrival=signf(Route.ARRIVALS[id][side].y-Route.DOORS[id][side].y)
 var stage=Route.LEVELS.keys().find(id)
 var opening=Vector2(2.26+stage*.14,3.60+stage*.23)
 var between_floors=id==Route.ICE_VAULT or (id==Route.SNOW_CAVE and side==1)
 var lip=Vector3(at.x,0,at.y+toward_arrival*(2.05 if between_floors else 1.35))
 var frame=tunnel(root,lip,toward_arrival,opening,FROZEN_PASSAGE_DEPTH if between_floors else 2.7,
  CAVE_COLORS[stage].lightened(.24),stage!=2 and not between_floors,MOUNTAIN_CUT if between_floors else TUNNEL_CUT)
 frame.name="FrostpassPassage%d"%side
 if id in Route.SNOW_FLOORS:snow_passage_treads(frame,id)
 if between_floors:
  frost_passage(frame,opening,id,boxes)
  return
 var stone=Fort.material(CAVE_COLORS[stage].lightened(.18),true)
 var trim=Fort.material(Color("aec7ce"),false)
 var iron=Geo.mat("414d59",.18)
 var glow=Geo.mat("f9bb73",0.0,.6) if stage==0 else Geo.mat("83d5ee",0.0,.56)
 for direction in [-1,1]:
  var post=lip+Vector3(direction*(opening.x+.49),0,-toward_arrival*.35)
  boxes.add(post+Vector3.UP*.29,Vector3(1.05,.58,1.04),stone)
  boxes.add(post+Vector3.UP*.62,Vector3(.88,.13,.88),trim)
  var fixture=post+Vector3(0,1.64,toward_arrival*.62)
  boxes.add(fixture,Vector3(.30,.47,.26),glow)
  for y in [-.25,.25]:
   boxes.add(fixture+Vector3.UP*y,Vector3(.44,.085,.39),iron)
  for x in [-.18,.18]:
   boxes.add(fixture+Vector3(x,0,toward_arrival*.13),Vector3(.05,.50,.05),iron)
 for row in 3:
  var z=lip.z+toward_arrival*(.64+row*.62)
  boxes.add(Vector3(at.x,.005+row*-.018,z),Vector3(4.10-row*.25,.09,.58),trim if row==0 else stone)

static func snow_passage_treads(frame:Node3D,id:int):
 Lamps.prepare_primitives()
 var treads=SurfaceTool.new()
 var frost=SurfaceTool.new()
 treads.begin(Mesh.PRIMITIVE_TRIANGLES)
 frost.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in 3:
  var z=2.43+row*.56
  var width=3.78-row*.22
  var height=.14-row*.032
  Lamps.block(treads,Vector3(0,height*.5,z),Vector3(width,height,.53))
  Lamps.block(frost,Vector3(0,height,z+.20),Vector3(width-.07,.021,.092))
 Geo.mesh(frame,treads.commit(),Vector3.ZERO,Geo.mat("769ebc" if id==Route.SNOW_CAVE else "8795c3",.05)).name="SnowMountainLandingTreads"
 Geo.mesh(frame,frost.commit(),Vector3.ZERO,Geo.mat("c1e5ed",0.0,.08)).name="SnowMountainLandingFrost"

static func frost_passage(frame:Node3D,opening:Vector2,id:int,boxes):
 var deep=id==Route.ICE_VAULT
 var glaze=ice_surface(id,true)
 frame.get_node("StoneCollar").material_override=glaze
 frame.get_node("TunnelReveal").material_override=Fort.material(Color("4d5275" if deep else "436571"),false)
 passage_lining(frame,opening,deep)
 var shade=ShaderMaterial.new()
 shade.shader=PASSAGE_SHADOW
 shade.set_shader_parameter("ice_glimmer",Color("343955" if deep else "254452"))
 frame.get_node("TunnelShade").material_override=shade
 var ribs=SurfaceTool.new()
 ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
 ribs.set_smooth_group(-1)
 for depth in [.39,.75]:
  for i in MOUNTAIN_CUT.size()-1:
   var a=passage_section(i,i+1,.02,opening,depth)
   var b=passage_section(i+1,i,.02,opening,depth)
   var inside_a=Vector3(a.x*.90,a.y*.94,a.z+.04)
   var inside_b=Vector3(b.x*.90,b.y*.94,b.z+.04)
   Crags.face(ribs,a,b,inside_b,inside_a)
   var back_a=inside_a-Vector3.BACK*.22
   var back_b=inside_b-Vector3.BACK*.22
   Crags.face(ribs,inside_a,inside_b,back_b,back_a)
 finish(frame,ribs,Fort.material(Color("767d9b" if deep else "678b96"),false),"FrozenPassageInnerStone")
 var cascade=SurfaceTool.new()
 cascade.begin(Mesh.PRIMITIVE_TRIANGLES)
 var molding=SurfaceTool.new()
 molding.begin(Mesh.PRIMITIVE_TRIANGLES)
 molding.set_smooth_group(-1)
 var inner=PackedVector3Array()
 var outer=PackedVector3Array()
 for i in MOUNTAIN_CUT.size():
  var p:Vector2=MOUNTAIN_CUT[i]
  var uneven=.16*sin(i*2.43)
  inner.append(Vector3(p.x*(opening.x+.29),p.y*(opening.y+.28),uneven-.107))
  outer.append(Vector3(p.x*(opening.x+.49),p.y*(opening.y+.47),uneven-.21))
 for i in inner.size()-1:
  var a=inner[i].lerp(inner[i+1],.025)
  var b=inner[i+1].lerp(inner[i],.025)
  var c=outer[i].lerp(outer[i+1],.025)
  var d=outer[i+1].lerp(outer[i],.025)
  var bevel_a=a.lerp(c,.36)+Vector3.BACK*.12
  var bevel_b=b.lerp(d,.36)+Vector3.BACK*.12
  Crags.face(molding,c,d,bevel_b,bevel_a)
  Crags.face(molding,bevel_a,bevel_b,b,a)
 finish(frame,molding,Fort.material(Color("aeb9db" if deep else "a1cad6"),false),"FrozenPassageMolding")
 for section in range(2,6):
  for i in 2:
   var progress=.18+i*.55
   var rim:Vector2=MOUNTAIN_CUT[section].lerp(MOUNTAIN_CUT[section+1],progress)*opening
   var uneven=lerpf(sin(section*2.43),sin((section+1)*2.43),progress)*.16
   var length=minf(.43+.34*absf(sin(section*4.7+i*2.8)),rim.y-2.65)
   ice_blade(cascade,Vector3(rim.x,rim.y+.09,uneven-.14),-length,Vector2(.15,.17),Vector2(.06,.05),section*2+i)
 for side in [-1,1]:
  for i in 3:
   var at=Vector3(side*(opening.x+.34+i*.30),-.05,-.21+i*.26)
   ice_blade(cascade,at,1.78-i*.40,Vector2(.31,.48),Vector2(side*.30,-.11),i+side)
 finish(frame,cascade,Geo.mat("bccef0" if deep else "b2dfe9",.22,.13),"FrozenPassageIcicles")
 var cage=SurfaceTool.new()
 var glass=SurfaceTool.new()
 cage.begin(Mesh.PRIMITIVE_TRIANGLES)
 glass.begin(Mesh.PRIMITIVE_TRIANGLES)
 Lamps.prepare_primitives()
 for side in [-1,1]:
  var socket=Vector3(side*(opening.x+.54),1.98,-.26)
  var lantern=socket+Vector3(0,-.11,.61)
  Lamps.rod(cage,socket,lantern,.075)
  Lamps.lantern(cage,glass,lantern,true)
  var slant=frame.transform*Vector3(side*(opening.x+.52),.32,.36)
  boxes.add(slant,Vector3(.81,.68,.93),Fort.material(Color("6d7fa8" if deep else "688d9f"),false))
 Geo.mesh(frame,cage.commit(),Vector3.ZERO,Geo.mat("364f66",.35)).name="FrozenPassageLanternBrackets"
 Geo.mesh(frame,glass.commit(),Vector3.ZERO,Geo.mat("bcdcf9",.0,.65)).name="FrozenPassageLanternGlass"
 Rooms.room_light(frame,Vector3(0,2.25,1.27),Color("c2e4ff"),.87,7.6).name="FrozenPassageLight"
 Rooms.room_light(frame,Vector3(0,1.08,-2.06),Color("a8bcff" if deep else "8bd8f1"),.52,4.6).name="FrozenPassageRecessLight"
 var tread=Fort.material(Color("8384ab" if deep else "769da9"),false)
 var rim_stone=Fort.material(Color("b1c7e3" if deep else "a0c7d3"),false)
 for row in range(-7,3):
  var z=row*.63+.40
  var joint=.53*sin(row*2.37)
  for side in [-1,1]:
   var width=1.77+side*joint
   var center=frame.transform*Vector3(-joint+side*width*.5,.018,z)
   boxes.add(center,Vector3(width-.035,.14,.59),tread)
 for side in [-1,1]:
  for z in [-3.24,-2.10,-.92,.61,1.90]:
   boxes.add(frame.transform*Vector3(side*1.91,.032,z),Vector3(.22,.17,1.16),rim_stone)

static func passage_section(from:int,to:int,join:float,opening:Vector2,depth:float)->Vector3:
 var p:Vector2=MOUNTAIN_CUT[from].lerp(MOUNTAIN_CUT[to],join)*opening
 var uneven=.16*lerpf(sin(from*2.43),sin(to*2.43),join)
 return Vector3(p.x*(1.0-.12*depth),p.y*(1.0-.09*depth),uneven-FROZEN_PASSAGE_DEPTH*depth)

static func passage_lining(frame:Node3D,opening:Vector2,deep:bool):
 var stone=SurfaceTool.new()
 stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 stone.set_smooth_group(-1)
 var frost=SurfaceTool.new()
 frost.begin(Mesh.PRIMITIVE_TRIANGLES)
 frost.set_smooth_group(-1)
 for section in MOUNTAIN_CUT.size()-1:
  for course in 6:
   var start=.093+course*.148
   var end=start+.142
   var joint=.50+.16*sin(section*3.21+course*2.42)
   for span:Vector2 in [Vector2(.006,joint-.011),Vector2(joint+.011,.994)]:
    var a=passage_section(section,section+1,span.x,opening,start)
    var b=passage_section(section,section+1,span.y,opening,start)
    var c=passage_section(section,section+1,span.y,opening,end)
    var d=passage_section(section,section+1,span.x,opening,end)
    var center=(a+b+c+d)*.25
    var bevel=Vector3(.977,.979,1.0)
    var inset_a=a.lerp(center,.077)*bevel
    var inset_b=b.lerp(center,.077)*bevel
    var inset_c=c.lerp(center,.077)*bevel
    var inset_d=d.lerp(center,.077)*bevel
    Crags.face(stone,inset_a,inset_b,inset_c,inset_d)
    Crags.face(stone,a,b,inset_b,inset_a)
    Crags.face(stone,b,c,inset_c,inset_b)
    Crags.face(stone,c,d,inset_d,inset_c)
    Crags.face(stone,d,a,inset_a,inset_d)
    var grain=sin(section*12.7+course*5.71+span.x*9.5)
    if course>0 and grain>-.42:
     var coat=Vector3(.994,.994,1.0)
     var lip_a=inset_a.lerp(inset_b,.10+.08*grain)*coat
     var lip_b=inset_b.lerp(inset_a,.19-.07*grain)*coat
     var tip_a=lip_a.lerp(inset_d*coat,.20+.13*grain)
     var tip_b=lip_b.lerp(inset_c*coat,.08+.07*grain)
     var seam=lip_a.lerp(lip_b,.54)
     var tip=seam.lerp(center*coat,.34+.12*grain)
     Crags.face(frost,lip_a,seam,tip,tip_a)
     Crags.face(frost,seam,lip_b,tip_b,tip)
 var lining=Fort.material(Color("586087" if deep else "507685"),false).duplicate()
 lining.set_shader_parameter("snow_cover",.37)
 finish(frame,stone,lining,"FrozenPassageWallLining")
 var glaze=ice_surface(Route.ICE_VAULT if deep else Route.SNOW_CAVE,true)
 glaze.set_shader_parameter("ice_color",Color("969fc9" if deep else "90beca"))
 finish(frame,frost,glaze,"FrozenPassageFrost")

static func arch(root:Node3D,boxes,at:Vector2,id:int,side:int):
 var stone=Fort.material(Color("71808c"),true)
 var trim=Fort.material(Color("b7cad0"),false)
 var timber=Fort.material(Color("634639"),false)
 var beam=timber if id==51004 else stone
 var back_direction=(Route.DOORS[id][side]-Route.ARRIVALS[id][side]).sign()
 var z=at.y+float(back_direction.y)*.8
 var glow=Geo.mat("ffbc69",0.0,.8)
 for x in [-2.1,2.1]:
  boxes.add(Vector3(at.x+x,1.65,z),Vector3(.68,3.3,1.16),beam)
  boxes.add(Vector3(at.x+x,.22,z),Vector3(1.0,.44,1.48),trim)
  boxes.add(Vector3(at.x+x,2.35,z-.65*back_direction.y),Vector3(.26,.60,.25),glow)
 boxes.add(Vector3(at.x,3.50,z),Vector3(5.0,.67,1.36),beam)
 boxes.add(Vector3(at.x,3.90,z),Vector3(5.35,.2,1.53),trim)
 boxes.add(Vector3(at.x,.04,z),Vector3(3.65,.08,2.2),trim)
 if id==51004:
  var roof=PackedVector2Array([Vector2(-2.80,0),Vector2(2.80,0),Vector2(0,1.03)])
  Geo.mesh(root,Shapes.extrude(roof,1.86),Vector3(at.x,3.93,z),timber)
  var snow=PackedVector2Array([Vector2(-2.94,0),Vector2(0,1.28),Vector2(2.94,0),Vector2(2.65,0),Vector2(0,1.06),Vector2(-2.65,0)])
  Geo.mesh(root,Shapes.extrude(snow,2.02),Vector3(at.x,3.95,z),Fort.material(Color("e0eef0"),false))

static func mountains(root:Node3D,id:int):
 var rock=SurfaceTool.new()
 rock.begin(Mesh.PRIMITIVE_TRIANGLES)
 var trees=[]
 var watch=id==51005
 var floor_height=-8.25 if id==Route.ROOF_GARDEN else 0.0
 if id==Route.ROOF_GARDEN:
  Geo.box(root,Vector3(0,floor_height-.26,-9),Vector3(155,.45,132),Fort.material(Color("dce8ee"),false))
 for i in 11:
  var x=-62.0+i*12.1
  var z=-46.0-6.0*cos(i*.65)-(5.0 if watch else 0.0)
  var high=10.0+sin(i*1.83)*4.0+(7.0*exp(-pow((i-7.0)*.48,2.0)) if watch else 4.0*exp(-pow((i-2.0)*.62,2.0)))
  Crags.ridge(rock,Vector3(x,floor_height-.5,z),Vector2(23,21),high,i+id,true,.54)
  var gap=sin(i*2.2)*2.6
  trees.append(Transform3D(Basis(Vector3.UP,i*.91).scaled(Vector3.ONE*(.63+i%4*.12)),Vector3(x+gap,floor_height,z+13.0)))
  if i%2==0:
   for side in [-1,1]:
    trees.append(Transform3D(Basis(Vector3.UP,i*.68).scaled(Vector3.ONE*(.74+i%3*.15)),Vector3((49.0+gap)*side,floor_height,-29+i*5.4)))
 var cliff=Fort.material(Color("6c839a") if watch else Color("8397aa"),false).duplicate()
 cliff.set_shader_parameter("snow_cover",.75)
 finish(root,rock,cliff,"SnowyPalisadeCliffs")
 snowy_grove(root,trees)

static func snowy_grove(root:Node3D,trees:Array,serial:int=10070,grove_name:String="",tint:Color=Color.TRANSPARENT):
 var woodland=serial!=10070
 var grove=Node3D.new()
 grove.name=grove_name if not grove_name.is_empty() else "SnowMountainLowerTrees" if serial==10088 else "SnowMountainWoodland" if woodland else "SnowyEvergreens"
 root.add_child(grove)
 Meadow.batch(grove,Meadow.crossgate_tree(serial),trees,true,0.0,tint if tint.a>0.0 else Color("99a382" if woodland else "91aab2"))
 var snowy:ShaderMaterial
 for part in grove.get_children():
  if tint.a>0.0 and part.get_meta("crossgate_tree_part","")=="Body":
   var bark:StandardMaterial3D=part.multimesh.mesh.surface_get_material(0).duplicate()
   bark.albedo_color*=Color("9da4b1")
   part.material_override=bark
  if part.get_meta("crossgate_tree_part","")!="Canopy":continue
  if snowy==null:
   snowy=part.material_override.duplicate()
   snowy.set_shader_parameter("snow_amount",.72 if woodland else .38)
   if woodland:snowy.set_shader_parameter("snow_breakup",.78)
   if tint.a>0.0:snowy.set_shader_parameter("snow_breakup",.94)
  part.material_override=snowy

static func town_details(root:Node3D,boxes,id:int,snow:Material):
 var watch=id==51005
 var bounds:Rect2i=Route.ROOMS[id][0]
 var lanterns=[]
 for cell in [Vector2i(bounds.position.x-1,18),Vector2i(bounds.end.x,9),Vector2i(17,1)]:
  var at=Route.point(cell)
  lanterns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.8,.69,.8)),Vector3(at.x,0,at.y)))
 Lamps.batch(root,10429,lanterns)
 var bank=SurfaceTool.new()
 bank.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(bounds.position.y+1,bounds.end.y,2):
  for side in [-1,1]:
   var edge=bounds.position.x-1 if side<0 else bounds.end.x
   var at=Route.point(Vector2i(edge,row))
   Crags.ridge(bank,Vector3(at.x,-.18,at.y),Vector2(3.9,8.1),.75+sin(row*1.3)*.23,row*side,false)
 finish(root,bank,snow,"TownSnowbanks")
 var trim=Fort.material(Color("8b9ba9") if watch else Color("654837"),watch)
 for i in 8:
  var at=Route.point(Vector2i((18 if watch else 4)+i,1))
  var height=1.48 if watch else .95
  boxes.add(Vector3(at.x,height*.5,at.y),Vector3(.48,height,.56),trim)
  boxes.add(Vector3(at.x,height,at.y),Vector3(.70,.18,.70),snow)
  if i>0:
   boxes.add(Vector3(at.x-1.5,height*.52,at.y),Vector3(2.95,.17 if not watch else .78,.27 if not watch else .70),trim)

static func house(root:Node3D,boxes,lot:Rect2i,index:int,id:int):
 var at=Route.point(lot.position)+Vector2(lot.size-Vector2i.ONE)*1.5
 var market=id==51004 and index==Route.MAIN_LOT
 var lodge=id in [51005,Route.ABANIS] and index==Route.MAIN_LOT
 var campus=id==Route.UNIVERSITY
 var academy=campus and index==Route.MAIN_LOT
 var glasshouse=campus and index==1
 var hospital=id==Route.ABANIS and Route.VILLAGE_ROOMS.get(index)==Route.ABANIS_HOSPITAL
 var auditorium=campus and Route.CAMPUS_ROOMS.get(index)==Route.AUDITORIUM
 var width=lot.size.x*3.0-.5
 var depth=lot.size.y*3.0-(3.35 if market else 1.85 if lodge else .5)
 var high=5.6 if academy else 5.05 if auditorium else 3.9 if hospital else 3.2+index%3*.55
 var peak=3.2 if hospital or auditorium else 2.8+index%3*.8
 var x=at.x
 var z=at.y
 var front=z+depth*.5
 var timber=Fort.material(Color("593b31"),false)
 var roof_tint=Color("729897") if glasshouse else Color("405e72") if campus else Color("435661") if id==51005 else Color("615355")
 if id==Route.ABANIS:roof_tint=Color(["634e47","485b5d","5b4441"][index%3])
 if hospital:roof_tint=Color("415969")
 var roof=Fort.material(roof_tint,true)
 var snow=Fort.material(Color("e0eef0"),false)
 var stone=Fort.material(Color("7c8586"),true)
 var plaster=Color(["b79773","b8a993","a18369"][index%3]) if id==Route.ABANIS else Color("bb996d") if index%2==0 else Color("977d61")
 var wall=Fort.material(Color("a3a797"),true) if hospital else stone if lodge or campus else Fort.material(plaster,false)
 boxes.add(Vector3(x,.34,z),Vector3(width,.68,depth),stone)
 boxes.add(Vector3(x,high*.5+.3,z),Vector3(width-.18,high,depth-.12),wall)
 for side in [-1,1]:
  boxes.add(Vector3(x+side*(width*.5-.23),high*.5+.27,z),Vector3(.35,high,.19+depth),timber)
  var bay=x+side*width*.27
  boxes.add(Vector3(bay,2.2,front),Vector3(1.38,1.48,.16),timber)
  boxes.add(Vector3(bay,2.2,front+.10),Vector3(1.05,1.12,.08),Geo.mat("e8ad68",0.0,.53))
  boxes.add(Vector3(bay,2.2,front+.17),Vector3(.09,1.10,.09),timber)
  boxes.add(Vector3(bay,2.2,front+.17),Vector3(1.0,.08,.09),timber)
  for shutter in [-1,1]:
   boxes.add(Vector3(bay+shutter*.83,2.2,front+.05),Vector3(.45,1.32,.19),roof)
   for rail in [-1,1]:
    boxes.add(Vector3(bay+shutter*.83,2.2+rail*.43,front+.16),Vector3(.46,.11,.08),timber)
  boxes.add(Vector3(bay,1.52,front+.18),Vector3(2.02,.17,.43),timber)
 var door_size=Vector3(2.62,2.99,.20) if lodge else Vector3(1.92,2.63,.20)
 boxes.add(Vector3(x,door_size.y*.5,front),door_size,timber)
 for slat in [-.54,-.27,0.0,.27,.54]:
  boxes.add(Vector3(x+slat,door_size.y*.50,front+.13),Vector3(.05,door_size.y*.91,.06),Geo.mat("845e42"))
 boxes.add(Vector3(x+.49,1.27,front+.17),Vector3(.15,.12,.075),Geo.mat("c3a46f",.26))
 for side in [-1,1]:
  boxes.add(Vector3(x+side*(door_size.x*.5+.12),door_size.y*.5,front+.12),Vector3(.24,door_size.y,.31),stone if lodge else timber)
 boxes.add(Vector3(x,door_size.y+.08,front+.11),Vector3(door_size.x+.6,.22,.35),stone if lodge else timber)
 boxes.add(Vector3(x,.17,front+.50),Vector3(2.52,.32,.96),stone)
 boxes.add(Vector3(x,high+.17,front),Vector3(width,.30,.21),timber)
 for side in [-1,1]:
  var face=x+side*width*.5
  boxes.add(Vector3(face,high+.05,z),Vector3(.21,.26,depth),timber)
  boxes.add(Vector3(face,1.02,z),Vector3(.24,.23,depth),timber)
  for brace in [-1,0,1]:
   boxes.add(Vector3(face,high*.52,z+brace*depth*.29),Vector3(.23,high*.8,.24),timber)
 var half=width*.5+(.96 if market else .66)
 var base=Vector3(x,high+.27,z)
 house_roof(root,base,half,depth,peak,roof,snow,3 if academy else 2 if lodge or auditorium or (id==51005 and index%2==0) else 1 if market or hospital or index%3==0 else 0)
 if academy:academy_terrace(root,boxes,base+Vector3.UP*(peak+.35),half,depth)
 var loft=Vector3(x,high+.36+peak*.32,z+depth*.51)
 boxes.add(loft,Vector3(1.22,1.24,.20),timber)
 boxes.add(loft+Vector3.BACK*.12,Vector3(.83,.83,.09),Geo.mat("e1a366",0.0,.35))
 boxes.add(loft+Vector3.BACK*.18,Vector3(.11,.83,.06),timber)
 boxes.add(Vector3(x+width*.26,high+peak*.8,z-depth*.26),Vector3(.94,2.14,.98),stone)
 boxes.add(Vector3(x+width*.26,high+peak*.8+1.13,z-depth*.26),Vector3(1.2,.22,1.2),snow)
 if lodge:
  var supplies=Node3D.new()
  supplies.name="RidgewatchHallProps"
  root.add_child(supplies)
  var plank=Fort.material(Color("8e7052"),false)
  Goods.crate(supplies,boxes,Vector3(x-4.4,0,front+.39),.84,true,timber,plank)
  Goods.barrel(supplies,Vector3(x+4.3,0,front+.44),.34,timber,plank,Geo.mat("414d59",.18))
  for side in [-1,1]:
   var pier=x+side*(width*.5-.70)
   boxes.add(Vector3(pier,high*.45,front+.10),Vector3(.62,high*.90,.40),stone)
   boxes.add(Vector3(pier,high*.90,front+.13),Vector3(.86,.34,.51),snow)
   var banner=Vector3(x+side*2.21,high-.77,front+.24)
   boxes.add(banner+Vector3.UP*.57,Vector3(1.04,.11,.18),timber)
   boxes.add(banner,Vector3(.81,1.11,.13),Geo.mat("496781"))
   boxes.add(banner+Vector3(0,-.45,.075),Vector3(.73,.12,.06),Geo.mat("b8bdba"))
  var tower=Vector3(x,high+peak,z-depth*.20)
  boxes.add(tower,Vector3(4.1,6.6,4.2),stone)
  boxes.add(tower+Vector3.UP*3.3,Vector3(4.8,.42,4.86),snow)
  boxes.add(tower+Vector3.UP*3.78,Vector3(4.8,.48,4.86),stone)
  boxes.add(tower+Vector3(0,1.75,2.14),Vector3(1.2,1.8,.15),Geo.mat("edb466",0.0,.46))
  boxes.add(tower+Vector3.UP*4.76,Vector3(.20,1.94,.20),timber)
  boxes.add(tower+Vector3(.60,5.38,0),Vector3(1.30,.65,.09),Geo.mat("78474a"))
 elif market:
  boxes.add(Vector3(x,.081,front+.86),Vector3(width-.35,.16,1.72),stone)
  storefront(root,boxes,Vector3(x,0,front),timber)
 if academy or glasshouse:
  academy_facade(root,boxes,Vector3(x,0,front),width,high,glasshouse)
 if campus and index in [0,1]:
  signpost(root,Vector3(x+2.75,1.95,front+.70),"技術室" if index==0 else "溫室")
 if hospital or auditorium:
  civic_entry(root,boxes,Vector3(x,0,front),high,hospital)
 if id==Route.ABANIS:
  abanis_facade(root,boxes,Vector3(x,0,front),width,high,peak,index,roof,snow)

static func civic_entry(root:Node3D,boxes,at:Vector3,high:float,hospital:bool):
 var entrance=Node3D.new()
 entrance.name="AbanisHospitalFacade" if hospital else "UniversityAuditoriumFacade"
 root.add_child(entrance)
 var frame=Fort.material(Color("b2b6aa"),false)
 var bronze=Geo.mat("6b5645",.15)
 var blue=Geo.mat("567d8b")
 for side in [-1,1]:
  var column=at+Vector3(side*1.45,1.49,.20)
  boxes.add(column,Vector3(.26,2.96,.38),frame)
  boxes.add(column+Vector3.UP*1.48,Vector3(.44,.18,.56),frame)
  Rooms.wall_lantern(entrance,at+Vector3(side*2.08,2.52,.30))
 var seal=at+Vector3(0,high+.62,.23)
 Geo.cylinder(entrance,seal,.56,.18,frame).rotation.x=PI*.5
 Geo.cylinder(entrance,seal+Vector3.BACK*.108,.42,.08,blue).rotation.x=PI*.5
 Geo.torus(entrance,seal+Vector3.BACK*.178,.29,.37,bronze).rotation.x=PI*.5
 Geo.box(entrance,seal+Vector3.BACK*.211,Vector3(.25,.25,.08),frame).rotation.z=PI*.25
 signpost(entrance,at+Vector3(2.9,1.93,.73),"醫院" if hospital else "禮堂")

static func abanis_facade(root:Node3D,boxes,at:Vector3,width:float,high:float,peak:float,index:int,roof:Material,snow:Material):
 var details=Node3D.new()
 details.name="AbanisHouseDetails%d"%index
 root.add_child(details)
 var timber=Fort.material(Color("583d30"),false)
 var trim=Fort.material(Color(["a87c54","929e92","9a6955"][index%3]),false)
 var stone=Fort.material(Color("90999b"),true)
 var iron=Geo.mat("4b4644",.23)
 var awning=PackedVector2Array([Vector2(-1.95,0),Vector2(0,1.03),Vector2(1.95,0)])
 if index%2==0:
  var eave=at+Vector3(0,2.98,.79)
  Geo.mesh(details,Shapes.extrude(awning,1.64),eave,roof)
  Geo.mesh(details,Shapes.extrude(awning,1.73),eave+Vector3.UP*.15,snow)
  boxes.add(eave+Vector3(0,0,.84),Vector3(3.94,.18,.16),trim)
  for side in [-1,1]:
   Geo.beam(details,at+Vector3(side*1.72,2.92,1.42),at+Vector3(side*1.72,2.01,.16),.17,timber)
 else:
  boxes.add(at+Vector3(0,3.10,.45),Vector3(3.2,.19,1.21),timber)
  boxes.add(at+Vector3(0,3.24,.43),Vector3(3.29,.13,1.20),snow)
  for side in [-1,1]:
   Geo.beam(details,at+Vector3(side*1.48,2.96,1.01),at+Vector3(side*1.48,2.26,.20),.13,timber)
 var gable=at+Vector3(0,high+.39,.70)
 var uprights=width*.24
 for side in [-1,1]:
  Geo.beam(details,gable+Vector3(side*width*.37,-.04,0),gable+Vector3(side*.63,peak*.53,0),.17,timber)
  for post in [1,2]:
   var length=peak*(.46-.12*post)
   boxes.add(gable+Vector3(side*uprights*post*.5,length*.5,-.02),Vector3(.15,length,.16),timber)
  var sill=at+Vector3(side*width*.27,1.59,.34)
  boxes.add(sill,Vector3(1.84,.15,.34),stone)
  boxes.add(sill+Vector3(.17*side,.10,.01),Vector3(1.43,.07,.32),snow)
  var frame=at+Vector3(side*width*.27,2.96,.22)
  boxes.add(frame,Vector3(1.64,.16,.31),trim)
  for shutter in [-1,1]:
   var panel=frame+Vector3(shutter*.83,-.76,-.005)
   boxes.add(panel+Vector3(shutter*.12,0,0),Vector3(.052,1.21,.055),trim)
   for hinge in [-1,1]:
    boxes.add(panel+Vector3(-shutter*.07,hinge*.43,.015),Vector3(.22,.10,.052),iron)
  for y in [1.06,1.38]:
   boxes.add(at+Vector3(side*width*.36,y,.09),Vector3(width*.18,.071,.12),trim)
  var pier=at+Vector3(side*(width*.5-.45),.56,.07)
  for course in 3:
   boxes.add(pier+Vector3(-side*course*.06,course*.32,0),Vector3(.68+.09*(course%2),.266,.26),stone)
 var fastener=Geo.box(details,gable+Vector3(0,peak*.72,-.02),Vector3(.31,.31,.18),trim)
 fastener.rotation.z=PI*.25
 if Route.VILLAGE_ROOMS.get(index)!=Route.ABANIS_HOSPITAL:
  Rooms.wall_lantern(details,at+Vector3(1.70,2.35,.26))

static func academy_facade(root:Node3D,boxes,at:Vector3,width:float,high:float,glasshouse:bool):
 var wing=Node3D.new()
 wing.name="UniversityGlasshouse" if glasshouse else "UniversityObservatory"
 root.add_child(wing)
 var metal=Geo.mat("355664")
 var glass=Geo.mat("9acecf" if glasshouse else "81b9db",.08,.21)
 var stone=Fort.material(Color("adbbbd"),false)
 var snow=Fort.material(Color("e0eef0"),false)
 if glasshouse:
  Geo.beam(wing,at+Vector3(-width*.46,high+.12,.43),at+Vector3(width*.46,high+.12,.43),.14,metal)
  Geo.box(wing,at+Vector3(0,high+.48,.25),Vector3(2.65,.33,.72),glass)
  for i in [-2,-1,1,2]:
   var bay=at+Vector3(i*width*.17,high*.53,.24)
   boxes.add(bay,Vector3(width*.155,high*.73,.12),glass)
   for j in [-1,1]:
    boxes.add(bay+Vector3(j*width*.077,0,.09),Vector3(.13,high*.78,.11),metal)
   boxes.add(bay+Vector3.BACK*.09,Vector3(width*.157,.15,.11),metal)
  boxes.add(at+Vector3(0,2.24,.23),Vector3(1.18,.88,.11),glass)
  boxes.add(at+Vector3(0,2.24,.31),Vector3(.11,.91,.10),metal)
  return
 for side in [-1,1]:
  var buttress=at+Vector3(side*3.65,high*.5,.19)
  boxes.add(buttress,Vector3(.72,high+.21,.62),stone)
  boxes.add(buttress+Vector3.UP*(high*.5+.12),Vector3(1.03,.24,.88),snow)
  for i in [1,2]:
   var window=at+Vector3(side*(4.9+i*2.15),3.37,.22)
   boxes.add(window,Vector3(1.40,2.18,.16),metal)
   boxes.add(window+Vector3.BACK*.10,Vector3(1.06,1.86,.11),glass)
   boxes.add(window+Vector3(0,1.08,.10),Vector3(1.27,.37,.11),stone)
  var banner=at+Vector3(side*2.40,high-.42,.45)
  Rooms.hanging_cloth(wing,banner,Vector2(1.17,2.24),.14,Color("385673"))
 var arch_shape=PackedVector2Array([Vector2(-2.24,0),Vector2(-2.24,.58),Vector2(-1.31,1.03),Vector2(0,1.23),
  Vector2(1.31,1.03),Vector2(2.24,.58),Vector2(2.24,0),Vector2(1.83,0),Vector2(1.83,.38),
  Vector2(1.07,.71),Vector2(0,.88),Vector2(-1.07,.71),Vector2(-1.83,.38),Vector2(-1.83,0)])
 Geo.mesh(wing,Shapes.extrude(arch_shape,.41),at+Vector3(0,3.05,.37),stone)
 var tower=at+Vector3(0,high+4.53,-3.4)
 Geo.cylinder(wing,tower,2.43,3.3,stone)
 Geo.cylinder(wing,tower+Vector3.UP*1.77,2.68,.39,metal)
 Geo.sphere(wing,tower+Vector3.UP*2.00,Vector3(4.89,2.35,4.89),Geo.mat("537f9a",.25))
 Geo.torus(wing,tower+Vector3.UP*2.33,1.87,1.99,stone).rotation.z=.52
 Geo.cylinder(wing,tower+Vector3.UP*3.68,.14,.63,stone)
 Geo.sphere(wing,tower+Vector3.UP*4.10,Vector3.ONE*.21,glass)

static func abanis_streets(root:Node3D,boxes,snow:Material,obstacles:Array[AABB]):
 var street=Node3D.new()
 street.name="AbanisStreetDetails"
 root.add_child(street)
 var lamps:Array[Transform3D]=[]
 var trees:Array[Transform3D]=[]
 var drift=SurfaceTool.new()
 drift.begin(Mesh.PRIMITIVE_TRIANGLES)
 for cell:Vector2i in [Vector2i(3,11),Vector2i(7,10),Vector2i(18,6),Vector2i(28,8),Vector2i(28,19),Vector2i(12,19)]:
  var point=Route.point(cell)
  var at=Vector3(point.x,0,point.y)
  var angle=cell.x*.31+cell.y*.77
  var size=.44+.19*absf(sin(angle))
  trees.append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*size),at))
  Crags.ridge(drift,at-Vector3.UP*.06,Vector2(2.7,2.6),.43,cell.x*13+cell.y,false)
  var trunk=Vector3(.41,1.55,.41)
  Art.solid(street,at+Vector3.UP*.775,trunk,1,"wood",true)
  obstacles.append(AABB(at+Vector3(-trunk.x*.5,0,-trunk.z*.5),trunk))
  lamps.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.73),at+Vector3(1.25,0,.57)))
 finish(street,drift,snow,"AbanisCurbSnow")
 snowy_grove(street,trees,10070,"AbanisStreetTrees")
 Lamps.batch(street,10429,lamps)
 var props=Node3D.new()
 props.name="AbanisStreetProps"
 street.add_child(props)
 var oak=Fort.material(Color("735844"),false)
 var cut=Fort.material(Color("a58260"),false)
 var iron=Geo.mat("4c555d",.20)
 var yard=Route.point(Vector2i(13,20))
 var supplies=Vector3(yard.x,0,yard.y)
 Goods.crate(props,boxes,supplies+Vector3.LEFT*.64,1.04,true,oak,cut)
 Goods.barrel(props,supplies+Vector3.RIGHT*.55,.41,oak,cut,iron)
 boxes.add(supplies+Vector3(-.77,1.01,.14),Vector3(.71,.11,.68),snow)
 var curb=Route.point(Vector2i(7,12))
 var bench=Vector3(curb.x,0,curb.y)
 Court.bench(boxes,bench,true,2.31,oak)
 Goods.barrel(props,bench+Vector3.BACK*1.72,.30,oak,cut,iron)
 for shape in [AABB(supplies+Vector3(-1.17,0,-.54),Vector3(2.14,1.06,1.08)),
   AABB(bench+Vector3(-.45,0,-1.17),Vector3(.90,1.63,2.34)),
   AABB(bench+Vector3(-.30,0,1.42),Vector3(.60,.60,.60))]:
  Art.solid(props,shape.get_center(),shape.size,1,"wood",true)
  obstacles.append(shape)
 var fork=Route.point(Vector2i(7,8))
 signpost(street,Vector3(fork.x,1.94,fork.y+1.18),"大學方向")
 var lower=Route.point(Vector2i(10,20))
 signpost(street,Vector3(lower.x,1.94,lower.y),"雪山山路")

static func academy_terrace(root:Node3D,boxes,at:Vector3,half:float,depth:float):
 var court=Node3D.new()
 court.name="UniversityExteriorRoofGarden"
 root.add_child(court)
 var stone=Fort.material(Color("8aa0ac"),false)
 var snow=Fort.material(Color("e1edf0"),false)
 var sides=half*.59
 var short=depth*.42
 for side in [-1,1]:
  boxes.add(at+Vector3(side*sides,.36,0),Vector3(.34,.73,short*2.0),stone)
  boxes.add(at+Vector3(side*sides,.78,0),Vector3(.41,.12,short*2.0),snow)
  boxes.add(at+Vector3(0,.36,side*short),Vector3(sides*2.0,.73,.34),stone)
  boxes.add(at+Vector3(0,.78,side*short),Vector3(sides*2.0,.12,.41),snow)
  Rooms.plant_bed(court,at+Vector3(side*sides*.63,0,-1.78),Vector2(3.07,4.10),side>0)

static func highland_square(root:Node3D,boxes,id:int,obstacles:Array[AABB]):
 var campus=id==Route.UNIVERSITY
 var square=Node3D.new()
 square.name="UniversityCourtyard" if campus else "AbanisVillageSquare"
 root.add_child(square)
 var stone=Fort.material(Color("8da0a6") if campus else Color("849092"),false)
 var trim=Fort.material(Color("b6cac8"),false)
 var oak=Fort.material(Color("745747"),false)
 var ice=Geo.mat("84bccc",.16,.15)
 var sign_point=Route.building_door(id)+Vector2(0,-1.70)
 var sign=Vector3(sign_point.x,4.66 if campus else 4.42,sign_point.y)
 boxes.add(sign,Vector3(4.92,.78,.22),oak)
 boxes.add(sign+Vector3.UP*.40,Vector3(5.05,.16,.35),trim)
 var title=Label3D.new()
 title.name="HighlandHallSign"
 title.text="魔法大學" if campus else "村長之家"
 title.position=sign+Vector3.BACK*.131
 title.font_size=48
 title.pixel_size=.012
 title.modulate=Color("fff1cc")
 square.add_child(title)
 var at=Vector3(1.5,0,8.0) if campus else Vector3(18,0,0)
 if campus:
  var mosaic=Geo.cylinder(square,at+Vector3.UP*.024,3.88,.046,trim)
  mosaic.name="UniversityCourtyardMosaic"
  for i in 8:
   var radial=Vector3(cos(i*TAU/8.0),0,sin(i*TAU/8.0))
   var mark=Geo.box(square,at+radial*3.14+Vector3.UP*.057,Vector3(.91,.05,.30),stone)
   mark.rotation.y=-i*TAU/8.0
  var garden=Node3D.new()
  garden.name="UniversityCourtyardPlanters"
  square.add_child(garden)
  for offset in [-13.7,12.9]:
   var bed=at+Vector3(offset,0,-3.7)
   var size=Vector3(4.56,.58,7.36)
   Rooms.plant_bed(garden,bed,Vector2(size.x,size.z),false)
   Art.solid(square,bed+Vector3.UP*.29,size,1,"stone",true)
   obstacles.append(AABB(bed+Vector3(-size.x*.5,0,-size.z*.5),size))
 Geo.cylinder(square,at+Vector3.UP*.055,2.55,.11,stone)
 Geo.cylinder(square,at+Vector3.UP*.18,1.71,.29,trim)
 Geo.cylinder(square,at+Vector3.UP*.39,1.44,.39,stone)
 Geo.cylinder(square,at+Vector3.UP*.61,1.16,.09,ice)
 if campus:
  Geo.cylinder(square,at+Vector3.UP*.88,.29,.57,stone)
  Geo.sphere(square,at+Vector3.UP*1.50,Vector3.ONE*.41,ice)
 else:
  for side in [-1,1]:
   Geo.box(square,at+Vector3(side*1.31,1.69,0),Vector3(.24,2.2,.24),oak)
  Geo.beam(square,at+Vector3(-1.53,2.79,0),at+Vector3(1.53,2.79,0),.24,oak)
  Geo.cylinder(square,at+Vector3(.42,.80,.12),.27,.36,oak,false,.34)
 var footprint=Vector3(3.15,.70,3.15)
 var center=at+Vector3.UP*.35
 Art.solid(square,center,footprint,1,"stone",true)
 obstacles.append(AABB(center-footprint*.5,footprint))

static func house_roof(root:Node3D,base:Vector3,half:float,depth:float,peak:float,roof:Material,snow:Material,style:int):
 var section=[Vector2(-half,0),Vector2(0,peak),Vector2(half,0)]
 if style==1:
  section.insert(1,Vector2(-half*.78,peak*.14))
  section.insert(3,Vector2(half*.78,peak*.14))
 elif style==2:
  section=[Vector2(-half,0),Vector2(-half*.69,peak*.40),Vector2(-half*.19,peak),
   Vector2(half*.19,peak),Vector2(half*.69,peak*.40),Vector2(half,0)]
 elif style==3:
  section=[Vector2(-half,0),Vector2(-half*.81,peak*.40),Vector2(-half*.68,peak),
   Vector2(half*.68,peak),Vector2(half*.81,peak*.40),Vector2(half,0)]
 var shape=Geo.mesh(root,Shapes.extrude(PackedVector2Array(section),depth+1.24),base,roof)
 shape.name="FrostpassRoof"
 shape.set_meta("frostpass_roof_profile",style)
 var outline=PackedVector2Array()
 for p:Vector2 in section:
  outline.append(Vector2(p.x*1.026,p.y+.20+.18*(1.0-absf(p.x)/half)))
 for i in range(section.size()-1,-1,-1):
  var p:Vector2=section[i]
  outline.append(Vector2(p.x*.976,p.y+.03))
 Geo.mesh(root,Shapes.extrude(outline,depth+1.55),base,snow)
 var edge_z=base.z+(depth+1.58)*.5
 for i in section.size()-1:
  var a:Vector2=section[i]
  var b:Vector2=section[i+1]
  Geo.beam(root,Vector3(base.x+a.x,base.y+a.y-.04,edge_z),Vector3(base.x+b.x,base.y+b.y-.04,edge_z),.14,roof)

static func storefront(root:Node3D,boxes,p:Vector3,timber:Material):
 var awning=Fort.material(Color("8e4a3f"),false)
 var plank=Fort.material(Color("9d7750"),false)
 var iron=Geo.mat("4b4e53",.20)
 var porch=Node3D.new()
 porch.name="SnowpineMarketProps"
 root.add_child(porch)
 var cover=Geo.box(porch,p+Vector3(0,2.91,.77),Vector3(6.7,.18,1.76),awning)
 cover.rotation.x=.115
 boxes.add(p+Vector3(0,2.80,1.68),Vector3(6.72,.21,.18),awning)
 for side in [-1,1]:
  var x=float(side)*2.94
  boxes.add(p+Vector3(x,1.36,1.48),Vector3(.22,2.72,.23),timber)
  Geo.beam(porch,p+Vector3(x,2.07,1.47),p+Vector3(x,2.91,.56),.14,timber)
  boxes.add(p+Vector3(x,2.35,1.36),Vector3(.17,.38,.14),Geo.mat("e6b171",.04,.55))
 var sign=p+Vector3(-2.28,2.35,1.58)
 boxes.add(sign,Vector3(1.19,.48,.15),plank)
 boxes.add(sign+Vector3.UP*.31,Vector3(.12,.23,.11),iron)
 var letters=Label3D.new()
 letters.name="SnowpineMarketSign"
 letters.text="MARKET"
 letters.position=sign+Vector3.BACK*.091
 letters.modulate=Color("fff0ce")
 letters.font_size=32
 letters.pixel_size=.0045
 porch.add_child(letters)
 for side in [-1,1]:
  boxes.add(sign+Vector3(side*.59,0,.09),Vector3(.08,.52,.08),timber)
 Goods.crate(porch,boxes,p+Vector3(3.95,0,.48),.87,true,timber,plank)
 Goods.barrel(porch,p+Vector3(-4.03,0,.42),.39,timber,plank,iron)
 Court.bench(boxes,p+Vector3(5.44,0,.54),false,1.68,timber)

static func cave_walls(root:Node3D,id:int,walk:PackedByteArray,context:Dictionary={}):
 var rock=SurfaceTool.new()
 rock.begin(Mesh.PRIMITIVE_TRIANGLES)
 rock.set_smooth_group(-1)
 var columns={}
 var size_:Vector2i=context.get("size",Route.SIZE);var origin_:Vector2=context.get("origin",Route.ORIGIN)
 var stage:int=context.get("stage",Route.LEVELS.keys().find(id))
 var doors_:Array=context.get("doors",Route.DOORS.get(id,[]))
 var frozen:bool=context.get("frozen",id in [Route.SNOW_CAVE,Route.ICE_VAULT])
 var shelf_ice=SurfaceTool.new()
 shelf_ice.begin(Mesh.PRIMITIVE_TRIANGLES)
 var ledges=SurfaceTool.new()
 ledges.begin(Mesh.PRIMITIVE_TRIANGLES)
 ledges.set_smooth_group(-1)
 var crust=SurfaceTool.new()
 crust.begin(Mesh.PRIMITIVE_TRIANGLES)
 crust.set_smooth_group(-1)
 var banks=SurfaceTool.new()
 banks.begin(Mesh.PRIMITIVE_TRIANGLES)
 if frozen:Lamps.prepare_primitives()
 for z in size_.y:
  for x in size_.x:
   var cell=Vector2i(x,z)
   if not open_cell(walk,cell,size_):continue
   for step:Vector2i in CARDINAL:
    if open_cell(walk,cell+step,size_):continue
    var edge=(origin_+Vector2(cell)*3)+Vector2(step)*1.5
    var tangent=Vector2(step.y,-step.x)*1.5
    var edge_points=[edge-tangent,edge,edge+tangent]
    for at:Vector2 in edge_points:
     if not columns.has(at):columns[at]=wall_column(at,stage,walk,size_,origin_)
    var serial=x*17+z*29+step.x*7+step.y*13
    if frozen and posmod(serial,11)<4 and not doors_.any(func(door):return Vector2(cell-door).length_squared()<16.0):
     var bank=edge-Vector2(step)*.21+tangent*.18*sin(serial)
     var spread=Vector2(2.83,.98) if step.x==0 else Vector2(.98,2.83)
     var swell=.23+.15*absf(sin(serial*.63))
     Lamps.oval(banks,Vector3(bank.x,-.022,bank.y),Vector3(spread.x,swell,spread.y))
    if frozen and posmod(serial,11)<3:
     var seam=6 if posmod(serial,11)==1 else 7
     var left:Vector3=columns[edge-tangent][seam]
     var middle:Vector3=columns[edge][seam]
     var right:Vector3=columns[edge+tangent][seam]
     ice_ledge(ledges,shelf_ice,crust,left.lerp(middle,.22),middle,right.lerp(middle,.17),step,serial)
    for segment in 2:
     var left:PackedVector3Array=columns[edge_points[segment]]
     var right:PackedVector3Array=columns[edge_points[segment+1]]
     for band in WALL_PROFILE.size()-1:
      Crags.face(rock,left[band],right[band],right[band+1],left[band+1])
 var stone=Fort.material(CAVE_COLORS[stage].darkened(.20),false).duplicate()
 stone.set_shader_parameter("snow_cover",context.get("snow_cover",.17+float(stage)*.20))
 if frozen:
  stone=ice_surface(id,true)
  stone.set_shader_parameter("powder_cover",.82)
  finish(root,shelf_ice,stone,"SnowMountainWallIce")
  var ledge_material=ice_surface(id,true)
  ledge_material.set_shader_parameter("ice_color",Color("8d95cb" if id==Route.ICE_VAULT else "75afc2"))
  finish(root,ledges,ledge_material,"SnowMountainLedges")
  var frost=ice_surface(id,true)
  frost.set_shader_parameter("ice_color",Color("bdc4e8" if id==Route.ICE_VAULT else "b9e0e7"))
  finish(root,crust,frost,"SnowMountainLedgeFrost")
  Geo.mesh(root,banks.commit(),Vector3.ZERO,Fort.material(Color("deebf2"),false)).name="SnowMountainBankDrifts"
 finish(root,rock,stone,"FrostpassRockWalls")

static func ice_ledge(shelf:SurfaceTool,icicles:SurfaceTool,crust:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,out:Vector2i,serial:int):
 var ice_edge=Vector3(-out.x,0,-out.y)
 var rim=PackedVector3Array([a+ice_edge*.24,b+ice_edge*(.74+.20*sin(serial)),c+ice_edge*.32])
 var ledge=PackedVector3Array([a,b,c])
 for part in 2:
  var first=rim[part]+Vector3.UP*.07
  var last=rim[part+1]+Vector3.UP*.07
  var lower_first=first-ice_edge*.16-Vector3.UP*.26
  var lower_last=last-ice_edge*.16-Vector3.UP*.26
  Crags.face(shelf,first,last,ledge[part+1]-ice_edge*.16,ledge[part]-ice_edge*.16)
  Crags.face(shelf,lower_first,lower_last,last,first)
  Crags.face(shelf,ledge[part]-Vector3.UP*.45,ledge[part+1]-Vector3.UP*.45,lower_last,lower_first)
  var high_a=first+Vector3.UP*.036
  var high_b=last+Vector3.UP*.036
  var back_a=ledge[part]-ice_edge*.14+Vector3.UP*.036
  var back_b=ledge[part+1]-ice_edge*.14+Vector3.UP*.036
  var middle=high_a.lerp(high_b,.43)-ice_edge*(.065+.04*sin(serial+part))
  var back_mid=back_a.lerp(back_b,.43)+Vector3.UP*.045
  Crags.face(crust,high_a,middle,back_mid,back_a)
  Crags.face(crust,middle,high_b,back_b,back_mid)
  Crags.face(crust,high_a-Vector3.UP*.14,high_b-Vector3.UP*.10,high_b,high_a)
  var foot=lower_first.lerp(lower_last,.58)
  var height=.52+.91*absf(sin(serial*.91+part*1.65))
  ice_blade(icicles,foot,-height,Vector2(.15,.18),Vector2(-out.x,-out.y)*.13,serial+part)

static func cave_mass(root:Node3D,id:int,walk:PackedByteArray,lots:Array,context:Dictionary={}):
 var rock=SurfaceTool.new()
 rock.begin(Mesh.PRIMITIVE_TRIANGLES)
 var size_:Vector2i=context.get("size",Route.SIZE);var origin_:Vector2=context.get("origin",Route.ORIGIN)
 var stage:int=context.get("stage",Route.LEVELS.keys().find(id))
 for lot:Rect2i in lots:
  var span=Vector2(lot.size)*3.0
  var at=(origin_+Vector2(lot.position)*3)+span*.5-Vector2.ONE*1.5
  Crags.ridge(rock,Vector3(at.x,-.35,at.y),span*.99,5.25+stage*.65,lot.position.x*9+lot.position.y,true,.49)
 for z in range(1,size_.y-1,2):
  for x in range(1,size_.x-1,2):
   var cell=Vector2i(x,z)
   if open_cell(walk,cell,size_):continue
   if CARDINAL.any(func(step):return open_cell(walk,cell+step,size_)):continue
   if not CARDINAL.any(func(step):return open_cell(walk,cell+step*2,size_)):continue
   if lots.any(func(lot):return lot.grow(1).has_point(cell)):continue
   var at=(origin_+Vector2(cell)*3)
   var serial=x*23+z*13
   var high=4.1+stage*.58+1.3*sin(serial*.11)
   Crags.ridge(rock,Vector3(at.x,-.35,at.y),Vector2(6,6),high,serial,true)
 var stone=Fort.material(CAVE_COLORS[stage].darkened(.29),false).duplicate()
 stone.set_shader_parameter("snow_cover",context.get("snow_cover",.12+stage*.13))
 if context.get("frozen",id in [Route.SNOW_CAVE,Route.ICE_VAULT]):
  stone=ice_surface(id,true)
  stone.set_shader_parameter("powder_cover",.82)
 finish(root,rock,stone,"FrostpassRockMass")

static func open_cell(walk:PackedByteArray,cell:Vector2i,size_:Vector2i=Route.SIZE)->bool:
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 var i=cell.y*size_.x+cell.x
 return (walk[i>>3] & (1<<(i&7)))!=0

static func wall_column(at:Vector2,stage:int,walk:PackedByteArray,size_:Vector2i=Route.SIZE,origin_:Vector2=Route.ORIGIN)->PackedVector3Array:
 # Neighboring faces share this column so every ledge continues around the corner.
 var outward=Vector2.ZERO
 for x in [-.75,.75]:
  for z in [-.75,.75]:
   var delta=Vector2(x,z)
   if open_cell(walk,Vector2i(((at+delta-origin_)/3.0).round()),size_):outward-=delta
 outward=outward.normalized()
 var relief=sin(at.x*.24+at.y*.31)*.83+cos(at.x*.91-at.y*.68)*.41
 var height=5.25+float(stage)*.68+relief
 var column=PackedVector3Array()
 for profile:Vector2 in WALL_PROFILE:
  var offset=maxf(0.0,profile.y*(1.0+.29*relief))
  var point=at+outward*offset
  column.append(Vector3(point.x,profile.x*height+.13*sin(at.x*.53-at.y*.73+profile.x*5.0),point.y))
 return column
