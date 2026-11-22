extends RefCounted
## Prepared source-painted roof shells and modular architectural details for Tina.
const Parts=preload("res://scripts/forest/forest_coastal_buildings.gd")
const ALIGNED_HIPS=[11403,11409,11410,11411,11412,11415,11416]
const IDS=[11402,11403,11407,11408,11413,11409,11410,11411,11412,11414,11415,11416,11450,11451]
# Original image coordinates: apex, left eave, near eave, right eave.
const ROOFS={
 11403:[Vector2(200,9),Vector2(57,128),Vector2(200,240),Vector2(347,127)],
 11407:[Vector2(226,4),Vector2(75,132),Vector2(255,260),Vector2(445,187)],
 11408:[Vector2(226,4),Vector2(15,182),Vector2(254,276),Vector2(393,129)],
 11409:[Vector2(156,37),Vector2(18,145),Vector2(153,230),Vector2(307,143)],
 11410:[Vector2(144,30),Vector2(6,125),Vector2(145,230),Vector2(297,125)],
 11411:[Vector2(149,14),Vector2(6,138),Vector2(164,239),Vector2(305,129)],
 11412:[Vector2(166,22),Vector2(18,144),Vector2(173,240),Vector2(314,129)],
 11415:[Vector2(220,13),Vector2(71,128),Vector2(220,236),Vector2(377,138)],
 11416:[Vector2(200,15),Vector2(55,130),Vector2(200,219),Vector2(347,129)]
}

static func painted_quad(skin,a:Vector3,b:Vector3,c:Vector3,d:Vector3,pixels:Array):
 var normal=(c-a).cross(b-a)
 if normal.length_squared()<.0000001:normal=(d-a).cross(b-a)
 if normal.length_squared()<.0000001:return
 normal=normal.normalized()
 var points=[a,b,c,d];var rect:Rect2=skin.graphic[0]
 for i in [0,1,2,0,2,3]:
  skin.surface.set_normal(normal)
  skin.surface.set_uv((rect.position+pixels[i])/skin.texture.get_size())
  skin.surface.add_vertex(points[i])

static func hip(native,serial:int,w:float,d:float,base:float,rise:float,at:Vector3,source:Array=[],peak_offset:Vector3=Vector3.ZERO):
 if source.is_empty():source=ROOFS[serial]
 # shortcut: Native art exposes two faces; mirrored rear paint needs replacement if original rear views are recovered.
 var cutouts=Array(gable_records(serial)).map(func(record):return PackedVector2Array(record[1]))
 var aligned=serial in ALIGNED_HIPS
 var edges=[[source[1],source[2]],[source[2],source[3]],[source[2],source[1]],[source[3],source[2]]]
 var corners=[Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]
 var profile=[Vector2(1.04,0),Vector2(1.01,.045),Vector2(.91,.14),Vector2(.72,.33),Vector2(.43,.62),Vector2(.16,.87),Vector2(.012,1)]
 var rings=[];var paint_rings=[]
 if aligned:
  for level in profile:
   var ring=[];var samples=[]
   var apex=aligned_roof_point(at+Vector3.UP*(base+rise),source[0],serial,w/1.09,d/1.09,at)
   for i in 3:
    var pixel:Vector2=source[0].lerp(source[i+1],level.x/1.04)
    var point=aligned_roof_point(hip_point(corners[i],level,w,d,base,rise,at,peak_offset),pixel,serial,w/1.09,d/1.09,at)
    var eave=aligned_roof_point(hip_point(corners[i],profile[0],w,d,base,rise,at,peak_offset),source[i+1],serial,w/1.09,d/1.09,at)
    point.y=lerpf(eave.y,apex.y,level.y)
    ring.append(point);samples.append(roof_pixel(point,serial,w/1.09,d/1.09,at))
   ring.append(ring[0]+ring[2]-ring[1]);rings.append(ring);paint_rings.append(samples)
 for face in 4:
  var left:Vector2=corners[face];var right:Vector2=corners[(face+1)%4]
  for level in profile.size()-1:
   var low:Vector2=profile[level];var high:Vector2=profile[level+1]
   for step in 8:
    var u=float(step)/8;var v=float(step+1)/8
    var a=hip_point(left.lerp(right,u),low,w,d,base,rise,at,peak_offset)
    var b=hip_point(left.lerp(right,u),high,w,d,base,rise,at,peak_offset)
    var c=hip_point(left.lerp(right,v),high,w,d,base,rise,at,peak_offset)
    var e=hip_point(left.lerp(right,v),low,w,d,base,rise,at,peak_offset)
    var p:Vector2=edges[face][0].lerp(edges[face][1],u);var q:Vector2=edges[face][0].lerp(edges[face][1],v)
    var pixels=[source[0].lerp(p,low.x/1.04),source[0].lerp(p,high.x/1.04),source[0].lerp(q,high.x/1.04),source[0].lerp(q,low.x/1.04)]
    var points=[a,b,c,e]
    if aligned:
     var next=(face+1)%4
     points=[rings[level][face].lerp(rings[level][next],u),rings[level+1][face].lerp(rings[level+1][next],u),rings[level+1][face].lerp(rings[level+1][next],v),rings[level][face].lerp(rings[level][next],v)]
     var first=[0,1,1,2][face];var last=[1,2,0,1][face]
     pixels=[paint_rings[level][first].lerp(paint_rings[level][last],u),paint_rings[level+1][first].lerp(paint_rings[level+1][last],u),paint_rings[level+1][first].lerp(paint_rings[level+1][last],v),paint_rings[level][first].lerp(paint_rings[level][last],v)]
    roof_quad(native,points,pixels,cutouts if face<2 else [])

static func facade_key(serial:int,face:String)->String:
 return "%s_%d_%s"%["jenova" if serial==11403 else "tina",serial,face]

static func shell_profile(serial:int,w:float,d:float)->Array:
 var left:Array=crops()[facade_key(serial,"left")][1];var right:Array=crops()[facade_key(serial,"right")][1]
 var lx=float(left[1][0]-left[0][0]);var rx=float(right[1][0]-right[0][0]);var total=w+d
 var scale=(lx+rx)/(total*.70710678)
 var wall=(float(left[3][1]-left[0][1])+float(right[3][1]-right[0][1]))*.5/(scale*.66226618)
 var height=(((float(left[2][1])+float(right[3][1]))*.5-ROOFS[serial][0].y)/scale-total*.52981294*.5)/.66226618
 return [total*rx/(lx+rx),total*lx/(lx+rx),wall,height-wall]

