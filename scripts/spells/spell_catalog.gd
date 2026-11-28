@static_unload
extends RefCounted
## Stable spell IDs are independent of the fighter wearing them and of input keys.
const Roster=preload("res://scripts/rogue_roster.gd")
const Warcraft=preload("res://scripts/warcraft_kit.gd")
const MOON="kazi/moon"
const MOON_NAME="追月"
const RECOVERY="uru/recovery"
const SPIRIT="uru/spirit"
const SPIRIT_NAME="※高感應電流"
const SURE_STRIKE="shin/sure-strike"
const GUARD_BREAK="kazi/guard-break"
const DOUBLE_EDGE="shin/double-edge"
const SHIN_SURE_STRIKE_NAME="乾坤"
const SHIN_DOUBLE_EDGE_NAME="諸刃"
const SHIN_TWO_BIRDS_NAME="一石二鳥"
const SHIN_COUNTER_NAME="反擊"
const COUNTER="shin/counter"
const BODYGUARD="shin/bodyguard"
const MEDITATION="shin/meditation"
const SHIN_MEDITATION_NAME="明鏡止水"
const KAZ_COMBO_NAME="連擊"
const COMBO="kazi/combo"
const BEE_FLURRY="bee/blink-flurry"
const BEARS="bog/cave-bears"
const RANDOM_SHOT_NAME="亂射"
const RANDOM_SHOT="lancelot/random-shot"
const BARRAGE_SHADOWS_NAME="亂射影分身"
const BARRAGE_SHADOWS="lancelot/barrage-shadows"
const KAZ_COMBO_DESCRIPTION="Charge and blink between reachable enemies. Remaining hits finish on a defeated target. Level sets hit count, per-hit damage and size. Consecutive casts strengthen the next combo; another skill resets the streak. Each hop needs a clear path within 32m. 5s cooldown."
const KAZ_COMBO_ICON=preload("res://assets/characters/crossgate/kazi/icons/combo.png")
const BLADE_DANCE="maze/blade-dance"
const MAZE_QI="maze/qigong"
const ASSASSINATION_NAME="暗殺 · Assassination"
const ASSASSINATION_DESCRIPTION="Press 1 with Katana to attempt an assassination on the nearest reachable enemy within 96m, then return. Instant-kill chance grows from 25% to 100%; bosses remain excluded. Each kill speeds up the next attempt. Invulnerable during the sequence."
const BLADE_DANCE_NAME="刀刃亂舞"
const BLADE_DANCE_DESCRIPTION="With Dagger equipped, flash and throw one dagger at each of the six closest visible enemies. Solid cover stops the shots. 5s cooldown."
const KAGEROU="kazi/kagerou"
const KAGEROU_NAME="陽炎 · Kagerou"
const KAGEROU_DESCRIPTION="Toggle dodge protection. Dodge chance grows from 25% at level 1 to 99% at level 30."
const KAGEROU_ICON=preload("res://assets/characters/crossgate/kazi/icons/kagerou.png")
const SLOTS={"equip":"1", "surge":"2", "sky_strike":"3", "special_4":"4", "special_5":"5", "special_6":"6"}
const KAGEROU_MANA_PER_SECOND=5.0
const MANA_COSTS={
 "guard-break":5,"counter":6,"sure-strike":8,"qigong":8,"fire":10,"meditation":10,
 "ice":12,"wind":12,"double-edge":12,"random-shot":12,"blade-dance":12,"moon":14,
 "two-birds":16,"recovery":16,"combo":18,"meteor":18,"blink-flurry":20,
 "assassination":22,"spirit":26,"mirror-image":35,"barrage-shadows":35,"cave-bears":40,"kagerou":5
}

static func mana_cost(id:String)->int:
 return MANA_COSTS.get(id.get_slice("/",1),0)

static func mana_description(id:String)->String:
 var cost=mana_cost(id)
 if cost==0:return ""
 if id==KAGEROU:return "%d mana to activate · %d mana/sec while active"%[cost,KAGEROU_MANA_PER_SECOND]
 if id==COUNTER:return "%d mana per retaliation"%cost
 return "%d mana"%cost
