extends RefCounted
## Shared native asset kit: the editor, validation and gameplay use one catalog.
const CATALOG={
 "grass":{"name":"Grass tile","group":"Ground","size":Vector2(8,8)},
 "sand":{"name":"Sand tile","group":"Ground","size":Vector2(8,8)},
 "stone_tile":{"name":"Stone paving","group":"Ground","size":Vector2(8,8)},
 "road":{"name":"Road tile","group":"Ground","size":Vector2(12,12)},
 "wall":{"name":"Stone wall","group":"Structures","size":Vector2(8,2)},
 "fence":{"name":"Wooden fence","group":"Structures","size":Vector2(8,1)},
 "torii":{"name":"Torii gate","group":"Structures","size":Vector2(14,3)},
 "pavilion":{"name":"Garden pavilion","group":"Structures","size":Vector2(10,10)},
 "lantern":{"name":"Stone lantern","group":"Structures","size":Vector2(2,2)},
 "crates":{"name":"Supply crates","group":"Structures","size":Vector2(4,3)},
 "banner":{"name":"Jade banner","group":"Structures","size":Vector2(2,2)},
 "bamboo":{"name":"Bamboo grove","group":"Nature","size":Vector2(4,4)},
 "cherry":{"name":"Cherry blossom","group":"Nature","size":Vector2(9,9)},
 "cedar":{"name":"Cedar tree","group":"Nature","size":Vector2(7,7)},
 "rock":{"name":"Mossy boulder","group":"Nature","size":Vector2(4,3)},
 "spawn":{"name":"Hero spawn","group":"Gameplay","size":Vector2(3,3)},
 "enemy":{"name":"Enemy entrance","group":"Gameplay","size":Vector2(5,5)},
 "base":{"name":"Defend this shrine","group":"Gameplay","size":Vector2(7,7)},
 "waypoint":{"name":"Route waypoint","group":"Gameplay","size":Vector2(3,3)},
 "tower":{"name":"Arrow tower site","group":"Gameplay","size":Vector2(3,3)},
 "mine":{"name":"Gold mine site","group":"Gameplay","size":Vector2(5,5)}
}
const SINGLETONS=["spawn","enemy","base"]
static func collision_boxes(kind: String)->Array:
 match kind:
  "wall":return [[Vector3(0,1.5,0),Vector3(8,3,2)]]
  "fence":return [[Vector3(0,.9,0),Vector3(8,1.8,.55)]]
  "torii":return [[Vector3(-5,3,0),Vector3(.9,6,.9)],[Vector3(5,3,0),Vector3(.9,6,.9)]]
  "pavilion":return [[Vector3(-3.5,2.6,-3.5),Vector3(.6,5.2,.6)],[Vector3(3.5,2.6,-3.5),Vector3(.6,5.2,.6)],[Vector3(-3.5,2.6,3.5),Vector3(.6,5.2,.6)],[Vector3(3.5,2.6,3.5),Vector3(.6,5.2,.6)],[Vector3(0,6.1,0),Vector3(10,1.6,10)]]
  "lantern":return [[Vector3(0,1.5,0),Vector3(1.4,3,1.4)]]
  "crates":return [[Vector3(0,1.2,0),Vector3(4,2.4,3)]]
  "rock":return [[Vector3(0,1,0),Vector3(4,2,3)]]
  "cherry","cedar":return [[Vector3(0,3,0),Vector3(.8,6,.8)]]
  "tower":return [[Vector3(0,1.5,0),Vector3(2.8,3,2.8)]]
  "mine":return [[Vector3(0,1.5,0),Vector3(4.6,3,4.7)]]
 return []

