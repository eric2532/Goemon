extends RefCounted
## Per-skill multipliers, snapshotted on attack tickets so released attacks keep their tuning.
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Levels=preload("res://scripts/spells/skill_levels.gd")
const BASE_DIAMETER=10.8
const BASIC_ATTACK_DAMAGE=50.0
const ROWS=[["size","Visual size ×",.1,5,.1],["hit_area","Hit area ×",.1,5,.1],["travel_speed","Travel speed ×",.1,5,.1],["damage","Damage ×",0,10,.1]]
const COUNTS={
 "blademaster/mirror-image":[5,"Copies"],
 "kazi/qigong":[8,"Blasts per cast"],"maze/qigong":[8,"Blasts per cast"],
 "kazi/moon":[6,"Waves per cast"],"kazi/wind":[8,"Target limit"],
 "kazi/fire":[8,"Target limit"],"kazi/ice":[8,"Target limit"],"kazi/meteor":[8,"Target limit"]
}
const NATIVE_ACTIONS={"kazi_combo":"combo","shin_two_birds":"two-birds","shin_counter":"counter","shin_counter_arm":"counter","shin_meditation":"meditation","maze_assassination":"assassination","maze/blade-dance":"blade-dance","lancelot_random_shot":"random-shot"}
static var definitions:Dictionary={}

static func all()->Dictionary:
 if definitions.is_empty():
  definitions=Catalog.all().duplicate()
  for row in [["demon-hunter/bolt",32,"Metamorphosis Bolt"],["demon-hunter/metamorphosis",32,"Metamorphosis"],["skullpion/tail",27,"Tail Sweep"],["skullpion/drill",27,"Poison Drill"],["skullpion/stomp",27,"Jump Stomp"],["skullpion/sand",27,"Sand Beam"]]:
   definitions[row[0]]={"id":row[0],"source":row[1],"name":row[2]}
  definitions["mountain-king/avatar"]={"id":"mountain-king/avatar","source":33,"name":"Avatar","native":true,"controls":["size"]}
  definitions["mountain-king/taunt"]={"id":"mountain-king/taunt","source":33,"name":"Taunt / War Cry","native":true,"controls":[]}
  for source in Catalog.Roster.CROSSGATE:
   var fighter:Dictionary=Catalog.Roster.CROSSGATE[source]
   var combat=["size","hit_area","damage"]
   if fighter.id=="bog":add_native(source,"cave-bears","召喚穴熊",[])
   if fighter.strike=="bow":
    add_native(source,"random-shot","亂射",["size","hit_area","travel_speed","damage"],12)
    add_native(source,"sure-strike","乾坤",combat)
    add_native(source,"barrage-shadows","亂射影分身",["damage"],5)
   if fighter.get("combo",false) or fighter.get("weapon_skills",false):
    add_native(source,"combo","連擊",combat,7 if fighter.get("weapon_skills",false) else 8)
   if fighter.get("weapon_skills",false):
    add_native(source,"sure-strike","乾坤",combat)
    add_native(source,"meditation","明鏡止水",["size"])
    add_native(source,"double-edge","諸刃",combat)
    add_native(source,"two-birds","一石二鳥",combat)
    add_native(source,"counter","反擊",combat,1)
   if fighter.get("throwing",false):
    add_native(source,"blade-dance","刀刃亂舞",["size","hit_area","travel_speed","damage"],6)
    add_native(source,"assassination","暗殺",combat)
   if fighter.get("kagerou",false):add_native(source,"kagerou","陽炎",[])
 return definitions

static func add_native(source:int,suffix:String,name_:String,controls:Array,count_:int=0):
 var id:String=Catalog.Roster.CROSSGATE[source].id+"/"+suffix
 definitions[id]={"id":id,"source":source,"name":name_,"native":true,"controls":controls}
 if count_>0:definitions[id].count=[count_,{"combo":"Combo hits","counter":"Counter hits","barrage-shadows":"Shadows","random-shot":"Arrows per volley"}.get(suffix,"Daggers / target limit")]

static func count_spec(id:String)->Array:
 return COUNTS.get(id,all().get(id,{}).get("count",[]))

static func rows(id:String)->Array:
 var count_=count_spec(id)
 return ROWS if count_.is_empty() else ROWS+[["count",count_[1],1,32,1]]

