extends RefCounted
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Data=preload("res://assets/maps/falan/room_art_data.gd")
const Bank=preload("res://scripts/forest/forest_falan_bank_art.gd")
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")

static func details(root:Node3D,boxes,id:int,origin:Vector2):
 var timber=Fort.material(Color("79513b"),false)
 var bronze=Fort.material(Color("aa8750"),false)
 var iron=Fort.material(Color("4f5450"),false)
 var cream=Fort.material(Color("dfc797"),false)
 var flame=Geo.mat("fbd597",0,.5)
 for row in Data.INN_DETAILS[id]:
  var at=origin+Vector2(row[0])*3
  var p=Vector3(at.x,0,at.y)
  match row[1]:
   17023:
    stool(root,p,timber,iron)
   17195:
    # The source anchor is on the public side of the raised counter edge.
    p+=Vector3(0,1.52,-1.76)
    Geo.cylinder(root,p+Vector3.UP*.055,.23,.11,bronze)
    Geo.cylinder(root,p+Vector3.UP*.26,.055,.48,bronze)
    for x in [-.15,0,.15]:
     var h=.55-absf(x)*.78
     Geo.cylinder(root,p+Vector3(x,h,0),.046,.25,cream)
     Geo.sphere(root,p+Vector3(x,h+.16,0),Vector3(.064,.12,.063),flame)
   16549,16521:
    Geo.beam(root,p+Vector3(.36,.34,-.87),p+Vector3(.74,2.22,-1.23),.047,timber)
    boxes.add(p+Vector3(.34,.20,-.85),Vector3(.39,.38,.20),cream)
   17607:
    notice(boxes,p+Vector3(-1.46,2.7,-1.5),3.80,timber,cream,true)
    Bank.Furniture.panel(root,"inn_notice",p+Vector3(-1.33,2.7,-1.5),Vector2(3.76,1.08),PI*.5)
   10415:
    notice(boxes,p+Vector3(0,2.53,-.38),.93,iron,cream,false)
    for side in [-1,1]:
     boxes.add(p+Vector3(side*.55,1.11,-.38),Vector3(.09,2.22,.10),iron)
   10567:
    var face=p+Vector3(0,2.97,-1.44)
    boxes.add(face,Vector3(.65,1.82,.16),timber)
    Bank.disk(root,face+Vector3(0,.48,.13),.25,.07,cream)
    Bank.disk(root,face+Vector3(0,-.49,.14),.12,.055,bronze)

static func stool(root:Node3D,p:Vector3,wood:Material,iron:Material):
 Geo.cylinder(root,p+Vector3.UP*.99,.41,.19,wood)
 for i in 3:
  var angle=i*TAU/3
  var edge=Vector3(cos(angle),0,sin(angle))
  Geo.beam(root,p+edge*.24+Vector3.UP*.96,p+edge*.36+Vector3.UP*.05,.052,wood)
 Geo.cylinder(root,p+Vector3.UP*.35,.28,.05,iron)

static func notice(boxes,p:Vector3,width:float,wood:Material,paper:Material,side:bool):
 boxes.add(p,Vector3(.11,1.31,width+.20) if side else Vector3(width+.20,1.31,.11),wood)
 var offset=Vector3.RIGHT if side else Vector3.BACK
 boxes.add(p+offset*.068,Vector3(.047,1.10,width) if side else Vector3(width,1.10,.047),paper)
 for i in 4:
  boxes.add(p+offset*.10+Vector3.UP*(i-1.5)*.18,Vector3(.025,.029,width*(.57+i%2*.16)) if side
   else Vector3(width*(.57+i%2*.16),.029,.025),wood)