static func aligned_roof_point(point:Vector3,pixel:Vector2,serial:int,w:float,d:float,at:Vector3)->Vector3:
 var left:Array=crops()[facade_key(serial,"left")][1];var right:Array=crops()[facade_key(serial,"right")][1]
 var corner=at+Vector3(-w*.5,0,d*.5)
 var anchor=(Vector2(left[2][0],left[2][1])+Vector2(right[3][0],right[3][1]))*.5
 var scale=float(left[1][0]-left[0][0]+right[1][0]-right[0][0])/((w+d)*.70710678)
 # Keep the roof and facade in the same native camera calibration.
 var shift=((pixel.x-anchor.x)/scale-(point.x+point.z-corner.x-corner.z)*.70710678)*.70710678
 point.x+=shift;point.z+=shift
 point.y=((anchor.y-pixel.y)/scale-(point.x-point.z-corner.x+corner.z)*.52981294)/.66226618
 return point

static func roof_pixel(point:Vector3,serial:int,w:float,d:float,at:Vector3)->Vector2:
 var left:Array=crops()[facade_key(serial,"left")][1];var right:Array=crops()[facade_key(serial,"right")][1]
 var anchor=(Vector2(left[2][0],left[2][1])+Vector2(right[3][0],right[3][1]))*.5
 var scale=float(left[1][0]-left[0][0]+right[1][0]-right[0][0])/((w+d)*.70710678)
 point-=at+Vector3(-w*.5,0,d*.5)
 return anchor+Vector2((point.x+point.z)*.70710678,-(point.x-point.z)*.52981294-point.y*.66226618)*scale

# Cut source-painted dormers out of the roof shell so the raised arch is not painted twice or buried.
static func roof_quad(native,points:Array,pixels:Array,cutouts:Array):
 if cutouts.is_empty():
  painted_quad(native,points[0],points[1],points[2],points[3],pixels);return
 for triangle in [[0,1,2],[0,2,3]]:
  var source=PackedVector2Array([pixels[triangle[0]],pixels[triangle[1]],pixels[triangle[2]]])
  var u=source[1]-source[0];var v=source[2]-source[0];var det=u.cross(v)
  if absf(det)<.000001:continue
  var polygons=[source]
  for cutout in cutouts:
   var remaining=[]
   for polygon in polygons:remaining.append_array(Geometry2D.clip_polygons(polygon,cutout))
   polygons=remaining
  var a:Vector3=points[triangle[0]];var b:Vector3=points[triangle[1]];var c:Vector3=points[triangle[2]]
  var normal=(c-a).cross(b-a).normalized()
  for polygon in polygons:
   var indices=Geometry2D.triangulate_polygon(polygon)
   for i in range(0,indices.size(),3):
    var samples=[polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]]];var vertices=[]
    for sample:Vector2 in samples:
     var delta=sample-source[0]
     vertices.append(a+(b-a)*delta.cross(v)/det+(c-a)*u.cross(delta)/det)
    if (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).dot(normal)<0:vertices.reverse();samples.reverse()
    for j in 3:
     native.surface.set_normal(normal);native.surface.set_uv((native.graphic[0].position+samples[j])/native.texture.get_size());native.surface.add_vertex(vertices[j])

static func hip_point(edge:Vector2,level:Vector2,w:float,d:float,base:float,rise:float,at:Vector3,peak_offset:Vector3=Vector3.ZERO)->Vector3:
 return at+Vector3(edge.x*w*.5*level.x,base+rise*level.y,edge.y*d*.5*level.x)+peak_offset*(1-level.x/1.04)

static func round_roof(native,at:Vector3,w:float,d:float,levels:Array,center_x:float,radius_x:float,rear_fold:bool=false):
 for level in levels.size()-1:
  var low:Array=levels[level];var high:Array=levels[level+1]
  for i in 48:
   var a=-i*TAU/48;var b=-(i+1)*TAU/48
   var pa=round_point(at,w,d,a,low);var pb=round_point(at,w,d,a,high)
   var pc=round_point(at,w,d,b,high);var pd=round_point(at,w,d,b,low)
   painted_quad(native,pa,pb,pc,pd,[round_pixel(a,low,center_x,radius_x,rear_fold),round_pixel(a,high,center_x,radius_x,rear_fold),round_pixel(b,high,center_x,radius_x,rear_fold),round_pixel(b,low,center_x,radius_x,rear_fold)])

static func round_point(at:Vector3,w:float,d:float,angle:float,level:Array)->Vector3:
 return at+Vector3(cos(angle)*w*level[0],level[1],sin(angle)*d*level[0])

static func round_pixel(angle:float,level:Array,x:float,radius:float,rear_fold:bool=false)->Vector2:
 if rear_fold:
  var sx=-absf(cos(angle));var sz=absf(sin(angle))
  return Vector2(x+(sx+sz)*.70710678*radius*level[0],level[2]+(sz-sx)*.70710678*level[3])
 # Preserve screen-horizontal position; reflect only hidden rear depth into the visible hemisphere.
 var horizontal=(cos(angle)+sin(angle))*.70710678
 var depth=absf((sin(angle)-cos(angle))*.70710678)
 return Vector2(x+horizontal*radius*level[0],level[2]+depth*level[3])

static func dome(native,w:float,d:float,height:float,serial:int=11414):
 var body=height*.62
 var cx=142 if serial==11402 else 152 if serial==11413 else 144
 var rx=130 if serial==11402 else 140 if serial==11413 else 128
 var lower=[[1,body,145,78],[.99,height*.6613,137,76],[.90,height*.7321,112,64],[.70,height*.8028,89,48],[.235,height*.85,74,17]] if serial==11402 else [[1,body,135,77],[.99,height*.6613,129,74],[.90,height*.7321,110,66],[.70,height*.8028,86,47],[.235,height*.85,72,17]] if serial==11413 else [[1,body,129,70],[.99,height*.6613,123,68],[.90,height*.7321,104,59],[.70,height*.8028,82,44],[.235,height*.85,67,16]]
 var offset=7 if serial==11402 else 5 if serial==11413 else 0
 round_roof(native,Vector3.ZERO,w*.55,d*.55,lower,cx,rx,serial==11402)
 round_roof(native,Vector3.ZERO,w*.55,d*.55,[[.235,height*.85,67+offset,16],[.235,height*.94,44+offset,16],[.275,height*.94,39+offset,17],[.24,height*.97,22+offset,13],[.01,height,5,.6]],cx,rx,serial==11402)

