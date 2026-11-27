extends RefCounted
## Source 10075: solid purple-roof shop, with native sign and glazing panels.
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
const Workshop=preload("res://scripts/forest/forest_falan_workshop.gd")
const ANCHOR=Vector2i(-28,28)
const ORIGIN=Vector3(-168,0,165)
const BODY=AABB(Vector3(-10,0,-10),Vector3(20,14,20))
static var mesh:Mesh

static func active(model)->bool:
 var item:Dictionary=model.props.get(ANCHOR,{})
 return item.get("kind","")=="falan_shop" and item.get("rotation",-1)==0 and is_equal_approx(float(item.get("scale",0)),.92) and model.scenery_heights.get(ANCHOR,0)==0

static func bounds()->AABB:
 var size_=BODY.size;size_.y=Proportions.height("special_10075",size_.y)
 return AABB(ORIGIN+BODY.position-Vector3(ANCHOR.x*6,0,ANCHOR.y*6),size_)

static func prepare()->Mesh:
 if mesh!=null:return mesh
 var skin=Houses.SourceMesh.new([],Houses.Atlas,.045);skin.tiles=Houses.Data.TILES
 skin.part="stone";skin.box(AABB(Vector3(-7,0,-7),Vector3(14,6.2,14)))
 skin.part="10003_base";skin.box(AABB(Vector3(-7.05,0,-7.05),Vector3(14.1,1.0,14.1)))
 main_roof(skin)
 for x in [-7.5,7.5]:
  for z in [-7.5,7.5]:tower(skin,Vector3(x,0,z))
 for x in [-4.2,0,4.2]:
  var p=Vector3(x,11.6 if x==0 else 11.1,-1.5 if x==0 else 2.6)
  lathe(skin,p,[Vector2(.42,0),Vector2(.42,1.2),Vector2(.72,1.25),Vector2(.85,1.55),Vector2(.42,1.8),Vector2(.2,2.7),Vector2(0,2.9)],"stone")
  for level in [.25,.75,1.15]:lathe(skin,p+Vector3.UP*level,[Vector2(.53,0),Vector2(.53,.12)],"trim")
 skin.part="10003_wood"
 for x in [-2.2,2.2]:
  skin.box(AABB(Vector3(x-.18,0,7.1),Vector3(.36,6.4,.45)))
  skin.part="trim";skin.box(AABB(Vector3(x-.35,.15,7.0),Vector3(.7,.4,.7)));skin.part="10003_wood"
 Houses.Village.detail(skin,Vector3(0,3.0,7.05),Vector3.RIGHT,"door",5.6)
 # The native sign sits in a projecting curved gable above the doorway.
 var contour=[Vector2(-3.3,6.0),Vector2(-3.0,6.5),Vector2(-2.5,7.1),Vector2(-1.6,8.1),Vector2(0,9.1),Vector2(1.6,8.1),Vector2(2.5,7.1),Vector2(3.0,6.5),Vector2(3.3,6.0)]
 skin.part="magic_roof"
 for i in contour.size()-1:
  var a:Vector2=contour[i];var b:Vector2=contour[i+1]
  skin.quad(Vector3(a.x,a.y,8.8),Vector3(a.x,a.y,6.1),Vector3(b.x,b.y,6.1),Vector3(b.x,b.y,8.8))
 skin.part="stone"
 for i in contour.size()-1:
  var a:Vector2=contour[i];var b:Vector2=contour[i+1]
  skin.quad(Vector3(a.x,6.0,8.82),Vector3(a.x,a.y,8.82),Vector3(b.x,b.y,8.82),Vector3(b.x,6.0,8.82))
 # The backing follows the native arched plaque instead of hiding the roof behind a rectangle.
 skin.part="10003_wood"
 var outline=[Vector2(-2.05,5.85),Vector2(-2.05,7.9),Vector2(-1.8,8.8),Vector2(-.8,9.0),Vector2(.6,8.65),Vector2(2.05,7.6),Vector2(2.05,5.85)]
 for i in outline.size():
  var a:Vector2=outline[i];var b:Vector2=outline[(i+1)%outline.size()]
  skin.quad(Vector3(a.x,a.y,8.82),Vector3(a.x,a.y,8.70),Vector3(b.x,b.y,8.70),Vector3(b.x,b.y,8.82))
  skin.quad(Vector3(0,7.3,8.82),Vector3(a.x,a.y,8.82),Vector3(b.x,b.y,8.82),Vector3(0,7.3,8.82))
  skin.quad(Vector3(0,7.3,8.70),Vector3(b.x,b.y,8.70),Vector3(a.x,a.y,8.70),Vector3(0,7.3,8.70))
 Houses.Village.detail(skin,Vector3(0,7.6,8.86),Vector3.RIGHT,"magic_sign",4.9)
 for i in 5:
  skin.part="stone";skin.box(AABB(Vector3(-2.15,i*.25,10.8-i*.7),Vector3(4.3,.25,.75)))
 for side in [-1,1]:
  for z in [-3.2,3.2]:
   for y in [1.6,4.6]:Houses.native_panel(skin,Vector3(side*7.08,y,z),Vector3.FORWARD*side,Vector2(5.4,3.52),"magic_side_window")
   skin.part="10003_wood"
   for edge in [-1,1]:skin.box(AABB(Vector3(side*7.06-.11,.45,z+edge*1.3-.10),Vector3(.22,5.5,.20)))
  skin.part="10003_wood"
  for y in [.7,5.9]:skin.box(AABB(Vector3(side*7.06-.11,y,-6.8),Vector3(.22,.22,13.6)))
 for x in [-3.2,3.2]:
  for y in [1.6,4.6]:Houses.native_panel(skin,Vector3(x,y,-7.08),Vector3.LEFT,Vector2(5.4,3.52),"magic_side_window")
 mesh=skin.finish()
 var paint=mesh.surface_get_material(0).duplicate();paint.set_shader_parameter("original_palette",false);mesh.surface_set_material(0,paint)
 mesh=Houses.surface_mesh(mesh)
 mesh=Proportions.fitted(mesh,"special_10075")
 return mesh

