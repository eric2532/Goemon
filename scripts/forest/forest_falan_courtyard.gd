extends RefCounted
## Source anchors sit on the 3 m archive grid, between the editor's 6 m cells.
const Data=preload("res://assets/maps/falan/castle_courtyard_data.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")
const Keep=preload("res://scripts/forest/forest_falan_keep_exterior.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const Ground=6.0
const FOUNTAINS=Data.FOUNTAINS
const LEGACY_KEEP=Vector2(-36,0)

static func replaces_saved_scenery(kind:String,at:Vector2)->bool:
 if kind=="falan_royal_keep":return at==LEGACY_KEEP
 if kind!="tree":return false
 return Data.TREES.any(func(row):return absf(row[0].x-at.x)<=3.01 and absf(row[0].y-at.y)<=3.01)

static func obstacles()->Array[AABB]:
 var result:Array[AABB]=[]
 for row in Data.WALLS:
  var extent=Vector3(9.02,13.5,4.6) if row[1]==10640 else Vector3(4.6,13.5,9.02)
  result.append(bounds(row[0],extent))
 for row in Data.SQUARE_TOWERS:
  result.append(bounds(row[0],Vector3(9.01,18.6,9.01)))
 for row in Data.ROUND_TOWERS:
  result.append(bounds(row[0],Vector3(8.9,22.4,8.9)))
 for row in Data.ANNEXES:
  result.append(bounds(row[0],Vector3(20.7,26.7,8.8)))
 for row in Data.HEDGES:
  result.append(bounds(row[0],Vector3(2.95,2.45,2.95)))
 for span in Keep.plinth_spans(Data.KEEP_BASE):
  result.append(bounds(span.get_center(),Vector3(span.size.x,16.0,span.size.y)))
 for row in Data.TREES:
  result.append(bounds(row[0],Vector3(1.0,6.2,1.0)))
 for at in FOUNTAINS:
  result.append(bounds(at,Vector3(5.3,1.05,5.3)))
 return result

static func bounds(at:Vector2,extent:Vector3)->AABB:
 return AABB(Vector3(at.x-extent.x*.5,Ground,at.y-extent.z*.5),extent)

static func build(root:Node3D):
 var courtyard=Node3D.new()
 courtyard.name="ArchivedCastleCourtyard"
 root.add_child(courtyard)
 var boxes=Boxes.new()
 var stone=Keep.masonry(Color("c7bea3"))
 var coping=Fort.material(Color("e0d5b6"),false)
 var quoin=Fort.material(Color("9d6344"),false)
 var slit=Fort.material(Color("414741"),false)
 var brass=Fort.material(Color("b69654"),false)
 var timber=Fort.material(Color("987044"),false)
 var dark_stone=Keep.masonry(Color("848973"))
 var hedge=Fort.material(Color("47643c"),false)
 for row in Data.WALLS:
  curtain_wall(boxes,point(row[0]),row[1]==10641,stone,dark_stone,coping,slit)
 for row in Data.SQUARE_TOWERS:
  if row[1] in [10644,10645]:
   buttress(courtyard,boxes,point(row[0]),stone,coping,dark_stone)
  else:
   var p=point(row[0])
   castle_tower(courtyard,boxes,p,8.0,17.5,stone,coping,quoin,slit,dark_stone)
   if row[1]==10647:Keep.banner(boxes,p+Vector3(4.15,12.0,0),PI*.5,brass)
 for row in Data.ROUND_TOWERS:
  Keep.open_turret(courtyard,point(row[0]),4.0,20.5,stone,coping,dark_stone)
 for row in Data.GATE_BEAMS:
  var p=point(row[0]-Vector2(3,0) if row[1]==10662 else row[0]-Vector2(3,3))
  var rotated=row[1]==10646
  part(boxes,p,rotated,Vector3(0,12.3,0),Vector3(9.4,2.6,4.25),stone)
  part(boxes,p,rotated,Vector3(0,13.58,0),Vector3(9.42,.25,4.3),dark_stone)
  for side in [-1,1]:
   for i in 6:
    part(boxes,p,rotated,Vector3((i-2.5)*1.46,13.96,side*1.87),Vector3(.82,.77,.72),coping)
   for i in 9:
    part(boxes,p,rotated,Vector3((i-4)*.91,11.12,side*1.88),Vector3(.13,1.66,.16),slit)
 for row in Data.ANNEXES:
  Keep.annex(courtyard,boxes,point(row[0]),stone,coping,dark_stone,brass)
 Keep.build(courtyard,boxes,Data.KEEP_BASE,Ground)
 var arch_mesh=load("res://scripts/forest/forest_freyja_art.gd").arch_mesh(2.4)
 for row in Data.PARAPETS:
  parapet(courtyard,boxes,point(row[0]),row[1],stone,coping,arch_mesh)
 var hedge_tops=[]
 for row in Data.HEDGES:
  var p=point(row[0])
  boxes.add(p+Vector3.UP*.20,Vector3(2.99,.40,2.99),coping)
  boxes.add(p+Vector3.UP*1.26,Vector3(2.98,1.81,2.98),hedge)
  for x in [-.73,.73]:
   for z in [-.73,.73]:
    hedge_tops.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.53,.30,.53)),p+Vector3(x,1.94,z)))
 Meadow.batch(courtyard,"leafy_shrub",hedge_tops)
 var flowers={}
 for row in Data.FLOWERS:
  var p=point(row[0])
  var serial:int=row[1]
  var asset="flowers_blue" if serial in [11641,11643] else "flowers_ivory" if serial in [10404,11647,12169,12170,12171] else "flowers_coral"
  if serial in [10039,10403,10404,16229]:
   Geo.cylinder(courtyard,p+Vector3.UP*.38,.47,.76,stone,false,.64)
   p.y+=.72
  if not flowers.has(asset):flowers[asset]=[]
  for i in 3:
   var angle=i*TAU/3.0+serial
   var offset=Vector3(cos(angle),0,sin(angle))*(.30 if p.y>Ground else .64)
   flowers[asset].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*1.1),p+offset))
 for asset in flowers:Meadow.batch(courtyard,asset,flowers[asset])
 var trees=[]
 for row in Data.TREES:
  var p=point(row[0])
  var size_:float=1.62+float(row[1]%4)*.13
  trees.append(Transform3D(Basis(Vector3.UP,row[1]*.71).scaled(Vector3.ONE*size_),p))
  Geo.torus(courtyard,p+Vector3.UP*.11,1.32,1.51,coping)
 Meadow.batch(courtyard,"broadleaf_tree",trees,true)
 for row in Data.PILLARS:
  var p=point(row[0])
  boxes.add(p+Vector3.UP*1.71,Vector3(.72,3.42,.72),quoin)
  boxes.add(p+Vector3.UP*3.45,Vector3(.94,.22,.94),coping)
 for row in Data.IRONWORK:ironwork(boxes,point(row[0]),row[1],slit)
 for row in Data.SIGNS:
  var p=point(row[0])
  for side in [-1,1]:boxes.add(p+Vector3(side*.81,1.06,0),Vector3(.13,2.12,.14),slit)
  boxes.add(p+Vector3.UP*1.41,Vector3(1.63,1.03,.23),timber)
 for row in Data.BENCHES:
  bench(boxes,point(row[0]),row[1]!=10451,2.3,timber)
 for row in Data.TABLES:
  var p=point(row[0])
  var rotated=row[1]<16574
  part(boxes,p,rotated,Vector3(0,1.01,0),Vector3(3.02,.19,2.05),timber)
  for x in [-1.20,1.20]:
   for z in [-.79,.79]:part(boxes,p,rotated,Vector3(x,.49,z),Vector3(.19,.98,.19),timber)
 for row in Data.LAMPS:lamp(courtyard,boxes,point(row[0]),row[1],stone)
 for at in FOUNTAINS:fountain(courtyard,point(at),stone,coping)
 monuments(courtyard,boxes,stone,coping,brass)
 cellar_entrance(boxes,stone,coping)
 entrance_steps(courtyard,boxes,stone,coping)
 boxes.build(courtyard)

