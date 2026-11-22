extends RefCounted
## 10012 and 10013 use the courtyard source grid. The front of the keep faces +X.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const CIVIC_ART="res://scripts/forest/forest_falan_civic_exterior.gd"
const ENTRY_Z=-1.5

static func masonry(color:Color)->ShaderMaterial:
 var material:ShaderMaterial=Fort.material(color).duplicate()
 material.set_shader_parameter("masonry_tile",Vector2(1.58,.73))
 return material

static func plinth_spans(base:Array)->Array[Rect2]:
 var spans:Array[Rect2]=[]
 for row in base:
  var center:Vector2=row[0]
  var span=Rect2(center-Vector2(1.5,row[1]*.5),Vector2(3,row[1]))
  if center.x<-24:
   spans.append(span)
   continue
  # These source cells depict the entrance stair; its own ramp owns collision.
  for range_:Vector2 in [Vector2(span.position.y,minf(span.end.y,ENTRY_Z-3.42)),
   Vector2(maxf(span.position.y,ENTRY_Z+3.42),span.end.y)]:
   if range_.y>range_.x:
    spans.append(Rect2(span.position.x,range_.x,span.size.x,range_.y-range_.x))
 return spans

static func build(root:Node3D,boxes,base:Array,ground:float):
 var keep=Node3D.new()
 keep.name="ArchivedRoyalKeep"
 root.add_child(keep)
 var stone=masonry(Color("c9c1a5"))
 var trim=Fort.material(Color("e3d6b6"),false)
 var terrace=Fort.material(Color("677473"))
 var slate=Fort.material(Color("4d7ca6"),false)
 var ridge=Fort.material(Color("8ca9c0"),false)
 var brass=Fort.material(Color("c69b43"),false)
 var civic=load(CIVIC_ART)
 for span in plinth_spans(base):
  var at=span.get_center()
  boxes.add(Vector3(at.x,ground+1.3,at.y),Vector3(span.size.x+.01,2.6,span.size.y),stone)
 var p=Vector3(-36,ground+2.65,ENTRY_Z)
 block(boxes,p+Vector3(-2.0,0,0),Vector2(20.2,23.0),15.4,stone,trim,terrace)
 block(boxes,p+Vector3(-4.25,15.4,0),Vector2(15.1,14.6),14.5,stone,trim,terrace)
 for x in [-10.6,2.0]:
  for z in [-6.0,6.0]:
   var turret=p+Vector3(x,26.2,z)
   blue_turret(keep,boxes,turret,2.22,12.5,stone,trim,slate,ridge,brass)
 for side in [-1,1]:
  var wing=p+Vector3(2.4,0,side*12.25)
  block(boxes,wing,Vector2(15.9,8.0),8.8,stone,trim,terrace)
  civic.roof(keep,wing+Vector3(-2.4,8.9,0),8.0,8.2,4.1,slate,ridge,PI*.5)
  for x in [-5.1,3.6]:
   blue_turret(keep,boxes,wing+Vector3(x,8.4,0),2.45,13.15,stone,trim,slate,ridge,brass)
  for z in [6.0,12.0]:banner(boxes,p+Vector3(6.4,14.7,side*z),PI*.5,brass)
  var post=p+Vector3(10.15,0,side*3.8)
  boxes.add(post+Vector3.UP*3.8,Vector3(1.2,7.6,1.35),stone)
  boxes.add(post+Vector3.UP*7.6,Vector3(1.6,.42,1.65),trim)
 var arch=p+Vector3(10.1,0,0)
 var portal=Geo.mesh(keep,civic.lancet(),arch,trim)
 portal.rotation.y=PI*.5
 portal.scale=Vector3(6.0,6.35,1)
 var dark=Geo.mesh(keep,civic.lancet(),arch+Vector3(.064,0,0),Fort.material(Color("343436"),false))
 dark.rotation.y=PI*.5
 dark.scale=Vector3(4.55,5.72,1)
 boxes.add(arch+Vector3(-.7,6.55,0),Vector3(4.0,.80,8.9),trim)
 boxes.add(arch+Vector3(-.7,7.08,0),Vector3(4.12,.30,8.95),terrace)
 for z in [-3.9,-2.0,0.0,2.0,3.9]:
  boxes.add(arch+Vector3(1.29,7.48,z),Vector3(.62,.69,1.02),trim)
 civic.roof(keep,p+Vector3(4.3,16.15,0),7.2,6.4,6.35,slate,ridge,PI*.5)
 clock(keep,p+Vector3(7.60,20.38,0),trim,brass)

static func block(boxes,p:Vector3,span:Vector2,height:float,stone:Material,trim:Material,top:Material):
 boxes.add(p+Vector3.UP*(height*.5),Vector3(span.x,height,span.y),stone)
 boxes.add(p+Vector3.UP*(height-.26),Vector3(span.x+.38,.62,span.y+.38),trim)
 boxes.add(p+Vector3.UP*(height+.06),Vector3(span.x,.18,span.y),top)
 for level in [.19,.83]:
  boxes.add(p+Vector3.UP*(height*level),Vector3(span.x+.18,.22,span.y+.18),trim)
 for side in [-1,1]:
  for i in ceili(span.y/1.8):
   boxes.add(p+Vector3(side*span.x*.5,height+.42,minf(span.y-.8,(i+.5)*1.8)-span.y*.5),Vector3(.62,.83,.92),trim)
  for i in ceili(span.x/1.8):
   boxes.add(p+Vector3(minf(span.x-.8,(i+.5)*1.8)-span.x*.5,height+.42,side*span.y*.5),Vector3(.92,.83,.62),trim)

