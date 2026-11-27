extends SceneTree
## Unknown source encounter operands cannot silently grant progression.
const Battle=preload("res://scripts/forest/forest_east_battles.gd")
class Game extends Node:
 var notices=[]
 func toast(value:String):notices.append(value)
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message);printerr("EAST_BATTLE_RESULTS_FAIL "+message)
func run():
 var game=Game.new();root.add_child(game)
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/population.json"))
 for id in ["80028","80006"]:
  var actor:Dictionary=source.actors.filter(func(row):return str(row.id)==id)[0]
  var raw=str(actor.script);var args=raw.split("|",true)
  var spec={"actor":actor,"raw_args":raw,"encounter":int(args[9]),"win":[15506,16,20] if id=="80028" else [100,665,184]}
  check(not Battle.victory(game,"test",spec),"Unknown item/flag result does not authorize an endpoint warp "+id)
  check(get_meta("east_battle_blockers",{}).has(id),"Exact source actor/result operands remain reviewable "+id)
  remove_meta("east_battle_blockers")
 var actor:Dictionary=source.actors.filter(func(row):return str(row.id)=="80023")[0]
 check(not Battle.victory(game,"test",{"actor":actor,"raw_args":actor.script,"encounter":9016,"win":[]}),"Source Shadow supplies no invented endpoint")
 check(not has_meta("east_battle_blockers"),"Source message IDs alone do not become false quest-result blockers")
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Verification/battle-result-contracts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual source Zombie/Minotaur unknown-result holds and Shadow no-endpoint behavior. No native fight or item-result semantics inferred."},"  "));file.close()
 print("EAST_BATTLE_RESULTS_RESULT checks=",checks," failures=",failures.size())
 game.queue_free();await process_frame;quit(1 if not failures.is_empty() else 0)
