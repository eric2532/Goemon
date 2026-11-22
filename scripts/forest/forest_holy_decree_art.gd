extends RefCounted

const Route=preload("res://scripts/forest/forest_holy_decree.gd")
const Frost=preload("res://scripts/forest/forest_frostpass_art.gd")
const Rooms=preload("res://scripts/forest/forest_frostpass_interiors.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Crags=preload("res://scripts/forest/forest_freyja_destination_art.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const ChamberProps=preload("res://scripts/forest/forest_falken_chamber_props.gd")
const CRYPT_STONE=Color("89948a")
const WALL_STEPS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const CORRIDOR_ROW=9
const CORRIDOR_TREADS=["a6b5b6","9ca9ab","a0afb0","acbac0","a0aaa8","6b4133"]
const MAZE_MASONRY=["a2aa99","a1a99a","9da99c","9fa799","a1a693","9ca797"]
const MINERAL_TINTS=[Vector3(1.54,1.32,1.43),Vector3(1.53,1.30,1.40),Vector3(1.45,1.31,1.47),
 Vector3(1.48,1.31,1.44),Vector3(1.46,1.24,1.32),Vector3(1.52,1.32,1.47)]
const DAIS_TINTS=[Color(.95,1.02,1.16),Color(.93,1.02,1.17),Color(.91,1.03,1.15),
 Color(.94,1.01,1.14),Color(1.14,.33,.08)]
const RUBBLE_CELLS=[
 [Vector2i(5,5),Vector2i(8,7),Vector2i(15,3),Vector2i(17,6),Vector2i(16,8),Vector2i(7,11)],
 [Vector2i(5,6),Vector2i(14,7),Vector2i(17,3),Vector2i(16,11)],
 [Vector2i(5,3),Vector2i(5,7),Vector2i(7,6),Vector2i(16,6),Vector2i(16,7),Vector2i(17,6),Vector2i(17,8),Vector2i(9,11),Vector2i(8,12)],
 [Vector2i(6,4),Vector2i(8,7),Vector2i(15,4),Vector2i(16,5),Vector2i(16,6),Vector2i(17,5),Vector2i(17,7),Vector2i(17,8),Vector2i(14,11),Vector2i(16,11)],
 [Vector2i(5,8),Vector2i(16,4)],
]

static func at(p:Vector2,y:float=0.0)->Vector3:return Vector3(p.x,y,p.y)

static func wall_color(id:int)->Color:
 if id==Route.HOUSE:return Color("997356")
 if id==Route.WEST_ROAD:return Color("84939a")
 if id==Route.GUARDIAN_FLOORS.back():return CRYPT_STONE.darkened(.11)
 var index=Route.section_index(id)
 return Color("575468") if index<0 else CRYPT_STONE.lerp(Color(Route.PALETTES[index]),.19).darkened(.13)

static func maze_masonry(index:int,base:bool)->ShaderMaterial:
 var color=Color(MAZE_MASONRY[index])
 if base:color=color.darkened(.08)
 var wall=Fort.material(color).duplicate() as ShaderMaterial
 wall.set_shader_parameter("masonry_tile",Vector2(1.62,.61))
 wall.set_shader_parameter("weathered_masonry",true)
 return wall

static func village_gate(root:Node3D):
 var gate=Node3D.new()
 gate.name="AbanisDecreeWestGate"
 gate.position=at(Route.ABANIS_WEST_GATE)
 gate.rotation.y=PI*.5
 root.add_child(gate)
 Frost.tunnel(gate,Vector3.ZERO,1.0,Vector2(1.92,3.5),2.1,Color("869ca5"),true)
 Frost.signpost(root,at(Route.ABANIS_WEST_GATE+Vector2(4.6,-2.1),1.95),"莎蓮娜西路")

static func build(root:Node3D,boxes,id:int,bits:PackedByteArray)->Dictionary:
 var index=Route.section_index(id)
 var corridor_only=index>=0 and id not in Route.GUARDIAN_FLOORS
 var color=wall_color(id)
 var outdoor=id==Route.WEST_ROAD
 var furnished={}
 if id==Route.HOUSE:
  for cell in Route.HOUSE_FURNITURE:furnished[cell]=true
 var tones:Array[Material]=[]
 var repaired_stone:ShaderMaterial
 var repairs:Array[Rect2i]=[]
 if index>=0:
  var floor_stone=ShaderMaterial.new()
  floor_stone.shader=preload("res://assets/materials/twin_kings_flagstone.gdshader")
  floor_stone.set_shader_parameter("rock_texture",Fort.ROCK)
  var tint:Vector3=MINERAL_TINTS[index]
  if corridor_only:tint*=Vector3(.93,1.06,.97)
  floor_stone.set_shader_parameter("mineral_tint",tint)
  floor_stone.set_shader_parameter("corridor_paving",corridor_only)
  tones.append(floor_stone)
  if id==Route.floor_id(1):
   repaired_stone=floor_stone.duplicate() as ShaderMaterial
   repaired_stone.set_shader_parameter("corridor_paving",false)
   repaired_stone.set_shader_parameter("mineral_tint",Vector3(1.76,1.70,2.05))
   for target in [Vector2i(15,10),Vector2i(6,16)]:
    var site=passage_cell(bits,target)
    repairs.append(Rect2i(site-Vector2i(1,1),Vector2i(3,3)))
 else:
  for variation in [-.028,0.0,.036]:
   var tint=Color("cbdcdd") if outdoor else color.lightened(.20)
   tones.append(Fort.material(tint.lightened(variation),id!=Route.HOUSE and not outdoor))
 for row in Route.SIZE.y:
  for col in Route.SIZE.x:
   var offset=row*Route.SIZE.x+col
   var cell=Vector2i(col,row)
   if (bits[offset>>3] & (1<<(offset&7)))==0 and not furnished.has(cell):continue
   var p=Route.point(cell)
   var finish=tones[(col*7+row*13)%tones.size()]
   if repaired_stone!=null and (repairs[0].has_point(cell) or repairs[1].has_point(cell)):
    finish=repaired_stone
   boxes.add(at(p,-.18),Vector3(3,.36,3),finish,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 if id==Route.HOUSE:
  house(root,boxes)
 elif id==Route.CELLAR or id==Route.PAST:
  var past=id==Route.PAST
  stone_disc(root,Route.RELIC,Color("c9a77d") if past else Color("61c5cc"),false)
  var stone=Fort.material(wall_color(id),true)
  for x in [-7.5,7.5]:pillar(root,boxes,Vector3(x,0,-16.1),stone,stone)
  var seal=Geo.torus(root,at(Route.RELIC,.025),2.25,2.34,Fort.material(Color("918d79"),false))
  seal.name="DecreeCellarInlay"
  if past and not root.get_tree().get_meta(Route.BLADE,false):
   var blade=Geo.box(root,at(Route.RELIC,1.15),Vector3(.30,.96,.13),Geo.mat("e3b779",.18,.23))
   blade.name="DecreeBladeFragment"
   blade.rotation.z=-.32
 elif outdoor:
  west_road(root,boxes)
 else:
  vault(root,boxes,id,index,bits)
 return furnished

static func house(root:Node3D,boxes):
 var walnut=Fort.material(Color("5d4635"),false)
 for x in [-7.5,10.5]:
  var shelf=Geo.mesh(root,Furniture.bookcase(4.4,6.0,true),Vector3(x,0,-12),null)
  shelf.rotation.y=-PI*.5
 Rooms.window(root,boxes,1.5,-16.25,false,walnut,Fort.material(Color("a28160"),false))
 Rooms.room_light(root,Vector3(1.5,3.4,-14),Color("b2ddff"),1.0,10.0)
 for x in [-12,12]:
  var loc=Vector3(x,0,3)
  Geo.mesh(root,Furniture.desk(3.7,3.3,x<0),loc,null)
  boxes.add(loc+Vector3(0,.014,0),Vector3(2.9,.06,2.7),Fort.material(Color("b18859"),false))
 Rooms.rug(root,boxes,Vector2(0,3.8),Vector2(6.0,11.0),Color("794651"))
 Rooms.stair_landing(root,boxes,Route.ROOM_STAIRS,"民家地下",true)
 Rooms.room_light(root,Vector3(0,4.7,-2),Color("ffd6a4"),1.15,16.0)
 boxes.add(Vector3(0,4.5,-14.7),Vector3(30,.40,.38),walnut)

static func west_road(root:Node3D,boxes):
 var rock=SurfaceTool.new()
 rock.begin(Mesh.PRIMITIVE_TRIANGLES)
 var trees=[]
 var snow=Fort.material(Color("a5bbc1"),false)
 for row in range(2,23,3):
  for x in [-1,1]:
   var p=Vector3(x*(26.0+2.5*sin(row)),.1,row*3.0-35)
   Crags.ridge(rock,p,Vector2(10,8),5.4+absf(sin(row*17+x))*4.2,row*7+x,true)
   var scale=.70+absf(cos(row*11+x))*.46
   trees.append(Transform3D(Basis(Vector3.UP,row*.72).scaled(Vector3.ONE*scale),p+Vector3(0,3.1,0)))
 for x in [-23.,-17.,-10.,-4.]:
  var p=Vector3(x,0,-25.8-.58*sin(x))
  Crags.ridge(rock,p,Vector2(4.9,3.8),1.1+.40*cos(x),roundi(x*7.0),false)
  trees.append(Transform3D(Basis(Vector3.UP,x).scaled(Vector3.ONE*.64),p+Vector3.UP*.74))
 Frost.finish(root,rock,snow,"DecreeRoadSnowbanks")
 Frost.snowy_grove(root,trees)
 stone_disc(root,Route.ROAD_DISC,Color("6fdad1"),true)
 Frost.tunnel(root,at(Route.LOWER_DOOR+Vector2(0,.50)), -1.0,Vector2(1.92,3.5),2.1,Color("869ca5"),true)
 Frost.signpost(root,at(Route.LANDING+Vector2(6,0),1.82),"鼓動的石盤")
 for p in [Vector2(8,20),Vector2(5,0),Vector2(-7,-14)]:
  Lamps.batch(root,10429,[Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.81),at(p))])
 boxes.add(at(Route.ROAD_DISC,-.36),Vector3(11,.37,10),snow)

