class_name PrototypeTuning
extends RefCounted

const DEFAULTS={
	"beam_duration":5.0,"beam_width":2.8,"beam_length":38.0,
	"max_hp":100.0,"damage_mult":1.0,"pipe_range":3.5,"charge_time":1.1,
	"jump_speed":15.55,"second_jump_speed":14.45,
	"walk_speed":10.2,"sprint_speed":18.0,"invincible":false,
	"coin_count":1,"split_count":5,"coin_damage":20.0,"coin_speed":32.0,
	"charged_damage":70.0,"charged_radius":2.2,"surge_duration":30.0,
	"surge_range":1.65,"surge_coin_size":1.8,"surge_coin_speed":1.65,
	"respawn_delay":6.0,"respawn_batch":3,"respawn_safe_distance":7.0,
	"max_active_enemies":200,"spawn_count":5,"enemy_hp":66.0,"enemy_damage":1.0,"boss_hp_mult":1.0,"freeze_ai":false
}
const PLAYER_ROWS=[
	["max_hp","Maximum HP",10,2000,10],
	["damage_mult","All player damage ×",0.1,10,0.1],
	["pipe_range","Pipe reach (m)",1.5,12,0.25],
	["charge_time","Full charge (seconds)",0.4,3,0.1],
	["walk_speed","Run speed",3,20,0.1],
	["sprint_speed","Sprint speed",8,35,0.5],
	["jump_speed","Jump launch speed",8,24,0.25],
	["second_jump_speed","Double-jump launch speed",8,24,0.25]
]
const COIN_ROWS=[
	["coin_count","Manual quick-toss coins",1,12,1],
	["split_count","Split-attack coin count",3,15,1],
	["coin_damage","Coin damage",1,250,1],
	["coin_speed","Coin speed",10,90,1],
	["charged_damage","Surge spin / giant coin damage",1,500,1],
	["charged_radius","Giant coin hit radius (m)",0.75,5,0.25],
	["surge_duration","Golden surge seconds",1,120,1],
	["surge_range","Surge pipe reach ×",1.1,3,0.05],
	["surge_coin_size","Surge coin size ×",1.1,3,0.1],
	["surge_coin_speed","Surge coin speed ×",1.1,3,0.1]
]
const BEAM_ROWS=[
	["beam_width","Width / diameter (m)",.5,6,.1],
	["beam_length","Length (m)",5,65,1]
]
const ENEMY_ROWS=[
	["max_active_enemies","Active enemy limit (next run)",32,400,1],
	["spawn_count","Spawn batch size",1,20,1],
	["respawn_delay","Enemy respawn delay (s)",2,30,.5],
	["respawn_batch","Respawn batch limit",1,8,1],
	["respawn_safe_distance","Respawn distance from hero",5,20,.5],
	["enemy_hp","Ninja / dummy HP",10,2000,1],
	["enemy_damage","Enemy damage ×",0,5,0.1],
	["boss_hp_mult","Boss maximum HP ×",0.1,5,0.1]
]

static func sanitized(values: Dictionary)->Dictionary:
	var result=DEFAULTS.duplicate()
	for rows in [PLAYER_ROWS,COIN_ROWS,BEAM_ROWS,ENEMY_ROWS]:
		for row in rows:
			var v=values.get(row[0],result[row[0]])
			if v is float or v is int: result[row[0]]=clampf(float(v),float(row[2]),float(row[3]))
	for key in ["invincible","freeze_ai"]:
		if values.get(key,false) is bool: result[key]=values.get(key,false)
	return result
