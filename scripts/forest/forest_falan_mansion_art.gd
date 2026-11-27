extends RefCounted
## The concert halls and studies belong to the mansion rotunda on city map 1000.
const Carvings=preload("res://scripts/forest/forest_falan_carvings.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")
const Data=preload("res://assets/maps/falan/room_art_data.gd")
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const CITY_CENTER=Vector2(36,-93)
const PAVILIONS=[Vector2(58.5,-76.5),Vector2(58.5,-109.5)]
const STAGES=[1301,1302]

static func surface_height(id:int,x:float,z:float)->float:
 var main=id==1301
 var center=0.0 if main else 1.5
 var apron=absf(z-center)
 var front=-74.5 if main else -26.5
 var shoulder=-83.0 if main else -33.5
 var back=-92.5 if main else -36.5
 var curve=front-9.5*pow(apron/(16.5 if main else 12.0),2)
 var wing=minf(shoulder-x,(35.5 if main else 33.5)-apron)
 var stage=minf(curve-x,(17.0 if main else 12.0)-apron)
 return clampf(.5+maxf(wing,stage)/3.0,0,1)*.93*clampf(.5+(x-back)/3.0,0,1)

static func exterior(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,copper:Material):
 var hall=Node3D.new();hall.name="MansionMainRotunda";root.add_child(hall)
 rotunda(hall,Vector3.ZERO,10.35,8.15,8.70,stone,pale,trim,base,slate,copper)
 var components:Array=Proportions.References.COMPONENTS["civic_1301"]
 var wings=components.slice(1);wings.sort_custom(func(a,b):return a.get_center().x<b.get_center().x)
 var index=0
 for at:Vector2 in PAVILIONS:
  var offset=at-CITY_CENTER
  var wing=Node3D.new();wing.name="MansionPavilion%d"%index;root.add_child(wing)
  rotunda(wing,Vector3(-offset.y,0,offset.x),5.1,4.55,4.45,stone,pale,trim,base,slate,copper)
  wing.transform=Proportions.measure(Proportions.node_points(wing),"",root.basis,wings[index]);index+=1
 var entrance=Boxes.new()
 root=hall
 var red=Fort.material(Color("a53026"),false)
 var dark=Fort.material(Color("263135"),false)
 for i in 3:
  entrance.add(Vector3(0,.10+i*.16,13.8-i*.60),Vector3(5.2,.20+i*.32,1.35),base)
 entrance.add(Vector3(0,.55,11.22),Vector3(3.5,.12,5.5),red)
 entrance.add(Vector3(0,.61,9.63),Vector3(3.27,.10,2.78),red)
 entrance.add(Vector3(0,2.86,8.93),Vector3(3.58,4.58,.22),dark)
 for side in [-1,1]:
  var foot=Vector3(side*2.52,0,12.65)
  Geo.cylinder(root,foot+Vector3.UP*3.22,.43,5.25,pale,false,.33)
  for level in [.64,1.12,5.62,5.99]:
   Geo.cylinder(root,foot+Vector3.UP*level,.59,.24,trim)
  Carvings.add(root,"mansion_portal",Vector3(side*2.52,4.80,13.12),Vector2(.70,1.90))
  entrance.add(Vector3(side*2.89,6.32,10.95),Vector3(.37,.48,4.86),pale)
 for level in [5.97,6.70]:
  entrance.add(Vector3(0,level,10.95),Vector3(6.11,.29,5.02),trim)
 entrance.add(Vector3(0,6.34,10.95),Vector3(5.90,.54,4.77),stone)
 Carvings.add(root,"mansion_frieze",Vector3(0,6.34,13.38),Vector2(5.74,.48))
 var points:Array[Vector3]=[]
 for group in entrance.groups.values():
  for pose:Transform3D in group.transforms:
   for corner in 8:points.append(pose*Vector3(.5 if corner&1 else -.5,.5 if corner&2 else -.5,.5 if corner&4 else -.5)+group.origin)
 hall.set_meta("source_box_points",points);entrance.build(hall)
 hall.transform=Proportions.measure(Proportions.node_points(hall),"",hall.get_parent().basis,components[0])

