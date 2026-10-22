extends RefCounted
## Quiet upper-body motion for fighters keeping their weapons ready.
const SWING_SCALE=.10
static func enabled(id: String,state: Dictionary)->bool:
	return id in ["samurai","magic-swordsman","ranger","knight"] and state.get("grounded",true) and state.get("attack")==null and not state.get("blocking",false) and not state.get("charging",false) and float(state.get("guardTime",0))<=0 and float(state.get("chargeTime",0))<=0 and float(state.get("shot",0))<=0 and float(state.get("drinkGesture",0))<=0 and float(state.get("roll",0))<=0 and state.get("travel")==null and state.get("dive")==null
static func swing_scale(id: String,state: Dictionary)->float:
	if not enabled(id,state):return 1.0
	return 0.0 if id in ["ranger","knight"] else SWING_SCALE
