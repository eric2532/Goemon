extends "res://scripts/level_progression.gd"
## Run-only team XP and card choices. Saved balance and character stats stay separate.
const CARDS={
	"tower_defense":{"category":"Tower","title":"Reinforced stone","description":"All towers withstand %d%% more damage.","step":.20},
	"tower_speed":{"category":"Tower","title":"Rapid volleys","description":"All towers shoot %d%% faster.","step":.15},
	"tower_damage":{"category":"Tower","title":"Heavy arrows","description":"All towers deal %d%% more damage.","step":.20},
	"worker_repair":{"category":"Worker","title":"Expert repairs","description":"All workers repair %d%% faster. Same ryo cost per HP.","step":.25},
	"worker_speed":{"category":"Worker","title":"Swift response","description":"All workers move %d%% faster and seek the nearest safe repair job.","step":.15},
	"worker_revive":{"category":"Worker","title":"Back on our feet","description":"Wounded workers revive at the castle after %d seconds, even during battle.","step":1.0},
	"character_damage":{"category":"Character","title":"United strength","description":"You and all friendly fighters deal %d%% more attack and spell damage.","step":.15},
	"character_speed":{"category":"Character","title":"Battle rhythm","description":"You and all friendly fighters attack %d%% faster.","step":.10},
	"legendary_tower":{"category":"Tower","title":"Heavenly artillery","description":"All your towers deal 5× total damage for the rest of this run. Includes current and future towers.","step":0.0},
	"legendary_workers":{"category":"Worker","title":"Royal workforce","description":"Gain 10 workers at your castle immediately. Free, even when food is full.","step":0.0},
	"legendary_mercenaries":{"category":"Character","title":"Mercenary company","description":"Gain 5 random mercenaries at your castle immediately. Free, even when food is full.","step":0.0},
	"legendary_hero":{"category":"Character","title":"A legend joins","description":"Summon 1 random hero: Illidan, Blademaster, Goemon, Musashi or Kojiro. They fight for you until defeated or this run ends.","step":0.0},
}
const RARITIES=["Normal","Silver","Gold","Diamond","Legendary"]
const LEGENDARIES={"Tower":["legendary_tower"],"Worker":["legendary_workers"],"Character":["legendary_mercenaries","legendary_hero"]}
var ranks:Dictionary={}
var offer:Array[String]=[]
var offer_rarities:Array[int]=[]
var choices=0
var xp_remainder=0
var rng=RandomNumberGenerator.new()

func reset(_direct_levels:bool=false):
	super.reset(false)
	ranks.clear();offer.clear();offer_rarities.clear();choices=0;xp_remainder=0

func kills_required()->int:return 0 if level>=MAX_LEVEL else 20+10*(level-1)
func pending()->int:return level-1-choices
func choice_level()->int:return choices+2
func multiplier(id:String)->float:
	var value=1.0+float(CARDS[id].step)*int(ranks.get(id,0))
	return value*pow(5.0,int(ranks.get("legendary_tower",0))) if id=="tower_damage" else value
func revival_seconds()->float:return 12.0/maxi(1,int(ranks.get("worker_revive",0)))
func description(id:String,rarity:int)->String:
	if id.begins_with("legendary_"):return CARDS[id].description
	return CARDS[id].description%(12/(rarity+1) if id=="worker_revive" else roundi(float(CARDS[id].step)*100*(rarity+1)))
static func rarity_from_roll(roll:int)->int:
	if roll<8475:return 0
	if roll<9475:return 1
	if roll<9875:return 2
	if roll<9975:return 3
	return 4
func award_kills(amount:int=1)->int:
	var gained=super.award_kills(amount)
	if level>=MAX_LEVEL:xp_remainder=0
	if pending()>0 and offer.is_empty():roll_offer()
	return gained

func award_enemy(reward_tenths:int=10)->int:
	if reward_tenths<=0 or level>=MAX_LEVEL:return 0
	# Keep fractional rewards exact while reusing the whole-XP level accumulator.
	var total=xp_remainder+reward_tenths
	xp_remainder=total%10
	return award_kills(total/10)

func experience()->float:return kills_into_level+xp_remainder/10.0
func progress()->float:return 1.0 if level>=MAX_LEVEL else experience()/kills_required()

func roll_offer():
	offer.clear();offer_rarities.clear()
	for category in ["Tower","Worker","Character"]:
		var rarity=rarity_from_roll(rng.randi_range(0,9999));offer_rarities.append(rarity)
		if rarity==4:
			var legends:Array=LEGENDARIES[category]
			offer.append(legends[rng.randi_range(0,legends.size()-1)]);continue
		var available:Array[String]=[]
		for id in CARDS:
			if not id.begins_with("legendary_") and CARDS[id].category==category and (id!="worker_revive" or not ranks.has(id)):available.append(id)
		offer.append(available[rng.randi_range(0,available.size()-1)])

func can_choose(id:String,offered_level:int)->bool:
	return pending()>0 and offered_level==choice_level() and offer.has(id)
func choose(id:String,offered_level:int)->bool:
	if not can_choose(id,offered_level):return false
	ranks[id]=int(ranks.get(id,0))+(1 if id.begins_with("legendary_") else offer_rarities[offer.find(id)]+1)
	choices+=1;offer.clear();offer_rarities.clear()
	if pending()>0:roll_offer()
	return true
