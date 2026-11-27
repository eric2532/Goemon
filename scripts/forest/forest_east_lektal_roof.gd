extends RefCounted
## Reuse the complete1233255house; measure its actual roof before attaching parts.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/lektal_roof/"
static var catalog:Dictionary={}
static var prepared:Mesh
static var roof_proof:Array=[]
static func owns(serial:int)->bool:return serial==1233255
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func roof_hit(raw:Mesh,origin:Vector3,direction:Vector3)->Vector3:
 var nearest=INF;var result=Vector3.INF
 for slot in raw.get_surface_count():
  var arrays:Array=raw.get_meta("east_cpu_arrays")[slot] if raw.has_meta("east_cpu_arrays") else raw.surface_get_arrays(slot)
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
   var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if normal.y<.03:continue
   var hit=Geometry3D.ray_intersects_triangle(origin,direction,arrays[Mesh.ARRAY_VERTEX][ids[0]],arrays[Mesh.ARRAY_VERTEX][ids[1]],arrays[Mesh.ARRAY_VERTEX][ids[2]])
   if hit!=null and origin.distance_squared_to(hit)<nearest:nearest=origin.distance_squared_to(hit);result=hit
 assert(result.is_finite(),"Source rooftop part must intersect its reused actual roof")
 return result
static func roof_pixel(raw:Mesh,g:Dictionary,pixel:Vector2)->Vector3:
 var ray=Vector3(-1./16.,1./East.Fit.VERTICAL,1./16.).normalized()
 return roof_hit(raw,East.point(pixel,0,g)+ray*1000.,-ray)
static func physical_distance(a:Vector3,b:Vector3)->float:
 return ((a-b)*Vector3(1.,East.OWNER_Y_SCALE,1.)).length()
static func chimney_part(g:Dictionary,spec:Dictionary)->Mesh:
 var mesh=East.round_body(g,spec);var arrays:Array=mesh.get_meta("east_cpu_arrays")[0].duplicate(true)
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var page=East.texture(g).get_size()
 for index in uv.size():uv[index]=(uv[index]*page-Vector2(g.rect[0],g.rect[1]))/Vector2(g.rect[2],g.rect[3])
 arrays[Mesh.ARRAY_TEX_UV]=uv
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(0,Source.material(load(ROOT+"chimney-front.png")))
 var rear:Array=mesh.get_meta("east_cpu_arrays")[1];result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,rear)
 var material:ShaderMaterial=mesh.surface_get_material(1).duplicate();material.set_shader_parameter("base_texture",load(ROOT+"surfaces.png"));result.surface_set_material(1,material)
 result.set_meta("east_cpu_arrays",[arrays,rear]);return result
static func coherent_roof(raw:Mesh,g:Dictionary,spec:Dictionary)->Mesh:
 # Keep every wall/roof vertex. Remove the old whole-sprite roof overlay, whose
 # occluded chimney margins copied roof fragments onto the new separate parts.
 # One measured slate patch continues across each complete hip, including backs.
 var height=float(spec.wall_pixels)/East.Fit.VERTICAL
 var left=East.point(East.v(spec.eaves[0]),height,g);var near=East.point(East.v(spec.eaves[1]),height,g);var right=East.point(East.v(spec.eaves[2]),height,g)
 var eaves=[near,left,left+right-near,right];var patch=[]
 for pixel:Array in data().roof_surface_patch:patch.append(roof_pixel(raw,g,Vector2(pixel[0],pixel[1])))
 var pitch=Vector2(physical_distance(patch[0],patch[3]),physical_distance(patch[0],patch[1]))
 assert(pitch.x>.1 and pitch.y>.1,"Native slate patch must have measured physical area")
 var result=ArrayMesh.new();var retained=[]
 for slot in raw.get_surface_count():
  var arrays:Array=raw.get_meta("east_cpu_arrays")[slot];var tool=Furniture.tool()
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]]if indexed else[i,i+1,i+2]
   var n:Vector3=arrays[Mesh.ARRAY_NORMAL][ids[0]];var roof=n.y>.03
   for index:int in ids:roof=roof and arrays[Mesh.ARRAY_VERTEX][index].y>=height-.001
   if slot==0 and roof:continue
   var face=0;var facing=-INF
   if slot==1 and roof:
    for edge in 4:
     var direction:Vector3=(eaves[(edge+1)%4]-eaves[edge]).normalized();var score=n.dot(Vector3.UP.cross(direction))
     if score>facing:facing=score;face=edge
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];tool.set_normal(arrays[Mesh.ARRAY_NORMAL][index]);var uv:Vector2=arrays[Mesh.ARRAY_TEX_UV][index]
    if slot==1 and roof:
     var tangent:Vector3=(eaves[(face+1)%4]-eaves[face]).normalized();var delta:Vector3=p-eaves[face];var along=delta.dot(tangent)
     var across=delta-tangent*along;across.y*=East.OWNER_Y_SCALE
     uv=Vector2(along/pitch.x,across.length()/pitch.y)
    tool.set_uv(uv)
    if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array and not arrays[Mesh.ARRAY_TEX_UV2].is_empty():tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][index])
    tool.add_vertex(p)
  var built=Source.committed_arrays(tool.commit_to_arrays());result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,built);retained.append(built);result.surface_set_material(slot,raw.surface_get_material(slot))
 result.set_meta("east_cpu_arrays",retained);result.set_meta("slate_patch_physical_pitch",pitch);return result
