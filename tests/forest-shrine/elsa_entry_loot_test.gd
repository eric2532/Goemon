extends SceneTree
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Loot=preload("res://scripts/forest/exploration_loot.gd")
class AreaModel extends RefCounted:
 var falan_area="interior"
 var falan_floor=0
 var terrain_detail=""
 var unexpected_access=false
 func _get(_property:StringName)->Variant:
  unexpected_access=true;return null
class TestGame extends Node:
 const FalanTour=preload("res://scripts/forest/forest_falan_tour.gd")
 var model:RefCounted
class Result extends RefCounted:
 var checks=0
 var errors:Array[String]=[]
 func check(ok:bool,message:String):
  checks+=1
  if not ok:errors.append(message)
func _initialize():run.call_deferred()
static func evaluate()->Dictionary:
 var result=Result.new()
 Original.Art.load_elsa()
 var game=TestGame.new();var loot=Loot.new();loot.game=game
 var maps:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/elsa/catalog.json")).maps
 result.check(maps.size()==95,"All95 island and journey source maps are covered")
 for row in maps.values():
  game.model=AreaModel.new();game.model.falan_floor=int(row.id)
  # The stub intentionally has no navigation/RNG data: source entry must return
  # before it attempts generic placement, not merely happen to place zero boxes.
  loot.prepare_world()
  result.check(loot.slots.is_empty() and not game.model.unexpected_access,"No generic entry chests on source map%d"%int(row.id))
  loot.prepared_model=null;loot.prepare_world()
  result.check(loot.slots.is_empty() and not game.model.unexpected_access,"Repeated preparation stays source-only on map%d"%int(row.id))
 game.model=AreaModel.new();game.model.falan_floor=15526;loot.prepare_world()
 result.check(loot.slots.is_empty() and not game.model.unexpected_access,"Existing fixed15526 policy is retained")
 loot.free();game.free()
 return {"checks":result.checks,"errors":result.errors}
func run():
 var result=evaluate()
 for error in result.get("errors",[]):printerr("ELSA_ENTRY_LOOT_FAIL ",error)
 print("ELSA_ENTRY_LOOT_RESULT checks=",result.get("checks",0)," failures=",result.get("errors",[]).size())
 quit(0 if result.get("checks",0)==192 and result.get("errors",[]).is_empty() else 1)