static func circular(native,skin,serial:int,w:float,d:float,height:float):
 var radius=w*.48;var body=height*.62
 skin.part="plaster"
 Parts.kili_round(skin,Vector3.ZERO,[Vector2(radius,0),Vector2(radius,body)])
 var cx=142 if serial==11402 else 152 if serial==11413 else 144
 var rx=114 if serial==11402 else 118 if serial==11413 else 112
 var top=175 if serial==11402 else 170 if serial==11413 else 158
 var bottom=304 if serial==11402 else 266 if serial==11413 else 254
 var ry=65 if serial==11402 else 58 if serial==11413 else 56
 round_roof(native,Vector3.ZERO,w*.481,d*.481,[[1,.5,bottom,ry],[1,body,top,ry]],cx,rx,serial==11402)
 round_roof(native,Vector3.ZERO,w*.482,d*.482,[[1,.02,bottom+25,ry],[1,.5,bottom,ry]],cx,rx,serial==11402)
 dome(native,w,d,height,serial)
 garden(native,w,d,serial)
 var door_height=body*(.78 if serial==11402 else .73)
 round_door(native,skin,serial,Vector3(-radius-.10,door_height*.5+.3,0),door_height*(48.0/104 if serial==11402 else 52.0/104),door_height)
 skin.part="stone"
 Parts.kili_round(skin,Vector3.ZERO,[Vector2(w*.57,0),Vector2(w*.57,.25),Vector2(w*.52,.36)])

static func bay(native,at:Vector3,radius:float,wall:float,rise:float):
 round_roof(native,at,radius*1.12,radius*1.12,[[1,wall*.91,198,62],[.985,wall*.91+rise*.16,186,57],[.85,wall*.91+rise*.34,167,44],[.58,wall*.91+rise*.51,148,29],[.27,wall*.91+rise*.60,135,12],[.01,wall*.91+rise*.62,130,.5]],226,102)

static func shelter(native,skin,serial:int,w:float,d:float,wall:float,height:float):
 var pixels=[Vector2(2,111),Vector2(53,27),Vector2(277,176),Vector2(219,256)] if serial==11450 else [Vector2(5,112),Vector2(57,32),Vector2(273,174),Vector2(217,257)]
 painted_quad(native,Vector3(-w*.60,wall*.70,-d*.54),Vector3(w*.54,height,-d*.54),Vector3(w*.54,height,d*.54),Vector3(-w*.60,wall*.70,d*.54),pixels)
 # Source-painted contents sit behind the reusable raised posts, not on the outer roof.
 painted_quad(native,Vector3(-w*.42,.10,-d*.45),Vector3(-w*.42,wall*.68,-d*.45),Vector3(-w*.42,wall*.68,d*.45),Vector3(-w*.42,.10,d*.45),[Vector2(44,217),Vector2(44,138),Vector2(215,247),Vector2(215,327)])
 painted_quad(native,Vector3(-w*.42,.10,d*.46),Vector3(-w*.42,height*.50,d*.46),Vector3(w*.40,height*.927,d*.46),Vector3(w*.40,.10,d*.46),[Vector2(223,323),Vector2(223,254),Vector2(278,190),Vector2(278,281)])
 painted_quad(native,Vector3(w*.40,.10,-d*.46),Vector3(w*.40,height*.927,-d*.46),Vector3(-w*.42,height*.50,-d*.46),Vector3(-w*.42,.10,-d*.46),[Vector2(223,323),Vector2(223,254),Vector2(278,190),Vector2(278,281)])
 skin.part="timber"
 for i in 12:
  var z=-d*.52+i*d*1.04/11;var high=[.45,.72,.55,.86][i%4]
  skin.box(AABB(Vector3(w*.54-.08,height-.15,z-.10),Vector3(.16,high,.20)))
 skin.box(AABB(Vector3(w*.54-.07,height+.13,-d*.54),Vector3(.14,.10,d*1.08)))
 skin.part="snowroof"
 for i in (13 if serial==11450 else 6):
  var z=-d*.47+i*d*.94/(12 if serial==11450 else 5);var tip=Vector3(-w*.60,wall*.70,z)
  Parts.kili_round(skin,tip,[Vector2(0,-.25-(i%3)*.12),Vector2(.07,0)])

static func finial(skin,at:Vector3):
 skin.part="stone"
 Parts.kili_round(skin,at,[Vector2(.21,0),Vector2(.24,.10),Vector2(.15,.18),Vector2(.12,.40),Vector2(.21,.48),Vector2(.17,.65),Vector2(.035,.76)])

static func join(walls:Mesh,roof:Mesh,pose:Transform3D,underlay:Mesh=null)->ArrayMesh:
 var result=ArrayMesh.new()
 for mesh:Mesh in [walls,roof]+([underlay] if underlay!=null else []):
  for surface in mesh.get_surface_count():
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(mesh,surface,pose)
   var part=tool.commit()
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0))
   result.surface_set_material(result.get_surface_count()-1,mesh.surface_get_material(surface))
 result.set_meta("native_roof",true)
 return result

static var crop_data:Dictionary={}
static func crops()->Dictionary:
 if crop_data.is_empty():crop_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/building-surfaces.json")).patches
 return crop_data

static func facade(native,serial:int,face:String,points:Array,prefix:String="tina"):
 var pixels:Array=crops()["%s_%d_%s"%[prefix,serial,face]][1]
 painted_quad(native,points[0],points[1],points[2],points[3],[Vector2(pixels[3][0],pixels[3][1]),Vector2(pixels[0][0],pixels[0][1]),Vector2(pixels[1][0],pixels[1][1]),Vector2(pixels[2][0],pixels[2][1])])

