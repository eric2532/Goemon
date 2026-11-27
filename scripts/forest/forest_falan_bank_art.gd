extends RefCounted
## Solid furnishings use the archived blocked footprints. Grilles hang above them.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Data=preload("res://assets/maps/falan/room_art_data.gd")

static var grille:Mesh

static func lattice()->Mesh:
 if grille!=null:return grille
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var shaft=BoxMesh.new()
 shaft.size=Vector3.ONE
 for i in 10:
  var x=(i-4.5)*.30
  Statues.rod(tool,shaft,Vector3(x,2.95,0),Vector3(x,4.19,0),.024)
  if i<9:
   for y in [3.27,3.89]:
    Statues.rod(tool,shaft,Vector3(x,y-.19,.018),Vector3(x+.30,y+.19,.018),.024)
    Statues.rod(tool,shaft,Vector3(x,y+.19,.018),Vector3(x+.30,y-.19,.018),.024)
 grille=tool.commit()
 return grille

static func details(root:Node3D,boxes,origin:Vector2):
 var stone=Fort.material(Color("b4ab8f"),false)
 var dark=Fort.material(Color("413d32"),false)
 var iron=Fort.material(Color("aaa99a"),false)
 var brass=Fort.material(Color("b09663"),false)
 for row in Data.BANK_DETAILS:
  var at=origin+Vector2(row[0])*3
  var p=Vector3(at.x,0,at.y)
  match row[1]:
   17641:
    p.z+=.32
    boxes.add(p+Vector3.UP*4.63,Vector3(3.03,.37,.65),dark)
    boxes.add(p+Vector3.UP*4.39,Vector3(3.03,.14,.61),stone)
    for y in [2.95,3.58,4.19]:
     boxes.add(p+Vector3.UP*y,Vector3(3.02,.045,.074),brass)
    Geo.mesh(root,lattice(),p,iron).name="FalanBankTellerGrille_%d"%row[0].x
   17533:
    Furniture.bank_bench(root,p)
    Art.solid(root,p+Vector3.UP*.46,Vector3(2.98,.92,1.46),1,"wood",true)
   17642:
    p+=Vector3(-1.5,0,-1.43)
    boxes.add(p+Vector3.UP*1.7,Vector3(2.10,3.4,.17),dark)
    boxes.add(p+Vector3(0,3.45,.13),Vector3(2.23,.16,.23),stone)
    for y in [.89,2.48]:
     boxes.add(p+Vector3(0,y,.108),Vector3(1.74,1.10,.08),brass)
     boxes.add(p+Vector3(0,y,.16),Vector3(1.54,.92,.07),dark)
    Geo.sphere(root,p+Vector3(.75,1.65,.22),Vector3.ONE*.16,brass)