static func baseline(id:String,key:String)->float:
 return float(count_spec(id)[0]) if key=="count" and not count_spec(id).is_empty() else 1.0

static func count(ticket:Dictionary,original:int)->int:
 return maxi(1,int(ticket.get("skill_count",original)))

const ACTIONS={
 "lancelot_random_shot":Catalog.RANDOM_SHOT,
 "shin_sure_strike":Catalog.SURE_STRIKE,
 "warcraft_bolt":"mountain-king/storm-bolt","warcraft_clap":"mountain-king/thunder-clap",
 "warcraft_avatar":"mountain-king/avatar","warcraft_taunt":"mountain-king/taunt",
 "dash":"goemon/dash","sky_strike":"goemon/sky-strike","surge":"goemon/surge",
 "fireball":"edo/volley","giant_fireball":"edo/giant-fireball","meteors":"edo/meteors","teleport":"edo/fire-dodge","shield":"edo/blue-surge",
 "musashi_rotation":"musashi/rotation","musashi_counter":"musashi/counter","musashi_charge":"musashi/charge","musashi_dkick":"musashi/d-kick","musashi_fence":"musashi/fence","musashi_homing":"musashi/homing","musashi_grenade":"musashi/grenade","musashi_three_way":"musashi/three-way",
 "ed_smoke_assault":"ed/smoke-assault","ed_quick_burst":"ed/quick-burst",
 "sasuke_bomb":"sasuke/bomb","sasuke_ice":"sasuke/ice","sasuke_ice_charge":"sasuke/ice","sasuke_hail":"sasuke/hail","sasuke_hair_up":"sasuke/hair-up","sasuke_hair_forward":"sasuke/hair-forward","sasuke_super_jump":"sasuke/super-jump",
 "yae_bazooka":"yae/bazooka","yae_bazooka_charge":"yae/bazooka","yae_lock_on":"yae/lock-on","yae_shield":"yae/shield","yae_shield_enter":"yae/shield","yae_shield_exit":"yae/shield",
 "sonic_spin_dash":"sonic/spin-dash","sonic_homing":"sonic/homing","warcraft_spin":"blademaster/spin","warcraft_immolation":"demon-hunter/immolation",
 "kojiro_homing":"kojiro/homing","kojiro_wave":"kojiro/wave","kojiro_wind":"kojiro/wind","knight/lion":"knight/lion"}

static func sanitized(values:Variant)->Dictionary:
 var result={}
 if not values is Dictionary:return result
 for id in values:
  if not all().has(id) or not values[id] is Dictionary:continue
  var profile={}
  for row in rows(id):
   var value=values[id].get(row[0])
   if supports(id,row[0]) and (value is float or value is int) and is_finite(float(value)):
    var bounded=clampf(float(value),row[2],row[3])
    if row[0]=="count":bounded=roundf(bounded)
    if bounded!=baseline(id,row[0]):profile[row[0]]=bounded
  if not profile.is_empty():result[id]=profile
 return result

static func value(game:Node,id:String,key:String)->float:
 if not is_instance_valid(game):return baseline(id,key)
 var profiles:Dictionary=game.settings.get("skill_balance",{})
 var profile:Dictionary=profiles.get(id,{})
 if Levels.family(id)=="qigong":profile=profiles.get("kazi/qigong",profiles.get("maze/qigong",{}))
 return float(profile.get(key,baseline(id,key)))

static func effective(hero:Hero,id:String,key:String,extra_card:String="",extra_ranks:int=0,level_override:int=0)->float:
 var base=value(hero.game,id,key)
 var rules=Levels.stats(id,level_override) if level_override>0 else rules_for(hero,id)
 if key=="count" and rules.has("count"):base+=float(rules.count)-baseline(id,"count")
 if key=="count" and Levels.family(id)=="moon":base+=float(hero.accessory_bonuses.get("moon_extra",0.0))
 if key in ["size","hit_area"]:base*=float(rules.get(key,1.0))
 if hero.team_progression==null:return base
 var bonus=modifier(hero,id,key)
 if not hero.ai_controlled and hero.game.player==hero:bonus+=hero.team_progression.skill_bonus(id,key,extra_card,extra_ranks)
 var result=base+bonus if key=="count" else base*maxf(0.0,1.0+bonus)
 if key=="count":result=clampf(roundf(result),1,128)
 if key in ["size","hit_area"] and supports(id,key) and not hero.ai_controlled:result*=hero.team_progression.skill_food_multiplier()
 return result

