extends RefCounted
## Original 17012/17013 cabinets, 17541 hutch, 17537/17538 beds and 17533 cushions.
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const DetailData=preload("res://assets/maps/falan/interior_details.gd")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
static var detail_materials:Dictionary={}
static var detail_quad:QuadMesh
static var meshes:Dictionary={}
const OFFICE_FAMILIES={17573:"bookcase",17587:"bookcase",17539:"desk",17572:"desk",17027:"chair",17028:"chair",17013:"cabinet"}

static func handles(id:int,serial:int)->bool:
 return (id==1101 and serial in [17012,17013]) or (id in [1111,1112] and serial in [17537,17538,17541]) or (id in [1091,1092] and OFFICE_FAMILIES.has(serial))

static func build(root:Node3D,id:int,serial:int,p:Vector3,width:float,length_:float,swap:bool):
 var family="cabinet" if serial in [17012,17013] else "hutch" if serial==17541 else "bed"
 if id in [1091,1092]:family=OFFICE_FAMILIES[serial]
 var key=[family,width,length_,serial if family in ["bookcase","desk"] else serial==17537]
 if not meshes.has(key):
  if family=="bed":meshes[key]=bed(width,length_,-1 if serial==17537 else 1)
  elif family in ["cabinet","hutch"]:meshes[key]=cabinet(width,length_,family=="hutch")
  elif family=="bookcase":meshes[key]=bookcase(width,length_,serial==17573)
  elif family=="desk":meshes[key]=desk(width,length_,serial==17572)
  elif family=="chair":meshes[key]=chair()
 var node=Geo.mesh(root,meshes[key],p,null)
 node.rotation.y=(-PI*.5 if family in ["cabinet","hutch","bookcase","desk"] else PI*.5) if swap else 0.0
 if family=="chair":node.rotation.y=-PI*.5 if serial==17028 else 0.0
 node.name="RecoveredInterior_%d"%serial
 node.set_meta("falan_interior_serial",serial);node.set_meta("falan_interior_floor",id)
 node.set_meta("falan_furniture_family",family);node.set_meta("falan_furniture_key",key)
 return node

static func tool()->SurfaceTool:
 var result=SurfaceTool.new();result.begin(Mesh.PRIMITIVE_TRIANGLES);return result

static func finish(tools:Array,materials:Array)->Mesh:
 var result=ArrayMesh.new()
 for i in tools.size():
  var part=tools[i].commit()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0));result.surface_set_material(i,materials[i])
 return result

static func bottle(glass:SurfaceTool,label:SurfaceTool,p:Vector3,height:float):
 Parts.rod(glass,p+Vector3.UP*height*.03,p+Vector3.UP*height*.57,height*.13)
 Parts.oval(glass,p+Vector3.UP*height*.57,Vector3(height*.26,height*.20,height*.26))
 Parts.rod(glass,p+Vector3.UP*height*.60,p+Vector3.UP*height*.94,height*.06)
 Parts.rod(label,p+Vector3.UP*height*.94,p+Vector3.UP*height,height*.068)
 Parts.rod(label,p+Vector3.UP*height*.20,p+Vector3.UP*height*.40,height*.1325)