static func face_uv(pixel:Vector2,quad:Array)->Vector2:
 var a=Vector2(quad[0][0],quad[0][1]);var b=Vector2(quad[1][0],quad[1][1]);var c=Vector2(quad[2][0],quad[2][1]);var d=Vector2(quad[3][0],quad[3][1])
 var uv=Vector2(.5,.5)
 for i in 8:
  var p=a.lerp(b,uv.x).lerp(d.lerp(c,uv.x),uv.y)
  var u=(b-a).lerp(c-d,uv.y);var v=(d-a).lerp(c-b,uv.x);var error=p-pixel
  var det=u.x*v.y-u.y*v.x
  assert(absf(det)>.0001,"Native facade must be invertible")
  uv-=Vector2((error.x*v.y-error.y*v.x)/det,(u.x*error.y-u.y*error.x)/det)
 return uv

static func face_point(pixel:Vector2,quad:Array,body:Vector3,w:float,d:float,h:float,face:String)->Vector3:
 var uv=face_uv(pixel,quad)
 return body+Vector3(-w*.5-.065,(1-uv.y)*h,(uv.x-.5)*d) if face=="left" else body+Vector3((uv.x-.5)*w,(1-uv.y)*h,d*.5+.065)

static func door(native,skin,serial:int,body:Vector3,w:float,d:float,h:float)->Dictionary:
 var face="right" if serial in [11410,11411] else "left"
 var pixels=[]
 if serial==11403:pixels=[Vector2(89,254),Vector2(89,180),Vector2(92,167),Vector2(100,161),Vector2(110,164),Vector2(124,179),Vector2(127,279)]
 elif serial==11409:pixels=[Vector2(88,285),Vector2(88,221),Vector2(92,207),Vector2(101,200),Vector2(112,201),Vector2(123,213),Vector2(124,311)]
 elif serial==11410:pixels=[Vector2(185,301),Vector2(185,225),Vector2(189,207),Vector2(198,191),Vector2(208,180),Vector2(217,181),Vector2(222,191),Vector2(222,279)]
 elif serial==11411:pixels=[Vector2(201,282),Vector2(201,213),Vector2(204,201),Vector2(212,195),Vector2(223,198),Vector2(236,211),Vector2(237,258)]
 elif serial==11412:pixels=[Vector2(105,269),Vector2(105,213),Vector2(109,201),Vector2(118,196),Vector2(128,202),Vector2(139,215),Vector2(142,297)]
 elif serial in [11415,11416]:pixels=[Vector2(80,244),Vector2(80,180),Vector2(84,167),Vector2(92,162),Vector2(103,166),Vector2(117,180),Vector2(121,268)]
 else:return {}
 if serial==11415:
  for i in pixels.size():pixels[i]+=Vector2(20,3)
 var quad:Array=crops()[facade_key(serial,face)][1]
 frame(native,skin,pixels,quad,body,w,d,h,face)
 var a=face_point(pixels[0],quad,body,w,d,h,face);var b=face_point(pixels[-1],quad,body,w,d,h,face)
 return {"at":(a+b)*.5,"width":a.distance_to(b)+.6,"face":face}

static func frame(native,skin,pixels:Array,quad:Array,body:Vector3,w:float,d:float,h:float,face:String,steps:String="tina_steps"):
 var normal=Vector3.LEFT if face=="left" else Vector3.BACK
 var center=Vector2.ZERO
 for p:Vector2 in pixels:center+=p
 center/=pixels.size()
 for i in pixels.size():
  var j=(i+1)%pixels.size();var a:Vector2=pixels[i];var b:Vector2=pixels[j]
  var ia=a.lerp(center,.12);var ib=b.lerp(center,.12)
  var pa=face_point(a,quad,body,w,d,h,face);var pb=face_point(b,quad,body,w,d,h,face)
  var qa=face_point(ia,quad,body,w,d,h,face);var qb=face_point(ib,quad,body,w,d,h,face)
  outward_quad(native,[pa+normal*.17,qa+normal*.17,qb+normal*.17,pb+normal*.17],[a,ia,ib,b],normal)
  painted_quad(native,qa,qa+normal*.17,qb+normal*.17,qb,[ia,ia,ib,ib])
  painted_quad(native,pa+normal*.17,pa,pb,pb+normal*.17,[a,a,b,b])
 var left=face_point(pixels[0],quad,body,w,d,h,face);var right=face_point(pixels[-1],quad,body,w,d,h,face)
 var threshold=(left+right)*.5
 var span=left.distance_to(right)+.4;var rise=maxf(.12,threshold.y*.33)
 skin.part=steps
 for step in 3:
  var depth=(3-step)*.42;var at=threshold+normal*(depth*.5+.03);at.y=step*rise
  skin.box(AABB(at-Vector3(depth*.5,0,span*.5),Vector3(depth,rise,span)) if face=="left" else AABB(at-Vector3(span*.5,0,depth*.5),Vector3(span,rise,depth)))
 # The source carries the handles/hinges; a small native-painted offset keeps them readable in side views.
 for fraction in [.33,.66]:
  var a=pixels[0].lerp(pixels[1],fraction)
  var at=face_point(a,quad,body,w,d,h,face)+normal*.20
  skin.part="trim";skin.box(AABB(at-Vector3(.07,.045,.07),Vector3(.14,.09,.14)))

static func outward_quad(native,points:Array,pixels:Array,normal:Vector3):
 if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0:
  points.reverse();pixels.reverse()
 painted_quad(native,points[0],points[1],points[2],points[3],pixels)

