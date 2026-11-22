extends RefCounted
const Route=preload("res://scripts/forest/forest_frostpass.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Inn=preload("res://scripts/forest/forest_falan_inn_art.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
static var wall_lantern_mesh:Mesh
static var ribbed_melon:Mesh

static func build(parent:Node3D,boxes,id:int)->Dictionary:
 var root=Node3D.new()
 root.name="SnowpineMarketInterior" if id==Route.MARKET else "RidgewatchHallInterior"
 if id==Route.ABANIS_HALL:root.name="AbanisVillageHallInterior"
 if id==Route.STUDY_HALL:root.name="UniversityStudyHallInterior"
 if id==Route.WORKSHOP:root.name="UniversityWorkshopInterior"
 if id==Route.GLASSHOUSE:root.name="UniversityGlasshouseInterior"
 if id==Route.ABANIS_HOSPITAL:root.name="AbanisHospitalInterior"
 if id==Route.AUDITORIUM:root.name="UniversityAuditoriumInterior"
 if id==Route.ROOF_GARDEN:root.name="UniversityRoofGarden"
 parent.add_child(root)
 var room:Dictionary=Route.INTERIORS[id]
 var bounds=Rect2(room.origin-Vector2.ONE*1.5,Vector2(room.size)*3.0)
 if id!=Route.ROOF_GARDEN:shell(root,boxes,bounds,id)
 match id:
  Route.MARKET:market(root,boxes,room)
  Route.WORKSHOP:workshop(root,boxes,room)
  Route.GLASSHOUSE:glasshouse(root,boxes,room,bounds)
  Route.ABANIS_HOSPITAL:hospital(root,boxes,room)
  Route.ABANIS_HALL:abanis_hall(root,boxes,room)
  Route.AUDITORIUM:auditorium(root,boxes,room)
  Route.ROOF_GARDEN:roof_garden(root,boxes,room,bounds)
  _:hall(root,boxes,room)
 if Route.ROOF_STAIRS.has(id):
  stair_landing(root,boxes,Route.ROOF_STAIRS[id],"屋頂花園")
 if id==Route.STUDY_HALL:
  var study=Node3D.new()
  study.name="UniversityStudyInstruments"
  root.add_child(study)
  var left=fixture(room,"left_table")+Vector3(1.08,1.59,2.56)
  var right=fixture(room,"right_table")+Vector3(-.96,1.59,-2.2)
  var brass=Geo.mat("ae9060",.25)
  var crystal=Geo.mat("81b6d2",.10,.32)
  Geo.cylinder(study,left+Vector3.UP*.12,.37,.24,brass)
  Geo.cylinder(study,left+Vector3.UP*.42,.12,.64,brass)
  Geo.sphere(study,left+Vector3.UP*.84,Vector3.ONE*.31,crystal)
  for i in 3:
   var book=Geo.box(study,right+Vector3(i*.029,.08+i*.11,0),Vector3(.66,.102,.46),Geo.mat(["655a77","507675","906543"][i]))
   book.rotation.y=(i-1)*.13
  room_light(study,left+Vector3.UP*.90,Color("a4d1ef"),.57,4.8)
  for side in [-1,1]:
   var panel=fixture(room,"hearth")+Vector3(side*5.88,3.61,-.82)
   boxes.add(panel,Vector3(1.71,2.42,.13),Geo.mat("615141"))
   boxes.add(panel+Vector3.BACK*.09,Vector3(1.53,2.19,.09),Geo.mat("63827e"))
   for bar in 4:
    boxes.add(panel+Vector3(-.10*sin(bar),.66-bar*.43,.16),Vector3(.89+bar*.06,.028,.025),Geo.mat("cbd4bf"))
 var occupied={}
 for lot:Rect2i in room.fixtures.values():
  for z in range(lot.position.y,lot.end.y):
   for x in range(lot.position.x,lot.end.x):occupied[Vector2i(x,z)]=true
 return occupied

static func shell(root:Node3D,boxes,bounds:Rect2,id:int):
 var market_room=id==Route.MARKET
 var base=bounds.get_center()
 var wall_color=Color("c7aa82") if market_room else Color("71808a")
 var trim_color=Color("a18d6e") if market_room else Color("9ba7a6")
 var floor_color=Color("8b704f") if market_room else Color("76818a")
 var masonry=not market_room
 var planks=["a37e54","94714c","9b7752"] if market_room else []
 var lining=[]
 match id:
  Route.WORKSHOP:
   wall_color=Color("cfc097")
   trim_color=Color("735742")
   floor_color=Color("544233")
   masonry=false
   planks=["795a40","89684c","806047"]
  Route.GLASSHOUSE:
   wall_color=Color("a5ae99")
   trim_color=Color("637e71")
   floor_color=Color("a69473")
  Route.ABANIS_HOSPITAL:
   wall_color=Color("8f9e9c")
   trim_color=Color("747e76")
   floor_color=Color("805737")
   masonry=false
   planks=["b9895e","ac7b50","be9169"]
   lining=["bcc6c1","a9b9b8","b5c4c6"]
  Route.ABANIS_HALL:
   wall_color=Color("8d6845")
   trim_color=Color("664b37")
   floor_color=Color("564331")
   masonry=false
   planks=["876a51","7a6048","8b6d51"]
   lining=["b4895b","a88155","c29a65"]
 var oak=Fort.material(Color("674938"),false)
 var coping=Fort.material(trim_color,false)
 var wall=Fort.material(wall_color,masonry)
 var floor_mat=Fort.material(floor_color,false).duplicate()
 if planks.is_empty():floor_mat.set_shader_parameter("frost_paving",true)
 Geo.box(root,Vector3(base.x,-.15,base.y),Vector3(bounds.size.x,.30,bounds.size.y),floor_mat).name="WinterInteriorFloor"
 if not planks.is_empty():
  var tones=planks.map(func(tint):return Fort.material(Color(tint),false))
  for row in roundi(bounds.size.y/.75):
   for col in roundi(bounds.size.x/3.0):
    var x=bounds.position.x+(col+.5)*3.0
    var z=bounds.position.y+(row+.5)*.75
    boxes.add(Vector3(x,-.03,z),Vector3(2.975,.064,.723),tones[(row*11+col*7)%tones.size()],
     GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 var north=bounds.position.y
 var rail_height=1.3 if lining.is_empty() else .24
 boxes.add(Vector3(base.x,2.4,north),Vector3(bounds.size.x,4.8,.36),wall)
 boxes.add(Vector3(base.x,rail_height*.5-.04,north+.26),Vector3(bounds.size.x,rail_height-.08,.23),oak if market_room else coping)
 for side in [-1,1]:
  var x=bounds.position.x if side<0 else bounds.end.x
  boxes.add(Vector3(x,1.95,base.y),Vector3(.36,3.9,bounds.size.y),wall)
  boxes.add(Vector3(x,rail_height*.5,base.y),Vector3(.45 if lining.is_empty() else .53,rail_height,bounds.size.y),oak if market_room else coping)
  boxes.add(Vector3(x,3.91,base.y),Vector3(.54,.20,bounds.size.y+.22),coping)
  var wing=(bounds.size.x-4.0)*.5
  boxes.add(Vector3(side*(wing*.5+2.0),.44,bounds.end.y),Vector3(wing,.88,.47),wall)
  boxes.add(Vector3(side*(wing*.5+2.0),.93,bounds.end.y),Vector3(wing+.10,.16,.60),coping)
  boxes.add(Vector3(2.18*side,1.41,bounds.end.y-.21),Vector3(.49,2.82,.70),oak)
  boxes.add(Vector3(2.18*side,2.90,bounds.end.y-.24),Vector3(.63,.27,.78),coping)
  var window_x=2.70 if market_room and side>0 else bounds.size.x*.29*side
  window(root,boxes,window_x,north+.22,market_room,oak,coping)
  room_light(root,Vector3(window_x,3.35,north+1.30),Color("a5d0ff"),.62,7.8)
 boxes.add(Vector3(base.x,4.72,north+.25),Vector3(bounds.size.x+.2,.27,.57),coping)
 boxes.add(Vector3(0,.031,bounds.end.y-1.17),Vector3(3.94,.064,1.92),coping)
 if market_room:
  for x in [-12.,-4.,4.,12.]:
   boxes.add(Vector3(x,2.38,north+.26),Vector3(.36,4.68,.48),oak)
 if not lining.is_empty():
  var boards=lining.map(func(tint):return Fort.material(Color(tint),false))
  for col in roundi(bounds.size.x/.75):
   var x=bounds.position.x+(col+.5)*.75
   boxes.add(Vector3(x,2.33,north+.20),Vector3(.716,4.57,.08),boards[(col*7+floori(col*.2))%boards.size()])
  for col in roundi(bounds.size.y/.75):
   var z=north+(col+.5)*.75
   var finish=boards[(col*5+floori(col*.25))%boards.size()]
   for x in [bounds.position.x+.20,bounds.end.x-.20]:
    boxes.add(Vector3(x,1.95,z),Vector3(.08,3.84,.716),finish)

static func window(root:Node3D,boxes,x:float,z:float,market_room:bool,oak:Material,trim:Material):
 var center=Vector3(x,3.02,z)
 var width=2.22 if market_room else 1.72
 boxes.add(center,Vector3(width+.32,2.05,.21),oak)
 boxes.add(center+Vector3.BACK*.139,Vector3(width,1.73,.14),Geo.mat("a5c6dc",0.0,.29))
 for y in [-.88,0,.88]:
  boxes.add(center+Vector3(0,y,.24),Vector3(width+.16,.12,.09),trim)
 boxes.add(center+Vector3.BACK*.23,Vector3(.105,1.89,.11),oak)
 if market_room:
  var rod=center+Vector3(0,1.08,.33)
  Geo.beam(root,rod+Vector3.LEFT*1.6,rod+Vector3.RIGHT*1.6,.062,oak)
  for side in [-1,1]:
   var at=rod+Vector3(side*1.22,-.06,.15)
   hanging_cloth(root,at,Vector2(.63,1.86),0.0,Color("935844")).name="SnowpineCurtain"
 else:
  boxes.add(center+Vector3(0,-1.05,.17),Vector3(width+.56,.24,.51),trim)

static func fixture(room:Dictionary,key:String)->Vector3:
 var lot:Rect2i=room.fixtures[key]
 var at:Vector2=room.origin+Vector2(lot.position)*3.0+Vector2(lot.size-Vector2i.ONE)*1.5
 return Vector3(at.x,0,at.y)

static func plant_bed(root:Node3D,at:Vector3,span:Vector2,melons:bool):
 var rim=Fort.material(Color("a08b70"),false)
 var earth=Geo.mat("503b31")
 var greens=[Geo.mat("537044"),Geo.mat("7b9258"),Geo.mat("8da265")]
 Geo.box(root,at+Vector3.UP*.29,Vector3(span.x,.58,span.y),rim)
 Geo.box(root,at+Vector3.UP*.593,Vector3(span.x-.28,.055,span.y-.28),earth)
 if melons:
  melon_rows(root,at,span)
  return
 var rows=maxi(2,roundi(span.y/2.15))
 for row in rows:
  for col in [-1,1]:
   var stem=at+Vector3(col*span.x*.24,.63,((row+.5)/rows-.5)*span.y*.87)
   for petal in 3:
    var angle=petal*TAU/3.0+row*.7+col*.4
    var leaf=Geo.sphere(root,stem+Vector3(cos(angle)*.26,.17+petal*.04,sin(angle)*.26),
     Vector3(.86,.22,.39),greens[(row+petal)%greens.size()])
    leaf.rotation.y=-angle
   if (row+col)%2==0:
    Geo.sphere(root,stem+Vector3.UP*.35,Vector3(.34,.35,.34),Geo.mat("a95a6d"))

static func melon_rows(root:Node3D,at:Vector3,span:Vector2):
 var bed=Node3D.new()
 bed.name="UniversityMelonBed%d"%root.get_child_count()
 bed.position=at
 root.add_child(bed)
 var trim=Fort.material(Color("bba894"),false)
 var soil=Geo.mat("69503c")
 var stem=Geo.mat("4d663b")
 var leaves=[Geo.mat("547645"),Geo.mat("769653"),Geo.mat("98ab6a")]
 for side in [-1,1]:
  Geo.box(bed,Vector3(side*(span.x*.5-.10),.63,0),Vector3(.21,.19,span.y),trim)
  Geo.box(bed,Vector3(0,.63,side*(span.y*.5-.10)),Vector3(span.x-.38,.19,.21),trim)
 var rows=maxi(2,roundi(span.y/1.9))
 var spacing=(span.y-1.30)/rows
 for side in [-1,1]:
  var x=side*span.x*.24
  Geo.box(bed,Vector3(x,.63,0),Vector3(.93,.13,span.y-.58),soil)
  for row in rows:
   var z=(row-(rows-1)*.5)*spacing
   var crown=Vector3(x+sin(row*1.4+side)*.23,.73,z)
   var tip=crown+Vector3(-side*.70,.09,spacing*.26)
   Geo.beam(bed,crown-Vector3.BACK*spacing*.34,tip,.055,stem)
   for petal in 4:
    var angle=petal*TAU/4.0+row*.59+side*.6
    var leaf=Geo.sphere(bed,crown+Vector3(cos(angle)*.36,.13+petal*.028,sin(angle)*.36),
     Vector3(.89,.15,.48),leaves[(row+petal)%leaves.size()])
    leaf.rotation=Vector3(.20*sin(angle),-angle,.18*cos(angle))
   Geo.sphere(bed,tip,Vector3(.54,.12,.35),leaves[1]).rotation.y=side*.57
   if (row+side)%3==0:continue
   var p=crown+Vector3(side*.53,.22,-.24)
   var melon=Geo.mesh(bed,melon_mesh(),p,null)
   melon.name="UniversityRibbedMelon"
   melon.scale=Vector3.ONE*(.85+.15*absf(sin(row+side)))
   melon.rotation.y=row*.71+side
   Geo.beam(bed,p+Vector3.UP*.21,p+Vector3(-side*.05,.38,.05),.081,stem)

static func melon_mesh()->Mesh:
 if ribbed_melon!=null:return ribbed_melon
 var rind=Geo.mat("ffffff").duplicate() as StandardMaterial3D
 rind.vertex_color_use_as_albedo=true
 rind.vertex_color_is_srgb=true
 var tool=Furniture.tool()
 tool.set_material(rind)
 for row in 11:
  for col in 32:
   for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
    var phi=PI*(row+corner.y)/11.0
    var theta=TAU*(col+corner.x)/32.0
    var normal=Vector3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))
    var rib=.5+.5*sin(theta*8.0)
    tool.set_normal(normal)
    tool.set_color(Color("9c8b49").lerp(Color("e3be70"),rib))
    tool.add_vertex(normal*Vector3(.40,.29,.37)*(.93+.07*rib))
 ribbed_melon=tool.commit()
 return ribbed_melon

