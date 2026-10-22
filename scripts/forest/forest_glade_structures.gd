extends RefCounted
## Static, shared miniature masonry. Original structure colliders own all gameplay.
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const STONE=[Color("b6b89f"),Color("a9ae94"),Color("bfc0a8"),Color("afb29a"),Color("a4ad93")]
static var meshes:Dictionary={}
static var stone_material:StandardMaterial3D
static var garden_material:StandardMaterial3D
static var ground_material:StandardMaterial3D
var tool:SurfaceTool
var rng=RandomNumberGenerator.new()

static func build(kind:String,model,placement:Transform3D)->Node3D:
 var root=Node3D.new();root.name="TowerDetails" if kind=="tower" else "BarracksDetails"
 var builder=new()
 if not meshes.has(kind):meshes[kind]=builder.structure(kind)
 if stone_material==null:
  stone_material=StandardMaterial3D.new();stone_material.vertex_color_use_as_albedo=true
  stone_material.vertex_color_is_srgb=true;stone_material.roughness=.95;stone_material.metallic_specular=.16
  garden_material=stone_material.duplicate();garden_material.cull_mode=BaseMaterial3D.CULL_DISABLED
  ground_material=stone_material.duplicate();ground_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 var masonry=MeshInstance3D.new();masonry.name="GladeMasonry";masonry.mesh=meshes[kind];masonry.material_override=stone_material;root.add_child(masonry)
 var planting=MeshInstance3D.new();planting.name="GladeGarden";planting.mesh=builder.garden(kind,model,placement);planting.material_override=garden_material
 planting.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(planting)
 var apron=MeshInstance3D.new();apron.name="GladeMeadow";apron.mesh=builder.meadow(kind,model,placement);apron.material_override=ground_material
 apron.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(apron)
 return root

func begin(seed_:int):
 rng.seed=seed_;tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
func finish()->ArrayMesh:
 tool.index();return tool.commit()
func triangle(a:Vector3,b:Vector3,c:Vector3,normal:Vector3,color:Color):
 # Godot's front faces use clockwise winding.
 var points=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
 for p in points:tool.set_normal(normal);tool.set_color(color);tool.add_vertex(p)
func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,normal:Vector3,color:Color):
 triangle(a,b,c,normal,color);triangle(a,c,d,normal,color)
func block(center:Vector3,size_:Vector3,color:Color,bevel:float=.12,basis:Basis=Basis.IDENTITY):
 var h=size_*.5;var r=minf(bevel,minf(h.x,minf(h.y,h.z))*.7)
 # Six broad faces, twelve bevels and eight clipped corners; no subdivision.
 for axis in 3:
  var u=(axis+1)%3;var v=(axis+2)%3
  for sign_ in [-1.0,1.0]:
   var normal=Vector3.ZERO;normal[axis]=sign_
   var points=[]
   for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
    var p=Vector3.ZERO;p[axis]=h[axis]*sign_;p[u]=(h[u]-r)*pair.x;p[v]=(h[v]-r)*pair.y;points.append(center+basis*p)
   quad(points[0],points[1],points[2],points[3],basis*normal,color)
  for su in [-1.0,1.0]:
   for sv in [-1.0,1.0]:
    var points=[]
    for pair in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
     var p=Vector3.ZERO;p[axis]=(h[axis]-r)*pair.x
     p[u]=(h[u]-(r if pair.y==1 else 0.0))*su;p[v]=(h[v]-(r if pair.y==0 else 0.0))*sv
     points.append(center+basis*p)
    var normal=Vector3.ZERO;normal[u]=su;normal[v]=sv
    quad(points[0],points[1],points[2],points[3],basis*normal.normalized(),color.lightened(.025))
 for x in [-1.0,1.0]:
  for y in [-1.0,1.0]:
   for z in [-1.0,1.0]:
    var sign_=Vector3(x,y,z);var points=[]
    for axis in 3:
     var p=(h-Vector3.ONE*r)*sign_;p[axis]=h[axis]*sign_[axis];points.append(center+basis*p)
    triangle(points[0],points[1],points[2],basis*sign_.normalized(),color)
func shade()->Color:return STONE[rng.randi_range(0,STONE.size()-1)]
func courses(width:float,height:float,depth:float):
 block(Vector3(0,height*.5,0),Vector3(width-.12,height,depth-.12),Color("7e8870"),.15)
 var rows=ceili(height/1.28);var row_height=height/rows
 for side in 4:
  var turn=Basis(Vector3.UP,side*PI*.5);var span=width if side%2==0 else depth;var face=depth*.5 if side%2==0 else width*.5
  for row in rows:
   var cursor=-span*.5;var first=true
   while cursor<span*.5-.01:
    var length_=minf(2.35+(rng.randf()-.5)*.32,span*.5-cursor)
    if first and row%2==1:length_=minf(1.16,length_)
    var p=Vector3(cursor+length_*.5,(row+.5)*row_height,face-.13)
    var color=shade()
    if row==0:color=color.lerp(Color("7c8b60"),.28)
    block(turn*p,Vector3(maxf(.05,length_-.055),row_height-.065,.42),color,.10,turn)
    cursor+=length_;first=false
