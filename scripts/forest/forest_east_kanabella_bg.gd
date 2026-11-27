extends RefCounted
## Private Kanabella BG-house reconstruction; source planes and routes stay native.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const Roof=preload("res://scripts/forest/forest_east_lektal_roof.gd")
const ROOT="res://assets/maps/falan/east_region/kanabella_bg/"
static var prepared:Mesh
static var proof:Array=[]
static func data()->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(ROOT+"prototype.json"))
static func reskin(reference:Mesh,g:Dictionary,part:String)->Mesh:
 var result=ArrayMesh.new();var retained=[];var old=Base.texture(g);var paint:Texture2D=load(ROOT+data().model+"-"+part+".png")
 for slot in reference.get_surface_count():
  var arrays:Array=reference.get_meta("east_cpu_arrays")[slot].duplicate(true);var material:Material=reference.surface_get_material(slot)
  if material is ShaderMaterial and material.get_shader_parameter("base_texture")==old:
   var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   for index in uv.size():uv[index]=uv[index]*old.get_size()/paint.get_size()
   arrays[Mesh.ARRAY_TEX_UV]=uv;material=Base.Source.material(paint)
  elif material is ShaderMaterial and material.get_shader_parameter("base_texture")==Base.Atlas:
   material=material.duplicate();material.set_shader_parameter("base_texture",load(ROOT+data().model+"-surfaces.png"))
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(slot,material);retained.append(arrays)
 result.set_meta("east_cpu_arrays",retained);return result
static func surface_pixel(raw:Mesh,g:Dictionary,pixel:Vector2)->Vector3:
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var start=Base.point(pixel,0,g)+ray*1000.;var result=Vector3.INF;var nearest=INF
 for arrays:Array in raw.get_meta("east_cpu_arrays"):
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  for index in range(0,vertices.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(start,-ray,vertices[index],vertices[index+1],vertices[index+2])
   if hit is Vector3 and start.distance_squared_to(hit)<nearest:nearest=start.distance_squared_to(hit);result=hit
 assert(result.is_finite(),"Native bay window must intersect the reused attic wall")
 return result
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var spec=data();var g={"origin":spec.native_origin,"rect":[0,0,spec.native_size[0],spec.native_size[1]],"footprint":[1,1],"page":0}
 var main:Mesh=Base.house(g,spec.main);var parts=[reskin(main,g,"walls")]
 # The existing main roof keeps its curved silhouette. Its own bounded paint
 # is separate from the stack/attic/curls which previously overlapped that sprite.
 var roof:Mesh=reskin(main,g,"roof");var selected=ArrayMesh.new();var selected_arrays=[]
 for slot in roof.get_surface_count():
  var material:Material=roof.surface_get_material(slot)
  if not material is ShaderMaterial or material.get_shader_parameter("base_texture")!=load(ROOT+spec.model+"-roof.png"):continue
  var arrays:Array=roof.get_meta("east_cpu_arrays")[slot];var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var count=0
  for index in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
   if arrays[Mesh.ARRAY_NORMAL][index].y<=.03:continue
   for corner in 3:
    var at=index+corner;tool.set_normal(arrays[Mesh.ARRAY_NORMAL][at]);tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][at])
    if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array and not arrays[Mesh.ARRAY_TEX_UV2].is_empty():tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][at])
    tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][at]);count+=1
  if count==0:continue
  var built=Base.Source.committed_arrays(tool.commit_to_arrays());selected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,built);selected.surface_set_material(selected.get_surface_count()-1,roof.surface_get_material(slot));selected_arrays.append(built)
 selected.set_meta("east_cpu_arrays",selected_arrays);parts.append(selected)
 var dormer:Dictionary=spec.dormer.duplicate(true);var at=Roof.roof_pixel(main,g,Base.v(dormer.roof_anchor));dormer.level_pixels=at.y*Base.Fit.VERTICAL
 var attic_raw:Mesh=Base.house(g,dormer);parts.append(reskin(attic_raw,g,"dormer"));proof.append({"part":"attic","roof_pixel":dormer.roof_anchor,"author_base_y":at.y,"source":"Existing complete measured gable/wall kit on the actual main roof"})
 var chimney:Dictionary=spec.chimney.duplicate(true);at=Roof.roof_pixel(main,g,Base.v(chimney.base));chimney.level_pixels=at.y*Base.Fit.VERTICAL
 parts.append(reskin(Base.round_body(g,chimney),g,"chimney"));proof.append({"part":"stack","roof_pixel":chimney.base,"author_base_y":at.y})
 for pixel:Array in spec.main.feet:
  var corner={"base":pixel,"height_pixels":110,"diameter":25,"material":"plaster","profile":[[0,.65],[.15,.80],[.4,.65],[.65,.55],[.85,.80],[1,1.10]]}
  parts.append(reskin(Base.round_body(g,corner),g,"walls"))
 parts.append(reskin(Base.stairs(g,spec.stairs),g,"stairs"))
 for row:Dictionary in spec.reliefs:
  var anchor=Base.v(row.anchor);at=surface_pixel(attic_raw,g,anchor) if row.part=="window" else Roof.roof_pixel(main,g,anchor);var native_u=anchor.x+float(g.origin[0]);var ground=(at.z-at.x)*8.
  var relief={"slope":row.slope,"ground_offset":ground-float(row.slope)*native_u,"depth":row.depth,"edges":[]};var polygon:Array=spec.component_polygons[row.part]
  for index in polygon.size():
   var a:Array=polygon[index];var b:Array=polygon[(index+1)%polygon.size()];relief.edges.append([a[0],a[1],b[0],b[1],a[0],a[1]])
  parts.append(Base.relief(g,relief,load(ROOT+spec.model+"-"+row.part+"-back.png"),load(ROOT+spec.model+"-"+row.part+".png")))
 var floor_skin=Base.native_skin(g,load(ROOT+spec.model+"-ground.png"));var corners=[]
 for pixel:Vector2 in [Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])]:corners.append(Base.point(pixel,.055,g))
 Base.painted_quad(floor_skin,corners[0],corners[3],corners[2],corners[1]);parts.append(floor_skin.finish())
 prepared=Base.owner_frame(Base.combine(parts));prepared.set_meta("east_kanabella_private",spec.model);prepared.set_meta("source_compound_support",proof);return prepared
