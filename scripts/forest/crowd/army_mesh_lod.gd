extends RefCounted
## Simplify rigid attachments independently; skinned/joint triangles stay exact.
## Source vertices and all animation data remain unchanged. Only far indices vary.
const ERRORS=[.01,.03,.1,.25]
static func part(arrays:Array,index:int)->int:
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1]
 if weights[index*4]!=1 or weights[index*4+1]!=0 or weights[index*4+2]!=0 or weights[index*4+3]!=0:return -1
 return int(arrays[Mesh.ARRAY_CUSTOM0][index*4])
static func components(indices:PackedInt32Array,vertices:PackedVector3Array)->Array:
 # Split disconnected rigid pieces before simplification, so the importer cannot
 # prune an entire small ornament or weapon tip from a larger same-color group.
 var parents=[];var points={}
 for triangle in indices.size()/3:
  parents.append(triangle)
  for corner in 3:
   var point=vertices[indices[triangle*3+corner]]
   if points.has(point):
    var a=triangle;var b=points[point]
    while parents[a]!=a:a=parents[a]
    while parents[b]!=b:b=parents[b]
    parents[a]=b
   else:points[point]=triangle
 var pieces={}
 for triangle in parents.size():
  var root=triangle
  while parents[root]!=root:root=parents[root]
  if not pieces.has(root):pieces[root]=PackedInt32Array()
  for corner in 3:pieces[root].append(indices[triangle*3+corner])
 return pieces.values()
static func build(resource:Resource)->ArrayMesh:
 var source:ArrayMesh=resource.get_meta("mesh");var result=ArrayMesh.new();var all_lods=[];var serialized:Array=source.get("_surfaces").duplicate(true)
 var texture:Image=resource.get_meta("pose_texture").get_image();var scales=[]
 # Frobenius norm bounds every pose's scale, including nonuniform/skewed bases.
 # Interpolated poses cannot exceed this bound. Translation cannot amplify error.
 for bone in texture.get_width()/6:
  var largest=0.0
  for row in texture.get_height():
   var squared=0.0
   for column in 3:
    var v=texture.get_pixel(bone*6+column,row);squared+=v.r*v.r+v.g*v.g+v.b*v.b
   largest=maxf(largest,sqrt(squared))
  scales.append(maxf(largest,.000001))
 for surface in source.get_surface_count():
  var arrays=source.surface_get_arrays(surface);var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var groups={};var fixed=PackedInt32Array()
  for i in range(0,indices.size(),3):
   var a=indices[i];var b=indices[i+1];var c=indices[i+2];var bone=part(arrays,a)
   var paint=int(arrays[Mesh.ARRAY_TEX_UV2][a].x)
   if bone<0 or part(arrays,b)!=bone or part(arrays,c)!=bone or int(arrays[Mesh.ARRAY_TEX_UV2][b].x)!=paint or int(arrays[Mesh.ARRAY_TEX_UV2][c].x)!=paint:
    fixed.append_array(PackedInt32Array([a,b,c]));continue
   var key=Vector2i(bone,paint)
   if not groups.has(key):groups[key]=PackedInt32Array()
   groups[key].append_array(PackedInt32Array([a,b,c]))
  var levels={}
  for error in ERRORS:levels[error]=fixed.duplicate()
  var pieces={};var piece_id=0
  for key in groups:
   for component in components(groups[key],arrays[Mesh.ARRAY_VERTEX]):
    pieces[Vector2i(key.x,piece_id)]=component;piece_id+=1
  for key in pieces:
   var original:PackedInt32Array=pieces[key];var mapping={};var inverse=PackedInt32Array();var local_indices=PackedInt32Array()
   for index in original:
    if not mapping.has(index):mapping[index]=inverse.size();inverse.append(index)
    local_indices.append(mapping[index])
   var local=[];local.resize(Mesh.ARRAY_MAX)
   for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_TANGENT]:
    if arrays[field]==null:continue
    local[field]=arrays[field].slice(0,0)
    var stride=arrays[field].size()/arrays[Mesh.ARRAY_VERTEX].size()
    for index in inverse:
     for component in stride:local[field].append(arrays[field][index*stride+component])
   local[Mesh.ARRAY_INDEX]=local_indices
   var importer=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,local)
   importer.generate_lods(25,0,[])
   for error in ERRORS:
    var selected=original
    for lod in importer.get_surface_lod_count(0):
     if importer.get_surface_lod_size(0,lod)*scales[key.x]>error:break
     selected=PackedInt32Array()
     for index in importer.get_surface_lod_indices(0,lod):selected.append(inverse[index])
    levels[error].append_array(selected)
  var lods={};var previous=indices.size()
  for error in ERRORS:
   if levels[error].size()<previous:
    lods[error]=levels[error];previous=levels[error].size()
  # Reuse original packed vertex/attribute/index buffers byte for byte. Calling
  # add_surface_from_arrays on decoded normals would quantize them a second time.
  var encoded=[];var width=2 if arrays[Mesh.ARRAY_VERTEX].size()<=65536 else 4
  for error in lods:
   var bytes=PackedByteArray();bytes.resize(lods[error].size()*width)
   for at in lods[error].size():
    if width==2:bytes.encode_u16(at*width,lods[error][at])
    else:bytes.encode_u32(at*width,lods[error][at])
   encoded.append(error);encoded.append(bytes)
  if not encoded.is_empty():serialized[surface].lods=encoded
  all_lods.append(lods)
 result.set("_surfaces",serialized)
 for surface in source.get_surface_count():result.surface_set_material(surface,source.surface_get_material(surface))
 result.set_meta("lod_indices",all_lods)
 return result