static func porch(skin,body:Vector3,w:float,d:float,h:float,doorway:Dictionary,serial:int=0,faces:Array=["left","right"]):
 skin.part="timber"
 var snowy=serial in [11411,11412,11415]
 var pub=serial in [11415,11416]
 var blue=serial in [11409,11410]
 if blue:faces=["left"] if serial==11409 else ["right"]
 var porch_paint="tina_blue_porch" if blue else "timber"
 skin.part=porch_paint
 var post_width=.30 if pub else .26 if blue else .23 if snowy else .14
 var rail_height=h*.32 if pub else h*.30 if blue else h*.25 if snowy else 1.48
 var rail_width=.18 if pub or snowy or blue else .13
 for face in faces:
  var width=d if face=="left" else w
  var gap=doorway.width if doorway.face==face else 0.0
  var center=doorway.at.z-body.z if face=="left" else doorway.at.x-body.x
  var ends=[-width*.5,width*.5] if gap==0 else [-width*.5,center-gap*.5,center+gap*.5,width*.5]
  for section in ends.size()/2:
   var low:float=ends[section*2];var high:float=ends[section*2+1]
   if high<=low:continue
   for y in ([.55,rail_height] if blue else [rail_height*.44,rail_height] if pub or snowy else [.64,1.48]):
    var at=body+Vector3(-w*.5-1.05,y,low) if face=="left" else body+Vector3(low,y,d*.5+1.05)
    skin.box(AABB(at+Vector3(-post_width*.5,0,0),Vector3(post_width,rail_width,high-low)) if face=="left" else AABB(at+Vector3(0,0,-post_width*.5),Vector3(high-low,rail_width,post_width)))
    if snowy:
     skin.part="tina_soft_snow"
     skin.box(AABB(at+Vector3(-post_width*.6,rail_width,0),Vector3(post_width*1.2,.07,high-low)) if face=="left" else AABB(at+Vector3(0,rail_width,-post_width*.6),Vector3(high-low,.07,post_width*1.2)))
     skin.part="timber"
   if blue:
    for i in range(1,ceili((high-low)/.65)):
     var p=lerpf(low,high,float(i)/ceili((high-low)/.65))
     var at=body+Vector3(-w*.5-1.05,.68,p) if face=="left" else body+Vector3(p,.68,d*.5+1.05)
     skin.box(AABB(at-Vector3(.07,0,.07),Vector3(.14,rail_height-.68,.14)))
   var count=maxi(1,ceili((high-low)/(3.8 if pub else 2.8 if snowy or blue else 1.6)))
   for i in count+1:
    var p=lerpf(low,high,float(i)/count)
    var base=.03 if blue else .50
    var at=body+Vector3(-w*.5-1.05,base,p) if face=="left" else body+Vector3(p,base,d*.5+1.05)
    skin.box(AABB(at-Vector3(post_width*.5,0,post_width*.5),Vector3(post_width,rail_height+.22-base,post_width)))
    if snowy:
     skin.part="tina_soft_snow"
     Parts.kili_round(skin,at+Vector3.UP*(rail_height-.28),[Vector2(post_width*.8,0),Vector2(post_width*.65,.10),Vector2(0,.14)])
     skin.part="timber"

static func round_door(native,skin,serial:int,center:Vector3,width:float,height:float):
 var quad=[];var outline=[];var face="left"
 if serial==11407:
  quad=[[151,291],[196,320],[196,414],[151,385]]
  outline=[Vector2(151,385),Vector2(151,316),Vector2(153,301),Vector2(162,291),Vector2(174,295),Vector2(191,309),Vector2(196,325),Vector2(196,414)]
 elif serial==11408:
  face="right";quad=[[274,318],[313,293],[313,390],[274,415]]
  outline=[Vector2(274,415),Vector2(274,333),Vector2(278,320),Vector2(287,308),Vector2(300,298),Vector2(309,300),Vector2(313,309),Vector2(313,390)]
 elif serial==11402:
  quad=[[27,276],[74,306],[74,410],[27,379]]
  outline=[Vector2(27,379),Vector2(27,291),Vector2(30,277),Vector2(40,267),Vector2(51,271),Vector2(67,287),Vector2(74,306),Vector2(74,410)]
 elif serial==11413:
  quad=[[35,218],[88,252],[88,334],[35,300]]
  outline=[Vector2(35,300),Vector2(35,240),Vector2(38,225),Vector2(49,215),Vector2(62,223),Vector2(82,244),Vector2(88,252),Vector2(88,334)]
 else:
  quad=[[31,211],[83,243],[83,324],[31,292]]
  outline=[Vector2(31,292),Vector2(31,230),Vector2(34,215),Vector2(45,204),Vector2(59,212),Vector2(78,228),Vector2(83,243),Vector2(83,324)]
 var body=center+Vector3(.070,-height*.5,0) if face=="left" else center+Vector3(0,-height*.5,-.070)
 var w=.01 if face=="left" else width;var d=width if face=="left" else .01
 var pixels=[Vector2(quad[3][0],quad[3][1]),Vector2(quad[0][0],quad[0][1]),Vector2(quad[1][0],quad[1][1]),Vector2(quad[2][0],quad[2][1])]
 var points=[]
 for pixel in pixels:points.append(face_point(pixel,quad,body,w,d,height,face))
 outward_quad(native,points,pixels,Vector3.LEFT if face=="left" else Vector3.BACK)
 frame(native,skin,outline,quad,body,w,d,height,face)

static func gable_records(serial:int)->Array:
 var records=[]
 if serial==11403:records=[["left",[Vector2(61,161),Vector2(68,149),Vector2(83,143),Vector2(100,149),Vector2(117,164),Vector2(130,185),Vector2(130,201),Vector2(61,179)]]]
 if serial==11409:records=[["left",[Vector2(80,223),Vector2(82,209),Vector2(90,198),Vector2(102,196),Vector2(115,205),Vector2(128,225),Vector2(128,245),Vector2(80,214)+Vector2(0,18)]]]
 if serial==11410:
  records=[["left",[Vector2(23,160),Vector2(34,140),Vector2(48,128),Vector2(62,128),Vector2(80,145),Vector2(96,170),Vector2(96,208),Vector2(23,169)]],
           ["right",[Vector2(222,188),Vector2(233,160),Vector2(249,143),Vector2(267,132),Vector2(284,135),Vector2(296,150),Vector2(296,177),Vector2(222,220)]]]
 if serial==11411:
  records=[["left",[Vector2(20,161),Vector2(28,145),Vector2(42,136),Vector2(55,139),Vector2(73,151),Vector2(92,173),Vector2(92,192),Vector2(20,176)]],
           ["right",[Vector2(197,216),Vector2(201,193),Vector2(211,180),Vector2(226,175),Vector2(240,181),Vector2(251,196),Vector2(251,212),Vector2(197,232)]]]
 return records