func rail(center:Vector3,length_:float,turn:Basis):
 var count=ceili(length_/2.5);var step=length_/count
 for i in count:
  block(center+turn*Vector3((i+.5)*step-length_*.5,0,0),Vector3(step-.055,1.2,.85),shade(),.13,turn)
func arch(center:Vector3,width:float,height:float,turn:Basis):
 var radius=width*.5;var spring=height-radius
 var dark=Color("354b3c")
 quad(center+turn*Vector3(-radius,0,0),center+turn*Vector3(radius,0,0),center+turn*Vector3(radius,spring,0),center+turn*Vector3(-radius,spring,0),turn*Vector3.BACK,dark)
 for i in 10:
  var a=PI*i/10;var b=PI*(i+1)/10
  triangle(center+turn*Vector3(0,spring,0),center+turn*Vector3(cos(a)*radius,spring+sin(a)*radius,0),center+turn*Vector3(cos(b)*radius,spring+sin(b)*radius,0),turn*Vector3.BACK,dark)
  var mid=(a+b)*.5
  block(center+turn*Vector3(cos(mid)*(radius+.25),spring+sin(mid)*(radius+.25),.06),Vector3(.49,(radius+.25)*PI/10-.025,.42),shade(),.065,turn*Basis(Vector3.FORWARD,mid))
 for side in [-1,1]:
  var count=ceili(spring/.9)
  for i in count:block(center+turn*Vector3(side*(radius+.25),(i+.5)*spring/count,.06),Vector3(.5,spring/count-.045,.42),shade(),.075,turn)
func slit(p:Vector3,turn:Basis):
 block(p,Vector3(.38,1.85,.07),Color("3e5142"),.03,turn)
 block(p+Vector3(0,-1.0,0),Vector3(.95,.22,.5),shade(),.07,turn)
func structure(kind:String)->ArrayMesh:
 begin(740 if kind=="tower" else 380)
 var tower=kind=="tower";var width=10.0 if tower else 17.2
 var deck=Profile.TOWER_DECK_HEIGHT if tower else Profile.BARRACKS_DECK_HEIGHT
 var body=Profile.TOWER_BODY_HEIGHT if tower else Profile.BARRACKS_BODY_HEIGHT
 block(Vector3(0,.34,0),Vector3(width+1.0,.68,width+1.0),Color("899475"),.17)
 courses(width,body,width)
 var deck_width=11.0 if tower else 17.8;var thickness=.5 if tower else .6
 block(Vector3(0,deck-thickness*.5,0),Vector3(deck_width,thickness,deck_width),Color("c0bfa4"),.13)
 # Broad paving slabs keep the occupied deck crisp from the combat camera.
 var tiles=4 if tower else 6;var step=(width-.8)/tiles
 for x in tiles:
  for z in tiles:block(Vector3((x+.5)*step-(width-.8)*.5,deck-.04,(z+.5)*step-(width-.8)*.5),Vector3(step-.045,.08,step-.045),shade().lightened(.035),.025)
 var rail_offset=5.0 if tower else 8.15
 for side in 4:
  var turn=Basis(Vector3.UP,side*PI*.5)
  rail(turn*Vector3(0,deck+.6,rail_offset),10.5 if tower else 17.2,turn)
  for slot in ([-3.5,0,3.5] if tower else [-6,-2,2,6]):
   block(turn*Vector3(slot,deck+1.7,rail_offset),Vector3(1.7 if tower else 2.2,1.0,.85 if tower else 1.1),shade().lightened(.04),.14,turn)
  slit(turn*Vector3(-3.0 if tower else -5.7,body*.66,width*.5+.095),turn)
  if not tower:slit(turn*Vector3(5.7,3.2,width*.5+.095),turn)
 arch(Vector3(0,.3,width*.5+.12),2.25 if tower else 3.35,4.8 if tower else 4.25,Basis.IDENTITY)
 if tower:
  # Retain both walkable landings and their precise heights.
  var pillar_height=Profile.TOWER_LOOKOUT_HEIGHT-deck-.5
  for x in [-4.7,4.7]:
   for i in 4:block(Vector3(x,deck+(i+.5)*pillar_height/4,-4.7),Vector3(.85,pillar_height/4-.04,.85),shade(),.085)
  block(Vector3(0,Profile.TOWER_LOOKOUT_CENTER,-4),Vector3(11.8,Profile.TOWER_LOOKOUT_THICKNESS,4),Color("bfc0a6"),.15)
  for x in [-4,0,4]:block(Vector3(x,Profile.TOWER_LOOKOUT_HEIGHT+.3,-5.4),Vector3(1.8,.6,.85),shade(),.12)
 else:
  block(Vector3(6.6,8.1,5.5),Vector3(.14,4.2,.14),Color("726a47"),.025)
  block(Vector3(5.2,9.4,5.5),Vector3(2.8,1.55,.08),Color("ac5341"),.015)
  block(Vector3(5.2,9.4,5.56),Vector3(.42,.9,.04),Color("ead198"),.008)
 # Low ivy follows selected joints, leaving the entrance and deck unobstructed.
 for side in [1,3]:
  var turn=Basis(Vector3.UP,side*PI*.5)
  for i in 15:
   var y=.5+i*.23;var x=width*.29+sin(i*.9)*.3
   block(turn*Vector3(x,y,width*.5+.105),Vector3(.32,.35,.075),Color("6e8657").lightened(rng.randf()*.1),.06,turn*Basis(Vector3.FORWARD,rng.randf_range(-.6,.6)))
 return finish()