static func vault(root:Node3D,boxes,id:int,index:int,bits:PackedByteArray):
 var final=id==Route.GUARDIAN_FLOORS.back()
 var corridor_only=id not in Route.GUARDIAN_FLOORS
 var number=Route.floor_number(id) if corridor_only else 0
 var color=wall_color(id).lightened(.08)
 var stone=Fort.material(color.darkened(.24),true)
 var metal=Fort.material(color.lightened(.24),false)
 var accent=Color("e9b47f")
 var details=Node3D.new()
 details.name="DecreeMazeDetails"
 root.add_child(details)
 var corridor=Node3D.new()
 corridor.name="DecreeCorridorDetails"
 details.add_child(corridor)
 maze_walls(details,corridor,boxes,bits,index,number)
 if corridor_only:
  floor_props(corridor,bits,number)
 else:
  corridor_props(corridor,bits,index)
 for door in [Route.LOWER_DOOR,Route.UPPER_DOOR]:
  var front=-signf(door.y)
  var portal=Frost.tunnel(root,at(door-Vector2(0,front*.85)),front,Vector2(1.93,3.53),2.1,color,true)
  portal.name="DecreeStairPassage"
  var tread=metal
  if door==Route.LOWER_DOOR or corridor_only:
   tread=Fort.material(Color(CORRIDOR_TREADS[index]),false)
   boxes.add(at(door+Vector2(0,front*2.94),.024),Vector3(3.96,.046,.26),tread)
  for step in 3:
   boxes.add(at(door+Vector2(0,front*(1.5+step*.47)),.11-step*.036),Vector3(3.52-step*.16,.17,.445),tread)
  for x in [-2.45,2.45]:
   var pedestal=at(door+Vector2(x,front*1.27))
   pillar(root,boxes,pedestal,stone,metal)
   Rooms.room_light(root,pedestal+Vector3(0,1.8,front*.89),accent,.84,8.7)
 if corridor_only:return
 if final:
  twin_kings_chamber(root,boxes,stone,metal,bits)
  return
 guardian_dais(details,boxes,index)
 guardian_rubble(details,bits,index)