static func stair_landing(root:Node3D,boxes,at:Vector2,caption:String,recessed:bool=false):
 var stone=Fort.material(Color("879ba6"),true)
 var trim=Fort.material(Color("adbec3"),false)
 var nosing=Fort.material(Color("596f7e"),false) if recessed else trim
 var rail=Geo.mat("51423c")
 var steps=Node3D.new()
 steps.name="UniversityGardenStairs"+caption
 steps.position=Vector3(at.x,0,at.y)
 root.add_child(steps)
 var first_z=1.50 if recessed else -.32
 var direction=1.0 if recessed else -1.0
 var base=-1.30 if recessed else 0.0
 for i in 5:
  var top=(-.12-.22*i) if recessed else (.16+.17*i)
  var z=first_z+direction*(i+.5)*.52
  var height=top-base
  Geo.box(steps,Vector3(0,base+height*.5,z),Vector3(2.50,height,.52),stone).name="UniversityStoneTread"
  boxes.add(steps.position+Vector3(0,top-.023,z+.21),Vector3(2.52,.08,.13),nosing)
 for side in [-1,1]:
  var x=side*1.36
  var wall_z=first_z+direction*1.49
  Geo.box(steps,Vector3(x,(base+.48)*.5,wall_z),Vector3(.28,.48-base,2.98),stone)
  Geo.box(steps,Vector3(x,.51,wall_z),Vector3(.35,.14,3.06),trim)
  for i in [0,1]:
   var z=first_z+direction*(.18+i*2.58)
   var y=1.07+(.23*i if not recessed else 0.0)
   Geo.box(steps,Vector3(x,(y+.53)*.5,z),Vector3(.16,y-.53,.16),rail)
   Geo.box(steps,Vector3(x,y,z),Vector3(.24,.12,.24),trim)
  Geo.beam(steps,Vector3(x,1.06,first_z+direction*.18),
   Vector3(x,1.06+(0.0 if recessed else .23),first_z+direction*2.76),.10,rail)
 var end_z=first_z+direction*2.92
 if recessed:
  Geo.box(steps,Vector3(0,-.32,end_z),Vector3(2.82,1.96,.19),stone)
  Geo.box(steps,Vector3(0,-.19,end_z-.11),Vector3(1.93,1.61,.09),Geo.mat("495763"))
 var plaque=Geo.box(steps,Vector3(0,1.65,end_z),Vector3(2.78,.61,.17),rail)
 for side in [-1,1]:
  Geo.box(steps,Vector3(side*1.36,1.37,end_z),Vector3(.19,1.66,.22),rail)
  wall_lantern(steps,Vector3(side*1.34,1.41,end_z-direction*.10))
 var sign=Label3D.new()
 sign.name="UniversityStairSign"
 sign.position=plaque.position-Vector3.BACK*direction*.095
 sign.rotation.y=PI if recessed else 0.0
 sign.text=caption
 sign.font_size=43
 sign.pixel_size=.012
 sign.modulate=Color("eef3e3")
 steps.add_child(sign)

