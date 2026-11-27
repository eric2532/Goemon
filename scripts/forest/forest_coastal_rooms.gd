extends RefCounted
## Complete source placements; shared furniture owns the familiar pieces.
const Data=preload("res://assets/maps/falan/coastal_room_props.gd")
const Atlas=preload("res://assets/maps/falan/coastal_room_props.png")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Inn=preload("res://scripts/forest/forest_falan_inn_art.gd")
static var meshes:Dictionary={}

static func batch(root:Node3D,groups:Dictionary):
 var group=Node3D.new()
 group.name="ArchivedCoastalFurnishings"
 root.add_child(group)
 for serial in groups:
  var node=MultiMeshInstance3D.new()
  node.name="OriginalFixture_"+str(serial)
  node.set_meta("source_graphic",serial)
  node.multimesh=MultiMesh.new()
  node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  node.multimesh.mesh=meshes[serial]
  node.multimesh.instance_count=groups[serial].size()
  for i in groups[serial].size():node.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,groups[serial][i]))
  group.add_child(node)

static func furnish(root:Node3D,boxes,p:Vector3,span:Vector2,serial:int,kind:String,groups:Dictionary):
 var wood=Fort.material(Color("936e49"),false)
 var dark=Fort.material(Color("563f2d"),false)
 var pale=Fort.material(Color("c5b185"),false)
 var iron=Fort.material(Color("67736b"),false)
 var glaze=Fort.material(Color("76928b") if serial in [16790,16793,16520,16650] else Color("b18a5d"),false)
 if kind in ["coast_wall","coast_picture","coast_counter","coast_cabinet","coast_apothecary","coast_display","coast_weapons","coast_rug","coast_native"]:
  if not meshes.has(serial):meshes[serial]=painted_shape(serial,kind)
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append(p)
  return
 var prop=Node3D.new()
 prop.name="CoastalProp_"+str(serial)
 prop.position=p
 prop.set_meta("source_graphic",serial)
 root.add_child(prop)
 match kind:
  "coast_side_barrel":
   Geo.cylinder(prop,Vector3.UP*.64,.60,1.55,wood).rotation.z=PI*.5
   for side in [-1,1]:Geo.torus(prop,Vector3(side*.57,.64,0),.55,.63,iron).rotation.z=PI*.5
  "coast_open_crate":
   boxes.add(p+Vector3.UP*.10,Vector3(1.45,.20,1.45),dark)
   for side in [-1,1]:
    boxes.add(p+Vector3(side*.68,.58,0),Vector3(.14,.96,1.45),wood)
    boxes.add(p+Vector3(0,.58,side*.68),Vector3(1.45,.96,.14),wood)
  "coast_book":
   boxes.add(p+Vector3.UP*.17,Vector3(.73,.21,.57),pale)
   for y in [.045,.30]:boxes.add(p+Vector3.UP*y,Vector3(.79,.06,.63),Fort.material(Color("8e4a3d"),false))
  "coast_embers":
   Geo.cylinder(prop,Vector3.UP*.27,.42,.54,iron,false,.58)
   Geo.torus(prop,Vector3.UP*.56,.49,.59,iron)
   for i in 6:
    var a=i*TAU/6
    Geo.sphere(prop,Vector3(cos(a)*.29,.54,sin(a)*.29),Vector3(.26,.15,.25),Fort.material(Color("ba6638") if i%2 else Color("4d4039"),false))
  "coast_cushion":
   Geo.sphere(prop,Vector3.UP*.23,Vector3(1.30,.46,1.10),pale)
  "coast_fruit":
   for i in 3:Geo.sphere(prop,Vector3((i-1)*.38,.19,(i%2)*.26),Vector3(.38,.38,.37),Fort.material(Color("c99942"),false))
  "coast_stool":
   if serial in [16530,17534]:Inn.stool(prop,Vector3.ZERO,wood,iron)
   else:
    var paint=Fort.material(Color("608d84") if serial==16786 else Color("7a895c"),false)
    boxes.add(p+Vector3.UP*.91,Vector3(1.0,.18,1.0),paint)
    for x in [-.39,.39]:
     for z in [-.39,.39]:boxes.add(p+Vector3(x,.43,z),Vector3(.12,.86,.12),paint)
  "coast_pot","coast_bin","coast_basket":
   var basket=kind=="coast_basket"
   var radius=.55 if basket else .42
   Geo.cylinder(prop,Vector3.UP*.38,radius*.70,.76,wood if basket else glaze,false,radius)
   Geo.torus(prop,Vector3.UP*.78,radius*.76,radius*1.03,pale if basket else glaze)
   if basket:
    for i in 4:
     var at=Vector3((i%2-.5)*.39,.80,(i/2-.5)*.39)
     Geo.sphere(prop,at,Vector3(.45,.34,.45),Fort.material(Color("e2d9bc") if serial in [11007,16601,16637] else Color("c47c45"),false))
  "coast_basin":
   Geo.cylinder(prop,Vector3.UP*.10,.44,.20,wood)
   Geo.cylinder(prop,Vector3.UP*.78,.12,1.5,wood)
   Geo.cylinder(prop,Vector3.UP*1.53,.43,.18,glaze,false,.55)
   Geo.cylinder(prop,Vector3.UP*1.64,.48,.025,Fort.material(Color("7399ad"),false))
  "coast_trough":
   boxes.add(p+Vector3.UP*.15,Vector3(span.x*.81,.3,span.y*.81),pale)
   for side in [-1,1]:
    boxes.add(p+Vector3(side*span.x*.40,.52,0),Vector3(.20,.76,span.y*.85),pale)
    boxes.add(p+Vector3(0,.52,side*span.y*.40),Vector3(span.x*.85,.76,.20),pale)
  "coast_stove":
   boxes.add(p+Vector3.UP*.64,Vector3(1.7,1.28,1.7),Fort.material(Color("acaa91")))
   Geo.cylinder(prop,Vector3.UP*1.30,.53,.08,dark)
   if serial==16619:Geo.sphere(prop,Vector3.UP*1.41,Vector3(.72,.21,.72),Fort.material(Color("d2a54b"),false))
  "coast_dining","coast_desk","coast_shelf":
   var top=Vector3(span.x*.76,.19,span.y*.76)
   var y=1.32
   boxes.add(p+Vector3.UP*y,top,wood)
   for x in [-1,1]:
    for z in [-1,1]:boxes.add(p+Vector3(x*top.x*.43,y*.5,z*top.z*.43),Vector3(.17,y,.17),dark)
   if kind=="coast_dining":
    boxes.add(p+Vector3.UP*1.43,Vector3(top.x*.79,.04,top.z*.79),Fort.material(Color("c1baa0"),false))
    for side in [-1,1]:
     Geo.cylinder(prop,Vector3(side*top.x*.28,1.49,0),.30,.05,pale)
     Geo.cylinder(prop,Vector3(side*top.x*.28,1.60,.55),.14,.24,glaze)
   elif kind=="coast_desk":
    boxes.add(p+Vector3(.20,1.45,0),Vector3(.85,.06,.66),pale)
    for i in 4:boxes.add(p+Vector3(-top.x*.34+i*.18,1.73,-top.z*.26),Vector3(.13,.72,.49),Fort.material(Color(["677e79","a9874d","946650","65718b"][i]),false))
   else:
    for i in 4:
     var at=Vector3((i-1.5)*top.x*.19,1.61,0)
     Geo.cylinder(prop,at,.20,.42,glaze,false,.16)
     Geo.cylinder(prop,at+Vector3.UP*.30,.09,.20,glaze)
  "coast_clock":
   boxes.add(p+Vector3.UP*2.9,Vector3(.7,.95,.22),wood)
   Geo.cylinder(prop,Vector3(0,2.9,.14),.27,.08,pale).rotation.x=PI*.5
   Geo.beam(prop,Vector3(0,2.4,0),Vector3(0,1.7,0),.035,iron)
   Geo.sphere(prop,Vector3(0,1.7,0),Vector3(.20,.20,.08),pale)
  "coast_tool":
   Geo.beam(prop,Vector3(-.35,.12,0),Vector3(.32,2.2,0),.055,wood)
   Geo.box(prop,Vector3(-.34,.18,0),Vector3(.64,.31,.16),pale if serial in [16548,16549] else iron)
  "coast_logs":
   for i in 4:Geo.beam(prop,Vector3(-.55,.22+i*.12,-.45),Vector3(.55,.22+i*.12,.45),.15,wood)
  "coast_hanging":
   Geo.beam(prop,Vector3(-1.25,2.9,0),Vector3(1.25,2.9,0),.065,wood)
   for i in 4:
    var x=(i-1.5)*.58
    Geo.beam(prop,Vector3(x,2.9,0),Vector3(x,2.4,0),.025,dark)
    Geo.sphere(prop,Vector3(x,2.23,0),Vector3(.24,.48,.26),pale)
  "coast_post":
   boxes.add(p+Vector3.UP*2.4,Vector3(.27,4.8,.27),wood)
   boxes.add(p+Vector3(.72,3.8,0),Vector3(1.45,.22,.22),wood)
  "coast_robe":
   var cloth=Fort.material(Color(["415f97","c99a4a","b5b498"][serial-16780]),false)
   Geo.cylinder(prop,Vector3.UP*.86,.48,1.72,cloth,false,.23)
   Geo.sphere(prop,Vector3.UP*1.85,Vector3(.6,.45,.43),cloth)
  "coast_goods":
   for side in [-1,1]:Geo.sphere(prop,Vector3(side*.24,.20,0),Vector3(.38,.32,.59),Fort.material(Color("a47642"),false))
  "coast_flowers","coast_wreath":
   for i in 8:
    var a=i*TAU/8
    var at=Vector3(cos(a)*.38,.28,sin(a)*.38) if kind=="coast_flowers" else Vector3(cos(a)*.45,2.7+sin(a)*.57,0)
    Geo.sphere(prop,at,Vector3(.20,.17,.18),Fort.material(Color("c29a58") if i%2 else Color("6e9360"),false))
  "coast_lute":
   Geo.sphere(prop,Vector3(0,1.7,0),Vector3(.68,.88,.22),pale)
   Geo.beam(prop,Vector3(0,1.9,0),Vector3(.2,3.1,0),.09,wood)
  "coast_bird":
   Geo.cylinder(prop,Vector3.UP*1.1,.07,2.2,wood)
   Geo.beam(prop,Vector3(-.5,2.2,0),Vector3(.5,2.2,0),.06,wood)
   Geo.sphere(prop,Vector3(0,2.45,0),Vector3(.35,.60,.30),Fort.material(Color("79a842"),false))
   Geo.sphere(prop,Vector3(0,2.76,.05),Vector3(.26,.26,.26),pale)
  "coast_wheel":
   var ring=Geo.torus(prop,Vector3.UP*.86,.60,.69,wood)
   ring.rotation.x=PI*.5
   for i in 8:
    var a=i*TAU/8
    Geo.beam(prop,Vector3.UP*.86,Vector3(cos(a)*.6,.86+sin(a)*.6,0),.035,wood)
   for side in [-1,1]:Geo.beam(prop,Vector3(side*.5,0,0),Vector3(0,1.7,0),.07,wood)
  "coast_hammock":
   for side in [-1,1]:
    boxes.add(p+Vector3(side*span.x*.43,1.8,0),Vector3(.20,3.6,.20),wood)
   for i in 12:
    var x=(i-5.5)*span.x*.067
    boxes.add(p+Vector3(x,1.1+.4*pow(absf(x)/(span.x*.43),2),0),Vector3(span.x*.068,.09,.85),pale)
  "coast_candles":
   Geo.cylinder(prop,Vector3.UP*.4,.12,.8,pale)
   for i in 3:
    var x=(i-1)*.28
    Geo.beam(prop,Vector3(0,.52,0),Vector3(x,.82,0),.04,pale)
    Geo.cylinder(prop,Vector3(x,1.05,0),.06,.46,pale)
  "coast_scale":
   boxes.add(p+Vector3.UP*.40,Vector3(.66,.8,.55),iron)
   Geo.sphere(prop,Vector3(0,.66,.29),Vector3(.43,.43,.08),pale)
   Geo.cylinder(prop,Vector3.UP*.93,.45,.12,wood)
  "coast_stair":
   var along_x=span.x>span.y
   var length=maxf(span.x,span.y)
   var width=minf(span.x,span.y)*.85
   var rise=2.7 if serial in [16590,16592] else 1.3
   for i in 9:
    var height=(i+1)*rise/9.0
    var offset=(i-4)*length/9.0
    var at=Vector3(offset,height*.5,0) if along_x else Vector3(0,height*.5,offset)
    var size_=Vector3(length/9.0+.01,height,width) if along_x else Vector3(width,height,length/9.0+.01)
    boxes.add(p+at,size_,wood if serial in [16590,16592,16594,16595] else pale)
   if serial in [16590,16592]:
    for side in [-1,1]:
     var a=Vector3(-length*.46,.7,side*width*.5) if along_x else Vector3(side*width*.5,.7,-length*.46)
     var b=Vector3(length*.46,rise+.7,side*width*.5) if along_x else Vector3(side*width*.5,rise+.7,length*.46)
     Geo.beam(prop,a,b,.065,wood)
  _:assert(false,"Missing coastal furnishing: "+kind)

