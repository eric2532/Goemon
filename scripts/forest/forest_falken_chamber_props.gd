extends RefCounted
## Solid scenery made for the current chamber. The map markers only supply placement.
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const FAMILIES={
 16583:"SpecimenCabinet",16649:"GlazedUrn",16651:"DarkUrn",
 16852:"SpecimenStand",16853:"SpecimenStand",16854:"SpecimenStand",
 17027:"StudyChair",17195:"Candles",17210:"Brazier",17212:"DisplayBench",
 17213:"DisplayCabinet",17215:"DisplayBench",17586:"WritingDesk",17587:"Bookcase",
 17605:"FloorSeal",17683:"PassageArch",17686:"StonePier",17688:"StonePier",
 17690:"CarvedWall",17692:"CarvedWall",17693:"CarvedWall",
}
static var meshes:Dictionary={}

static func batch(parent:Node3D,family:String,placements:Array):
 if not meshes.has(family):meshes[family]=build_mesh(family)
 var node=MultiMeshInstance3D.new()
 node.name="Chamber"+family
 node.multimesh=MultiMesh.new()
 node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=meshes[family]
 node.multimesh.instance_count=placements.size()
 for i in placements.size():node.multimesh.set_instance_transform(i,placements[i])
 parent.add_child(node)

static func pose(family:String,at:Vector2)->Transform3D:
 # The arch marker is on the first of three open cells. Center on the middle cell.
 if family=="PassageArch":at.x+=3.0
 var faces_south=family in ["SpecimenCabinet","Bookcase","DisplayBench","DisplayCabinet","WritingDesk"]
 return Transform3D(Basis(Vector3.UP,-PI*.5 if faces_south else 0.0),Vector3(at.x,0,at.y))

static func build_mesh(family:String)->Mesh:
 Parts.prepare_primitives()
 match family:
  "PassageArch":return arch()
  "StonePier","CarvedWall":return stonework(family=="CarvedWall")
  "MazeNiche","MazeEmberNiche":return maze_niche(family=="MazeEmberNiche")
  "MazeWallRelief":return maze_wall_relief()
  "MazeBasin":return maze_basin()
  "MazeRubble":return maze_rubble()
  "MazeFloorGrille","MazeIronScreen":return maze_ironwork(family=="MazeIronScreen")
  "SpecimenCabinet":return Furniture.cabinet(2.6,2.8,true)
  "DisplayCabinet":return Furniture.cabinet(2.5,7.9,false)
  "WritingDesk":return Furniture.desk(4.1,8.7,true)
  "Bookcase":return Furniture.bookcase(2.7,2.8,false)
  "StudyChair":return Furniture.chair()
  "GlazedUrn","DarkUrn":
   var clay=Furniture.tool()
   clay.append_from(Shapes.urn_mesh(),0,Transform3D(Basis.IDENTITY.scaled(Vector3(1.64,1.58,1.64)),Vector3.ZERO))
   return Furniture.finish([clay],[Geo.mat("455f67",.18) if family=="GlazedUrn" else Geo.mat("233f38",.10)])
  "SpecimenStand","DisplayBench","FloorSeal","MazeOrbStand":return display(family)
  "Brazier","Candles":return lamps(family=="Brazier")
 assert(false,"Unknown chamber scenery family: "+family)
 return null

static func maze_niche(with_ember:bool)->Mesh:
 var frame=Furniture.tool()
 var shadow=Furniture.tool()
 var profile=PackedVector2Array([Vector2(-.66,0),Vector2(.66,0),Vector2(.66,1.25),
  Vector2(.45,1.57),Vector2(0,1.83),Vector2(-.45,1.57),Vector2(-.66,1.25)])
 append_profile(frame,profile,.20,Transform3D.IDENTITY)
 append_profile(shadow,profile,.036,Transform3D(Basis.IDENTITY.scaled(Vector3(.79,.86,1)),Vector3(0,.06,.103)))
 Parts.block(frame,Vector3(0,-.05,.05),Vector3(1.47,.12,.34))
 var surfaces=[frame,shadow]
 var materials=[Fort.material(Color("788571"),false),Fort.material(Color("202a24"),false)]
 if with_ember:
  var ember=Furniture.tool()
  var mark=PackedVector2Array([Vector2(-.25,.24),Vector2(-.22,.67),Vector2(-.06,.84),
   Vector2(.03,1.25),Vector2(.23,.82),Vector2(.24,.41),Vector2(.16,.24)])
  append_profile(ember,mark,.02,Transform3D(Basis.IDENTITY,Vector3(0,0,.136)))
  surfaces.append(ember)
  materials.append(Geo.mat("b7512a",.1,.27))
 return Furniture.finish(surfaces,materials)

