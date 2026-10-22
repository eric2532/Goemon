class_name RecoveredSasukeCombatProfile
extends RefCounted
## Source action rows and decoded handlers, at the original 30 game steps/second.
const DATA_PATH="res://assets/characters/recovered_sasuke/combat_profile.json"
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
static func release_time(kind: String)->float:
	return (9.0 if kind=="hail" else (8.0 if kind=="ice" else 4.0))/HZ
static func cue_time(stage: int)->float:return [2.0,6.0,7.0][clampi(stage,0,2)]/HZ
