extends "res://scripts/forest/experience_progression.gd"
## Main-character XP and upgrade choices for the current run.
const Experience=preload("res://scripts/forest/experience_progression.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const QI_SKILLS=["kazi/qigong","maze/qigong"]
const CARDS={
	"pet_damage":{"category":"Pet","title":"Stronger strikes","description":"All your hounds and mantises gain %d%% of base damage.","step":.30},
	"pet_speed":{"category":"Pet","title":"Fleet paws","description":"All your hounds and mantises move %d%% faster.","step":.20},
	"pet_health":{"category":"Pet","title":"Stalwart companions","description":"All your hounds and mantises gain %d%% of base maximum health.","step":.30},
	"character_damage":{"category":"Character","title":"United strength","description":"You and all friendly fighters deal %d%% more attack and spell damage.","step":.30},
	"character_speed":{"category":"Character","title":"Battle rhythm","description":"You and all friendly fighters attack %d%% faster.","step":.20},
	"player_range":{"category":"Character","title":"Far-reaching strikes","description":"Your controlled character gains %d%% more melee attack reach.","step":.25},
	"qi_orbs":{"category":"Character","title":"氣功蛋 · More orbs","description":"Your Qi Orbs fire %d extra orbs per cast. Damage per orb stays the same.","step":2.0,"skills":QI_SKILLS,"stat":"count","max_rank":8},
	"qi_area":{"category":"Character","title":"氣功蛋 · Wider hits","description":"Your Qi Orbs gain %d%% hit radius. Visual size and damage stay the same.","step":.20,"skills":QI_SKILLS,"stat":"hit_area","max_rank":8},
	"legendary_goemon":{"category":"Character","title":"Goemon joins","description":"Summon Goemon to fight for you until defeated or this run ends.","step":0.0,"hero":1},
	"legendary_musashi":{"category":"Character","title":"Musashi joins","description":"Summon Musashi to fight for you until defeated or this run ends.","step":0.0,"hero":13},
	"legendary_kojiro":{"category":"Character","title":"Kojiro joins","description":"Summon Kojiro to fight for you until defeated or this run ends.","step":0.0,"hero":28},
	"legendary_blademaster":{"category":"Character","title":"Blademaster joins","description":"Summon Blademaster to fight for you until defeated or this run ends.","step":0.0,"hero":31},
	"legendary_illidan":{"category":"Character","title":"Illidan joins","description":"Summon Illidan to fight for you until defeated or this run ends.","step":0.0,"hero":32},
	"legendary_mountain_king":{"category":"Character","title":"Mountain King joins","description":"Summon Mountain King to fight for you until defeated or this run ends.","step":0.0,"hero":33},
}
const RARITIES=["Silver","Gold","Diamond"]
const CARD_LEVELS=[1,3,5]
const RARITY_MARBLES=[7,9,4]
var ranks:Dictionary={}
var skills:Array[String]=[]
var offer:Array[String]=[]
var offer_rarities:Array[int]=[]
var choices=0
const STAT_NAMES={"vitality":"Vitality","attack":"Attack","magic_power":"Magic power","attack_speed":"Attack Speed","defense":"Defense","magic_defense":"Magic defense","critical_chance":"Critical Chance","dodge_chance":"Dodge","counter_chance":"Counter attack","accuracy":"Accuracy"}
var food_ranks:Dictionary={}
var pet_food_ranks:Dictionary={}
var food_levels=0
var pet_food_levels:Dictionary={}
var stat_points=0
const SKILL_FOOD_STEP=.05
var skill_food_stacks=0
var skill_levels:Dictionary={}
var pet_skill_levels:Dictionary={}
var pet_experience:Dictionary={}
# Retain existing run bonuses; new pet growth needs no allocated points.
var pet_stat_ranks:Dictionary={}
var skill_modifiers:Dictionary={}
var stat_ranks={"vitality":0,"attack":0,"magic_power":0,"attack_speed":0,"defense":0,"magic_defense":0,"critical_chance":0,"dodge_chance":0,"counter_chance":0,"accuracy":0}
var cards_enabled=true:
	set(enabled):
		cards_enabled=enabled
		if not enabled:skip_offers()
var rng=RandomNumberGenerator.new()
var rarity_bag:Array[int]=[]

func reset(_direct_levels:bool=false):
	super.reset(false)
	ranks.clear();skills.clear();offer.clear();offer_rarities.clear();rarity_bag.clear();choices=0
	stat_points=0
	food_ranks.clear();pet_food_ranks.clear();food_levels=0;pet_food_levels.clear()
	skill_food_stacks=0
	skill_levels.clear();pet_skill_levels.clear();pet_experience.clear();pet_stat_ranks.clear();skill_modifiers.clear()
	for id in stat_ranks:stat_ranks[id]=0

func apply_food_progress(saved:Dictionary):
	food_ranks=saved.get("stats",{}).duplicate()
	pet_food_ranks=saved.get("pets",{}).duplicate(true)
	var next_levels:int=saved.get("levels",0)
	grant_food_levels(self,maxi(0,next_levels-food_levels));food_levels=next_levels
	for key in pet_food_ranks:
		var next_pet_levels:int=pet_food_ranks[key].get("levels",0)
		if next_pet_levels>pet_food_levels.get(key,0):
			if not pet_experience.has(key):pet_experience[key]=Experience.new()
			grant_food_levels(pet_experience[key],next_pet_levels-pet_food_levels.get(key,0))
		pet_food_levels[key]=next_pet_levels

static func grant_food_levels(xp,amount:int):
	# Award a whole level's XP, retaining progress and the normal level-up rewards.
	for i in mini(amount,Experience.MAX_LEVEL-xp.level):xp.award_kills(xp.kills_required())

func spend_stat(id:String)->bool:
	if stat_points<=0 or not stat_ranks.has(id):return false
	if id in ["critical_chance","dodge_chance","counter_chance"] and stat_chance_bonus(id)>=100:return false
	stat_points-=1;stat_ranks[id]+=1
	return true
func stat_health_bonus()->float:return 20.0*(level-1)+100.0*stat_rank("vitality")
func stat_regeneration()->float:return 1.0*stat_rank("vitality")
func stat_damage_multiplier()->float:return 1.0+.03*(level-1)+.15*stat_rank("attack")
func stat_magic_multiplier()->float:return 1.0+.03*(level-1)+.15*stat_rank("magic_power")
func stat_attack_multiplier()->float:return 1.0+.10*stat_rank("attack_speed")
func stat_defense()->float:return 2.0*(level-1)+10.0*stat_rank("defense")
func stat_magic_defense()->float:return 2.0*(level-1)+10.0*stat_rank("magic_defense")
func stat_critical_chance_bonus()->float:return stat_chance_bonus("critical_chance")
func stat_rank(id:String)->int:return stat_ranks.get(id,0)+food_ranks.get(id,0)
func stat_chance_bonus(id:String)->float:return float(stat_rank(id))
func skill_food_multiplier()->float:return 1.0+SKILL_FOOD_STEP*skill_food_stacks
func stat_incoming_multiplier(extra_defense:float=0.0,defense_factor:float=1.0,magical:bool=false)->float:
	var defense=stat_magic_defense() if magical else stat_defense()
	return 100.0/(100.0+(defense+extra_defense)*defense_factor)

func pending()->int:return level-1-choices
func choice_level()->int:return choices+2
func multiplier(id:String,extra_ranks:int=0)->float:
	return 1.0+float(CARDS[id].step)*(int(ranks.get(id,0))+extra_ranks)
func pet_growth(key:String,per_level:float)->float:
	var xp=pet_experience.get(key)
	if xp==null:return 0.0
	var levels:float=xp.level-1
	return per_level*levels/(1.0+levels/20.0)
func pet_rank(key:String,id:String)->int:return pet_stat_ranks.get(key,{}).get(id,0)+pet_food_ranks.get(key,{}).get(id,0)
func pet_points(_key:String)->int:return 0
func can_spend_pet_stat(_key:String,_id:String)->bool:return false
func spend_pet_stat(_key:String,_id:String)->bool:return false
func pet_mana_bonus(key:String)->float:return minf(980.0,pet_growth(key,3.0)+10.0*pet_rank(key,"mana"))
func pet_health_bonus(key:String)->float:return Pets.BASE_HEALTH*pet_growth(key,.16 if Pets.category(Pets.skin(key))=="Dragon lizards" else .08)+30.0*pet_rank(key,"vitality")
func pet_damage_bonus(key:String)->float:return Pets.BASE_DAMAGE*(pet_growth(key,.20 if Pets.category(Pets.skin(key)) in ["Mantises","Bees"] else .10)+.10*pet_rank(key,"damage"))
func pet_passive_level(key:String)->int:return 1+pet_rank(key,"passive")
func party_passive_bonus(selected:Array,stat:String)->float:
	var bonus=0.0
	for key in selected:
		var skin=Pets.skin(key);var passive=Pets.passive(skin)
		if passive.get("stat","")==stat:bonus+=Pets.passive_value(skin,pet_passive_level(key))
	return bonus
func pet_damage_multiplier(key:String)->float:return multiplier("pet_damage")+pet_damage_bonus(key)/Pets.BASE_DAMAGE
func award_pet_enemy(key:String,reward_tenths:int)->int:
	if reward_tenths<=0:return 0
	if not pet_experience.has(key):pet_experience[key]=Experience.new()
	return pet_experience[key].award_enemy(reward_tenths)
func skill_bonus(skill:String,stat:String,extra_card:String="",extra_ranks:int=0)->float:
	var bonus=0.0
	for id in CARDS:
		var card:Dictionary=CARDS[id]
		if card.get("stat","")==stat and card.get("skills",[]).has(skill):
			bonus+=float(card.step)*(int(ranks.get(id,0))+(extra_ranks if id==extra_card else 0))
	return bonus
func award_kills(amount:int=1)->int:
	var gained=super.award_kills(amount)
	stat_points+=gained
	if not cards_enabled:skip_offers()
	return gained

func skip_offers():
	choices=level-1
	offer.clear();offer_rarities.clear()

func draw_rarity()->int:
	if rarity_bag.is_empty():
		for rarity in RARITY_MARBLES.size():
			for marble in RARITY_MARBLES[rarity]:rarity_bag.append(rarity)
		for i in range(rarity_bag.size()-1,0,-1):
			var j=rng.randi_range(0,i)
			var marble=rarity_bag[i];rarity_bag[i]=rarity_bag[j];rarity_bag[j]=marble
	return rarity_bag.pop_back()

func roll_offer(targets:Array[String]):
	offer.clear();offer_rarities.clear()
	var available=targets.duplicate()
	for slot in mini(3,available.size()):
		var group=available if slot==2 else available.filter(func(id):return id.contains("|")==(slot==1))
		if group.is_empty():group=available
		var id:String=group[rng.randi_range(0,group.size()-1)]
		offer.append(id);offer_rarities.append(draw_rarity());available.erase(id)

func can_choose(id:String,offered_level:int)->bool:
	return cards_enabled and pending()>0 and offered_level==choice_level() and offer.has(id)
func choose(id:String,offered_level:int)->bool:
	if not can_choose(id,offered_level):return false
	choices+=1;offer.clear();offer_rarities.clear()
	return true
