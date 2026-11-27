extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Candidate=preload("res://scripts/forest/forest_east_cave_room_candidates.gd")
var checks=0
var failures=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
 Maps.Art.load_east();var results=[]
 for source in [11037,34018]:
  var state=Maps.state(Maps.runtime_id(source));var stage=Node3D.new();root.add_child(stage)
  var before=state.bits.duplicate();var result=Candidate.build_mass(stage,source,state);var mass=stage.get_child(0)
  check(result.source_wall_placements>100 and result.blocked_mass_cells>100,"Whole native cave wall context "+str(source))
  check(result.chunks>0 and result.triangles>0,"Existing closed boundary/chunk owner "+str(source))
  for cell:Vector2i in mass.get_meta("recovered_cliff_cells",[]):
   check(not Maps.open(state.bits,state.size,cell),"Inferred mass stays outside original walk/portal cell "+str(source)+":"+str(cell))
  check(state.bits==before,"Original walk bits unchanged "+str(source))
  results.append(result);stage.queue_free();await process_frame
 var file=FileAccess.open(Candidate.ROOT+"context-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rooms":results,"scope":"Private source-blocked closed-mass geometry only. No game scene, camera, render, route or visual-fidelity acceptance."}," "));file.close()
 print("EAST_CAVE_CONTEXT_CONTRACTS checks=",checks," failures=",failures.size());quit(failures.size())