static func point(at:Vector2)->Vector3:return Vector3(at.x,Ground,at.y)

static func part(boxes,p:Vector3,rotated:bool,offset:Vector3,extent:Vector3,material:Material):
 if rotated:
  offset=Vector3(offset.z,offset.y,offset.x)
  extent=Vector3(extent.z,extent.y,extent.x)
 boxes.add(p+offset,extent,material)

static func curtain_wall(boxes,p:Vector3,rotated:bool,stone:Material,base:Material,coping:Material,slit:Material):
 part(boxes,p,rotated,Vector3(0,6.65,0),Vector3(9.02,13.3,4.22),stone)
 part(boxes,p,rotated,Vector3(0,1.92,0),Vector3(9.02,3.84,4.6),base)
 part(boxes,p,rotated,Vector3(0,4.16,0),Vector3(9.02,.48,4.56),coping)
 part(boxes,p,rotated,Vector3(0,12.59,0),Vector3(9.02,.53,4.72),coping)
 for side in [-1,1]:
  part(boxes,p,rotated,Vector3(0,13.13,side*1.89),Vector3(9.02,.92,.63),stone)
  for i in 6:
   var x=(i-2.5)*1.36
   part(boxes,p,rotated,Vector3(x,8.28,side*2.13),Vector3(.26,4.18,.07),slit)
   part(boxes,p,rotated,Vector3(x,13.88,side*1.95),Vector3(.78,.78,.76),coping)
   part(boxes,p,rotated,Vector3(x,12.37,side*2.35),Vector3(.49,.54,.22),coping)

