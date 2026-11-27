extends SceneTree
## Private decoder/material contracts; actual source/reverse gameplay cameras remain required.
const Baked=preload("res://scripts/forest/forest_east_cliff_relief.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Volume Candidates/"
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check_(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 var records:Dictionary=Baked.data(FOLDER).graphics
 check_(records.size()==6,"All six private cliff source families are present")
 for id in [12536,12537,12538,12542,12543,12546]:
  var row:Dictionary=records[str(id)];var mesh:Mesh=Baked.mesh(id,null,FOLDER);var arrays_:Array=mesh.get_meta("east_cpu_arrays")[0]
  var vertices:PackedVector3Array=arrays_[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays_[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays_[Mesh.ARRAY_TEX_UV];var colors:PackedColorArray=arrays_[Mesh.ARRAY_COLOR];var indices:PackedInt32Array=arrays_[Mesh.ARRAY_INDEX]
  check_(mesh.get_surface_count()==1 and indices.size()==int(row.cost.triangles)*3,"Each native volume face has one authoritative material: "+str(id))
  check_(vertices.size()==int(row.cost.vertices) and normals.size()==vertices.size() and uv.size()==vertices.size() and colors.size()==vertices.size(),"Complete ECR4 position/normal/palette/UV buffers: "+str(id))
  var finite=true;var unit=true;var valid=true
  for i in vertices.size():finite=finite and vertices[i].is_finite() and normals[i].is_finite() and uv[i].is_finite();unit=unit and absf(normals[i].length()-1.)<.001
  for index in indices:valid=valid and index>=0 and index<vertices.size()
  check_(finite and unit and valid,"Finite normalized geometry and in-range indices: "+str(id))
  var material:ShaderMaterial=mesh.surface_get_material(0)
  check_(material.shader==preload("res://scripts/forest/forest_east_cliff_volume.gdshader") and material.get_shader_parameter("native_paint")!=null and material.get_shader_parameter("rock_texture")!=null,"Independent native-view paint and reused fixed-scale stone grain: "+str(id))
  var center=Vector3((row.source_footprint[0]-1)*1.5,0,-(row.source_footprint[1]-1)*1.5);var bounds=mesh.get_aabb();var expected:Array=row.geometry_bounds
  check_((bounds.position+center-Vector3(expected[0][0],expected[0][1],expected[0][2])).length()<.001 and (bounds.end+center-Vector3(expected[1][0],expected[1][1],expected[1][2])).length()<.001,"Source-frame bounds decode without owner Y compression: "+str(id))
  check_(float(row.native_registration.fraction)==1. and int(row.closed_boulders)>0 and row.source_contour.shared_native_modified==false,"Complete observed source coverage and preserved shared source owner: "+str(id))
 print("EAST_CLIFF_VOLUME_CONTRACTS checks=",checks," failures=",failures.size())
 var file=FileAccess.open(FOLDER+"decoder-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Private ECR4 decoder/material/source-frame contracts. No map publication, gameplay performance or visual acceptance is established."},"  "));file.close()
 Baked.meshes.clear();Baked.candidate_textures.clear();Baked.candidate_data.clear();await process_frame;quit(1 if not failures.is_empty() else 0)