const KAZI_ICONS={
 BEE_FLURRY:preload("res://assets/ui/crossgate/skills/bee-blink-flurry.svg"),
 BODYGUARD:preload("res://assets/characters/crossgate/hit_feedback/exclamation.png"),
 COUNTER:preload("res://assets/characters/crossgate/shin/counter-icon.png"),
 MEDITATION:preload("res://assets/characters/crossgate/shin/meditation-icon.png"),
 BARRAGE_SHADOWS:preload("res://assets/ui/portraits/crossgate/model/43-106125.png"),
 RANDOM_SHOT:preload("res://assets/ui/crossgate/weapons/defaults/bow.png"),
 "blademaster/mirror-image":preload("res://assets/ui/crossgate/skills/mirror-image.png"),
 COMBO:KAZ_COMBO_ICON,
 SURE_STRIKE:preload("res://assets/characters/crossgate/shin/sure-strike-icon.png"),
 GUARD_BREAK:preload("res://assets/characters/crossgate/hit_feedback/guard-break-icon.png"),
 DOUBLE_EDGE:preload("res://assets/characters/crossgate/shin/double-edge-icon.png"),
 BEARS:preload("res://assets/ui/crossgate/skills/summon-bears.png"),
 MOON:preload("res://assets/characters/crossgate/kazi/icons/moon.png"),
 "kazi/qigong":preload("res://assets/characters/crossgate/kazi/icons/qigong-blue.png"),
 MAZE_QI:preload("res://assets/characters/crossgate/kazi/icons/qigong-blue.png"),
 "kazi/fire":preload("res://assets/characters/crossgate/kazi/icons/fire.png"),
 "kazi/ice":preload("res://assets/characters/crossgate/kazi/icons/ice.png"),
 "kazi/wind":preload("res://assets/characters/crossgate/kazi/icons/wind.png"),
 "kazi/meteor":preload("res://assets/characters/crossgate/kazi/icons/meteor.png"),
 RECOVERY:preload("res://assets/characters/crossgate/ruby/recovery-icon.png"),
 SPIRIT:preload("res://assets/characters/crossgate/ruby/spirit-icon.png")
}
const SPECIALS=[
 [BEE_FLURRY,Roster.KAZI_ID,"Bee Flurry","start_bee_flurry"],
 [COUNTER,Roster.SHIN_ID,SHIN_COUNTER_NAME,""],
 [BODYGUARD,Roster.SHIN_ID,"護衛",""],
 [MEDITATION,Roster.SHIN_ID,SHIN_MEDITATION_NAME,"start_shin_meditation"],
 [BARRAGE_SHADOWS,Roster.LANCELOT_ID,BARRAGE_SHADOWS_NAME,"start_shadow_mirrors"],
 [KAGEROU,Roster.KAZI_ID,KAGEROU_NAME,"toggle_kagerou"],
 [COMBO,Roster.KAZI_ID,KAZ_COMBO_NAME,"start_combo"],
 [SURE_STRIKE,Roster.SHIN_ID,SHIN_SURE_STRIKE_NAME,"start_shin_area_cast"],
 [GUARD_BREAK,Roster.KAZI_ID,"崩擊 · Guard Break","start_guard_break"],
 [DOUBLE_EDGE,Roster.SHIN_ID,SHIN_DOUBLE_EDGE_NAME,"start_shin_area_cast"],
 [BEARS,Roster.BOG_ID,"召喚穴熊","summon_cave_bears"],
 [RANDOM_SHOT,Roster.LANCELOT_ID,RANDOM_SHOT_NAME,"start_random_shot"],
 [MOON,34,MOON_NAME,"start_cast"],
 [MAZE_QI,Roster.MAZE_ID,"氣功蛋 · Qi Orbs","start_cast"],
 ["kazi/qigong",34,"氣功蛋 · Qi Orbs","start_cast"],
 ["kazi/fire",34,"Fire","start_cast"],
 ["kazi/ice",34,"Ice","start_cast"],
 ["kazi/wind",34,"Wind","start_cast"],
 ["kazi/meteor",34,"隕石 · Meteor","start_cast"],
 [RECOVERY,Roster.RUBY_ID,"恢復魔法","start_recovery"],
 [SPIRIT,Roster.RUBY_ID,SPIRIT_NAME,"start_cast"],
 ["mountain-king/storm-bolt",33,"Storm Bolt","start_bolt"],
 ["mountain-king/thunder-clap",33,"Thunder Clap","start_clap"],
 ["blademaster/spin",31,"Bladestorm","start_spin"],
 ["blademaster/wind-walk",31,"Wind Walk","start_wind"],
 ["blademaster/mirror-image",31,"分身 · Mirror Image","start_mirrors"],
 ["demon-hunter/immolation",32,"Immolation · Toggle","toggle_immolation"],
 ["dark-lumina-3/sword",30,"Dark Lumina 3 · Sword","start_move",[0]],
 ["dark-lumina-3/wind",30,"Dark Lumina 3 · Wind","start_move",[1]],
 ["dark-lumina-3/water",30,"Dark Lumina 3 · Water","start_move",[2]],
 ["dark-lumina-3/fire",30,"Dark Lumina 3 · Fire","start_move",[3]],
 ["dark-lumina-3/earth",30,"Dark Lumina 3 · Earth","start_move",[4]],
 ["dark-lumina-3/sky",30,"Dark Lumina 3 · Sky","start_move",[5]],

 ["knight/lion",7,"Royal Lion Rush","start_charge"],
 ["dark-lumina-2/fireballs",29,"Dark Lumina · Paired Fireballs","start_dark_attack",[1]],
 ["dark-lumina-2/shockwave",29,"Dark Lumina · Jump Stomp & Energy Waves","start_dark_attack",[2]],
 ["dark-lumina-2/grab",29,"Dark Lumina · Claw Grab","start_dark_attack",[0]],
 ["dark-lumina-2/spin",29,"Dark Lumina · Spin Attack","start_dark_attack",[5]],
 ["kojiro/homing",28,"Kojiro’s Homing Shots","start_skill",["homing"]],
 ["kojiro/wave",28,"Kojiro’s Sword Wave","start_skill",["wave"]],
 ["kojiro/wind",28,"Kojiro’s Wind","start_skill",["wind"]],
 ["goemon/dash",1,"Forward Dash","dash"],
 ["goemon/surge",1,"Golden Surge","surge"],
 ["goemon/sky-strike",1,"Sky Strike","sky"],
 ["edo/volley",2,"Triple Fireball","cast_fireball",[false]],
 ["edo/giant-fireball",2,"Giant Fireball","cast_fireball",[true]],
 ["edo/blue-surge",2,"Blue Surge","activate_shield"],
 ["edo/beam",2,"Piercing Fire Beam","beam"],
 ["edo/meteors",2,"Meteor Rain","request_meteors"],
 ["edo/fire-dodge",2,"Fire Dodge","teleport"],
 ["musashi/rotation",13,"Lumina Rotation","start_rotation"],
 ["musashi/counter",13,"Mighty Strike","start_counter"],
 ["musashi/crosswise",13,"X Slash · Full Combo","start_combo",["crosswise"]],
 ["musashi/tenderize",13,"Tenderize · Full Combo","start_combo",["tenderize"]],
 ["musashi/desperado",13,"Desperado · Full Combo","start_combo",["desperado"]],
 ["musashi/leaping-strike",13,"Leaping Strike · Air Attack","start_leaping_strike"],
 ["musashi/guard",13,"Lumina Guard","input",["surge"]],
 ["musashi/charge",13,"Charged Lumina Rotation","input",["equip"]],
 ["musashi/d-kick",13,"D-Kick","select_number",[3]],
 ["musashi/fence",13,"Fence","select_number",[4]],
 ["musashi/homing",13,"Homing","select_number",[5]],
 ["musashi/grenade",13,"Grenade","select_number",[6]],
 ["musashi/three-way",13,"3-Way · Hold and Release","select_number",[7]],
 ["ed/beam",14,"Ed's Beam","input",["light_attack"]],
 ["ed/fireballs",14,"Bouncing Fireballs","start_attack",[true]],
 ["ed/smoke-assault",14,"Smoke Assault","start_utility"],
 ["ed/quick-burst",14,"Quick Burst","start_quick_burst"],
 ["ben/flight",15,"Propeller Flight","flight"],
 ["ben/bombs",15,"Propeller Bomb Barrage","input",["heavy_attack"]],
 ["ben/stars",15,"Star Fan / Hold Axes","input",["equip"]],
 ["ben/axes",15,"Throwing Axes","start_utility",[true]],
 ["sasuke/bomb",16,"Firecracker Bomb","start_bomb"],
 ["sasuke/ice",16,"Ice Kunai / Hold Hail Beam","input",["equip"]],
 ["sasuke/hail",16,"Hail Beam","start_ice",[true]],
 ["sasuke/hair-up",16,"Hair Attack Up","start_hair",[false]],
 ["sasuke/hair-forward",16,"Hair Attack Forward","start_hair",[true]],
 ["sasuke/super-jump",16,"Super Jump","start_super_jump"],
 ["yae/shield",17,"Sword Shield","input",["equip"]],
 ["yae/bazooka",17,"Bazooka / Hold Lock-on","input",["heavy_attack"]],
 ["yae/lock-on",17,"Lock-on Shot","start_bazooka",[true]],
 ["sonic/spin-dash",19,"Spin Dash · Hold and Release","input",["equip"]],
 ["sonic/homing",19,"Homing Attack · Airborne","start_homing"]
]
static var _spells:Dictionary={}

