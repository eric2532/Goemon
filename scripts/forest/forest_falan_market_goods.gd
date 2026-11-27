extends RefCounted
## The city's small stalls and delivery goods share painted wood, copper and cloth.
const Data=preload("res://assets/maps/falan/city_street_data.gd")
const Streets=preload("res://scripts/forest/forest_falan_streets.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Details=preload("res://scripts/forest/forest_falan_street_details.gd")
const DISPLAYS=[10053,10056,10057,10536,10540,10541]
const CARTS=[10043,10044]
const BOARDS=[10413,10415,10416,10417,10419,11496,11497]

static func build(parent:Node3D,model,links:Array,npcs:Array):
 var root=Node3D.new()
 root.name="ArchivedFalanMarketGoods"
 root.set_meta("obstacles",model.scenery_obstacles.duplicate())
 root.set_meta("links",links)
 parent.add_child(root)
 var boxes=Boxes.new()
 var protected:Array[Vector2]=[]
 for link in links:protected.append(link.at)
 for npc in npcs:protected.append(npc[0])
 var mask:Image=model.terrain.mask_texture().get_image()
 var origin:Vector2=model.terrain.mask_bounds().position+Vector2.ONE*1.5
 var occupied:Array[Rect2]=[]
 var flowers=[]
 var wood=Fort.material(Color("87613f"),false)
 var cut=Fort.material(Color("bb945d"),false)
 var iron=Geo.mat("495751",.36)
 for feature in [DISPLAYS,CARTS,BOARDS,[]]:
  for row in Data.MARKET_GOODS:
   var serial:int=row[1]
   if feature.is_empty():
    if serial in DISPLAYS or serial in CARTS or serial in BOARDS:continue
   elif serial not in feature:continue
   var size_=footprint(serial)
   var p=Streets.ground(model,row[0])
   var radius=size_.length()*.5
   var bounds=Rect2(row[0]-size_*.5,size_)
   if not fits(model,p,radius,bounds,protected,occupied):
    if serial not in DISPLAYS and serial not in CARTS:continue
    # Small shifts keep the display in its original plot when the shell is wider.
    var nearby=false
    for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,
     Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
     var at:Vector2=row[0]+direction*2.25
     var pixel=Vector2i(((at-origin)/3.0).round())
     if not Rect2i(Vector2i.ZERO,mask.get_size()).has_point(pixel) or mask.get_pixelv(pixel).b>.32:continue
     p=Streets.ground(model,at)
     bounds.position=at-size_*.5
     if fits(model,p,radius,bounds,protected,occupied):
      nearby=true
      break
    if not nearby:continue
   occupied.append(bounds)
   var prop=Node3D.new()
   prop.name="MarketGood_%d_%d_%d"%[serial,roundi(p.x),roundi(p.z)]
   prop.set_meta("source_anchor",row[0])
   root.add_child(prop)
   if serial in CARTS:
    flower_cart(prop,boxes,p,serial==10043,wood,cut,iron,flowers)
   elif serial in BOARDS:
    Details.place(prop,serial,p)
   elif serial==10541:
    wares(prop,boxes,p,wood,cut)
   elif serial in [10053,10056,10057,10536]:
    produce(prop,boxes,p,serial,wood,cut)
   elif serial in [10055,11017,11018,11019,11020]:
    crate(prop,boxes,p,1.2 if serial in [11017,11018] else .9,serial!=10055,wood,cut)
   else:
    var cask=Geo.mat("98603c" if serial%3 else "716646")
    barrel(prop,p,.50 if serial==10553 else .68,cask,cut,iron,serial in [10021,10022])
    if serial in [10032,10033,10034]:
     barrel(prop,p+Vector3(.88,0,.55),.58,cask,cut,iron)
     if serial!=10032:barrel(prop,p+Vector3(-.76,0,.54),.58,Geo.mat("876247"),cut,iron)
     if serial==10034:barrel(prop,p+Vector3(0,1.16,.26),.54,cask,cut,iron)
    if serial==10540:fruit(prop,p+Vector3.UP*1.28,4,0,.62)
   var height=.80 if serial in CARTS else (2.4 if serial in BOARDS else 1.22)
   Art.solid(prop,p+Vector3.UP*height*.5,Vector3(size_.x,height,size_.y),1,"wood",true)
 Assets.batch(root,"flowers_coral",flowers)
 pickets(root,boxes,model,protected,occupied,wood,cut)
 boxes.build(root)

static func fits(model,p:Vector3,radius:float,bounds:Rect2,protected:Array[Vector2],occupied:Array[Rect2])->bool:
 if not Streets.fits(model,p,radius,protected):return false
 return not occupied.any(func(box):return box.intersects(bounds))

static func footprint(serial:int)->Vector2:
 if serial in [10053,10056,10057]:return Vector2(3.25,2.65)
 if serial==10541:return Vector2(1.0,2.45)
 if serial in [10032,10033,10034]:return Vector2(2.85,1.96)
 if serial==10043:return Vector2(1.7,.95)
 if serial==10044:return Vector2(.95,1.7)
 if serial in BOARDS:return Vector2(.52,.52)
 return Vector2(1.40,1.40)

static func produce(root:Node3D,boxes,p:Vector3,serial:int,wood:Material,cut:Material):
 var turned=serial==10056 or (serial==10057 and p.x>-150)
 var groups=1 if serial==10536 else 4
 for i in groups:
  var x=0.0 if groups==1 else (-.75 if i%2==0 else .75)
  var z=0.0 if groups==1 else (-.60 if i<2 else .60)
  var at=p+(Vector3(z,0,x) if turned else Vector3(x,0,z))
  var y=.97 if i<2 else .72
  Court.part(boxes,at,turned,Vector3.UP*(y-.17),Vector3(1.41,.26,1.13),wood)
  for a in [-.70,.70]:
   Court.part(boxes,at,turned,Vector3(a,y+.04,0),Vector3(.093,.22,1.19),cut)
   Court.part(boxes,at,turned,Vector3(a,y*.32,.40),Vector3(.14,y*.64,.14),wood)
   Court.part(boxes,at,turned,Vector3(a,y*.32,-.40),Vector3(.14,y*.64,.14),wood)
  for b in [-.55,.55]:Court.part(boxes,at,turned,Vector3(0,y+.04,b),Vector3(1.41,.22,.10),cut)
  fruit(root,at+Vector3.UP*y,5,(i+(2 if serial==10057 else 0))%5,.90)

static func fruit(root:Node3D,p:Vector3,count:int,kind:int,spread:float):
 var colors=["e79235","7c9e48","a84032","643e71","d7b17c"]
 for i in count:
  var angle=i*2.399963
  var radius=sqrt(float(i)/count)*spread*.57
  var pos=p+Vector3(cos(angle)*radius,.085,sin(angle)*radius*.68)
  var size_=.27+float((i+kind)%3)*.044
  Geo.sphere(root,pos,Vector3(size_,size_*(1.42 if kind==0 else .88),size_),Geo.mat(colors[kind]))
  if kind in [0,2]:Geo.sphere(root,pos+Vector3.UP*.14,Vector3(.10,.055,.13),Geo.mat("547045"))

static func barrel(root:Node3D,p:Vector3,r:float,wood:Material,cut:Material,iron:Material,sideways:bool=false):
 var holder=Node3D.new()
 holder.position=p+Vector3.UP*(r if sideways else 0.0)
 if sideways:holder.rotation.z=PI*.5
 root.add_child(holder)
 Geo.cylinder(holder,Vector3.UP*r*.47,r*.85,r*.94,wood,false,r)
 Geo.cylinder(holder,Vector3.UP*r*1.42,r,r*.96,wood,false,r*.86)
 Geo.cylinder(holder,Vector3.UP*r*1.89,r*.80,.045,cut)
 for level in [.22,.53,1.39,1.67]:
  Geo.cylinder(holder,Vector3.UP*r*level,r*(.91 if level in [.22,1.67] else .98),.076,iron)
 for offset in [-.31,0,.31]:
  Geo.box(holder,Vector3(0,r*1.931,offset*r),Vector3(r*1.32,.017,.024),wood)

static func crate(root:Node3D,boxes,p:Vector3,w:float,closed:bool,wood:Material,cut:Material):
 boxes.add(p+Vector3.UP*.10,Vector3(w,.20,w),wood)
 if closed:boxes.add(p+Vector3.UP*(w*.47),Vector3(w*.96,w*.86,w*.96),wood)
 for side in [-1,1]:
  for height in [.21,.45,.69]:
   boxes.add(p+Vector3(0,w*height,side*w*.49),Vector3(w,.19,.086),cut)
   boxes.add(p+Vector3(side*w*.49,w*height,0),Vector3(.086,.19,w),cut)
  for edge in [-1,1]:
   boxes.add(p+Vector3(side*w*.46,w*.42,edge*w*.46),Vector3(.12,w*.84,.12),wood)
 if closed:
  for i in 4:boxes.add(p+Vector3((i-1.5)*w*.24,w*.92,0),Vector3(w*.225,.10,w),cut)
  for side in [-1,1]:
   Geo.beam(root,p+Vector3(-w*.38,w*.19,side*w*.515),p+Vector3(w*.38,w*.74,side*w*.515),.054,wood)
   Geo.beam(root,p+Vector3(side*w*.515,w*.19,-w*.38),p+Vector3(side*w*.515,w*.74,w*.38),.054,wood)

static func pickets(root:Node3D,boxes,model,protected:Array[Vector2],occupied:Array[Rect2],wood:Material,trim:Material):
 var directions=[Vector3.LEFT,Vector3.RIGHT,Vector3.BACK,Vector3.FORWARD]
 for row in Data.MARKET_PICKETS:
  var p=Streets.ground(model,row[0])
  for i in 4:
   if (int(row[2]) & (1<<i))==0:continue
   var axis:Vector3=directions[i]
   var at=p+axis*.75
   var rotated=i>=2
   var bounds=Vector2(.18,1.5) if rotated else Vector2(1.5,.18)
   if not fits(model,at,.40,Rect2(Vector2(at.x,at.z)-bounds*.5,bounds),protected,occupied):continue
   for y in [.40,.87]:
    Court.part(boxes,at,rotated,Vector3.UP*y,Vector3(1.52,.13,.12),wood)
   for step in [.18,.65,1.13]:
    var post=p+axis*step
    boxes.add(post+Vector3.UP*.61,Vector3(.20,1.22,.20),wood)
    boxes.add(post+Vector3.UP*1.23,Vector3(.21,.14,.21),trim)
   Art.solid(root,at+Vector3.UP*.61,Vector3(bounds.x,1.22,bounds.y),1,"wood",true)

static func flower_cart(root:Node3D,boxes,p:Vector3,turned:bool,wood:Material,cut:Material,iron:Material,flowers:Array):
 var axis=Vector3.RIGHT if turned else Vector3.BACK
 var across=Vector3.BACK if turned else Vector3.RIGHT
 Court.part(boxes,p,turned,Vector3(0,.76,0),Vector3(.87,.22,1.30),wood)
 for side in [-1,1]:
  Court.part(boxes,p,turned,Vector3(side*.42,.97,0),Vector3(.10,.27,1.27),cut)
  Geo.beam(root,p+across*side*.32+Vector3.UP*.75,p+axis*1.02+across*side*.29+Vector3.UP*.92,.065,wood)
  Geo.beam(root,p+across*side*.27+Vector3.UP*.73,p+axis*.32+across*side*.26+Vector3.UP*.06,.066,iron)
 var wheel=p-axis*.61+Vector3.UP*.38
 var rim=Geo.torus(root,wheel,.29,.36,iron)
 rim.quaternion=Quaternion(Vector3.UP,across)
 for i in 6:
  var angle=i*TAU/6
  Geo.beam(root,wheel,wheel+axis*cos(angle)*.31+Vector3.UP*sin(angle)*.31,.035,cut)
 for i in range(-1,2):
  flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.75),p+axis*i*.33+Vector3.UP*.87))

