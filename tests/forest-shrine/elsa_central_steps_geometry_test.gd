extends "res://tests/forest-shrine/original_maps_test.gd"
## Inspect the actual shared mesh arrays without a scene or GPU mesh readback.
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/Elsa Island/Temple Interior/Central Assembly Candidate/Steps/"

func run():
 var row:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"data.json"));var paints={}
 for pair in [["native","native-paint.png"],["floor","floor-paint.png"],["body","body.png"],["stone","stone.png"],["cap","cap.png"],["gold","gold.png"]]:
  paints[pair[0]]=ImageTexture.create_from_image(Image.load_from_file(FOLDER+pair[1]))
 var mesh=Scenery.central_steps_mesh(row,paints)
 check(mesh==Scenery.central_steps_mesh(row,paints),"Repeated setup shares the prepared source mesh")
 check(mesh.has_meta("source_all_surface_arrays"),"All surfaces retain CPU arrays")
 var arrays:Array=mesh.get_meta("source_all_surface_arrays");var names:Array=mesh.get_meta("source_paint_names")
 check(arrays.size()==mesh.get_surface_count() and arrays.size()==names.size(),"Every material boundary retains its matching geometry")
 var triangles=0;var finite=true;var minimum_area=INF
 for i in arrays.size():
  var vertices:PackedVector3Array=arrays[i][Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[i][Mesh.ARRAY_NORMAL]
  var uv:PackedVector2Array=arrays[i][Mesh.ARRAY_TEX_UV]
  check(vertices.size()==normals.size() and vertices.size()==uv.size(),"Complete vertex/normal/paint data "+names[i])
  for p in vertices:finite=finite and p.is_finite()
  for p in uv:finite=finite and p.is_finite() and p.x>=0. and p.x<=1. and p.y>=0. and p.y<=1.
  for j in range(0,vertices.size(),3):
   minimum_area=minf(minimum_area,(vertices[j+1]-vertices[j]).cross(vertices[j+2]-vertices[j]).length()*.5);triangles+=1
 check(finite,"Actual prepared positions and UVs are finite and bounded")
 check(minimum_area>.00000001,"Terminal front faces do not become zero-width treads")
 check(mesh.get_aabb().end.y>float(row.top_height),"The landing's source coping has real height above its deck")
 check(row.flights.size()==2 and row.slabs.size()==2,"Both turning flights and both connecting landings exist")
 print("ELSA_CENTRAL_STEPS_GEOMETRY checks=",checks," failures=",failures," triangles=",triangles," minimum_area=",minimum_area)
 await finish()
