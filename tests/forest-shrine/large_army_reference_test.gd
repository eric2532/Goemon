extends SceneTree
const REFERENCE="res://tests/forest-shrine/fixtures/large_army_reference.json"
var failures=0
var checks=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 if not FileAccess.file_exists(REFERENCE):
  check(false,"Large-army reference is missing; capture current controls and real attack behavior before replacing NPCs")
  finish();return
 var reference=JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
 var approved=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/fixtures/large_army_approved_updates.json"))
 var expected_hashes:Dictionary=reference.protected_hashes.duplicate();expected_hashes.merge(approved.approved_source_hashes,true)
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 await fixture.make_game("original")
 check(fixture.input_map()==reference.input_map,"Player input bindings remain the captured bindings")
 check(fixture.protected_hashes()==expected_hashes,"Protected playable implementations remain unchanged")
 for id in range(1,19):
  var expected:Dictionary=reference.players[str(id)].duplicate(true)
  if approved.players.has(str(id)):expected=approved.players[str(id)]
  var first=await fixture.trace_player(id,[])
  var second=await fixture.trace_player(id,[])
  check(first==second,"Player %d produces deterministic input/action traces"%id)
  check(JSON.parse_string(JSON.stringify(first))==expected,"Player %d retains captured movement and attack behavior"%id)
  check(first.movement>0,"Player %d responds to the existing movement input"%id)
  check(first.released,"Player %d releases held input while the game is paused"%id)
 for kit in [5,7,8,10,11]:
  var trace=await fixture.trace_ally(kit,"opening")
  check(JSON.parse_string(JSON.stringify(trace))==approved.paid_allies[str(kit)],"Ally %d retains the reviewed current paid-guard source trace"%kit)
 await fixture.close();fixture.queue_free();await process_frame
 finish()
func finish():
 print("LARGE_ARMY_REFERENCE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