static func maze_walls(details:Node3D,corridor:Node3D,boxes,bits:PackedByteArray,index:int,number:int):
 var niches=[]
 var passage_niches=[]
 var passage_reliefs=[]
 var embers=[]
 var reliefs=[]
 var final=index==Route.GUARDIAN_FLOORS.size()-1
 var rib=Fort.material(Color("785d4c"),true)
 var lip=Fort.material(Color("8e8069"),false)
 var corner_bricks=[Fort.material(Color("915b43"),false),Fort.material(Color("72584b"),false)]
 var candles=[]
 for z in Route.SIZE.y:
  for x in Route.SIZE.x:
   var cell=Vector2i(x,z)
   if not maze_open(bits,cell):continue
   var center=Route.point(cell)
   if center.distance_squared_to(Route.UPPER_DOOR)<33.0 or center.distance_squared_to(Route.LOWER_DOOR)<33.0:continue
   for step:Vector2i in WALL_STEPS:
    if maze_open(bits,cell+step):continue
    var along=x if step.y!=0 else z
    var edge=center+Vector2(step)*1.29
    if number>0 or z>=CORRIDOR_ROW:
     corridor_wall_end(boxes,bits,cell,step,edge,corner_bricks)
     if along%3!=2:continue
     var facing=Basis(Vector3.UP,atan2(-step.x,-step.y))
     if number==0 and ((index==3 and step in [Vector2i.UP,Vector2i.LEFT]) or (index==2 and along%6==2)):
      passage_reliefs.append(Transform3D(facing,at(edge,2.12)))
     else:
      passage_niches.append(Transform3D(facing.scaled_local(Vector3(.78,.87,1)),at(edge,1.23)))
    elif along%3==0:
     var size=Vector3(.38,4.18,.27) if step.y!=0 else Vector3(.27,4.18,.38)
     boxes.add(at(edge,2.09),size,rib)
     boxes.add(at(edge,4.22),Vector3(size.x+.13,.14,size.z+.13),lip)
    elif along%3==2:
     var orientation=Basis(Vector3.UP,atan2(-step.x,-step.y))
     var placement=Transform3D(orientation,at(edge,1.10))
     if not final and along%6==2 and z<=3 and step!=Vector2i.DOWN:
      reliefs.append(Transform3D(orientation,at(edge,2.12)))
     elif z<=8 and (along+(0 if final else index))%2==0:
      embers.append(placement)
     else:
      niches.append(placement)
 if number==0:
  for row in [9,14,20]:
   var p=Route.point(passage_cell(bits,Vector2i(12 if row==20 else 10,row)))
   candles.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.38),at(p)))
   Rooms.room_light(corridor,at(p,2.75),Color("eab486"),.86 if index<4 else .66,8.8)
  ChamberProps.batch(details,"MazeNiche",niches)
  ChamberProps.batch(corridor,"Candles",candles)
 else:
  var size=passage_niches.size()
  var count=mini(Route.Corridors.SCENERY[number][3],size-1)
  for i in range(count-1,-1,-1):
   var pick=floori((i+.5)*size/count)
   var niche:Transform3D=passage_niches.pop_at(pick)
   passage_reliefs.append(Transform3D(niche.basis.orthonormalized(),niche.origin+Vector3.UP*.89))
 if not embers.is_empty():ChamberProps.batch(details,"MazeEmberNiche",embers)
 if not reliefs.is_empty():ChamberProps.batch(details,"MazeWallRelief",reliefs)
 if not passage_niches.is_empty():ChamberProps.batch(corridor,"MazeNiche",passage_niches)
 if not passage_reliefs.is_empty():ChamberProps.batch(corridor,"MazeWallRelief",passage_reliefs)

