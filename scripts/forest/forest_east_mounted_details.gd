extends RefCounted
## Thin native details reuse the existing closed alpha-relief shell.
const Relief=preload("res://scripts/forest/forest_elsa_scenery.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const ROOT="res://assets/maps/falan/east_region/mounted_details/"
const IDS=[10526,10547,10550,10551,10567,10569,10582,11113,11114,11119,11122,16139,16236,16237,16238,16239,16240,16241,16242,16243,16565,16645,17521,17522,17523,17560,17563,11059,17674,14529,14536]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func face(arrays:Array,low:int,high:int,material:Material)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(low,high):tool.set_normal(arrays[Mesh.ARRAY_NORMAL][i]);tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][i]);tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][i])
 var result=tool.commit();result.surface_set_material(0,material);return result
static func floor_piece(g:Dictionary,texture:Texture2D)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var pixels=[Vector2.ZERO,Vector2(g.size[0],0),Vector2(g.size[0],g.size[1]),Vector2(0,g.size[1])]
 for index in [0,1,2,0,2,3]:
  var native=pixels[index]+Vector2(g.origin[0],g.origin[1]);tool.set_normal(Vector3.UP);tool.set_uv(pixels[index]/Vector2(g.size[0],g.size[1]));tool.add_vertex(Vector3(native.x*3./64.-native.y/16.,.025,native.x*3./64.+native.y/16.))
 var result=tool.commit();result.surface_set_material(0,Source.material(texture));return result
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate native mounted detail references")
 var front:Texture2D=load(ROOT+str(serial)+"-front.png");var back:Texture2D=load(ROOT+str(serial)+"-back.png");var result:Mesh
 if g.mode=="floor":result=floor_piece(g,front)
 else:
  var row=g.duplicate(true);row.rect=[0,0,g.size[0],g.size[1]];row.cut=[serial]
  var raw=Relief.relief_shape(row,front,back,g.edges,Vector2(g.slope,g.ground))
  var arrays=raw.surface_get_arrays(0);assert(arrays[Mesh.ARRAY_VERTEX].size()==12,"Existing relief front/reverse contract changed")
  var wood:ShaderMaterial=Source.material(back).duplicate();wood.set_shader_parameter("original_palette",false)
  var sides=ArrayMesh.new();sides.add_surface_from_arrays(raw.surface_get_primitive_type(1),raw.surface_get_arrays(1));sides.surface_set_material(0,wood)
  # Elsa emits the displaced reverse first, then the original source plane.
  # Keep the native lettering/art on that original plane, without mirroring it.
  result=East.combine([face(arrays,0,6,wood),face(arrays,6,12,Source.material(front)),sides])
 result.set_meta("east_native_mounted_detail",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_closed_reverse",g.mode!="floor");meshes[serial]=result
 return result