static func roof_garden(root:Node3D,boxes,room:Dictionary,bounds:Rect2):
 var stone=Fort.material(Color("7f99a7"),true)
 var snow=Fort.material(Color("e1edf0"),false)
 var paving=Fort.material(Color("9caeb5"),false).duplicate()
 paving.set_shader_parameter("frost_paving",true)
 Geo.box(root,Vector3(0,-2.90,0),Vector3(bounds.size.x,3.20,bounds.size.y),stone)
 var edge_z=bounds.end.y-3.0
 Geo.box(root,Vector3(0,-.65,(bounds.position.y+edge_z)*.5),
  Vector3(bounds.size.x,1.30,bounds.size.y-3.0),paving).name="UniversityRoofPaving"
 var edge_x=bounds.position.x
 for key in ["west_stair","east_stair"]:
  var well=fixture(room,key).x
  var right=well-1.5
  Geo.box(root,Vector3((edge_x+right)*.5,-.65,edge_z+1.5),Vector3(right-edge_x,1.30,3.0),paving)
  edge_x=well+1.5
 Geo.box(root,Vector3((edge_x+bounds.end.x)*.5,-.65,edge_z+1.5),Vector3(bounds.end.x-edge_x,1.30,3.0),paving)
 for side in [-1,1]:
  var at=Vector3(side*(bounds.size.x*.5-.13),-1.06,0)
  boxes.add(at,Vector3(.61,.29,bounds.size.y+.56),snow)
  var roof_shape=PackedVector2Array([Vector2(-7.5,0),Vector2(0,3.8),Vector2(7.5,0)])
  Geo.mesh(root,Shapes.extrude(roof_shape,20.0),Vector3(side*29.2,-5.3,-3),stone)
  Geo.mesh(root,Shapes.extrude(roof_shape,20.3),Vector3(side*29.2,-5.03,-3),snow)
 var garden=Node3D.new()
 garden.name="UniversityRoofPlanters"
 root.add_child(garden)
 for key:String in room.fixtures:
  if key.ends_with("_stair"):continue
  var span=Vector2(room.fixtures[key].size)*3.0-Vector2.ONE*.50
  plant_bed(garden,fixture(room,key),span,key=="east_melons" or key=="east_vines")
 for hall:int in Route.ROOF_LANDINGS:
  var label="禮堂" if hall==Route.AUDITORIUM else "研習室"
  stair_landing(root,boxes,Route.ROOF_LANDINGS[hall],label,true)

static func hospital(root:Node3D,boxes,room:Dictionary):
 var oak=Fort.material(Color("815637"),false)
 var trim=Fort.material(Color("bd905b"),false)
 var pewter=Geo.mat("536a6e",.19)
 var linen=Geo.mat("e4d8b7")
 var bed=Furniture.bed(3.65,4.13,1)
 bed.surface_set_material(2,Fort.material(Color("758e87"),false))
 var ward=fixture(room,"ward")
 var beds=Node3D.new()
 beds.name="AbanisWardBeds"
 root.add_child(beds)
 for row in [-1,0,1]:
  Geo.mesh(beds,bed,ward+Vector3(0,0,row*3.61),null).rotation.y=PI*.5
 for row in [-1,1]:
  var at=ward+Vector3(0,0,row*1.79)
  for side in [-1,1]:
   Geo.beam(beds,at+Vector3(side*2.04,.1,0),at+Vector3(side*2.04,2.64,0),.068,oak)
  hanging_cloth(beds,at+Vector3(0,2.57,0),Vector2(3.94,1.58),0.0,Color("c3c8b6")).name="AbanisWardCurtain"
 var counter=fixture(room,"counter")
 var dispensary=Node3D.new()
 dispensary.name="AbanisDispensary"
 dispensary.position=counter
 root.add_child(dispensary)
 Geo.mesh(dispensary,trestle(Vector3(1.17,1.55,8.12),oak,trim),Vector3.LEFT*1.65,null).name="AbanisHospitalCounter"
 var wing=trestle(Vector3(1.20,1.55,3.63),oak,trim)
 for end in [-1,1]:
  Geo.mesh(dispensary,wing,Vector3(.75,0,end*3.44),null).rotation.y=PI*.5
  Inn.stool(dispensary,Vector3(.83,0,end*1.37),trim,pewter)
  Geo.cylinder(dispensary,Vector3(-1.63,1.62,end*2.29),.49,.11,Geo.mat("97835d"),false,.55)
 var paperwork=Furniture.tool()
 var ink=Furniture.tool()
 Furniture.ledger(paperwork,ink,Vector3(-1.63,1.59,0),Vector2(.79,1.10))
 Furniture.quill(ink,paperwork,Vector3(-1.39,1.56,-.83))
 Geo.mesh(dispensary,Furniture.finish([paperwork,ink],[linen,Geo.mat("534333")]),Vector3.ZERO,null)
 var glass=Furniture.tool()
 var labels=Furniture.tool()
 for i in 3:
  Furniture.bottle(glass,labels,Vector3(.36+i*.54,1.55,-3.46),.59-i*.065)
 Geo.mesh(dispensary,Furniture.finish([glass,labels],[Geo.mat("597f79"),linen]),Vector3.ZERO,null)
 Geo.mesh(dispensary,Shapes.urn_mesh(),Vector3(1.89,1.55,3.44),Geo.mat("77979a")).scale=Vector3.ONE*.72
 var cabinet=fixture(room,"cabinet")+Vector3.FORWARD*.35
 Geo.mesh(root,abanis_drawers(7.82,1.72,3.18,7,5,Geo.mat("4d5149"),trim),cabinet,null).name="AbanisApothecaryDrawers"
 for side in [-1,1]:
  Inn.notice(boxes,Vector3(side*5.82,2.84,room.origin.y-1.12),1.18,oak,linen,false)
  wall_lantern(root,Vector3(side*3.97,3.72,room.origin.y-1.10))
 room_light(root,counter+Vector3(-1.4,3.81,-.65),Color("ffedcb"),1.10,12.0)
 room_light(root,ward+Vector3(1.5,3.3,0),Color("e1f0dc"),.82,11.8)
 rug(root,boxes,Vector2(-7.25,4.10),Vector2(3.68,6.35),Color("a1916b"))
 abanis_dispensary_rug(root,boxes,Vector2(counter.x-.41,counter.z))