static func corridor_wall_end(boxes,bits:PackedByteArray,cell:Vector2i,step:Vector2i,edge:Vector2,bricks:Array):
 var tangent=Vector2i(-step.y,step.x)
 for side in [-1,1]:
  var next:Vector2i=cell+tangent*side
  if maze_open(bits,next) and not maze_open(bits,next+step):continue
  for course in 7:
   var width=.53 if course%2==0 else .35
   var end=edge+Vector2(tangent)*side*(1.48-width*.49)
   var size=Vector3(width,.52,.15) if step.y!=0 else Vector3(.15,.52,width)
   boxes.add(at(end,.32+course*.58),size,bricks[course%2])

static func corridor_props(corridor:Node3D,bits:PackedByteArray,index:int):
 if index==0:
  var stands=[]
  for cell in [Vector2i(10,12),Vector2i(5,15)]:
   var p=Route.point(passage_cell(bits,cell))+Vector2(.6,-1.0)
   stands.append(Transform3D(Basis.IDENTITY,at(p)))
   Rooms.room_light(corridor,at(p,2.20),Color("a7cde0"),.53,6.3)
  ChamberProps.batch(corridor,"MazeOrbStand",stands)
 elif index==1:
  var rubble=[]
  for cell in [Vector2i(9,11),Vector2i(15,14),Vector2i(14,18)]:
   rubble.append(Transform3D(Basis(Vector3.UP,cell.x*.68),at(Route.point(passage_cell(bits,cell)))))
  ChamberProps.batch(corridor,"MazeRubble",rubble)

