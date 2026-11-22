extends RefCounted
## The nave and hospital furnishings fit inside the recovered blocked cells.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
static var drape:Mesh

static func furnish(root:Node3D,boxes,p:Vector3,swap:bool,length_:float,kind:String,serial:int):
 var wood=Fort.material(Color("71462f"),false)
 var polished=Fort.material(Color("99613c"),false)
 var shade=Fort.material(Color("453027"),false)
 var bronze=Fort.material(Color("ad8450"),false)
 var gold=Fort.material(Color("cdb277"),false)
 var pale=Fort.material(Color("d4cbbb"),false)
 match kind:
  "civic_pew":
   var span=length_*.94
   Court.part(boxes,p,swap,Vector3(0,.79,-.12),Vector3(span,.19,1.14),polished)
   Court.part(boxes,p,swap,Vector3(0,1.37,.45),Vector3(span,.19,.26),polished)
   Court.part(boxes,p,swap,Vector3(0,1.13,.45),Vector3(span-.55,.36,.15),wood)
   for i in int(span/.50):
    var x=(i+.5)*.50-span*.5
    Court.part(boxes,p,swap,Vector3(x,1.14,.54),Vector3(.10,.42,.075),bronze)
   for end in [-1,1]:
    Court.part(boxes,p,swap,Vector3(end*(span*.5-.10),.73,0),Vector3(.24,1.46,1.35),wood)
    Court.part(boxes,p,swap,Vector3(end*(span*.5-.10),1.47,.41),Vector3(.35,.19,.40),polished)
   Court.part(boxes,p,swap,Vector3(0,.25,-.36),Vector3(span-.23,.20,.41),shade)
  "civic_reredos":
   var height=9.2 if serial==17144 else 6.98
   Court.part(boxes,p,swap,Vector3(0,.23,0),Vector3(length_*.99,.46,1.72),shade)
   Court.part(boxes,p,swap,Vector3(0,height*.44,0),Vector3(length_*.94,height*.87,1.15),wood)
   for y in [1.16,height*.42,height*.76]:
    Court.part(boxes,p,swap,Vector3(0,y,0),Vector3(length_*.97,.22,1.43),bronze)
   for i in range(-3,4):
    var x=i*length_*.13
    var top=height*(1.0-absf(i)*.055)
    Court.part(boxes,p,swap,Vector3(x,top*.53,.08),Vector3(.48,top*1.06,1.31),polished)
    Court.part(boxes,p,swap,Vector3(x,top-.36,.63),Vector3(.76,.23,.25),gold)
    var peak=p+Vector3(0,top-.20,x) if swap else p+Vector3(x,top-.20,0)
    Geo.spike(root,peak,peak+Vector3.UP*.97,.23,bronze)
    if i==3:continue
    var niche=x+length_*.065
    var niche_height=height*.67
    Court.part(boxes,p,swap,Vector3(niche,niche_height,.584),Vector3(length_*.09,height*.27,.087),shade)
    for offset in [-.29,.29]:
     Court.part(boxes,p,swap,Vector3(niche+offset,niche_height,.645),Vector3(.088,height*.22,.077),gold)
    var medallion=p+Vector3(.66,niche_height,niche) if swap else p+Vector3(niche,niche_height,.66)
    Geo.sphere(root,medallion,Vector3(.17,.92,.44) if swap else Vector3(.44,.92,.17),pale)
  "civic_stall":
   Court.part(boxes,p,swap,Vector3(0,1.60,.42),Vector3(length_*.97,3.20,.32),wood)
   Court.part(boxes,p,swap,Vector3(0,3.12,.34),Vector3(length_,.24,.53),bronze)
   Court.part(boxes,p,swap,Vector3(0,.83,-.13),Vector3(length_*.89,.22,.94),polished)
   for i in range(3):
    var x=(i-1)*length_*.33
    Court.part(boxes,p,swap,Vector3(x,1.53,-.03),Vector3(.21,3.06,1.06),polished)
    Court.part(boxes,p,swap,Vector3(x,2.97,-.34),Vector3(.30,.16,.23),gold)
  "civic_basin":
   Court.part(boxes,p,swap,Vector3(0,.55,0),Vector3(length_*.94,1.1,1.72),wood)
   Court.part(boxes,p,swap,Vector3(0,1.12,0),Vector3(length_*.88,.07,1.53),Fort.material(Color("466779"),false))
   for side in [-1,1]:
    Court.part(boxes,p,swap,Vector3(0,1.29,side*.78),Vector3(length_*.95,.25,.20),bronze)
    Court.part(boxes,p,swap,Vector3(side*length_*.465,1.29,0),Vector3(.23,.25,1.73),bronze)
  "civic_font":
   var stone=Fort.material(Color("b6bcb3"))
   Geo.cylinder(root,p+Vector3.UP*.16,.57,.32,pale)
   Geo.cylinder(root,p+Vector3.UP*.78,.37,.96,stone,false,.29)
   Geo.cylinder(root,p+Vector3.UP*1.28,.38,.36,stone,false,.63)
   Geo.torus(root,p+Vector3.UP*1.50,.50,.66,pale)
   Geo.cylinder(root,p+Vector3.UP*1.43,.48,.056,Fort.material(Color("879da0"),false))
  "civic_globes":
   var palette=[Geo.mat("b89bc7",0,.28),Geo.mat("adc9cd",0,.27),Geo.mat("e4c381",0,.25)]
   var count=3 if serial==17139 else 1
   for i in count:
    var x=(i-(count-1)*.5)*.69
    var at=p+(Vector3(0,0,x) if swap else Vector3(x,0,0))
    var h=.84+(count-i-1)*.32
    Geo.cylinder(root,at+Vector3.UP*h*.5,.35,h,wood,false,.24)
    Geo.cylinder(root,at+Vector3.UP*h,.39,.12,bronze)
    Geo.sphere(root,at+Vector3.UP*(h+.32),Vector3.ONE*.69,palette[i if count==3 else int(serial==17147)])
  "civic_statue":
   Statues.build(root,boxes,p,10401)
  "civic_stool":
   Court.part(boxes,p,swap,Vector3.UP*.81,Vector3(1.22,.19,1.19),wood)
   Court.part(boxes,p,swap,Vector3.UP*.93,Vector3(1.10,.16,1.08),Fort.material(Color("9a554a"),false))
   for side in [-1,1]:
    for end in [-1,1]:
     Court.part(boxes,p,swap,Vector3(side*.49,.39,end*.49),Vector3(.13,.78,.13),bronze)
  "civic_screen":
   screen(root,p,pale,bronze)

