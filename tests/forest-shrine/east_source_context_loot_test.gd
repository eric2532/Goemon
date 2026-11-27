extends SceneTree
## Staged private-town guard only; no source chest/reward or live scene changes.
const Context=preload("res://scripts/forest/forest_east_source_context_review.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT=Context.ROOT+"Town Entry Loot/"
class BlockedGrid:
 extends RefCounted
 func is_point_solid(_at):return true
class Model:
 extends RefCounted
 var falan_area="alyut"
 var falan_floor=0
 var terrain_detail=""
 var terrain=Resource.new()
 var falan_scale=1.3
 var seed_value=42
 var gold=321
 var navigation_region=Rect2i(0,0,1,1)
 var allied_grid=BlockedGrid.new()
 var placement_started=0
 func nearest_open(_at):placement_started+=1;return Vector2i.ZERO
 func cell_of(_point):return Vector2i.ZERO
 func world_point(at:Vector2,_rise:float=0.):return Vector3(at.x,0,at.y)
class Game:
 extends Node
 const FalanTour=preload("res://scripts/forest/forest_falan_tour.gd")
 const PLAYER_SPAWN_CELL=Vector2i.ZERO
 var model=Model.new()
var checks=0
var failed=[]
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failed.append(label);push_error(label)
func sample(script:Script,active:bool,owned:bool,area_:String)->Dictionary:
 Tour.Regions.private_source_context=Context if active else null
 var game=Game.new();game.model.falan_area=area_
 if owned:game.model.terrain.set_meta("east_alyut_separate_source_private" if area_=="alyut" else "east_il_low_source_private",true)
 var loot=script.new();loot.game=game;loot.prepare_world()
 var result={"placement_started":game.model.placement_started,"gold":game.model.gold,"slots":loot.slots.size(),"prepared":loot.prepared_model!=null};loot.free();game.free();return result
func run():
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"source-review.json"));var paths:Array=manifest.unchanged_source_quest_map_generator_inputs.keys();paths.append_array([get_script().resource_path,"scripts/forest/forest_east_source_context_review.gd","scripts/forest/exploration_loot.gd",OUT+"exploration_loot.gd",OUT+"source-review.json"])
 paths.append(OUT+"exploration_loot-before.gd")
 var before=Fresh.snapshot(paths);check(Tour.Regions.private_source_context==null,"Loot guard test starts with default-null context")
 var source=FileAccess.get_file_as_string(OUT+"exploration_loot-before.gd");var staged=FileAccess.get_file_as_string(OUT+"exploration_loot.gd")
 var added="\tvar source_context=game.FalanTour.Regions.private_source_context\n\tif source_context!=null and source_context.suppress_entry_chests(model):return\n"
 check(staged.replace(added,"")==source and source.sha256_text()==manifest.baseline_sha256 and FileAccess.get_sha256("res://scripts/forest/exploration_loot.gd") in [manifest.baseline_sha256,manifest.candidate_sha256],"The reviewed/applied loot change is exactly one default-off adapter guard; every source/generator/death/reward method is byte-identical")
 var original:Script=load(OUT+"exploration_loot-before.gd");var candidate:Script=load(OUT+"exploration_loot.gd")
 for area_ in ["il_village","alyut"]:
  var ordinary=sample(original,false,false,area_);var default_=sample(candidate,false,false,area_)
  check(default_==ordinary and int(default_.placement_started)==1,"Default-null town entry executes exactly the unchanged generic path "+area_)
  var owned=sample(candidate,true,true,area_)
  check(owned.placement_started==0 and owned.slots==0 and owned.prepared,"Privately owned original Town has no extra procedural entry chests "+area_)
  check(owned.gold==321,"Town entry guard leaves Gold/quest services untouched "+area_)
  check(sample(candidate,true,false,area_)==ordinary,"Unowned Town remains on its existing loot behavior "+area_)
 var model=Model.new()
 for area_ in ["north_coast","east_gate","interior","city","freyja"]:
  model.falan_area=area_;check(not Context.suppress_entry_chests(model),"Other owners and generated interiors are outside the private Town loot guard "+area_)
 for path:String in manifest.unchanged_source_quest_map_generator_inputs:check(FileAccess.get_sha256("res://"+path)==manifest.unchanged_source_quest_map_generator_inputs[path],"Source map/NPC/program/generator/input bytes stay untouched "+path)
 Tour.Regions.private_source_context=null;var changed=Fresh.changed(before);check(changed.is_empty(),"Staged loot proof source inputs remained current")
 var report={"checks":checks,"failures":failed,"source_hashes":before,"source_changed_during_run":changed,"scope":"Pure fake-blocked-placement comparison of existing versus staged prepare_world, plus exact one-guard diff/source preservation. No shared loot application, rendered chest/NPC claim, actual scene or global loot rewrite."}
 var file=FileAccess.open(OUT+"contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close();print("EAST_TOWN_ENTRY_LOOT checks=",checks," failures=",failed.size());quit(failed.size())