static func floor_props(corridor:Node3D,bits:PackedByteArray,number:int):
 var counts:Array=Route.Corridors.SCENERY[number]
 var slots:Array[Transform3D]=[]
 for z in range(5,20):
  for x in range(2,21):
   var cell=Vector2i(x,z)
   if not maze_open(bits,cell):continue
   for step:Vector2i in WALL_STEPS:
    if maze_open(bits,cell+step):continue
    var facing=Basis(Vector3.UP,atan2(-step.x,-step.y))
    slots.append(Transform3D(facing,at(Route.point(cell)+Vector2(step)*.56)))
    break
 var period_fixtures=2 if number<=2 else 0
 var remaining:int=counts[0]+counts[1]+counts[2]+counts[4]+period_fixtures
 if remaining==0:return
 var families=["MazeRubble","MazeOrbStand","Candles","MazeFloorGrille","MazeIronScreen"]
 var amounts=[counts[0],counts[1],counts[2],counts[4],period_fixtures]
 var slot_index=0
 for family in families.size():
  var transforms=[]
  for i in amounts[family]:
   var pick=mini(floori((slot_index+.5)*slots.size()/remaining),slots.size()-1)
   var placement=slots[pick]
   slot_index+=1
   if family==1:
    Rooms.room_light(corridor,placement.origin+Vector3.UP*2.18,Color("a7cde0"),.48,6.5)
   elif family==2:
    placement.basis=placement.basis.scaled_local(Vector3.ONE*1.35)
    Rooms.room_light(corridor,placement.origin+Vector3.UP*2.15,Color("eab486"),.66,6.8)
   elif family==4:
    if number==1:
     var monument=placement.origin+placement.basis.z*1.03
     var base=Geo.box(corridor,monument+Vector3.UP*.18,Vector3(1.21,.36,2.06),Fort.material(Color("7e968a")))
     base.basis=placement.basis
     var rider=Geo.mesh(corridor,Statues.sculpt(10462),monument+Vector3.UP*.36,Fort.material(Color("78a6a2"),false))
     rider.name="MazeVerdigrisMonument"
     rider.basis=placement.basis.scaled_local(Vector3.ONE*.71)
    placement.origin-=placement.basis.z*.64
   transforms.append(placement)
  if not transforms.is_empty():ChamberProps.batch(corridor,families[family],transforms)

static func maze_open(bits:PackedByteArray,cell:Vector2i)->bool:
 if not Rect2i(Vector2i.ZERO,Route.SIZE).has_point(cell):return false
 var index=cell.y*Route.SIZE.x+cell.x
 return (bits[index>>3] & (1<<(index&7)))!=0

static func passage_cell(bits:PackedByteArray,target:Vector2i)->Vector2i:
 if maze_open(bits,target):return target
 var best=target
 var distance=INF
 for z in range(CORRIDOR_ROW,21):
  for x in range(2,21):
   var cell=Vector2i(x,z)
   var d=target.distance_squared_to(cell)
   if d>=distance or not maze_open(bits,cell):continue
   best=cell
   distance=d
 return best

