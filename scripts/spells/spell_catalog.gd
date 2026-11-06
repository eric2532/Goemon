@static_unload
extends RefCounted
## Stable spell IDs are independent of the fighter wearing them and of input keys.
const Roster=preload("res://scripts/rogue_roster.gd")
const SLOTS={"equip":"1", "surge":"2", "sky_strike":"3", "special_4":"4", "special_5":"5"}
const SPECIALS=[
 ["mountain-king/storm-bolt",33,"Storm Bolt","start_bolt"],
 ["mountain-king/thunder-clap",33,"Thunder Clap","start_clap"],
 ["blademaster/spin",31,"Bladestorm","start_spin"],
 ["blademaster/wind-walk",31,"Wind Walk","start_wind"],
 ["blademaster/mirror-image",31,"Mirror Image · Five Allies","start_mirrors"],
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
 _spells["musashi/leaping-strike"].air_attack=true
 _spells["musashi/leaping-strike"].description="While equipped, press either attack in the air to dive into Musashi's recovered Fusion downstroke. Works after either jump; the skill key also works airborne. Choose Musashi's Jump Style for his double jump."
 _spells["mountain-king/thunder-clap"].description="Instant ground shockwave, usable during attacks: 22.5/27/31.5m radius, 60/100/140 damage, half movement and attack speed for 5s (3s on bosses). Rank follows levels 1/3/5; 6s cooldown."
 # The charged magical primary and aerial finisher are spells too; melee stays with weapons.
 _spells["blademaster/wind-walk"].description="Stealth and 50% faster movement for up to 8s. The opening attack ends stealth and deals double damage. 12s cooldown."
 _spells["blademaster/mirror-image"].description="Create five scattered copies of yourself for 15s. They immediately seek nearby visible enemies, favor separate targets and approach from different sides. Attacks are chosen at random. 22s cooldown."
 _spells["demon-hunter/immolation"].description="Toggle a burning aura: 30 base damage to nearby enemies once per second. Solid cover blocks it."
 _spells["knight/lion"].description="Gather shield-blue energy for 0.8s, then unleash a piercing lion for 5s at 60 m/s. 360 base damage and strong knockback; 14s cooldown. Solid cover stops it."
 _spells["mage/fireball"]={"id":"mage/fireball","source":6,"name":"Charged Fireball","method":"charge","args":[]}
 _spells["magic-swordsman/dive"]={"id":"magic-swordsman/dive","source":9,"name":"Sword Energy Dive","method":"_begin_dive","args":[]}
 return _spells

static func defaults(character:int)->Dictionary:
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
  if str(character)!=str(int(str(character))) or int(str(character)) not in Roster.PLAYABLE_IDS or not value[character] is Dictionary:continue
  var slots={}
  for action in value[character]:
   var id=value[character][action]
   if SLOTS.has(action) and id is String and all().has(id):slots[action]=id
  if not slots.is_empty():result[str(character)]=slots
 return result

# Native shortcuts call the existing owner; only explicitly borrowed skills need a donor.
static func hotbar(character:int)->Array:
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