static func lathe(skin,p:Vector3,profile:Array,paint:String):
 skin.part=paint
 for k in profile.size()-1:
  var a:Vector2=profile[k];var b:Vector2=profile[k+1]
  for i in 16:
   var t=float(i)*TAU/16;var u=float(i+1)*TAU/16
   var p0=p+Vector3(cos(t)*a.x,a.y,sin(t)*a.x)
   var p1=p+Vector3(cos(t)*b.x,b.y,sin(t)*b.x)
   var p2=p+Vector3(cos(u)*b.x,b.y,sin(u)*b.x)
   var p3=p+Vector3(cos(u)*a.x,a.y,sin(u)*a.x)
   skin.quad(p3,p2,p1,p0)

static func tower(skin,p:Vector3):
 lathe(skin,p,[Vector2(2.0,0),Vector2(2.0,6.7)],"magic_stone")
 for y in [.2,1.6,4.5,6.4]:lathe(skin,p+Vector3.UP*y,[Vector2(2.12,0),Vector2(2.12,.22)],"trim")
 for normal:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
  Houses.Village.detail(skin,p+normal*2.03+Vector3.UP*1.0,Vector3.UP.cross(normal),"magic_window",2.6)
  skin.part="trim"
  var tangent=Vector3.UP.cross(normal)
  for side in [-1,1]:
   var foot=p+normal*1.90+tangent*side*.68
   lathe(skin,foot,[Vector2(.12,.25),Vector2(.12,1.9)],"trim")
 lathe(skin,p,[Vector2(2.35,6.7),Vector2(2.25,7.4),Vector2(1.8,8.4),Vector2(1.1,9.5),Vector2(.65,10.1)],"magic_roof")
 lathe(skin,p,[Vector2(.8,10.1),Vector2(.9,10.45),Vector2(.45,11.0),Vector2(.25,11.2)],"10007_roof")
 lathe(skin,p,[Vector2(.22,11.0),Vector2(.18,12.1),Vector2(0,12.5)],"trim")

static func build(parent:Node3D,model):
 var node=MeshInstance3D.new();node.name="RecoveredFalanMagicShop10075";node.mesh=prepare()
 node.position=ORIGIN+Vector3.UP*model.surface_height(ORIGIN.x,ORIGIN.z)
 node.set_meta("original_graphic",10075);parent.add_child(node)

static func main_roof(skin):
 # The native roof has a long rounded ridge; a central pyramid loses its silhouette.
 var profile=[Vector3(8.2,6.1,8.2),Vector3(8.0,6.5,7.5),Vector3(7.4,7.8,6.0),Vector3(6.7,9.5,4.2),Vector3(5.8,11.0,2.0),Vector3(5.2,11.8,.02)]
 var corners=[Vector2(-1,-.8),Vector2(-.8,-1),Vector2(.8,-1),Vector2(1,-.8),Vector2(1,.8),Vector2(.8,1),Vector2(-.8,1),Vector2(-1,.8)]
 skin.part="magic_roof"
 for i in profile.size()-1:
  var a:Vector3=profile[i];var b:Vector3=profile[i+1]
  for j in corners.size():
   var p:Vector2=corners[j];var q:Vector2=corners[(j+1)%corners.size()]
   skin.quad(Vector3(q.x*a.x,a.y,q.y*a.z),Vector3(q.x*b.x,b.y,q.y*b.z),Vector3(p.x*b.x,b.y,p.y*b.z),Vector3(p.x*a.x,a.y,p.y*a.z))
 skin.quad(Vector3(-5.2,11.8,.02),Vector3(-5.2,11.8,-.02),Vector3(5.2,11.8,-.02),Vector3(5.2,11.8,.02))