static func wares(root:Node3D,boxes,p:Vector3,wood:Material,cut:Material):
 boxes.add(p+Vector3.UP*1.02,Vector3(.91,.19,2.41),cut)
 for x in [-.38,.38]:
  for z in [-1.02,1.02]:boxes.add(p+Vector3(x,.48,z),Vector3(.13,.96,.13),wood)
 for i in 5:
  var at=p+Vector3(.14 if i%2 else -.11,1.12,(i-2)*.40)
  var glaze=Geo.mat(["446b61","b37049","ad9e71","547a8b","84543e"][i])
  Geo.cylinder(root,at+Vector3.UP*.16,.13,.32,glaze,false,.175)
  Geo.cylinder(root,at+Vector3.UP*.37,.16,.17,glaze,false,.076)
  Geo.cylinder(root,at+Vector3.UP*.49,.075,.10,glaze)

static func signpost(boxes,p:Vector3,serial:int,wood:Material,cut:Material,iron:Material):
 var turned=serial in [10416,11496]
 Court.part(boxes,p,turned,Vector3.UP*1.19,Vector3(.19,2.38,.19),wood)
 Court.part(boxes,p,turned,Vector3(.38,2.23,0),Vector3(.98,.11,.13),iron)
 Court.part(boxes,p,turned,Vector3(.40,1.88,0),Vector3(.88,.54,.13),cut)
 for side in [-1,1]:
  Court.part(boxes,p,turned,Vector3(.40,1.88,side*.083),Vector3(.57,.29,.045),wood)
  Court.part(boxes,p,turned,Vector3(.40,1.88,side*.116),Vector3(.35,.061,.03),cut)