static func gables(native,serial:int,body:Vector3,w:float,d:float,h:float,records:Array=[],prefix:String="tina"):
 if records.is_empty():records=gable_records(serial)
 for record in records:
  var face:String=record[0];var pixels:Array=record[1];var quad:Array=crops()[facade_key(serial,face) if prefix=="tina" else "%s_%d_%s"%[prefix,serial,face]][1]
  var normal=Vector3.LEFT if face=="left" else Vector3.BACK;var center=Vector2.ZERO
  for p:Vector2 in pixels:center+=p
  center/=pixels.size()
  var middle=face_point(center,quad,body,w,d,h,face)+normal*.42
  for i in pixels.size():
   var a:Vector2=pixels[i];var b:Vector2=pixels[(i+1)%pixels.size()]
   var back_a=face_point(a,quad,body,w,d,h,face);var back_b=face_point(b,quad,body,w,d,h,face)
   var points=[middle,back_a+normal*.42,back_b+normal*.42];var samples=[center,a,b]
   if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0:points.reverse();samples.reverse()
   var rect:Rect2=native.graphic[0]
   for j in 3:
    native.surface.set_normal(normal);native.surface.set_uv((rect.position+samples[j])/native.texture.get_size());native.surface.add_vertex(points[j])
   painted_quad(native,back_a,back_a+normal*.42,back_b+normal*.42,back_b,[a,a,b,b])

static func garden(native,w:float,d:float,serial:int=11414):
 var cx=142 if serial==11402 else 152 if serial==11413 else 144
 var rx=142 if serial==11402 else 150 if serial==11413 else 144
 var outer=360 if serial==11402 else 320 if serial==11413 else 309
 var ry=82 if serial!=11413 else 88
 var inner=327 if serial==11402 else 285 if serial==11413 else 280
 round_roof(native,Vector3.ZERO,w*.57,d*.57,[[1,.025,outer,ry],[.99,.335,outer-5,ry-2],[.84,.375,inner,65]],cx,rx)

static func bay_porch(skin,w:float,d:float,serial:int=11408):
 var turn=Basis(Vector3(0,0,-1),Vector3.UP,Vector3(-1,0,0)) if serial==11407 else Basis.IDENTITY
 var corner=turn*Vector3(w*.46,.025,d*.46)
 for start_ in [Vector3(-w*.08,.025,d*.46),Vector3(w*.46,.025,d*.11)]:
  var start=turn*start_;var span=corner-start;var length_=span.length();var axis=span/length_
  var low=start.min(corner)
  skin.part="tina_bay_fence"
  for y in [.55,1.45]:skin.box(AABB(low+Vector3(-.08,y,-.08),span.abs()+Vector3(.16,.15,.16)))
  var boards=ceili(length_/.58)
  for i in boards+1:
   var at=start.lerp(corner,float(i)/boards);var height=[1.88,1.95,1.83,1.91][i%4]
   skin.box(AABB(at-Vector3(.07,0,.07),Vector3(.14,height,.44)) if absf(axis.z)>.5 else AABB(at-Vector3(.22,0,.07),Vector3(.44,height,.14)))
  var count=ceili(length_/2.8)
  for i in count+1:
   var p=start.lerp(corner,float(i)/count)
   skin.part="tina_bay_fence"
   Parts.kili_round(skin,p,[Vector2(.19,0),Vector2(.19,2.1),Vector2(0,2.1)])
   if serial==11408:
    skin.part="snowroof"
    Parts.kili_round(skin,p+Vector3.UP*2.1,[Vector2(.22,0),Vector2(.18,.10),Vector2(0,.13)])

static func bay_walls(native,serial:int,body:Vector3,w:float,d:float,h:float):
 for face in ["left","right"]:
  var quad:Array=crops()["tina_%d_%s"%[serial,face]][1]
  var a=Vector2(quad[0][0],quad[0][1]);var b=Vector2(quad[1][0],quad[1][1]);var c=Vector2(quad[2][0],quad[2][1]);var e=Vector2(quad[3][0],quad[3][1])
  # shortcut: Only exposed wall strips are known; replace concealed timber if more original views are recovered.
  var low=.58 if serial==11408 and face=="right" else 0.0
  var high=.43 if serial==11407 and face=="left" else 1.0
  var pixels=[e.lerp(c,low),a.lerp(b,low),a.lerp(b,high),e.lerp(c,high)];var points=[]
  for pixel in pixels:points.append(face_point(pixel,quad,body,w,d,h,face))
  outward_quad(native,points,pixels,Vector3.LEFT if face=="left" else Vector3.BACK)
 var windows=[["left",[Vector2(93,184),Vector2(122,204),Vector2(122,253),Vector2(93,233)]],
  ["right",[Vector2(343,302),Vector2(370,283),Vector2(370,335),Vector2(343,354)]],
  ["right",[Vector2(403,257),Vector2(429,239),Vector2(429,289),Vector2(403,307)]]] if serial==11407 else [
  ["left",[Vector2(44,238),Vector2(76,260),Vector2(76,290),Vector2(44,268)]],
  ["left",[Vector2(102,280),Vector2(126,297),Vector2(126,331),Vector2(102,313)]],
  ["right",[Vector2(342,187),Vector2(372,167),Vector2(372,231),Vector2(342,252)]]]
 for window in windows:
  var face:String=window[0];var pixels:Array=window[1];var quad:Array=crops()["tina_%d_%s"%[serial,face]][1]
  var normal=Vector3.LEFT if face=="left" else Vector3.BACK
  for side in [0.0,.78]:
   var paint=[pixels[3].lerp(pixels[2],side),pixels[0].lerp(pixels[1],side),pixels[0].lerp(pixels[1],side+.22),pixels[3].lerp(pixels[2],side+.22)]
   var points=[]
   for pixel in paint:points.append(face_point(pixel,quad,body,w,d,h,face)+normal*.16)
   outward_quad(native,points,paint,normal)
   for i in 4:
    var j=(i+1)%4
    painted_quad(native,points[i],points[i]-normal*.16,points[j]-normal*.16,points[j],[paint[i],paint[i],paint[j],paint[j]])

# Left/right reach on world X and Z, traced from the native rail ends and corner stubs.
const RAILS=[Vector4(0,0,-1,1),Vector4(-1,1,0,0),Vector4(-.25,1,-1,1),Vector4(-1,1,-.25,1),Vector4(-1,1,-1,.25),Vector4(-.25,1,-.25,1),Vector4(0,0,-.25,1),Vector4(0,0,-1,.25),Vector4(-.25,1,0,0),Vector4(-1,.25,0,0),Vector4(-.25,.25,-1,1),Vector4(-.25,1,-1,1),Vector4(-1,1,-.25,1),Vector4(-1,1,-1,.25)]