static func cabinet(width:float,length_:float,medicine:bool)->Mesh:
 Parts.prepare_primitives()
 var wood=tool();var trim=tool();var contents=tool();var light=tool()
 var depth=width*.48;var span=length_*.90;var height=3.62 if medicine else 3.85
 Parts.block(wood,Vector3(-depth*.43,height*.5,0),Vector3(.13,height,span))
 for z in [-span*.5,span*.5]:Parts.block(wood,Vector3(0,height*.5,z),Vector3(depth,height,.18))
 for y in [.12,1.04,height-.10]:Parts.block(trim,Vector3(0,y,0),Vector3(depth+.10,.17,span+.13))
 Parts.block(wood,Vector3(0,.56,0),Vector3(depth,.92,span))
 var doors=2
 for i in doors:
  var z=(float(i)+.5)/doors*span-span*.5
  Parts.block(trim,Vector3(depth*.51,.56,z),Vector3(.08,.71,span/doors-.08))
  Parts.block(wood,Vector3(depth*.56,.56,z),Vector3(.04,.54,span/doors-.25))
  Parts.oval(light,Vector3(depth*.60,.59,z-signf(z)*span/doors*.25),Vector3(.10,.10,.10))
  Parts.block(trim,Vector3(depth*.51,.95,z),Vector3(.09,.15,span/doors-.08))
  Parts.oval(light,Vector3(depth*.60,.95,z),Vector3(.10,.08,.10))
 var levels=[1.15,2.30] if not medicine else [1.15,2.45,3.05]
 for y in levels:Parts.block(trim,Vector3(0,y,0),Vector3(depth,.10,span))
 if not medicine:
  var count_=7
  for row in 2:
   for i in count_:
    var z=(float(i)+.5)/count_*span-span*.5
    bottle(contents,light,Vector3(depth*.12,levels[row]+.02,z),.75+(i%3)*.06)
 else:
  for row in [1,2]:
   for i in maxi(4,floori(span/.23)):
    var z=-span*.43+i*.23
    Parts.block(contents,Vector3(depth*.20,levels[row]+.25,z),Vector3(depth*.50,.41+(i%3)*.07,.15))
    for band in [-.12,.12]:Parts.block(trim,Vector3(depth*.46,levels[row]+.26+band,z),Vector3(.02,.018,.12))
  bottle(trim,light,Vector3(depth*.18,1.17,-span*.27),.75)
  Parts.block(contents,Vector3(depth*.13,1.46,span*.27),Vector3(depth*.56,.52,.64))
  for side in [-1,1]:Parts.rod(light,Vector3(depth*.13,1.72,span*.27+side*.20),Vector3(depth*.13,1.88,span*.27+side*.20),.035)
  Parts.rod(light,Vector3(depth*.13,1.88,span*.27-.20),Vector3(depth*.13,1.88,span*.27+.20),.035)
 return finish([wood,trim,contents,light],[Fort.material(Color("67412e"),false),Fort.material(Color("a87849"),false),Geo.mat("466d5a") if not medicine else Geo.mat("4d6085"),Geo.mat("e3d6bb")])

static func bed(width:float,length_:float,head:int)->Mesh:
 Parts.prepare_primitives()
 var wood=tool();var linen=tool();var covers=tool()
 Parts.block(wood,Vector3(0,.58,0),Vector3(width*.64,.40,length_*.82))
 Parts.block(linen,Vector3(0,.95,0),Vector3(width*.61,.44,length_*.78))
 for side in [-1,1]:
  for end in [-1,1]:
   var h=2.04 if end==head else 1.28
   Parts.block(wood,Vector3(side*width*.33,h*.5,end*length_*.41),Vector3(.22,h,.22))
   Parts.oval(wood,Vector3(side*width*.33,h-.03,end*length_*.41),Vector3(.25,.18,.25))
 Parts.block(wood,Vector3(0,1.48,head*length_*.41),Vector3(width*.64,.70,.17))
 Parts.block(wood,Vector3(0,1.81,head*length_*.41),Vector3(width*.66,.12,.23))
 Parts.block(wood,Vector3(0,.84,-head*length_*.41),Vector3(width*.64,.54,.16))
 Parts.oval(linen,Vector3(0,1.27,head*length_*.27),Vector3(width*.43,.28,length_*.17))
 var columns=16;var rows=24
 for y in rows:
  for x in columns:
   var points=[]
   for uv:Vector2 in [Vector2(float(x)/columns,float(y)/rows),Vector2(float(x)/columns,float(y+1)/rows),Vector2(float(x+1)/columns,float(y+1)/rows),Vector2(float(x+1)/columns,float(y)/rows)]:
    var fold=pow(absf(uv.x-.5)*2,8)*.31
    var rise=sin(uv.x*PI)*sin(uv.y*PI)*.055+sin(uv.y*PI*8)*sin(uv.x*PI)*.018
    points.append(Vector3((uv.x-.5)*width*.64,1.23+rise-fold,(uv.y-.5)*length_*.59-head*length_*.07))
   Shapes.quad(covers,points[0],points[3],points[2],points[1])
 Parts.oval(linen,Vector3(0,1.22,-head*length_*.35),Vector3(width*.63,.16,length_*.075))
 return finish([wood,linen,covers],[Fort.material(Color("885c37"),false),Fort.material(Color("e8dfce"),false),Fort.material(Color("b3a27c"),false)])

