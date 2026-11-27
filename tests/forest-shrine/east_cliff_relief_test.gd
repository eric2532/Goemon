extends SceneTree
const Cliffs=preload("res://scripts/forest/forest_east_field_cliffs.gd")
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check_(condition:bool,label:String):
 checks+=1
 if not condition:failures+=1;push_error(label)
func run():
 for id in range(12536,12548):
  var mesh:Mesh=Cliffs.mesh(id);var source:Dictionary=Cliffs.Native.graphic(id);var profile:Dictionary=Cliffs.Native.data()[str(id)]
  var bounds=mesh.get_aabb();var sparse=int(source.footprint[0])==1
  check_(mesh.get_surface_count()>0,"Prepared cliff mesh "+str(id))
  check_(mesh.has_meta("native_border_crest") if sparse else mesh.has_meta("east_source_correlated_relief"),"Exact scoped visual owner "+str(id))
  if sparse:continue
  var proof:Dictionary=mesh.get_meta("east_source_correlated_relief")
  var expected:Array=proof.geometry_bounds;var center=Vector3((source.footprint[0]-1)*1.5,0,-(source.footprint[1]-1)*1.5)
  check_((bounds.position+center-Vector3(expected[0][0],expected[0][1],expected[0][2])).length()<.001 and (bounds.end+center-Vector3(expected[1][0],expected[1][1],expected[1][2])).length()<.001,"Source-fitted visible bounds, independent from unchanged footprint/navigation "+str(id))
  check_(mesh.get_surface_count()==2 and mesh.surface_get_material(0).shader==Cliffs.reverse_material.shader and mesh.surface_get_material(0).get_shader_parameter("east_vertex_palette")==true and mesh.surface_get_material(1)!=Cliffs.reverse_material,"Closed stone substrate and separate native steep-face material "+str(id))
  check_(float(proof.maximum_source_projection_error_pixels)<.0001 and int(proof.solid_triangles)>=14336 and int(proof.solid_triangles)<=57344,"Prepared calibrated source projection and bounded adaptive relief "+str(id))
  if proof.has("source_paint_triangles"):
   var count_=0
   for arrays_ in mesh.get_meta("east_cpu_arrays"):count_+=arrays_[Mesh.ARRAY_INDEX].size()/3
   check_(count_==int(proof.solid_triangles),"Each source-facing triangle has one authoritative material; no overlapping solid/paint faces "+str(id))
 var expected:Vector2=Cliffs.Regions.frame("east_gate").inverse().basis_xform(Vector2.RIGHT)
 check_((Cliffs.source_basis("east_gate")*Vector3.RIGHT-Vector3(expected.x,0,expected.y)).length()<.0001,"Source-art orientation matches source-grid inverse transform")
 check_(not Cliffs.owns("west_lakes",12538,true) and not Cliffs.owns("laruka",12538,true),"Other region owners preserved")
 print("EAST_CLIFF_RELIEF_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