static func furnish(root:Node3D,boxes,p:Vector3,width:float,length_:float,along_x:bool,kind:String,serial:int):
 var oak=Fort.material(Color("a87950"),false)
 var edge=Fort.material(Color("cfab73"),false)
 var walnut=Fort.material(Color("65503c"),false)
 var dark=Fort.material(Color("3e342c"),false)
 var brass=Fort.material(Color("ab9361"),false)
 var iron=Fort.material(Color("737b74"),false)
 var felt=Fort.material(Color("4d674a"),false)
 var paper=Fort.material(Color("ddd4ae"),false)
 var frame=Node3D.new()
 frame.name="FalanBank_%d"%serial
 frame.position=p
 frame.rotation.y=PI*.5 if along_x or serial in [17568,17569,10436] else 0.0
 root.add_child(frame)
 if kind=="bank_counter":
  var end=serial in [17566,17567]
  var span=length_+.34
  var depth=2.90
  var shape=Vector3(depth,1.36,span)
  var z=0.0
  if end:
   shape.z-=depth*.5
   z=-depth*.25
   var tip=Vector3(0,.68,span*.5-depth*.5)
   Geo.cylinder(frame,tip,depth*.5,1.36,oak).mesh.radial_segments=20
   Geo.cylinder(frame,tip+Vector3.UP*.71,depth*.53,.15,edge).mesh.radial_segments=20
  Geo.box(frame,Vector3(0,.68,z),shape,oak)
  Geo.box(frame,Vector3(0,.17,z),Vector3(depth+.06,.22,shape.z),walnut)
  Geo.box(frame,Vector3(0,1.38,z),Vector3(depth+.10,.18,shape.z),edge)
  Geo.box(frame,Vector3(0,1.48,z),Vector3(depth-.09,.09,shape.z),oak)
  for i in ceili(shape.z/.47):
   var at=z-shape.z*.5+(i+.5)*shape.z/ceili(shape.z/.47)
   for side in [-1,1]:
    Geo.box(frame,Vector3(side*depth*.5,.76,at),Vector3(.06,.94,.105),edge)
  if serial in [17569,17571]:
   Geo.box(frame,Vector3(.51,1.54,0),Vector3(.94,.04,minf(2.13,span*.63)),felt)
  if serial in [17567,17569,17571]:
   ledger(frame,Vector3(-.28,1.54,span*.19),walnut,paper)
 elif kind=="bank_desk":
  var top=Vector3(width*.72,.18,length_*.79)
  Geo.box(frame,Vector3.UP*1.44,top,oak)
  Geo.box(frame,Vector3.UP*1.29,Vector3(top.x*.96,.29,top.z*.96),walnut)
  for side in [-1,1]:
   for end in [-1,1]:
    Geo.box(frame,Vector3(side*top.x*.40,.63,end*top.z*.41),Vector3(.28,1.26,.28),dark)
  Geo.box(frame,Vector3(-top.x*.22,1.55,top.z*.22),Vector3(top.x*.36,.046,top.z*.21),felt)
  ledger(frame,Vector3(top.x*.20,1.55,top.z*.19),walnut,paper)
  ledger(frame,Vector3(-top.x*.23,1.55,-top.z*.19),walnut,paper)
 elif kind=="bank_stand":
  boxes.add(p+Vector3.UP*.61,Vector3(1.87,1.22,2.10),walnut)
  boxes.add(p+Vector3.UP*1.25,Vector3(2.10,.21,2.32),iron)
  for side in [-1,1]:
   boxes.add(p+Vector3(side*.97,.73,0),Vector3(.12,1.30,2.24),oak)
 elif kind=="bank_clock":
  Geo.box(frame,Vector3.UP*1.6,Vector3(1.04,3.20,.52),walnut)
  Geo.box(frame,Vector3.UP*.19,Vector3(1.31,.38,.71),oak)
  Geo.box(frame,Vector3(0,1.35,.28),Vector3(.62,1.48,.09),dark)
  Geo.box(frame,Vector3(0,1.54,.35),Vector3(.05,1.11,.04),brass)
  disk(frame,Vector3(0,1.03,.37),.21,.09,brass)
  disk(frame,Vector3(0,3.09,.12),.60,.50,oak)
  if serial not in [10436,10495]:disk(frame,Vector3(0,3.03,.39),.39,.12,paper)
  if serial in [10436,10495]:
   Furniture.panel(frame,"clock_%d"%serial,Vector3(0,3.03,.495),Vector2(.74,1.0))
  else:
   Geo.box(frame,Vector3(0,3.14,.47),Vector3(.048,.25,.033),dark)
   Geo.box(frame,Vector3(.11,3.03,.47),Vector3(.23,.048,.033),dark)
 elif kind=="bank_vault":
  Geo.box(frame,Vector3.UP*1.90,Vector3(2.87,3.80,2.64),walnut)
  Geo.box(frame,Vector3(0,1.59,1.35),Vector3(2.35,2.97,.19),brass)
  Geo.box(frame,Vector3(0,1.59,1.49),Vector3(2.12,2.75,.17),dark)
  for x in [-1.05,1.05]:
   for y in [.32,.69,1.07,1.45,1.83,2.21,2.59,2.86]:
    Geo.sphere(frame,Vector3(x,y,1.58),Vector3.ONE*.10,iron)
  disk(frame,Vector3(.34,1.57,1.60),.38,.13,iron)
  disk(frame,Vector3(.34,1.57,1.69),.23,.08,dark)
  for i in 5:
   var angle=i*TAU/5
   Geo.beam(frame,Vector3(.34,1.57,1.76),Vector3(.34+cos(angle)*.31,1.57+sin(angle)*.31,1.76),.028,brass)

static func disk(root:Node3D,p:Vector3,radius:float,depth:float,material:Material):
 Geo.cylinder(root,p,radius,depth,material).rotation.x=PI*.5

static func ledger(root:Node3D,p:Vector3,cover:Material,paper:Material):
 Geo.box(root,p,Vector3(.74,.07,.59),cover)
 Geo.box(root,p+Vector3.UP*.047,Vector3(.67,.045,.53),paper)
 for i in 4:
  Geo.box(root,p+Vector3(-.015,.075,(i-1.5)*.087),Vector3(.49,.014,.017),cover)
