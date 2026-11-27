extends RefCounted
## Reset only the current encounter's combat ledger; travel never calls this.
const LEDGERS={"habaru_slot":"habaru_slain","zombie_slot":"zombie_slain","captain_slot":"captain_slain","grave_slot":"grave_slain","falken_slot":"falken_slain","frostpass_slot":"frostpass_slain","venoa_bear_slot":"venoa_bear_slain"}

static func supported(identity:String)->bool:
 return identity.begins_with("regional:")or identity.begins_with("elsa:")or identity.begins_with("endpoint:")or identity in LEDGERS or identity in["undersea_slot","ruby_slot"]

static func begin(game,record:Dictionary)->bool:
 var identity:String=record.group;var tree:SceneTree=game.get_tree();var waves=game.model.waves
 if identity.begins_with("regional:"):return preload("res://scripts/forest/forest_university_region.gd").begin(game,identity.trim_prefix("regional:"),-1,true)
 if identity.begins_with("elsa:"):
  load("res://scripts/forest/forest_elsa_route.gd").begin(game,identity.trim_prefix("elsa:"));return true
 if identity.begins_with("endpoint:"):
  return preload("res://scripts/forest/forest_explore_endpoints.gd").spawn(game,game.explore_access.endpoint)
 if identity=="undersea_slot":
  waves.undersea_source_requested=false;waves.undersea_source_pending=false;waves.snow_pending.clear();waves.snow_group_ids.clear()
  return true
 if identity=="ruby_slot":
  var ruby=game.FalanTour.Ruby;var events=game.FalanTour.RubyEvents
  tree.set_meta(ruby.SLAIN,{})
  var state:Dictionary=tree.get_meta(events.STATE,{})
  if not state.is_empty():state.active=true;state.complete=false;tree.set_meta(events.STATE,state)
  waves.spawned=0;return true
 if not LEDGERS.has(identity):return false
 var ledger:String=LEDGERS[identity]
 if identity=="falken_slot":ledger=game.FalanTour.Falken.SLAIN
 if identity=="venoa_bear_slot":ledger=game.Habaru.VENOA_SLAIN
 var slain:Dictionary=tree.get_meta(ledger,{}).duplicate()
 for key in slain.keys():
  if key is Vector2i and key.x!=game.model.falan_floor:continue
  if identity=="venoa_bear_slot"and int(key)/100!=game.model.falan_floor:continue
  if identity=="zombie_slot"and int(key)!=0 and int(key)/10!=game.model.falan_floor:continue
  slain.erase(key)
 tree.set_meta(ledger,slain)
 # Surviving ambient members are retired without kills/rewards before the existing spawner rebuilds its formation.
 for enemy in game.model.enemies.values().filter(func(e):return e.has(identity)):
  var handle:int=game.army_runtime.handles.get(enemy.id,0)
  if handle!=0:game.army_runtime.despawn(handle)
  game.model.enemies.erase(enemy.id)
 waves.spawned=0
 if identity=="habaru_slot":
  game.habaru_dialogue_seen=false
  if is_instance_valid(game.habaru_waiting):game.habaru_waiting.show()
  else:game.prepare_habaru_dialogue()
 if identity=="falken_slot":
  game.falken_dialogue_seen=false
  if is_instance_valid(game.falken_waiting):game.falken_waiting.show()
  else:game.prepare_falken_dialogue()
 return true
