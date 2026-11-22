extends RefCounted
## The shrine and lower gallery use the archive's 3 m stair strips.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ARCHIVE=preload("res://assets/maps/falan/room_art_data.gd")
const RAISED_FLOORS=[1522,1530]

static func surface_height(id:int,x:float,z:float)->float:
 if id==1530 and x>=-43.5 and z>=-25.5 and z<=28.5:
  return clampf((-4.5-x)/3.0,0.0,1.0)*1.12
 if id==1522:
  var edge=maxf(maxf(22.5-x,x-49.5),absf(z)-13.5)
  edge=maxf(edge,(absf(x-36.0)+absf(z)-24.0)*.7071)
  return clampf(edge/3.0,0.0,1.0)*.96
 return 0.0

static func build(root:Node3D,boxes,id:int,origin:Vector2):
 if not ARCHIVE.CELLAR_STAIRS.has(id):return
 var room=Node3D.new()
 room.name="ArchivedCellarDetails"
 root.add_child(room)
 var stone=Fort.material(Color("a6b5b8"),false)
 var edge=Fort.material(Color("d0d7cd"),false)
 for row in ARCHIVE.CELLAR_STAIRS[id]:
  var at=origin+Vector2(row[0])*3.0
  var serial:int=row[1]
  var along_x=serial not in [17112,17114,17116,17119,17122,17125]
  var direction=Vector2.RIGHT if along_x else Vector2.DOWN
  var start=at-direction*1.5
  var finish=at+direction*1.5
  var low=surface_height(id,start.x,start.y)
  var high=surface_height(id,finish.x,finish.y)
  if is_equal_approx(low,high):
   # shortcut: keep shallow landing trims level with the archived path; use
   # a separate height tier when the neighboring floor boundaries are known.
   high+=.20 if serial in [17113,17112] else .045
   low+=.20 if serial in [12000,17111,17114] else .045
  for i in 5:
   var p=start.lerp(finish,(i+.5)/5.0)
   var top=maxf(lerpf(low,high,i/5.0),lerpf(low,high,(i+1)/5.0))+.045
   var extent=Vector3(.61,.13,2.98) if along_x else Vector3(2.98,.13,.61)
   boxes.add(Vector3(p.x,top-.065,p.y),extent,stone)
   p+=direction*(-.23 if high>low else .23)
   var nosing=Vector3(.076,.063,2.99) if along_x else Vector3(2.99,.063,.076)
   boxes.add(Vector3(p.x,top-.023,p.y),nosing,edge)
 if id==1530:
  # The pale dais, blue floor and gilded border come from the original atlas.
  for at in [Vector2(-39,24),Vector2(-39,-21),Vector2(-18,24),Vector2(-18,-21)]:
   brazier_light(room,at,surface_height(id,at.x,at.y))
  for z in [-15.0,15.0]:
   var p=Vector3(-3,0,z)
   Geo.cylinder(room,p+Vector3.UP*.19,.36,.38,edge,false,.25)
   Geo.cylinder(room,p+Vector3.UP*2.12,.10,3.70,stone,false,.075)
   Geo.cylinder(room,p+Vector3.UP*3.99,.21,.26,edge,false,.13)
   Geo.sphere(room,p+Vector3.UP*4.22,Vector3(.37,.56,.37),edge)
 elif id==1531:
  for at in [Vector2(0,30),Vector2(0,-15)]:brazier_light(room,at,0)

static func brazier_light(root:Node3D,at:Vector2,height:float):
 var lamp=OmniLight3D.new()
 lamp.position=Vector3(at.x,height+1.45,at.y)
 lamp.light_color=Color("f1ba72")
 lamp.light_energy=1.2
 lamp.omni_range=7.0
 root.add_child(lamp)

