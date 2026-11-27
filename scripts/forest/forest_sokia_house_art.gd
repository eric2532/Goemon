extends RefCounted
## Sokia fixed rooms keep their own source fixtures and plain wall sections.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const OWN=[17024,16621,16631,17562,17563,17565,11094,11102,11033,10047,10048,16134]
static func owns(serial:int,family:String="")->bool:return family=="room_wall" or serial in OWN or serial in range(16894,16928) or serial in range(13254,13265)
static func wall_ring(points:Array,g:Dictionary,height:float)->Array:
 var polygon=[];var center=Vector2.ZERO
 for point in points:
  var pixel=Vector2(point[0]+g.origin[0],point[1]+g.origin[1])
  var at=Vector2((pixel.x/Fit.HORIZONTAL-(pixel.y+height*Fit.VERTICAL)/Fit.FLOOR)*.5,(pixel.x/Fit.HORIZONTAL+(pixel.y+height*Fit.VERTICAL)/Fit.FLOOR)*.5)
  polygon.append(at);center+=at
 center/=polygon.size()
 var result=[]
 for i in 32:
  var direction=Vector2.from_angle(i*TAU/32);var at=center
  for j in polygon.size():
   var hit=Geometry2D.segment_intersects_segment(center,center+direction*10000,polygon[j],polygon[(j+1)%polygon.size()])
   if hit!=null:at=hit;break
  result.append(Vector3(at.x,height,at.y))
 return result

static func mesh(serial:int,g:Dictionary,texture:Texture2D,cap:Dictionary={})->Mesh:
 var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var skin=Source.new([rect,-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,1./Fit.VERTICAL)
 var h=maxf(.3,(-float(g.origin[1])-24)/Fit.VERTICAL)
 if serial in [10047,10048]:
  var art=load("res://scripts/forest/forest_original_map_art.gd").data()
  var column:Dictionary=art.graphics["10048"]
  var raw=Forms.mesh(10048,"column",column,texture)
  var target=Rect2(-47,-225,92,244)
  var pose=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),target)
  var fitted=Fit.transformed(raw,pose)
  var arrays=fitted.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_VERTEX].size():skin.vertex(arrays[Mesh.ARRAY_VERTEX][i],arrays[Mesh.ARRAY_NORMAL][i])
  if serial==10047:
   var top=fitted.get_aabb().end.y
   skin.box(AABB(Vector3(-.75,top-2.8,-12),Vector3(1.5,2.8,12)))
 elif serial in range(13254,13265):
  skin.box(AABB(Vector3(-1.5,0,-1.5),Vector3(3,4.3,3)))
 elif serial==16134:
  var top=9.1
  skin.box(AABB(Vector3(-2.4,top,-.8),Vector3(4.8,.08,1.6)))
 elif not cap.is_empty():
  var height=float(cap.height_pixels)/Fit.VERTICAL;var top=wall_ring(cap.polygon,g,height)
  var base=wall_ring(cap.base,g,0.) if cap.get("base",[]).size()>=3 else []
  for i in range(1,top.size()-1):
   skin.vertex(top[0],Vector3.UP);skin.vertex(top[i],Vector3.UP);skin.vertex(top[i+1],Vector3.UP)
  for i in top.size():
   var a:Vector3=top[i];var b:Vector3=top[(i+1)%top.size()]
   skin.quad(base[i] if not base.is_empty() else Vector3(a.x,0,a.z),base[(i+1)%top.size()] if not base.is_empty() else Vector3(b.x,0,b.z),b,a)
 elif serial in [17562,17563,17565]:
  # Wall notices are paint, with their original position above the floor.
  var corners=[]
  for uv in [Vector2.ZERO,Vector2(0,rect.size.y),rect.size,Vector2(rect.size.x,0)]:
   var pixel:Vector2=uv+Vector2(g.origin[0],g.origin[1]);var p:Vector3
   if serial==17565:
    var x=1.49;var z=pixel.x/Fit.HORIZONTAL-x
    p=Vector3(x,((z-x)*8-pixel.y)/Fit.VERTICAL,z)
   else:
    var z=-1.49;var x=pixel.x/Fit.HORIZONTAL-z
    p=Vector3(x,((z-x)*8-pixel.y)/Fit.VERTICAL,z)
   corners.append(p)
  skin.quad(corners[0],corners[1],corners[2],corners[3])
 elif g.family=="room_wall" or serial in range(16894,16928) or serial==16621:
  skin.box(AABB(Vector3(-1.5,0,-1.5),Vector3(3,h,3)))
 elif serial==17024:
  Forms.Buildings.kili_round(skin,Vector3.ZERO,[Vector2(1.8,h*.88),Vector2(1.8,h),Vector2(0,h)])
  skin.box(AABB(Vector3(-.16,.2,-.16),Vector3(.32,h*.73,.32)))
  skin.box(AABB(Vector3(-1.2,0,-.15),Vector3(2.4,.2,.3)))
  skin.box(AABB(Vector3(-.15,0,-1.2),Vector3(.3,.2,2.4)))
 elif serial==11094:
  for row in 2:
   for column in 2:
    skin.box(AABB(Vector3(-1.5+column*1.5,row*h*.48,-1.2),Vector3(1.45,h*.48,2.4)))
 elif serial==11033:
  skin.box(AABB(Vector3(-1.1,0,-.6),Vector3(2.2,h,1.2)))
 elif serial==11102:
  Forms.Buildings.kili_round(skin,Vector3.ZERO,[Vector2(1.1,0),Vector2(1.25,h*.9),Vector2(1.1,h),Vector2(.97,h*.86),Vector2(.88,h*.3)])
 elif serial==16631:
  for z in [-7.5,1.2]:skin.box(AABB(Vector3(-.14,0,z-.14),Vector3(.28,h,.28)))
  skin.box(AABB(Vector3(-.13,h*.91,-7.6),Vector3(.26,.22,8.9)))
  for i in 20:
   var a=float(i)/20;var b=float(i+1)/20
   var za=lerpf(-7.3,1.,a);var zb=lerpf(-7.3,1.,b)
   var ya=h*(.38+.31*pow(absf(a-.5)*2,2));var yb=h*(.38+.31*pow(absf(b-.5)*2,2))
   skin.quad(Vector3(-.55,ya,za),Vector3(.55,ya,za),Vector3(.55,yb,zb),Vector3(-.55,yb,zb))
 var result=skin.finish()
 if g.family=="room_wall" or serial in range(16894,16928):
  var arrays=result.surface_get_arrays(0)
  var black=(rect.position+Vector2(rect.size.x*.5,5))/texture.get_size()
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   if arrays[Mesh.ARRAY_NORMAL][i].y>.5:arrays[Mesh.ARRAY_TEX_UV][i]=black
  result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(0,Source.material(texture))
 return result
