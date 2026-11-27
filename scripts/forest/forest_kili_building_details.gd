extends RefCounted
## Source-specific terrace contours and raised entrance/sign paint on the existing solid shells.
# shortcut: Native art has one view; rear contours and fine relief depth remain fitted.
const Parts=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Native=preload("res://scripts/forest/forest_venoa_buildings.gd")
const Roofs=preload("res://scripts/forest/forest_tina_building_details.gd")
const DOORS={
 11289:[0,[[72,290],[72,225],[77,213],[88,210],[103,218],[108,231],[108,313]]],
 11290:[1,[[225,317],[225,229],[232,212],[245,199],[257,198],[262,209],[262,290]]],
 11292:[0,[[52,311],[52,247],[68,237],[78,244],[78,330]]],
 11293:[0,[[58,385],[58,323],[61,306],[73,293],[86,301],[94,319],[94,407]]],
 11294:[0,[[87,338],[87,281],[91,269],[100,265],[107,278],[107,355]]],
}
# Individual low, rounded cap rhythms for the native terrace families, in source pixels.
const CAPS={11289:[13,8,10,6,12,7],11290:[10,6,13,8,11,7],11292:[11,7,9,16,8],11293:[8,12,7,10,6],11294:[12,8,10,18,9,7],11295:[13,7,11,8],11297:[9,7,18,8],11298:[10,6,14,8]}
static func terrace(walls,skin,w:float,d:float,h:float,at:Vector3,white:bool,serial:int):
 skin.part="white" if white else "roof"
 skin.quad(at+Vector3(-w*.5,h+.02,-d*.5),at+Vector3(w*.5,h+.02,-d*.5),at+Vector3(w*.5,h+.02,d*.5),at+Vector3(-w*.5,h+.02,d*.5))
 var corners=[Vector3(-w*.5,0,-d*.5),Vector3(-w*.5,0,d*.5),Vector3(w*.5,0,d*.5),Vector3(w*.5,0,-d*.5)]
 var rhythm:Array=CAPS.get(serial,[10,7,12,8])
 for edge in 4:
  var a:Vector3=corners[edge]+at;var b:Vector3=corners[(edge+1)%4]+at
  var tangent=(b-a).normalized();var inward=Vector3(tangent.z,0,-tangent.x)*.34
  var count_=maxi(2,roundi(a.distance_to(b)/1.8));var profile=[]
  for i in count_:
   var cap=float(rhythm[(i+edge)%rhythm.size()])*.045
   for station in [[0.,.26],[.10,.28],[.20,.28+cap*.85],[.35,.28+cap],[.65,.28+cap],[.80,.28+cap*.85],[.90,.28],[1.,.26]]:
    profile.append(a.lerp(b,(i+station[0])/count_)+Vector3.UP*(h+station[1]))
  for i in profile.size()-1:
   var p:Vector3=profile[i];var q:Vector3=profile[i+1]
   var base_a=Vector3(p.x,h,p.z);var base_b=Vector3(q.x,h,q.z)
   if white:
    skin.part="white";skin.quad(base_a,p,q,base_b)
   else:walls.quad(base_a,p,q,base_b)
   skin.part="white" if white else "plaster"
   skin.quad(p+inward,base_a+inward,base_b+inward,q+inward)
   skin.part="white" if white else "trim"
   skin.quad(p+inward,q+inward,q,p)

static func relief(walls,serial:int,w:float,d:float):
 if not DOORS.has(serial):return
 var corners=[Vector3(-w*.5,0,-d*.5),Vector3(-w*.5,0,d*.5),Vector3(w*.5,0,d*.5)]
 var row:Array=DOORS[serial];var edge=int(row[0]);var a:Vector3=corners[edge];var b:Vector3=corners[edge+1]
 var normal=Vector3(-(b-a).z,0,(b-a).x).normalized()
 var pixels=[];var points=[]
 for p in row[1]:
  var pixel=Vector2(p[0],p[1]);pixels.append(pixel);points.append(Native.on_plane(pixel,a,b,walls.graphic[1])+normal*.08)
 var triangles=Geometry2D.triangulate_polygon(PackedVector2Array(pixels))
 for i in range(0,triangles.size(),3):
  var a_=triangles[i];var b_=triangles[i+1];var c_=triangles[i+2]
  var n=(points[c_]-points[a_]).cross(points[b_]-points[a_]).normalized()
  for index in [a_,b_,c_]:
   walls.surface.set_normal(n);walls.surface.set_uv((walls.graphic[0].position+pixels[index])/walls.texture.get_size());walls.surface.add_vertex(points[index])
 for i in points.size():
  var next=(i+1)%points.size();walls.quad(points[i],points[next],points[next]-normal*.08,points[i]-normal*.08)
 if serial==11292:
  var p=Native.on_plane(Vector2(63,239),a,b,walls.graphic[1])+normal*.18
  var side=(b-a).normalized()*.73;var up=Vector3.UP*.43
  Roofs.painted_quad(walls,p-side-up,p-side+up,p+side+up,p+side-up,[Vector2(49,251),Vector2(49,238),Vector2(77,220),Vector2(77,233)])
