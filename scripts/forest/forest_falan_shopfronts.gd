extends RefCounted
## Recover the doors' trades and slate palettes from their matching exterior sprites.
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")
static var portal_arch:Mesh
const PROFILES={
 1011:["blade",Color("9c4934")], 1012:["blade",Color("537774")],
 1021:["shield",Color("677348")], 1022:["shield",Color("3b6568")],
 1031:["bottle",Color("3f6678")], 1041:["star",Color("654b8c")],
 1051:["cask",Color("3d6282")], 1061:["produce",Color("3d6288")],
 1062:["produce",Color("3d6288")], 1071:["hammer",Color("456785")],
 1081:["cask",Color("396783")],
}

static func match_shops(model,links:Array)->Dictionary:
 var shops={}
 for link in links:
  var floor_:int=link.get("floor",-1)
  if not PROFILES.has(floor_):continue
  var best=16.0
  var chosen=null
  for anchor in model.props:
   if shops.has(anchor) or model.props[anchor].kind not in ["falan_shop","falan_townhouse"]:continue
   var p:Vector3=model.scenery_point(anchor)
   var delta:Vector2=link.at-Vector2(p.x,p.z)
   var forward=Vector2.DOWN.rotated(-deg_to_rad(model.props[anchor].rotation))
   var distance=delta.length()
   if distance<best and forward.dot(delta)>distance*.72:
    best=distance
    chosen=anchor
  if chosen!=null:shops[chosen]=floor_
 return shops

static func build(parent:Node3D,transform_:Transform3D,floor_:int):
 var profile:Array=PROFILES[floor_]
 var trade:String=profile[0]
 var root=Node3D.new()
 root.name="FalanShopfront_%d_%d_%d"%[floor_,roundi(transform_.origin.x),roundi(transform_.origin.z)]
 root.transform=transform_
 parent.add_child(root)
 var boxes=Boxes.new()
 var frame=Fort.material(Color("654e3c"),false)
 var brass=Fort.material(Color("c4a36b"),false)
 var dark=Fort.material(Color("3d514e"),false)
 var enamel=Fort.material(profile[1].darkened(.36),false)
 var stone=Fort.material(Color("b9aa87"))
 var coping=Fort.material(Color("dbc8a0"),false)
 var badge=Geo.mat("e4d0a2",.12)
 var sign=Vector3(0,5.62,6.53)
 boxes.add(sign,Vector3(2.99,1.19,.20),frame)
 boxes.add(sign+Vector3(0,0,.12),Vector3(2.75,1.04,.065),brass)
 boxes.add(sign+Vector3(0,0,.17),Vector3(2.54,.85,.065),enamel)
 for side in [-1,1]:
  var end=sign+Vector3(side*1.52,0,0)
  boxes.add(end,Vector3(.11,1.48,.23),frame)
  Geo.sphere(root,end+Vector3.UP*.78,Vector3.ONE*.18,brass)
  var p=Vector3(side*2.06,3.06,6.58)
  boxes.add(p+Vector3(0,.55,.16),Vector3(.12,.13,.47),dark)
  boxes.add(p+Vector3(0,.33,.35),Vector3(.10,.44,.10),dark)
  boxes.add(p+Vector3(0,.04,.35),Vector3(.31,.44,.30),Geo.mat("e1ca88",0,.14))
  for y in [-.20,.27]:boxes.add(p+Vector3(0,y,.35),Vector3(.36,.075,.36),dark)
 symbol(root,boxes,sign+Vector3(0,0,.235),trade,badge)
 doorway(root,boxes,frame,stone,coping)
 if trade=="star":
  for side in [-1,1]:
   var turret=Vector3(side*5.35,0,5.70)
   Geo.cylinder(root,turret+Vector3.UP*4.63,1.31,9.26,stone,false,1.10)
   for h in [.25,2.29,5.63,8.87]:Geo.cylinder(root,turret+Vector3.UP*h,1.35-h*.021,.24,coping)
   var slate=Fort.material(profile[1],false)
   Geo.cylinder(root,turret+Vector3.UP*10.04,1.35,1.56,slate,false,.70)
   Geo.cylinder(root,turret+Vector3.UP*11.23,.70,.82,slate,false,.12)
   Geo.sphere(root,turret+Vector3.UP*11.73,Vector3.ONE*.31,brass)
 elif trade=="produce":
  var p=Vector3(-5.4,0,4.7)
  boxes.add(p+Vector3.UP*5.60,Vector3(1.34,11.2,1.32),stone)
  for y in [3.02,7.72,10.78,11.23]:boxes.add(p+Vector3.UP*y,Vector3(1.60,.24,1.61),coping)
 elif trade=="cask":
  for side in [-1,1]:
   var p=Vector3(side*2.73,3.71,6.70)
   boxes.add(p,Vector3(.61,2.27,.075),enamel)
   boxes.add(p+Vector3(0,1.15,.045),Vector3(.85,.11,.11),brass)
   boxes.add(p+Vector3(0,-.98,.045),Vector3(.56,.11,.075),brass)
 boxes.build(root)

