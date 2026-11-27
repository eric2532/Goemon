extends RefCounted
## Source-reviewed Il/Laruka plants, assembled from the existing scenery primitives.
## Hidden leaf/petal volume is inferred; original art, anchors and collision are retained.
const IDS=[11626,12160,12169,12170,12171,12175,12176,12177,12178,12179,12180,12181,11087,11088,11089,11090,11091,11092,11108,11109]
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
static var meshes={}

static func leaf(root:Node3D,at:Vector3,angle:float,height:float,material:Material):
 var direction=Vector3(cos(angle),0,sin(angle))
 var tip=at+direction*.23+Vector3.UP*height
 var node=Geo.sphere(root,(at+tip)*.5,Vector3(.11,at.distance_to(tip),.055),material)
 node.quaternion=Quaternion(Vector3.UP,(tip-at).normalized())

static func mesh(serial:int,g:Dictionary)->Mesh:
 assert(serial in IDS)
 if meshes.has(serial):return meshes[serial]
 var stage=Node3D.new()
 var green=Forms.Fort.material(Color("567c43"),false)
 var light=Forms.Fort.material(Color("a0b86c"),false)
 var pale=Forms.Fort.material(Color("ded6a2"),false)
 if serial==12160:
  for i in 3:
   var at=Vector3((i-1)*.18,0,(i-1)*.18)
   var high=.8+(i%2)*.25
   Geo.beam(stage,at,at+Vector3.UP*high,.018,green)
   for j in 5:
    for side in [-1,1]:leaf(stage,at+Vector3.UP*(high*(.18+j*.15)),i*.7+side*1.3,.20,light if j%2==0 else green)
 elif serial==12181:
  for j in 7:leaf(stage,Vector3.ZERO,j*2.4,.35+(j%3)*.16,light if j%2==0 else green)
 elif serial>=11626:
  var pink=serial in [12175,12176,12177,12178,12179,12180]
  var petal=Forms.Fort.material(Color("e39b9f" if pink else "e9dc9c"),false)
  var heart=Forms.Fort.material(Color("f5dfaa"),false)
  var tall=serial in [12175,12176,12177]
  for i in (3 if tall else 5):
   var along=(i-1)*.30 if tall else (i-2)*.21
   var at=Vector3(along,0,along)
   var high=(.70 if i==2 else 1.0+(i%2)*.22) if tall else .35+(i%3)*.12
   Geo.beam(stage,at,at+Vector3.UP*high,.016,green)
   for j in 3:leaf(stage,at+Vector3.UP*(high*(.12+j*.18)),j*2.4+i,.20,green)
   for level in (4 if tall else 1):
    var center=at+Vector3.UP*(high*(.5+level*.15) if tall else high)
    for j in 5:
     var angle=j*TAU/5.
     Geo.sphere(stage,center+Vector3(cos(angle)*.075,.025,sin(angle)*.075),Vector3(.14,.08,.14),petal)
    Geo.sphere(stage,center+Vector3.UP*.045,Vector3(.085,.07,.085),heart)
 else:
  var single=serial in [11108,11109]
  var seedling=serial in [11091,11109]
  var cabbage=serial==11092
  var red=serial in [11088,11090]
  var crop=Forms.Fort.material(Color("c87562" if red else "d8dbb5"),false)
  for i in (1 if single else 2):
   var along=0.0 if single else (i-.5)*.56
   var at=Vector3(along,0,along)
   var high=.08 if seedling else .47 if cabbage else .62
   if seedling:Geo.beam(stage,at,at+Vector3.UP*high,.012,green)
   if not seedling:
    if cabbage:
     for j in 5:
      var angle=j*TAU/5.
      Geo.sphere(stage,at+Vector3(cos(angle)*.11,.27,sin(angle)*.11),Vector3(.30,.45,.25),light if j%2==0 else green)
    else:
     var long_root=serial in [11089,11090,11108]
     Geo.sphere(stage,at+Vector3.UP*.26,Vector3(.30,.53 if long_root else .36,.30),crop)
     Geo.cylinder(stage,at+Vector3.UP*.055,.015,.11,pale,false,.055)
   for j in (3 if seedling else 5):leaf(stage,at+Vector3.UP*high,j*TAU/5.+i,.15 if seedling else .35,green if j%2==0 else light)
  if seedling:
   var shallow=Transform3D(Basis(Vector3(.575,0,.425),Vector3.UP,Vector3(.425,0,.575)),Vector3.ZERO)
   for child:Node3D in stage.get_children():child.transform=shallow*child.transform
 # Native drawings spread across their isometric horizontal axis. Preserve
 # that width and the original anchor; do not inflate each plant to a tile box.
 meshes[serial]=Forms.append_fitted(null,stage,3.,3.,1.,Vector3.ZERO,g)
 var root_offset:float=meshes[serial].get_aabb().position.y
 if absf(root_offset)>.00001:
  meshes[serial]=load("res://scripts/forest/forest_falan_proportions.gd").transformed(meshes[serial],Transform3D(Basis.IDENTITY,Vector3.DOWN*root_offset))
 meshes[serial].set_meta("source_garden_graphic",serial)
 return meshes[serial]