static func bench(width:float,length_:float)->Mesh:
 Parts.prepare_primitives();var wood=tool();var cloth=tool()
 Parts.block(wood,Vector3(0,.37,0),Vector3(width,.70,length_))
 Parts.block(wood,Vector3(0,.68,0),Vector3(width,.15,length_+.06))
 Parts.oval(cloth,Vector3(0,.80,0),Vector3(width,.26,length_))
 for side in [-1,1]:Parts.oval(cloth,Vector3(side*width*.43,.80,0),Vector3(width*.16,.27,length_))
 return finish([wood,cloth],[Fort.material(Color("6a4a31"),false),Fort.material(Color("c4b18b"),false)])

static func bank_bench(root:Node3D,p:Vector3):
 var key=["bank_bench"]
 if not meshes.has(key):meshes[key]=bench(2.98,1.46)
 var node=Geo.mesh(root,meshes[key],p,null)
 node.set_meta("falan_interior_serial",17533);node.set_meta("falan_interior_floor",1121)
 node.set_meta("falan_furniture_family","bench");node.set_meta("falan_furniture_key",key)

static func panel(root:Node3D,feature:String,p:Vector3,size_:Vector2,yaw:float=0.0):
 if detail_quad==null:detail_quad=QuadMesh.new();detail_quad.size=Vector2.ONE
 if not detail_materials.has(feature):
  var rect:Rect2=DetailData.FEATURES[feature]
  var material:ShaderMaterial=SourceMesh.material(DetailData.ATLAS).duplicate()
  material.set_shader_parameter("uv_scale",(rect.size-Vector2.ONE)/DetailData.ATLAS.get_size())
  material.set_shader_parameter("uv_offset",(rect.position+Vector2.ONE*.5)/DetailData.ATLAS.get_size())
  material.set_shader_parameter("original_palette",false)
  detail_materials[feature]=material
 var node=Geo.mesh(root,detail_quad,p,detail_materials[feature])
 node.scale=Vector3(size_.x,size_.y,1);node.rotation.y=yaw
 node.set_meta("falan_interior_art",feature)
 return node


static func rounded_block(surface:SurfaceTool,p:Vector3,size_:Vector3,radius:float):
 # Indexed primitives need appended meshes; loose vertices would be unreferenced.
 var shape=tool()
 var edge=[]
 for corner in 4:
  var angle=corner*PI*.5
  var center=Vector3((size_.x*.5-radius)*(1 if corner in [0,3] else -1),0,(size_.z*.5-radius)*(1 if corner in [0,1] else -1))
  for step in 7:
   var t=angle+step*PI/12
   edge.append(center+Vector3(cos(t),0,sin(t))*radius)
 for i in edge.size():
  var a:Vector3=edge[i];var b:Vector3=edge[(i+1)%edge.size()]
  for side in [-1,1]:
   var y=Vector3.UP*size_.y*.5*side
   shape.set_normal(Vector3.UP*side)
   for point in [Vector3.ZERO,a,b] if side==1 else [Vector3.ZERO,b,a]:shape.add_vertex(p+y+point)
  Shapes.quad(shape,p+a-Vector3.UP*size_.y*.5,p+b-Vector3.UP*size_.y*.5,p+b+Vector3.UP*size_.y*.5,p+a+Vector3.UP*size_.y*.5)
 shape.index();surface.append_from(shape.commit(),0,Transform3D.IDENTITY)