static func level_for(hero:Hero,id:String)->int:
 if hero.team_progression!=null and hero.get("pet_key") is String:return pet_level_for(hero.team_progression,hero.pet_key,id)
 return int(hero.team_progression.skill_levels.get(Levels.family(id),1)) if hero.team_progression!=null else 1

static func pet_level_for(progression:RefCounted,pet_key:String,id:String)->int:
 return int(progression.pet_skill_levels.get(pet_key,{}).get(Levels.family(id),1))

static func rules_for(hero:Hero,id:String)->Dictionary:
 if not Catalog.Roster.is_crossgate_fighter(hero.character_id):return {}
 if id!="blademaster/mirror-image" and not Catalog.Roster.is_crossgate_fighter(int(all().get(id,{}).get("source",0))):return {}
 return Levels.stats(id,level_for(hero,id))

static func modifier(hero:Hero,id:String,key:String)->float:
 if hero.team_progression==null:return 0.0
 var total=0.0
 for entry in hero.team_progression.skill_modifiers.get(Levels.family(id),{}).values():total+=float(entry.get(key,0.0))
 return total

static func set_level(hero:Hero,id:String,value_:float)->bool:
 if hero.team_progression==null or not all().has(id) or not is_finite(value_):return false
 if hero.get("pet_key") is String:
  if not hero.team_progression.pet_skill_levels.has(hero.pet_key):hero.team_progression.pet_skill_levels[hero.pet_key]={}
  hero.team_progression.pet_skill_levels[hero.pet_key][Levels.family(id)]=clampi(roundi(value_),1,Levels.MAX_LEVEL)
 else:hero.team_progression.skill_levels[Levels.family(id)]=clampi(roundi(value_),1,Levels.MAX_LEVEL)
 hero.game.prepare_skill_count(id)
 return true

static func set_modifier(hero:Hero,id:String,source:String,values:Dictionary)->bool:
 if hero.team_progression==null or not all().has(id) or source.is_empty():return false
 var clean={}
 var rules=rules_for(hero,id)
 for key in values:
  if key=="qi_color":
   if Levels.family(id)!="qigong":return false
   if not values[key] is Color or not values[key].is_equal_approx(values[key].clamp()):return false
   clean[key]=values[key];continue
  if key not in ["count","damage","size","hit_area","travel_speed","critical_bonus","chance","healing"]:return false
  if key in ["critical_bonus","chance","healing"] and not rules.has(key):return false
  if key in ["count","damage","size","hit_area","travel_speed"] and not supports(id,key) and not rules.has(key):return false
  if not (values[key] is float or values[key] is int) or not is_finite(float(values[key])):return false
  clean[key]=clampf(float(values[key]),-128,128) if key=="count" else clampf(float(values[key]),-1,100)
 var family=Levels.family(id)
 if not hero.team_progression.skill_modifiers.has(family):hero.team_progression.skill_modifiers[family]={}
 if clean.is_empty():hero.team_progression.skill_modifiers[family].erase(source)
 else:hero.team_progression.skill_modifiers[family][source]=clean
 hero.game.prepare_skill_count(id)
 return true

static func qi_color(hero:Hero)->Color:
 var cosmetics=preload("res://scripts/forest/equipment.gd")
 if hero.game.settings.get("cosmetic_loadouts",{}).has(cosmetics.wearer(hero)):return cosmetics.qi_color(hero)
 if hero.team_progression!=null:
  for entry in hero.team_progression.skill_modifiers.get("qigong",{}).values():
   if entry.has("qi_color"):return entry.qi_color
 return Color.WHITE

static func basic_damage(_pattern:Dictionary,hero:Hero=null)->float:
 if hero==null or (is_instance_valid(hero.model) and hero.model.get("gear_weapon")=="beast-master"):return BASIC_ATTACK_DAMAGE
 return BASIC_ATTACK_DAMAGE+float(hero.accessory_bonuses.get("attack",0.0))

static func normal_damage(hero:Hero)->float:
 if Catalog.Roster.is_crossgate_fighter(hero.character_id) and hero.model.get("gear_weapon") is String:
  return (100.0 if hero.model.gear_weapon=="staff" or hero.model.fighter.strike=="staff" else 250.0)+float(hero.accessory_bonuses.get("attack",0.0))
 return 100.0 if Catalog.Roster.crossgate_profile(hero.character_id).get("strike","")=="staff" else 250.0