static func furnish(root:Node3D,boxes,p:Vector3,width:float,length_:float,swap:bool,serial:int,kind:String):
 var timber=Fort.material(Color("845b42"),false)
 var pale=Fort.material(Color("b68d62"),false)
 var dark=Fort.material(Color("5f3b31"),false)
 var brass=Fort.material(Color("c1a369"),false)
 var iron=Fort.material(Color("646d68"),false)
 var cloth=Fort.material(Color("a96253"),false)
 var linen=Fort.material(Color("dbc59a"),false)
 var blue=Fort.material(Color("2e5960"),false)
 var frame=Node3D.new()
 frame.name="FalanInn_%d"%serial
 frame.position=p
 frame.rotation.y=PI*.5 if swap else 0.0
 root.add_child(frame)
 match kind:
  "inn_counter":
   var lottery=serial>=17196
   var round_end=serial in [17018,17197,17202]
   var span=Vector2(width+.33,length_+.33)
   var top=blue if lottery else pale
   var wall=timber if lottery else dark
   var layers=[[.18,.30,iron],[.73,1.08,wall],[1.41,.25,top]]
   for layer in layers:
    var offset=Vector3.UP*layer[0]
    if round_end:
     var side=-1 if serial==17197 else 1
     Geo.mesh(frame,rounded_corner(span,layer[1],side),offset,layer[2])
    else:
     Geo.box(frame,offset,Vector3(span.x,layer[1],span.y),layer[2])
   if serial in [17021,17022]:
    Geo.cylinder(frame,Vector3(.32,1.60,0),.43,.07,linen)
    Geo.cylinder(frame,Vector3(-.16,1.76,.47),.19,.42,iron,false,.14)
    Geo.cylinder(frame,Vector3(.18,1.69,-.41),.13,.28,brass)
   if serial==17196:Bank.ledger(frame,Vector3.UP*1.58,dark,linen)
  "inn_table":
   Geo.box(frame,Vector3.UP*.91,Vector3(2.13,.17,1.47),cloth)
   for side in [-1,1]:
    for end in [-1,1]:
     Geo.cylinder(frame,Vector3(side*.88,.44,end*.53),.095,.88,timber,false,.12)
  "inn_cupboard":
   Geo.box(frame,Vector3.UP*1.21,Vector3(1.55,2.42,length_*.87),timber)
   Geo.box(frame,Vector3.UP*2.47,Vector3(1.70,.18,length_*.93),pale)
   for side in [-1,1]:
    for leaf in [-1,1]:
     Geo.box(frame,Vector3(side*.80,1.21,leaf*length_*.22),Vector3(.12,1.91,length_*.40),dark)
     Geo.box(frame,Vector3(side*.87,1.32,leaf*.15),Vector3(.11,.14,.083),brass)
  "inn_produce":
   Goods.crate(root,boxes,p,1.30,false,timber,pale)
   Goods.fruit(root,p+Vector3.UP*.87,5,2,.90)
  "inn_sign":
   notice(boxes,p+Vector3(0,1.05,0),1.04,dark,linen,false)
   Geo.beam(frame,Vector3(0,.12,-.47),Vector3(0,1.68,0),.08,timber)
  "inn_chest":
   var enamel=Fort.material(Color("ad4e30"),false) if serial==10443 else blue
   Geo.box(frame,Vector3.UP*.47,Vector3(1.65,.94,1.14),enamel)
   var lid=Geo.cylinder(frame,Vector3.UP*.89,.58,1.65,enamel)
   lid.rotation.z=PI*.5
   for end in [-1,1]:
    var strap=Geo.cylinder(frame,Vector3(end*.61,.89,0),.60,.091,brass)
    strap.rotation.z=PI*.5
    Geo.box(frame,Vector3(end*.61,.46,.586),Vector3(.085,.89,.045),brass)
   Geo.box(frame,Vector3(0,.68,.612),Vector3(.26,.27,.089),brass)
  "inn_sack":
   Geo.sphere(frame,Vector3.UP*.37,Vector3(.96,.74,.82),linen)
   Geo.cylinder(frame,Vector3.UP*.76,.13,.19,linen,false,.20)
   Geo.cylinder(frame,Vector3.UP*.69,.14,.05,cloth)
  "inn_bucket":
   Geo.cylinder(frame,Vector3.UP*.33,.38,.66,iron,false,.43)
   Geo.cylinder(frame,Vector3.UP*.66,.44,.09,brass)
   Geo.cylinder(frame,Vector3.UP*.715,.33,.035,dark)
  "inn_display":
   Geo.box(frame,Vector3.UP*.77,Vector3(1.98,.38,length_*.89),timber)
   for side in [-1,1]:
    for end in [-1,1]:
     Geo.box(frame,Vector3(side*.78,.34,end*length_*.37),Vector3(.16,.68,.18),dark)
    for i in 7:
     var z=((i+.5)/7-.5)*length_*.77
     Geo.box(frame,Vector3(side*.43,1.02,z),Vector3(.60,.16,.72),[blue,linen,cloth][(i+side+1)%3])

static func rounded_corner(span:Vector2,height:float,side:int)->Mesh:
 var half=span*.5
 var radius=minf(half.x,half.y)*.91
 var outline=[Vector2(-half.x,-half.y),Vector2(half.x,-half.y)]
 for i in 7:
  var angle=i*PI/12
  outline.append(half-Vector2.ONE*radius+Vector2(cos(angle),sin(angle))*radius)
 outline.append(Vector2(-half.x,half.y))
 if side<0:
  for i in outline.size():outline[i].x*=-1
  outline.reverse()
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in outline.size():
  var p:Vector2=outline[i]
  var q:Vector2=outline[(i+1)%outline.size()]
  var a=Vector3(p.x,height*.5,p.y)
  var b=Vector3(q.x,height*.5,q.y)
  var down=Vector3.DOWN*height
  for vertex in [Vector3.UP*(height*.5),a,b,a,b+down,b,a,a+down,b+down]:
   tool.add_vertex(vertex)
 tool.generate_normals()
 return tool.commit()
