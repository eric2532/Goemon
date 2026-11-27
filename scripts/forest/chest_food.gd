extends RefCounted
## Original Cross Gate artwork; nutrition lasts for the current run.
const Pets=preload("res://scripts/forest/pet_catalog.gd")
# Keep historical meal IDs for saved-data compatibility; presentation uses the current food art.
const ITEMS={
	"vitality-bread":{"name":"Vitality bread","stat":"vitality","effect":"+100 max HP · +1 HP/sec"},
	"power-steak":{"name":"Power steak","stat":"attack","effect":"+15% physical damage"},
	"sage-jelly":{"name":"Sage soup","stat":"magic_power","effect":"+15% magic damage"},
	"swift-sushi":{"name":"Swift sushi","stat":"attack_speed","effect":"+10% attack speed"},
	"iron-meatballs":{"name":"Iron meatballs","stat":"defense","effect":"+10 defense"},
	"ward-jelly":{"name":"Ward soup","stat":"magic_defense","effect":"+10 magic defense"},
	"lucky-cake":{"name":"Lucky cake","stat":"critical_chance","effect":"+1% critical chance"},
	"feather-parfait":{"name":"Feather parfait","stat":"dodge_chance","effect":"+1% dodge"},
	"duelist-fish":{"name":"Duelist fish","stat":"counter_chance","effect":"+1% counter chance"},
	"focus-riceball":{"name":"Focus riceball","stat":"accuracy","effect":"+1 Accuracy"},
	"growth-rice":{"name":"Growth rice","levels":1,"effect":"+1 character level"},
	"royal-feast":{"name":"Royal feast","levels":3,"effect":"+3 character levels"},
	"pet-stew":{"name":"Pet hearty stew","pet_stat":"vitality","effect":"Party pets: +30 max HP each"},
	"pet-skewers":{"name":"Pet power skewers","pet_stat":"damage","effect":"Party pets: +5 attack each"},
	"pet-melon":{"name":"Pet mana broth","pet_stat":"mana","effect":"Party pets: +10 max MP each"},
	"pet-feast":{"name":"Pet celebration feast","pet_levels":1,"effect":"Party pets: +1 level each"},
}
const ICONS={
	"vitality-bread":preload("res://assets/items/crossgate/vitality-bread.png"),
	"power-steak":preload("res://assets/items/crossgate/power-steak.png"),
	"sage-jelly":preload("res://assets/items/crossgate/sage-soup.png"),
	"swift-sushi":preload("res://assets/items/crossgate/swift-sushi.png"),
	"iron-meatballs":preload("res://assets/items/crossgate/iron-meatballs.png"),
	"ward-jelly":preload("res://assets/items/crossgate/ward-soup.png"),
	"lucky-cake":preload("res://assets/items/crossgate/lucky-cake.png"),
	"feather-parfait":preload("res://assets/items/crossgate/feather-parfait.png"),
	"duelist-fish":preload("res://assets/items/crossgate/duelist-fish.png"),
	"focus-riceball":preload("res://assets/items/crossgate/focus-riceball.png"),
	"growth-rice":preload("res://assets/items/crossgate/growth-rice.png"),
	"royal-feast":preload("res://assets/items/crossgate/royal-feast.png"),
	"pet-stew":preload("res://assets/items/crossgate/pet-stew.png"),
	"pet-skewers":preload("res://assets/items/crossgate/pet-skewers.png"),
	"pet-melon":preload("res://assets/items/crossgate/pet-mana-broth.png"),
	"pet-feast":preload("res://assets/items/crossgate/pet-feast.png"),
}

static func count(value,maximum:int=10000)->int:
	if not (value is int or value is float) or not is_finite(float(value)):return 0
	return int(clampf(float(value),0,maximum))

static func sanitized(value)->Dictionary:
	var result={"stats":{},"levels":0,"pets":{}}
	if not value is Dictionary:return result
	result.levels=count(value.get("levels",0),98)
	var stats=value.get("stats",{})
	if stats is Dictionary:
		for item in ITEMS.values():
			if item.has("stat"):
				var id:String=item.stat
				result.stats[id]=count(stats.get(id,0),100 if id.ends_with("chance") else 10000)
	var pets=value.get("pets",{})
	if pets is Dictionary:
		for key in pets:
			if not key is String or Pets.skin(key)<0 or not pets[key] is Dictionary:continue
			var ranks={}
			for id in ["vitality","damage","mana","levels"]:ranks[id]=count(pets[key].get(id,0),98 if id in ["mana","levels"] else 10000)
			result.pets[key]=ranks
	return result

static func eligible(game,id:String)->bool:
	if not ITEMS.has(id):return false
	var item:Dictionary=ITEMS[id];var state=game.model.team_progression
	if item.has("stat"):
		return state.food_ranks.get(item.stat,0)<(100 if item.stat.ends_with("chance") else 10000) and (not item.stat.ends_with("chance") or (game.player.effective_dodge_chance() if item.stat=="dodge_chance" else game.player.combat_tuning(item.stat))<100)
	if item.has("levels"):return state.level<99
	for key in Pets.sanitized(game.settings.forest_pet_loadout):
		if item.has("pet_levels"):
			if not state.pet_experience.has(key) or state.pet_experience[key].level<99:return true
		elif state.pet_food_ranks.get(key,{}).get(item.pet_stat,0)<(98 if item.pet_stat=="mana" else 10000) and (item.pet_stat!="mana" or state.pet_mana_bonus(key)<980):return true
	return false

static func reward(game,id:String)->bool:
	if not eligible(game,id):return false
	var state=game.model.team_progression
	var saved=sanitized({"stats":state.food_ranks,"levels":state.food_levels,"pets":state.pet_food_ranks});var item:Dictionary=ITEMS[id]
	if item.has("stat"):saved.stats[item.stat]=saved.stats.get(item.stat,0)+1
	elif item.has("levels"):saved.levels=mini(98,saved.levels+mini(item.levels,99-game.model.team_progression.level))
	else:
		for key in Pets.sanitized(game.settings.forest_pet_loadout):
			var ranks:Dictionary=saved.pets.get_or_add(key,{})
			if item.has("pet_levels"):
				var xp=game.model.team_progression.pet_experience.get(key)
				if xp==null or xp.level<99:ranks.levels=mini(98,ranks.get("levels",0)+1)
			else:ranks[item.pet_stat]=mini(98 if item.pet_stat=="mana" else 10000,ranks.get(item.pet_stat,0)+1)
	game.model.team_progression.apply_food_progress(saved)
	game.player.refresh_max_health(true)
	game.army_runtime.finish_integration()
	for key in Pets.sanitized(game.settings.forest_pet_loadout):
		var handle:int=game.army_runtime.handles.get(game.army_runtime.HOUND_ID-Pets.skin(key),0)
		if handle!=0 and game.army_runtime.valid(handle):game.army_runtime.apply_pet_growth(handle,key,item.has("pet_levels"))
	return true
