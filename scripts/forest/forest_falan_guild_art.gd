extends RefCounted
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Data=preload("res://assets/maps/falan/room_art_data.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")

static func details(root:Node3D,boxes,origin:Vector2):
 var oak=Fort.material(Color("8e6744"),false)
 for row in Data.GUILD_DETAILS:
  var at=origin+Vector2(row[0])*3.0
  var p=Vector3(at.x,0,at.y)
  if row[1]==17534:
   Furniture.office_detail(root,1092,17534,p)
  else:
   boxes.add(p+Vector3(-1.46,2.63,-1.50),Vector3(.11,2.24,3.14),oak)
   Furniture.panel(root,"guild_notice",p+Vector3(-1.395,2.63,-1.50),Vector2(3.0,2.10),PI*.5)

static func furnish(root:Node3D,boxes,p:Vector3,kind:String,serial:int):
 var timber=Fort.material(Color("8f6744"),false)
 var cream=Fort.material(Color("e9dfc5"),false)
 var brass=Fort.material(Color("bd9656"),false)
 if kind=="guild_supply":
  Goods.crate(root,boxes,p,1.30,false,timber,brass)
  for i in 6:
   var at=p+Vector3((i%3-1)*.33,.93,(-.23 if i<3 else .23))
   Geo.cylinder(root,at,.105,1.03+(i%3)*.14,cream).rotation.z=(i%3-1)*.20
  return
 var dark=Fort.material(Color("484838"),false)
 var enamel=Fort.material(Color("3e6170"),false)
 var frame=Node3D.new()
 frame.name="FalanGuildCounter_%d_%d_%d"%[serial,roundi(p.x),roundi(p.z)]
 frame.position=p
 if serial>=17595:frame.rotation.y=PI*.5
 root.add_child(frame)
 Geo.box(frame,Vector3.UP*.15,Vector3(2.98,.30,2.98),dark)
 Geo.box(frame,Vector3.UP*.77,Vector3(2.83,1.18,2.83),enamel)
 Geo.box(frame,Vector3.UP*1.40,Vector3(2.99,.23,2.99),cream)
 for y in [.40,1.18]:
  Geo.box(frame,Vector3.UP*y,Vector3(2.94,.083,2.94),brass)
 for i in 4:
  var x=(i-1.5)*.66
  Geo.box(frame,Vector3(x,.79,1.43),Vector3(.12,.68,.07),brass)
  if serial==17592:Geo.box(frame,Vector3(1.43,.79,x),Vector3(.07,.68,.12),brass)
 if serial in [17594,17596]:
  var pottery=Fort.material(Color("517a8d") if serial==17594 else Color("5a7256"),false)
  Geo.box(frame,Vector3(.20,1.535,-.21),Vector3(1.43,.055,.83),timber)
  for i in 3:
   var at=Vector3((i-1)*.41+.20,1.54,-.21)
   var height=.32+i*.12
   Geo.sphere(frame,at+Vector3.UP*(height*.40),Vector3(.32,height,.33),pottery)
   Geo.cylinder(frame,at+Vector3.UP*(height*.91),.086,.17,pottery,false,.062)
   Geo.cylinder(frame,at+Vector3.UP*(height*.91+.092),.081,.040,cream)