static func guardian_dais(details:Node3D,boxes,index:int):
 var center=Route.point(Vector2i(11,5))
 var red=index==4
 var edge=Fort.material(Color("869492"),false)
 var lip=Fort.material(Color(1.02,1.13,1.24),false)
 var inset=Fort.material(DAIS_TINTS[index],false)
 var etching=Geo.mat("8b3725" if red else "829293")
 boxes.add(at(center,.12),Vector3(12.3,.24,12.3),edge)
 boxes.add(at(center,.265),Vector3(10.03,.14,10.03),lip)
 boxes.add(at(center,.331),Vector3(9.90,.065,9.90),inset)
 for direction in [-1,1]:
  for stone in 4:
   var shift=stone-1.5
   var across=center+Vector2(shift*3.0,direction*5.48)
   var down=center+Vector2(direction*5.48,shift*2.47)
   boxes.add(at(across,.269),Vector3(2.95,.13,1.05),lip)
   boxes.add(at(down,.269),Vector3(1.05,.13,2.42),lip)
 if red:
  for side in [-1,1]:
   boxes.add(at(center+Vector2(side*4.53,0),.365),Vector3(.12,.006,9.16),etching)
   boxes.add(at(center+Vector2(0,side*4.53),.365),Vector3(9.16,.006,.12),etching)
 for radius in [3.36,3.05,2.30]:
  var ring=Geo.torus(details,at(center,.367),radius-.058,radius+.058,etching)
  ring.name="DecreeGuardianSeal"
  ring.scale.y=.15
  ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for mark in 16:
  var angle=TAU*mark/16.0
  var p=center+Vector2(cos(angle),sin(angle))*2.71
  boxes.add(at(p,.367),Vector3(.13,.005,.13),etching,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 var basins=[]
 var candles=[]
 for side in [-1,1]:
  for end in [-1,1]:
   var p=center+Vector2(4.25*side,4.25*end)
   basins.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.22),at(p,.365)))
   Rooms.room_light(details,at(p,3.2),Color("eaba88"),.79,8.2)
   if side==end:
    candles.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.44),at(p+Vector2(2.45*side,0))))
 ChamberProps.batch(details,"MazeBasin",basins)
 ChamberProps.batch(details,"Candles",candles)

static func guardian_rubble(details:Node3D,bits:PackedByteArray,index:int):
 var poses=[]
 for i in RUBBLE_CELLS[index].size():
  var cell=passage_cell(bits,RUBBLE_CELLS[index][i])
  var size=.66+.13*((index*3+i*5)%7)
  if index in [2,3]:size*=1.25
  var orientation=Basis(Vector3.UP,i*2.40).scaled(Vector3(size,1.0,size))
  poses.append(Transform3D(orientation,at(Route.point(cell))))
 ChamberProps.batch(details,"MazeRubble",poses)

static func twin_kings_chamber(root:Node3D,boxes,stone:Material,trim:Material,bits:PackedByteArray):
 var scenery=Node3D.new()
 scenery.name="TwinKingsScenery"
 root.add_child(scenery)
 var gold=Geo.mat("d9ad62",.23)
 var patina=Geo.mat("947847",.34)
 Lamps.prepare_primitives()
 var statue_mesh=Furniture.tool()
 var wing_detail=Furniture.tool()
 statue_mesh.append_from(Statues.sculpt(10400),0,
  Transform3D(Basis.IDENTITY.scaled(Vector3(1.42,1.76,1.49)),Vector3.ZERO))
 var wing=PackedVector2Array([
  Vector2(.22,1.15),Vector2(.57,1.46),Vector2(.90,1.73),Vector2(1.08,2.07),
  Vector2(.78,1.99),Vector2(1.16,2.49),Vector2(.75,2.35),Vector2(.94,2.78),
  Vector2(.62,2.55),Vector2(.20,2.00)])
 for side in [-1.0,1.0]:
  var basis=Basis(Vector3.UP,-.40 if side>0 else PI+.40)
  var joint=Vector3(0,.25,-.48)
  ChamberProps.append_profile(statue_mesh,wing,.14,Transform3D(basis,joint))
  for i in [3,5,7]:
   var tip=wing[i]
   Lamps.rod(wing_detail,joint+basis*Vector3(.24,1.68,.085),joint+basis*Vector3(tip.x*.91,tip.y*.97,.077),.034)
 var figure=Furniture.finish([statue_mesh,wing_detail],[gold,patina])
 for p in [Vector2(-12.6,-22.1),Vector2(8.7,-23.3),Vector2(11.0,-12.0)]:
  var base=at(p)
  Geo.cylinder(scenery,base+Vector3.UP*.12,1.02,.24,gold)
  Geo.cylinder(scenery,base+Vector3.UP*.30,.90,.16,patina)
  Geo.cylinder(scenery,base+Vector3.UP*.43,.95,.14,gold)
  var statue=Geo.mesh(scenery,figure,base+Vector3.UP*.50,null)
  statue.name="TwinKingsGoldStatue"
  statue.rotation.y=-.34
  Rooms.room_light(scenery,base+Vector3(.7,3.0,2.3),Color("ffe2ae"),.72,8.4)
 var braziers=[]
 for p in [Vector2(-10.6,-26.9),Vector2(9.7,-26.8),Vector2(-18.2,-10.9),Vector2(12.8,-9.5)]:
  braziers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.79),at(p)))
 ChamberProps.batch(scenery,"Brazier",braziers)
 var candles=[]
 for p in [Vector2(-10.1,-22.6),Vector2(6.2,-24.8),Vector2(12.6,-14.1),Vector2(-13.2,-12.1)]:
  candles.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.6),at(p)))
 ChamberProps.batch(scenery,"Candles",candles)
 var ring=Geo.torus(scenery,Vector3(0,.021,-18.0),3.18,3.34,Geo.mat("684e40"))
 ring.name="TwinKingsFloorRing"
 ring.scale.y=.16
 ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for x in [-20.,-7.9,11.8,20.]:
  boxes.add(Vector3(x,1.78,-28.19),Vector3(.68,3.52,.38),stone)
  boxes.add(Vector3(x,3.48,-28.15),Vector3(.91,.18,.48),trim)
 bone_piles(scenery,bits)
 upright_seal(scenery,Vector2(-10.6,-13.3),gold)

