extends SceneTree
const Shapes=preload("res://scripts/forest/forest_coastal_buildings.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Sokia full-source outdoors/"
func _initialize():
 create_timer(60).timeout.connect(func():printerr("SOKIA_HOUSE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var records={};var failures=0;var checks=0
 var turn=Basis(Vector3.UP,PI*.5)
 var source=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"house-original-metadata.json"))
 for serial in [11289,11290,11292,11293,11294,11295,11298]:
  var row:Array=Shapes.Data.GRAPHICS[serial];var span:Vector2=row[2]
  var offset=Vector3((span.x-3.)*.5,0,(3.-span.y)*.5)
  var expected:Array=[source[str(serial)].x,source[str(serial)].y]
  var origin:Vector2=Shapes.Proportions.project(turn*offset)-row[1]
  checks+=1
  if origin.distance_to(Vector2(expected[0],expected[1]))>.0001:failures+=1
  var mesh:Mesh=Shapes.shape(serial);var points:Array[Vector3]=Shapes.Proportions.mesh_points(mesh)
  var foot=AABB();var found=false
  for p in points:
   if absf(p.y)>.0001:continue
   if found:foot=foot.expand(p)
   else:foot=AABB(p,Vector3.ZERO);found=true
  checks+=1
  if not found or points.is_empty():failures+=1
  var projected=Shapes.Proportions.projected_bounds(points,Transform3D(turn,turn*offset))
  records[serial]={"model_span_metres":[span.x,span.y],"source_tile_span":[span.x/3.,span.y/3.],"source_anchor_to_mesh_centre":[offset.x,offset.y,offset.z],"computed_graphic_origin":[origin.x,origin.y],"original_graphic_origin":expected,"mesh_aabb":[mesh.get_aabb().position.x,mesh.get_aabb().position.y,mesh.get_aabb().position.z,mesh.get_aabb().size.x,mesh.get_aabb().size.y,mesh.get_aabb().size.z],"actual_y0_foot_aabb":[foot.position.x,foot.position.z,foot.size.x,foot.size.z],"actual_source_projected_bounds":[projected.position.x,projected.position.y,projected.size.x,projected.size.y]}
 var file=FileAccess.open(REVIEW+"house-native-contract.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"houses":records,"limits":"Measured whole existing mesh and original calibrated origin; this does not certify every hidden surface or a rendered silhouette."},"  ")+"\n");file.close()
 print("SOKIA_HOUSE_CONTRACT ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
