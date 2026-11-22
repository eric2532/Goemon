extends RefCounted
## One source-10301 workshop; the saved blocks retain the access lane to both room-1071 doors.
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const MARKERS={Vector2i(-38,26):90,Vector2i(-35,24):270}
const ORIGIN=Vector3(-229.5,0,150)
const BODY=AABB(Vector3(-8.25,0,-10.5),Vector3(16.5,8.0,21.0))
static var mesh:Mesh

static func active(model)->bool:
 for anchor in MARKERS:
  var item:Dictionary=model.props.get(anchor,{})
  if item.get("kind","")!="falan_townhouse" or item.get("rotation",-1)!=MARKERS[anchor] or not is_equal_approx(float(item.get("scale",0)),.92):return false
  if model.scenery_heights.get(anchor,0)!=0:return false
 return true

static func prepare()->Mesh:
 if mesh!=null:return mesh
 var skin=Houses.SourceMesh.new([],Houses.Atlas,.045);skin.tiles=Houses.Data.TILES
 for box in [BODY]:
  skin.part="plaster";skin.box(box)
  skin.part="10003_base";var base=box;base.size.y=1.1;skin.box(base)
  skin.part="10003_wood"
  for y in [1.1,4.1,7.7]:
   var band=box;band.position+=Vector3(-.035,y,-.035);band.size=Vector3(box.size.x+.07,.18,box.size.z+.07);skin.box(band)
  for x in [box.position.x,box.end.x]:
   for z in [box.position.z,box.end.z]:skin.box(AABB(Vector3(x-.12,0,z-.12),Vector3(.24,8,.24)))
  for side in [-1,1]:
   var z=box.get_center().z+side*(box.size.z*.5+.04)
   for x in [-.28,.28]:
    for y in [2.6,6.0]:Houses.Village.detail(skin,Vector3(box.get_center().x+x*box.size.x,y,z),Vector3.RIGHT*side,"workshop_window",2.8)
 # A continuous roof joins the blocks above the existing walkable lane.
 roof(skin,Vector3(0,8.1,0),9.3,11.3,6.2)
 for side in [-1,1]:
  var z=side*8.0
  skin.part="10003_wood"
  for offset in [-2.0,2.0]:skin.box(AABB(Vector3(10.0,0,z+offset-.17),Vector3(.34,6.8,.34)))
  skin.box(AABB(Vector3(10.0,5.4,z-2.15),Vector3(.4,.32,4.3)))
  skin.part="trim"
  for offset in [-2.0,2.0]:
   for y in [.15,.65,5.1]:skin.box(AABB(Vector3(9.87,y,z+offset-.3),Vector3(.6,.18,.6)))
  skin.part="10003_wood"
  for i in 10:
   var a=PI*float(i)/10;var b=PI*float(i+1)/10
   var lo_a=Vector3(10.37,3.5+sin(a)*1.6,z+cos(a)*1.6)
   var hi_a=Vector3(10.37,3.5+sin(a)*1.85,z+cos(a)*1.85)
   var lo_b=Vector3(10.37,3.5+sin(b)*1.6,z+cos(b)*1.6)
   var hi_b=Vector3(10.37,3.5+sin(b)*1.85,z+cos(b)*1.85)
   skin.quad(lo_a,hi_a,hi_b,lo_b)
  skin.part="trim";skin.box(AABB(Vector3(8.32,6.5,z-2.15),Vector3(.32,2.2,4.3)))
  Houses.Village.detail(skin,Vector3(8.68,7.6,z),Vector3.FORWARD,"smith_sign" if side>0 else "workshop_trade_sign",4.2)
  skin.part="blue_roof"
  skin.quad(Vector3(10.4,5.5,z+2.2),Vector3(8.1,6.9,z+2.2),Vector3(8.1,6.9,z-2.2),Vector3(10.4,5.5,z-2.2))
 for z in [-9.0,9.0]:
  Houses.Village.detail(skin,Vector3(8.3,2.4,z),Vector3.FORWARD,"door",4.6)
 for z in [-3.4,3.4]:
  Houses.Village.detail(skin,Vector3(8.31,3.2,z),Vector3.FORWARD,"workshop_window",4.5)
 # Source roof dormers are separate solid cheeks and pitched slate caps.
 for z in [-6.2,6.2]:
  for side in [-1,1]:
   var front=side*5.9;var back=side*3.7
   skin.part="plaster"
   skin.box(AABB(Vector3(minf(front,back),9.9,z-1.0),Vector3(absf(front-back),1.5,2.0)))
   Houses.Village.detail(skin,Vector3(front+side*.035,10.7,z),Vector3.FORWARD*side,"workshop_window",1.9)
   skin.part="blue_roof"
   up_quad(skin,Vector3(front,11.3,z-1.2),Vector3(back,11.3,z-1.2),Vector3(back,12.5,z),Vector3(front,12.5,z))
   up_quad(skin,Vector3(front,12.5,z),Vector3(back,12.5,z),Vector3(back,11.3,z+1.2),Vector3(front,11.3,z+1.2))
 chimney(skin,Vector3(-6.5,7.5,-7.8))
 mesh=skin.finish()
 var paint=mesh.surface_get_material(0).duplicate();paint.set_shader_parameter("original_palette",false);mesh.surface_set_material(0,paint)
 mesh=Houses.surface_mesh(mesh)
 mesh=Proportions.fitted(mesh,"special_10301")
 return mesh