static func doorway(root:Node3D,boxes,wood:Material,stone:Material,trim:Material):
 if portal_arch==null:
  var shape=SurfaceTool.new()
  shape.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in 14:
   var a=i*PI/14.0
   var b=(i+1)*PI/14.0
   var low_a=Vector3(cos(a)*1.31,sin(a)*1.32,0)
   var low_b=Vector3(cos(b)*1.31,sin(b)*1.32,0)
   var high_a=Vector3(cos(a)*1.66,sin(a)*1.64,0)
   var high_b=Vector3(cos(b)*1.66,sin(b)*1.64,0)
   var depth=Vector3.BACK*.29
   for point in [low_a,low_b,high_b,low_a,high_b,high_a,
    high_a,high_b,high_b-depth,high_a,high_b-depth,high_a-depth,
    low_b,low_a,low_a-depth,low_b,low_a-depth,low_b-depth]:
    shape.add_vertex(point)
  shape.generate_normals()
  portal_arch=shape.commit()
 Geo.mesh(root,portal_arch,Vector3(0,3.31,6.68),wood)
 for side in [-1,1]:
  boxes.add(Vector3(side*1.53,1.90,6.55),Vector3(.32,2.89,.38),wood)
  boxes.add(Vector3(side*1.53,.38,6.56),Vector3(.62,.51,.57),stone)
  boxes.add(Vector3(side*1.53,3.28,6.60),Vector3(.57,.24,.50),trim)
 boxes.add(Vector3(0,.12,6.51),Vector3(2.52,.22,.95),stone)

static func symbol(root:Node3D,boxes,p:Vector3,trade:String,metal:Material):
 match trade:
  "blade":
   for side in [-1,1]:
    var heel=p+Vector3(side*.36,-.30,0)
    var guard=p+Vector3(side*.21,-.13,0)
    var tip=p+Vector3(-side*.29,.34,0)
    Geo.beam(root,heel,guard,.060,metal)
    Geo.beam(root,guard,tip,.073,metal)
    Geo.beam(root,guard+Vector3(-.14,side*.11,0),guard+Vector3(.14,-side*.11,0),.045,metal)
  "shield":
   Geo.sphere(root,p+Vector3.UP*.035,Vector3(.71,.62,.19),metal)
   Geo.spike(root,p+Vector3.DOWN*.02,p+Vector3.DOWN*.36,.25,metal)
   boxes.add(p+Vector3(0,.039,.11),Vector3(.11,.43,.06),Fort.material(Color("6c7e72"),false))
  "bottle":
   Geo.sphere(root,p+Vector3.DOWN*.085,Vector3(.61,.45,.21),metal)
   boxes.add(p+Vector3.UP*.18,Vector3(.20,.25,.16),metal)
   boxes.add(p+Vector3.UP*.32,Vector3(.26,.081,.16),metal)
  "star":
   Geo.sphere(root,p,Vector3(.33,.33,.18),metal)
   for i in 8:
    var a=i*TAU/8
    var ray=Vector3(cos(a),sin(a),0)
    Geo.spike(root,p+ray*.10,p+ray*(.38 if i%2==0 else .27),.073,metal)
  "hammer":
   Geo.beam(root,p+Vector3(-.28,-.28,0),p+Vector3(.21,.22,0),.079,metal)
   var head=Geo.box(root,p+Vector3(.18,.18,0),Vector3(.49,.18,.18),metal)
   head.rotation.z=-PI*.25
  "cask":
   Geo.sphere(root,p,Vector3(.68,.63,.20),metal)
   for y in [-.17,.17]:boxes.add(p+Vector3(0,y,.102),Vector3(.56,.073,.038),Fort.material(Color("6b5338"),false))
  _:
   boxes.add(p+Vector3.DOWN*.11,Vector3(.75,.26,.16),metal)
   for i in range(-1,2):
    Geo.sphere(root,p+Vector3(i*.22,.13,.021),Vector3(.21,.23,.15),metal)
