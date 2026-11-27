extends RefCounted
## Graphic11268: source-camera paint on observed faces, native part paint around hidden sides.
const FRONT_PATH="res://assets/maps/falan/il_chief/front.png"
const Tiles=preload("res://assets/maps/falan/il_chief/surfaces.gd")
const Atlas=preload("res://assets/maps/falan/il_chief/surfaces.png")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Round=preload("res://scripts/forest/forest_coastal_buildings.gd")
const VERTICAL=sqrt(2.0*(32.0/3.0*32.0/3.0-64.0))
const VILLAGE_HEIGHT=.045*VERTICAL
const CENTER=Vector2(145,380)
const OFFSET=Vector3(1.27,0,1.27)
const VIEW=Vector3(-1,1.603567,1)
static var cached:Mesh

static func octagon(rx:float,rz:float,cut:float,y:float)->Array[Vector3]:
 var result:Array[Vector3]=[]
 for p in [Vector2(-rx,-rz+cut),Vector2(-rx,rz-cut),Vector2(-rx+cut,rz),Vector2(rx-cut,rz),Vector2(rx,rz-cut),Vector2(rx,-rz+cut),Vector2(rx-cut,-rz),Vector2(-rx+cut,-rz)]:
  result.append(OFFSET+Vector3(p.x,y,p.y))
 return result

static func quad(base,front,a:Vector3,b:Vector3,c:Vector3,d:Vector3,paint:String,observed:bool=true):
 base.part=paint;base.quad(a,b,c,d)
 var normal=(c-a).cross(b-a).normalized()
 if observed and normal.dot(VIEW)>.08:
  # Native front paint stays on the photographed face; every solid has a separate complete tiled backing.
  var lift=normal*.025
  front.quad(a+lift,b+lift,c+lift,d+lift)

static func ring(base,front,lower:Array[Vector3],upper:Array[Vector3],paint:String,observed:bool=true):
 for i in lower.size():quad(base,front,lower[i],upper[i],upper[(i+1)%upper.size()],lower[(i+1)%lower.size()],paint,observed)

static func roof_point(angle:float,radius:float,y:float)->Vector3:
 var x=cos(angle)*radius;var z=sin(angle)*radius
 # The source roof is narrower across the screen than along the visible depth axis.
 var sum=(x+z)*.83;var depth=z-x
 return OFFSET+Vector3((sum-depth)*.5,y,(sum+depth)*.5)

static func roof(base,front,profile:Array,sectors:int,phase:float):
 for level in profile.size()-1:
  var low:Vector2=profile[level];var high:Vector2=profile[level+1]
  for i in sectors:
   var a=-i*TAU/sectors+phase;var b=-(i+1)*TAU/sectors+phase
   var uneven_a=(sin(i*13.17)+sin(i*7.11))*.10 if level==0 else 0.0
   var uneven_b=(sin((i+1)*13.17)+sin((i+1)*7.11))*.10 if level==0 else 0.0
   var p=roof_point(a,low.x+uneven_a,low.y+uneven_a)
   var q=roof_point(b,low.x+uneven_b,low.y+uneven_b)
   var u=roof_point(a,high.x,high.y)
   var v=roof_point(b,high.x,high.y)
   quad(base,front,p,u,v,q,"thatch")
 # Closed, dark eave thickness follows the roof, rather than a flat cone edge.
 for i in sectors:
  var a=-i*TAU/sectors+phase;var b=-(i+1)*TAU/sectors+phase
  var low:Vector2=profile[0]
  var p=roof_point(a,low.x,low.y)
  var q=roof_point(b,low.x,low.y)
  quad(base,front,p-Vector3.UP*.38,p,q,q-Vector3.UP*.38,"dark_thatch",false)
  base.part="dark_thatch"
  base.quad(OFFSET+Vector3.UP*(low.y-.38),p-Vector3.UP*.38,q-Vector3.UP*.38,OFFSET+Vector3.UP*(low.y-.38))