static func abanis_dispensary_rug(root:Node3D,boxes,center:Vector2):
 var span=Vector2(7.44,10.20)
 rug(root,boxes,center,span,Color("4e6768"))
 var colors=[Geo.mat("384d53"),Geo.mat("729484"),Geo.mat("73989b")]
 var tiles=[Furniture.tool(),Furniture.tool(),Furniture.tool()]
 for z in 6:
  for x in 5:
   var p=Vector3((x-2)*1.28,.094,(z-2.5)*1.47)
   Shapes.quad(tiles[(z+2*x)%3],p+Vector3.FORWARD*.71,p+Vector3.RIGHT*.62,
    p+Vector3.BACK*.71,p+Vector3.LEFT*.62)
 Geo.mesh(root,Furniture.finish(tiles,colors),Vector3(center.x,0,center.y),null).name="AbanisDispensaryRunner"

static func abanis_drawers(width:float,depth:float,height:float,columns:int,rows:int,wood:Material,trim:Material)->Mesh:
 Lamps.prepare_primitives()
 var casework=Furniture.tool()
 var fronts=Furniture.tool()
 var brass=Furniture.tool()
 Lamps.block(casework,Vector3.UP*height*.5,Vector3(width,height,depth))
 for y in [.09,height-.10]:
  Furniture.rounded_block(fronts,Vector3.UP*y,Vector3(width+.11,.18,depth+.10),.13)
 var panel=Vector2((width-.32)/columns,(height-.40)/rows)
 for row in rows:
  for col in columns:
   var p=Vector3((col+.5)*panel.x-(width-.32)*.5,.20+(row+.5)*panel.y,depth*.5+.037)
   Lamps.block(fronts,p,Vector3(panel.x-.067,panel.y-.070,.072))
   Lamps.block(casework,p+Vector3.BACK*.039,Vector3(panel.x-.106,panel.y-.112,.016))
   Lamps.oval(brass,p+Vector3.BACK*.061,Vector3(.112,.077,.089))
 return Furniture.finish([casework,fronts,brass],[wood,trim,Geo.mat("af9466",.24)])

static func auditorium(root:Node3D,boxes,room:Dictionary):
 var oak=Fort.material(Color("664b3a"),false)
 var wood=Fort.material(Color("998066"),false)
 var trim=Fort.material(Color("af9980"),false)
 var stage_at=fixture(room,"stage")
 var stage=Geo.box(root,stage_at+Vector3.UP*.32,Vector3(25.7,.64,5.55),oak)
 stage.name="UniversityLecternStage"
 for plank in 7:
  boxes.add(stage_at+Vector3(0,.649,(plank-3)*.76),Vector3(25.55,.022,.73),wood)
 Geo.box(root,stage_at+Vector3(0,.206,2.63),Vector3(10.4,.41,.83),trim)
 var lectern=stage_at+Vector3(0,.65,.72)
 Geo.cylinder(root,lectern+Vector3.UP*.078,.55,.156,oak)
 Geo.box(root,lectern+Vector3.UP*.79,Vector3(.47,1.48,.49),oak)
 Geo.box(root,lectern+Vector3.UP*1.56,Vector3(1.37,.17,.96),trim).rotation.x=-.19
 for side in [-1,1]:
  var seats=fixture(room,"west_seats" if side<0 else "east_seats")
  for row in 4:
   Court.bench(boxes,seats+Vector3(0,0,(row-1.5)*2.65),false,10.01,oak)
  var front=stage_at+Vector3(side*8.6,4.98,-2.01)
  hanging_cloth(root,front,Vector2(2.58,3.47),.35,Color("485975"))
  wall_lantern(root,front+Vector3(-side*2.86,-1.36,.11))
 room_light(root,lectern+Vector3.UP*3.53,Color("ffddaa"),1.42,12.0)
 rug(root,boxes,Vector2(0,1.55),Vector2(5.36,19.8),Color("694e6b"))

static func workshop(root:Node3D,boxes,room:Dictionary):
 var oak=Fort.material(Color("624634"),false)
 var cut=Fort.material(Color("a47e54"),false)
 var stone=Fort.material(Color("8b8876"),false)
 var iron=Geo.mat("3e474a",.32)
 var steel=Geo.mat("a8bdc1",.35)
 var bench=fixture(room,"bench")
 var work_at=bench+Vector3(.24,0,3.17)
 var work=Geo.mesh(root,trestle(Vector3(4.22,1.51,4.24),oak,cut),work_at,null)
 work.name="UniversityArcaneWorkbench"
 boxes.add(bench+Vector3(-.82,.025,-2.55),Vector3(3.48,.052,6.62),stone)
 workshop_forges(root,bench+Vector3(-1.44,0,-2.55))
 workshop_weapon_rack(root,fixture(room,"cases"),oak,cut,iron,steel)
 var bookcase=Geo.mesh(root,Furniture.bookcase(4.65,8.5,true),fixture(room,"cabinet"),null)
 bookcase.rotation.y=-PI*.5
 var top=work_at+Vector3.UP*1.51
 var anvil=Shapes.extrude(PackedVector2Array([
  Vector2(-.50,0),Vector2(-.50,.13),Vector2(-.26,.20),Vector2(-.26,.35),
  Vector2(-.57,.43),Vector2(-.57,.57),Vector2(.73,.57),Vector2(.51,.43),
  Vector2(.18,.32),Vector2(.18,.19),Vector2(.41,.13),Vector2(.41,0)]),.50)
 Geo.mesh(root,anvil,top+Vector3(.56,0,-.22),iron).rotation.y=.27
 Geo.box(root,top+Vector3(.62,.61,-.22),Vector3(.59,.07,.26),steel).rotation.y=.27
 var hammer=top+Vector3(1.25,.08,1.20)
 Geo.beam(root,hammer,hammer+Vector3(-.73,0,-.39),.056,cut)
 Geo.box(root,hammer+Vector3(-.68,.07,-.38),Vector3(.32,.20,.21),iron).rotation.y=-1.04
 for i in 3:
  var ingot=Geo.box(root,top+Vector3(-1.46+i*.48,.10,-1.54+i*.062),Vector3(.39,.19,.73),steel)
  ingot.rotation.y=.21-i*.27
 Geo.mesh(root,Shapes.urn_mesh(),top+Vector3(-1.37,0,.90),iron).scale=Vector3.ONE*.67
 var notes=Furniture.tool()
 var binding=Furniture.tool()
 Furniture.ledger(notes,binding,Vector3.ZERO,Vector2(1.35,1.09))
 Furniture.quill(binding,notes,Vector3(.86,0,.15))
 Geo.mesh(root,Furniture.finish([notes,binding],[Geo.mat("e8d4af"),oak]),top+Vector3(-.83,.015,-.28),null)
 Goods.crate(root,boxes,bench+Vector3(-2.22,0,3.43),1.14,true,oak,cut)

