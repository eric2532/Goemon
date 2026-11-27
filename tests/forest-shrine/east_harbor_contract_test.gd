extends SceneTree
## Exercise the actual crew actions/timer without importing the whole world.
const Harbor=preload("res://scripts/forest/forest_east_harbor.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/harbor-contracts.json"
class MockRecovered:
 static var west_boundary_available=true
 static func owns(id:int)->bool:return id!=59000 or west_boundary_available
 static func source_point(_id:int,cell:Vector2i)->Vector2:return Vector2(cell)*3.
 static func runtime_id(id:int)->int:return id+1000000 if id>=51000 else id
 static func source_id(id:int)->int:return id-1000000 if id>=1000000 else id
class MockWinter:
 const Recovered=MockRecovered
class MockIndoor:
 static func layout(id:int)->Dictionary:return {"floor":id}
class MockTour:
 const Winter=MockWinter
 const Indoor=MockIndoor
 static func travel(game,layout:Dictionary,options:Dictionary):
  game.model.falan_floor=layout.floor
  game.model.falan_area="interior"
  game.arrival=options.arrival
  game.transitioning=false
class FakeGame extends Node:
 var FalanTour=MockTour
 var model={"gold":2000,"falan_area":"interior","falan_floor":40001}
 var player={"hp":100}
 var camera_rig={"yaw":0.}
 var playing=true
 var transitioning=false
 var paused=false
 var ordinary_pause=false
 var dialogue:Node=null
 var arrival=Vector2.ZERO
 var notices=[]
 func toast(message:String):notices.append(message)
var checks=0
var failures=[]
func _initialize():
 create_timer(60,true,false,true).timeout.connect(func():printerr("EAST_HARBOR_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message);printerr("EAST_HARBOR_FAIL "+message)
func run():
 var game=FakeGame.new();root.add_child(game)
 var data=Harbor.data()
 check(data.voyage_seconds==20,"User-directed voyage lasts twenty active-play seconds")
 var crew:Array=data.actions.keys().filter(func(id):return data.actions[id].kind=="voyage")
 crew.sort()
 for id in crew:
  var action:Dictionary=data.actions[id]
  var ship:Dictionary=data.ships[str(int(action.ship))]
  var destination:Dictionary=data.ports[str(int(action.arrival))]
  check(Harbor.action(game,"east_harbor:"+id),"Crew action is recognized: "+id)
  check(game.transitioning and has_meta(Harbor.VOYAGE),"Crew starts departure immediately: "+id)
  await process_frame
  check(game.model.falan_floor==MockRecovered.runtime_id(int(ship.floor)),"Crew uses source ship arrival floor: "+id)
  Harbor.tick(game,7.)
  var attendant={1:"305051",2:"305103",10:"1102040",20:"1102230",50:"1102412"}[int(action.ship)]
  Harbor.action(game,"east_harbor:"+attendant)
  check(has_meta(Harbor.VOYAGE) and is_equal_approx(float(get_meta(Harbor.VOYAGE,{}).get("left",-1.)),13.),"Talking to the original attendant neither restarts nor skips the voyage: "+id)
  game.paused=true;Harbor.tick(game,100.);game.paused=false
  game.ordinary_pause=true;Harbor.tick(game,100.);game.ordinary_pause=false
  game.dialogue=Node.new();Harbor.tick(game,100.);game.dialogue.free();game.dialogue=null
  check(has_meta(Harbor.VOYAGE) and is_equal_approx(float(get_meta(Harbor.VOYAGE,{}).get("left",-1.)),13.),"Pause and dialogue hold the remaining voyage: "+id)
  game.model.falan_floor=MockRecovered.runtime_id(int(ship.maps[-1]));Harbor.tick(game,12.999)
  check(has_meta(Harbor.VOYAGE) and not game.transitioning,"Walking between source ship rooms preserves the timer: "+id)
  Harbor.tick(game,.0011)
  await process_frame
  check(not has_meta(Harbor.VOYAGE) and game.model.falan_floor==MockRecovered.runtime_id(int(destination.floor)),"Exactly twenty active-play seconds reach source destination: "+id)
  check(game.arrival==Vector2(destination.cell[0],destination.cell[1])*3.,"Source port landing cell is retained: "+id)
 MockRecovered.west_boundary_available=false
 var before_floor:int=game.model.falan_floor;var before_gold:int=game.model.gold
 Harbor.action(game,"east_harbor:1102413")
 check(not has_meta(Harbor.VOYAGE) and not game.transitioning and game.model.falan_floor==before_floor and game.model.gold==before_gold,"Unavailable West59000 boundary holds ship50 before timer/travel/fare")
 check(get_meta("east_harbor_blockers",{}).has("east_harbor:1102413"),"Held ship50 connection records its exact regional-owner blocker")
 MockRecovered.west_boundary_available=true
 game.model.gold=499
 Harbor.action(game,"east_harbor:305106")
 check(not game.transitioning and game.model.gold==499,"Goral return clerk cannot charge or travel with insufficient fare")
 game.model.gold=500
 Harbor.action(game,"east_harbor:305106")
 await process_frame
 check(game.model.gold==0 and game.model.falan_floor==40006 and game.arrival==Vector2(84,55)*3.,"Goral return clerk charges original fare and reaches the source return port")
 Harbor.action(game,"east_harbor:305102");await process_frame
 game.model.falan_floor=33200;Harbor.tick(game,1.)
 check(not has_meta(Harbor.VOYAGE),"Leaving the ship cancels a stale voyage")
 Harbor.action(game,"east_harbor:305102");await process_frame
 game.player.hp=0;Harbor.tick(game,1.)
 check(not has_meta(Harbor.VOYAGE),"Death clears a stale voyage")
 var file=FileAccess.open(OUT,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"directions":crew.size(),"scope":"Actual crew actions, twenty-second active-play timer, original ship/port landing cells, room changes, paused dialogue, original Goral return fare and stale-voyage cleanup. Mock travel endpoint; rendered world crossing remains separate."},"  "));file.close()
 print("EAST_HARBOR_RESULT checks=",checks," failures=",failures.size())
 game.queue_free();await process_frame
 quit(1 if not failures.is_empty() else 0)
