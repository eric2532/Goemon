extends SceneTree
## Current bounded owner set: the complete ancient-root compound stays separate.
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
func _initialize():run.call_deferred()
func run():
 var inputs={};var paths=[get_script().resource_path,"res://scripts/forest/forest_east_region_art.gd","res://scripts/forest/forest_east_tree_families.gd","res://scripts/forest/forest_east_nature.gd",Nature.ROOT+"data.json","res://scripts/forest/forest_east_round_cactus.gd",Nature.Cactus.ROOT+"data.json"]
 for path in paths:inputs[path]=FileAccess.get_sha256(path)
 Nature.Base.Art.load_east();var failures=[];var rows=[];var total=0
 if Nature.owns(11699):failures.append("Canopy-only11699 must not preempt the incomplete full BG-root compound")
 for token in Nature.data().graphics:
  var serial=int(token)
  if not Nature.owns(serial):continue
  var g:Dictionary=Nature.Base.Art.data().graphics[token];var mesh:Mesh=Nature.mesh(serial,g);var count=0
  if mesh==null or mesh.get_surface_count()==0:failures.append("Missing "+token);continue
  if not mesh.get_aabb().position.is_finite() or not mesh.get_aabb().size.is_finite() or mesh.get_aabb().size.y<=0:failures.append("Bounds "+token)
  if serial in [11746,11782,11785,11786] and int(mesh.get_meta("east_round_cactus",-1))!=serial:failures.append("Accepted ribbed cactus owner missing "+token)
  for arrays:Array in mesh.get_meta("east_cpu_arrays"):
   if arrays[Mesh.ARRAY_VERTEX].is_empty():failures.append("Empty surface "+token)
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    count+=1
    if not p.is_finite():failures.append("Nonfinite "+token);break
  total+=count;rows.append({"graphic":serial,"vertices":count,"bounds":var_to_str(mesh.get_aabb()),"kind":mesh.get_meta("east_nature_kind","")})
 if rows.size()!=240:failures.append("Expected exactly240source-backed nature owners")
 for path in inputs:
  if FileAccess.get_sha256(path)!=inputs[path]:failures.append("Input changed "+path)
 var folder="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Owned240/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file=FileAccess.open(folder+"meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"input_hashes":inputs,"graphics":rows,"vertices":total,"failures":failures,"scope":"CPU mesh construction/ownership/finite geometry only; source-placed rendered acceptance remains separate."},"  "));file.close()
 print("EAST_NATURE_OWNED_MESHES graphics=",rows.size()," vertices=",total," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(failures.size())
