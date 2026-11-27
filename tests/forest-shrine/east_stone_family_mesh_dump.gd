extends SceneTree
## Offline source study from the exact cached candidate arrays; no gameplay acceptance.
const Stone=preload("res://scripts/forest/forest_east_stone_families.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Stone Family Candidate/"
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Stone Mesh Study/"
const IDS=[12100,12103,12109,12118,12135,13432,13435,13542,13580,13720,13829,13904,15053,15068,15101,15303,15345,15490,15501,15623,15766,17700,1233290,1233293,1238211,1260054]
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));var records={}
 for id:int in IDS:
  var spec:Dictionary=Stone.data(FOLDER).graphics[str(id)];var mesh:Mesh=Stone.mesh(id,{},FOLDER);var surfaces=[]
  var retained:Array=mesh.get_meta("east_cpu_arrays")
  for surface in retained.size():
   var arrays_:Array=retained[surface];var vertices=[];var normals=[];var uv=[];var colors=[];var indices=[]
   for p:Vector3 in arrays_[Mesh.ARRAY_VERTEX]:vertices.append([p.x,p.y,p.z])
   for n:Vector3 in arrays_[Mesh.ARRAY_NORMAL]:normals.append([n.x,n.y,n.z])
   if arrays_[Mesh.ARRAY_TEX_UV]!=null:
    for p:Vector2 in arrays_[Mesh.ARRAY_TEX_UV]:uv.append([p.x,p.y])
   if arrays_[Mesh.ARRAY_COLOR]!=null:
    for c:Color in arrays_[Mesh.ARRAY_COLOR]:colors.append([c.r,c.g,c.b,c.a])
   if arrays_[Mesh.ARRAY_INDEX]!=null:
    for index in arrays_[Mesh.ARRAY_INDEX]:indices.append(index)
   if indices.is_empty():indices=range(vertices.size())
   var painted=surface==0 and not spec.has("reuse_asset")
   var crop=[]
   if spec.kind=="sparse_cave_cap_or_edge":painted=surface>0;crop=spec.visible_box
   if spec.kind=="sealed_carved_door_crag":painted=surface in [1,2]
   surfaces.append({"vertices":vertices,"normals":normals,"uv":uv,"colors":colors,"indices":indices,"painted":painted,"crop":crop})
  var box=mesh.get_aabb()
  records[str(id)]={"kind":spec.kind,"surfaces":surfaces,"inferred_back_rgb":spec.inferred_back_rgb,"bounds":[[box.position.x,box.position.y,box.position.z],[box.end.x,box.end.y,box.end.z]],"whole_asset":spec.get("reuse_asset","")}
  await process_frame
 var file=FileAccess.open(OUT+"meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"graphics":records,"candidate_sha256":FileAccess.get_sha256(FOLDER+"data.json"),"cliff_data_sha256":FileAccess.get_sha256(Stone.Crags.StoneRelief.ROOT+"data.json"),"scope":"Private source/geometry study from cached runtime arrays. Offline lighting/material approximation; actual launcher cameras remain required."}));file.close()
 print("EAST_STONE_MESH_DUMP graphics=",records.size());quit(0)
