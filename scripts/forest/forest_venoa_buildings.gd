extends RefCounted
## Native visible foundations, roof curves and roof furniture; no physics or frame work.
# shortcut: One source angle establishes visible stations; concealed depth and rear faces remain inferred.
const Data=preload("res://assets/maps/falan/venoa_buildings.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Roofs=preload("res://scripts/forest/forest_tina_building_details.gd")
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const HORIZONTAL=32.0/3.0
const PIXEL_HEIGHT=.045
static var meshes={}

static func v(p:Array)->Vector2:return Vector2(p[0],p[1])
static func project(p:Vector3,origin:Vector2)->Vector2:
 return origin+Vector2((p.x+p.z)*HORIZONTAL,(p.z-p.x)*8.0-p.y/PIXEL_HEIGHT)

static func at_height(pixel:Vector2,height:float,origin:Vector2)->Vector3:
 var u=(pixel.x-origin.x)/HORIZONTAL
 var w=(pixel.y-origin.y+height/PIXEL_HEIGHT)/8.0
 return Vector3((u-w)*.5,height,(u+w)*.5)

static func delta(pixel:Vector2)->Vector3:
 return Vector3((pixel.x/HORIZONTAL-pixel.y/8.0)*.5,0,(pixel.x/HORIZONTAL+pixel.y/8.0)*.5)

static func on_plane(pixel:Vector2,a:Vector3,b:Vector3,origin:Vector2)->Vector3:
 var pa=project(Vector3(a.x,0,a.z),origin);var pb=project(Vector3(b.x,0,b.z),origin)
 var p=a.lerp(b,inverse_lerp(pa.x,pb.x,pixel.x))
 p.y=(project(Vector3(p.x,0,p.z),origin).y-pixel.y)*PIXEL_HEIGHT
 return p

static func roof_quads(profile:Array,rear:Vector3,back:Array=[])->Array:
 var result=[]
 for i in profile.size()-1:
  var quad=[profile[i],profile[i]+rear if back.is_empty() else back[i],profile[i+1]+rear if back.is_empty() else back[i+1],profile[i+1]]
  if (quad[2]-quad[0]).cross(quad[1]-quad[0]).y<0:quad.reverse()
  result.append(quad)
 return result

static func surface_point(pixel:Vector2,quads:Array,origin:Vector2)->Vector3:
 var result=Vector3.INF;var nearest=-INF
 for quad in quads:
  for triangle in [[0,1,2],[0,2,3]]:
   var a:Vector3=quad[triangle[0]];var b:Vector3=quad[triangle[1]];var c:Vector3=quad[triangle[2]]
   var pa=project(a,origin);var u=project(b,origin)-pa;var w=project(c,origin)-pa
   var det=u.cross(w)
   if absf(det)<.00001:continue
   var d=pixel-pa;var s=d.cross(w)/det;var t=u.cross(d)/det
   if s<-.001 or t<-.001 or s+t>1.001:continue
   var p=a+(b-a)*s+(c-a)*t
   var depth=p.dot(Vector3(-1.0,16.0*PIXEL_HEIGHT,1.0))
   if depth>nearest:result=p;nearest=depth
 assert(result.is_finite(),"A native roof fixture must meet its actual roof: "+str(pixel))
 return result

static func hull(points:Array,origin:Vector2)->PackedVector2Array:
 var pixels=PackedVector2Array()
 for p:Vector3 in points:pixels.append(project(p,origin))
 var polygon=Geometry2D.convex_hull(pixels)
 if polygon.size()>1 and polygon[0].is_equal_approx(polygon[-1]):polygon.remove_at(polygon.size()-1)
 return polygon

static func loft(skin,profile:Array,rear:Vector3,base:float,origin:Vector2,cutouts:Array=[],back_profile:Array=[]):
 var back=back_profile
 if back.is_empty():
  back=[]
  for p:Vector3 in profile:back.append(p+rear)
 for quad in roof_quads(profile,rear,back):
  var pixels=[]
  for p in quad:pixels.append(project(p,origin).clamp(Vector2.ONE*.5,skin.graphic[0].size-Vector2.ONE*.5))
  Roofs.roof_quad(skin,quad,pixels,cutouts)
 for i in profile.size()-1:
  var a:Vector3=profile[i];var b:Vector3=profile[i+1]
  skin.quad(a,b,Vector3(b.x,base,b.z),Vector3(a.x,base,a.z))
  var back_a:Vector3=back[i];var back_b:Vector3=back[i+1]
  skin.quad(back_b,back_a,Vector3(back_a.x,base,back_a.z),Vector3(back_b.x,base,back_b.z))
 for i in [0,profile.size()-1]:
  var p:Vector3=profile[i];var q:Vector3=back[i]
  var corners=[p,Vector3(p.x,base,p.z),Vector3(q.x,base,q.z),q]
  if i==0:corners.reverse()
  skin.quad(corners[0],corners[1],corners[2],corners[3])

static func opening(skin,center:Vector3,width:float,pixel:Vector2):
 # Reuse the original flue's dark interior pigment below the solid rim.
 var points=[center+Vector3(-width*.5,0,-width*.5),center+Vector3(width*.5,0,-width*.5),center+Vector3(width*.5,0,width*.5),center+Vector3(-width*.5,0,width*.5)]
 Roofs.painted_quad(skin,points[0],points[3],points[2],points[1],[pixel,pixel,pixel,pixel])

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var row:Dictionary=Data.FORMS[serial]
 var r:Array=row.rect;var rect=Rect2(r[0],r[1],r[2],r[3]);var origin=v(row.origin)
 var skin=Source.new([rect,origin,Vector2.ONE,0],Data.ATLAS,PIXEL_HEIGHT)
 var feet=[]
 for pixel in row.floor:feet.append(at_height(v(pixel),0,origin))
 feet.append(feet[0]+feet[2]-feet[1])
 skin.projection_center=(feet[0]+feet[1]+feet[2]+feet[3])*.25
 var edge=[feet[0],feet[1]] if row.end=="left" else [feet[1],feet[2]]
 var axis:Vector3=edge[1]-edge[0];var normal=Vector3(-axis.z,0,axis.x).normalized()
 var profile=[]
 for pixel in row.roof:profile.append(on_plane(v(pixel),edge[0]+normal*.35,edge[1]+normal*.35,origin))
 var rear=delta(v(row.rear)-v(row.roof[row.peak]))
 var back_profile=[]
 if row.has("back_roof"):
  for pixel in row.back_roof:back_profile.append(on_plane(v(pixel),edge[0]+normal*.35+rear,edge[1]+normal*.35+rear,origin))
 var quads=roof_quads(profile,rear,back_profile)
 var body_height=minf(profile[0].y,profile[-1].y)
 var bottom:float=row.get("bottom",0.0)
 assert(body_height>bottom,"The native facade must have positive wall height")
 for i in 4:
  var a:Vector3=feet[i];var b:Vector3=feet[(i+1)%4]
  skin.quad(a+Vector3.UP*bottom,a+Vector3.UP*body_height,b+Vector3.UP*body_height,b+Vector3.UP*bottom)
 skin.quad(feet[0]+Vector3.UP*body_height,feet[3]+Vector3.UP*body_height,feet[2]+Vector3.UP*body_height,feet[1]+Vector3.UP*body_height)
 var cutouts=[];var raised=[]
 var features:Array=row.get("dormers",[]).duplicate()
 features.append_array(row.get("porches",[]))
 if row.has("bell"):features.append(row.bell)
 for feature in features:
  var face=[feet[0],feet[1]] if feature.face=="left" else [feet[1],feet[2]]
  var along:Vector3=face[1]-face[0];var outward=Vector3(-along.z,0,along.x).normalized()
  var station=on_plane(v(feature.anchor),face[0],face[1],origin) if feature in row.get("porches",[]) else surface_point(v(feature.anchor),quads,origin)
  var tangent=Vector3.UP.cross(outward)
  var front=[]
  for pixel in feature.roof:front.append(on_plane(v(pixel),station-tangent,station+tangent,origin))
  var back=delta(v(feature.rear)-v(feature.roof[feature.peak]))
  var base=station.y-.08
  for p in front:base=minf(base,p.y-.08)
  var bounds=front.duplicate()
  for p:Vector3 in front:bounds.append(p+back);bounds.append(Vector3(p.x,base,p.z));bounds.append(Vector3(p.x+back.x,base,p.z+back.z))
  cutouts.append(hull(bounds,origin));raised.append([front,back,base,feature,station])
 var stacks=[]
 for spec in row.get("flues",[]):
  var station=surface_point(v(spec[0]),quads,origin)
  var height=(spec[0][1]-spec[1][1])*PIXEL_HEIGHT
  stacks.append([station,height,float(spec[2]),v(spec[3]),false,{}])
 for spec in row.get("pots",[]):
  var station=at_height(v(spec.base),0,origin) if spec.get("ground",false) else surface_point(v(spec.base),quads,origin)
  var height=(spec.base[1]-spec.top[1])*PIXEL_HEIGHT
  stacks.append([station,height,float(spec.width),v(spec.top),true,spec])
 for stack in stacks:
  var p:Vector3=stack[0];var height:float=stack[1];var width:float=stack[2]
  var points=[]
  for x in [-1,1]:
   for z in [-1,1]:
    for y in [0.0,height]:points.append(p+Vector3(x*width*.5,y,z*width*.5))
  cutouts.append(hull(points,origin))
 loft(skin,profile,rear,body_height,origin,cutouts,back_profile)
 for item in raised:
  loft(skin,item[0],item[1],item[2],origin)
  if item[3].has("center"):
   var station:Vector3=item[4];var tangent=Vector3.FORWARD
   var center=on_plane(v(item[3].center),station-tangent,station+tangent,origin)
   Parts.kili_round(skin,center-Vector3.UP*.35,[Vector2(.55,0),Vector2(.57,.10),Vector2(.40,.24),Vector2(.28,.65),Vector2(.10,.90)])
   for z in [-.85,.85]:skin.box(AABB(station+Vector3(-.10,0,z-.10),Vector3(.20,2.7,.20)))
 for stack in stacks:
  var p:Vector3=stack[0];var height:float=stack[1];var width:float=stack[2]
  var shaft=width*.76
  skin.box(AABB(p+Vector3(-shaft*.5,-.15,-shaft*.5),Vector3(shaft,height+(.15 if stack[4] else -.25),shaft)))
  if stack[4]:
   skin.box(AABB(p+Vector3(-width*.5,height-.22,-width*.5),Vector3(width,.24,width)))
   for hole in stack[5].holes:
    var top=at_height(v(hole),p.y+height+1.6,origin)
    var foot=Vector3(top.x,p.y+height,top.z)
    Parts.kili_round(skin,foot,[Vector2(.45,0),Vector2(.48,1.42),Vector2(.55,1.49),Vector2(.55,1.60),Vector2(.38,1.60),Vector2(.38,1.10)])
    opening(skin,foot+Vector3.UP*1.09,.69,v(hole))
  else:
   var rim=.28
   for side in [-1,1]:
    skin.box(AABB(p+Vector3(-width*.5,height-.20,side*(width-rim)*.5-rim*.5),Vector3(width,.30,rim)))
    skin.box(AABB(p+Vector3(side*(width-rim)*.5-rim*.5,height-.20,-width*.5+rim),Vector3(rim,.30,width-rim*2)))
   opening(skin,p+Vector3.UP*(height-.21),shaft*.94,stack[3])
 for foot in row.get("supports",[]):
  var p=at_height(v(foot),0,origin)
  skin.box(AABB(p+Vector3(-.28,0,-.28),Vector3(.56,bottom+.18,.56)))
  for y in [.12,bottom-.12]:skin.box(AABB(p+Vector3(-.43,y,-.43),Vector3(.86,.20,.86)))
 for stair in row.get("stairs",[]):
  var upper_a=at_height(v(stair[0]),bottom,origin);var upper_b=at_height(v(stair[1]),bottom,origin)
  var lower_a=at_height(v(stair[3]),0,origin);var lower_b=at_height(v(stair[2]),0,origin)
  for step in 8:
   var t=step/8.0;var next=(step+1)/8.0;var height=bottom*(1-t)
   var a=upper_a.lerp(lower_a,t);var b=upper_b.lerp(lower_b,t)
   var c=upper_b.lerp(lower_b,next);var d=upper_a.lerp(lower_a,next)
   a.y=height;b.y=height;c.y=height;d.y=height
   skin.quad(a,b,c,d)
   skin.quad(d,Vector3(d.x,height-bottom/8,d.z),Vector3(c.x,height-bottom/8,c.z),c)
 for i in maxi(0,row.get("yard",[]).size()-1):
  var a=at_height(v(row.yard[i]),0,origin);var b=at_height(v(row.yard[i+1]),0,origin)
  var offset=Vector3(-(b-a).z,0,(b-a).x).normalized()*.20
  var up=Vector3.UP*3.4
  skin.quad(a+offset,a+offset+up,b+offset+up,b+offset)
  skin.quad(b-offset,b-offset+up,a-offset+up,a-offset)
  skin.quad(a+offset+up,a-offset+up,b-offset+up,b+offset+up)
  skin.quad(a-offset,a-offset+up,a+offset+up,a+offset)
  skin.quad(b+offset,b+offset+up,b-offset+up,b-offset)
 if row.has("yard_post"):
  var foot=at_height(v(row.yard_post),0,origin)
  Parts.kili_round(skin,foot,[Vector2(0,0),Vector2(.44,0),Vector2(.44,4.9),Vector2(.52,4.95),Vector2(.52,5.08),Vector2(.28,5.12),Vector2(.52,5.35),Vector2(.55,5.55),Vector2(.40,5.78),Vector2(0,5.9)])
 var frame=Proportions.native_coastal_frame()
 var mesh=Proportions.transformed(skin.finish(),frame);mesh.set_meta("original_graphic",serial)
 for i in profile.size():profile[i]=frame*profile[i]
 rear=frame.basis*rear
 for quad in quads:
  for i in quad.size():quad[i]=frame*quad[i]
 mesh.set_meta("native_foundation",row.floor);mesh.set_meta("native_roof_profile",row.roof)
 mesh.set_meta("native_roof_points",profile);mesh.set_meta("native_roof_rear",rear)
 mesh.set_meta("native_roof_quads",quads);mesh.set_meta("native_origin",origin)
 meshes[serial]=mesh
 return mesh
