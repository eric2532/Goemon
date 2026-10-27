extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var runtime=Runtime.new();runtime.configure(null);seed(102222)
 for fixture in 500:
  var rows=[];var handles={};var expected={};var fallback=PackedInt64Array()
  for i in 50:
   var row={"id":fixture*100+i,"variant":[0,1,3,2,4,-1][randi()%6],"hp":[0,100.0,-1.0][randi()%3]};rows.append(row)
   if i%3:handles[row.id]=4294967296+i%10 # Duplicate handles preserve last-row ownership.
   if row.hp<=0:continue
   var handle:int=handles.get(row.id,0)
   if handle==0 or not Soldier.supports(row.variant):fallback.append(i)
   else:expected[handle]=i
  runtime.handles=handles
  var held=rows.duplicate(true);var index:Dictionary=runtime.index_enemy_rows(rows)
  check(index.valid and index.handles==expected and index.fallback==fallback,"Native index preserves model order, pending rows, unsupported bodies, dead rows and duplicate handles")
  check(rows==held,"Indexing never mutates caller-owned model rows")
 for bad in [[{}],[null],[{"id":1,"variant":0,"hp":"bad"}]]:
  check(not runtime.native.index_enemy_rows(bad,{},Soldier.ROLE_TO_TYPE).valid,"Malformed row capture is rejected before a caller can use its index")
 check(runtime.index_enemy_rows([]).valid,"Empty armies produce a valid empty capture")
 var handle:int=runtime.spawn(1,0,0,Vector3(3,4,5),123.456789,1.3);runtime.set_pose(handle,Vector3(3,4,5),.7)
 var held=runtime.unit_state(handle);var keys=held.keys().duplicate();runtime.free()
 check(held.hp==123.456789 and held.position==Vector3(3,4,5) and held.keys()==keys and held.size()==28,"A full typed hit-state dictionary remains owned and readable after its native key cache is freed")
 print("ARMY_TOWER_INDEX_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
