extends RefCounted
## Pure measured wall/cap parts; source maps retain placement, collision and routes.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Timber=preload("res://scripts/forest/forest_il_laruka_buildings.gd")

static func source_point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var u=(pixel.x+float(g.origin[0]))/(32./3.);var v=(pixel.y+float(g.origin[1])+height/.045)/8.
 return Vector3((u-v)*.5,height,(u+v)*.5)

static func projected(p:Vector3,g:Dictionary)->Vector2:
 return Vector2((p.x+p.z)*(32./3.)-float(g.origin[0]),(p.z-p.x)*8.-p.y/.045-float(g.origin[1]))

static func oriented_quad(base,front,points:Array,wanted:Vector3,paint:bool=true):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 if normal.dot(wanted)<0:points=[points[3],points[2],points[1],points[0]];normal=-normal
 base.quad(points[0],points[1],points[2],points[3])
 if paint and normal.dot(Vector3(-1,0,1))>.01:
  for index in [0,1,2,0,2,3]:front.projected_vertex(points[index]+normal*.006,normal,points[index])

static func vertical_section(base,front,footprint:PackedVector2Array,bottom:float,top:float,paint:bool=true):
 var center=Vector2.ZERO
 for point:Vector2 in footprint:center+=point
 center/=footprint.size()
 for index in footprint.size():
  var a:Vector2=footprint[index];var b:Vector2=footprint[(index+1)%footprint.size()];var out=(a+b)*.5-center
  oriented_quad(base,front,[Vector3(a.x,bottom,a.y),Vector3(a.x,top,a.y),Vector3(b.x,top,b.y),Vector3(b.x,bottom,b.y)],Vector3(out.x,0,out.y),paint)
 var triangles=Geometry2D.triangulate_polygon(footprint)
 var previous:String=base.part;base.part="cap"
 for upper in [false,true]:
  var height=top if upper else bottom
  for index in range(0,triangles.size(),3):
   var points=[]
   for corner in 3:
    var p=footprint[triangles[index+corner]];points.append(Vector3(p.x,height,p.y))
   points.append(points[-1]);oriented_quad(base,front,points,Vector3.UP if upper else Vector3.DOWN,false)
 base.part=previous

static func plane_point(pixel:Vector2,axis:Vector3,plane:Vector3,g:Dictionary)->Vector3:
 var across=((pixel.x+float(g.origin[0]))/(32./3.)-plane.x-plane.z)/(axis.x+axis.z)
 var point=plane+axis*across
 point.y=((point.z-point.x)*8.-pixel.y-float(g.origin[1]))*.045
 return point

static func window_frame(base,front,footprint:PackedVector2Array,g:Dictionary):
 if not g.has("window_pixels"):return
 var rect:Array=g.window_pixels
 var center=Vector2.ZERO
 for p:Vector2 in footprint:center+=p
 center/=footprint.size()
 var midpoint=(float(rect[0])+float(rect[2]))*.5;var selected=[];var score=-INF
 for index in footprint.size():
  var a:Vector2=footprint[index];var b:Vector2=footprint[(index+1)%footprint.size()];var delta=b-a
  var normal=Vector3(delta.y,0,-delta.x).normalized();var m=(a+b)*.5-center
  if normal.dot(Vector3(m.x,0,m.y))<0:normal=-normal
  if normal.dot(Vector3(-1,0,1))<=.01:continue
  var u=(a.x+a.y)*(32./3.)-float(g.origin[0]);var v=(b.x+b.y)*(32./3.)-float(g.origin[0])
  if absf(v-u)<1. or midpoint<minf(u,v) or midpoint>maxf(u,v):continue
  var t=inverse_lerp(u,v,midpoint);var at=a.lerp(b,t);var value=Vector3(at.x,0,at.y).dot(Vector3(-1,0,1))
  if value>score:selected=[a,b,normal];score=value
 if selected.is_empty():return
 var start=Vector3(selected[0].x,0,selected[0].y);var end=Vector3(selected[1].x,0,selected[1].y)
 var axis=(end-start).normalized();var plane=start+Vector3(selected[2])*.10
 var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
 for pixel:Array in g.window_native_points:
  var p=plane_point(Vector2(pixel[0],pixel[1]),axis,plane,g);var q=Vector2(p.dot(axis),p.y);low=low.min(q);high=high.max(q)
 low-=Vector2(.09,.09);high+=Vector2(.09,.09)
 var a=axis*low.x+plane-axis*plane.dot(axis);a.y=low.y
 var b=axis*high.x+plane-axis*plane.dot(axis);b.y=high.y
 var outline=PackedVector2Array([Vector2(a.dot(axis),a.y),Vector2(b.dot(axis),a.y),Vector2(b.dot(axis),b.y),Vector2(a.dot(axis),b.y)])
 var slab=Shapes.extrude(outline,.15);var turn=Basis(Vector3.UP,atan2(-axis.z,axis.x));var arrays=slab.surface_get_arrays(0);var wall_plane=plane-axis*plane.dot(axis)
 for index in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
  var points=[]
  for corner in 3:points.append(turn*arrays[Mesh.ARRAY_VERTEX][index+corner]+wall_plane)
  var normal:Vector3=turn*arrays[Mesh.ARRAY_NORMAL][index]
  points.append(points[-1]);oriented_quad(base,front,points,normal,true)
 # Closed reused timber moulding follows the observed frame, without a route opening.
 base.part="trim"
 var points=[a,Vector3(a.x,b.y,a.z),b,Vector3(b.x,a.y,b.z)]
 for index in 4:Timber.bar(base,points[index],points[(index+1)%4],.065)
 var mid=(a+b)*.5
 Timber.bar(base,Vector3(mid.x,a.y,mid.z),Vector3(mid.x,b.y,mid.z),.045)
 Timber.bar(base,Vector3(a.x,mid.y,a.z),Vector3(b.x,mid.y,b.z),.045)

static func wall(g:Dictionary,texture:Texture2D,paint_texture:Texture2D)->Mesh:
 var base=Source.new([],texture,.045);base.tiles={"wall":Vector2.ZERO,"trim":Vector2(128,0),"cap":Vector2(256,0)};base.part="wall"
 var pitch=float(g.rectified_material.world_pitch);base.pitches={"wall":pitch,"trim":pitch,"cap":pitch}
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],paint_texture,.045)
 var footprint=PackedVector2Array()
 for pixel:Array in g.cap_pixels:
  var p=source_point(Vector2(pixel[0],pixel[1]),float(g.wall_height),g);footprint.append(Vector2(p.x,p.z))
 var low=float(g.wall_height)-.14 if g.get("cap_only",false) else 0.
 if g.get("wood_trim",false) and not g.get("cap_only",false):
  base.part="trim";vertical_section(base,front,footprint,low,.48)
  base.part="wall";vertical_section(base,front,footprint,.48,float(g.wall_height)-.25)
  base.part="trim";vertical_section(base,front,footprint,float(g.wall_height)-.25,float(g.wall_height))
 else:vertical_section(base,front,footprint,low,float(g.wall_height))
 if not g.get("cap_only",false):
  base.part="trim";window_frame(base,front,footprint,g)
 var result=base.finish();var back:ShaderMaterial=result.surface_get_material(0).duplicate();back.set_shader_parameter("original_palette",false);result.surface_set_material(0,back)
 var paint=front.finish();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.surface_get_arrays(0));result.surface_set_material(1,paint.surface_get_material(0))
 return result