static func workshop_forges(root:Node3D,at:Vector3):
 var stone=Furniture.tool()
 var dark=Furniture.tool()
 var coals=Furniture.tool()
 for z in [-2.16,0.0,2.16]:
  var hearth=Vector3(0,0,z)
  Lamps.block(stone,hearth+Vector3(0,.13,0),Vector3(1.71,.26,2.02))
  Lamps.block(stone,hearth+Vector3(0,.44,0),Vector3(1.52,.44,1.83))
  for side in [-1,1]:
   Lamps.block(stone,hearth+Vector3(0,1.04,side*.67),Vector3(1.48,.86,.46))
  Lamps.block(dark,hearth+Vector3(-.44,1.05,0),Vector3(.17,.88,.94))
  Lamps.block(stone,hearth+Vector3(-.10,1.53,0),Vector3(1.51,.25,1.83))
  Lamps.block(stone,hearth+Vector3(-.29,1.78,0),Vector3(1.12,.29,1.34))
  Lamps.block(stone,hearth+Vector3(-.42,2.51,0),Vector3(.73,1.35,.83))
  Lamps.block(stone,hearth+Vector3(-.42,3.19,0),Vector3(.90,.25,1.00))
  Lamps.block(dark,hearth+Vector3(.24,.665,0),Vector3(.93,.09,.88))
  for i in 4:
   var ember=hearth+Vector3(.24+(i%2)*.19,.74,-.33+i*.21)
   Lamps.oval(coals,ember,Vector3(.46,.20+(i%3)*.14,.26))
   Lamps.rod(dark,hearth+Vector3(.71,.72,-.33+i*.22),hearth+Vector3(.71,1.14,-.33+i*.22),.024)
  room_light(root,at+hearth+Vector3(1.08,1.20,0),Color("ffc18d"),.68,4.7)
 Geo.mesh(root,Furniture.finish([stone,dark,coals],[Fort.material(Color("a69b81")),Geo.mat("3c302b"),
  Geo.mat("e55e25",0.0,.89)]),at,null).name="UniversityForgeBank"

static func workshop_weapon_rack(root:Node3D,at:Vector3,oak:Material,cut:Material,iron:Material,steel:Material):
 var rack=Furniture.tool()
 var fittings=Furniture.tool()
 var brass=Geo.mat("a87e4c",.31)
 for z in [-4.89,0.0,4.89]:
  Lamps.block(rack,Vector3(0,.13,z),Vector3(1.81,.26,.44))
  Lamps.block(rack,Vector3(.27,1.56,z),Vector3(.29,3.12,.32))
  Lamps.block(fittings,Vector3(.12,2.94,z),Vector3(.07,.29,.30))
 for y in [.37,1.16,2.72,3.07]:
  Lamps.block(rack,Vector3(.09,y,0),Vector3(.46,.19,10.03))
 Geo.mesh(root,Furniture.finish([rack,fittings],[oak,iron]),at,null).name="UniversityWeaponRack"
 var blade=Shapes.extrude(PackedVector2Array([Vector2(-.11,0),Vector2(.11,0),Vector2(.088,1.44),
  Vector2(0,1.62),Vector2(-.088,1.44)]),.10)
 for i in 4:
  var z=-4.19+i*1.09
  var hilt=at+Vector3(-.22,.92,z)
  var sword=Geo.mesh(root,blade,hilt,steel)
  sword.rotation.y=-PI*.5
  sword.scale.y=.91+(i%3)*.11
  Geo.beam(root,hilt+Vector3.FORWARD*.27,hilt+Vector3.BACK*.27,.050,brass)
  Geo.beam(root,hilt-Vector3.UP*.39,hilt,.068,iron)
  Geo.sphere(root,hilt-Vector3.UP*.40,Vector3.ONE*.16,brass)
 for z in [.99,2.24,3.57]:
  var bow=at+Vector3(-.30,1.65,z)
  var tip=Vector3(0,1.09,.32)
  var last=bow+Vector3(0,-tip.y,tip.z)
  for segment in range(1,7):
   var t=float(segment)/3.0-1.0
   var next=bow+Vector3(0,t*tip.y,tip.z-.51*(1.0-t*t))
   Geo.beam(root,last,next,.068,cut)
   last=next
  Geo.beam(root,bow+Vector3(0,-tip.y,tip.z),bow+tip,.014,Geo.mat("b6a88b"))
 var shield=at+Vector3(-.57,1.03,4.33)
 Geo.sphere(root,shield,Vector3(.23,1.12,.98),iron)
 Geo.sphere(root,shield+Vector3.LEFT*.11,Vector3(.14,.92,.80),Geo.mat("587a76"))
 Geo.sphere(root,shield+Vector3.LEFT*.18,Vector3(.16,.30,.30),brass)

static func glasshouse(root:Node3D,boxes,room:Dictionary,bounds:Rect2):
 var oak=Fort.material(Color("675747"),false)
 var trim=Fort.material(Color("ad9369"),false)
 var brick=Fort.material(Color("a7785a"),false)
 var iron=Geo.mat("41645b",.18)
 var copper=Geo.mat("a7895d",.31)
 var soil=Geo.mat("483731")
 var tilled=Fort.material(Color("ab794f"),false)
 var earth=Fort.material(Color("78543b"),false)
 var timber=Fort.material(Color("79543a"),false)
 var furrow=Shapes.extrude(PackedVector2Array([Vector2(-.46,.08),Vector2(-.38,.25),Vector2(-.24,.34),
  Vector2(.24,.34),Vector2(.38,.25),Vector2(.46,.08)]),9.94)
 var carrot=CylinderMesh.new()
 carrot.bottom_radius=.08
 carrot.top_radius=.16
 carrot.height=.18
 carrot.radial_segments=12
 var carrot_skin=Geo.mat("c46c39")
 var panes=[Geo.mat("9dbeb9",.15,.17),Geo.mat("b3d2c6",.14,.20)]
 var plants=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
 var flora={"leafy_shrub":[],"flowers_ivory":[],"flowers_coral":[],"flowers_blue":[]}
 var growing=Node3D.new()
 growing.name="UniversityGrowingBeds"
 root.add_child(growing)
 Lamps.prepare_primitives()
 for side in [-1,1]:
  var bed=fixture(room,"west_bed" if side<0 else "east_bed")
  var plot=Node3D.new()
  plot.name="UniversityWestCropPlot" if side<0 else "UniversityEastCropPlot"
  plot.position=bed
  growing.add_child(plot)
  boxes.add(bed+Vector3.UP*.055,Vector3(4.76,.11,10.62),earth)
  var fence=Furniture.tool()
  for y in [.45,.85]:
   Lamps.block(fence,Vector3(side*2.38,y,0),Vector3(.13,.14,10.38))
   Lamps.block(fence,Vector3(0,y,-5.18),Vector3(4.76,.14,.13))
  for z in [-5.18,-2.59,0.0,2.59,5.18]:
   Lamps.block(fence,Vector3(side*2.38,.56,z),Vector3(.22,1.12,.22))
  for x in [0.0,-side*2.38]:
   Lamps.block(fence,Vector3(x,.56,-5.18),Vector3(.22,1.12,.22))
  Geo.mesh(plot,Furniture.finish([fence],[timber]),Vector3.ZERO,null).name="UniversityPlotFence"
  for row in 4:
   var x=(row-1.5)*1.08
   Geo.mesh(plot,furrow,Vector3(x,0,0),tilled).name="UniversityCropFurrow%d"%row
   for plant in 7:
    var stem=bed+Vector3(x,.34,(plant-3)*1.39)
    var turn=Basis(Vector3.UP,float(plant)*1.28+row*.71)
    if side<0:
     Geo.mesh(plot,carrot,stem-bed+Vector3.UP*.07,carrot_skin)
     flora.leafy_shrub.append(Transform3D(turn.scaled(Vector3(.23,.33,.23)),stem+Vector3.UP*.085))
    else:
     var bloom=["flowers_ivory","flowers_coral","flowers_blue"][row%3]
     flora[bloom].append(Transform3D(turn.scaled(Vector3.ONE*(1.28+(plant%3)*.18)),stem))
     flora.leafy_shrub.append(Transform3D(turn.scaled(Vector3(.16,.16,.19)),stem))
  var edge=bounds.position.x if side<0 else bounds.end.x
  for row in 6:
   var panel=Vector3(edge-side*.23,2.81,bounds.position.y+3.12+row*4.05)
   for half in [-1,1]:
    boxes.add(panel+Vector3(0,0,half*.96),Vector3(.11,2.33,1.86),panes[(row+half+1)%2])
   var frame=panel+Vector3(-side*.13,0,0)
   for rail in [-1.17,.57,1.17]:
    boxes.add(frame+Vector3.UP*rail,Vector3(.19,.10,3.98),iron)
   for post in [-1.95,0.0,1.95]:
    boxes.add(frame+Vector3.BACK*post,Vector3(.19,2.39,.12),iron)
 var table=fixture(room,"potting")
 Geo.mesh(root,trestle(Vector3(7.24,1.37,2.31),oak,trim),table,null).name="UniversityBotanicalWorkbench"
 for i in 4:
  var pot=table+Vector3(.11+i*.77,1.37,-.17+sin(i)*.35)
  Geo.mesh(root,Shapes.urn_mesh(),pot,brick).scale=Vector3.ONE*(.60+i*.09)
  var rim=pot+Vector3.UP*(.43+i*.055)
  Geo.cylinder(root,rim,.232+i*.034,.035,soil)
  var bloom=["flowers_ivory","flowers_blue"][i%2]
  flora[bloom].append(Transform3D(Basis(Vector3.UP,float(i)).scaled(Vector3.ONE*.66),rim))
 for asset:String in flora:
  plants.batch(growing,asset,flora[asset])
 var can=table+Vector3(-2.62,1.37,.06)
 Geo.cylinder(root,can+Vector3.UP*.32,.32,.64,iron,false,.35)
 Geo.cylinder(root,can+Vector3.UP*.64,.36,.057,copper)
 Geo.torus(root,can+Vector3(-.32,.37,0),.222,.274,copper).rotation.x=PI*.5
 Geo.beam(root,can+Vector3(.21,.27,0),can+Vector3(.83,.67,.11),.057,copper)
 Geo.beam(root,can+Vector3(.78,.64,.105),can+Vector3(.88,.71,.12),.11,copper)
 var notes=Furniture.tool()
 var binding=Furniture.tool()
 Furniture.ledger(notes,binding,Vector3.ZERO,Vector2(1.02,.79))
 Geo.mesh(root,Furniture.finish([notes,binding],[Geo.mat("e1d9b9"),oak]),table+Vector3(-1.24,1.39,.37),null)
 for side in [-1,1]:
  room_light(root,Vector3(side*7.2,4.13,-4.2),Color("d6ebc9"),.88,10.8)

