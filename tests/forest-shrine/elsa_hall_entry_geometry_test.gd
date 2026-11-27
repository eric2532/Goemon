extends SceneTree
## Staged mesh topology/footprint proof, not playable or visual acceptance.
var checks=0
var failures=0

func _initialize():run.call_deferred()

func check(value:bool,message:String):
 checks+=1
 if not value:failures+=1;printerr("ELSA_HALL_ENTRY_FAIL ",message)

func run():
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Elsa Island/Temple Interior/Hall Entry Candidate/data.json"))
 check(int(data.map)==59530 and data.candidate_only,"Draft stays explicitly staged on its real source map")
 check(data.steps.sample_ground and data.steps.tiers.size()==5,"Five source treads retain the existing ground-sampled stair contract")
 var footprint_error=0.
 for i in data.steps.tiers.size():
  var tier:Dictionary=data.steps.tiers[i];var all:Array=tier.points+tier.back_points;var polygon=PackedVector2Array()
  for point in all:polygon.append(Vector2(point[0],point[2]))
  var triangles=Geometry2D.triangulate_polygon(polygon)
  check(not triangles.is_empty(),"Closed source tread triangulates "+str(i))
  var expected=0.;var actual=0.
  var origin=polygon[0]
  for j in polygon.size():expected+=(polygon[j]-origin).cross(polygon[(j+1)%polygon.size()]-origin)*.5
  for j in range(0,triangles.size(),3):
   var a=polygon[triangles[j]];var b=polygon[triangles[j+1]];var c=polygon[triangles[j+2]]
   actual+=absf((b-a).cross(c-a))*.5
  check(absf(actual-absf(expected))<.01,"Triangulation covers the original tread without overlaps "+str(i))
  for j in tier.points.size():
   var point:Array=tier.points[j];var pixel=Vector2((point[0]+point[2])*32./3.,(point[2]-point[0])*8.)
   var source_:Array=data.source_curves[i][j]
   footprint_error=maxf(footprint_error,pixel.distance_to(Vector2(source_[0],source_[1])))
 check(footprint_error<.001,"All original XZ source footprints remain fixed without a height-dependent coordinate warp")
 check(float(data.steps.grid.heights.min())< -3. and is_zero_approx(float(data.steps.grid.heights.max())),"Preliminary local support descends from the unchanged upper floor")
 var steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd");steps.records[59530]=data
 var origin=Vector2(data.steps.map_origin[0],data.steps.map_origin[1])
 check(steps.height(origin.x+59*3,origin.y+93*3,59530)<-5.,"The exact original59,93 event meets the lower support without moving its XZ")
 check(is_zero_approx(steps.height(origin.x+69*3,origin.y+92*3,59530)),"The confirmed upper approach stays at its existing height")
 var grid:Dictionary=data.steps.grid;var border=0.
 for z in int(grid.size[1]):
  for x in int(grid.size[0]):
   if x in [0,int(grid.size[0])-1] or z in [0,int(grid.size[1])-1]:border=maxf(border,absf(float(grid.heights[z*int(grid.size[0])+x])))
 check(border<.0001,"The local support rejoins the unchanged flat physical ground at every cutout edge")
 print("ELSA_HALL_ENTRY_GEOMETRY_RESULT checks=",checks," failures=",failures," source_footprint_error=",footprint_error)
 quit(0 if failures==0 else 1)
