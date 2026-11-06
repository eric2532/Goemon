extends RefCounted
## Persisted editor values; models keep a private run snapshot.
const EnemyBalance=preload("res://scripts/forest/enemy_balance.gd")
const CARD_RARITIES=[["card_silver_chance","Silver",10.0],["card_gold_chance","Gold",4.0],["card_diamond_chance","Diamond",1.0],["card_legendary_chance","Legendary",.25]]
const ROWS=[
	["spawn_group_start","Starting group size",1,10000,1],
	["spawn_group_growth","Growth per group",0,10000,1],
	["starting_gold","Starting gold",0,100000000,100],
	["enemy_wall_health","Enemy wall / tower health",1,1000000,500],
	["enemy_castle_health","Enemy Skullpion statue health",1,1000000,500],
	["tower_health","Tower health",1,1000000,50],
	["tower_damage","Guard Tower damage",0,100000,1],
	["tower_attack_speed","Guard volleys / sec",.05,20,.05],
	# Retain the saved key so existing tower strength settings still apply.
	["tower_workers","Shots per tower volley",1,24,1],
	["enemy_size_mult","Enemy size ×",.25,3,.05],
	["enemy_health_mult","Enemy health ×",.25,50,.25],
	["enemy_damage_mult","Enemy damage ×",.1,10,.1],
	["enemy_speed_mult","Enemy movement ×",.25,5,.05],
	["boss_health","Skullpion health",1,1000000,1000],
	["boss_speed","Skullpion speed (before ×)",.25,6,.25]]
const TYPES=[0,1,3,6,9,14,16,4,17,18]
const ENEMIES=["Thirstquencher Sword","Thirstquencher Gun","Thirstquencher Spear","Vambee","Haya Wolf","Vambee Torso","Slow Guy","Skullpion","Dark Lumina 2","Dark Lumina 3"]
const MAX_WAVES=50
const MAX_ENEMIES=10000
const POPULATION_VERSION=1
static func split_legacy_wave(values:Array,bosses:int)->Array:
	var counts=[0,0,0,0,0,0,0,bosses,0,0]
	for slot in [0,1,3]:
		var family=preload("res://scripts/forest/forest_enemy_roles.gd").WAVE_FAMILIES[slot]
		for i in int(values[slot]):counts[TYPES.find(family[i%family.size()])]+=1
	return counts
static func default_wave(index: int)->Array:
	var total=[360,540,715,895,1195][mini(index,4)]
	var values=[0,0,0,0]
	for i in total:values[[0,1,3][i%3]]+=1
	return split_legacy_wave(values,1)
static func defaults()->Dictionary:
	var waves=[]
	for i in range(5):waves.append(default_wave(i))
	var values={"population_version":POPULATION_VERSION,"spawn_group_start":10,"spawn_group_growth":1,"starting_gold":1000000,"enemy_wall_health":6000.0,"enemy_castle_health":6000.0,"tower_health":500.0,"tower_damage":18.0,"tower_attack_speed":1.0/1.4,"tower_workers":3,"enemy_health_mult":3.0,"enemy_damage_mult":2.0,"enemy_speed_mult":1.2,"enemy_size_mult":1.0,"bosses_per_portal":1,"boss_health":30000.0,"boss_speed":1.5,"waves":waves,"enemy_profiles":{}}
	for row in CARD_RARITIES:values[row[0]]=row[2]
	return values
static func rarity_cutoffs(values:Dictionary)->Array[int]:
	var cutoffs:Array[int]=[0,0,0,0]
	var cutoff=10000
	for i in range(CARD_RARITIES.size()-1,-1,-1):
		cutoff-=roundi(values[CARD_RARITIES[i][0]]*100)
		cutoffs[i]=cutoff
	return cutoffs
static func sanitized(raw)->Dictionary:
	var out=defaults()
	if not raw is Dictionary:return out
	var remaining=10000
	for row in CARD_RARITIES:
		var value=raw.get(row[0],row[2])
		if not (value is int or value is float) or not is_finite(float(value)):value=row[2]
		var chance=mini(remaining,roundi(clampf(float(value),0,100)*100))
		out[row[0]]=chance/100.0;remaining-=chance
	out.enemy_profiles=EnemyBalance.sanitized(raw.get("enemy_profiles",{}),TYPES)
	for row in ROWS:
		var value=raw.get(row[0],out[row[0]])
		if (value is int or value is float) and is_finite(float(value)):
			out[row[0]]=clampf(float(value),row[2],row[3])
			if row[0] in ["spawn_group_start","spawn_group_growth","starting_gold","tower_workers","bosses_per_portal"]:out[row[0]]=int(out[row[0]])
	var boss_value=raw.get("bosses_per_portal",1)
	var bosses=0 if (boss_value is int or boss_value is float) and boss_value==0 else 1
	out.bosses_per_portal=bosses
	var waves=raw.get("waves",null)
	if waves is Array and not waves.is_empty():
		out.waves=[]
		for i in range(mini(waves.size(),MAX_WAVES)):
			var counts=default_wave(i);counts[TYPES.find(4)]=bosses
			if waves[i] is Array and waves[i].size() in [4,8,9,TYPES.size()]:
				var values=[]
				for value in waves[i]:
					values.append(clampi(int(value),0,MAX_ENEMIES) if (value is int or value is float) and is_finite(float(value)) else 0)
				if values.size()==4:
					# Split the old mixed families; the retired Daruma slot never spawned.
					counts=split_legacy_wave(values,bosses)
				else:
					counts=values
					while counts.size()<TYPES.size():counts.append(0)
			out.waves.append(counts)
	elif bosses==0:
		for wave in out.waves:wave[TYPES.find(4)]=0
	return out

static func from_saved(raw)->Dictionary:
	if not raw is Dictionary:return defaults()
	var migrated=raw.duplicate(true)
	if raw.get("population_version",0)!=POPULATION_VERSION:
		# Legacy ordinary counts represented five-body groups; expand only once.
		var waves=migrated.get("waves",[])
		if waves is Array:
			for wave in waves:
				if not wave is Array or wave.size()!=4:continue
				for type in [0,1,3]:
					var value=wave[type]
					if (value is int or value is float) and is_finite(float(value)):wave[type]=clampi(int(value),0,2000)*5
	return sanitized(migrated)