static func all()->Dictionary:
 if not _spells.is_empty():return _spells
 for row in SPECIALS:
  _spells[row[0]]={"id":row[0],"source":row[1],"name":row[2],"method":row[3],"args":row[4] if row.size()>4 else []}
 for source in Roster.ids():
  var data=Roster.data(source)
  for slot in ["flintlock","roll","drink"]+(["rapid_shot"] if data.id=="ranger" else []):
   var id="%s/%s"%[data.id,slot.replace("_","-")]
   _spells[id]={"id":id,"source":source,"name":data.abilities[slot].name,"description":data.abilities[slot].description,"icon":data.abilities[slot].icon,"method":"action","args":[slot]}
 _spells["mountain-king/storm-bolt"].description="Homing hammer: 100/225/350 damage, 5s stun (3s on bosses). Rank follows levels 1/3/5; 9s cooldown. Solid cover blocks it."
 for key in ["crosswise","tenderize","desperado"]:
  _spells["musashi/"+key].description="One press performs the complete Fusion/Lumina sequence. Each cut keeps its windup and must physically connect. Grounded start; interruption cancels the remaining cuts."
 _spells[COMBO].description=KAZ_COMBO_DESCRIPTION+" Uses the receiving fighter's attack gesture and weapon sounds."
 _spells[BEE_FLURRY].description="Shine, then blink around one enemy for five single hits, alternating random opposing sides. Completes all five hits even if the target dies. Invulnerable from shine through return to your starting position; the whole sequence runs at 1.5× speed. Starts within twice your current attack range; every blink uses the Assassination teleport sound. Levels 1–30 add 5 percentage points of critical chance per level, capped at 100% final chance. Damage, five hits, size, range and 5s cooldown stay fixed."
 _spells[SURE_STRIKE].description="Approach the aimed or Tab-targeted enemy and use your empowered normal attack. Damage grows from 1.1× to 4× base damage. Confirmed-hit explosions are visual feedback. 5s cooldown."
 _spells[GUARD_BREAK].required_weapon="melee"
 _spells[GUARD_BREAK].description="With a melee weapon, aim or Tab-target an enemy and rush in. A frontal hit while the guard holds breaks it and staggers the enemy. Damage starts at 1.8× normal per hit and gains 0.2× per level, up to 7.6× at level 30. The charge and impact grow with each level. A miss spends the attack and 5 mana without dealing damage."
 _spells[DOUBLE_EDGE].description="Approach the aimed or Tab-targeted enemy and use your empowered normal attack with 1.6× to 7.4× base damage. Reduce your defense by 10% to 39% for 10s. Works with any weapon. Independent 5s cooldown."
 _spells[MEDITATION].description="Restore 5% of current missing HP at level 1, +1 percentage point per level, reaching 34% at level 30. Heal once when the original cast completes; interruption cancels the heal. Original effects change at levels 10, 19, and 28. EX unlocks at level 30. Works with any weapon. 10s cooldown."
 _spells[KAGEROU].description=KAGEROU_DESCRIPTION
 _spells[BEARS].description="Summon five fast 穴熊 guards with 150 HP, 50 mana and 50 damage per basic hit. They spread out to protect you. Repeat casts add more guards without a cooldown."
 _spells[RANDOM_SHOT].required_weapon="bow"
 _spells[BARRAGE_SHADOWS].required_weapon="bow"
 _spells[BARRAGE_SHADOWS].description="Requires an active Bow. Each cast adds stationary shadows for 30s that fire using your current 亂射 level. Solid cover blocks arrows. 22s cooldown. With BW033 active, the skill is level 30 and has no cooldown."
 _spells[BODYGUARD].description="Automatic while equipped, with any weapon. 50% shuffle-bag chance at level 1, +1 percentage point per additional level (79% at level 30), to interrupt your action, dash in front of an ally within 12 m, push them clear without interrupting their action and take their hit. Pets jump in, then attack the closest reachable enemy. No mana cost. Each additional level reduces only the intercepted hit's damage by 1%, reaching 29% at level 30."
 _spells[COUNTER].required_weapon="polearm"
 _spells[COUNTER].description="Requires an active Spear (Polearm). Always active while equipped: automatically retaliate after taking damage. Skill level sets damage and hit count; consecutive triggers speed up the counters."
 _spells[RANDOM_SHOT].description="Requires an active Bow. Rapidly fire arrows at nearby visible enemies. Level sets arrow count. Solid cover blocks shots. 5s cooldown."
 _spells["musashi/leaping-strike"].air_attack=true
 _spells["musashi/leaping-strike"].description="While equipped, press either attack in the air to dive into Musashi's recovered Fusion downstroke. Works after either jump; the skill key also works airborne. Choose Musashi's Jump Style for his double jump."
 _spells["mountain-king/thunder-clap"].description="Instant ground shockwave, usable during attacks: 22.5/27/31.5m radius, 60/100/140 damage, half movement and attack speed for 5s (3s on bosses). Rank follows levels 1/3/5; 6s cooldown."
 # The charged magical primary and aerial finisher are spells too; melee stays with weapons.
 _spells["blademaster/wind-walk"].description="Stealth and 50% faster movement for up to 8s. The opening attack ends stealth and deals double damage. 12s cooldown."
 _spells["blademaster/mirror-image"].description="Create scattered copies of yourself for %ds. Cross Gate skill levels increase their count and damage. They follow you until enemies are nearby, then favor separate targets and use ready skills before basic attacks. %ds cooldown."%[Warcraft.MIRROR_TIME,Warcraft.MIRROR_COOLDOWN]
 _spells["demon-hunter/immolation"].description="Toggle a burning aura: 30 base damage to nearby enemies once per second. Solid cover blocks it."
 _spells["knight/lion"].description="Gather shield-blue energy for 0.8s, then unleash a piercing lion for 5s at 60 m/s. 360 base damage and strong knockback; 14s cooldown. Solid cover stops it."
 _spells[MOON].description="Release 3–10 waves per cast as the skill levels up. Each wave deals 1.4× to 5.75× base damage. Solid cover blocks waves. 5s cooldown."
 _spells["kazi/qigong"].description="Release 1–16 Qi blasts. Each deals 1.5× to 7.3× base damage. Gain +10 critical-chance points at levels 10, 20 and 30. Color items share this skill and level."
 _spells[MAZE_QI].description="氣功蛋; shares its level, damage, count and critical milestones. Regular blue by default; color items change presentation."
 for element in ["fire","ice","wind","meteor"]:
  _spells["kazi/"+element].description="Each target takes 100 × skill level plus the caster's base magic damage, split across the cast's contacts and pulses. Start with one target and gain one every five levels. Original effect tiers change at levels 10, 19 and 28."
 _spells[RECOVERY].description="Cast on yourself to restore 20% of current missing HP at level 1, +1 percentage point per level, reaching 49%. Original recovery circles change at levels 10, 19, and 28. EX unlocks at level 30. 10s cooldown."
 _spells[SPIRIT].description="精神衝擊波 Lv. 11 · Each normal strike fires at every visible enemy within 192 m. The strikes share 5,000 spell damage plus the caster's base magic damage per target. Solid cover stops the shots. 5s cooldown."
 for key in ["qigong","fire","ice","wind","meteor"]:
  _spells["kazi/"+key].description+=" Kaz and Ruby can target up to 144 m away. Borrowed range is 48 m. Base cooldown is 5s. Their damaging casts speed up the next spell by 0.1×, up to 5×. A miss resets the chain."
  if key!="qigong":_spells["kazi/"+key].description+=" Their cast ignores terrain and walls."
 _spells["mage/fireball"]={"id":"mage/fireball","source":6,"name":"Charged Fireball","method":"charge","args":[]}
 _spells["magic-swordsman/dive"]={"id":"magic-swordsman/dive","source":9,"name":"Sword Energy Dive","method":"_begin_dive","args":[]}
 return _spells

