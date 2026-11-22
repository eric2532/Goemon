extends RefCounted
## Stair widths and room-space anchors are measured on the archived 3 m grid.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Sculptures=preload("res://scripts/forest/forest_beast_sculptures.gd")
const DAIS_FOOT=-4.5
const DAIS_EDGE=-7.5
const DAIS_BACK=-28.5
const DAIS_HEIGHT=1.35
const DAIS_Z=Vector2(-25.5,22.5)

static func surface_height(id:int,x:float,z:float)->float:
 if id!=1511 or z<DAIS_Z.x or z>DAIS_Z.y or x<DAIS_BACK:return 0.0
 return DAIS_HEIGHT*clampf((DAIS_FOOT-x)/(DAIS_FOOT-DAIS_EDGE),0.0,1.0)

static func build(root:Node3D,boxes,id:int):
 if id not in [1511,1520,1521]:return
 var palace=Node3D.new()
 palace.name="PalaceArchitecture"
 root.add_child(palace)
 match id:
  1511:
   var center_z=(DAIS_Z.x+DAIS_Z.y)*.5
   var width=DAIS_Z.y-DAIS_Z.x
   var stone=Fort.material(Color("d6cbb3"),false)
   boxes.add(Vector3((DAIS_BACK+DAIS_EDGE)*.5,DAIS_HEIGHT*.5-.02,center_z),Vector3(DAIS_EDGE-DAIS_BACK,DAIS_HEIGHT,width),stone)
   var slab=BoxShape3D.new()
   slab.size=Vector3(DAIS_EDGE-DAIS_BACK,DAIS_HEIGHT,width)
   support(palace,slab,Vector3((DAIS_BACK+DAIS_EDGE)*.5,DAIS_HEIGHT*.5,center_z))
   steps(palace,boxes,DAIS_FOOT,DAIS_EDGE,center_z,width,0.0,DAIS_HEIGHT,5,false)
   var ramp=ConvexPolygonShape3D.new()
   var points=PackedVector3Array()
   for z in [DAIS_Z.x,DAIS_Z.y]:
    points.append_array(PackedVector3Array([Vector3(DAIS_FOOT,0,z),Vector3(DAIS_EDGE,0,z),Vector3(DAIS_EDGE,DAIS_HEIGHT,z)]))
   ramp.points=points
   support(palace,ramp,Vector3.ZERO)
   royal_canopy(palace,boxes)
  1520:
   steps(palace,boxes,-19.5,-39.0,1.5,6.0,0.0,4.2,16,true)
   steps(palace,boxes,-31.5,-39.0,15.0,2.8,0.0,4.2,10,true)
   steps(palace,boxes,-31.5,-39.0,-12.0,2.8,0.0,4.2,10,true)
   var stone=Fort.material(Color("ded7bd"),false)
   boxes.add(Vector3(-41.25,2.1,1.5),Vector3(4.5,4.2,30.0),stone)
   boxes.add(Vector3(-40.55,4.16,1.5),Vector3(5.9,.25,30.2),Fort.material(Color("e5dac2"),false))
   rail(palace,boxes,Vector3(-43.3,4.2,-13.3),Vector3(-43.3,4.2,16.3))
   for side in [-1,1]:
    var end=1.5+side*14.85
    rail(palace,boxes,Vector3(-43.3,4.2,end),Vector3(-39.1,4.2,end))
   steps(palace,boxes,-43.5,-49.5,1.5,4.2,4.2,6.3,8,true)
  1521:
   steps(palace,boxes,97.5,91.5,3.0,8.4,0.0,1.65,6,true)

static func support(root:Node3D,shape:Shape3D,at:Vector3):
 var body=StaticBody3D.new()
 body.name="RoyalDaisSupport"
 body.collision_layer=1
 body.collision_mask=0
 body.position=at
 root.add_child(body)
 var collider=CollisionShape3D.new()
 collider.shape=shape
 body.add_child(collider)

static func steps(root:Node3D,boxes,foot:float,top:float,z:float,width:float,base:float,rise:float,count:int,rails:bool):
 var limestone=Fort.material(Color("d0c9b0"),false)
 var nosing=Fort.material(Color("ebe3ca"),false)
 var run=(top-foot)/count
 for i in count:
  var height=base+rise*(i+1)/count
  var x=foot+run*(i+.5)
  boxes.add(Vector3(x,height*.5-.02,z),Vector3(absf(run)+.012,height,width),limestone)
  boxes.add(Vector3(foot+run*i+signf(run)*.04,height-.038,z),Vector3(.08,.076,width+.04),nosing)
 if rails:
  for side in [-1,1]:
   var edge=z+side*(width*.5-.17)
   rail(root,boxes,Vector3(foot+run*.35,base+.12,edge),Vector3(top,base+rise,edge))

static func rail(root:Node3D,boxes,a:Vector3,b:Vector3):
 var stone=Fort.material(Color("e1d4b3"),false)
 var count=maxi(1,ceili(a.distance_to(b)/1.03))
 for i in range(count+1):
  var p=a.lerp(b,float(i)/count)
  var end=i==0 or i==count
  boxes.add(p+Vector3.UP*.56,Vector3(.30,1.15,.30) if end else Vector3(.115,1.12,.115),stone)
  if end:boxes.add(p+Vector3.UP*1.15,Vector3(.38,.18,.38),stone)
 Geo.beam(root,a+Vector3.UP*1.10,b+Vector3.UP*1.10,.19,stone)

