extends SceneTree
const East=preload("res://scripts/forest/forest_east_region_art.gd")
var failures=[]
func _initialize():call_deferred("run")
func run():
 var inputs={}
 for path in ["res://scripts/forest/forest_east_region_art.gd","res://scripts/forest/forest_east_tree_families.gd",East.ROOT+"profiles.json","res://assets/maps/original_crossgate/east/catalog.json"]:inputs[path]=FileAccess.get_sha256(path)
 East.Art.load_east();var total_vertices=0;var total_triangles=0;var total_surfaces=0;var count=0;var rows=[];var islet_checks=0
 for token in East.data().graphics:
  var serial=int(token);var graphic:Dictionary=East.Art.data().graphics[token];var mesh:Mesh=East.mesh(0,serial,graphic)
  if mesh==null or mesh.get_surface_count()==0:failures.append("Missing mesh "+token);continue
  var box=mesh.get_aabb()
  if not box.position.is_finite() or not box.size.is_finite() or box.size.y<=0:failures.append("Invalid solid bounds "+token)
  if East.data().graphics[token].kind=="source_islet":
   var spec:Dictionary=East.data().graphics[token];var water:Array=mesh.get_meta("east_cpu_arrays")[0]
   if not is_finite(float(spec.ground_offset)):failures.append("Nonfinite native islet ground offset "+token)
   for normal:Vector3 in water[Mesh.ARRAY_NORMAL]:
    if normal.y<.99:failures.append("Native islet water must face upward "+token);break
   for vertex:Vector3 in water[Mesh.ARRAY_VERTEX]:
    if vertex.y< -2.1 or vertex.y> -2.:failures.append("Native islet water must remain below native ground "+token);break
   islet_checks+=1
  var profile_vertices=0;var profile_triangles=0
  for slot in mesh.get_surface_count():
   var arrays:Array=mesh.get_meta("east_cpu_arrays")[slot] if mesh.has_meta("east_cpu_arrays") else mesh.surface_get_arrays(slot)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];total_vertices+=vertices.size();profile_vertices+=vertices.size()
   var indices=arrays[Mesh.ARRAY_INDEX];var triangles=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else vertices.size())/3
   total_triangles+=triangles;profile_triangles+=triangles;total_surfaces+=1
   if vertices.is_empty():failures.append("Empty surface "+token)
   for p in vertices:
    if not p.is_finite():failures.append("Nonfinite vertex "+token);break
  count+=1
  rows.append({"graphic":serial,"kind":East.data().graphics[token].kind,"surfaces":mesh.get_surface_count(),"vertices":profile_vertices,"triangles":profile_triangles,"bounds":[box.position.x,box.position.y,box.position.z,box.size.x,box.size.y,box.size.z]})
 for path in inputs:
  if FileAccess.get_sha256(path)!=inputs[path]:failures.append("Input changed during mesh test: "+path)
 var attachments=shrine_attachments()
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/all-meshes.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"input_hashes":inputs,"profiles":rows,"total_vertices":total_vertices,"total_triangles":total_triangles,"total_surfaces":total_surfaces,"islet_water_checks":islet_checks,"living_spire_attachments":attachments,"failures":failures,"tree_helper_sha256":FileAccess.get_sha256("res://scripts/forest/forest_east_tree_families.gd"),"module_sha256":FileAccess.get_sha256("res://scripts/forest/forest_east_region_art.gd"),"profiles_sha256":FileAccess.get_sha256(East.ROOT+"profiles.json")},"  "));file.close()
 print("EAST_ALL_LANDMARK_MESHES profiles=",count," vertices=",total_vertices," triangles=",total_triangles," surfaces=",total_surfaces," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)

func shrine_attachments()->Array:
 # A native-pixel ray checks the actual reconstructed roof, catching detached spires.
 var graphic:Dictionary=East.Art.data().graphics["1230040"];var spec:Dictionary=East.data().graphics["1230040"]
 var houses=[1,0,2,0];var result=[];var ray=Vector3(-1./16.,1./East.Fit.VERTICAL,1./16.).normalized()
 for index in spec.towers.size():
  var tower:Dictionary=spec.towers[index];var base=East.point(East.v(tower.base),float(tower.level_pixels)/East.Fit.VERTICAL,graphic)
  var roof:Mesh=East.house(graphic,spec.houses[houses[index]]);var high=-INF
  for arrays:Array in roof.get_meta("east_cpu_arrays"):
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for offset in range(0,vertices.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(base+ray*200.,-ray,vertices[offset],vertices[offset+1],vertices[offset+2])
    if hit!=null:high=maxf(high,hit.y)
  var gap=absf(base.y-high);result.append({"native_base":tower.base,"vertical_gap_reference":gap})
  if not is_finite(gap) or gap>.20:failures.append("Shrine spire detached from measured roof "+str(tower.base)+": "+str(gap))
 return result