static func bookcase(width:float,length_:float,double_bay:bool)->Mesh:
 Parts.prepare_primitives()
 var wood=tool();var trim=tool();var blue=tool();var red=tool();var paper=tool()
 var depth=width*.48;var span=length_*.90;var height=3.85
 Parts.block(wood,Vector3(-depth*.46,height*.5,0),Vector3(.12,height,span))
 for z in [-span*.5,span*.5]:Parts.block(wood,Vector3(0,height*.5,z),Vector3(depth,height,.15))
 for y in [.12,height-.12]:
  Parts.block(trim,Vector3(0,y,0),Vector3(depth+.14,.18,span+.16))
  Parts.rod(trim,Vector3(depth*.52,y-.03,-span*.51),Vector3(depth*.52,y-.03,span*.51),.045)
 var bays=2 if double_bay else 1
 if double_bay:Parts.block(wood,Vector3(0,height*.5,0),Vector3(depth,height,.15))
 for row in 5:
  var level=.27+row*.68
  Parts.block(trim,Vector3(0,level,0),Vector3(depth,.10,span))
  for bay in bays:
   var bay_span=span/bays-.24
   var count_=maxi(3,floori(bay_span/.21))
   for i in count_:
    var z=-span*.5+(bay+.5)*span/bays+(float(i)+.5)/count_*bay_span-bay_span*.5
    var h=.43+((i+row)%4)*.035
    var book=Vector3(depth*.12,level+.05+h*.5,z)
    Parts.block(red if (i+row)%5==0 else blue,book,Vector3(depth*.63,h,bay_span/count_*.77))
    for band in [-1,1]:Parts.block(trim,Vector3(depth*.444,book.y+band*h*.30,z),Vector3(.016,.018,bay_span/count_*.70))
    if i%4==1:Parts.block(paper,Vector3(depth*.453,book.y,z),Vector3(.018,.055,bay_span/count_*.52))
 return finish([wood,trim,blue,red,paper],[Fort.material(Color("71452e"),false),Fort.material(Color("b68a51"),false),Fort.material(Color("455e78"),false),Fort.material(Color("8a4832"),false),Fort.material(Color("d4c7a1"),false)])