static func rotunda(root:Node3D,p:Vector3,radius:float,wall:float,rise:float,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,copper:Material):
 var dark=Fort.material(Color("3d4843"),false)
 var crimson=Fort.material(Color("ac382c"),false)
 var main=radius>6.0
 var bays=16 if main else 12
 for band in [[.26,.50,1.0,base],[.62,.27,.975,trim],[wall*.5,wall,.865,stone],
  [wall*.88,.21,.98,trim],[wall-.38,.58,.97,base],[wall,.25,1.01,trim]]:
  Geo.cylinder(root,p+Vector3.UP*band[0],radius*band[2],band[1],band[3]).mesh.radial_segments=64
 for i in bays:
  var angle=i*TAU/bays
  var radial=Vector3(sin(angle),0,cos(angle))
  var pillar=radial.rotated(Vector3.UP,PI/bays)
  var foot=p+pillar*radius*.924
  Geo.cylinder(root,foot+Vector3.UP*wall*.454,radius*.036,wall*.76,pale,false,radius*.028)
  for level in [.10,.79,.85]:
   Geo.cylinder(root,foot+Vector3.UP*wall*level,radius*.050,.22,trim)
  if main:
   Carvings.add(root,"mansion_frieze",p+radial*(radius*1.015)+Vector3.UP*(wall-.48),Vector2(radius*.36,1.03),angle)
  if main and i in [0,1,bays-1]:continue
  Carvings.add(root,"mansion_window",p+radial*(radius*.865+.08)+Vector3.UP*wall*.44,Vector2(radius*.171,wall*.48),angle)
  var sill=Geo.box(root,p+radial*radius*.89+Vector3.UP*wall*.20,Vector3(radius*.208,.18,.37),trim)
  sill.rotation.y=angle
  if main:
   Carvings.mansion_valance(root,p+radial*radius*.91+Vector3.UP*wall*.712,radius*.194,wall*.146,angle,crimson)
 var previous=radius
 for i in 16:
  var a=i*PI/32
  var b=(i+1)*PI/32
  var lower=sin(a)*rise
  var upper=sin(b)*rise
  var next=radius*cos(b)
  Geo.cylinder(root,p+Vector3.UP*(wall+(lower+upper)*.5),previous,upper-lower,slate,false,next).mesh.radial_segments=64
  previous=next
 for rib in (8 if main else 0):
  var axis=Vector3(sin(rib*TAU/8),0,cos(rib*TAU/8))
  for i in 12:
   var a=i*PI/24
   var b=(i+1)*PI/24
   Geo.beam(root,p+axis*(radius*cos(a))+Vector3.UP*(wall+rise*sin(a)+.11),
    p+axis*(radius*cos(b))+Vector3.UP*(wall+rise*sin(b)+.11),.17,trim)
 if main:
  Carvings.mansion_lantern(root,p+Vector3.UP*(wall+rise-.07),copper,dark)
 else:
  Geo.cylinder(root,p+Vector3.UP*(wall+rise),radius*.045,.13,slate)

static func stair_cells(id:int,serial:int)->Rect2i:
 for row in Data.FIXTURES.get(id,[]):
  if row[2]=="mansion_stair" and row[3]==serial:return Rect2i(row[0],row[1])
 return Rect2i()