static func fence_arms(serial:int)->Vector4:
 return RAILS[serial-(11378 if serial>=11378 else 11363)]

static func fence(skin,serial:int,height:float):
 var arms=fence_arms(serial);skin.part="tina_fence_wood"
 Parts.kili_round(skin,Vector3.ZERO,[Vector2(.12,0),Vector2(.12,height-.08),Vector2(.09,height),Vector2(0,height)])
 for y in [height*.43,height*.73]:
  if arms.y>arms.x:skin.box(AABB(Vector3(arms.x*1.52,y,-.09),Vector3((arms.y-arms.x)*1.52,.17,.18)))
  if arms.w>arms.z:skin.box(AABB(Vector3(-.09,y,arms.z*1.52),Vector3(.18,.17,(arms.w-arms.z)*1.52)))
  skin.part="tina_fence_rope"
  Parts.kili_round(skin,Vector3.UP*y,[Vector2(.16,.025),Vector2(.16,.11)])
  skin.part="tina_fence_wood"
  if serial>=11378:
   skin.part="snowroof"
   if arms.y>arms.x:skin.box(AABB(Vector3(arms.x*1.54,y+.15,-.10),Vector3((arms.y-arms.x)*1.54,.055,.20)))
   if arms.w>arms.z:skin.box(AABB(Vector3(-.10,y+.15,arms.z*1.54),Vector3(.20,.055,(arms.w-arms.z)*1.54)))
   skin.part="tina_fence_wood"
 if serial>=11378:
  skin.part="snowroof";Parts.kili_round(skin,Vector3.UP*height,[Vector2(.15,0),Vector2(.12,.06),Vector2(0,.08)])

static func timber_log(skin,at:Vector3,axis:Vector3,length_:float,radius:float,bark:String="tina_log_bark",end_paint:String="tina_log_end"):
 var tangent=Vector3.UP.cross(axis);var previous=skin.part
 for i in 12:
  var a=-i*TAU/12;var b=-(i+1)*TAU/12
  var p=Vector3.UP*cos(a)*radius+tangent*sin(a)*radius;var q=Vector3.UP*cos(b)*radius+tangent*sin(b)*radius
  skin.part=bark
  skin.quad(at+p-axis*length_*.5,at+p+axis*length_*.5,at+q+axis*length_*.5,at+q-axis*length_*.5)
  skin.part=end_paint
  for side in [-1,1]:
   var points=[at+axis*side*length_*.5,at+p+axis*side*length_*.5,at+q+axis*side*length_*.5]
   var samples=[Vector2(.5,.5),Vector2(.5+sin(a)*.45,.5-cos(a)*.45),Vector2(.5+sin(b)*.45,.5-cos(b)*.45)]
   if (points[2]-points[0]).cross(points[1]-points[0]).dot(axis*side)<0:points.reverse();samples.reverse()
   for j in 3:
    skin.surface.set_normal(axis*side);skin.surface.set_uv2(skin.tiles[skin.part]);skin.surface.set_uv(samples[j]);skin.surface.add_vertex(points[j])
 skin.part=previous

static func flat_logs(skin,serial:int,w:float,d:float,center:Vector3):
 var axis=Vector3.BACK if serial==11462 else Vector3.RIGHT
 var across=Vector3.RIGHT if serial==11462 else Vector3.BACK
 var width=w if serial==11462 else d;var length_=d if serial==11462 else w
 var radius=width*.085
 for i in 5:timber_log(skin,center+across*(i-2)*radius*1.94+Vector3.UP*radius,axis,length_*.90,radius)

static func wood_shelter(native,skin,w:float,d:float,height:float):
 var wall=height*.64
 for side in [-1,1]:
  var points=[Vector3(side*w*.60,wall,-d*.54),Vector3(0,height,-d*.54),Vector3(0,height,d*.54),Vector3(side*w*.60,wall,d*.54)]
  outward_quad(native,points,[Vector2(0,58),Vector2(25,4),Vector2(171,105),Vector2(145,156)],Vector3(side,1,0))
 skin.part="timber"
 for z in [-d*.44,d*.44]:
  for x in [-w*.43,w*.43]:skin.box(AABB(Vector3(x-.08,0,z-.08),Vector3(.16,wall,.16)))
 for row in 2:
  for column in 4-row:
   timber_log(skin,Vector3((column-(3-row)*.5)*w*.22,.30+row*.52,0),Vector3.BACK,d*.90,w*.12)
 # Native hanging yellow hides project in front of the raised log stack.
 painted_quad(native,Vector3(-w*.48,wall*.22,-d*.44),Vector3(-w*.48,wall*.78,-d*.44),Vector3(-w*.48,wall*.78,d*.44),Vector3(-w*.48,wall*.22,d*.44),[Vector2(36,131),Vector2(36,94),Vector2(130,145),Vector2(130,181)])

const CRATES={
 11016:[[Vector2(4,34),Vector2(42,3),Vector2(86,35),Vector2(48,63)],[Vector2(4,34),Vector2(48,63),Vector2(48,110),Vector2(5,80)],[Vector2(48,63),Vector2(86,35),Vector2(86,84),Vector2(48,110)]],
 11466:[[Vector2(11,31),Vector2(52,3),Vector2(99,33),Vector2(56,62)],[Vector2(13,34),Vector2(56,62),Vector2(56,112),Vector2(13,84)],[Vector2(56,62),Vector2(99,33),Vector2(99,82),Vector2(56,112)]],
 11467:[[Vector2(5,24),Vector2(35,4),Vector2(65,24),Vector2(35,44)],[Vector2(5,24),Vector2(35,44),Vector2(35,67),Vector2(5,49)],[Vector2(35,44),Vector2(65,24),Vector2(65,49),Vector2(35,67)]],
 11468:[[Vector2(4,28),Vector2(42,3),Vector2(86,34),Vector2(48,59)],[Vector2(4,30),Vector2(48,59),Vector2(48,108),Vector2(5,77)],[Vector2(48,59),Vector2(86,35),Vector2(86,85),Vector2(48,108)]],
 11469:[[Vector2(3,17),Vector2(29,3),Vector2(55,18),Vector2(31,34)],[Vector2(3,18),Vector2(31,34),Vector2(31,65),Vector2(4,50)],[Vector2(31,34),Vector2(55,18),Vector2(55,49),Vector2(31,65)]]
}
static func crate(native,skin,serial:int,w:float,d:float,height:float,center:Vector3):
 var x=w*.37;var z=d*.37;var h=height*.9;var faces:Array=CRATES[serial]
 painted_quad(native,center+Vector3(-x,h,-z),center+Vector3(x,h,-z),center+Vector3(x,h,z),center+Vector3(-x,h,z),faces[0])
 for side in [-1,1]:
  var left:Array=faces[1];var right:Array=faces[2]
  painted_quad(native,center+Vector3(side*x,0,side*z),center+Vector3(side*x,h,side*z),center+Vector3(side*x,h,-side*z),center+Vector3(side*x,0,-side*z),[left[3],left[0],left[1],left[2]])
  painted_quad(native,center+Vector3(-side*x,0,side*z),center+Vector3(-side*x,h,side*z),center+Vector3(side*x,h,side*z),center+Vector3(side*x,0,side*z),[right[3],right[0],right[1],right[2]])
 skin.part="tina_crate_trim"
 for a in [-1,1]:
  for b in [-1,1]:skin.box(AABB(center+Vector3(a*x-.045,0,b*z-.045),Vector3(.09,h+.02,.09)))
 if serial==11466:
  skin.part="tina_soft_snow"
  Parts.kili_round(skin,center,[Vector2(w*.47,0),Vector2(w*.42,.10),Vector2(w*.35,.17)])

