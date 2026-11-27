extends SceneTree
const Candidate=preload("res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate/Diagonal Contract/candidate/scripts/forest/forest_kai_terrain.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const Corridors=preload("res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate/Diagonal Contract/corridor-probe.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate/Diagonal Contract/"
var checks=0
var failures=0
var expected_errors=0
class Field extends Candidate:
 var input:Resource
 func terrain_field()->Resource:return input
 func coordinate(x:float,z:float)->Vector2:return Vector2(x+6.,z+6.)/spacing
class Model extends RefCounted:
 var terrain:RefCounted
 var navigation_revision=1
 var trees={}
 var scenery_obstacles={}
 var roads={}
 var tree_rotations={}
 var authored_scenery=false
 func surface_height(x:float,z:float)->float:return terrain.height(x,z)
class Navigation extends RefCounted:
 var terrain:RefCounted
 var building_contact_bounds={}
 func _refresh_candidates():pass
 func move_clear(point:Vector3,radius:float)->bool:return terrain.disk_clear(point,radius)
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr(message)
func surface(mask:Variant=PackedByteArray())->Resource:
 var result=Resource.new();var values=PackedFloat32Array();var coverage=PackedByteArray();var bridges=PackedByteArray()
 for z in 21:
  for x in 21:values.append(.4*sin(x*1.7)*cos(z*1.3));coverage.append(1);bridges.append(0)
 for row:Array in [["width",21],["spacing",1.3],["heights",values],["covered",coverage],["bridges",bridges]]:result.set_meta(row[0],row[1])
 if mask!=null:result.set_meta("diagonal_flips",mask)
 return result
func full_mask()->PackedByteArray:
 var result=PackedByteArray();result.resize(441)
 for z in 20:
  for x in 20:result[z*21+x]=1
 return result
func independent_height(h:Array,uv:Vector2,flip:bool)->float:
 # Barycentric interpolation from emitted triangle vertices, independent of Kai's formula.
 var corners=[Vector3(0,h[0],0),Vector3(1,h[1],0),Vector3(1,h[3],1),Vector3(0,h[2],1)]
 var indices=[0,1,2] if uv.x>=uv.y else [0,2,3]
 if not flip:indices=[0,1,3] if uv.x+uv.y<=1 else [1,2,3]
 var a:Vector3=corners[indices[0]];var b:Vector3=corners[indices[1]];var c:Vector3=corners[indices[2]]
 var determinant=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
 var u=((b.z-c.z)*(uv.x-c.x)+(c.x-b.x)*(uv.y-c.z))/determinant
 var v=((c.z-a.z)*(uv.x-c.x)+(a.x-c.x)*(uv.y-c.z))/determinant
 return u*a.y+v*b.y+(1-u-v)*c.y
func test_valid():
 var field=Field.new()
 for mode in 4:
  var mask=PackedByteArray() if mode==0 else full_mask()
  if mode==2:
   for z in 20:
    for x in 20:mask[z*21+x]=(x+z)%2
  if mode==3:mask.fill(0);mask[5*21+5]=1
  field.input=surface(mask);field.configure([])
  check(field.diagonal_mask_valid,"Valid mask accepted")
  for iz in range(1,28):
   for ix in range(1,28):
    var point=Vector2(ix*.625,iz*.625);var x=floori(point.x);var z=floori(point.y);var at=z*21+x
    var h=[field.heights[at],field.heights[at+1],field.heights[at+21],field.heights[at+22]]
    var wanted=independent_height(h,point-Vector2(x,z),not mask.is_empty() and mask[at]!=0)
    var world=point*1.3-Vector2.ONE*6
    check(absf(field.height(world.x,world.y)-wanted)<.000002,"Kai height matches selected mesh triangle")
    check(absf(field._covered_height(world.x,world.y)-wanted)<.000002,"Kai covered height matches selected mesh triangle")
  var range_=field._building_ground_result(Vector2i.ZERO,Vector2i.ZERO)
  check(range_.error.is_empty(),"Clipped gentle building footprint remains valid")
  var low=(Vector2.ONE*3.)/1.3;var high=(Vector2.ONE*9.)/1.3;var minimum=INF;var maximum=-INF
  for z in range(floori(low.y),ceili(high.y)):
   for x in range(floori(low.x),ceili(high.x)):
    var u0=maxf(0.,low.x-x);var u1=minf(1.,high.x-x);var v0=maxf(0.,low.y-z);var v1=minf(1.,high.y-z)
    var samples=[Vector2(u0,v0),Vector2(u1,v0),Vector2(u0,v1),Vector2(u1,v1)]
    var at=z*21+x;var flip=not mask.is_empty() and mask[at]!=0
    for u in [u0,u1]:
     var v=u if flip else 1-u
     if v>=v0 and v<=v1:samples.append(Vector2(u,v))
    for v in [v0,v1]:
     var u=v if flip else 1-v
     if u>=u0 and u<=u1:samples.append(Vector2(u,v))
    var h=[field.heights[at],field.heights[at+1],field.heights[at+21],field.heights[at+22]]
    for uv:Vector2 in samples:
     var value=independent_height(h,uv,flip);minimum=minf(minimum,value);maximum=maxf(maximum,value)
  check(absf(range_.minimum-minimum)<.000002 and absf(range_.maximum-maximum)<.000002,"Building clipped extrema match independent triangle samples")
 field.input=surface(null);field.configure([]);check(field.diagonal_mask_valid and field.diagonal_flips.is_empty(),"Missing/NIL metadata restores default")
 field.input=null;field.configure([]);check(field.diagonal_mask_valid and field.diagonal_flips.is_empty(),"Null-surface setup clears prior mask")
func test_invalid():
 var short_=PackedByteArray([0]);var bad=full_mask();bad[0]=2;var last_row=full_mask();last_row[420]=1;var last_column=full_mask();last_column[20]=1
 for mask:Variant in [short_,bad,last_row,last_column,"invalid",PackedInt32Array([1])]:
  var field=Field.new();field.input=surface(mask);print("EXPECTED_MASK_REJECTION_BEGIN");field.configure([{"ax":0,"az":0,"bx":1,"bz":0,"width":1,"h0":6,"h1":6}]);expected_errors+=1;print("EXPECTED_MASK_REJECTION_END")
  check(not field.diagonal_mask_valid,"Invalid mask is marked invalid in release path")
  check(not field.contains(1,0) and is_nan(field.height(1,0)) and is_nan(field._covered_height(1,0)),"Invalid mask cannot expose flat0 or piece fallback")
  check(not field.disk_clear(Vector3(1,6,0),.25),"Invalid mask rejects body disk")
  check(not field._building_ground_result(Vector2i.ZERO,Vector2i.ZERO).error.is_empty(),"Invalid mask rejects building support")
func test_corridors():
 check(ClassDB.class_exists("GoemonTerrainMath"),"Actual legacy accelerator is loaded for eligibility proof")
 var model=Model.new();model.terrain=Candidate.new();var navigation=Navigation.new();navigation.terrain=model.terrain;var corridor=Corridors.new(model,navigation)
 Candidate.field=surface();model.terrain.configure([]);corridor._refresh(model)
 check(corridor.native_sampler!=null,"Empty valid mask retains existing native accelerator")
 Candidate.field=surface(full_mask());model.terrain.configure([]);model.navigation_revision+=1;corridor._refresh(model)
 check(corridor.native_sampler==null,"Nonempty orientation mask uses existing GDScript path")
 Candidate.field=surface("invalid");print("EXPECTED_MASK_REJECTION_BEGIN");model.terrain.configure([]);expected_errors+=1;print("EXPECTED_MASK_REJECTION_END");model.navigation_revision+=1;corridor._refresh(model)
 check(not model.terrain.diagonal_mask_valid and model.terrain.diagonal_flips.is_empty(),"Wrongtype exact Kai input has invalid state despite empty decoded mask")
 check(corridor.native_sampler==null,"Invalid mask cannot bypass Kai guard through native accelerator")
 var result=corridor.probe(PackedVector3Array([Vector3(-239,0,-239)]),PackedFloat64Array([.25]))
 check(result.size()==2 and is_nan(result[0]) and result[1]==0,"Actual corridor probe fails closed after malformed metadata")
 Candidate.field=surface(null);model.terrain.configure([]);model.navigation_revision+=1;corridor._refresh(model)
 check(model.terrain.diagonal_mask_valid and corridor.native_sampler!=null,"Default orientation/accelerator recovers after invalid setup")
 Candidate.field=null
func _initialize():
 var paths=["res://tests/forest-shrine/east_diagonal_kai_test.gd",ROOT+"candidate/scripts/forest/forest_kai_terrain.gd",ROOT+"candidate/scripts/forest/forest_terrain_corridors.gd",ROOT+"corridor-probe.gd",ROOT+"source-contract.json","res://scripts/forest/forest_ramparts.gd"]
 var before=Fresh.snapshot(paths)
 test_valid();test_invalid();test_corridors()
 var changed=Fresh.changed(before);check(changed.is_empty(),"Candidate source stayed current")
 var report={"checks":checks,"failures":failures,"expected_push_errors":expected_errors,"source_hashes":before,"source_changed":changed,"scope":"Isolated candidate Kai sampler/building/malformed contract only; no active Host scene"}
 var file=FileAccess.open(ROOT+"kai-proof.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_DIAGONAL_KAI ",checks,"/",failures," expected_push_errors=",expected_errors)
 quit(1 if failures else 0)
