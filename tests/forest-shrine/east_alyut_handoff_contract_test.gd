extends SceneTree
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const PRIVATE="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate/"
var checks=0
var failures=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
 Full.review_root="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/MissingAlyutHandoff/"
 check(not Full.field_handoff(Vector2i(58,30)),"Missing/disabled source completion has no field handoff")
 Full.review_root=PRIVATE
 var expected={}
 for x in [58,59]:
  for y in range(28,31):expected[Vector2i(x,y)]=true
 for x in [66,67]:
  for y in range(61,64):expected[Vector2i(x,y)]=true
 for y in 100:
  for x in 100:
   var cell=Vector2i(x,y);check(Full.field_handoff(cell)==expected.has(cell),"Exact original field handoff "+str(cell))
 var cache_key=[PRIVATE,String(Full.data().source.sha256)]
 check(Full.handoff_cells.has(cache_key) and Full.handoff_cells[cache_key].size()==12,"Handoff cells cached by folder/source hash")
 for cell in [Vector2i(58,31),Vector2i(59,31),Vector2i(66,64),Vector2i(67,64),Vector2i(36,73)]:check(not Full.field_handoff(cell),"Gate/known-flower source cells remain village-owned "+str(cell))
 var file=FileAccess.open(PRIVATE+"handoff-api-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hybrid_sha256":Full.data().source.sha256,"scope":"Exact12-cell cached source context API only; Region integration is owned/tested separately."}," "));file.close()
 print("EAST_ALYUT_HANDOFF_API checks=",checks," failures=",failures.size());quit(failures.size())