static func desk(width:float,length_:float,writing:bool)->Mesh:
 Parts.prepare_primitives()
 var wood=tool();var trim=tool();var pages=tool();var blue=tool();var red=tool()
 var size_=Vector3(width*.72,.18,length_*.79)
 var radius=minf(size_.x,size_.z)*(.13 if writing else .30)
 rounded_block(trim,Vector3.UP*1.44,size_+Vector3(.08,.02,.08),radius)
 rounded_block(wood,Vector3.UP*1.53,Vector3(size_.x-.09,.08,size_.z-.09),radius*.90)
 Parts.block(wood,Vector3.UP*1.25,Vector3(size_.x*.93,.24,size_.z*.94))
 for side in [-1,1]:
  for end in [-1,1]:
   var leg=Vector3(side*size_.x*.37,0,end*size_.z*.39)
   Parts.block(wood,leg+Vector3.UP*.59,Vector3(.22,1.18,.22))
   Parts.oval(trim,leg+Vector3.UP*.16,Vector3(.27,.15,.27))
 Parts.block(wood,Vector3(0,.30,0),Vector3(size_.x*.74,.10,size_.z*.78))
 if writing:
  Parts.block(wood,Vector3(-size_.x*.35,.77,0),Vector3(.16,.86,size_.z*.78))
  Parts.block(wood,Vector3(0,.77,0),Vector3(size_.x*.69,.86,.12))
  for end in [-1,1]:
   var p=Vector3(size_.x*.14,1.60,end*size_.z*.27)
   ledger(pages,trim,p,Vector2(size_.x*.25,size_.z*.20))
  Parts.block(blue,Vector3(size_.x*.29,1.60,-size_.z*.05),Vector3(size_.x*.24,.06,size_.z*.17))
  quill(trim,pages,Vector3(-size_.x*.25,1.57,0))
 else:
  Parts.block(wood,Vector3(-size_.x*.35,.77,0),Vector3(.15,.86,size_.z*.77))
  for i in 11:
   var z=(float(i)/10-.5)*size_.z*.65
   Parts.block(red if i%3==0 else blue,Vector3(size_.x*.12,.59,z),Vector3(size_.x*.42,.45+(i%3)*.04,.13))
  var at=Vector3(0,1.58,-size_.z*.26)
  for i in 5:Parts.block(pages,at+Vector3.UP*(.018+i*.024),Vector3(size_.x*.59,.019,size_.z*.25))
  for i in 4:
   var y=1.62+i*.10;var z=size_.z*.25+(i%2)*.04
   Parts.block(red if i%2==0 else blue,Vector3(0,y,z),Vector3(size_.x*.63,.085,size_.z*.23))
   Parts.block(pages,Vector3(size_.x*.015,y,z),Vector3(size_.x*.62,.045,size_.z*.22))
  quill(trim,pages,Vector3(size_.x*.18,1.57,0))
 var surfaces=[wood,trim,pages,blue]
 var materials=[Fort.material(Color("865732"),false),Fort.material(Color("b58b50"),false),Fort.material(Color("eee0b4"),false),Fort.material(Color("3b6256"),false)]
 if not writing:surfaces.append(red);materials.append(Fort.material(Color("8e4430"),false))
 return finish(surfaces,materials)

static func ledger(pages:SurfaceTool,trim:SurfaceTool,p:Vector3,size_:Vector2):
 Parts.block(trim,p,Vector3(size_.x+.07,.055,size_.y+.08))
 for side in [-1,1]:
  var x=side*size_.x*.25
  Parts.block(pages,p+Vector3(x,.045,0),Vector3(size_.x*.49,.04,size_.y))
  for line in 5:
   Parts.block(trim,p+Vector3(x,.068,(line-2)*size_.y*.13),Vector3(size_.x*(.29+(line%2)*.06),.006,.014))

static func quill(ink:SurfaceTool,feather:SurfaceTool,p:Vector3):
 Parts.rod(ink,p,p+Vector3.UP*.10,.11)
 var end=p+Vector3(.20,.70,.08)
 Parts.rod(ink,p+Vector3.UP*.10,end,.012)
 Parts.oval(feather,end-Vector3(.03,.13,.02),Vector3(.11,.37,.05))

