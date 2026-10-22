extends SceneTree
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 for kind in [0,1,3]:
  var source:ArrayMesh=Soldier.data(kind).get_meta("mesh");var mesh=Soldier.make_mesh(kind)
  check(mesh.get_surface_count()==3,"Soldier%d shares three original texture groups instead of thirteen material draws"%kind)
  if not mesh.has_meta("source_ranges"):
   check(false,"Merged soldier geometry must retain verifiable source ranges");continue
  # Godot decodes/re-encodes octahedral normals while regrouping surfaces;
  # keep that error below one source packing quantum (unshaded shader).
  var same=true;var vertices=0;var indices=0;var normal_error=0.0;var field_errors={}
  for row in mesh.get_meta("source_ranges"):
   var a=source.surface_get_arrays(row.source_slot);var b=mesh.surface_get_arrays(row.surface)
   vertices+=a[Mesh.ARRAY_VERTEX].size();indices+=a[Mesh.ARRAY_INDEX].size()
   for i in a[Mesh.ARRAY_VERTEX].size():
    var at:int=row.vertex_first+i
    normal_error=maxf(normal_error,a[Mesh.ARRAY_NORMAL][i].distance_to(b[Mesh.ARRAY_NORMAL][at]))
    for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:
     if a[field][i]!=b[field][at]:field_errors[field]=field_errors.get(field,0)+1
    same=same and a[Mesh.ARRAY_VERTEX][i]==b[Mesh.ARRAY_VERTEX][at] and a[Mesh.ARRAY_NORMAL][i].distance_to(b[Mesh.ARRAY_NORMAL][at])<.0001 and a[Mesh.ARRAY_TEX_UV][i]==b[Mesh.ARRAY_TEX_UV][at] and a[Mesh.ARRAY_COLOR][i]==b[Mesh.ARRAY_COLOR][at] and a[Mesh.ARRAY_TEX_UV2][i].x==b[Mesh.ARRAY_TEX_UV2][at].x and b[Mesh.ARRAY_TEX_UV2][at].y==row.source_slot
   for i in a[Mesh.ARRAY_INDEX].size():same=same and a[Mesh.ARRAY_INDEX][i]+row.vertex_first==b[Mesh.ARRAY_INDEX][row.index_first+i]
   var original=source.surface_get_material(row.source_slot);var material=mesh.surface_get_material(row.surface)
   check(material.get_shader_parameter("albedo_texture")==original.albedo_texture,"Soldier group keeps the exact original texture resource")
   var palette:Image=material.get_shader_parameter("tint_palette").get_image()
   var expected:Color=original.albedo_color.srgb_to_linear()
   check(palette.get_pixel(0,row.source_slot).is_equal_approx(expected),"Float material palette keeps the original uniform color without vertex quantization")
  var actual_vertices=0;var actual_indices=0
  for surface in mesh.get_surface_count():actual_vertices+=mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size();actual_indices+=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()
  print("SOLDIER_BATCH_FIDELITY kind=",kind," normal_error=",normal_error," field_errors=",field_errors)
  check(same and vertices==actual_vertices and indices==actual_indices,"Every original soldier vertex, triangle, normal, UV, part and vertex color survives batching")
 print("ARMY_SOLDIER_BATCHES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
