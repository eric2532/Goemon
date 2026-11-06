extends "res://scripts/level_progression.gd"
## Run-only team XP and card choices. Saved balance and character stats stay separate.
const CARDS={
	"tower_defense":{"category":"Tower","title":"Reinforced stone","description":"All towers withstand %d%% more damage.","step":.30},
	"tower_speed":{"category":"Tower","title":"Rapid volleys","description":"All towers shoot %d%% faster.","step":.25},
	"tower_damage":{"category":"Tower","title":"Heavy ammunition","description":"All towers deal %d%% more damage.","step":.30},
	"worker_repair":{"category":"Worker","title":"Expert repairs","description":"All workers repair %d%% faster. Same ryo cost per HP.","step":.50},
	"worker_speed":{"category":"Worker","title":"Swift response","description":"All workers move %d%% faster and seek the nearest safe repair job.","step":.25},
	"worker_revive":{"category":"Worker","title":"Back on our feet","description":"Wounded workers revive at the castle after %d seconds, even during battle.","step":1.0},
	"character_damage":{"category":"Character","title":"United strength","description":"You and all friendly fighters deal %d%% more attack and spell damage.","step":.30},
	"character_speed":{"category":"Character","title":"Battle rhythm","description":"You and all friendly fighters attack %d%% faster.","step":.20},
	"player_range":{"category":"Character","title":"Far-reaching strikes","description":"Your controlled character gains %d%% more melee attack reach.","step":.25},
	"legendary_tower":{"category":"Tower","title":"Heavenly artillery","description":"All your towers deal 5× total damage for the rest of this run. Includes current and future towers.","step":0.0},
	"legendary_workers":{"category":"Worker","title":"Royal workforce","description":"Gain 10 workers at your castle immediately. Free, even when food is full.","step":0.0},
	"legendary_dragoons":{"category":"Character","title":"Dragoon company","description":"Gain 5 Dragoons at your castle immediately. Free, even when food is full.","step":0.0,"mercenary":0},
	"legendary_rangers":{"category":"Character","title":"Ranger company","description":"Gain 5 Rangers at your castle immediately. Free, even when food is full.","step":0.0,"mercenary":1},
	"legendary_ninjas":{"category":"Character","title":"Ninja company","description":"Gain 5 Ninjas at your castle immediately. Free, even when food is full.","step":0.0,"mercenary":2},
	"legendary_knights":{"category":"Character","title":"Knight company","description":"Gain 5 Knights at your castle immediately. Free, even when food is full.","step":0.0,"mercenary":3},
	"legendary_explorers":{"category":"Character","title":"Explorer company","description":"Gain 5 Explorers at your castle immediately. Free, even when food is full.","step":0.0,"mercenary":4},
	"legendary_goemon":{"category":"Character","title":"Goemon joins","description":"Summon Goemon to fight for you until defeated or this run ends.","step":0.0,"hero":1},
	"legendary_musashi":{"category":"Character","title":"Musashi joins","description":"Summon Musashi to fight for you until defeated or this run ends.","step":0.0,"hero":13},
	"legendary_kojiro":{"category":"Character","title":"Kojiro joins","description":"Summon Kojiro to fight for you until defeated or this run ends.","step":0.0,"hero":28},
	"legendary_blademaster":{"category":"Character","title":"Blademaster joins","description":"Summon Blademaster to fight for you until defeated or this run ends.","step":0.0,"hero":31},
	"legendary_illidan":{"category":"Character","title":"Illidan joins","description":"Summon Illidan to fight for you until defeated or this run ends.","step":0.0,"hero":32},
	"legendary_mountain_king":{"category":"Character","title":"Mountain King joins","description":"Summon Mountain King to fight for you until defeated or this run ends.","step":0.0,"hero":33},
}
const RARITIES=["Normal","Silver","Gold","Diamond","Legendary"]
var ranks:Dictionary={}
var offer:Array[String]=[]
var offer_rarities:Array[int]=[]
var choices=0
var xp_remainder=0
var rng=RandomNumberGenerator.new()
var rarity_cutoffs:Array[int]=[8475,9475,9875,9975]

func reset(_direct_levels:bool=false):
	super.reset(false)
	ranks.clear();offer.clear();offer_rarities.clear();choices=0;xp_remainder=0

func kills_required()->int:return 0 if level>=MAX_LEVEL else 20+10*(level-1)
func pending()->int:return level-1-choices
func choice_level()->int:return choices+2
func multiplier(id:String,extra_ranks:int=0)->float:
	var value=1.0+float(CARDS[id].step)*(int(ranks.get(id,0))+extra_ranks)
	return value*pow(5.0,int(ranks.get("legendary_tower",0))) if id=="tower_damage" else value
func revival_seconds()->float:return 12.0/maxi(1,int(ranks.get("worker_revive",0)))
func description(id:String,rarity:int)->String:
	if id.begins_with("legendary_"):return CARDS[id].description
	return CARDS[id].description%(12/(rarity+1) if id=="worker_revive" else roundi(float(CARDS[id].step)*100*(rarity+1)))
static func rarity_from_roll(roll:int,cutoffs:Array=[8475,9475,9875,9975])->int:
	for rarity in cutoffs.size():
		if roll<cutoffs[rarity]:return rarity
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
	for slot in 3:
		var rarity=rarity_from_roll(rng.randi_range(0,9999),rarity_cutoffs);offer_rarities.append(rarity)
		var available:Array[String]=[]
		for id in CARDS:
			if id.begins_with("legendary_")!=(rarity==4) or offer.has(id):continue
			if id!="worker_revive" or not ranks.has(id):available.append(id)
		offer.append(available[rng.randi_range(0,available.size()-1)])

func can_choose(id:String,offered_level:int)->bool:
	return pending()>0 and offered_level==choice_level() and offer.has(id)
func choose(id:String,offered_level:int)->bool:
	if not can_choose(id,offered_level):return false
	ranks[id]=int(ranks.get(id,0))+(1 if id.begins_with("legendary_") else offer_rarities[offer.find(id)]+1)
	choices+=1;offer.clear();offer_rarities.clear()
	if pending()>0:roll_offer()
	return true
