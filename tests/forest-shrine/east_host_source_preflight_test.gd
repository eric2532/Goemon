extends SceneTree
const Host=preload("res://scripts/forest/forest_east_host_source_context.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/"
var checks=0
var errors=[]
func _initialize():run.call_deferred()
func check(yes:bool,label:String):
 checks+=1
 if not yes:errors.append(label);if errors.size()<=10:printerr("EAST_HOST_PREFLIGHT_FAIL ",label)
func run():
 var restore_path=ROOT+"Village Props/Cliff Audit/Source Context Audit/Prototype/field100-restore.json"
 var audit_path=ROOT+"Runtime Audit/Source100 Completeness/report.json"
 var snapshot=Fresh.snapshot([get_script().resource_path,"scripts/forest/forest_east_host_source_context.gd",restore_path,audit_path,Host.SHORE])
 var restore:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(restore_path));var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(audit_path))
 for row:Dictionary in audit.source100_entrances_and_returns:
  var state:Dictionary=row.state
  if state.context not in ["field","joined-Il-context","joined-Alyut-context"]:continue
  var cell=Vector2i(state.cell[0],state.cell[1]);check(Host.can_travel(100,cell,restore)==bool(state.full_open),"Original audited field endpoint "+str(cell))
 for row:Dictionary in audit.source100_actors:
  var state:Dictionary=row.state
  if state.context not in ["field","joined-Il-context","joined-Alyut-context"]:continue
  var cell=Vector2i(state.cell[0],state.cell[1]);check(Host.can_travel(100,cell,restore)==bool(state.full_open),"Original audited field actor "+str(cell))
 for cell:Vector2i in [Vector2i(681,343),Vector2i(682,343),Vector2i(595,83),Vector2i(596,83),Vector2i(587,50),Vector2i(588,50)]:check(Host.can_travel(100,cell,restore),"Exact original village field transfer stays eligible "+str(cell))
 check(not Host.can_travel(100,Vector2i(681,344),restore),"Original blocked11077gate footprint stays closed")
 for cell:Vector2i in [Vector2i(-1,0),Vector2i(840,609),Vector2i(839,610),Vector2i(374,327),Vector2i(398,583),Vector2i(526,399),Vector2i(600,600)]:
  check(not Host.scene_contains(cell) and not Host.can_travel(100,cell,restore),"OutsideEast/Northorothergoal destination rejected "+str(cell))
 check(not Host.can_travel(2000,Vector2i(44,31),restore),"Host owner does not consume a village source")
 var changed=Fresh.changed(snapshot);check(changed.is_empty(),"Preflight remained source-current")
 var file=FileAccess.open(ROOT+"Il Source Completion/Low Source Candidate/Host/preflight-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors.size(),"failed":errors,"source_hashes":snapshot,"source_changed":changed,"scope":"Private original-source100 destination eligibility only. Nativebit+ownedscenebounds/othergoal preflight; no terrain/physical route/player/art acceptance."},"  "));file.close();print("EAST_HOST_PREFLIGHT checks=",checks," failures=",errors.size());quit(1 if not errors.is_empty() else 0)
