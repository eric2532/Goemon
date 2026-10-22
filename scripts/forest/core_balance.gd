extends RefCounted
## Persisted editor values; models keep a private run snapshot.
const ROWS=[
	["starting_gold","Starting gold",0,100000000,100],
	["tower_health","Watchtower health",1,1000000,50],
	["tower_damage","Damage per arrow",0,100000,1],
	["tower_attack_speed","Shots / second / worker",.05,20,.05],
	["tower_workers","Max workers per tower",1,24,1],
	["enemy_health_mult","Enemy health ×",.25,50,.25],
	["enemy_damage_mult","Enemy damage ×",.1,10,.1],
	["enemy_speed_mult","Enemy movement ×",.25,5,.05],
	["bosses_per_portal","Boss per portal (0 / 1)",0,1,1],
	["boss_health","Portal boss health (before ×)",1,1000000,1000],
	["boss_speed","Portal boss speed (before ×)",.25,6,.25]]
const ENEMIES=["Thirstquencher Sword","Thirstquencher Gun","Daruma Breaker","Thirstquencher Spear"]
const MAX_WAVES=50
const MAX_ENEMIES=10000
const POPULATION_VERSION=1
static func default_wave(index: int)->Array:
	var total=[72,108,144,180,240][mini(index,4)]
	var counts=[0,0,1 if index>=2 else 0,0]
	for i in range(counts[2],total):counts[[0,1,3][i%3]]+=1
	for type in [0,1,3]:counts[type]*=5
	return counts
static func defaults()->Dictionary:
	var waves=[]
	for i in range(5):waves.append(default_wave(i))
	return {"population_version":POPULATION_VERSION,"starting_gold":1000000,"tower_health":500.0,"tower_damage":18.0,"tower_attack_speed":1.0/1.4,"tower_workers":3,"enemy_health_mult":3.0,"enemy_damage_mult":2.0,"enemy_speed_mult":1.2,"bosses_per_portal":1,"boss_health":24000.0,"boss_speed":1.5,"waves":waves}
static func sanitized(raw)->Dictionary:
	var out=defaults()
	if not raw is Dictionary:return out
	for row in ROWS:
		var value=raw.get(row[0],out[row[0]])
		if (value is int or value is float) and is_finite(float(value)):
			out[row[0]]=clampf(float(value),row[2],row[3])
			if row[0] in ["starting_gold","tower_workers","bosses_per_portal"]:out[row[0]]=int(out[row[0]])
	var waves=raw.get("waves",null)
	if waves is Array and not waves.is_empty():
		out.waves=[]
		for i in range(mini(waves.size(),MAX_WAVES)):
			var counts=default_wave(i)
			if waves[i] is Array and waves[i].size()==4:
				for type in range(4):
					var value=waves[i][type]
					if (value is int or value is float) and is_finite(float(value)):counts[type]=clampi(int(value),0,MAX_ENEMIES)
			out.waves.append(counts)
	return out

static func from_saved(raw)->Dictionary:
	var out=sanitized(raw)
	if not raw is Dictionary or raw.get("population_version",0)==POPULATION_VERSION:return out
	# Legacy editor counts represented five-body ordinary groups. Migrate
	# only valid saved rows; new editor/model counts always mean individuals.
	var waves=raw.get("waves",[])
	if waves is Array:
		for index in mini(waves.size(),out.waves.size()):
			if not waves[index] is Array or waves[index].size()!=4:continue
			for type in [0,1,3]:
				var value=waves[index][type]
				if (value is int or value is float) and is_finite(float(value)):
					out.waves[index][type]=clampi(int(value),0,2000)*5
	return out