static func stone_blocks(base,front):
 for course in 2:
  var low=octagon(9.7-course*.20,10.3-course*.20,4.1,course*3.975)
  var high=octagon(9.7-course*.20,10.3-course*.20,4.1,(course+1)*3.975)
  ring(base,front,low,high,"stone")
  for side in 8:
   var a:Vector3=low[side];var b:Vector3=low[(side+1)%8]
   var c:Vector3=high[side];var d:Vector3=high[(side+1)%8]
   var count_=maxi(2,roundi(a.distance_to(b)/2.3))
   var offset=.45 if (course+side)%2 else 0.0
   for block in count_+1:
    var start=maxf(0.0,(float(block)-offset)/count_);var end=minf(1.0,(float(block+1)-offset)/count_)
    if end-start<.025:continue
    var p=a.lerp(b,start);var q=a.lerp(b,end);var u=c.lerp(d,start);var v=c.lerp(d,end)
    var outward=(q-p).cross(Vector3.UP).normalized();var tangent=(q-p).normalized()
    var relief=.11+float((side+block+course)%3)*.045
    var inset=.08
    var pp=p+tangent*inset+Vector3.UP*inset+outward*relief
    var qq=q-tangent*inset+Vector3.UP*inset+outward*relief
    var uu=u+tangent*inset-Vector3.UP*inset+outward*relief
    var vv=v-tangent*inset-Vector3.UP*inset+outward*relief
    quad(base,front,pp,uu,vv,qq,"stone")
    for face in [[p,u,uu,pp],[q,qq,vv,v],[u,v,vv,uu],[p,pp,qq,q]]:
     quad(base,front,face[0],face[1],face[2],face[3],"stone")
 ring(base,front,octagon(9.3,9.9,4.1,7.95),octagon(9.15,9.75,4.1,9.15),"stone_cap")
 var cap=octagon(9.15,9.75,4.1,9.15)
 for i in 8:quad(base,front,OFFSET+Vector3.UP*9.15,cap[(i+1)%8],cap[i],OFFSET+Vector3.UP*9.15,"stone_cap")

static func source_point(pixel:Vector2,normal:Vector3,plane:float)->Vector3:
 var sum=(pixel.x-CENTER.x)/(32.0/3.0)
 var x=(plane-normal.z*sum)/(normal.x-normal.z);var z=sum-x
 return Vector3(x,(CENTER.y+(z-x)*8.0-pixel.y)/VERTICAL,z)

static func relief(base,front,corners:Array,normal:Vector3,plane:float,width:float):
 # The photographed door/window frames receive real thickness at their exact source-camera positions.
 for i in corners.size():
  var a=source_point(corners[i],normal,plane)+normal*.12
  var b=source_point(corners[(i+1)%corners.size()],normal,plane)+normal*.12
  base.part="timber";Parts.bar(base,a,b,width)
  var tangent=(b-a).normalized();var across=normal.cross(tangent)*width*.5
  front.quad(a-across,a+across,b+across,b-across)