static func chair(plain_back:bool=true)->Mesh:
 Parts.prepare_primitives();var wood=tool();var trim=tool();var cushion=tool()
 rounded_block(trim,Vector3.UP*.86,Vector3(1.45,.16,1.40),.15)
 Parts.oval(cushion,Vector3(0,.99,0),Vector3(1.28,.20,1.23))
 for side in [-1,1]:
  for end in [-1,1]:Parts.rod(wood,Vector3(side*.59,.06,end*.57),Vector3(side*.50,.84,end*.48),.060)
  Parts.rod(trim,Vector3(.57,.35,side*.55),Vector3(-.57,.35,side*.55),.035)
  if plain_back:Parts.rod(wood,Vector3(.54,.87,side*.53),Vector3(.59,2.45,side*.63),.052)
 if plain_back:
  var back=tool()
  for i in 12:
   var a=float(i)/12*2-1;var b=float(i+1)/12*2-1
   var za=a*.61;var zb=b*.61
   var xa=.52+.12*(1-a*a);var xb=.52+.12*(1-b*b)
   var ya=2.20+.25*a*a;var yb=2.20+.25*b*b
   var p=Vector3(xa,1.24,za);var q=Vector3(xb,1.24,zb)
   var pa=Vector3(xa,ya,za);var pb=Vector3(xb,yb,zb);var depth=Vector3.RIGHT*.10
   Shapes.quad(back,p,pa,pb,q)
   Shapes.quad(back,p+depth,q+depth,pb+depth,pa+depth)
   Shapes.quad(back,pa,pa+depth,pb+depth,pb)
   Shapes.quad(back,p,q,q+depth,p+depth)
   if i==0:Shapes.quad(back,p,p+depth,pa+depth,pa)
   if i==11:Shapes.quad(back,q,pb,pb+depth,q+depth)
   Parts.rod(trim,Vector3(xa+.04,ya,za),Vector3(xb+.04,yb,zb),.045)
  back.index();wood.append_from(back.commit(),0,Transform3D.IDENTITY)
 return finish([wood,trim,cushion],[Fort.material(Color("83553a"),false),Fort.material(Color("b58a52"),false),Fort.material(Color("dfc6a1"),false)])

static func office_detail(root:Node3D,id:int,serial:int,p:Vector3):
 var key=["bank_bench"] if serial==17532 else ["office_door"] if serial==17559 else ["office_stool"]
 if not meshes.has(key):
  if serial==17532:meshes[key]=bench(2.98,1.46)
  elif serial==17559:meshes[key]=office_door()
  else:
   Parts.prepare_primitives();var wood=tool();var trim=tool()
   Parts.rod(trim,Vector3.UP*.87,Vector3.UP*.96,.43)
   Parts.rod(wood,Vector3.UP*.96,Vector3.UP*1.08,.40)
   for side in [-1,1]:
    for end in [-1,1]:Parts.rod(wood,Vector3(side*.30,.04,end*.30),Vector3(side*.20,.90,end*.20),.040)
    Parts.rod(trim,Vector3(side*.26,.36,-.26),Vector3(side*.26,.36,.26),.026)
    Parts.rod(trim,Vector3(-.26,.36,side*.26),Vector3(.26,.36,side*.26),.026)
   meshes[key]=finish([wood,trim],[Fort.material(Color("855c32"),false),Fort.material(Color("b68a4c"),false)])
 var node=Geo.mesh(root,meshes[key],p,null)
 if serial==17532:node.rotation.y=PI*.5
 node.set_meta("falan_interior_serial",serial);node.set_meta("falan_interior_floor",id)
 node.set_meta("falan_furniture_family","bench" if serial==17532 else "door" if serial==17559 else "stool");node.set_meta("falan_furniture_key",key)


static func office_door()->Mesh:
 Parts.prepare_primitives();var wood=tool();var trim=tool();var cloth=tool()
 for side in [-1,1]:
  Parts.block(wood,Vector3(side*1.20,1.88,-1.46),Vector3(.25,3.76,.31))
  Parts.block(trim,Vector3(side*1.20,3.70,-1.46),Vector3(.37,.16,.40))
 Parts.block(wood,Vector3(0,3.43,-1.46),Vector3(2.67,.72,.31))
 for y in [3.06,3.80]:Parts.block(trim,Vector3(0,y,-1.43),Vector3(2.86,.13,.42))
 for i in 7:
  var x=(i-3)*.30
  for j in 10:
   var y=.17+j*.28
   Parts.block(cloth,Vector3(x,y,-1.45),Vector3(.24,.25,.12))
   Parts.block(wood,Vector3(x,y-.11,-1.45),Vector3(.24,.025,.13))
   Parts.oval(trim,Vector3(x,y-.12,-1.36),Vector3(.10,.06,.07))
 return finish([wood,trim,cloth],[Fort.material(Color("67452e"),false),Fort.material(Color("ac8547"),false),Fort.material(Color("b7a173"),false)])