static func screen(root:Node3D,p:Vector3,linen:Material,bronze:Material):
 if drape==null:
  var mesh=SurfaceTool.new()
  mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in 14:
   var a=fold(float(i)/14)
   var b=fold(float(i+1)/14)
   var c=b+Vector3.UP*2.56
   var d=a+Vector3.UP*2.56
   for point in [a,b,c,a,c,d,b,a,d,b,d,c]:mesh.add_vertex(point)
  mesh.generate_normals()
  drape=mesh.commit()
 var frame=Node3D.new()
 frame.position=p
 frame.rotation.y=PI*.5
 root.add_child(frame)
 Geo.mesh(frame,drape,Vector3.ZERO,linen)
 for side in [-1,1]:
  var foot=Vector3(side*1.12,0,0)
  Geo.cylinder(frame,foot+Vector3.UP*.10,.27,.20,bronze)
  Geo.cylinder(frame,foot+Vector3.UP*1.53,.068,3.06,bronze)
  Geo.sphere(frame,foot+Vector3.UP*3.11,Vector3.ONE*.18,bronze)
 Geo.beam(frame,Vector3(-1.18,2.98,0),Vector3(1.18,2.98,0),.056,bronze)

static func fold(t:float)->Vector3:
 return Vector3((t-.5)*2.08,.39+.05*cos(t*TAU*4.0),.12*sin(t*TAU*4.0))

static func hospital_desk(root:Node3D,boxes,p:Vector3,swap:bool,length_:float):
 var brass=Fort.material(Color("aa8553"),false)
 var glaze=[Geo.mat("6d8e88"),Geo.mat("8d633c"),Geo.mat("758996")]
 for i in 3:
  var d=length_*.19+i*.37
  var at=p+(Vector3(-d,0,.38) if swap else Vector3(.38,0,-d))
  Geo.cylinder(root,at+Vector3.UP*1.53,.115,.30,glaze[i],false,.132)
  Geo.cylinder(root,at+Vector3.UP*1.72,.063,.11,glaze[i])
  Geo.cylinder(root,at+Vector3.UP*1.80,.082,.070,brass)
 Court.part(boxes,p,swap,Vector3(-.39,1.39,length_*.26),Vector3(.73,.08,.69),Fort.material(Color("ddd0ad"),false))