static func roof(skin,p:Vector3,width:float,depth:float,height:float,paint:String="blue_roof"):
 skin.part=paint
 skin.quad(p+Vector3(-width,0,depth),p+Vector3(-width,0,-depth),p+Vector3(0,height,-depth),p+Vector3(0,height,depth))
 skin.quad(p+Vector3(0,height,depth),p+Vector3(0,height,-depth),p+Vector3(width,0,-depth),p+Vector3(width,0,depth))
 skin.part="plaster"
 for side in [-1,1]:
  var a=p+Vector3(-width,0,side*depth);var b=p+Vector3(0,height,side*depth);var c=p+Vector3(width,0,side*depth)
  if side>0:skin.quad(a,b,c,c)
  else:skin.quad(c,b,a,a)

static func chimney(skin,p:Vector3):
 skin.part="stone"
 for i in 12:
  var a=float(i)*TAU/12;var b=float(i+1)*TAU/12
  var lo=p+Vector3(cos(a)*1.3,0,sin(a)*1.3);var next=p+Vector3(cos(b)*1.3,0,sin(b)*1.3)
  skin.quad(next,next+Vector3.UP*7.5,lo+Vector3.UP*7.5,lo)
 skin.part="10003_wood"
 for x in [-1,1]:
  for z in [-1,1]:skin.box(AABB(p+Vector3(x*.9-.15,7.5,z*.9-.15),Vector3(.3,1.2,.3)))
 # The original chimney has a red cap distinct from the main blue roof.
 roof(skin,p+Vector3.UP*8.6,1.7,1.7,1.0,"10007_roof")

static func build(parent:Node3D,model):
 var node=MeshInstance3D.new();node.name="RecoveredFalanWorkshop10301";node.mesh=prepare()
 node.position=ORIGIN+Vector3.UP*model.surface_height(ORIGIN.x,ORIGIN.z)
 node.set_meta("original_graphic",10301);parent.add_child(node)

static func bounds(anchor:Vector2i)->AABB:
 return AABB(ORIGIN+BODY.position-Vector3(anchor.x*6,0,anchor.y*6),Vector3(BODY.size.x,Proportions.height("special_10301",14.3),BODY.size.z))

static func up_quad(skin,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 if (c-a).cross(b-a).y<0:skin.quad(d,c,b,a)
 else:skin.quad(a,b,c,d)
