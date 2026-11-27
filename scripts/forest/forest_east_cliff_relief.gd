extends RefCounted
## Prepared source-correlated stone relief, shared by the scoped East cliff owner.
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_field_cliffs/relief/"
static var prepared:Dictionary={}
static var meshes:Dictionary={}
static var candidate_data:Dictionary={}
static var candidate_textures:Dictionary={}

static func data(folder:String=ROOT)->Dictionary:
 if folder!=ROOT:
  if not candidate_data.has(folder):candidate_data[folder]=JSON.parse_string(FileAccess.get_file_as_string(folder+"data.json"))
  return candidate_data[folder]
 if prepared.is_empty():prepared=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return prepared

static func arrays(values:PackedFloat32Array,offset:int,count_:int,stride:int,indices:PackedInt32Array)->Array:
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var colors=PackedColorArray()
 vertices.resize(count_);normals.resize(count_)
 if stride in [8,12]:uv.resize(count_)
 if stride in [10,12]:colors.resize(count_)
 for i in count_:
  var base=offset+i*stride
  vertices[i]=Vector3(values[base],values[base+1],values[base+2]);normals[i]=Vector3(values[base+3],values[base+4],values[base+5])
  if stride==8:uv[i]=Vector2(values[base+6],values[base+7])
  if stride==12:uv[i]=Vector2(values[base+10],values[base+11])
  if stride in [10,12]:colors[i]=Color(values[base+6],values[base+7],values[base+8],values[base+9])
 var result=[];result.resize(Mesh.ARRAY_MAX)
 result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals;result[Mesh.ARRAY_INDEX]=indices
 if stride in [8,12]:result[Mesh.ARRAY_TEX_UV]=uv
 if stride in [10,12]:result[Mesh.ARRAY_COLOR]=colors
 return result

static func mesh(serial:int,reverse:Material,folder:String=ROOT)->Mesh:
 var cache_key:Variant=serial if folder==ROOT else [folder,serial]
 if meshes.has(cache_key):return meshes[cache_key]
 var file=FileAccess.open(folder+str(serial)+".bin",FileAccess.READ)
 var format=file.get_buffer(4).get_string_from_ascii();assert(format in ["ECR2","ECR3","ECR4"])
 if format=="ECR4":
  var count_=file.get_32();var index_count=file.get_32();var length=file.get_32()
  var packed=file.get_buffer(file.get_length()-file.get_position()).decompress(length,FileAccess.COMPRESSION_DEFLATE);file.close()
  var vertex_bytes=count_*48;var values=packed.slice(0,vertex_bytes).to_float32_array();var ids=packed.slice(vertex_bytes).to_int32_array()
  assert(ids.size()==index_count and values.size()==count_*12)
  var retained=arrays(values,0,count_,12,ids);var volume=ArrayMesh.new();volume.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,retained)
  var paint=ShaderMaterial.new();paint.shader=preload("res://scripts/forest/forest_east_cliff_volume.gdshader")
  var texture_key=[folder,serial]
  if not candidate_textures.has(texture_key):candidate_textures[texture_key]=ImageTexture.create_from_image(Image.load_from_file(folder+str(serial)+".png")) if folder.begins_with("res://build/") else load(folder+str(serial)+".png")
  paint.set_shader_parameter("native_paint",candidate_textures[texture_key]);paint.set_shader_parameter("rock_texture",preload("res://assets/textures/edo/rock.png"))
  var row:Dictionary=data(folder).graphics[str(serial)];paint.set_shader_parameter("native_eye",Vector3(-1,16.*float(row.pixel_height),1).normalized())
  volume.surface_set_material(0,paint);volume.set_meta("native_cliff_profile",serial);volume.set_meta("east_source_correlated_relief",row);volume.set_meta("east_cpu_arrays",[retained]);meshes[cache_key]=volume
  return volume
 var paint_stride=12 if format=="ECR3" else 8
 var solid_count=file.get_32();var paint_count=file.get_32();var solid_indices=file.get_32();var paint_indices=file.get_32();var byte_count=file.get_32()
 var bytes=file.get_buffer(file.get_length()-file.get_position()).decompress(byte_count,FileAccess.COMPRESSION_DEFLATE);file.close()
 var float_count=solid_count*10+paint_count*paint_stride;var floats=bytes.slice(0,float_count*4).to_float32_array()
 var solid_ids=bytes.slice(float_count*4,(float_count+solid_indices)*4).to_int32_array()
 var paint_ids=bytes.slice((float_count+solid_indices)*4).to_int32_array()
 assert(solid_ids.size()==solid_indices and paint_ids.size()==paint_indices)
 if format=="ECR3":
  var observed={}
  for triangle in data(folder).graphics[str(serial)].source_paint_triangles:observed[int(triangle)]=true
  var retained=PackedInt32Array();retained.resize(solid_ids.size()-observed.size()*3);var at=0
  for triangle in solid_ids.size()/3:
   if observed.has(triangle):continue
   for vertex in 3:retained[at]=solid_ids[triangle*3+vertex];at+=1
  solid_ids=retained
 var solid=arrays(floats,0,solid_count,10,solid_ids);var paint=arrays(floats,solid_count*10,paint_count,paint_stride,paint_ids)
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,solid);var hidden:ShaderMaterial=reverse.duplicate();hidden.set_shader_parameter("east_vertex_palette",true);hidden.set_shader_parameter("rock_texture",preload("res://assets/textures/edo/rock.png"));hidden.set_shader_parameter("use_cliff_face",false);result.surface_set_material(0,hidden)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint)
 var material:ShaderMaterial=Paint.material(load(folder+str(serial)+".png")).duplicate()
 if format=="ECR3":material.shader=load(folder+"front.gdshader")
 material.set_shader_parameter("original_palette",false);result.surface_set_material(1,material)
 result.set_meta("native_cliff_profile",serial);result.set_meta("east_source_correlated_relief",data(folder).graphics[str(serial)])
 result.set_meta("east_cpu_arrays",[solid,paint]);meshes[cache_key]=result
 return result