static func market(root:Node3D,boxes,room:Dictionary):
 var oak=Fort.material(Color("704a33"),false)
 var plank=Fort.material(Color("a2754d"),false)
 var trim=Fort.material(Color("c19458"),false)
 var iron=Geo.mat("484749",.23)
 var counter=fixture(room,"counter")
 var desk=Geo.mesh(root,trestle(Vector3(8.78,1.55,2.46),oak,plank),counter,null)
 desk.name="SnowpineMarketCounter"
 boxes.add(counter+Vector3(0,.83,1.06),Vector3(8.13,1.38,.22),oak)
 for x in [-3.04,-1.02,1.02,3.04]:
  boxes.add(counter+Vector3(x,.77,1.196),Vector3(1.82,.93,.075),trim)
  boxes.add(counter+Vector3(x,.77,1.241),Vector3(1.57,.72,.026),plank)
  boxes.add(counter+Vector3(x,1.19,1.242),Vector3(.26,.058,.058),iron)
 boxes.add(counter+Vector3(0,.27,1.21),Vector3(8.31,.17,.17),plank)
 counter_scale(root,counter+Vector3(-2.42,1.55,.06))
 var book=Furniture.tool()
 var cover=Furniture.tool()
 Furniture.ledger(book,cover,Vector3.ZERO,Vector2(1.04,.70))
 Furniture.quill(cover,book,Vector3(.70,0,.10))
 Geo.mesh(root,Furniture.finish([book,cover],[Geo.mat("e0c991"),Geo.mat("674c35")]),
  counter+Vector3(.42,1.57,.15),null).name="SnowpineLedger"
 Geo.mesh(root,Shapes.urn_mesh(),counter+Vector3(3.0,1.55,.26),Geo.mat("55736e")).name="SnowpineGlazedJar"
 var cupboard=Geo.mesh(root,Furniture.cabinet(4.49,6.52,false),fixture(room,"cupboard"),null)
 cupboard.name="SnowpineCupboard"
 cupboard.rotation.y=-PI*.5
 Goods.produce(root,boxes,fixture(room,"produce")+Vector3.LEFT*1.37,10053,oak,plank)
 Goods.produce(root,boxes,fixture(room,"produce")+Vector3.RIGHT*1.37,10057,oak,plank)
 var stock=fixture(room,"stock")
 Goods.barrel(root,stock+Vector3.BACK*1.17,.63,oak,plank,iron)
 Goods.crate(root,boxes,stock+Vector3.FORWARD*1.14,1.34,true,oak,plank)
 Goods.wares(root,boxes,fixture(room,"sundries"),oak,plank)
 Inn.notice(boxes,Vector3(-1.18,2.62,room.origin.y-1.26),2.26,oak,Geo.mat("ddc69b"),false)
 wall_lantern(root,Vector3(-3.76,3.39,room.origin.y-1.09))
 Goods.produce(root,boxes,fixture(room,"display"),10536,oak,plank)
 rug(root,boxes,Vector2(0,2.5),Vector2(4.3,8.7),Color("934e3b"))
 room_light(root,counter+Vector3(0,3.65,1),Color("ffd096"),1.12,12.0)

