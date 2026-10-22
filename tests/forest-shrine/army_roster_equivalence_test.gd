extends SceneTree
## Current playable input/ability code against original and native fitted actors.
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 if not fixture.has_method("compare_backends"):
  check(false,"Whole-roster current-input backend comparison is missing");fixture.free();finish();return
 await fixture.make_game("original")
 for id in range(1,19):
  if not OS.get_cmdline_user_args().is_empty() and id!=int(OS.get_cmdline_user_args()[0]):continue
  for scenario in ["primary","secondary","utility_tap","utility_hold","skill","movement","switch","reward"]:
   var result:Dictionary=await fixture.compare_backends(id,scenario)
   if result.legacy.samples!=result.native.samples or result.legacy.hits!=result.native.hits:
    var file=FileAccess.open("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Large Army Rebuild/Tests/roster-%d-%s.json"%[id,scenario],FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
   check(result.legacy.samples==result.native.samples,"Character%d %s movement/aim/HP samples match"%[id,scenario])
   check(result.legacy.states==result.native.states,"Character%d %s action ordering matches"%[id,scenario])
   check(result.legacy.hits==result.native.hits,"Character%d %s real fitted damage contacts match"%[id,scenario])
   check(result.legacy.released and result.native.released,"Character%d %s held input releases during pause"%[id,scenario])
   check(result.legacy.rewards==result.native.rewards,"Character%d %s kill and reward attribution matches"%[id,scenario])
   check(result.legacy.input_map==result.native.input_map,"Character%d %s uses identical player controls"%[id,scenario])
 await fixture.close();fixture.queue_free();await process_frame;finish()
func finish():
 print("ARMY_ROSTER_EQUIVALENCE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
