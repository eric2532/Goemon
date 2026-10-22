extends RefCounted
## Original body-stream windows. World collision/damage remain game adapters.
const HZ=30.0
const CHARGE_LIMIT=128
const CHARGE_PER_TICK=3 # func_8014A59C, without the optional fast-charge item.
static var _actions:Dictionary={}
static func action(key:String)->Dictionary:
	if _actions.is_empty():
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_musashi/action_sources.json"))
		_actions=data.actions
	return _actions.get(key,{})
static func duration(key:String)->float:return float(action(key).ticks)/HZ
static func window(key:String)->Array[float]:
	var data=action(key);var ticks:Array=data.active_ticks
	if ticks.is_empty():return [0.0,0.0]
	# Vector2 components are single precision and can delay an exact source tick.
	return [float(ticks[0])/HZ,float(ticks[1] if ticks.size()>1 else data.ticks)/HZ]
static func cue(key:String,word:String)->float:
	for event in action(key).events:
		if event.word==word:return float(event.tick)/HZ
	return -1.0