static func painted_shape(serial:int,kind:String,art:Array=[],atlas:Texture2D=Atlas)->Mesh:
 if kind=="coast_native":return native_shape(serial)
 if art.is_empty():art=Data.GRAPHICS[serial]
 var span:Vector2=art[2]
 var rect:Rect2=art[0]
 var scale_=clampf(rect.size.x/((span.x+span.y)*32.0/3.0),.22,1.0)
 var extent=span*scale_
 var height=maxf(.20,(rect.size.y-(span.x+span.y)*8*scale_)*4.8/139.0)
 var skin=SourceMesh.new(art,atlas,4.8/139.0)
 if kind=="coast_wall":
  skin.box(AABB(Vector3(-span.x*.5,0,-span.y*.5),Vector3(span.x,height,span.y)))
 elif kind=="coast_rug":
  skin.quad(Vector3(-span.x*.5,.04,-span.y*.5),Vector3(span.x*.5,.04,-span.y*.5),Vector3(span.x*.5,.04,span.y*.5),Vector3(-span.x*.5,.04,span.y*.5))
 elif kind=="coast_picture":
  var horizontal=serial in [11118,16586,16798,17604]
  if horizontal:skin.box(AABB(Vector3(-1.45,1.6,-.055),Vector3(2.9,2.7,.11)))
  else:skin.box(AABB(Vector3(-.055,1.6,-1.45),Vector3(.11,2.7,2.9)))
 else:
  if kind in ["coast_weapons","coast_apothecary"]:
   extent=Vector2(span.x*.86,.63) if span.x>span.y else Vector2(.63,span.y*.86)
  height=minf(height,4.5)
  skin.box(AABB(Vector3(-extent.x*.5,0,-extent.y*.5),Vector3(extent.x,height,extent.y)))
 return skin.finish()

static func native_shape(serial:int)->Mesh:
 var art=load("res://scripts/forest/forest_original_map_art.gd")
 var forms=load("res://scripts/forest/forest_original_map_solids.gd")
 var g:Dictionary=art.data().graphics.get(str(serial),{}).duplicate(true)
 var texture:Texture2D
 if g.is_empty():
  g=Data.NATIVE[serial].duplicate(true)
  var rect:Rect2=Data.GRAPHICS[serial][0]
  g.rect=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
  texture=Atlas
 else:texture=art.solid_texture(int(g.page))
 if g.family.is_empty() or g.family=="coast_native":g.family=Data.NATIVE[serial].family
 var raw:Mesh=forms.mesh(serial,forms.kind(serial,false,g),g,texture)
 var offset=Vector3((float(g.footprint[0])-1.)*1.5,0,(1.-float(g.footprint[1]))*1.5)
 return PartsFit.transformed(raw,Transform3D(Basis.IDENTITY,-offset))

const PartsFit=preload("res://scripts/forest/forest_falan_proportions.gd")