static func furnishings(root:Node3D,center:Vector3,width:float,length_:float,swap:bool,serial:int,kind:String):
 var gold=Fort.material(Color("c6a26c"),false)
 var oak=Fort.material(Color("aa7851"),false)
 var wood=Fort.material(Color("61402f"),false)
 var pale=Fort.material(Color("ded1ab"),false)
 var red=Fort.material(Color("94382d"),false)
 var frame=Node3D.new()
 frame.name="FalanMansion_%d"%serial
 frame.position=center
 frame.rotation.y=PI*.5 if swap else 0.0
 root.add_child(frame)
 match kind:
  "mansion_column":
   Geo.cylinder(frame,Vector3.UP*2.3,1.23,4.6,red)
   for h in [.22,.49,3.98,4.46]:
    Geo.cylinder(frame,Vector3.UP*h,1.34,.17,gold)
   Geo.cylinder(frame,Vector3.UP*4.62,1.34,.22,wood)
  "mansion_stair":
   if serial==17658:
    # The offset lower flight needs the landing to reach around its inside rail.
    var deck=Vector3(width+.86,2.8,length_+1.39)
    var p=Vector3(0,deck.y*.5,.29)
    Geo.box(frame,p,deck,pale)
    Geo.box(frame,p+Vector3.UP*(deck.y*.5-.035),Vector3(deck.x,.11,deck.z),gold)
    Art.solid(frame,p,deck,1,"stone")
   else:
    var lower=serial==17657
    frame.rotation.y=-PI*.5 if lower else PI
    var start=0.0 if lower else 2.8
    var rise=2.8 if lower else 2.25
    var top=length_*.5
    var run=length_ if lower else length_-1.45
    var steps=9
    for i in steps:
     var z=(i+.5)*run/steps-top
     var y=start+rise*(i+1)/steps
     Geo.box(frame,Vector3(0,y*.5,z),Vector3(width*.84,y,run/steps+.04),pale)
     Geo.box(frame,Vector3(0,y,z-.11),Vector3(width*.86,.08,run/steps+.09),gold)
     for side in [-1,1]:
      Geo.cylinder(frame,Vector3(side*width*.39,y+.44,z),.044,.88,wood)
    var foot=Vector3(0,start,-top)
    var summit=Vector3(0,start+rise,run-top)
    var points=PackedVector3Array()
    for x in [-width*.42,width*.42]:
     var side=Vector3(x,0,0)
     points.append_array(PackedVector3Array([foot+side,summit+side,
      Vector3(x,-.08,foot.z),Vector3(x,-.08,summit.z)]))
    var slope=ConvexPolygonShape3D.new()
    slope.points=points
    Palace.support(frame,slope,Vector3.ZERO)
    for side in [-1,1]:
     var rail=Vector3(side*width*.39,.88,0)
     Geo.beam(frame,foot+rail,summit+rail,.12,wood)
     Art.solid(frame,(foot+summit)*.5+rail-Vector3.UP*.30,
      Vector3(.13,1.13,foot.distance_to(summit)-.24),1,"wood").rotation.x=-atan2(rise,run)
    if not lower:
     var deck=Vector3(width*.84,summit.y,top-summit.z+.04)
     var p=Vector3(0,summit.y*.5,(summit.z+top)*.5)
     Geo.box(frame,p,deck,pale)
     Art.solid(frame,p,deck,1,"stone")
     var end=Vector3(0,summit.y+.48,top-.07)
     Geo.box(frame,end+Vector3.UP*.40,Vector3(deck.x,.14,.17),wood)
     for x in [-deck.x*.42,0,deck.x*.42]:
      Geo.box(frame,end+Vector3.RIGHT*x,Vector3(.13,.96,.15),wood)
     Art.solid(frame,end,Vector3(deck.x,.96,.17),1,"wood")
  "mansion_desk":
   Geo.box(frame,Vector3.UP*1.52,Vector3(width*.52,.19,length_*.86),oak)
   Geo.box(frame,Vector3.UP*1.31,Vector3(width*.44,.28,length_*.80),wood)
   for side in [-1,1]:
    for end in [-1,1]:
     Geo.cylinder(frame,Vector3(side*width*.22,.69,end*length_*.35),.105,1.38,wood,false,.16)
   Geo.box(frame,Vector3(0,1.66,0),Vector3(.92,.09,1.35),wood)
   for end in [-1,1]:
    Geo.box(frame,Vector3(.03,1.73,end*.30),Vector3(.81,.08,.58),pale).rotation.x=end*.10
   for i in 3:
    Geo.box(frame,Vector3(.09,1.63+i*.09,length_*.26),Vector3(.70,.10,.97),red if i==1 else gold).rotation.y=i*.19
  "mansion_piano":
   var body=Geo.cylinder(frame,Vector3(0,1.82,.72),1.0,.64,wood)
   body.scale=Vector3(2.17,1,2.95)
   var lid=Geo.cylinder(frame,Vector3(.08,2.77,.81),1.0,.105,oak)
   lid.scale=Vector3(2.20,1,2.90)
   lid.rotation.z=.39
   Geo.beam(frame,Vector3(1.36,2.09,.87),Vector3(1.65,3.41,.87),.085,gold)
   Geo.box(frame,Vector3(0,1.79,-.89),Vector3(4.26,.64,3.14),wood)
   Geo.box(frame,Vector3(0,2.17,-2.57),Vector3(3.86,.13,.78),pale)
   for i in 21:
    Geo.box(frame,Vector3((i-10)*.176,2.25,-2.57),Vector3(.015,.02,.74),wood)
    if i%7 not in [2,6]:Geo.box(frame,Vector3((i-10)*.176+.08,2.29,-2.39),Vector3(.09,.07,.45),wood)
   Geo.box(frame,Vector3(0,2.56,-1.76),Vector3(1.38,.65,.14),wood).rotation.x=-.25
   Geo.box(frame,Vector3(0,2.62,-1.84),Vector3(1.05,.43,.065),pale).rotation.x=-.25
   for foot in [Vector2(-1.75,-1.72),Vector2(1.75,-1.72),Vector2(0,2.57)]:
    Geo.cylinder(frame,Vector3(foot.x,.79,foot.y),.14,1.58,wood,false,.25)
 frame.set_meta("archive_graphic",serial)