static func bench(boxes,p:Vector3,rotated:bool,width:float,timber:Material):
 part(boxes,p,rotated,Vector3(0,.8,0),Vector3(width,.19,.83),timber)
 for x in [-width*.37,width*.37]:
  for z in [-.28,.28]:part(boxes,p,rotated,Vector3(x,.41,z),Vector3(.15,.82,.14),timber)
 for y in [1.02,1.30,1.57]:
  part(boxes,p,rotated,Vector3(0,y,.38),Vector3(width-.07,.13,.14),timber)

static func tower(boxes,p:Vector3,width:float,height:float,stone:Material,coping:Material,quoin:Material,slit:Material):
 var edge=width*.5
 boxes.add(p+Vector3.UP*height*.5,Vector3(width,height,width),stone)
 boxes.add(p+Vector3.UP*.67,Vector3(width+.11,1.34,width+.11),stone)
 boxes.add(p+Vector3.UP*(height-.06),Vector3(width+.26,.52,width+.26),coping)
 for rotated in [false,true]:
  for side in [-1,1]:
   for shift in [-.25,0,.25]:
    part(boxes,p,rotated,Vector3(width*shift,height*.70,side*(edge+.015)),Vector3(.22,1.68,.065),slit)
   for mark in range(-2,3):
    part(boxes,p,rotated,Vector3(mark*width*.211,height+.52,side*(edge-.32)),Vector3(.75,.83,.70),coping)
   for level in int(height/1.19):
    var inset=.44 if level%2==0 else .70
    for corner in [-1,1]:
     part(boxes,p,rotated,Vector3(corner*(edge-inset*.5),.95+level*1.19,side*(edge+.022)),Vector3(inset,.42,.09),quoin)

static func castle_tower(root:Node3D,boxes,p:Vector3,width:float,height:float,stone:Material,coping:Material,quoin:Material,slit:Material,base:Material,source_merlon:Mesh=null):
 var edge=width*.5
 boxes.add(p+Vector3.UP*(height*.5-.36),Vector3(width,height-.72,width),stone)
 if source_merlon==null:boxes.add(p+Vector3.UP*1.67,Vector3(width+.41,3.34,width+.41),base)
 if source_merlon==null:
  boxes.add(p+Vector3.UP*(height-.06),Vector3(width+.26,.52,width+.26),coping)
  boxes.add(p+Vector3.UP*(height+.22),Vector3(width-.17,.16,width-.17),base)
 else:
  for rotated in [false,true]:
   for side in [-1,1]:part(boxes,p,rotated,Vector3(0,height-.25,side*(edge-.13)),Vector3(width+.26,1.0,.52),coping)
  Geo.box(root,p+Vector3.UP*(height-.40),Vector3(width-.17,.16,width-.17),base).set_meta("falan_fort_paving_top",true)
 if source_merlon==null:
  for i in 4:
   var angle=i*PI*.5
   Keep.lancet(root,p+Vector3(sin(angle)*edge,11.9,cos(angle)*edge),angle,1.52,3.23,coping)
 for rotated in [false,true]:
  for side in [-1,1]:
   if source_merlon==null:
    for shift in [-.25,0,.25]:part(boxes,p,rotated,Vector3(width*shift,height*.48,side*(edge+.015)),Vector3(.22,2.71,.065),slit)
   part(boxes,p,rotated,Vector3(0,height+.43,side*(edge-.32)),Vector3(width,.62,.58),stone)
   if source_merlon==null:
    for mark in range(-2,3):part(boxes,p,rotated,Vector3(mark*width*.211,height+.96,side*(edge-.32)),Vector3(.75,.76,.70),coping)
   for level in int(height/1.19):
    var inset=(.95 if level%2==0 else 1.35) if source_merlon!=null else (.44 if level%2==0 else .70)
    for corner in [-1,1]:
     part(boxes,p,rotated,Vector3(corner*(edge-inset*.5),.95+level*1.19,side*(edge+.022)),Vector3(inset,.60 if source_merlon!=null else .42,.09),quoin)
 if source_merlon!=null:
  for x in [-3,-1,1,3]:
   for z in [-3,-1,1,3]:
    if abs(x)!=3 and abs(z)!=3:continue
    var block=Geo.mesh(root,source_merlon,p+Vector3(x*(edge-.32)/3,height+.96,z*(edge-.32)/3),coping)
    block.scale.y=1.4
    block.set_meta("falan_crown_block",true)