static func maze_wall_relief()->Mesh:
 var stone=Furniture.tool()
 var carving=Furniture.tool()
 Parts.rod(stone,Vector3.ZERO,Vector3(0,0,.16),.79)
 Parts.rod(carving,Vector3(0,0,.16),Vector3(0,0,.18),.63)
 var rim=TorusMesh.new()
 rim.rings=24;rim.ring_segments=6
 rim.inner_radius=.63;rim.outer_radius=.74
 stone.append_from(rim,0,Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,0,.177)))
 for turn in 6:
  var angle=TAU*turn/6.0
  var tip=Vector3(.42*cos(angle),.42*sin(angle),.207)
  Parts.rod(stone,Vector3(0,0,.205),tip,.048)
  Parts.oval(stone,tip,Vector3(.16,.16,.078))
 return Furniture.finish([stone,carving],[Fort.material(Color("a0a695"),false),Fort.material(Color("585f53"),false)])

static func maze_ironwork(screen:bool)->Mesh:
 var frame=Furniture.tool()
 var iron=Furniture.tool()
 if screen:
  for side in [-1,1]:
   Parts.rod(frame,Vector3(1.04*side,0,0),Vector3(1.04*side,2.59,0),.072)
   Parts.oval(frame,Vector3(1.04*side,2.60,0),Vector3(.18,.24,.18))
  for y in [.48,1.82]:
   Parts.rod(frame,Vector3(-1.02,y,0),Vector3(1.02,y,0),.043)
  for bar in range(-4,5):
   Parts.rod(iron,Vector3(bar*.218,.15,0),Vector3(bar*.218,2.28,0),.032)
 else:
  for side in [-1,1]:
   Parts.block(frame,Vector3(side*.72,.048,0),Vector3(.12,.09,1.55))
   Parts.block(frame,Vector3(0,.048,side*.72),Vector3(1.32,.09,.12))
  Parts.block(iron,Vector3(0,.012,0),Vector3(1.32,.018,1.32))
  for bar in range(-3,4):
   Parts.block(iron,Vector3(bar*.19,.05,0),Vector3(.06,.07,1.32))
 return Furniture.finish([frame,iron],[Geo.mat("777a6e",.22),Geo.mat("3e3b35",.36)])

static func maze_basin()->Mesh:
 var brass=Furniture.tool()
 var recess=Furniture.tool()
 for leg in 3:
  var angle=TAU*leg/3.0+.26
  var direction=Vector3(cos(angle),0,sin(angle))
  var foot=direction*.57
  var knee=direction*.25+Vector3.UP*.54
  Parts.rod(brass,foot,knee,.043)
  Parts.rod(brass,knee,direction*.14+Vector3.UP*1.31,.055)
 Parts.rod(brass,Vector3.UP*1.22,Vector3.UP*1.33,.26)
 Parts.rod(recess,Vector3.UP*1.32,Vector3.UP*1.51,.39)
 var lip=TorusMesh.new()
 lip.rings=24;lip.ring_segments=8
 lip.inner_radius=.34;lip.outer_radius=.47
 brass.append_from(lip,0,Transform3D(Basis.IDENTITY,Vector3.UP*1.53))
 return Furniture.finish([brass,recess],[Geo.mat("b28b4b",.36),Geo.mat("5e4f34",.28)])

static func maze_rubble()->Mesh:
 var dark=Furniture.tool()
 var pale=Furniture.tool()
 var stone=CylinderMesh.new()
 stone.radial_segments=5;stone.rings=0
 stone.bottom_radius=.50;stone.top_radius=.32;stone.height=1.0
 for i in 22:
  var angle=i*2.39996
  var spread=.17*sqrt(i)
  var width=.22+(.47 if i<5 else .19)*absf(sin(i*3.7))
  var height=width*(.35+.32*absf(cos(i)))
  var size=Vector3(width,height,width*(.52+.5*absf(sin(i))))
  var position=Vector3(spread*cos(angle),height*.41,spread*.78*sin(angle))
  var tilt=Basis(Vector3.UP,angle)*Basis(Vector3.FORWARD,.32*sin(i))
  var surface=pale if i%3==0 else dark
  surface.append_from(stone,0,Transform3D(tilt.scaled_local(size),position))
 return Furniture.finish([dark,pale],[Fort.material(Color("566265"),false),Fort.material(Color("aeb9b9"),false)])

