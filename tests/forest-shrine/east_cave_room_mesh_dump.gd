extends SceneTree
const Candidate=preload("res://scripts/forest/forest_east_cave_room_candidates.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Cave Room Study/"
func _initialize():call_deferred("run")
func run():
 var rows={};var failures=[]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for token in Candidate.data().graphics:
  if OS.get_cmdline_user_args().has("--rooms-only") and int(token)<17000:continue
  var serial=int(token);var mesh=Candidate.mesh(serial);var surfaces=[];var triangles=0
  var retained:Array=mesh.get_meta("east_cpu_arrays",[])
  for index in mesh.get_surface_count():
   var arrays:Array=retained[index] if index<retained.size() else mesh.surface_get_arrays(index)
   var vertices=[];var normals=[];var uv=[];var uv2=[];var ids=[];var colors=[]
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:vertices.append([p.x,p.y,p.z])
   for p:Vector3 in arrays[Mesh.ARRAY_NORMAL]:normals.append([p.x,p.y,p.z])
   if arrays[Mesh.ARRAY_TEX_UV]!=null:
    for p:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:uv.append([p.x,p.y])
   if arrays[Mesh.ARRAY_TEX_UV2]!=null:
    for p:Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:uv2.append([p.x,p.y])
   if arrays[Mesh.ARRAY_INDEX]!=null:
    for id in arrays[Mesh.ARRAY_INDEX]:ids.append(id)
   if arrays[Mesh.ARRAY_COLOR]!=null:
    for color:Color in arrays[Mesh.ARRAY_COLOR]:colors.append([color.r,color.g,color.b])
   triangles+=(ids.size() if not ids.is_empty() else vertices.size())/3
   surfaces.append({"vertices":vertices,"normals":normals,"uv":uv,"uv2":uv2,"indices":ids,"colors":colors})
  var bounds=mesh.get_aabb()
  if not is_finite(bounds.size.y) or bounds.size.y<=0:failures.append(token)
  rows[token]={"surfaces":surfaces,"triangles":triangles,"bounds":{"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]},"role":Candidate.data().graphics[token].role}
 var file=FileAccess.open(OUT+("room-meshes.json" if OS.get_cmdline_user_args().has("--rooms-only") else "meshes.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"graphics":rows,"failures":failures,"candidate_sha256":FileAccess.get_sha256(Candidate.ROOT+"data.json")}," "));file.close()
 print("EAST_CAVE_ROOM_MESH_DUMP graphics=",rows.size()," failures=",failures.size());quit(failures.size())