static func pub_details(native,skin,body:Vector3,w:float,d:float,h:float,serial:int=11416):
 var offset=Vector2(20,3) if serial==11415 else Vector2.ZERO
 var quad:Array=crops()["tina_%d_left"%serial][1]
 # The archive has two ground kegs; the old third keg and stacked boxes covered its carved corner post.
 for i in 2:
  var at=face_point(Vector2(135+25*i,318+15*i)+offset,quad,body,w,d,h,"left")
  at.x-=.85;at.y=.50
  var radius=d*.083*(1.0 if i==0 else .85);var height=h*(.36 if i==0 else .30)
  skin.part="tina_barrel_red"
  Parts.kili_round(skin,at,[Vector2(0,0),Vector2(radius*.82,0),Vector2(radius,height*.20),Vector2(radius,height*.78),Vector2(radius*.80,height),Vector2(0,height)])
  skin.part="tina_barrel_hoop"
  for level in [.17,.80]:Parts.kili_round(skin,at+Vector3.UP*height*level,[Vector2(radius*1.01,0),Vector2(radius*1.01,.10)])
  if i==0:
   skin.part="tina_barrel_red"
   Parts.kili_round(skin,at+Vector3.UP*height,[Vector2(radius*.40,0),Vector2(radius*.45,height*.28),Vector2(radius*.36,height*.28),Vector2(radius*.34,height*.06)])
   skin.part="tina_barrel_hoop"
   for level in [.03,.23]:Parts.kili_round(skin,at+Vector3.UP*(height+height*level),[Vector2(radius*.45,0),Vector2(radius*.45,.065)])
  if serial==11415:
   skin.part="tina_soft_snow"
   Parts.kili_round(skin,at+Vector3.UP*(height+.02),[Vector2(radius*(.46 if i==0 else 0),0),Vector2(radius*.82,0),Vector2(radius*.85,.07),Vector2(radius*(.46 if i==0 else 0),.07)])
 pub_post(native,body+Vector3(-w*.5-1.15,.5,d*.5+.65),d*.14,h*.78,offset)

 # Keep the painted lettering and frame at their actual facade coordinates.
 var pixels=[Vector2(158,239),Vector2(189,259),Vector2(189,278),Vector2(158,258)]
 var points=[]
 for i in pixels.size():pixels[i]+=offset
 for pixel in pixels:points.append(face_point(pixel,quad,body,w,d,h,"left")+Vector3.LEFT*.16)
 outward_quad(native,points,pixels,Vector3.LEFT)
 for i in 4:
  var j=(i+1)%4
  painted_quad(native,points[i],points[i]+Vector3.RIGHT*.16,points[j]+Vector3.RIGHT*.16,points[j],[pixels[i],pixels[i],pixels[j],pixels[j]])

static func pub_post(native,at:Vector3,width:float,height:float,offset:Vector2=Vector2.ZERO,profile:Array=[],faces:Array=[]):
 # Preserve the carved source faces on a solid corner post, including the stepped cap.
 var levels=[[0.0,.72],[.70,.72],[.72,1.0],[.78,1.0],[.80,.78],[.91,.78],[.94,.52],[1.0,.04]]
 var left=[[Vector2(170,383),Vector2(190,397)],[Vector2(170,316),Vector2(190,330)],[Vector2(151,302),Vector2(192,327)],[Vector2(153,293),Vector2(192,317)],[Vector2(173,290),Vector2(196,305)],[Vector2(173,278),Vector2(196,293)],[Vector2(178,278),Vector2(197,291)],[Vector2(197,265),Vector2(197,265)]]
 var right=[[Vector2(190,397),Vector2(211,383)],[Vector2(190,330),Vector2(211,316)],[Vector2(192,327),Vector2(221,307)],[Vector2(192,317),Vector2(221,298)],[Vector2(196,305),Vector2(213,294)],[Vector2(196,293),Vector2(213,282)],[Vector2(197,291),Vector2(213,280)],[Vector2(197,265),Vector2(197,265)]]
 if not profile.is_empty():levels=profile
 if not faces.is_empty():left=faces[0];right=faces[1]
 for side in 4:
  var corners=[Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]
  var a:Vector2=corners[side];var b:Vector2=corners[(side+1)%4]
  var pixels:Array=left if side%2==0 else right
  for i in levels.size()-1:
   var lo:Array=levels[i];var hi:Array=levels[i+1]
   var points=[at+Vector3(a.x*width*lo[1],height*lo[0],a.y*width*lo[1]),at+Vector3(a.x*width*hi[1],height*hi[0],a.y*width*hi[1]),at+Vector3(b.x*width*hi[1],height*hi[0],b.y*width*hi[1]),at+Vector3(b.x*width*lo[1],height*lo[0],b.y*width*lo[1])]
   painted_quad(native,points[0],points[1],points[2],points[3],[pixels[i][0]+offset,pixels[i+1][0]+offset,pixels[i+1][1]+offset,pixels[i][1]+offset])
