extends RefCounted
## Native Komatei broken walls/decks; source map owns placement, walking and routes.
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/ruin_sections/"
const IDS=[1233270,1233271,1233272,1233273,1233274,1233275,1233279,1233280,1233281,1233282]
static var catalog:Dictionary={}
static var meshes:Dictionary={}

static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func source_point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var u=(pixel.x+float(g.origin[0]))/(32./3.)
 var v=(pixel.y+float(g.origin[1])+height/.045)/8.
 return Vector3((u-v)*.5,height,(u+v)*.5)

static func append_piece(shape:Mesh,pose:Transform3D,base,front,paint_top:bool=false,observed_normal:Vector3=Vector3.ZERO,paint_ends:bool=false,shade:float=1.):
 var arrays=shape.surface_get_arrays(0)
 for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
  var n:Vector3=(pose.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
  var tile=("floor" if paint_top else "cap") if n.y>.4 else "stone"
  var axis=Vector3.RIGHT if absf(n.z)>.5 else Vector3.BACK
  for j in 3:
   var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i+j]
   base.surface.set_normal(n);base.surface.set_color(Color(shade,shade,shade));base.surface.set_uv2(base.tiles[tile])
   base.surface.set_uv(Vector2(p.dot(axis),-p.y)/1.45 if absf(n.y)<.8 else Vector2(p.x,p.z)/1.45)
   base.surface.add_vertex(p)
   if observed_normal!=Vector3.ZERO and n.dot(observed_normal)>.9 or paint_ends and (n.x<-.1 or n.z>.1) or paint_top and n.y>.8:front.projected_vertex(p+n*.003,n,p)

static func contour(points:Array,axis:Vector3,plane:Vector3,g:Dictionary)->Array[Vector2]:
 var result:Array[Vector2]=[]
 for pixel:Array in points:
  var across=(float(pixel[0])+float(g.origin[0]))/(32./3.)
  var p=plane
  if absf(axis.x)>.5:p.x=across-p.z
  else:p.z=across-p.x
  var height=(-float(g.origin[1])+(p.z-p.x)*8-float(pixel[1]))*.045
  result.append(Vector2(p.dot(axis),height))
 result.sort_custom(func(a,b):return a.x<b.x)
 return result

static func at_height(profile:Array[Vector2],t:float)->float:
 if t<=profile[0].x:return profile[0].y
 for i in range(1,profile.size()):
  if t<=profile[i].x:return lerpf(profile[i-1].y,profile[i].y,inverse_lerp(profile[i-1].x,profile[i].x,t))
 return profile[-1].y

static func broken_blocks(rim:Array[Vector2])->Array[Vector2]:
 var result:Array[Vector2]=[]
 for i in rim.size():
  var p:Vector2=rim[i]
  if i>0:result.append(Vector2(p.x-(p.x-rim[i-1].x)*.32,p.y))
  result.append(p)
  if i+1<rim.size():result.append(Vector2(p.x+(rim[i+1].x-p.x)*.32,p.y))
 return result

static func wall_strip(base,front,axis:Vector3,plane:Vector3,rim:Array[Vector2],depth:float,windows:Array=[],floor_y:float=0.,observed:bool=true,paint_ends:bool=false):
 rim=broken_blocks(rim)
 var normal=axis.cross(Vector3.UP)
 var cuts:Array[float]=[]
 for p:Vector2 in rim:cuts.append(p.x)
 for window:Dictionary in windows:
  for i in 9:cuts.append(float(window.center)-float(window.width)*.5+float(window.width)*i/8.)
 cuts.sort();var unique:Array[float]=[]
 for t:float in cuts:
  if t<rim[0].x or t>rim[-1].x:continue
  if unique.is_empty() or t-unique[-1]>.001:unique.append(t)
 var pose=Transform3D(Basis(axis,Vector3.UP,normal),plane-normal*depth*.5)
 for i in unique.size()-1:
  var a=unique[i];var b=unique[i+1];var h0=at_height(rim,a);var h1=at_height(rim,b)
  var window:Dictionary={}
  for candidate:Dictionary in windows:
   if absf((a+b)*.5-float(candidate.center))<float(candidate.width)*.5:window=candidate;break
  var sections=[]
  if window.is_empty():sections.append(PackedVector2Array([Vector2(a,floor_y),Vector2(b,floor_y),Vector2(b,h1),Vector2(a,h0)]))
  else:
   var bottom:float=window.bottom
   var top0=bottom+float(window.height)-.35+.35*sqrt(maxf(0,1-pow((a-float(window.center))/(float(window.width)*.5),2)))
   var top1=bottom+float(window.height)-.35+.35*sqrt(maxf(0,1-pow((b-float(window.center))/(float(window.width)*.5),2)))
   sections.append(PackedVector2Array([Vector2(a,0),Vector2(b,0),Vector2(b,bottom),Vector2(a,bottom)]))
   sections.append(PackedVector2Array([Vector2(a,top0),Vector2(b,top1),Vector2(b,h1),Vector2(a,h0)]))
  for outline:PackedVector2Array in sections:append_piece(Shapes.extrude(outline,depth),pose,base,front,false,normal if observed else Vector3.ZERO,paint_ends)
 for window:Dictionary in windows:
  var outline=PackedVector2Array([Vector2(float(window.center)-float(window.width)*.5,float(window.bottom)),Vector2(float(window.center)+float(window.width)*.5,float(window.bottom))])
  for i in range(8,-1,-1):
   var t=float(window.center)-float(window.width)*.5+float(window.width)*i/8.
   var h=float(window.bottom)+float(window.height)-.35+.35*sqrt(maxf(0,1-pow((t-float(window.center))/(float(window.width)*.5),2)))
   outline.append(Vector2(t,h))
  var recess_pose=Transform3D(Basis(axis,Vector3.UP,normal),plane-normal*minf(.16,depth*.35))
  append_piece(Shapes.extrude(outline,.035),recess_pose,base,front,false,Vector3.ZERO,false,.24)

