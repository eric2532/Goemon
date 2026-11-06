extends RefCounted
## Per-skill multipliers, snapshotted on attack tickets so released attacks keep their tuning.
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const ROWS=[["size","Visual size ×",.1,5,.1],["hit_area","Hit area ×",.1,5,.1],["travel_speed","Travel speed ×",.1,5,.1],["damage","Damage ×",0,10,.1]]
static var definitions:Dictionary={}

static func all()->Dictionary:
 if definitions.is_empty():
  definitions=Catalog.all().duplicate()
  for row in [["demon-hunter/bolt",32,"Metamorphosis Bolt"],["demon-hunter/metamorphosis",32,"Metamorphosis"],["skullpion/tail",27,"Tail Sweep"],["skullpion/drill",27,"Poison Drill"],["skullpion/stomp",27,"Jump Stomp"],["skullpion/sand",27,"Sand Beam"]]:
   definitions[row[0]]={"id":row[0],"source":row[1],"name":row[2]}
 return definitions

const ACTIONS={
 "warcraft_bolt":"mountain-king/storm-bolt","warcraft_clap":"mountain-king/thunder-clap",
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
  for row in ROWS:
   var value=values[id].get(row[0])
   if supports(id,row[0]) and (value is float or value is int) and is_finite(float(value)):
    var bounded=clampf(float(value),row[2],row[3])
    if bounded!=1.0:profile[row[0]]=bounded
  if not profile.is_empty():result[id]=profile
 return result

static func value(game:Node,id:String,key:String)->float:
 return float(game.settings.get("skill_balance",{}).get(id,{}).get(key,1.0)) if is_instance_valid(game) else 1.0

static func factor(ticket:Dictionary,key:String)->float:
 return float(ticket.get("skill_"+key,1.0))

static func identify(hero:Hero,action:String)->String:
 if hero.spell_loadout!=null and not hero.spell_loadout.casting_id.is_empty():return hero.spell_loadout.casting_id
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

static func decorate(hero:Hero,ticket:Dictionary,action:String):
 var id=identify(hero,action)
 if id.is_empty():return
 ticket.skill_id=id
 for row in ROWS:ticket["skill_"+row[0]]=value(hero.game,id,row[0])

static func supports(id:String,key:String)->bool:
 if id in ["musashi/crosswise","musashi/tenderize","musashi/desperado","musashi/leaping-strike"]:return key=="damage"
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