func mound(center:Vector3,size_:Vector3,color:Color):
 var rings=3;var segments=7
 for ring in rings:
  var a=PI*.5*ring/rings;var b=PI*.5*(ring+1)/rings
  for segment in segments:
   var c=TAU*segment/segments;var d=TAU*(segment+1)/segments
   var p=[]
   for angle in [Vector2(a,c),Vector2(a,d),Vector2(b,d),Vector2(b,c)]:p.append(center+Vector3(cos(angle.x)*cos(angle.y),sin(angle.x),cos(angle.x)*sin(angle.y))*size_)
   var normal=((p[0]+p[1]+p[2]+p[3])*.25-center).normalized()
   quad(p[0],p[1],p[2],p[3],normal,color.lightened(rng.randf()*.055))
func garden(kind:String,model,placement:Transform3D)->ArrayMesh:
 begin(319 if kind=="tower" else 820)
 var half=5.5 if kind=="tower" else 8.9
 # Every planted corner is terrain-fitted once at construction; no frame updates.
 for side in [-1,1]:
  for end in [-1,1]:
   var p=Vector3(side*(half+.2),0,end*(half-.4))
   var world_p=placement*p;p.y=model.surface_height(world_p.x,world_p.z)-placement.origin.y+.04
   if absf(p.y)>.9:continue
   mound(p,Vector3(1.7,.055,1.65),Color("81925d"))
   for i in 5:
    var offset=Vector3(rng.randf_range(-.8,.8),0,rng.randf_range(-.7,.7))
    mound(p+offset,Vector3(.83,.62,.75)*rng.randf_range(.7,1.25),Color("688453"))
   for i in 17:
    var angle=rng.randf()*TAU;var q=p+Vector3(cos(angle),0,sin(angle))*rng.randf_range(.5,1.6)
    var height=rng.randf_range(.28,.75)
    triangle(q+Vector3(-.12,0,0),q+Vector3(.12,0,0),q+Vector3(.09,height,.1),Vector3.BACK,Color("819b61"))
    triangle(q+Vector3(0,0,-.12),q+Vector3(0,0,.12),q+Vector3(-.09,height*.8,.1),Vector3.RIGHT,Color("91a86e"))
   for i in 3:
    var q=p+Vector3(rng.randf_range(-1,1),.15,rng.randf_range(-1,1))
    mound(q,Vector3(.13,.24,.13),Color("c5b1b4") if i%2 else Color("e4d9ae"))
 for i in 3:
  var p=Vector3((i%2-.5)*.22,0,half+.4+i*.65);var wp=placement*p
  p.y=model.surface_height(wp.x,wp.z)-placement.origin.y+.055
  if absf(p.y)>.9:continue
  block(p,Vector3(2.25,.13,.57),Color("aaad8f"),.06,Basis(Vector3.UP,(i-1)*.035))
 return finish()

func meadow(kind:String,model,placement:Transform3D)->ArrayMesh:
 begin(510)
 var half=5.5 if kind=="tower" else 8.9
 var extent=half+4.0;var divisions=18;var vertices=[];var colors=[]
 for z in divisions+1:
  for x in divisions+1:
   var p=Vector3(lerpf(-extent,extent,float(x)/divisions),0,lerpf(-extent,extent,float(z)/divisions))
   var wp=placement*p;p.y=model.surface_height(wp.x,wp.z)-placement.origin.y+.026
   var outside=Vector2(maxf(0,absf(p.x)-half),maxf(0,absf(p.z)-half)).length()
   var fade=1.0-smoothstep(1.3,3.8,outside)
   # Fade on steep ground as well; raised native terrain remains legible.
   fade*=1.0-smoothstep(.5,1.4,absf(p.y))
   var tone=(sin(p.x*.45)+sin(p.z*.53+p.x*.2))*.25+.5
   var color=Color("7d9366").lerp(Color("9caa79"),tone);color.a=fade*.92
   vertices.append(p);colors.append(color)
 for z in divisions:
  for x in divisions:
   var a=z*(divisions+1)+x;var b=a+1;var c=a+divisions+1;var d=c+1
   for index in [a,b,c,b,d,c]:
    tool.set_normal(Vector3.UP);tool.set_color(colors[index]);tool.add_vertex(vertices[index])
 return finish()