static func prepare()->Mesh:
 if cached!=null:return cached
 var front=Source.new([Rect2(0,0,344,522),CENTER],load(FRONT_PATH),1.0/VERTICAL)
 front.reflection_threshold=INF
 var base=Source.new([],Atlas,1.0/VERTICAL);base.tiles=Tiles.TILES
 base.pitches={"plaster":2.2,"timber":1.1,"stone":2.8,"stone_cap":2.6,"thatch":2.4,"dark_thatch":2.4}
 stone_blocks(base,front)
 var lower=octagon(8.4,8.8,4.9,9.12);var upper=octagon(8.4,8.8,4.9,19.25)
 ring(base,front,lower,upper,"plaster")
 for y in [9.2,10.2,18.9]:ring(base,front,octagon(8.53,8.93,4.9,y),octagon(8.53,8.93,4.9,y+.26),"timber")
 for i in 8:
  var a:Vector3=lower[i];var b:Vector3=upper[i]
  base.part="timber";Parts.bar(base,a,b,.30)
  # Rear windows repeat the visible construction; there are no extra doors.
  var midpoint=(lower[i]+lower[(i+1)%8])*.5
  var normal=(lower[(i+1)%8]-lower[i]).cross(Vector3.UP).normalized()
  if normal.dot(VIEW)<=.08:Parts.window(base,midpoint+Vector3.UP*4.6+normal*.12,normal,4.4,"window")
 roof(base,front,[Vector2(10.95,18.75),Vector2(10.55,19.2),Vector2(8.8,20.4),Vector2(6.3,22.3),Vector2(3.3,24.0)],32,PI/16)
 for i in 8:
  var n=Vector3(cos(-i*TAU/8),0,sin(-i*TAU/8))
  base.part="timber"
  Parts.bar(base,OFFSET+n*3.05+Vector3.UP*22.2,OFFSET+n*3.55+Vector3.UP*24.0,.27)
  Parts.bar(base,OFFSET+n*8.0+Vector3.UP*17.7,roof_point(-i*TAU/8,10.55,18.6),.23)
 var drum_low=octagon(3.15,3.15,1.85,23.85);var drum_high=octagon(3.15,3.15,1.85,29.2)
 ring(base,front,drum_low,drum_high,"timber")
 for i in 8:
  var edge:Vector3=drum_low[(i+1)%8]-drum_low[i];var normal=edge.cross(Vector3.UP).normalized()
  base.part="timber";Parts.bar(base,drum_low[i],drum_high[i],.18)
  if normal.dot(VIEW)<=.08:Parts.window(base,(drum_low[i]+drum_low[(i+1)%8])*.5+Vector3.UP*2.65+normal*.10,normal,3.1,"upper_window")
 roof(base,front,[Vector2(4.55,28.7),Vector2(4.25,29.3),Vector2(3.2,30.8),Vector2(1.55,32.2),Vector2(.35,33.0)],24,PI/12)
 relief(base,front,[Vector2(73,288),Vector2(113,315),Vector2(113,388),Vector2(73,361)],Vector3.LEFT,8.4-OFFSET.x,.28)
 var diagonal=Vector3(-1,0,1).normalized()
 relief(base,front,[Vector2(154,321),Vector2(198,321),Vector2(198,369),Vector2(154,369)],diagonal,12.3/sqrt(2.0),.17)
 # The small hanging sign keeps its source art and receives a wood bracket, cap and shallow body.
 var sign=source_point(Vector2(285,250),Vector3.BACK,10.2)
 base.part="timber";Parts.bar(base,sign+Vector3.UP*1.5,sign+Vector3.UP*3.0,.16)
 Parts.bar(base,sign+Vector3.UP*2.95,sign+Vector3.UP*2.95-Vector3.RIGHT*2.7,.18)
 base.box(AABB(sign+Vector3(-1.65,-1.2,-.22),Vector3(3.3,2.4,.44)))
 Round.detail(base,sign+Vector3.BACK*.24,Vector3.RIGHT,"sign",4.2)
 Round.detail(base,sign-Vector3.BACK*.24,Vector3.LEFT,"sign",4.2)
 base.part="timber";Parts.bar(base,OFFSET+Vector3.UP*32.7,OFFSET+Vector3.UP*36.9,.12)
 var result=ArrayMesh.new()
 for mesh:Mesh in [base.finish(),front.finish()]:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,mesh.surface_get_material(0))
 cached=result
 return result

static func build(root:Node3D,p:Vector3,source_frame:bool=false)->MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=prepare();node.position=p
 node.scale.y=1.0 if source_frame else VILLAGE_HEIGHT
 node.name="BlueCGVillageBuilding_11268";node.set_meta("source_graphic",11268)
 node.set_meta("source_inferred","Hidden slopes/walls, block and thatch depth, rear window rhythm, thin vane thickness; no new doors or routes.")
 root.add_child(node)
 var vane=Sprite3D.new();vane.name="SourceRooster11268"
 vane.texture=preload("res://assets/maps/falan/il_laruka/chief-rooster.png")
 vane.pixel_size=1.0/VERTICAL
 vane.position=OFFSET+Vector3(.72,(380.0-29.0)/VERTICAL,.72)
 vane.rotation.y=-PI*.25;vane.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
 vane.scale.x=VERTICAL/(sqrt(2.0)*32.0/3.0) if source_frame else VILLAGE_HEIGHT
 vane.double_sided=true;node.add_child(vane)
 return node