static func slab(base,front,outline:PackedVector2Array,height:float,depth:float):
 var pose=Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),Vector3.UP*(height-depth*.5))
 append_piece(Shapes.extrude(outline,depth),pose,base,front,true,Vector3.ZERO,true)

static func mesh(serial:int,graphic:Dictionary={})->Mesh:
 assert(owns(serial),"Unowned native Komatei ruin section")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 if not graphic.is_empty():assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate stale Komatei ruin contours")
 var base=Source.new([],load(ROOT+"surfaces.png"),.045)
 base.tiles={"stone":Vector2(0,0),"cap":Vector2(128,0),"floor":Vector2(256,0)}
 var front=Source.new([Rect2(Vector2.ZERO,Vector2(g.size[0],g.size[1])),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+".png"),.045)
 if g.form=="turret":
  var frames={"west":[Vector3.BACK,Vector3.ZERO],"south":[Vector3.RIGHT,Vector3.ZERO],"east":[Vector3.FORWARD,Vector3(6,0,0)],"north":[Vector3.LEFT,Vector3(0,0,-6)]}
  for face:String in frames:
   var axis:Vector3=frames[face][0];var plane:Vector3=frames[face][1]
   var holes=g.windows.filter(func(w):return w.face==face)
   wall_strip(base,front,axis,plane,contour(g.rims[face],axis,plane,g),float(g.depth),holes,0.,face in ["west","south"])
  slab(base,front,PackedVector2Array([Vector2(.70,.70),Vector2(5.30,.70),Vector2(5.30,5.30),Vector2(.70,5.30)]),float(g.deck),.38)
 elif g.form=="wall":
  var axis=Vector3.RIGHT if g.axis=="x" else Vector3.BACK
  var plane=Vector3(0,0,float(g.plane)) if g.axis=="x" else Vector3(float(g.plane),0,0)
  var rim=contour(g.rim,axis,plane,g);var lower:Array[Vector2]=[]
  for p:Vector2 in rim:lower.append(Vector2(p.x,minf(p.y,float(g.cap_bottom))))
  wall_strip(base,front,axis,plane,lower,float(g.depth),g.windows,0.,true,true)
  wall_strip(base,front,axis,plane,rim,float(g.cap_depth),[],float(g.cap_bottom),true,true)
 else:
  var outline=PackedVector2Array();var vertices:Array[Vector3]=[]
  for pixel:Array in g.polygon:
   var p=source_point(Vector2(pixel[0],pixel[1]),float(g.height),g)
   vertices.append(p);outline.append(Vector2(p.x,-p.z))
  slab(base,front,outline,float(g.height),float(g.depth))
  # Native raised panels have a low broken parapet along their two rear edges.
  for edge in 2:
   var a:Vector3=vertices[edge];var b:Vector3=vertices[edge+1];var axis=(b-a).normalized()
   var length_=a.distance_to(b);var plane=a-axis*a.dot(axis)
   plane.y=0.
   var rim:Array[Vector2]=[]
   for i in 9:rim.append(Vector2(a.dot(axis)+length_*i/8.,float(g.height)+(.45 if i%2==0 else .75)))
   # Render-only parapet; a source panel never adds navigation or a usable upper floor.
   wall_strip(base,front,axis,plane,rim,.45,[],float(g.height),true,true)
 var result=base.finish();var paint=front.finish()
 var stone=result.surface_get_material(0).duplicate();stone.set_shader_parameter("use_vertex_color",true);stone.set_shader_parameter("original_palette",false);result.surface_set_material(0,stone)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.surface_get_arrays(0));result.surface_set_material(1,paint.surface_get_material(0))
 result.set_meta("native_komatei_section",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256)
 result.set_meta("source_footprint",g.footprint);result.set_meta("render_only_windows",g.get("windows",[]).size())
 result.set_meta("reconstructed_hidden_depth",true)
 meshes[serial]=result
 return result