static func bone_piles(root:Node3D,bits:PackedByteArray):
 var bones=Furniture.tool()
 var aged=Furniture.tool()
 var sockets=Furniture.tool()
 var shaft=CylinderMesh.new()
 shaft.height=1.0
 shaft.radial_segments=6
 shaft.rings=0
 var knob=SphereMesh.new()
 knob.radial_segments=6
 knob.rings=3
 var sites=[Vector2(-19.3,-25.2),Vector2(-15.7,-25.3),Vector2(-11.7,-26.4),Vector2(-7.8,-24.6),
  Vector2(-15.8,-20.1),Vector2(-20.0,-21.5),Vector2(-19.6,-18.3),Vector2(-17.2,-16.6),
  Vector2(-20.1,-13.0),Vector2(-18.7,-9.9),Vector2(-15.2,-9.8),Vector2(-12.9,-16.4),
  Vector2(-7.4,-10.1),Vector2(-4.2,-11.6),Vector2(-1.0,-10.5),Vector2(6.1,-10.0),
  Vector2(14.9,-10.4),Vector2(18.7,-9.7),Vector2(16.0,-13.9),Vector2(19.7,-14.2),
  Vector2(18.6,-17.6),Vector2(16.0,-18.5),Vector2(19.3,-22.0),Vector2(18.8,-25.5),
  Vector2(14.6,-25.3),Vector2(12.2,-24.8),Vector2(3.2,-13.2),Vector2(-3.9,-15.6),
  Vector2(-10.5,-2.1),Vector2(-7.2,-2.7),Vector2(-2.0,4.5)]
 for pile in sites.size():
  var site:Vector2=sites[pile]
  var cell=Vector2i(((site-Route.ORIGIN)/3.0).round())
  var origin=at(site if maze_open(bits,cell) else Route.point(passage_cell(bits,cell)))
  for i in range(65+pile%14):
   var angle=i*2.39996+pile*.43
   var offset=Vector3(cos(angle),0,sin(angle))
   var radius=.12+sqrt(i)*(.174+.012*(pile%4))
   var layer=absf(sin(i*1.46+pile))
   var height=.087+layer*(.10+.34*exp(-radius*radius*.80))
   var center=origin+offset*radius+Vector3.UP*height
   var axis=Vector3(cos(angle*1.79),.31*sin(angle*1.42),sin(angle*1.79))
   var end=axis*(.12+.031*(i%6)+(.20 if i%11==0 else 0.0))
   var finish=aged if i%4==0 else bones
   Statues.rod(finish,shaft,center-end,center+end,.046+.013*(i%4))
   if i%3==0:
    for side in [-1,1]:
     Statues.shape(finish,knob,center+end*side,Vector3(.17,.13,.15))
  if pile%2==0:
   for rib in range(5):
    var spine=origin+Vector3(-.43,.24,-.41-rib*.16)
    for side in [-1,1]:
     var arch=spine+Vector3(.32*side,.18,.015)
     var bend=spine+Vector3(.48*side,.06,.082)
     var tip=spine+Vector3(.39*side,-.14,.18)
     Lamps.rod(bones,spine,arch,.044)
     Lamps.rod(bones,arch,bend,.048)
     Lamps.rod(aged,bend,tip,.042)
  var head=origin+Vector3(.35*cos(pile),.34,.57*sin(pile))
  Lamps.oval(bones,head,Vector3(.58,.49,.52))
  Lamps.oval(aged,head+Vector3(0,-.16,.157),Vector3(.33,.16,.29))
  for x in [-.084,.084]:
   Lamps.oval(sockets,head+Vector3(x,.012,.247),Vector3(.105,.097,.050))
 var bone_mesh=Furniture.finish([bones,aged,sockets],[Geo.mat("e9ddbe"),Geo.mat("92856d"),Geo.mat("504b40")])
 Geo.mesh(root,bone_mesh,Vector3.ZERO,null).name="TwinKingsBonePiles"