static func royal_canopy(root:Node3D,boxes):
 var gold=Fort.material(Color("b68a3c"),false)
 var braid=Fort.material(Color("e0b660"),false)
 var velvet=Fort.material(Color("853e38"),false)
 var pleat=Fort.material(Color("a55543"),false)
 var back=-28.13
 var base=DAIS_HEIGHT
 for i in 26:
  var z=-10.0+i*.80
  var depth=back+(.12 if i%2==0 else .02)
  boxes.add(Vector3(depth,base+2.05,z),Vector3(.18,4.1,.81),pleat if i%2==0 else velvet)
 for side in [-1,1]:
  var z=side*9.55
  var p=Vector3(-25.6,base,z)
  boxes.add(p+Vector3.UP*2.6,Vector3(.45,5.20,.52),gold)
  boxes.add(p+Vector3.UP*.13,Vector3(.71,.26,.74),braid)
  boxes.add(p+Vector3.UP*5.1,Vector3(.70,.22,.75),braid)
  Geo.sphere(root,p+Vector3.UP*5.5,Vector3(.36,.50,.36),braid)
  for i in 6:
   boxes.add(Vector3(-26.03+(i%2)*.12,base+1.96,z-side*i*.25),Vector3(.26,3.92,.25),velvet if i%2 else pleat)
 var prev=Vector3.ZERO
 for i in 17:
  var z=-10.0+i*1.25
  var height=4.72+1.05*(1.0-pow(absf(z)/10.0,1.5))
  var p=Vector3(-25.6,base+height,z)
  boxes.add(p-Vector3.UP*.23,Vector3(2.7,.58,1.26),gold)
  if i>0:
   Geo.beam(root,prev+Vector3(.07,.10,0),p+Vector3(.07,.10,0),.14,braid)
  prev=p

static func furnishing(root:Node3D,boxes,center:Vector3,kind:String,serial:int):
 var wood=Fort.material(Color("58392c"),false)
 var gilding=Fort.material(Color("ba8b42"),false)
 var red=Fort.material(Color("873f37"),false)
 var metal=Fort.material(Color("7e7d6a"),false)
 if kind=="armor" and serial in [16193,16196]:
  var model=Geo.mesh(root,Sculptures.armor(serial),center,null)
  model.scale=Vector3.ONE*5.42/model.mesh.get_aabb().size.y
  return
 match kind:
  "royal_stool":
   boxes.add(center+Vector3.UP*.72,Vector3(1.35,.18,1.26),wood)
   boxes.add(center+Vector3.UP*.84,Vector3(1.16,.12,1.06),Fort.material(Color("ccb790"),false))
   for x in [-.48,.48]:
    for z in [-.43,.43]:boxes.add(center+Vector3(x,.34,z),Vector3(.15,.68,.15),wood)
  "armor":
   var direction=-1.0 if serial in [16193,16195] else 1.0
   boxes.add(center+Vector3.UP*.11,Vector3(1.27,.22,1.07),Fort.material(Color("928978"),false))
   for side in [-1,1]:
    boxes.add(center+Vector3(side*.24,.65,0),Vector3(.25,1.02,.39),metal)
    boxes.add(center+Vector3(side*.53,1.57,0),Vector3(.34,.61,.45),metal)
   boxes.add(center+Vector3.UP*1.44,Vector3(.87,.72,.58),metal)
   boxes.add(center+Vector3.UP*1.06,Vector3(.74,.18,.59),wood)
   Geo.sphere(root,center+Vector3.UP*2.09,Vector3(.56,.68,.57),metal)
   boxes.add(center+Vector3(.0,2.06,.285),Vector3(.37,.09,.05),wood)
   if serial!=16197:
    var grip=center+Vector3(direction*.78,.43,.20)
    var tip=center+Vector3(direction*1.10,3.44,.19)
    Geo.beam(root,grip,tip,.10,wood)
    Geo.spike(root,tip-Vector3.UP*.19,tip+Vector3.UP*.37,.12,metal)
  "brazier":
   var stone=Fort.material(Color("c9c2a9"),false)
   Geo.cylinder(root,center+Vector3.UP*.13,.57,.26,stone)
   Geo.cylinder(root,center+Vector3.UP*.62,.34,.73,stone,false,.23)
   Geo.cylinder(root,center+Vector3.UP*1.04,.26,.24,metal,false,.48)
   Geo.spike(root,center+Vector3.UP*1.13,center+Vector3(.06,1.61,0),.22,Geo.mat("eaa448",0.0,.26))
  "state_bed":
   var cream=Fort.material(Color("e6cd92"),false)
   var silk=Fort.material(Color("325765"),false)
   boxes.add(center+Vector3.UP*.57,Vector3(5.2,.78,6.2),wood)
   boxes.add(center+Vector3.UP*1.04,Vector3(5.0,.28,5.98),cream)
   boxes.add(center+Vector3(0,1.25,-2.07),Vector3(3.1,.26,1.02),red)
   for x in [-2.5,2.5]:
    for z in [-2.88,2.88]:
     boxes.add(center+Vector3(x,2.36,z),Vector3(.21,4.72,.21),gilding)
     boxes.add(center+Vector3(x*.90,2.65,z*.89),Vector3(.38,3.73,.69),silk)
     Geo.beam(root,center+Vector3(x*.90,4.15,z*.88),center+Vector3(x*.31,5.23,z*.31),.13,gilding)
     for fold in 4:
      var offset=(fold+.5)*.21
      boxes.add(center+Vector3(x*.91,2.92,z*.88-signf(z)*offset),Vector3(.23,3.1-.38*fold,.24),silk)
   Geo.cylinder(root,center+Vector3.UP*4.86,3.07,.10,gilding)
   Geo.cylinder(root,center+Vector3.UP*5.18,3.00,.59,red,false,1.19)
   Geo.cylinder(root,center+Vector3.UP*5.51,1.25,.13,gilding,false,1.05)
   Geo.sphere(root,center+Vector3.UP*5.80,Vector3(.63,.60,.63),gilding)
