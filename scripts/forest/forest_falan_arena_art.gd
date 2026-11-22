extends RefCounted
## The original stairs and platforms share a surface with the room floor and its collider.
const Data=preload("res://assets/maps/falan/room_art_data.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const RAISED=[1401,1403]
const MAIN_LINK=Vector2(3,174)
const SIDE_LINK=Vector2(3,-165)
const ANNEX_RETURNS={
 1420:[Vector2(-12,-9),Vector2(-12,-12)],
 1421:[Vector2(-12,9),Vector2(3,-12)],
 1422:[Vector2(-27,3),Vector2(18,-12)],
}
static var ring_arch:Mesh

static func surface_height(id:int,x:float,z:float)->float:
 var p=Vector2(x,z)
 if id==1401:
  if z<0:return terrace(p,Vector2(3,-129),Vector2(24,24),6.0)*1.44
  var lower=terrace(p,Vector2(1.5,123),Vector2(58.5,39),6.0)*1.56
  return lower+terrace(p,Vector2(3,123),Vector2(18,18),6.0)*1.16
 if id==1403:
  return maxf(terrace(p,Vector2(-36,-3),Vector2(15,15),6.0),
   terrace(p,Vector2(9,-3),Vector2(15,15),6.0))*1.28
 return 0.0

static func terrace(p:Vector2,center:Vector2,half:Vector2,bevel:float)->float:
 var q=(p-center).abs()
 var edge=maxf(maxf(q.x-half.x,q.y-half.y),(q.x+q.y-half.x-half.y+bevel)*.707107)
 return clampf(.5-edge/3.0,0.0,1.0)

static func exterior(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,copper:Material):
 var iron=Fort.material(Color("45483e"),false)
 var flags=Fort.material(Color("a84436"),false)
 if ring_arch==null:ring_arch=load("res://scripts/forest/forest_freyja_art.gd").arch_mesh(1.50,trim)
 root.scale.x=1.11
 for spec in [[.32,.64,11.91,base],[5.33,.44,11.58,trim],[10.75,.44,11.55,trim],[11.66,.49,11.28,pale]]:
  var band=Geo.cylinder(root,Vector3.UP*spec[0],spec[2],spec[1],spec[3])
  band.mesh.radial_segments=56
 Geo.cylinder(root,Vector3.UP*5.61,9.44,10.82,iron).mesh.radial_segments=32
 Geo.cylinder(root,Vector3.UP*10.51,10.86,.28,stone).mesh.radial_segments=56
 for bay in 14:
  var yaw=bay*TAU/14-PI*.5
  var axis=Basis(Vector3.UP,yaw)
  var radial=axis.x
  var tangent=axis.z
  var center=radial*11.0
  var panel=Node3D.new()
  panel.transform=Transform3D(axis,center)
  root.add_child(panel)
  for level in [0.62,6.12]:
   var arch=Geo.mesh(panel,ring_arch,Vector3.UP*level,null)
   arch.set_surface_override_material(0,stone)
   arch.scale=Vector3(1.0,.81,.429)
   if bay!=0 or level>1.0:
    var rail=Geo.box(panel,Vector3(.70,level+.86,0),Vector3(.23,.20,3.83),trim)
    rail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for i in 8:
     Geo.box(panel,Vector3(.72,level+.44,(i-3.5)*.49),Vector3(.22,.86,.15),pale)
  var pier=center+tangent*2.46
  Geo.cylinder(root,pier+Vector3.UP*5.48,.53,10.96,pale,false,.39)
  for level in [1.02,4.58,5.68,9.98]:
   Geo.cylinder(root,pier+Vector3.UP*level,.62,.29,trim)
  if bay%2==0:
   Geo.box(panel,Vector3(.79,10.42,0),Vector3(.18,.86,1.03),base)
   var badge=Geo.cylinder(panel,Vector3(.89,10.43,0),.33,.13,trim)
   badge.rotation.z=PI*.5
  if bay in [1,3,11,13]:
   Geo.box(panel,Vector3(.89,7.48,1.58),Vector3(.12,3.42,.63),flags)
   Geo.box(panel,Vector3(.96,9.20,1.58),Vector3(.18,.11,.96),copper)
   Geo.box(panel,Vector3(.96,6.14,1.58),Vector3(.14,.11,.67),copper)
  for offset in [-1.58,0,1.58]:
   Geo.box(panel,Vector3(.15,12.07,offset),Vector3(.76,.88,.67),trim)
 for side in [-1,1]:
  Court.tower(boxes,Vector3(side*4.22,10.58,-5.31),4.78,6.65,pale,trim,stone,iron)
 boxes.add(Vector3(0,13.32,-5.45),Vector3(4.02,5.66,5.32),stone)
 boxes.add(Vector3(0,14.25,-2.77),Vector3(1.52,1.43,.07),iron)
 boxes.add(Vector3(0,14.25,-2.72),Vector3(1.04,.96,.08),copper)
 boxes.add(Vector3(0,16.19,-5.45),Vector3(4.38,.41,5.64),trim)
 load("res://scripts/forest/forest_falan_civic_exterior.gd").roof(root,Vector3(0,16.34,-5.45),4.81,6.0,3.22,slate,trim)
 for i in 3:
  boxes.add(Vector3(0,.09+i*.17,11.84-i*.28),Vector3(4.11,.18+i*.34,.81),pale)

static func build_rooms(root:Node3D,boxes,id:int,origin:Vector2,atlas:ShaderMaterial,main_only:bool=false):
 if id in RAISED:stairs(boxes,id,origin,main_only)
 if id==1401:
  var inlays=SurfaceTool.new()
  inlays.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in Data.ARENA_MARKS:
   if main_only and row[0].y<90:continue
   var at=origin+Vector2(row[0])*3.0
   var y=surface_height(id,at.x,at.y)
   for uv:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
    var point=at+(uv-Vector2.ONE*.5)*13.52
    inlays.set_normal(Vector3.UP)
    inlays.set_uv(Vector2((row[1]+lerpf(.004,.996,uv.x))/5.0,uv.y))
    inlays.add_vertex(Vector3(point.x,y+.047,point.y))
  var ring=Geo.mesh(root,inlays.commit(),Vector3.ZERO,atlas)
  ring.name="FalanArenaInlays"
  ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var battlements=Node3D.new()
  battlements.scale.y=.59
  root.add_child(battlements)
  var pale=Fort.material(Color("c2b69a"))
  var coping=Fort.material(Color("dcccaa"),false)
  var stone=Fort.material(Color("929481"))
  var dark=Fort.material(Color("51564a"),false)
  var brick=Fort.material(Color("a17654"),false)
  var blocks=Boxes.new()
  for row in Data.ARENA_FORTS:
   if main_only:continue
   var at=origin+Vector2(row[0])*3.0
   var p=Vector3(at.x,0,at.y)
   if row[1] in [10640,10641]:Court.curtain_wall(blocks,p,row[1]==10641,pale,stone,coping,dark)
   else:Court.tower(blocks,p,9.0,17.5,pale,coping,brick,dark)
  blocks.build(battlements)
 elif id==1403:
  var flowers={}
  for row in Data.ARENA_FLOWERS:
   var at=origin+Vector2(row[0])*3.0
   var p=Vector3(at.x,surface_height(id,at.x,at.y),at.y)
   var serial:int=row[1]
   var asset="flowers_coral" if serial in [10403,10404] else "flowers_blue" if serial in range(11627,11634) else "flowers_ivory"
   if not flowers.has(asset):flowers[asset]=[]
   if serial in [10403,10404]:
    Geo.cylinder(root,p+Vector3.UP*.24,.30,.48,Fort.material(Color("aca998")),false,.42)
    p.y+=.48
   var potted=serial in [10403,10404]
   var count=3 if potted else 5
   for i in count:
    var angle=i*TAU/count+serial
    var scale_=1.15 if potted else 1.73+float(i%3)*.14
    flowers[asset].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_),
     p+Vector3(cos(angle),0,sin(angle))*(.25 if potted else .70)))
  for asset in flowers:Assets.batch(root,asset,flowers[asset])
  garden_arch(root,boxes)
 elif id in Data.ARENA_BOARDS:
  var wood=Fort.material(Color("795036"),false)
  var trim=Fort.material(Color("bc9b60"),false)
  var red=Fort.material(Color("a43f32"),false)
  var blue=Fort.material(Color("396078"),false)
  for row in Data.ARENA_BOARDS[id]:
   var at=origin+Vector2(row[0])*3.0
   var p=Vector3(at.x,0,at.y)
   var turned=row[1]==11025
   for side in [-1,1]:
    Court.part(boxes,p,turned,Vector3(side*1.12,1.53,0),Vector3(.14,3.06,.15),wood)
    Court.part(boxes,p,turned,Vector3(side*1.12,3.13,0),Vector3(.23,.18,.23),trim)
   Court.part(boxes,p,turned,Vector3(0,2.69,0),Vector3(2.24,1.04,.20),wood)
   Court.part(boxes,p,turned,Vector3(0,3.24,0),Vector3(2.31,.16,.29),trim)
   for side in [-1,1]:
    Court.part(boxes,p,turned,Vector3(0,2.39,side*.119),Vector3(2.08,.22,.042),red)
    for i in range(-2,3):
     Court.part(boxes,p,turned,Vector3(i*.35,2.40,side*.147),Vector3(.19,.13,.036),blue if i%2==0 else trim)

