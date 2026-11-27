extends SceneTree
const Gate=preload("res://scripts/forest/forest_east_il_gate_parts.gd")
func _initialize():run.call_deferred()
func run():
 var failures=[];var rows=[];var checks=0
 for serial in[11077,11078]:
  var mesh=Gate.mesh(serial);var box=mesh.get_aabb();checks+=3
  if mesh!=Gate.mesh(serial):failures.append("Immutable mesh cache changed "+str(serial))
  if not box.position.is_finite()or not box.size.is_finite():failures.append("Nonfinite bounds")
  if box.size.y<5. or box.size.y>7.5:failures.append("Native arched leaf height outside source frame")
  var vertices=0
  for arrays:Array in mesh.get_meta("east_cpu_arrays"):
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    vertices+=1
    if not point.is_finite():failures.append("Nonfinite vertex")
  rows.append({"graphic":serial,"origin":mesh.get_meta("source_origin"),"footprint":mesh.get_meta("source_footprint"),"bounds":var_to_str(box),"surfaces":mesh.get_surface_count(),"vertices":vertices})
 DirAccess.make_dir_recursive_absolute("res://build/Other Files/Asset Toolkit/East Gate Region/Il Gate Parts")
 var f=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Il Gate Parts/meshes.json",FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"Private CPU-only source dimensions/cache/finite geometry; no gameplay or rendered approval.","checks":checks,"failures":failures,"meshes":rows},"  "));f.close();print("IL_GATE_PART_MESHES checks=",checks," failures=",failures.size());quit(failures.size())
