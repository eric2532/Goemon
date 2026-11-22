extends RefCounted
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Data=preload("res://assets/maps/falan/room_art_data.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")
const Inn=preload("res://scripts/forest/forest_falan_inn_art.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const STAIR_ENTRY=Rect2i(7,18,1,2)

static func build(root:Node3D,boxes,origin:Vector2):
 var timber=Fort.material(Color("74543c"),false)
 var brass=Fort.material(Color("a58a5b"),false)
 var linen=Fort.material(Color("d8c39a"),false)
 var cream=Fort.material(Color("d9c9a8"),false)
 var orange=Fort.material(Color("a75434"),false)
 for row in Data.EMPLOYMENT_DETAILS:
  var at=origin+Vector2(row[0])*3
  var p=Vector3(at.x,0,at.y)
  match row[1]:
   17532:
    Furniture.office_detail(root,1091,17532,p)
   17534:
    Furniture.office_detail(root,1091,17534,p)
   17554:
    boxes.add(p+Vector3(0,4.44,-.30),Vector3(3.01,.60,.70),cream)
    boxes.add(p+Vector3(0,4.11,-.30),Vector3(3.01,.13,.78),timber)
   17559:
    Furniture.office_detail(root,1091,17559,p)
    Furniture.panel(root,"office_door_crown",p+Vector3(0,3.43,-1.287),Vector2(2.36,.61))
   17560:
    boxes.add(p+Vector3(0,3.31,.28),Vector3(.61,1.56,.09),orange)
    boxes.add(p+Vector3(0,4.07,.30),Vector3(.80,.095,.15),brass)
    boxes.add(p+Vector3(0,3.44,.34),Vector3(.15,.34,.045),brass)
   17564:
    Inn.notice(boxes,p+Vector3(-1.46,2.68,0),1.36,timber,linen,true)
    Furniture.panel(root,"office_notice",p+Vector3(-1.33,2.68,0),Vector2(1.36,1.10),PI*.5)
 stairs(root,boxes,cream,timber)

static func stairs(root:Node3D,boxes,stone:Material,timber:Material):
 var stair=Node3D.new()
 stair.name="FalanEmploymentStaircase"
 root.add_child(stair)
 flight(stair,Vector3(-10.50,0,19.5),11.98,5.45,3.24,0)
 var turn=Vector3(-25.45,1.62,19.5)
 var turn_size=Vector3(6.02,3.24,5.78)
 boxes.add(turn,turn_size,stone)
 Art.solid(stair,turn,turn_size,1,"stone")
 flight(stair,Vector3(-25.45,3.24,16.65),6.91,4.87,1.63,-PI*.5)
 var summit=Vector3(-25.45,2.435,8.75)
 var summit_size=Vector3(4.87,4.87,2.03)
 boxes.add(summit,summit_size,stone)
 Art.solid(stair,summit,summit_size,1,"stone")
 var guard=Vector3(-25.45,5.37,7.82)
 boxes.add(guard,Vector3(4.87,.91,.14),timber)
 Art.solid(stair,guard,Vector3(4.87,.91,.14),1,"wood")

static func flight(root:Node3D,foot:Vector3,run:float,width:float,rise:float,yaw:float):
 var section=Node3D.new()
 section.position=foot
 section.rotation.y=yaw
 root.add_child(section)
 var treads=Boxes.new()
 Palace.steps(section,treads,0,-run,0,width,0,rise,ceili(run/.86),true)
 treads.build(section)
 var ramp=ConvexPolygonShape3D.new()
 var points=PackedVector3Array()
 for side in [-1,1]:
  var z=width*.5*side
  points.append_array(PackedVector3Array([Vector3(0,0,z),Vector3(-run,rise,z),Vector3(-run,-.08,z),Vector3(0,-.08,z)]))
  Art.solid(section,Vector3(-run*.5,rise*.5+.47,z),Vector3(Vector2(run,rise).length()-.25,.90,.13),1,"stone").rotation.z=-atan2(rise,run)
 ramp.points=points
 Palace.support(section,ramp,Vector3.ZERO)
