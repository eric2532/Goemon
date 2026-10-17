extends RefCounted
## Persisted editor values; models keep a private run snapshot.
const ROWS=[
	["starting_gold","Starting gold",0,100000000,100],
	["tower_health","Watchtower health",1,1000000,50],
	["tower_damage","Damage per arrow",0,100000,1],
	["tower_attack_speed","Shots / second / worker",.05,20,.05],
	["tower_workers","Max workers per tower",1,24,1]]
const ENEMIES=["Masked Raider","Reed Archer","Daruma Breaker","Lantern Runner"]
const MAX_WAVES=50
const MAX_ENEMIES=2000
static func default_wave(index: int)->Array:
	var total=[72,108,144,180,240][mini(index,4)]
	var counts=[0,0,1 if index>=2 else 0,0]
	for i in range(counts[2],total):counts[[0,1,3][i%3]]+=1
	return counts
static func defaults()->Dictionary:
	var waves=[]
	for i in range(5):waves.append(default_wave(i))
	return {"starting_gold":1000000,"tower_health":500.0,"tower_damage":18.0,"tower_attack_speed":1.0/1.4,"tower_workers":3,"waves":waves}
static func sanitized(raw)->Dictionary:
	var out=defaults()
	if not raw is Dictionary:return out
	for row in ROWS:
		var value=raw.get(row[0],out[row[0]])
		if (value is int or value is float) and is_finite(float(value)):
			out[row[0]]=clampf(float(value),row[2],row[3])
			if row[0] in ["starting_gold","tower_workers"]:out[row[0]]=int(out[row[0]])
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