static func upright_seal(root:Node3D,p:Vector2,gold:Material):
 var seal=Node3D.new()
 seal.name="TwinKingsUprightSeal"
 seal.position=at(p)
 root.add_child(seal)
 var dark=Fort.material(Color("34564c"),false)
 var edge=Fort.material(Color("648578"),false)
 Geo.box(seal,Vector3.UP*.14,Vector3(2.30,.28,2.13),edge)
 Geo.box(seal,Vector3.UP*1.64,Vector3(1.48,2.74,1.48),dark)
 var crown=CylinderMesh.new()
 crown.radial_segments=4
 crown.bottom_radius=1.047
 crown.top_radius=.06
 crown.height=.84
 Geo.mesh(seal,crown,Vector3.UP*3.43,dark).rotation.y=PI*.25
 var face=Fort.material(Color("24443d"),false)
 Geo.box(seal,Vector3(0,1.63,.747),Vector3(1.16,2.24,.036),face)
 var glyph=Geo.box(seal,Vector3(0,2.37,.782),Vector3(.24,.24,.026),gold)
 glyph.rotation.z=PI*.25
 for i in 5:
  Geo.box(seal,Vector3(0,2.02-i*.23,.779),Vector3(.56+.14*sin(i*2.4),.028,.015),edge)
 Rooms.room_light(seal,Vector3(0,2.0,1.4),Color("93ccb1"),.83,8.5)

static func pillar(root:Node3D,boxes,p:Vector3,stone:Material,trim:Material):
 boxes.add(p+Vector3.UP*.16,Vector3(1.15,.32,1.15),trim)
 boxes.add(p+Vector3.UP*1.39,Vector3(.76,2.62,.76),stone)
 boxes.add(p+Vector3.UP*2.71,Vector3(.96,.24,.96),trim)
 Rooms.wall_lantern(root,p+Vector3(0,2.16,.43))

static func stone_disc(root:Node3D,p:Vector2,light:Color,heightened:bool):
 var mesh=Node3D.new()
 mesh.name="DecreeStoneDisc"
 mesh.position=at(p)
 root.add_child(mesh)
 var stone=Fort.material(Color("484e56"),true)
 var edge=Fort.material(Color("9c998b"),true)
 var metal=Geo.mat(light.to_html(false),.10,.68)
 var width=1.36 if heightened else 1.07
 Geo.cylinder(mesh,Vector3.UP*.12,width+.26,.24,edge)
 Geo.cylinder(mesh,Vector3.UP*.39,width,.42,stone)
 Geo.cylinder(mesh,Vector3.UP*.66,width+.10,.16,edge)
 Geo.torus(mesh,Vector3.UP*.754,width*.82,width*.86,metal)
 Geo.torus(mesh,Vector3.UP*.756,width*.40,width*.45,metal)
 for i in 8:
  var angle=i*TAU/8.0
  var notch=Geo.box(mesh,Vector3(sin(angle)*width*.63,.755,cos(angle)*width*.63),Vector3(.065,.04,.26),metal)
  notch.rotation.y=angle
 Rooms.room_light(mesh,Vector3.UP*1.2,light,1.44,10.5)