static func buttress(root:Node3D,boxes,p:Vector3,stone:Material,coping:Material,base:Material):
 for row in [[1.9,5.9,3.8,4.95],[7.36,4.95,7.2,2.4]]:
  var taper=Geo.cylinder(root,p+Vector3.UP*row[0],row[1],row[2],base if row[0]<2.0 else stone,false,row[3])
  taper.mesh.radial_segments=4
  taper.rotation.y=PI*.25
 boxes.add(p+Vector3.UP*11.34,Vector3(3.55,1.10,3.55),stone)
 for x in [-1.41,1.41]:
  for z in [-1.41,1.41]:boxes.add(p+Vector3(x,12.12,z),Vector3(.65,.68,.65),coping)

static func ironwork(boxes,p:Vector3,serial:int,iron:Material):
 var rotated=serial in [10675,10684]
 for i in 5:
  part(boxes,p,rotated,Vector3((i-2)*.56,1.38,0),Vector3(.09,2.76,.09),iron)
  part(boxes,p,rotated,Vector3((i-2)*.56,2.80,0),Vector3(.19,.15,.19),iron)
 for y in [.54,1.94]:part(boxes,p,rotated,Vector3(0,y,0),Vector3(2.85,.12,.12),iron)

static func parapet(root:Node3D,boxes,p:Vector3,serial:int,stone:Material,coping:Material,arch:Mesh):
 var span=serial in [10624,10625,10629,10630]
 var rotated=serial in [10623,10624,10628,10630]
 var length_=12.0 if span else 3.04
 if serial in [10624,10625]:
  var arch_node=Geo.mesh(root,arch,p-Vector3.UP*5.25,stone)
  arch_node.rotation.y=0 if rotated else PI*.5
 else:
  part(boxes,p,rotated,Vector3(0,-2.55,0),Vector3(length_,5.1,2.4),stone)
 part(boxes,p,rotated,Vector3(0,.35,0),Vector3(length_,.86,2.52),stone)
 for i in (6 if span else 1):
  var x=(i-2.5)*2.0 if span else 0.0
  part(boxes,p,rotated,Vector3(x,1.04,0),Vector3(1.35,.66,2.16),coping)
 if serial in [10620,10621,10626]:
  boxes.add(p+Vector3.UP*1.6,Vector3(2.05,.54,2.05),coping)
  boxes.add(p+Vector3.UP*2.06,Vector3(1.42,.49,1.42),stone)
  boxes.add(p+Vector3.UP*2.48,Vector3(.77,.42,.77),coping)

static func fountain(root:Node3D,p:Vector3,stone:Material,coping:Material):
 var water=Geo.mat("6aa4bd",.15)
 Geo.cylinder(root,p+Vector3.UP*.27,2.65,.54,stone)
 Geo.cylinder(root,p+Vector3.UP*.52,2.49,.065,water)
 Geo.torus(root,p+Vector3.UP*.61,2.30,2.65,coping)
 Geo.cylinder(root,p+Vector3.UP*.83,.54,.62,stone,false,.39)
 Geo.cylinder(root,p+Vector3.UP*1.12,.34,.22,coping,false,.58)
 Geo.torus(root,p+Vector3.UP*1.26,.30,.59,water)
 Geo.spike(root,p+Vector3.UP*1.19,p+Vector3.UP*2.01,.13,water)