static func furnish(root:Node3D,boxes,p:Vector3,kind:String,serial:int,swap:bool,length_:float):
 var stone=Fort.material(Color("a6b1af"),false)
 var pale=Fort.material(Color("c8cec3"),false)
 var bronze=Fort.material(Color("826740"),false)
 var gold=Fort.material(Color("c5a260"),false)
 var iron=Fort.material(Color("434e50"),false)
 var timber=Fort.material(Color("74553b"),false)
 match kind:
  "moon":
   pedestal(boxes,p,1.30,bronze,gold)
   var crescent=Geo.mesh(root,moon_mesh(),p+Vector3.UP*1.95,pale)
   crescent.name="ArchiveCrescent"
   crescent.rotation.y=deg_to_rad(-36+(serial-17237)*90)
  "lectern":
   pedestal(boxes,p,1.54,bronze,gold)
   var book=Geo.box(root,p+Vector3.UP*.89,Vector3(.94,.23,1.24),iron)
   book.rotation.z=-.19
   var page=Geo.box(root,p+Vector3(.012,1.03,0),Vector3(.82,.07,1.12),pale)
   page.rotation.z=-.19
  "finial":
   pedestal(boxes,p,.73,bronze,gold)
   Geo.cylinder(root,p+Vector3.UP*.66,.21,.39,bronze,false,.13)
   Geo.sphere(root,p+Vector3.UP*.93,Vector3(.29,.32,.29),gold)
  "rope":
   var axis=Vector3.RIGHT if swap else Vector3.BACK
   var end=axis*minf(1.7,length_*.33)
   for side in [-1,1]:
    var post=p+end*side
    Geo.cylinder(root,post+Vector3.UP*.18,.24,.35,stone)
    Geo.cylinder(root,post+Vector3.UP*.64,.11,1.13,iron,false,.09)
    Geo.sphere(root,post+Vector3.UP*1.23,Vector3.ONE*.29,pale)
   var last=p-end+Vector3.UP*1.03
   for i in range(1,7):
    var t=i/6.0
    var next=p+end*(2.0*t-1.0)+Vector3.UP*(1.03-.30*sin(PI*t))
    Geo.beam(root,last,next,.065,pale)
    last=next
  "grille":
   var tall=serial==17091
   var height=4.6 if tall else 2.20
   var span=minf(4.6,length_*.92)
   for i in range(ceili(span/.40)+1):
    var x=lerpf(-span*.5,span*.5,float(i)/ceili(span/.40))
    var at=p+Vector3(x,0,0) if swap else p+Vector3(0,0,x)
    boxes.add(at+Vector3.UP*height*.5,Vector3(.10,height,.10),iron)
    boxes.add(at+Vector3.UP*(height+.065),Vector3(.15,.18,.15),stone)
   for level in [.43,height*.67,height-.22]:
    var extent=Vector3(span+.14,.12,.14) if swap else Vector3(.14,.12,span+.14)
    boxes.add(p+Vector3.UP*level,extent,iron)
  "bust":
   pedestal(boxes,p,1.3,stone,pale)
   boxes.add(p+Vector3.UP*.91,Vector3(.75,.34,.49),stone)
   Geo.sphere(root,p+Vector3.UP*1.25,Vector3(.48,.56,.43),stone)
  "crate","chest":
   var chest=kind=="chest"
   var width=1.32 if chest else 1.76
   var height=.94 if chest else 1.41
   boxes.add(p+Vector3.UP*height*.5,Vector3(width,height,width*.83),timber)
   boxes.add(p+Vector3.UP*height,Vector3(width+.09,.17,width*.88),bronze)
   for corner in [-1,1]:
    for side in [-1,1]:
     boxes.add(p+Vector3(corner*width*.40,height*.51,side*width*.421),Vector3(.14,height,.07),gold if chest else bronze)
   if chest:boxes.add(p+Vector3(0,height*.72,width*.43),Vector3(.24,.22,.08),gold)

static func pedestal(boxes,p:Vector3,width:float,body:Material,trim:Material):
 boxes.add(p+Vector3.UP*.10,Vector3(width,.20,width),trim)
 boxes.add(p+Vector3.UP*.38,Vector3(width*.77,.38,width*.77),body)
 boxes.add(p+Vector3.UP*.62,Vector3(width*.93,.16,width*.93),trim)

static var crescent_mesh:Mesh
static func moon_mesh()->Mesh:
 if crescent_mesh!=null:return crescent_mesh
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var front=Vector3.BACK*.095
 for i in 18:
  var a=moon_section(float(i)/18.0)
  var b=moon_section(float(i+1)/18.0)
  quad(surface,a[0]+front,b[0]+front,b[1]+front,a[1]+front)
  quad(surface,a[1]-front,b[1]-front,b[0]-front,a[0]-front)
  quad(surface,a[0]-front,b[0]-front,b[0]+front,a[0]+front)
  quad(surface,a[1]+front,b[1]+front,b[1]-front,a[1]-front)
 surface.generate_normals()
 crescent_mesh=surface.commit()
 return crescent_mesh

static func moon_section(t:float)->Array:
 var angle=lerpf(-PI*.51,PI*.60,t)
 var outer=Vector3(cos(angle)*.89-.28,sin(angle)*1.21,0)
 var width=.045+.55*pow(sin(PI*t),.82)
 return [outer,outer-Vector3.RIGHT*width]

static func quad(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 for point in [a,c,b,a,d,c]:surface.add_vertex(point)