static func level_skills()->Array[String]:
 var result:Array[String]=[];var seen={}
 for id in all():
  if id!="blademaster/mirror-image" and not Catalog.Roster.is_crossgate_fighter(int(all()[id].source)):continue
  if id=="maze/qigong" or Levels.stats(id,1).is_empty() or seen.has(Levels.family(id)):continue
  seen[Levels.family(id)]=true;result.append(id)
 return result

static func active_slots(hero:Hero)->Array[String]:
 var result:Array[String]=["","","","","",""]
 if not Catalog.Roster.is_crossgate_fighter(hero.character_id):return result
 var loadout=hero.spell_loadout;var equipped=loadout.assignments(hero.character_id)
 var slots=loadout.slots_for(hero.character_id)
 var source:String=Catalog.Roster.crossgate_profile(hero.character_id).id
 var native_names={Catalog.KAZ_COMBO_NAME:"combo",Catalog.SHIN_SURE_STRIKE_NAME:"sure-strike",Catalog.SHIN_DOUBLE_EDGE_NAME:"double-edge",Catalog.SHIN_TWO_BIRDS_NAME:"two-birds",Catalog.SHIN_COUNTER_NAME:"counter",Catalog.SHIN_MEDITATION_NAME:"meditation",Catalog.KAGEROU_NAME:"kagerou",Catalog.RANDOM_SHOT_NAME:"random-shot",Catalog.BARRAGE_SHADOWS_NAME:"barrage-shadows","召喚穴熊":"cave-bears"}
 for i in mini(6,slots.size()):
  if slots[i].is_empty():continue
  var action:String=Catalog.SLOTS.keys()[i]
  if equipped.has(action):result[i]=equipped[action]
  elif i==0 and Catalog.Roster.has_crossgate_throws(hero.character_id) and not hero.model.gear_external:result[i]=source+("/blade-dance" if hero.model.daggers else "/assassination")
  elif native_names.has(slots[i][0]):result[i]=source+"/"+native_names[slots[i][0]]
 return result

static func effect_tier_name(id:String,tier:int)->String:
 var highest="Large + shine"
 if Levels.family(id) in Levels.ELEMENTS:highest="Highest original tier"
 elif Levels.family(id)=="meditation":highest="Large + gold sparkles"
 return ["Small","Medium","Large",highest,"EX"][clampi(tier,0,Levels.EX_TIER)]

static func level_preview(id:String,level_:int)->String:
 var rules=Levels.stats(id,level_);var parts:PackedStringArray=[]
 if rules.has("count"):parts.append("%d %s"%[rules.count,{"combo":"hits","counter":"hits","random-shot":"arrows","qigong":"blasts","moon":"waves","mirror-image":"copies","barrage-shadows":"shadows"}.get(Levels.family(id),"targets")])
 if rules.has("damage"):parts.append("%.2f× damage"%rules.damage)
 if rules.has("secondary_damage"):parts.append("%.2f× follow-up"%rules.secondary_damage)
 if rules.has("base_damage"):parts.append("%d spell damage / target"%rules.base_damage)
 if rules.has("chance"):parts.append("%.2f%% chance"%(100*rules.chance))
 if rules.has("healing"):parts.append("%d%% missing HP"%roundi(100*rules.healing))
 if rules.has("defense_penalty"):parts.append("−%d%% defense, 10s"%roundi(100*rules.defense_penalty))
 if rules.has("defense_bonus"):parts.append("−%d%% intercepted damage"%roundi(100*rules.defense_bonus))
 if rules.has("critical_bonus"):parts.append("+%d%% crit"%rules.critical_bonus)
 if rules.has("size") and Levels.family(id)!="double-edge":parts.append("%.2f× %s"%[rules.size,"explosion" if Levels.family(id)=="two-birds" else "impact size"])
 if Levels.family(id) in Levels.SHINE_FAMILIES:parts.append("EX casting shine" if level_>=Levels.MAX_LEVEL else "Original shine tier %d"%(Levels.shine_tier(level_)+1))
 if rules.has("effect_tier"):parts.append(effect_tier_name(id,rules.effect_tier))
 return " · ".join(parts)