static func append_profile(surface:SurfaceTool,outline:PackedVector2Array,depth:float,placement:Transform3D):
 # The block and torus surfaces are indexed. Loose profile vertices would be dropped.
 var profile=SurfaceTool.new()
 profile.create_from(Shapes.extrude(outline,depth),0)
 profile.index()
 surface.append_from(profile.commit(),0,placement)

static func arch()->Mesh:
 var stone=Furniture.tool()
 var cut=Furniture.tool()
 var bands=Furniture.tool()
 var spring=3.55
 for side in [-1,1]:
  var x=side*4.78
  for row in 5:
   Parts.block(stone,Vector3(x,(row+.5)*.71,0),Vector3(.55,.69,1.23))
  for y in [.10,.25,spring-.14,spring]:
   Parts.block(cut,Vector3(x,y,0),Vector3(.64,.12,1.42))
 # Tapered arch stones frame a clear nine-metre passage at floor level.
 for wedge in 13:
  var angle_start=(wedge+.025)*PI/13
  var angle_end=(wedge+.975)*PI/13
  var a=Vector2(cos(angle_start),sin(angle_start))
  var b=Vector2(cos(angle_end),sin(angle_end))
  var inner=Vector2(4.51,1.96)
  var outer=Vector2(5.12,2.54)
  var points=PackedVector2Array([a*inner,b*inner,b*outer,a*outer])
  var surface=cut if wedge%3==0 else stone
  append_profile(surface,points,1.42 if wedge==6 else 1.21,Transform3D(Basis.IDENTITY,Vector3.UP*spring))
 for side in [-1,1]:
  var center=Vector3(0,5.76,side*.76)
  var seal=PackedVector2Array([Vector2(-.20,0),Vector2(0,.23),Vector2(.20,0),Vector2(0,-.23)])
  append_profile(bands,seal,.11,Transform3D(Basis.IDENTITY,center))
 return Furniture.finish([stone,cut,bands],[Fort.material(Color("667774"),false),Fort.material(Color("a2aa97"),false),Geo.mat("a9834f",.48)])

static func stonework(carved:bool)->Mesh:
 var stone=Furniture.tool()
 var trim=Furniture.tool()
 var cap=Furniture.tool()
 var enamel=Furniture.tool()
 var depth=5.70 if carved else 2.92
 var width=2.73
 for row in 8:
  var center_y=(row+.50)*.58
  var join=depth*(.15 if row%2==0 else -.15)
  for limits in [Vector2(-depth*.5,join),Vector2(join,depth*.5)]:
   Parts.block(stone,Vector3(0,center_y,(limits.x+limits.y)*.5),Vector3(width,.565,limits.y-limits.x-.018))
 for y in [.14,.34,4.54]:
  Parts.block(trim,Vector3(0,y,0),Vector3(2.91,.18,depth+.065))
 Parts.block(cap,Vector3(0,4.73,0),Vector3(2.91,.18,depth+.065))
 if carved:
  var outline=PackedVector2Array([Vector2(-.98,0),Vector2(-.98,1.67),Vector2(-.74,2.05),Vector2(0,2.57),Vector2(.74,2.05),Vector2(.98,1.67),Vector2(.98,0)])
  var ring=TorusMesh.new()
  ring.inner_radius=.62;ring.outer_radius=.74;ring.rings=24;ring.ring_segments=6
  for side in [-1,1]:
   var facing=Basis(Vector3.UP,side*PI*.5)
   var face=Vector3(side*1.38,1.05,0)
   append_profile(trim,outline,.14,Transform3D(facing,face))
   trim.append_from(ring,0,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(side*1.52,2.37,0)))
   # Three folded waterways inside the medallion give the room its own emblem.
   for offset in [-.26,0.0,.26]:
    var points=[Vector3(side*1.56,2.20+offset,-.46),Vector3(side*1.56,2.32+offset,-.16),Vector3(side*1.56,2.28+offset,.14),Vector3(side*1.56,2.43+offset,.43)]
    for i in points.size()-1:Parts.rod(enamel,points[i],points[i+1],.055)
 var tools=[stone,trim,cap]
 var materials=[Fort.material(Color("5a6b66"),true),Fort.material(Color("939f90"),false),Fort.material(Color("39423e"),false)]
 if carved:
  tools.append(enamel)
  materials.append(Geo.mat("418176",.32))
 return Furniture.finish(tools,materials)