static func abanis_hall(root:Node3D,boxes,room:Dictionary):
 var oak=Fort.material(Color("78513a"),false)
 var plank=Fort.material(Color("a78152"),false)
 var iron=Geo.mat("34383a",.32)
 var brass=Geo.mat("ad8e5d",.32)
 var fire=fixture(room,"hearth")
 var stove=Node3D.new()
 stove.name="AbanisParlorStove"
 stove.position=fire+Vector3.BACK*.11
 root.add_child(stove)
 var hearth_stone=Fort.material(Color("77746a"),false)
 for x in [-1,0,1]:
  for z in [-1,0,1]:
   boxes.add(fire+Vector3(x*1.24,.065,z*.85),Vector3(1.22,.13,.83),hearth_stone)
 Geo.box(stove,Vector3(0,1.06,0),Vector3(2.03,1.36,1.62),iron)
 for y in [.40,1.76]:
  Geo.box(stove,Vector3(0,y,0),Vector3(2.18,.19,1.75),iron)
 for side in [-1,1]:
  Geo.box(stove,Vector3(side*.52,1.06,.85),Vector3(.92,1.13,.11),brass)
  Geo.box(stove,Vector3(side*.52,1.07,.91),Vector3(.76,.96,.08),iron)
  Geo.beam(stove,Vector3(side*.22,1.11,.97),Vector3(side*.35,1.11,.97),.038,brass)
  for depth in [-1,1]:
   Geo.beam(stove,Vector3(side*.88,.51,depth*.62),Vector3(side*.96,.16,depth*.70),.115,iron)
 Geo.cylinder(stove,Vector3(0,3.06,-.38),.20,2.54,iron)
 for y in [1.88,3.18,4.29]:
  Geo.cylinder(stove,Vector3(0,y,-.38),.25,.10,iron)
 wall_lantern(root,fire+Vector3(-2.86,2.85,-1.09))
 room_light(root,fire+Vector3(0,2.38,1.35),Color("ffc27d"),.93,9.0)

 var supper=fixture(room,"left_table")
 Geo.mesh(root,trestle(Vector3(3.64,1.54,6.52),oak,plank),supper,null).name="AbanisChiefsDesk"
 var bench=trestle(Vector3(.76,.77,6.0),oak,plank)
 for side in [-1,1]:
  Geo.mesh(root,bench,supper+Vector3.RIGHT*(side*2.26),null)
 var cloth=Geo.mat("b4b09b")
 var top=supper+Vector3.UP*1.55
 Geo.box(root,top,Vector3(2.75,.027,5.98),cloth)
 for side in [-1,1]:
  Geo.box(root,top+Vector3(side*1.26,.016,0),Vector3(.045,.010,5.96),Geo.mat("899788"))
 table_props(root,top+Vector3.UP*.018,false)
 rug(root,boxes,Vector2(supper.x,supper.z),Vector2(5.68,8.30),Color("91594b"))
 hanging_cloth(root,Vector3(-5.65,3.96,room.origin.y-1.10),Vector2(1.40,2.32),.0,Color("985f50")).name="AbanisWovenHanging"
 room_light(root,supper+Vector3(-.3,4.12,-1.20),Color("ffe1ae"),.95,10.2)

 var rest=fixture(room,"right_table")
 var bed=Furniture.bed(3.55,5.12,-1)
 for side in [-1,1]:
  Geo.mesh(root,bed,rest+Vector3.BACK*(side*2.13),null).rotation.y=PI*.5
  var towel=Geo.box(root,rest+Vector3(0,1.31,side*2.13+.08),Vector3(.72,.14,.47),Geo.mat("ece3c8"))
  towel.rotation.y=PI*.10*side
 var records=fixture(room,"records")+Vector3.FORWARD*.24
 var dresser=Geo.mesh(root,abanis_drawers(3.42,1.56,1.73,2,3,oak,plank),records,null)
 dresser.name="AbanisFlowerDresser"
 var vase=records+Vector3.UP*1.73
 Geo.mesh(root,Shapes.urn_mesh(),vase,Geo.mat("486f88")).scale=Vector3.ONE*.82
 Geo.torus(root,vase+Vector3.UP*.532,.335,.369,Geo.mat("c5d7c6"))
 Goods.Assets.batch(dresser,"flowers_coral",[
  Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.75),vase-dresser.position+Vector3(-.12,.49,0)),
  Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.69),vase-dresser.position+Vector3(.13,.49,.09))
 ])

 var cloth_at=fixture(room,"provisions")
 var bolts=Geo.mesh(root,trestle(Vector3(1.84,1.06,2.62),oak,plank),cloth_at+Vector3.FORWARD*1.14,null)
 bolts.name="AbanisClothDisplay"
 var dyes=[Geo.mat("c6b588"),Geo.mat("7e9f9e"),Geo.mat("a16d52")]
 for i in 3:
  var p=bolts.position+Vector3((i-1)*.46,1.21,(i-1)*.13)
  Geo.cylinder(root,p,.17,1.39,dyes[i]).rotation.x=PI*.5
  Geo.cylinder(root,p+Vector3.BACK*.69,.082,.040,plank).rotation.x=PI*.5
 Geo.mesh(root,Furniture.chair(),cloth_at+Vector3.BACK*1.15,null)

static func hall(root:Node3D,boxes,room:Dictionary):
 var oak=Fort.material(Color("684b38"),false)
 var plank=Fort.material(Color("987454"),false)
 var stone=Fort.material(Color("647582"))
 var pale=Fort.material(Color("aab4b1"),false)
 var iron=Geo.mat("42494a",.35)
 var fire=fixture(room,"hearth")
 var hearth=Node3D.new()
 hearth.name="RidgewatchHearth"
 hearth.position=fire
 root.add_child(hearth)
 Geo.box(hearth,Vector3(0,.18,.0),Vector3(7.2,.36,2.81),pale)
 Geo.box(hearth,Vector3(0,1.46,-.97),Vector3(4.8,2.61,.43),Geo.mat("24272d"))
 for x in [-2.21,2.21]:
  Geo.box(hearth,Vector3(x,1.6,.03),Vector3(.87,2.96,2.15),stone)
  Geo.box(hearth,Vector3(x,2.91,.06),Vector3(1.13,.31,2.37),pale)
 Geo.box(hearth,Vector3(0,3.28,.03),Vector3(5.58,.54,2.58),stone)
 Geo.box(hearth,Vector3(0,3.58,.08),Vector3(5.93,.23,2.66),pale)
 Geo.box(hearth,Vector3(0,.47,-.06),Vector3(2.36,.15,1.20),iron)
 var rail=Vector3(0,.63,.64)
 Geo.beam(hearth,rail+Vector3.LEFT*1.26,rail+Vector3.RIGHT*1.26,.056,iron)
 for x in [-1.15,-.74,-.36,0,.36,.74,1.15]:
  Geo.beam(hearth,Vector3(x,.40,.56),Vector3(x,.82,.64),.046,iron)
  Geo.sphere(hearth,Vector3(x,.82,.64),Vector3.ONE*.115,iron)
 for side in [-1,1]:
  var at=fire+Vector3(side*2.81,.38,1.12)
  Geo.beam(root,at,at+Vector3(.11*side,1.74,-.23),.041,iron)
  Geo.sphere(root,at+Vector3(.11*side,1.77,-.23),Vector3.ONE*.14,iron)
 for side in [-1,1]:
  Geo.beam(hearth,Vector3(-.83,.65,side*.34),Vector3(.83,.82,-side*.34),.26,oak)
  Geo.spike(hearth,Vector3(.47*side,.61,-.04),Vector3(.26*side,1.54,.08),.61,Geo.mat("e97b3f",0.0,.74))
 Geo.spike(hearth,Vector3(0,.65,.16),Vector3(.17,1.83,.09),.70,Geo.mat("ffb358",0.0,.89))
 room_light(hearth,Vector3(0,1.50,.66),Color("ffb068"),1.65,12.0)
 var crest=PackedVector2Array([Vector2(-.61,.40),Vector2(.61,.40),Vector2(.57,-.12),
  Vector2(.29,-.38),Vector2(0,-.55),Vector2(-.29,-.38),Vector2(-.57,-.12)])
 var shield=Geo.mesh(root,Shapes.extrude(crest,.17),fire+Vector3(0,4.16,-1.08),iron)
 shield.name="RidgewatchWallCrest"
 var badge=Geo.box(root,fire+Vector3(0,4.21,-.968),Vector3(.36,.36,.08),pale)
 badge.rotation.z=PI*.25
 for side in [-1,1]:
  var at=fire+Vector3(side*3.67,4.25,-1.13)
  hanging_cloth(root,at,Vector2(1.47,1.80),.43,Color("385c7d")).name="RidgewatchBanner"
  wall_lantern(root,fire+Vector3(side*5.60,3.55,-1.07))
 var records=Geo.mesh(root,Furniture.bookcase(4.2,6.32,true),fixture(room,"records"),null)
 records.name="RidgewatchRecords"
 records.rotation.y=-PI*.5
 var table_mesh=trestle(Vector3(3.96,1.55,7.18),oak,plank)
 var bench_mesh=trestle(Vector3(.87,.76,6.73),oak,plank)
 for key in ["left_table","right_table"]:
  var at=fixture(room,key)
  var table=Geo.mesh(root,table_mesh,at,null)
  table.name="RidgewatchTable"
  for side in [-1,1]:
   Geo.mesh(root,bench_mesh,at+Vector3(side*2.37,0,0),null)
  table_props(root,at+Vector3.UP*1.55,key=="left_table")
 var supplies=fixture(room,"provisions")
 Goods.crate(root,boxes,supplies+Vector3.FORWARD*1.15,1.23,true,oak,plank)
 Goods.barrel(root,supplies+Vector3.BACK*.95,.63,oak,plank,iron)
 rug(root,boxes,Vector2(0,.83),Vector2(5.4,19.2),Color("3a627d"))
 room_light(root,Vector3(0,4.27,4.2),Color("ffe0aa"),.84,10.0)