static func stairs(boxes,id:int,origin:Vector2,main_only:bool=false):
 var pale=Fort.material(Color("d4ccb6"))
 var trim=Fort.material(Color("e4d9c1"),false)
 var directions=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]
 for row in Data.ARENA_STAIRS[id]:
  if main_only and row[0].y<90:continue
  var center=origin+Vector2(row[0])*3.0
  var rise:Vector2=directions[row[1]-17111]
  for step in 4:
   var low=center+rise*(-1.5+step*.75)
   var high=low+rise*.75
   var start=surface_height(id,low.x,low.y)
   var top=surface_height(id,high.x,high.y)
   if top-start<.05:continue
   var middle=(low+high)*.5
   var depth=top-start+.075
   var size_=Vector3(.754,depth,3.01) if rise.x!=0 else Vector3(3.01,depth,.754)
   boxes.add(Vector3(middle.x,top+.044-depth*.5,middle.y),size_,pale)
   var nosing=middle-rise*.31
   var lip=Vector3(.12,.042,3.01) if rise.x!=0 else Vector3(3.01,.042,.12)
   boxes.add(Vector3(nosing.x,top+.052,nosing.y),lip,trim)

static func garden_arch(root:Node3D,boxes):
 var stone=Fort.material(Color("bab29a"))
 var trim=Fort.material(Color("dbca9f"),false)
 var carving=Fort.material(Color("c8b48e"))
 for x in [-21.0,-6.0]:
  boxes.add(Vector3(x,.48,36),Vector3(2.11,.96,2.22),stone)
  Geo.cylinder(root,Vector3(x,3.5,36),.64,5.3,carving,false,.51)
  for y in [1.10,3.58,6.15]:Geo.cylinder(root,Vector3(x,y,36),.82,.36,trim)
 var last=Vector3(-21,6.15,36)
 for i in range(1,15):
  var t=i/14.0
  var p=Vector3(lerpf(-21,-6,t),6.15+sin(t*PI)*3.35,36)
  Geo.beam(root,last,p,.53,trim)
  Geo.beam(root,last+Vector3.DOWN*.49,p+Vector3.DOWN*.49,.18,carving)
  last=p

