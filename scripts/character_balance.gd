extends RefCounted
## Sparse per-character overrides; the old prototype section remains the baseline.
const Roster=preload("res://scripts/rogue_roster.gd")
static var _native_scales:Dictionary={}
static var _profile_keys:Dictionary={}
const MELEE_IDS=[1,3,4,5,7,8,9,11,12,13,15,16,17,28,31,32,33]
const MELEE_ROWS=[["melee_reach","Melee reach ×",.5,10,.05]]
const COMBO_ROWS=[
	["combo_charge_size","連擊 · Charge glow ×",.1,5,.1],
	["combo_effect_height","連擊 · Burst size / base fighter height",.1,10,.1],
	["combo_splash_radius","連擊 · Splash radius (m)",0,30,.5]
]
const COMMON_ROWS=[
	["model_scale","Model size ×",.1,10,.1],
	["max_hp","Base maximum HP",10,5000,10],
	["damage_mult","Damage ×",.1,10,.1],
	["critical_chance","Critical chance (%)",0,100,1],
	["dodge_chance","Dodge chance (%)",0,100,1],
	["counter_chance","Counter chance (%)",0,100,1],
	["accuracy","Accuracy",0,100,1],
	["walk_speed","Run speed",3,40,.1],
	["sprint_speed","Sprint speed",3,60,.1],
	["jump_height","Jump height ×",.25,5,.05],
	["jump_drop_speed","Jump drop speed ×",.25,2,.05],
	["jump_speed","Jump launch speed",8,40,.25],
	["second_jump_speed","Double-jump launch speed",8,40,.25]
]

static func key_for(id: int)->String:
	if id==1:return "goemon"
	if id==2:return "edo"
	if not _profile_keys.has(id):_profile_keys[id]=Roster.class_id(id)
	return _profile_keys[id]

static func name_for(id: int)->String:
	return "Goemon" if id==1 else ("Edo" if id==2 else Roster.name_for(id))

static func special_rows(id: int)->Array:
	if id==1:return MELEE_ROWS+[["pipe_range","Pipe reach (m)",1.5,12,.25]]+PrototypeTuning.COIN_ROWS
	if id==2:return PrototypeTuning.BEAM_ROWS
	if Roster.crossgate_profile(id).get("magic","")=="ruby":return MELEE_ROWS+[["recovery","Recovery · 回復",0,5000,1]]
	if id in [31,32,33]:return [["attack_speed","Attack speed ×",.1,10,.1]]+MELEE_ROWS
	var fighter=Roster.crossgate_profile(id)
	if fighter.get("combo",false) or fighter.get("weapon_skills",false):return MELEE_ROWS+COMBO_ROWS
	return MELEE_ROWS if id in MELEE_IDS or Roster.is_crossgate_fighter(id) or Roster.is_enemy(id) else []

static func sanitized(values: Dictionary,id: int)->Dictionary:
	var result={}
	for row in COMMON_ROWS+special_rows(id):
		var value=values.get(row[0])
		if (value is int or value is float) and is_finite(float(value)):
			result[row[0]]=clampf(float(value),row[2],row[3])
	return result

static func load_profiles(values: Dictionary)->Dictionary:
	var result={}
	for id in Roster.PLAYABLE_IDS:
		var key=key_for(id)
		if values.get(key) is Dictionary:result[key]=sanitized(values[key],id)
	return result

static func value(baseline: Dictionary,profiles: Dictionary,id: int,key: String)->float:
	var overrides: Dictionary=profiles.get(key_for(id),{})
	if overrides.has(key):return float(overrides[key])
	if key=="combo_charge_size":return 1.0
	if key=="combo_effect_height":return preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER/preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
	if key=="combo_splash_radius":return preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*.5
	if id==Roster.MAZE_ID and key=="model_scale":return value(baseline,profiles,Roster.KAZI_ID,key)
	if key=="model_scale":return 6.0 if id in [31,32,33] else 1.0
	if key=="attack_speed":return 3.0 if id in [31,32,33] else 1.0
	if key=="max_hp" and Roster.is_crossgate_fighter(id):return 200.0
	if id==29 and key=="max_hp":return preload("res://scripts/forest/dark_lumina_kit.gd").HEALTH
	if key=="recovery" and Roster.is_crossgate_fighter(id):return 100.0
	if key in ["melee_reach","jump_height","jump_drop_speed"]:return 1.0
	if key=="critical_chance":return clampf(float(baseline.get(key,5.0)),0,100)
	if key in ["dodge_chance","counter_chance"]:return 5.0
	if key=="accuracy":return 0.0
	var result=float(baseline.get(key,PrototypeTuning.DEFAULTS.get(key,1.0)))
	if Roster.is_rogue(id) and key in ["max_hp","walk_speed","sprint_speed","jump_speed","second_jump_speed"]:
		# Authored class ratios are immutable. Live baseline values and editable
		# per-character overrides above are deliberately never cached.
		if not _native_scales.has(id):
			var native=Roster.data(id)
			var jump=sqrt(3.0) if native.id=="dragoon" else (sqrt(2.0) if native.id=="ranger" else 1.0)
			_native_scales[id]={"max_hp":float(native.maxHealth)/100.0,"walk_speed":float(native.speed)/5.15,"sprint_speed":float(native.speed)/5.15,"jump_speed":jump,"second_jump_speed":jump}
		result*=float(_native_scales[id][key])
	return result