static func available(spec:Dictionary)->bool:
 return Roster.is_crossgate_fighter(spec.source) or spec.id=="blademaster/mirror-image"

static func weapon_matches(required:String,weapon:String)->bool:
 if required=="melee":return weapon not in ["bow","kunai","boomerang"]
 return required==weapon

static func has_required_weapon(spec:Dictionary,weapons:Array)->bool:
 var required:String=spec.get("required_weapon","")
 return required.is_empty() or weapons.any(func(weapon):return weapon_matches(required,weapon))

static func weapon_compatible(spec:Dictionary,model:Node)->bool:
 var required:String=spec.get("required_weapon","")
 return required.is_empty() or (model.has_method("current_weapon") and weapon_matches(required,model.current_weapon()))

static func defaults(character:int)->Dictionary:
 if Roster.is_crossgate_fighter(character):return {}
 if Roster.is_rogue(character):
  var id=Roster.class_id(character)
  return {"equip":id+"/roll","surge":id+"/drink","sky_strike":"knight/lion" if id=="knight" else ("ranger/rapid-shot" if id=="ranger" else "")}
 return {
  1:{"equip":"goemon/dash","surge":"goemon/surge","sky_strike":"goemon/sky-strike"},
  2:{"equip":"edo/fire-dodge","surge":"edo/blue-surge","sky_strike":"edo/meteors"},
  13:{"equip":"musashi/charge","surge":"musashi/guard","sky_strike":""},
  14:{"equip":"ed/smoke-assault","surge":"ed/quick-burst","sky_strike":""},
  15:{"equip":"ben/stars","surge":"","sky_strike":""},
  16:{"equip":"sasuke/ice","surge":"sasuke/super-jump","sky_strike":"sasuke/hair-up"},
  17:{"equip":"yae/shield","surge":"","sky_strike":""},
  18:{"equip":"","surge":"","sky_strike":""},
  31:{"equip":"blademaster/spin","surge":"blademaster/wind-walk","sky_strike":"blademaster/mirror-image"},
  33:{"equip":"mountain-king/storm-bolt","surge":"mountain-king/thunder-clap"},
  32:{"surge":"demon-hunter/immolation"},
  28:{"equip":"kojiro/homing","surge":"kojiro/wind","sky_strike":"kojiro/wave"},
  30:{"equip":"dark-lumina-3/fire","surge":"dark-lumina-3/earth","sky_strike":"dark-lumina-3/wind"},
  29:{"equip":"dark-lumina-2/fireballs","surge":"dark-lumina-2/shockwave","sky_strike":"dark-lumina-2/spin"},
  19:{"equip":"sonic/spin-dash","surge":"sonic/homing","sky_strike":""}
 }.get(character,{})