static func furnish(root:Node3D,boxes,p:Vector3,length_:float,kind:String,serial:int):
 var stone=Fort.material(Color("c4b9a1"))
 var trim=Fort.material(Color("e1d5ba"),false)
 var timber=Fort.material(Color("a4784f"),false)
 match kind:
  "arena_counter":
   var corner=serial==17613
   var turned=serial in [17615,17617]
   var face=Vector3(0,1.41,0)
   Court.part(boxes,p,turned,Vector3.UP*.62,Vector3(2.98,1.24,1.52),stone)
   Court.part(boxes,p,turned,face,Vector3(3.01,.26,1.78),timber)
   if corner:
    Court.part(boxes,p,false,Vector3.UP*.62,Vector3(1.52,1.24,2.98),stone)
    Court.part(boxes,p,false,face,Vector3(1.78,.26,3.01),timber)
   for side in [-1,1]:Court.part(boxes,p,turned,Vector3(0,.17,side*.73),Vector3(3.0,.18,.17),trim)
   if serial in [17617,17621]:
    Court.part(boxes,p,turned,Vector3(.43,1.58,.12),Vector3(.62,.12,.48),trim)
    Court.part(boxes,p,turned,Vector3(.43,1.648,.12),Vector3(.065,.025,.40),timber)
    if serial==17617:
     Geo.cylinder(root,p+Vector3(-.48,1.72,0),.11,.35,Geo.mat("698e78"),false,.074)
  "arena_gallery":
   var turned=serial in [17106,17107]
   for step in 4:
    var height=.45+step*.39
    Court.part(boxes,p,turned,Vector3(0,height*.5,(step-1.5)*1.12),Vector3(length_*.87,height,1.16),stone)
    Court.part(boxes,p,turned,Vector3(0,height,(step-1.5)*1.12),Vector3(length_*.90,.13,1.19),trim)
  "arena_tree":
   Assets.batch(root,"broadleaf_tree",[Transform3D(Basis(Vector3.UP,serial).scaled(Vector3(.88,.94,.88)),p)],true)
  "arena_statue":
   Statues.build(root,boxes,p,10400)
