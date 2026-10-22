class_name RecoveredYaeCombatProfile
extends RefCounted
## Original Yae action rows at30Hz; gold tier3 and combat powers unlocked.
const DATA_PATH="res://assets/characters/recovered_yae/combat_profile.json"
const HZ=30.0
const CHARGE_SECONDS=2.0
static var cache: Dictionary={}
static func data()->Dictionary:
 if cache.is_empty():
  var file=FileAccess.open(DATA_PATH,FileAccess.READ)
  if file:cache=JSON.parse_string(file.get_as_text())
 return cache
static func action(id: int)->Dictionary:return data().get("actions",{}).get(str(id),{})
static func duration(id: int)->float:return float(action(id).get("transition_ticks",1))/HZ
static func rate(id: int)->float:return float(action(id).get("rate",1.0))
static func source_time(id: int,frame: float)->float:return ceilf(frame/maxf(absf(rate(id)),.001))/HZ
static func combo_actions()->Array:return [0x68,0x69,0x6a]
static func release_time(id: int)->float:
 return source_time(id,float(data().bazooka.source_release_frames.get(str(id),9)))