static func trestle(size_:Vector3,wood:Material,trim:Material)->Mesh:
 Lamps.prepare_primitives()
 var frame=Furniture.tool()
 var top=Furniture.tool()
 var height=size_.y
 Furniture.rounded_block(top,Vector3.UP*(height-.10),Vector3(size_.x,.20,size_.z),minf(.27,size_.x*.20))
 Lamps.block(frame,Vector3.UP*(height-.24),Vector3(size_.x*.88,.16,size_.z*.94))
 for end in [-1,1]:
  var z=end*size_.z*.36
  Lamps.block(frame,Vector3(0,.11,z),Vector3(size_.x*.87,.19,.34))
  Lamps.block(frame,Vector3(0,(height-.18)*.52,z),Vector3(size_.x*.42,height-.29,.22))
  Lamps.block(top,Vector3(0,height*.42,z+end*.139),Vector3(size_.x*.34,.10,.08))
 Lamps.block(frame,Vector3(0,height*.44,0),Vector3(size_.x*.22,.18,size_.z*.74))
 return Furniture.finish([frame,top],[wood,trim])

static func counter_scale(root:Node3D,at:Vector3):
 var scale_root=Node3D.new()
 scale_root.name="SnowpineBalanceScale"
 scale_root.position=at
 root.add_child(scale_root)
 var brass=Geo.mat("b68d53",.39)
 var iron=Geo.mat("525155",.35)
 Geo.cylinder(scale_root,Vector3.UP*.07,.30,.14,iron,false,.23)
 Geo.beam(scale_root,Vector3.UP*.13,Vector3.UP*1.09,.066,brass)
 Geo.beam(scale_root,Vector3(-.77,1.03,0),Vector3(.77,1.03,0),.043,brass)
 Geo.sphere(scale_root,Vector3.UP*1.13,Vector3.ONE*.15,brass)
 for side in [-1,1]:
  var x=side*.72
  Geo.cylinder(scale_root,Vector3(x,.48,0),.23,.07,brass,false,.31)
  for end in [-1,1]:
   Geo.beam(scale_root,Vector3(x+end*.20,.52,0),Vector3(x,1.01,0),.017,iron)
 Geo.cylinder(scale_root,Vector3(.72,.57,0),.095,.13,iron,false,.072)

static func hanging_cloth(root:Node3D,at:Vector3,span:Vector2,point:float,tint:Color)->MeshInstance3D:
 var folds=Furniture.tool()
 var border=Furniture.tool()
 var prev=Vector3.ZERO
 var prev_hem=Vector3.ZERO
 for i in 9:
  var t=float(i)/8.0*2.0-1.0
  var top=Vector3(t*span.x*.5,0,.085*cos(t*PI*2.0))
  var hem=Vector3(top.x,-span.y-point*(1.0-absf(t)),top.z*.68+.05)
  if i>0:
   Shapes.quad(folds,prev,top,hem,prev_hem)
   Shapes.quad(folds,top-Vector3.BACK*.027,prev-Vector3.BACK*.027,prev_hem-Vector3.BACK*.027,hem-Vector3.BACK*.027)
   var edge=Vector3(0,.085,.014)
   Shapes.quad(border,prev_hem+edge+Vector3.UP*.071,hem+edge+Vector3.UP*.071,hem+edge,prev_hem+edge)
  prev=top
  prev_hem=hem
 Geo.beam(root,at+Vector3.LEFT*span.x*.61+Vector3.UP*.04,at+Vector3.RIGHT*span.x*.61+Vector3.UP*.04,
  .049,Geo.mat("7c623e",.25))
 return Geo.mesh(root,Furniture.finish([folds,border],[Fort.material(tint,false),Geo.mat("cbb381")]),at,null)

static func wall_lantern(root:Node3D,at:Vector3):
 if wall_lantern_mesh==null:
  Lamps.prepare_primitives()
  var frame=Furniture.tool()
  var glass=Furniture.tool()
  Lamps.block(frame,Vector3(0,-.02,-.08),Vector3(.27,.52,.12))
  Lamps.rod(frame,Vector3(0,.15,-.03),Vector3(0,.15,.39),.042)
  Lamps.lantern(frame,glass,Vector3(0,.13,.39),true)
  wall_lantern_mesh=Furniture.finish([frame,glass],[Geo.mat("505459",.31),Geo.mat("e6af63",0.0,.74)])
 Geo.mesh(root,wall_lantern_mesh,at,null).name="WinterWallLantern"

static func table_props(root:Node3D,at:Vector3,planning:bool):
 if planning:
  var pages=Furniture.tool()
  var ink=Furniture.tool()
  Furniture.ledger(pages,ink,Vector3(-.12,0,-1.18),Vector2(1.54,1.04))
  Furniture.quill(ink,pages,Vector3(.89,0,-1.28))
  Geo.mesh(root,Furniture.finish([pages,ink],[Geo.mat("e0c893"),Geo.mat("4e4942")]),at,null).name="RidgewatchPlanningLedger"
  var roll=Geo.cylinder(root,at+Vector3(.33,.16,1.78),.15,1.06,Geo.mat("cbb888"))
  roll.rotation.z=PI*.5
  Geo.box(root,at+Vector3(-.01,.036,.81),Vector3(1.39,.055,.85),Geo.mat("cfbaa1"))
  for row in [-.20,0,.20]:
   Geo.box(root,at+Vector3(-.16,.067,.81+row),Vector3(.81,.009,.017),Geo.mat("7c6951"))
 else:
  var ceramic=Geo.mat("c0b193")
  var platter=Geo.cylinder(root,at+Vector3(0,.058,.56),.71,.11,ceramic,false,.80)
  platter.name="RidgewatchServingPlatter"
  Goods.fruit(root,at+Vector3(0,.12,.56),5,4,.60)
  Geo.mesh(root,Shapes.urn_mesh(),at+Vector3(.43,0,-1.59),Geo.mat("4c6c72"))
  for x in [-.57,.59]:
   Geo.cylinder(root,at+Vector3(x,.14,-.56),.132,.28,ceramic,false,.162)

static func rug(root:Node3D,boxes,center:Vector2,span:Vector2,tint:Color):
 var edge=Fort.material(Color("ceb68a"),false)
 boxes.add(Vector3(center.x,.032,center.y),Vector3(span.x,.049,span.y),Fort.material(tint,false))
 for side in [-1,1]:
  boxes.add(Vector3(center.x+side*(span.x*.5-.19),.065,center.y),Vector3(.16,.024,span.y-.28),edge)
  boxes.add(Vector3(center.x,.065,center.y+side*(span.y*.5-.19)),Vector3(span.x-.28,.024,.16),edge)
 for step in [-1,0,1]:
  var mark=Vector3(center.x,.067,center.y+step*span.y*.28)
  var border=Geo.box(root,mark,Vector3(1.17,.016,1.17),edge)
  border.rotation.y=PI*.25
  var inset=Geo.box(root,mark+Vector3.UP*.013,Vector3(.83,.014,.83),Fort.material(tint.darkened(.25),false))
  inset.rotation.y=PI*.25

static func room_light(root:Node3D,point:Vector3,color:Color,energy:float,reach:float)->OmniLight3D:
 var lamp=OmniLight3D.new()
 lamp.position=point
 lamp.light_color=color
 lamp.light_energy=energy
 lamp.omni_range=reach
 root.add_child(lamp)
 return lamp
