extends RefCounted
## Private exact ancient-tree assembly; source navigation remains with OriginalMaps.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const Trees=preload("res://scripts/forest/forest_east_tree_families.gd")
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
const ROOT="res://assets/maps/falan/east_region/root_compounds/"
static var catalog={}
static var prepared:Mesh
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func body_graphic()->Dictionary:
 var row:Dictionary=data().body
 return {"origin":row.native_origin,"rect":[0,0,row.native_size[0],row.native_size[1]],"footprint":[1,1]}
static func private_bark():
 var skin=Base.PreparedSkin.new([],load(ROOT+"bark-grain.png"),1./Base.Fit.VERTICAL)
 skin.tiles={"bark":Vector2.ZERO};skin.part="bark";skin.pitches.bark=2.6
 return skin
static func smooth_bark_normals(mesh:Mesh)->Mesh:
 # Independent body and neck share smooth ring normals; source paint and cavity
 # retain their own normals, vertices and UVs.
 var source:Array=mesh.get_meta("east_cpu_arrays");var result=ArrayMesh.new();var retained=[]
 for slot in source.size():
  var arrays:Array=source[slot]
  if slot in [0,3]:
   arrays=arrays.duplicate(true);var sums={};var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for index in range(0,vertices.size(),3):
    var face=(vertices[index+2]-vertices[index]).cross(vertices[index+1]-vertices[index])
    for corner in 3:
     var key=vertices[index+corner].snapped(Vector3.ONE*.00001);sums[key]=sums.get(key,Vector3.ZERO)+face
   for index in vertices.size():
    var n:Vector3=sums[vertices[index].snapped(Vector3.ONE*.00001)]
    if n.length_squared()>.0000001:arrays[Mesh.ARRAY_NORMAL][index]=n.normalized()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(slot,mesh.surface_get_material(slot));retained.append(arrays)
 result.set_meta("east_cpu_arrays",retained);return result
static func curved_root(wood,controls:Array,radii:Array):
 # Shared ring loft follows the original centerline controls. Buried joins are
 # open; only the observed ground toe rounds to its unchanged source endpoint.
 var centers=[];var widths=[]
 for segment in controls.size()-1:
  for step in 8:
   var t=step/8.;var before:Vector3=controls[maxi(0,segment-1)];var low:Vector3=controls[segment];var high:Vector3=controls[segment+1];var after:Vector3=controls[mini(controls.size()-1,segment+2)]
   centers.append(low.cubic_interpolate(high,before,after,t));widths.append(lerpf(radii[segment],radii[segment+1],t))
 var ending:Vector3=controls[-1];var toward:Vector3=(ending-centers[-1]).normalized();centers.append(ending-toward*.22);widths.append(.22);centers.append(ending);widths.append(0.)
 var rings=[]
 for i in centers.size():
  var direction:Vector3=(centers[mini(i+1,centers.size()-1)]-centers[maxi(0,i-1)]).normalized();var across=direction.cross(Vector3.UP).normalized()
  if across.length_squared()<.01:across=Vector3.RIGHT
  var rise=across.cross(direction).normalized();var ring=[]
  for side in 32:
   var angle=side*TAU/32.;var radial=(across*cos(angle)+rise*sin(angle))*float(widths[i]);radial.y*=1.25;ring.append(centers[i]+radial)
  rings.append(ring)
 for level in rings.size()-1:
  for side in 32:
   var next=(side+1)%32;wood.quad(rings[level][next],rings[level+1][next],rings[level+1][side],rings[level][side])
static func crown_spec()->Dictionary:
 var spec:Dictionary=Nature.data().graphics["11699"].duplicate(true)
 assert(spec.kind=="source_leaf_dome" and spec.native_rgba_sha256==data().crown.source_rgba_sha256,"Reuse the exact prepared native umbrella, not crossed full-crown cards")
 var bounds:Array=spec.visible;var u=(437.-float(bounds[0]))/float(bounds[2]-bounds[0]);var v=(511.-float(bounds[1]))/float(bounds[3]-bounds[1])
 spec.dome_height=8.;spec.base_height=327.*Base.OWNER_HEIGHT_PER_PIXEL-sin(u*PI)*sin(v*PI)*float(spec.dome_height)
 return spec
static func projected_pixel(p:Vector3,g:Dictionary)->Vector2:
 return Vector2((p.x+p.z)*Base.Fit.HORIZONTAL,(p.z-p.x)*8.-p.y*Base.Fit.VERTICAL)-Vector2(g.origin[0],g.origin[1])