static func valid_loadouts(value:Variant)->Dictionary:
 var result={}
 if not value is Dictionary:return result
 for character in value:
  if not Roster.valid_loadout_key(character) or not value[character] is Dictionary:continue
  var slots={}
  for action in value[character]:
   if action=="special_6" and not Roster.is_crossgate_fighter(int(str(character).get_slice(":",0))):continue
   var id=value[character][action]
   if id==KAGEROU and not Roster.is_crossgate_fighter(int(str(character).get_slice(":",0))):continue
   if SLOTS.has(action) and id is String and (id not in [RECOVERY,MEDITATION] or Roster.is_crossgate_fighter(int(str(character).get_slice(":",0)))) and all().has(id):slots[action]=id
  # An empty skin record prevents inheriting the old fighter loadout.
  if not slots.is_empty() or ":" in str(character):result[str(character)]=slots
 return result

static func crossgate_native_skills(profile:Dictionary,weapon:String="")->Dictionary:
 if weapon.is_empty():weapon=profile.get("weapon","")
 var slots={}
 if profile.get("strike","")=="bow":
  slots.equip=[RANDOM_SHOT_NAME,"start_random_shot"]
  slots.surge=[SHIN_SURE_STRIKE_NAME,"start_shin_area_cast"]
  slots.special_5=[BARRAGE_SHADOWS_NAME,"start_shadow_mirrors"]
 if profile.get("combo",false):slots.surge=[KAZ_COMBO_NAME,"start_combo"]
 if profile.get("kagerou",false):slots.special_6=[KAGEROU_NAME,"toggle_kagerou"]
 if profile.get("throwing",false):slots.equip=["暗殺 / "+BLADE_DANCE_NAME+" / Qi Blast",""]
 if profile.get("weapon_skills",false) and weapon in ["sword","polearm","axe"]:
  var sword=weapon!="polearm"
  slots.equip=[SHIN_SURE_STRIKE_NAME if sword else SHIN_DOUBLE_EDGE_NAME,"start_shin_area_cast"]
  slots.surge=[KAZ_COMBO_NAME,"start_combo"] if sword else [SHIN_COUNTER_NAME,""]
  if not sword:slots.sky_strike=[SHIN_TWO_BIRDS_NAME,"start_shin_area_cast",true]
  slots.special_4=[SHIN_MEDITATION_NAME,"start_shin_meditation"]
 if profile.get("id","")=="bog":slots.sky_strike=["召喚穴熊","summon_cave_bears"]
 return slots

