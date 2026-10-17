extends RefCounted
## Sparse per-character overrides; the old prototype section remains the baseline.
const Roster=preload("res://scripts/rogue_roster.gd")
const MELEE_IDS=[1,3,4,5,7,8,9,11,12]
const MELEE_ROWS=[["melee_reach","Melee reach ×",.5,3,.05]]
const COMMON_ROWS=[
	["max_hp","Base maximum HP",10,5000,10],
	["damage_mult","Damage ×",.1,10,.1],
	["critical_chance","Critical chance (%)",0,100,1],
	["walk_speed","Run speed",3,40,.1],
	["sprint_speed","Sprint speed",8,60,.5],
	["jump_speed","Jump launch speed",8,40,.25],
	["second_jump_speed","Double-jump launch speed",8,40,.25]
]

static func key_for(id: int)->String:
	return "goemon" if id==1 else ("edo" if id==2 else Roster.class_id(id))

static func name_for(id: int)->String:
	return "Goemon" if id==1 else ("Edo" if id==2 else Roster.name_for(id))

static func special_rows(id: int)->Array:
	if id==1:return MELEE_ROWS+[["pipe_range","Pipe reach (m)",1.5,12,.25]]+PrototypeTuning.COIN_ROWS
	if id==2:return PrototypeTuning.BEAM_ROWS
	return MELEE_ROWS if id in MELEE_IDS else []

static func sanitized(values: Dictionary,id: int)->Dictionary:
	var result={}
	for row in COMMON_ROWS+special_rows(id):
		var value=values.get(row[0])
		if (value is int or value is float) and is_finite(float(value)):
			result[row[0]]=clampf(float(value),row[2],row[3])
	return result

static func load_profiles(values: Dictionary)->Dictionary:
	var result={}
	for id in range(1,13):
		var key=key_for(id)
		if values.get(key) is Dictionary:result[key]=sanitized(values[key],id)
	return result

static func value(baseline: Dictionary,profiles: Dictionary,id: int,key: String)->float:
	var overrides: Dictionary=profiles.get(key_for(id),{})
	if overrides.has(key):return float(overrides[key])
	if key=="melee_reach":return 1.0
	if key=="critical_chance":return clampf(float(baseline.get(key,5.0)),0,100)
	var result=float(baseline.get(key,PrototypeTuning.DEFAULTS.get(key,1.0)))
	if Roster.is_rogue(id):
		var native=Roster.data(id)
		if key=="max_hp":result*=float(native.maxHealth)/100.0
		elif key in ["walk_speed","sprint_speed"]:result*=float(native.speed)/5.15
		elif key in ["jump_speed","second_jump_speed"] and native.id=="dragoon":result*=sqrt(3.0)
		elif key in ["jump_speed","second_jump_speed"] and native.id=="ranger":result*=sqrt(2.0)
	return result
