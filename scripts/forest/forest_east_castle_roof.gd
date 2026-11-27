extends RefCounted
## Isolated East derivative: exact source XZ, canonical height, independent hidden coping.
const Master=preload("res://scripts/forest/forest_beast_castle.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const OWNER_Y=.045*Fit.VERTICAL
const PATH="res://assets/maps/falan/east_region/classic_architecture/castle_roof/data.json"
static var prepared:Mesh
static var spec:Dictionary={}

static func data()->Dictionary:
 if spec.is_empty():spec=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 return spec

static func back_part(height:float)->String:
 for row:Dictionary in data().bands:
  if height>=float(row.low)-.01 and height<=float(row.high)+.01:return row.back_part
 return "plaster"

static func tiled_uv(point:Vector3,normal:Vector3)->Vector2:
 if absf(normal.y)>.7:return Vector2(point.x,point.z)/1.8
 var tangent=normal.cross(Vector3.UP).normalized()
 return Vector2(point.dot(tangent),-point.y)/1.8

static func mesh()->Mesh:
 if prepared!=null:return prepared
 var reference=Master.mesh();var result=ArrayMesh.new();var retained=[];var source_slots=[];var roof_indices={}
 var owner=Basis.IDENTITY.scaled(Vector3(1,OWNER_Y,1));var normals=owner.inverse().transposed()
 var native:Dictionary=Art.data().beast_castle;var blue=Vector2(native.tiles.blue_roof[0],native.tiles.blue_roof[1])
 for slot in reference.get_surface_count():
  var original:Array=reference.surface_get_arrays(slot)
  assert(not original[Mesh.ARRAY_VERTEX].is_empty(),"Castle master arrays must remain available before preparing the East derivative")
  if slot!=5:
   var arrays:Array=original.duplicate(true);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   var tiles:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array else PackedVector2Array()
   for index in vertices.size():
    vertices[index]=owner*vertices[index];ns[index]=(normals*ns[index]).normalized()
    if slot in [0,1] and not tiles.is_empty() and tiles[index].distance_to(blue)<.1:uv[index]=tiled_uv(vertices[index],ns[index])
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=ns
   if not uv.is_empty():arrays[Mesh.ARRAY_TEX_UV]=uv
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);retained.append(arrays);source_slots.append(slot)
   result.surface_set_material(result.get_surface_count()-1,reference.surface_get_material(slot));continue
  # The old canopy projected a complete facade onto every hidden face.
  var observed=SurfaceTool.new();observed.begin(Mesh.PRIMITIVE_TRIANGLES)
  var back=Source.new([],load(Art.ROOT+"beast-castle-sculpture-surfaces.png"),.045)
  for part:String in native.tiles:back.tiles[part]=Vector2(native.tiles[part][0],native.tiles[part][1])
  var mapping=[[],[]];var index_array=original[Mesh.ARRAY_INDEX];var indexed=index_array is PackedInt32Array and not index_array.is_empty()
  for triangle in range(0,index_array.size() if indexed else original[Mesh.ARRAY_VERTEX].size(),3):
   var first=int(index_array[triangle]) if indexed else triangle;var old_normal:Vector3=original[Mesh.ARRAY_NORMAL][first]
   var known=old_normal.dot(Vector3(-1,1.603567,1))>.05;var level=0.
   for corner in 3:
    var at=int(index_array[triangle+corner]) if indexed else triangle+corner;level+=original[Mesh.ARRAY_VERTEX][at].y/3.
   var part=back_part(level)
   for corner in 3:
    var at=int(index_array[triangle+corner]) if indexed else triangle+corner;var p:Vector3=owner*original[Mesh.ARRAY_VERTEX][at];var n:Vector3=(normals*original[Mesh.ARRAY_NORMAL][at]).normalized()
    mapping[0 if known else 1].append(at)
    if known:
     observed.set_normal(n);observed.set_uv(original[Mesh.ARRAY_TEX_UV][at]);observed.add_vertex(p)
    else:
     back.surface.set_normal(n);back.surface.set_uv2(back.tiles[part]);back.surface.set_uv(tiled_uv(p,n));back.surface.add_vertex(p)
  for pass_ in 2:
   var arrays:Array=observed.commit_to_arrays() if pass_==0 else back.surface.commit_to_arrays()
   if arrays[Mesh.ARRAY_VERTEX].is_empty():continue
   var index=result.get_surface_count();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);retained.append(arrays);source_slots.append(5);roof_indices[index]=PackedInt32Array(mapping[pass_])
   var material:ShaderMaterial=reference.surface_get_material(5)
   if pass_==1:
    material=Source.material(back.texture,true).duplicate();material.set_shader_parameter("original_palette",false)
   result.surface_set_material(index,material)
 result.set_meta("east_castle_cpu_arrays",retained);result.set_meta("east_castle_source_slots",source_slots);result.set_meta("east_castle_roof_indices",roof_indices)
 result.set_meta("canonical_owner_y",OWNER_Y);result.set_meta("owner_y_conversions",1);result.set_meta("source_xz_unchanged",true)
 result.set_meta("inferred_roof_backs","Independent native coping/plaster tiers at fixed1.8m pitch; no mirrored full facade")
 prepared=result;return result
