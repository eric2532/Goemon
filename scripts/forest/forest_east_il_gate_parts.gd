extends RefCounted
## PRIVATE original11077/11078arched leaves/posts. Pure immutable meshes; no collider.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const ROOT="res://assets/maps/falan/east_region/il_gate_parts/"
const EYE=Vector3(-.0625,.045,.0625)
static var catalog={}
static var meshes={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func owns(serial:int)->bool:return serial in[11077,11078]
static func point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 return Base.point(pixel,height/Base.OWNER_Y_SCALE,g)*Vector3(1.,Base.OWNER_Y_SCALE,1.)
static func projected(pixel:Vector2,g:Dictionary,slope:float,offset:float)->Vector3:
 var p=Base.projected(pixel,g,slope,offset);p.y*=Base.OWNER_Y_SCALE;return p
static func native(g:Dictionary,paint:Texture2D):
 return Base.PreparedSkin.new([Rect2(0,0,g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],paint,.045)
static func tiled(paint:Texture2D):
 var skin=Base.PreparedSkin.new([],paint,.045);skin.tiles={"stone":Vector2.ZERO};return skin
static func solid_quad(skin,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 var n=(c-a).cross(b-a).normalized();var tangent=Vector3(n.z,0,-n.x).normalized()
 if tangent.length_squared()<.01:tangent=Vector3.RIGHT
 for p:Vector3 in[a,b,c,a,c,d]:
  skin.surface.set_normal(n);skin.surface.set_uv(Vector2(p.x,p.z)/5.76 if absf(n.y)>.6 else Vector2(p.dot(tangent),-p.y)/5.76);skin.surface.set_uv2(Vector2.ZERO);skin.surface.add_vertex(p)
static func mesh(serial:int)->Mesh:
 assert(owns(serial))
 if meshes.has(serial):return meshes[serial]
 Furniture.Parts.prepare_primitives()
 var spec:Dictionary=data().graphics[str(serial)];var g={"origin":spec.origin,"rect":[0,0,spec.size[0],spec.size[1]],"footprint":spec.footprint}
 var face=native(g,load(ROOT+str(serial)+"-leaf-front.png"));var wood=native(g,load(ROOT+str(serial)+"-leaf-back.png"));var reverse=native(g,load(ROOT+str(serial)+"-leaf-back.png"));var sides=tiled(load(ROOT+str(serial)+"-wood.png"));var post=tiled(load(ROOT+str(serial)+"-stone.png"));var stone_front=native(g,load(ROOT+str(serial)+"-post-front.png"))
 var pixels=PackedVector2Array();var polygon=[]
 for p:Array in spec.leaf_polygon:
  pixels.append(Vector2(p[0],p[1]));polygon.append(projected(Vector2(p[0],p[1]),g,spec.leaf_plane_slope,spec.leaf_plane_offset))
 var indices=Geometry2D.triangulate_polygon(pixels);assert(not indices.is_empty(),"Native arched gate outline must triangulate")
 var normal=(polygon[1]-polygon[0]).cross(polygon[2]-polygon[0]).normalized()
 if normal.dot(EYE)<0.:normal=-normal
 var back=[]
 for p:Vector3 in polygon:back.append(p-normal*float(spec.leaf_thickness))
 for i in range(0,indices.size(),3):
  var order=[indices[i],indices[i+1],indices[i+2]]
  if (polygon[order[2]]-polygon[order[0]]).cross(polygon[order[1]]-polygon[order[0]]).dot(normal)<0.:order.reverse()
  for at:int in order:
   wood.projected_vertex(polygon[at],normal,polygon[at]);face.projected_vertex(polygon[at]+normal*.012,normal,polygon[at])
  order.reverse()
  for at:int in order:reverse.projected_vertex(back[at],-normal,polygon[at])
 for i in polygon.size():
  var j=(i+1)%polygon.size();solid_quad(sides,polygon[j],polygon[i],back[i],back[j])
 var left=point(Base.v(spec.post_feet[0]),0.,g);var near=point(Base.v(spec.post_feet[1]),0.,g);var right=point(Base.v(spec.post_feet[2]),0.,g);var ring=[near,left,left+right-near,right];var body_height=float(spec.post_body_top_pixels)*.045;var cap_height=float(spec.post_height_pixels)*.045;var center=(left+right)*.5
 var caps=Furniture.tool()
 for i in 4:
  var j=(i+1)%4;var a:Vector3=ring[i];var b:Vector3=ring[j];solid_quad(post,a,b,b+Vector3.UP*body_height,a+Vector3.UP*body_height)
  var n=(b+Vector3.UP*body_height-a).cross(b-a).normalized()
  if n.dot(EYE)>0.:
   for p:Vector3 in[a,b,b+Vector3.UP*body_height,a,b+Vector3.UP*body_height,a+Vector3.UP*body_height]:stone_front.projected_vertex(p+n*.012,n,p)
  var wide_a=center+(a-center)*1.07;var wide_b=center+(b-center)*1.07
  Furniture.Shapes.quad(caps,wide_a+Vector3.UP*body_height,wide_b+Vector3.UP*body_height,wide_b+Vector3.UP*cap_height,wide_a+Vector3.UP*cap_height)
  Furniture.Shapes.quad(caps,wide_a,wide_b,wide_b+Vector3.UP*.36,wide_a+Vector3.UP*.36)
  # Rear corner brick rhythm repeats the observed exposed blocks, with no door.
  if n.dot(EYE)<0.:
   for level in[1.0,2.1,3.25]:Furniture.Shapes.quad(caps,a+n*.015+Vector3.UP*level,a.lerp(b,.28)+n*.015+Vector3.UP*level,a.lerp(b,.28)+n*.015+Vector3.UP*(level+.22),a+n*.015+Vector3.UP*(level+.22))
 var top=[]
 for p:Vector3 in ring:top.append(center+(p-center)*1.07+Vector3.UP*cap_height)
 Furniture.Shapes.quad(caps,top[0],top[1],top[2],top[3])
 for index in[0,1,2,0,2,3]:stone_front.projected_vertex(top[index]+Vector3.UP*.012,Vector3.UP,top[index])
 var metal=Furniture.tool();var rim=tiled(load(ROOT+str(serial)+"-wood.png"));var shift=float(spec.shift)
 for level in[42.,82.,117.]:
  var a=projected(Vector2(6.+shift,level+24.),g,spec.leaf_plane_slope,spec.leaf_plane_offset);var b=projected(Vector2(49.+shift,level),g,spec.leaf_plane_slope,spec.leaf_plane_offset)
  for depth in[.035,-float(spec.leaf_thickness)-.035]:
   Base.Harbor.Parts.rod(metal,a+normal*depth,b+normal*depth,.055)
 # The arched rim is a real reused timber rod, not a frame stretched onto a box.
 for i in spec.arch.size()-1:
  var a=projected(Base.v(spec.arch[i]),g,spec.leaf_plane_slope,spec.leaf_plane_offset);var b=projected(Base.v(spec.arch[i+1]),g,spec.leaf_plane_slope,spec.leaf_plane_offset);Base.rod(rim,a+normal*.025,b+normal*.025,.075,"stone")
 var parts=[wood.finish(),face.finish(),reverse.finish(),sides.finish(),post.finish(),stone_front.finish(),Furniture.finish([caps,metal],[Fort.material(Color("95613b"),false),Fort.material(Color("343f3a"),false)]),rim.finish()]
 var result=Base.combine(parts);result.set_meta("east_il_gate_part",serial);result.set_meta("source_origin",spec.origin);result.set_meta("source_footprint",spec.footprint);result.set_meta("height_frame","original-owner");result.set_meta("inferred_reverse",true);meshes[serial]=result;return result