static func damage(hero:Hero,ticket:Dictionary,original:float)->float:
 var rules:Dictionary=ticket.get("skill_rules",{})
 return normal_damage(hero)*float(rules.damage) if rules.has("damage") else original

static func summary(hero:Hero,id:String)->String:
 var rules=rules_for(hero,id)
 if rules.is_empty():return ""
 var text="Level %d / 30"%level_for(hero,id)
 if rules.has("count"):text+=" · Count %d"%int(effective(hero,id,"count"))
 if rules.has("damage"):text+=" · %.2f× base damage"%float(rules.damage)
 if rules.has("secondary_damage"):text+=" · Follow-up %.2f×"%float(rules.secondary_damage)
 if rules.has("base_damage"):text+=" · %d spell damage per target per cast"%int(rules.base_damage)
 if rules.has("chance"):text+=" · %.2f%% chance"%(100*clampf(float(rules.chance)+modifier(hero,id,"chance"),0,1))
 if rules.has("healing"):text+=" · Heal %d%% missing HP"%roundi(100*float(rules.healing))
 if rules.has("defense_bonus"):text+=" · −%d%% intercepted damage"%roundi(100*rules.defense_bonus)
 if rules.has("critical_bonus"):text+=" · +%d critical-chance points"%int(rules.critical_bonus)
 return text

static func factor(ticket:Dictionary,key:String)->float:
 return float(ticket.get("skill_"+key,1.0))

static func shine_factor(ticket:Dictionary)->float:
 var rules:Dictionary=ticket.get("skill_rules",{})
 var size_=factor(ticket,"size")
 if rules.is_empty() or Levels.family(ticket.get("skill_id","")) not in Levels.SHINE_FAMILIES:return size_
 # Original sheets supply level growth; keep saved item, food and tuning bonuses.
 return size_/float(rules.get("size",1.0))

static func identify(hero:Hero,action:String)->String:
 if hero.spell_loadout!=null and not hero.spell_loadout.casting_id.is_empty():return hero.spell_loadout.casting_id
 var fighter=Catalog.Roster.crossgate_profile(hero.character_id)
 if not fighter.is_empty():
  var suffix=NATIVE_ACTIONS.get(action,"")
  if action=="shin_sure_strike":suffix="double-edge" if hero.model.motions.get("weapon","")=="polearm" else "sure-strike"
  if suffix=="counter":return Catalog.COUNTER
  var native_id:String=fighter.id+"/"+suffix
  if not suffix.is_empty() and all().has(native_id):return native_id
  if suffix=="combo":return Catalog.COMBO
  if suffix=="meditation":return Catalog.MEDITATION
 if all().has(action):return action
 var kit=hero.active_ability
 if hero.character_id==13 and kit!=null and not kit.combo_skill.is_empty():return "musashi/"+kit.combo_skill
 if hero.character_id==32 and action=="warcraft_attack" and kit.demon:return "demon-hunter/bolt"
 if action=="warcraft_morph":return "demon-hunter/metamorphosis"
 if hero.character_id==27 and kit!=null and action in ["enemy_primary","skullpion_drill","skullpion_sand"]:return {102:"skullpion/tail",103:"skullpion/sand",104:"skullpion/stomp",105:"skullpion/drill"}.get(kit.action,"")
 if action=="beam":return "ed/beam" if hero.character_id==14 else "edo/beam"
 if action in ["leader_primary","leader_secondary"] and kit!=null:
  return {"beam":"ed/beam","fireballs":"ed/fireballs","fan":"ben/stars","axes":"ben/axes","bombs":"ben/bombs"}.get(kit.mode,"")
 if action.begins_with("dark_lumina_3_"):
  return "dark-lumina-3/"+["sword","wind","water","fire","earth","sky"][clampi(int(action.trim_prefix("dark_lumina_3_")),0,5)]
 if action=="dark_lumina" and kit!=null:
  return {0:"dark-lumina-2/grab",1:"dark-lumina-2/fireballs",2:"dark-lumina-2/shockwave",5:"dark-lumina-2/spin"}.get(kit.action,"")
 if action=="rogue_knight_shield_counter":return "knight/flintlock"
 if action.begins_with("rogue_"):
  var suffix=action.trim_prefix("rogue_"+Catalog.Roster.class_id(hero.character_id)+"_")
  var id=Catalog.Roster.class_id(hero.character_id)+"/"+{"secondary":"flintlock","sweep":"flintlock","utility":"roll","skill":"drink","rapid_shot":"rapid-shot"}.get(suffix,suffix)
  if id=="mage/primary":id="mage/fireball"
  if id=="magic-swordsman/dive":return id
  return id if all().has(id) else ""
 return ACTIONS.get(action,"")