static func build(parent: Node3D,kind: String,collisions: bool=true)->Node3D:
 var n=Node3D.new();n.name="Piece_"+kind;parent.add_child(n)
 var stone=Geo.mat("788c85");var dark=Geo.mat("314c4c");var wood=Geo.mat("65503b")
 var red=Geo.mat("b95142");var gold=Geo.mat("ddbe79",.25);var green=Geo.mat("507f58")
 match kind:
  "grass","sand","stone_tile","road":
   var colors={"grass":"65834e","sand":"ad9e76","stone_tile":"85948c","road":"c1b084"}
   var side=12.0 if kind=="road" else 8.0
   Geo.box(n,Vector3(0,.015,0),Vector3(side,.025,side),Geo.mat(colors[kind]))
   if kind=="stone_tile":
    for x in [-2.0,2.0]:Geo.box(n,Vector3(x,.031,0),Vector3(.07,.012,8),dark)
    Geo.box(n,Vector3(0,.031,0),Vector3(8,.012,.07),dark)
  "wall":
   Geo.box(n,Vector3(0,1.5,0),Vector3(8,3,2),stone)
   for row in range(3):
    for col in range(4):
     Geo.box(n,Vector3(-3+col*2, .5+row, -1.02),Vector3(1.92,.88,.04),Geo.mat("97a598" if (row+col)%2==0 else "657c73"))
   Geo.box(n,Vector3(0,3.15,0),Vector3(8.5,.3,2.5),dark)
   Geo.box(n,Vector3(0,3.32,0),Vector3(8.5,.06,2.5),gold)
  "fence":
   for x in [-3.7,0,3.7]:
    Geo.box(n,Vector3(x,.95,0),Vector3(.38,1.9,.5),wood)
    Geo.box(n,Vector3(x,1.92,0),Vector3(.6,.12,.65),gold)
   for y in [.6,1.35]:Geo.box(n,Vector3(0,y,0),Vector3(8,.26,.28),wood)
  "torii":
   for x in [-5.0,5.0]:
    Geo.cylinder(n,Vector3(x,3,0),.44,6,red)
    Geo.cylinder(n,Vector3(x,.18,0),.68,.36,dark)
   Geo.box(n,Vector3(0,4.7,0),Vector3(11.4,.45,.55),red)
   Geo.box(n,Vector3(0,6.1,0),Vector3(13.6,.6,1.3),dark)
   Geo.box(n,Vector3(0,5.72,0),Vector3(12.8,.22,1),red)
   for side in [-1,1]:
    var tip=Geo.box(n,Vector3(side*6.35,6.3,0),Vector3(2,.35,1.3),dark);tip.rotation.z=side*.13
   Geo.box(n,Vector3(0,5.15,-.45),Vector3(.9,1.3,.15),gold)
  "pavilion":
   Geo.box(n,Vector3(0,.06,0),Vector3(8,.12,8),wood)
   for x in [-3.5,3.5]:
    for z in [-3.5,3.5]:
     Geo.cylinder(n,Vector3(x,2.6,z),.3,5.2,red)
     Geo.box(n,Vector3(x,.3,z),Vector3(.8,.6,.8),stone)
   Geo.box(n,Vector3(0,5.2,0),Vector3(8,.35,8),red)
   var roof=Geo.cylinder(n,Vector3(0,6.1,0),7.05,1.6,dark,false,.5);roof.mesh.radial_segments=4;roof.rotation.y=PI/4
   for side in [-1,1]:Geo.box(n,Vector3(side*4.4,5.42,0),Vector3(.22,.18,9.6),gold)
   Geo.cylinder(n,Vector3(0,7.05,0),.25,.55,gold)
  "lantern":
   Geo.box(n,Vector3(0,.18,0),Vector3(1.6,.36,1.6),stone)
   Geo.cylinder(n,Vector3(0,1.2,0),.27,1.8,stone)
   Geo.box(n,Vector3(0,2.3,0),Vector3(1.25,.8,1.25),dark)
   for x in [-.64,.64]:Geo.box(n,Vector3(x,2.3,0),Vector3(.035,.5,.6),Geo.mat("ffd999",0,.7))
   for z in [-.64,.64]:Geo.box(n,Vector3(0,2.3,z),Vector3(.6,.5,.035),Geo.mat("ffd999",0,.7))
   var cap=Geo.cylinder(n,Vector3(0,2.95,0),1.3,.6,stone,false,.15);cap.mesh.radial_segments=4;cap.rotation.y=PI/4
  "crates":
   for p in [Vector3(-1,.8,0),Vector3(1,.8,0),Vector3(0,2,0)]:
    Geo.box(n,p,Vector3(1.8,1.5,2.6),wood)
    for x in [-.6,.6]:Geo.box(n,p+Vector3(x,0,-1.31),Vector3(.16,1.4,.05),gold)
    Geo.box(n,p+Vector3(0,0,-1.35),Vector3(1.7,.16,.04),dark)
  "banner":
   Geo.cylinder(n,Vector3(0,2.4,0),.09,4.8,wood)
   Geo.box(n,Vector3(.8,3.3,0),Vector3(1.6,2.3,.05),Geo.mat("48a595"))
   Geo.box(n,Vector3(.8,3.3,-.04),Vector3(.18,1.7,.03),gold)
   Geo.cylinder(n,Vector3(0,.12,0),.6,.24,stone)
  "bamboo":
   for i in range(7):
    var x=sin(i*2.4)*1.4;var z=cos(i*2.4)*1.4;var height=4.8+(i%3)*.8
    Geo.cylinder(n,Vector3(x,height*.5,z),.12,height,green)
    for y in range(1,5):Geo.cylinder(n,Vector3(x,y,z),.14,.055,gold)
    for j in range(2):
     var leaf=Geo.sphere(n,Vector3(x+.5,height-1+j*.6,z),Vector3(1.8,.2,.65),green);leaf.rotation.z=.4+j*.5
  "cherry","cedar":
   Geo.cylinder(n,Vector3(0,3,0),.4,6,wood,false,.25)
   if kind=="cherry":
    for i in range(5):
     var p=Vector3(sin(i*2.4)*2,6.4+(i%2),cos(i*2.4)*2)
     Geo.beam(n,Vector3(0,3.8,0),p,.18,wood)
     Geo.sphere(n,p,Vector3(5.3,3.4,4.8),Geo.mat("eab1b4" if i%2==0 else "cf829e"))
    for i in range(7):Geo.sphere(n,Vector3(sin(i*1.8)*3,.07,cos(i*1.8)*3),Vector3(.28,.07,.18),Geo.mat("eab1b4"))
   else:
    for i in range(3):Geo.cylinder(n,Vector3(0,4.5+i*1.6,0),3.5-i*.8,4,Geo.mat("355f4a" if i%2==0 else "467457"),false,0)
  "rock":
   var b=Geo.sphere(n,Vector3(0,.9,0),Vector3(4,2.5,3),stone);b.rotation.z=.17
   Geo.sphere(n,Vector3(-.4,1.9,.1),Vector3(2.8,.4,2),Geo.mat("78935f"))
  "base":
   Geo.cylinder(n,Vector3(0,.06,0),4,.12,stone)
   Geo.torus(n,Vector3(0,.15,0),3.4,3.6,gold)
   Geo.cylinder(n,Vector3(0,2,0),.6,4,Geo.mat("ffe1a0",.2,.7),false,.15)
   Geo.sphere(n,Vector3(0,4.8,0),Vector3(1.5,1.5,1.5),Geo.mat("fff0c2",.1,1))
  "spawn","enemy","waypoint","tower","mine":
   var colors={"spawn":"69d9ce","enemy":"ef9179","waypoint":"9be2a4","tower":"e5ca85","mine":"f7cb63"}
   var radius=2.3 if kind=="mine" else (2.5 if kind=="enemy" else 1.5)
   Geo.cylinder(n,Vector3(0,.05,0),radius,.1,dark)
   Geo.torus(n,Vector3(0,.12,0),radius*.8,radius,Geo.mat(colors[kind],.2,.3))
   if kind in ["enemy","waypoint","spawn"]:
    var arrow=Geo.box(n,Vector3(0,.14,0),Vector3(.2,.04,1.8),Geo.mat(colors[kind]));arrow.rotation.y=.7
    arrow=Geo.box(n,Vector3(.6,.14,0),Vector3(.2,.04,1.8),Geo.mat(colors[kind]));arrow.rotation.y=-.7
 if collisions and kind not in ["tower","mine"]:
  for box in collision_boxes(kind):
   var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;n.add_child(body)
   var shape=CollisionShape3D.new();var resource=BoxShape3D.new();resource.size=box[1];shape.shape=resource;shape.position=box[0];body.add_child(shape)
 return n