# Native shortcuts call the existing owner; only explicitly borrowed skills need a donor.
static func hotbar(character:int)->Array:
 if Roster.is_crossgate_fighter(character):return [[],[],[],[],[],[]]
 var slots=[]
 if Roster.is_rogue(character):
  var data=Roster.data(character)
  slots=[
   [data.abilities.roll.name,"equip" if data.id in ["samurai","ninja","explorer","master-thief"] else "dodge"],
   [data.abilities.drink.name,"surge"],
   ["Royal Lion Rush","sky_strike"] if character==7 else ["Rapid Shot · Hold","sky_strike"] if character==10 else [],
   [data.abilities.flintlock.name,"heavy_attack"],["Charged Fireball · Hold","light_attack"] if character==6 else []]
 else:
  slots={
   1:[["Forward Dash","equip"],["Golden Surge","surge"],["Sky Strike","sky_strike"],["Coins","weapon_coin"],["Chain Pipe","weapon_chain"]],
   2:[["Fire Dodge","equip"],["Blue Surge","surge"],["Meteor Rain","sky_strike"],["Fireballs / Blue Beam · Hold","light_attack"],["Giant Fireball","heavy_attack"]],
   13:[["X Slash","start_combo","crosswise"],["Tenderize","start_combo","tenderize"],["Desperado","start_combo","desperado"],["Lumina Rotation","select_number",1],["Mighty Strike","select_number",2]],
   14:[["Smoke Assault","equip"],["Quick Burst","surge"],["Bouncing Fireballs","heavy_attack"],["Beam · Hold","light_attack"],[]],
   15:[["Stars / Hold Axes","equip"],["Bombs · Hold","heavy_attack"],["Throwing Axes","start_utility",true],[],[]],
   16:[["Ice / Hold Hail","equip"],["Super Jump","surge"],["Hair Up","start_hair",false],["Hair Forward","start_hair",true],["Firecracker Bomb","heavy_attack"]],
   17:[["Sword Shield · Hold","equip"],["Bazooka / Hold Lock-on","heavy_attack"],["Lock-on Shot","start_bazooka",true],[],[]],
   18:[["Rocket Launcher","select_slot",1],["Pistol","select_slot",2],["Shotgun","select_slot",3],["Assault Rifle","select_slot",4],["Energy Sword","select_slot",5]],
   19:[["Spin Dash · Hold","equip"],["Homing · Airborne","surge"],[],[],[]],
   27:[["Tail Sweep","equip"],["Poison Drill","surge"],["Jump Stomp","heavy_attack"],["Sand Beam · Hold","light_attack"],[]],
   31:[["Bladestorm","equip"],["Wind Walk","surge"],["Mirror Image · Five Allies","sky_strike"],[],[]],
   33:[["Storm Bolt","equip"],["Thunder Clap","surge"],["Avatar","sky_strike"],["Taunt · War Cry","special_4"],[]],
   32:[["Metamorphosis","equip"],["Immolation · Toggle","surge"],[],[],[]],
   28:[["Homing Shots","equip"],["Wind","surge"],["Sword Wave","sky_strike"],[],[]],
   29:[["Paired Fireballs","equip"],["Jump Stomp","surge"],["Spin Attack","sky_strike"],["Claw Grab","light_attack"],[]],
   30:[["Wind","select_number",1],["Water","select_number",2],["Fire","select_number",3],["Earth","select_number",4],["Sky","select_number",5]]
  }.get(character,[[],[],[],[],[]])
 return slots