static func settees(root:Node3D,boxes,id:int,origin:Vector2):
 var gold=Fort.material(Color("c6a26c"),false)
 var wood=Fort.material(Color("61402f"),false)
 var red=Fort.material(Color("9d3929"),false)
 var linen=Fort.material(Color("d2bc94"),false)
 for row in Data.MANSION_SETTEES[id]:
  var p=origin+Vector2(row[0])*3.0
  var center=Vector3(p.x,0,p.y)
  var side_seat:bool=row[1]==17533
  var span=Vector3(2.98,0,1.34) if side_seat else Vector3(1.34,0,2.98)
  boxes.add(center+Vector3.UP*.38,span+Vector3.UP*.72,wood)
  boxes.add(center+Vector3.UP*.69,span+Vector3(.09,.15,.09),gold)
  boxes.add(center+Vector3.UP*.84,span+Vector3.UP*.22,linen if side_seat else red)
  Art.solid(root,center+Vector3.UP*.48,span+Vector3.UP*.96,1,"wood")
  if row[1]==17525:
   var bolster=Geo.cylinder(root,center+Vector3(0,.93,1.26),.17,1.32,red)
   bolster.rotation.z=PI*.5

static func pictures(root:Node3D,id:int,origin:Vector2,material:ShaderMaterial):
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var uv=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]
 for row in Data.ROOM_PICTURES[id]:
  var p=origin+Vector2(row[0])*3.0
  var center=Vector3(p.x,2.85,p.y)
  var normal=Vector3.RIGHT if row[2] else Vector3.BACK
  var across=Vector3.FORWARD if row[2] else Vector3.RIGHT
  for point:Vector2 in uv:
   mesh.set_normal(normal)
   mesh.set_uv(Vector2((row[1]+lerpf(.008,.992,point.x))*.25,point.y))
   mesh.add_vertex(center+across*(point.x-.5)*4.55+Vector3.UP*(.5-point.y)*1.82)
 var panels=Geo.mesh(root,mesh.commit(),Vector3.ZERO,material)
 panels.name="ArchivedRoomPaintings"
 panels.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