static func blue_turret(root:Node3D,boxes,p:Vector3,radius:float,height:float,stone:Material,trim:Material,slate:Material,ridge:Material,brass:Material):
 load(CIVIC_ART).spire(root,p,radius,height,stone,trim,slate,ridge,brass)
 for i in 4:
  var yaw=i*PI*.5
  var face=Vector3(sin(yaw),0,cos(yaw))
  lancet(root,p+face*radius*.891+Vector3.UP*(height*.23),yaw,radius*.92,height*.37,trim)
  boxes.add(p+face*radius*.939+Vector3.UP*(height*.60),Vector3(.46,.37,.46),trim)
 Geo.sphere(root,p+Vector3.UP*(height+radius*1.89),Vector3.ONE*radius*.31,brass)

static func lancet(root:Node3D,p:Vector3,yaw:float,width:float,height:float,trim:Material):
 var face=Vector3(sin(yaw),0,cos(yaw))
 var shape=load(CIVIC_ART).lancet()
 var outline=Geo.mesh(root,shape,p,trim)
 outline.rotation.y=yaw
 outline.scale=Vector3(width+.29,height+.22,1)
 var recess=Geo.mesh(root,shape,p+face*.045+Vector3.UP*.13,Fort.material(Color("394547"),false))
 recess.rotation.y=yaw
 recess.scale=Vector3(width,height,1)
 var mullion=Geo.box(root,p+face*.072+Vector3.UP*(height*.4),Vector3(.10,height*.72,.10),trim)
 mullion.rotation.y=yaw

static func banner(boxes,p:Vector3,yaw:float,brass:Material):
 var face=Vector3(sin(yaw),0,cos(yaw))
 var across=Vector3(cos(yaw),0,-sin(yaw))
 var dimensions=Vector3(.10,4.9,1.28) if absf(face.x)>.5 else Vector3(1.28,4.9,.10)
 boxes.add(p,dimensions,Fort.material(Color("b34130"),false))
 boxes.add(p+face*.075,dimensions*Vector3(.85,.98,.85),Fort.material(Color("9b3829"),false))
 var gold=dimensions
 gold.y=3.65
 if absf(face.x)>.5:gold.z=.22
 else:gold.x=.22
 boxes.add(p+face*.13+across*.32,gold,brass)
 boxes.add(p+Vector3.UP*2.47,Vector3(dimensions.x+.27,.17,dimensions.z+.27),brass)

static func clock(root:Node3D,p:Vector3,trim:Material,brass:Material):
 var rim=Geo.cylinder(root,p,1.49,.27,trim)
 rim.rotation.z=PI*.5
 var face=Geo.cylinder(root,p+Vector3.RIGHT*.15,1.23,.09,Fort.material(Color("557eaa"),false))
 face.rotation.z=PI*.5
 for i in 12:
  var angle=TAU*i/12
  Geo.sphere(root,p+Vector3(.23,cos(angle)*1.02,sin(angle)*1.02),Vector3.ONE*.13,brass)
 Geo.beam(root,p+Vector3.RIGHT*.24,p+Vector3(.24,.70,0),.09,brass)
 Geo.beam(root,p+Vector3.RIGHT*.24,p+Vector3(.24,-.23,.47),.09,brass)

static func annex(root:Node3D,boxes,p:Vector3,stone:Material,trim:Material,base:Material,brass:Material):
 block(boxes,p,Vector2(20.7,8.8),13.7,stone,trim,base)
 for side in [-1,1]:
  var at=p+Vector3(side*4.62,13.65,0)
  open_turret(root,at,3.22,10.8,stone,trim,base,8)
  for direction in [-1,1]:
   var yaw=0.0 if direction>0 else PI
   lancet(root,p+Vector3(side*5.2,6.0,direction*4.46),yaw,1.28,4.5,trim)
   lancet(root,at+Vector3(0,3.15,direction*3.05),yaw,1.06,4.4,trim)
  banner(boxes,p+Vector3(side*10.40,8.1,1.65),side*PI*.5,brass)

static func open_turret(root:Node3D,p:Vector3,radius:float,height:float,stone:Material,trim:Material,base:Material,sides:int=12):
 var foot=Geo.cylinder(root,p+Vector3.UP*1.61,radius*1.12,3.22,base,false,radius*.97)
 foot.mesh.radial_segments=sides
 var shaft=Geo.cylinder(root,p+Vector3.UP*(height*.5+1.1),radius*.98,height-2.2,stone,false,radius)
 shaft.mesh.radial_segments=sides
 var floor_=Geo.cylinder(root,p+Vector3.UP*(height-.72),radius,.38,base)
 floor_.mesh.radial_segments=sides
 for i in sides:
  var angle=i*TAU/sides
  var face=Vector3(sin(angle),0,cos(angle))
  var coping=Geo.box(root,p+face*(radius*.92)+Vector3.UP*height,Vector3(TAU*radius/sides*.98,1.10,.51),trim)
  coping.rotation.y=angle
  var tooth=Geo.box(root,coping.position+Vector3.UP*.78,Vector3(TAU*radius/sides*.55,.61,.74),trim)
  tooth.rotation.y=angle
  if i%2==0:
   var slit=Geo.box(root,p+face*(radius*.965)+Vector3.UP*(height*.43),Vector3(.17,2.1,.14),Fort.material(Color("48504b"),false))
   slit.rotation.y=angle
