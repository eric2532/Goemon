extends SceneTree
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
func _initialize():run.call_deferred()
func run():
 var inputs={}
 for path in ["res://scripts/forest/forest_east_region_art.gd","res://scripts/forest/forest_east_tree_families.gd","res://scripts/forest/forest_east_nature.gd",Nature.ROOT+"data.json"]:inputs[path]=FileAccess.get_sha256(path)
 Nature.Base.Art.load_east();var failures=[];var rows=[];var total=0
 for token in Nature.data().graphics:
  var serial=int(token);var g:Dictionary=Nature.Base.Art.data().graphics[token];var mesh:Mesh=Nature.mesh(serial,g)
  if mesh==null or mesh.get_surface_count()==0:failures.append("Missing "+token);continue
  var bounds=mesh.get_aabb()
  if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.y<=0:failures.append("Bounds "+token)
  var vertices=0
  for arrays:Array in mesh.get_meta("east_cpu_arrays"):
   if arrays[Mesh.ARRAY_VERTEX].is_empty():failures.append("Empty surface "+token)
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    vertices+=1
    if not p.is_finite():failures.append("Nonfinite "+token);break
  total+=vertices;rows.append({"graphic":serial,"kind":Nature.data().graphics[token].kind,"vertices":vertices,"bounds":var_to_str(bounds)})
 for path in inputs:
  if FileAccess.get_sha256(path)!=inputs[path]:failures.append("Input changed during mesh test: "+path)
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/meshes.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"input_hashes":inputs,"graphics":rows,"vertices":total,"failures":failures,"module_sha256":FileAccess.get_sha256("res://scripts/forest/forest_east_nature.gd"),"data_sha256":FileAccess.get_sha256(Nature.ROOT+"data.json")},"  "));file.close()
 print("EAST_NATURE_MESHES graphics=",rows.size()," vertices=",total," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(failures.size())