static func mesh(serial:int,g:Dictionary)->Mesh:
 assert(owns(serial) and g.rgba_sha256==data().source_rgba_sha256,"Regenerate bounded Lektal roof source")
 if prepared!=null:return prepared
 var spec:Dictionary=East.data().graphics[str(serial)].houses[0].duplicate(true);spec.cap=false
 var original=East.house(g,spec);var house=coherent_roof(original,g,spec)
 var paint:ShaderMaterial=house.surface_get_material(0).duplicate();paint.set_shader_parameter("base_texture",load(ROOT+"house-atlas.png"));house.surface_set_material(0,paint)
 var backing:ShaderMaterial=house.surface_get_material(1).duplicate();backing.set_shader_parameter("base_texture",load(ROOT+"surfaces.png"));house.surface_set_material(1,backing)
 var base_pixel=Vector2(data().chimney_base[0],data().chimney_base[1]);var base=roof_pixel(original,g,base_pixel);var level=base.y*East.Fit.VERTICAL
 roof_proof.append({"part":"chimney","native_pixel":data().chimney_base,"base_height_pixels":level,"physical_y":base.y*East.OWNER_Y_SCALE,"original_roof_delta":0.})
 var stack={"base":data().chimney_base,"level_pixels":level,"height_pixels":data().chimney_height_pixels,"diameter":28.,"material":"sandstone","profile":[[0.,1.5],[.08,1.5],[.12,1.12],[.22,1.12],[.27,.73],[.80,.62],[.91,.72],[1.,.72]]}
 var cap={"base":[base_pixel.x,base_pixel.y-float(data().chimney_height_pixels)],"level_pixels":level+float(data().chimney_height_pixels),"height_pixels":data().chimney_cap_height_pixels,"diameter":42.,"material":"roof_wood","profile":[[0.,.78],[.14,1.],[.43,.98],[.74,.66],[1.,0.]]}
 var parts=[house,chimney_part(g,stack),chimney_part(g,cap)]
 var solid=East.structure();var front=East.native_skin(g);solid.part="timber"
 var top:Array[Vector3]=[];var bottom:Array[Vector3]=[]
 for row:Array in data().hatch_top:
  var pixel=Vector2(row[0],row[1]);var support=roof_pixel(original,g,pixel);var p=East.point(pixel,support.y+float(data().hatch_lift_m)/East.OWNER_Y_SCALE,g)
  top.append(p);bottom.append(roof_hit(original,p+Vector3.UP*1000.,Vector3.DOWN))
  roof_proof.append({"part":"hatch","native_pixel":row,"physical_top_y":p.y*East.OWNER_Y_SCALE,"physical_base_y":bottom[-1].y*East.OWNER_Y_SCALE,"physical_depth":(p.y-bottom[-1].y)*East.OWNER_Y_SCALE})
 for i in 4:
  var j=(i+1)%4;solid.quad(bottom[j],top[j],top[i],bottom[i])
  var normal=(top[i]-bottom[j]).cross(top[j]-bottom[j]).normalized()
  if normal.dot(Vector3(-1,0,1))>0.:East.painted_quad(front,bottom[j],top[j],top[i],bottom[i])
  East.rod(solid,top[i],top[j],.12,"timber")
 solid.quad(top[0],top[1],top[2],top[3]);East.painted_quad(front,top[0],top[1],top[2],top[3])
 solid.quad(bottom[3],bottom[2],bottom[1],bottom[0]);parts.append(solid.finish());parts.append(front.finish())
 prepared=East.owner_frame(East.combine(parts));prepared.set_meta("east_lektal_roof",serial);prepared.set_meta("source_rgba_sha256",g.rgba_sha256);prepared.set_meta("roof_attachment_proof",roof_proof);prepared.set_meta("inferred_hidden_details",true)
 return prepared
