extends SceneTree
## Setup/teardown readiness and unowned-area guards; no Host scene or route claim.
const Context=preload("res://scripts/forest/forest_east_source_context_review.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
class CountingHost:
 extends RefCounted
 static var calls=0
 static var resets=0
 static func ready(_restore):calls+=1;return false
 static func configure_model(_model,_restore):pass
 static func add_navigation(_nav,_model):pass
 static func build(_root,_model):pass
 static func prepare_world(_world,_player):pass
 static func can_travel(_source,_cell,_restore):return false
 static func apply_materials(_ground,_water,_terrain):pass
 static func scene_handoff(_model,_before,_at,_radius):return {}
 static func owns(_model):return true
 static func reset():resets+=1
class Model:
 extends RefCounted
 var falan_area="freyja"
class Game:
 extends RefCounted
 var model=Model.new()
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_source_context_review.gd"];var before=Fresh.snapshot(paths)
 Context.reset();var game=Game.new()
 check(not Context.host_ready() and Context.scene_handoff(game,Vector2.ZERO,Vector2.RIGHT).is_empty(),"Null private owner does not require player/native traits")
 Context.host_owner=CountingHost;Context.restored_field={"raw_sha256":"readiness-contract-one"}
 for area_ in ["freyja","south_gate","city","interior","il_village","alyut"]:
  game.model.falan_area=area_;check(Context.scene_handoff(game,Vector2.ZERO,Vector2.RIGHT).is_empty(),"Unowned area never enters the Host handoff "+area_)
 check(CountingHost.calls==0,"Unowned/default handoff guards do not inspect Host files/readiness")
 game.model.falan_area="north_coast"
 for i in 60:check(Context.scene_handoff(game,Vector2.ZERO,Vector2.RIGHT).is_empty(),"Unready Host cannot initiate movement handoff sample"+str(i))
 check(CountingHost.calls==1,"Repeated frame queries evaluate immutable Host readiness once at setup")
 Context.restored_field={"raw_sha256":"readiness-contract-two"}
 check(not Context.host_ready() and CountingHost.calls==2,"A different explicit raw input has a separate readiness result")
 Context.reset();check(Context.host_readiness.is_empty() and Context.host_owner==null and CountingHost.resets==1,"Teardown drops only private readiness ownership and calls its owner reset")
 Context.host_owner=CountingHost;Context.restored_field={"raw_sha256":"readiness-contract-two"}
 check(not Context.host_ready() and CountingHost.calls==3,"A reset process payload revalidates even the same raw input")
 Context.reset();var changed=Fresh.changed(before);check(changed.is_empty(),"Handoff adapter contract sources remained current")
 var report={"checks":checks,"failures":failures,"host_readiness_evaluations":CountingHost.calls,"source_hashes":before,"source_changed_during_run":changed,"scope":"Pure default/unowned guards and setup-time readiness cache lifecycle. No geometric/outward preflight, source100 scene, player/pet movement or route acceptance. Historical seam52assertions mean13directions times4radii across five cells/eight undirected edges, not52distinct edges."}
 var file=FileAccess.open(Context.ROOT+"handoff-adapter-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_SOURCE_HANDOFF_ADAPTER checks=",checks," failures=",failures.size());quit(failures.size())