static func native_surface(pixel:Vector2,g:Dictionary,arrays_list:Array)->Vector3:
 var direction=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 var source=Base.projected(pixel,g,0.,111.)+direction*150.;var nearest=INF;var result=source-direction*150.
 for arrays:Array in arrays_list:
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  for index in range(0,points.size(),3):
   var hit:Variant=Geometry3D.ray_intersects_triangle(source,-direction,points[index],points[index+1],points[index+2])
   if hit is Vector3 and source.distance_squared_to(hit)<nearest:nearest=source.distance_squared_to(hit);result=hit
 return result
static func emit_body_triangle(back,front,points:Array,normal:Vector3,eye:Vector3,core:Vector3):
 for p:Vector3 in points:
  back.surface.set_normal(normal);back.surface.set_uv(Vector2((atan2(p.z-core.z,p.x-core.x)+PI)/TAU*8.,-p.y/11.6));back.surface.set_uv2(Vector2.ZERO);back.surface.add_vertex(p)
 if normal.dot(eye)>0.:
  for p:Vector3 in points:front.projected_vertex(p+normal*.018,normal,p)
static func hollow_triangle(back,front,points:Array,normal:Vector3,eye:Vector3,core:Vector3,g:Dictionary,cavity:PackedVector2Array,cavity_bounds:Rect2,depth:int=0):
 var pixels=PackedVector2Array();var bounds:Rect2
 for index in 3:
  var pixel=projected_pixel(points[index],g);pixels.append(pixel)
  bounds=Rect2(pixel,Vector2.ZERO) if index==0 else bounds.expand(pixel)
 if normal.dot(eye)<=.001 or not bounds.intersects(cavity_bounds,true):emit_body_triangle(back,front,points,normal,eye,core);return
 if maxf(pixels[0].distance_to(pixels[1]),maxf(pixels[1].distance_to(pixels[2]),pixels[2].distance_to(pixels[0])))>14. and depth<6:
  var ab:Vector3=(points[0]+points[1])*.5;var bc:Vector3=(points[1]+points[2])*.5;var ca:Vector3=(points[2]+points[0])*.5
  for triangle in [[points[0],ab,ca],[ab,points[1],bc],[ca,bc,points[2]],[ab,bc,ca]]:hollow_triangle(back,front,triangle,normal,eye,core,g,cavity,cavity_bounds,depth+1)
  return
 var a:Vector2=pixels[1]-pixels[0];var b:Vector2=pixels[2]-pixels[0];var determinant=a.cross(b)
 if absf(determinant)<.000001:emit_body_triangle(back,front,points,normal,eye,core);return
 for polygon:PackedVector2Array in Geometry2D.clip_polygons(pixels,cavity):
  var indices=Geometry2D.triangulate_polygon(polygon)
  for start in range(0,indices.size(),3):
   var triangle=[]
   for corner in 3:
    var delta:Vector2=polygon[indices[start+corner]]-pixels[0];var u=delta.cross(b)/determinant;var v=a.cross(delta)/determinant
    triangle.append(points[0]+(points[1]-points[0])*u+(points[2]-points[0])*v)
   if (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).dot(normal)<0.:triangle.reverse()
   emit_body_triangle(back,front,triangle,normal,eye,core)
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var info:Dictionary=data();var g=body_graphic();var parts=[]
 # The visible upper wood narrows24/43/84pixels at BGrows10/35/70.
 # Continue only that waist into the canopy; the lower root fork leaves no broad ground cap.
 var trunk={"base":[364,327],"top":[385,0],"height_pixels":327,"diameter":200,"cut_stump":false,"trace":[[364,327,.14],[382,300,.55],[370,270,.85],[379,200,.95],[374,130,1.03],[386,70,.42],[388,35,.215],[385,0,.06]]}
 var original:Mesh=Base.living_tree_body(g,trunk);var wood=private_bark()
 # Existing source-traced branch primitive forms the observed buttress routes.
 # Physical thickness and the unseen continuation are inferred from each root.
 for route:Array in [
  [[354,110,210],[286,224,85],[198,309,18],[128,370,0]],
  [[357,150,177],[286,249,78],[224,281,25],[92,285,0]],
  [[375,130,197],[421,245,82],[444,332,25],[462,421,0]],
  [[390,120,207],[455,230,97],[496,309,32],[519,419,0]],
  [[398,110,217],[457,219,108],[536,265,24],[638,292,0]],
  [[358,80,247],[306,161,108],[235,180,22],[149,179,0]],
  [[401,80,247],[461,155,92],[535,184,19],[616,219,0]]]:
  var path=[]
  for p:Array in route:path.append(Base.point(Vector2(p[0],p[1]),float(p[2])/Base.Fit.VERTICAL,g))
  curved_root(wood,path,[2.8,1.8,.72,.22])
 # The unseen rear continues the source's broad buttress/root rhythm, rather
 # than ending in a plain cylindrical back. These inferred ribs stay closed.
 var core=Base.point(Vector2(364,327),0.,g);var trunk_top=Base.point(Vector2(385,0),327./Base.Fit.VERTICAL,g)
 for angle in [-1.40,-.70,0.,.70]:
  var radial=Vector3(cos(angle),0,sin(angle))
  # The rib enters the bole, rather than stopping visibly on its outside wall.
  curved_root(wood,[core+radial*7.2,core.lerp(trunk_top,.38)+radial*4.7,core.lerp(trunk_top,.72)+radial*2.0],[1.35,1.0,.22])
 var root_mesh:Mesh=wood.finish();var assembled:Mesh=Base.combine([original,root_mesh]);var back=private_bark();var front=Base.native_skin(g,load(ROOT+"body-front.png"));var eye=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 var cavity=PackedVector2Array()
 for p:Array in info.prototype.source_hollow_outline:cavity.append(Vector2(p[0],p[1]))
 var cavity_bounds=Rect2(cavity[0],Vector2.ZERO)
 for p:Vector2 in cavity:cavity_bounds=cavity_bounds.expand(p)
 for arrays:Array in assembled.get_meta("east_cpu_arrays"):
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for start in range(0,vertices.size(),3):
   hollow_triangle(back,front,[vertices[start],vertices[start+1],vertices[start+2]],normals[start],eye,core,g,cavity,cavity_bounds)
 parts.append(Base.bark_finish(back));parts.append(front.finish())
 # The native dark root hollow is a closed recess, not a new room or route.
 var recess=private_bark();var rim=[];var inner=[]
 for pixel:Vector2 in cavity:
  var at=native_surface(pixel,g,assembled.get_meta("east_cpu_arrays"));rim.append(at);inner.append(at-eye*float(info.prototype.inferred_hollow_depth))
 var midpoint=Vector3.ZERO
 for at:Vector3 in inner:midpoint+=at
 midpoint/=inner.size()
 for index in rim.size():
  var next=(index+1)%rim.size();recess.quad(rim[index],inner[index],inner[next],rim[next])
  var cap_normal:Vector3=(midpoint-inner[index]).cross(inner[next]-inner[index])
  if cap_normal.dot(eye)>0.:recess.quad(inner[index],inner[next],midpoint,midpoint)
  else:recess.quad(inner[index],midpoint,inner[next],inner[next])
 var cavity_mesh:Mesh=Base.bark_finish(recess);var dark:ShaderMaterial=cavity_mesh.surface_get_material(0).duplicate();dark.set_shader_parameter("base_color",Color(.22,.18,.12));cavity_mesh.surface_set_material(0,dark);parts.append(cavity_mesh)
 var crown_g={"origin":info.crown.native_origin,"rect":[0,0,info.crown.native_size[0],info.crown.native_size[1]],"footprint":[1,1]}
 # The hidden neck overlaps the trunk and enters opaque canopy pixels. Meeting
 # the projected bottom of crossed alpha cards alone left a visible physical gap.
 var neck=private_bark();var neck_bottom=trunk_top-Vector3.UP*2.
 var umbrella=crown_spec();var neck_top:Vector3=Nature.dome_point(Vector2(437,430),crown_g,umbrella,false).lerp(Nature.dome_point(Vector2(437,430),crown_g,umbrella,true),.5)
 neck_top.y/=Base.OWNER_Y_SCALE
 var neck_rings=[];var core_radius=200./(2.*Base.Fit.HORIZONTAL*sqrt(2.))*.06
 for layer in 5:
  var t=layer/4.;var center:Vector3=neck_bottom.lerp(neck_top,t);var radius=lerpf(core_radius,.20,t);var ring=[]
  for side in 48:
   var angle=side*TAU/48.;var wave=1.+.035*sin(angle*7.+5.)*(1.-t);ring.append(center+Vector3(cos(angle)*radius*wave,0,sin(angle)*radius*wave))
  neck_rings.append(ring)
 for layer in neck_rings.size()-1:
  for side in 48:
   var next=(side+1)%48;neck.quad(neck_rings[layer][next],neck_rings[layer+1][next],neck_rings[layer+1][side],neck_rings[layer][side])
 var neck_mesh:Mesh=neck.finish();var neck_back=private_bark();var neck_front=Base.native_skin(crown_g,load(ROOT+"native-crown-wood.png"))
 for arrays:Array in neck_mesh.get_meta("east_cpu_arrays"):
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for index in range(0,vertices.size(),3):
   for corner in 3:
    var at=index+corner;var p:Vector3=vertices[at]
    neck_back.surface.set_normal(normals[at]);neck_back.surface.set_uv(Vector2((atan2(p.z-core.z,p.x-core.x)+PI)/TAU*8.,-p.y/11.6));neck_back.surface.set_uv2(Vector2.ZERO);neck_back.surface.add_vertex(p)
   if normals[index].dot(eye)<=0.:continue
   for corner in 3:
    var at=index+corner;neck_front.projected_vertex(vertices[at]+normals[at]*.018,normals[at],vertices[at])
 parts.append(Base.bark_finish(neck_back));parts.append(neck_front.finish())
 # The original936x651 crown is a broad umbrella footprint. Reuse the existing
 # closed source-painted leaf dome; two vertical cards made a giant edge-on fin.
 var canopy:Mesh=Nature.leaf_dome(crown_g,umbrella)
 var upper:ShaderMaterial=canopy.surface_get_material(0).duplicate();upper.set_shader_parameter("base_texture",load(ROOT+"native-crown-leaves.png"));canopy.surface_set_material(0,upper)
 var underside:ShaderMaterial=canopy.surface_get_material(1).duplicate();underside.set_shader_parameter("base_texture",load(ROOT+"native-crown-leaves.png"));underside.set_shader_parameter("original_palette",false);underside.set_shader_parameter("base_color",Color(.65,.78,.58));canopy.surface_set_material(1,underside)
 parts.append(Base.transformed_existing(canopy,Transform3D(Basis.IDENTITY.scaled(Vector3(1.,1./Base.OWNER_Y_SCALE,1.)),Vector3.ZERO)))
 var limbs=private_bark()
 for target:Vector2 in [Vector2(305,516),Vector2(455,510)]:
  var end:Vector3=Nature.dome_point(target,crown_g,umbrella,false).lerp(Nature.dome_point(target,crown_g,umbrella,true),.5);end.y/=Base.OWNER_Y_SCALE
  var middle=trunk_top.lerp(end,.55)-Vector3.UP*.35
  Trees.tapered_limb(limbs,trunk_top-Vector3.UP*.3,middle,1.1,.9,false,false);Trees.tapered_limb(limbs,middle,end,.9,.7,false,true)
 var branch_mesh:Mesh=Base.bark_finish(limbs);parts.append(branch_mesh);var wood_paint=Base.native_skin(crown_g,load(ROOT+"native-crown-wood.png"))
 for arrays:Array in branch_mesh.get_meta("east_cpu_arrays"):
  for index in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
   if arrays[Mesh.ARRAY_NORMAL][index].dot(eye)<=0.:continue
   for corner in 3:
    var at=index+corner;wood_paint.projected_vertex(arrays[Mesh.ARRAY_VERTEX][at]+arrays[Mesh.ARRAY_NORMAL][at]*.018,arrays[Mesh.ARRAY_NORMAL][at],arrays[Mesh.ARRAY_VERTEX][at])
 parts.append(wood_paint.finish())
 # Only the exact132drawing base is replaced by this private derivative. Pixels
 # outside the traced body are retained; unseen grass below the solid is inferred.
 var ground=Base.native_skin(g,load(ROOT+"ground-reconstruction.png"));var corners=[]
 for pixel in [Vector2.ZERO,Vector2(736,0),Vector2(736,551),Vector2(0,551)]:corners.append(Base.point(pixel,.055,g))
 for index in [0,2,1,0,3,2]:ground.projected_vertex(corners[index],Vector3.UP,corners[index])
 parts.append(ground.finish());prepared=Base.owner_frame(smooth_bark_normals(Base.combine(parts)));prepared.set_meta("east_ancient_root_compound",true);prepared.set_meta("source_bg_drawings",132);prepared.set_meta("source_crown",11699);prepared.set_meta("east_root_canopy_owner","source_leaf_dome")
 return prepared