static func display(family:String)->Mesh:
 var frame=Furniture.tool()
 var trim=Furniture.tool()
 var glass=Furniture.tool()
 if family=="FloorSeal":
  Furniture.rounded_block(frame,Vector3.UP*.024,Vector3(1.40,.045,1.40),.26)
  for angle in [0.0,TAU/3.0,2.0*TAU/3.0]:
   var direction=Vector3(cos(angle),0,sin(angle))
   Parts.rod(trim,Vector3.UP*.051,Vector3.UP*.051+direction*.58,.033)
  return Furniture.finish([frame,trim],[Fort.material(Color("525e5a"),false),Geo.mat("a9834f",.48)])
 if family=="MazeOrbStand":
  Parts.block(frame,Vector3.UP*.12,Vector3(.91,.24,.91))
  Parts.block(frame,Vector3.UP*.88,Vector3(.57,1.36,.57))
  for y in [.36,1.54]:
   Parts.block(trim,Vector3.UP*y,Vector3(.67,.10,.67))
  for side in [-1,1]:
   Parts.block(trim,Vector3(side*.23,.90,.295),Vector3(.065,1.07,.030))
   Parts.block(trim,Vector3(side*.295,.90,-.23),Vector3(.030,1.07,.065))
  Parts.rod(trim,Vector3.UP*1.57,Vector3.UP*1.71,.35)
  Parts.oval(glass,Vector3.UP*1.94,Vector3(.53,.57,.53))
  return Furniture.finish([frame,trim,glass],[Fort.material(Color("404d48"),false),Geo.mat("a9834f",.48),Geo.mat("5f90a7",.32,.12)])
 if family=="SpecimenStand":
  for band in [[.12,.24,1.56],[.61,.77,1.17],[1.08,.17,1.55]]:
   Furniture.rounded_block(frame,Vector3(0,band[0],0),Vector3(band[2],band[1],band[2]),.13)
  Parts.rod(trim,Vector3.UP*1.17,Vector3.UP*1.28,.43)
  Parts.oval(glass,Vector3.UP*1.58,Vector3(.63,.67,.63))
  Parts.rod(trim,Vector3.UP*1.88,Vector3.UP*1.97,.23)
 else:
  for z in [-3.35,3.35]:
   Parts.block(frame,Vector3(0,.64,z),Vector3(1.62,1.28,.28))
  Parts.block(frame,Vector3(0,.28,0),Vector3(1.55,.16,7.06))
  Furniture.rounded_block(frame,Vector3.UP*1.27,Vector3(1.93,.20,7.62),.17)
  Parts.block(trim,Vector3(0,1.40,-.15),Vector3(1.43,.09,6.92))
  for i in 7:
   Furniture.bottle(glass,trim,Vector3(.12,1.45,(i-3)*.91),.51+(i%3)*.18)
 return Furniture.finish([frame,trim,glass],[Fort.material(Color("737366") if family=="SpecimenStand" else Color("60463a"),false),Geo.mat("a9834f",.48),Geo.mat("36685e",.18)])

static func lamps(brazier:bool)->Mesh:
 var stand=Furniture.tool()
 var wax=Furniture.tool()
 var flame=Furniture.tool()
 if brazier:
  Furniture.rounded_block(stand,Vector3.UP*.11,Vector3(1.13,.22,1.13),.16)
  Parts.rod(stand,Vector3.UP*.20,Vector3.UP*1.04,.21)
  Parts.rod(wax,Vector3.UP*.98,Vector3.UP*1.22,.36)
  Parts.oval(flame,Vector3(.05,1.43,0),Vector3(.31,.55,.28))
  Parts.oval(flame,Vector3(-.13,1.35,.10),Vector3(.20,.29,.20))
 else:
  Parts.rod(stand,Vector3.ZERO,Vector3.UP*.095,.34)
  Parts.rod(stand,Vector3.UP*.08,Vector3.UP*.62,.07)
  for x in [-.31,0.0,.31]:
   var height=.72+.14*(1.0-absf(x)/.31)
   var point=Vector3(x,.50,0)
   Parts.rod(stand,Vector3.UP*.38,point,.04)
   Parts.rod(wax,point,Vector3(x,height,0),.072)
   Parts.oval(flame,Vector3(x,height+.077,0),Vector3(.08,.18,.08))
 return Furniture.finish([stand,wax,flame],[Fort.material(Color("8d9586"),false) if brazier else Geo.mat("806840",.42),Geo.mat("514037",.48) if brazier else Geo.mat("e2d4ad"),Geo.mat("ffb43f",0.0,.74)])