static func lamp(root:Node3D,boxes,p:Vector3,serial:int,stone:Material):
 var iron=Fort.material(Color("595e51"),false)
 var glass=Geo.mat("c2d7d2",0,.12)
 var single=serial in [17083,10612]
 var height=4.1 if single else 5.65
 boxes.add(p+Vector3.UP*.18,Vector3(.96,.36,.96),stone)
 boxes.add(p+Vector3.UP*.53,Vector3(.64,.55,.64),iron)
 Geo.cylinder(root,p+Vector3.UP*(height*.5+.40),.11,height-.42,iron,false,.072)
 if single:
  Geo.sphere(root,p+Vector3.UP*height,Vector3(.39,.37,.39),glass)
  return
 for side in [-1,1]:
  var tip=p+Vector3(side*.69,height-.23,0)
  Geo.beam(root,p+Vector3.UP*(height-.55),tip,.11,iron)
  Geo.sphere(root,tip-Vector3.UP*.25,Vector3(.36,.47,.36),glass)
  boxes.add(tip-Vector3.UP*.10,Vector3(.39,.13,.39),iron)

static func monuments(root:Node3D,boxes,stone:Material,coping:Material,brass:Material):
 var arch:Array[Vector3]=[]
 for row in Data.MONUMENTS:
  var p=point(row[0])
  if row[1] in [10045,10046]:
   boxes.add(p+Vector3.UP*.38,Vector3(2.7,.76,2.7),stone)
   Geo.cylinder(root,p+Vector3.UP*2.05,1.22,3.16,stone,false,.78)
   boxes.add(p+Vector3.UP*3.61,Vector3(1.86,.33,1.86),coping)
   Geo.cylinder(root,p+Vector3.UP*4.88,.62,2.35,stone,false,.47)
   arch.append(p+Vector3.UP*6.0)
  else:Statues.build(root,boxes,p,row[1])
 if arch.size()!=2:return
 var last=arch[0]
 for i in range(1,17):
  var t=float(i)/16.0
  var next=arch[0].lerp(arch[1],t)+Vector3.UP*(sin(t*PI)*2.6)
  Geo.beam(root,last,next,.46,coping)
  last=next

static func entrance_steps(root:Node3D,boxes,stone:Material,coping:Material):
 var carpet=Fort.material(Color("913e32"),false)
 var foot=Vector3(-17.4,Ground,Keep.ENTRY_Z)
 var upper=Vector3(-25.9,Ground+2.65,Keep.ENTRY_Z)
 for i in 10:
  var tread=foot.lerp(upper,(i+.5)/10.0)
  var height=(i+1)*.265
  boxes.add(Vector3(tread.x,Ground+height*.5-.02,Keep.ENTRY_Z),Vector3(.855,height,6.8),stone)
  boxes.add(Vector3(tread.x,Ground+height-.025,Keep.ENTRY_Z),Vector3(.85,.09,3.36),carpet)
  boxes.add(Vector3(tread.x+.37,Ground+height-.04,Keep.ENTRY_Z),Vector3(.10,.075,6.84),coping)
 for side in [-1,1]:
  var offset=Vector3(0,0,side*3.31)
  Palace.rail(root,boxes,foot+offset,upper+offset)
 var ramp=ConvexPolygonShape3D.new()
 var points=PackedVector3Array()
 for z in [-3.4,3.4]:
  var offset=Vector3(0,0,z)
  points.append_array(PackedVector3Array([foot+offset,upper+offset,Vector3(upper.x,Ground,z)]))
 ramp.points=points
 Palace.support(root,ramp,Vector3.ZERO)

static func cellar_entrance(boxes,stone:Material,coping:Material):
 var p=point(Vector2(87,-18))
 boxes.add(p+Vector3.UP*.041,Vector3(3.04,.08,2.51),Fort.material(Color("554d40"),false))
 for side in [-1,1]:
  boxes.add(p+Vector3(0,.13,side*1.40),Vector3(3.51,.23,.29),coping)
 for i in 5:
  boxes.add(p+Vector3((i-2)*.58,.09+i*.026,0),Vector3(.29,.035,2.45),stone)