static func decorate(hero:Hero,ticket:Dictionary,action:String,level_override:int=0):
 var id=identify(hero,action)
 if id.is_empty():return
 ticket.skill_id=id
 for row in rows(id):ticket["skill_"+row[0]]=effective(hero,id,row[0],"",0,level_override)
 var rules=Levels.stats(id,level_override) if level_override>0 else rules_for(hero,id)
 if Catalog.Roster.is_crossgate_fighter(hero.character_id):ticket.skill_level=level_override if level_override>0 else level_for(hero,id)
 if Levels.family(id)=="ice":ticket.accessory_ice_hits=int(hero.accessory_bonuses.get("ice_hits",3))
 if Levels.family(id)=="moon":ticket.accessory_moon_extra=int(hero.accessory_bonuses.get("moon_extra",0))
 if Levels.family(id)=="wind":ticket.accessory_wind_extra=int(hero.accessory_bonuses.get("wind_extra",0))
 if Levels.family(id)=="sure-strike" and hero.accessory_bonuses.get("sure_explosion",0)>0:ticket.accessory_sure_explosion=true
 if rules.is_empty():return
 ticket.skill_rules=rules
 if rules.has("healing"):ticket.skill_healing=clampf(float(rules.healing)+modifier(hero,id,"healing"),0,1)
 ticket.critical_chance=clampf(float(ticket.get("critical_chance",0))+float(rules.get("critical_bonus",0))+modifier(hero,id,"critical_bonus"),0,100)
 if Levels.family(id)=="qigong":
  ticket.qi_color=qi_color(hero)
  ticket.qi_chrome=preload("res://scripts/forest/equipment.gd").qi_chrome(hero)
 if rules.has("chance"):ticket.skill_chance=clampf(float(rules.chance)+modifier(hero,id,"chance"),0,1)

static func supports(id:String,key:String)->bool:
 if id==Catalog.BEE_FLURRY:return key in ["size","hit_area","damage"]
 if id==Catalog.GUARD_BREAK:return key in ["size","damage"]
 if id==Catalog.BODYGUARD:return false
 if key=="count":return not count_spec(id).is_empty()
 if all().get(id,{}).get("native",false):return key in all()[id].controls
 if id==Catalog.RECOVERY:return key=="size"
 if id in ["musashi/crosswise","musashi/tenderize","musashi/desperado","musashi/leaping-strike"]:return key in ["size","hit_area","damage"]
 if id.ends_with("/drink") or id in ["musashi/guard","ben/flight","blademaster/mirror-image","blademaster/wind-walk","goemon/surge","demon-hunter/metamorphosis","master-thief/roll"]:return false
 if id=="sasuke/super-jump":return key=="travel_speed"
 if id.ends_with("/roll"):
  if id in ["samurai/roll","ninja/roll"]:return true
  if id=="magic-swordsman/roll":return key in ["hit_area","damage","travel_speed"]
  return key=="travel_speed" and id!="mage/roll"
 if id=="mage/flintlock":return key in ["size","hit_area"]
 if id=="master-thief/flintlock":return key=="size"
 if key=="travel_speed":
  return id not in ["mountain-king/thunder-clap","blademaster/spin","demon-hunter/immolation","musashi/rotation","musashi/counter","musashi/charge","yae/shield","edo/beam","edo/blue-surge","edo/fire-dodge","ed/beam","sasuke/hair-up","sasuke/hair-forward","dark-lumina-3/earth","dark-lumina-2/spin","dark-lumina-2/grab","dark-lumina-2/shockwave","skullpion/tail","skullpion/drill","skullpion/stomp","skullpion/sand","knight/flintlock","mage/flintlock","master-thief/flintlock"]
 if key=="size":return id not in ["goemon/dash","yae/shield","sasuke/hair-up","sasuke/hair-forward","dark-lumina-2/grab","dark-lumina-2/spin","skullpion/tail","skullpion/drill","skullpion/stomp","skullpion/sand","edo/blue-surge"]
 return true
