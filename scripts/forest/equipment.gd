extends RefCounted
## Saved gear belongs to a fighter or a stable pet identity, independently of run levels.
const Roster=preload("res://scripts/rogue_roster.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Spells=preload("res://scripts/spells/spell_catalog.gd")
const Cosmetics=preload("res://scripts/forest/cosmetic_catalog.gd")
const WEAPON_SLOTS=["1","2","3","4","5"]
const ACCESSORY_SLOTS=["accessory:1","accessory:2","accessory:3","accessory:4","accessory:5"]
const COSMETIC_SLOTS=["1","2","3","4","5"]
const SLOTS=WEAPON_SLOTS+ACCESSORY_SLOTS
const LEGACY_SLOTS=["1","2","3","4","5","6","7","8","9","10"]
const CHEST_SWORDS=["weapon:SW016","weapon:SW020","weapon:SW042","weapon:SW052","weapon:SW082","weapon:SW101"]
const CHEST_AXES=["weapon:AX018","weapon:AX013","weapon:AX024"]
const CHEST_BOWS=["weapon:BW033"]
const CHEST_WEAPONS=CHEST_SWORDS+CHEST_AXES+CHEST_BOWS
static var ITEMS={
 "weapon:sword":{"name":"Sword","weapon":"sword","icon":preload("res://assets/ui/crossgate/weapons/defaults/sword.png")},
 "weapon:SW016":{"name":"SW016 · Lv3 Sword","weapon":"sword","level":3,"description":"ATK +55 · Dodge chance +10 percentage points.","effects":{"attack":55.0,"dodge_chance":10.0},"icon":preload("res://assets/items/crossgate/swords/sw016.png")},
 "weapon:SW020":{"name":"SW020 · Lv6 Sword","weapon":"sword","level":6,"description":"ATK +150 · Dodge chance +20 percentage points.","effects":{"attack":150.0,"dodge_chance":20.0},"icon":preload("res://assets/items/crossgate/swords/sw020.png")},
 "weapon:SW042":{"name":"SW042 · Lv2 Sword","weapon":"sword","level":2,"description":"ATK +45 · Dodge chance +30 percentage points.","effects":{"attack":45.0,"dodge_chance":30.0},"icon":preload("res://assets/items/crossgate/swords/sw042.png")},
 "weapon:SW052":{"name":"SW052 · Lv6 Sword","weapon":"sword","level":6,"description":"ATK +300 · Dodge chance +40 percentage points.","effects":{"attack":300.0,"dodge_chance":40.0},"icon":preload("res://assets/items/crossgate/swords/sw052.png")},
 "weapon:SW082":{"name":"SW082 · Lv10 Sword","weapon":"sword","level":10,"description":"ATK +400 · Connected normal attacks add level 7 Fire, without a casting motion.","effects":{"attack":400.0,"sword_fire":7.0},"icon":preload("res://assets/items/crossgate/swords/sw082.png")},
 "weapon:SW101":{"name":"SW101 · Lv10 Sword","weapon":"sword","level":10,"description":"ATK +300 · One click performs two normal attacks.","effects":{"attack":300.0,"sword_repeat":1.0},"icon":preload("res://assets/items/crossgate/swords/sw101.png")},
 "weapon:three-weapon":{"name":"Three-Weapon Combo","weapon":"three-weapon","description":"Cycles sword → spear → axe with matching sounds. Uses this character's sword attack stats.","icon":preload("res://assets/ui/crossgate/weapons/three-weapon.png")},
 "weapon:axe":{"name":"Axe","weapon":"axe","description":"Accuracy −10.","icon":preload("res://assets/ui/crossgate/weapons/defaults/axe.png")},
 "weapon:AX018":{"name":"AX018 · Lv3 Axe","weapon":"axe","level":3,"description":"ATK +150 · Critical chance +30 percentage points · Accuracy −10.","effects":{"attack":150.0,"critical_chance":30.0},"icon":preload("res://assets/items/crossgate/axes/ax018.png")},
 "weapon:AX013":{"name":"AX013 · Lv4 Axe","weapon":"axe","level":4,"description":"ATK +300 · Critical chance +30 percentage points · Accuracy −10.","effects":{"attack":300.0,"critical_chance":30.0},"icon":preload("res://assets/items/crossgate/axes/ax013.png")},
 "weapon:AX024":{"name":"AX024 · Lv8 Axe","weapon":"axe","level":8,"description":"ATK +500 · Accuracy −10 · A connected normal hit triggers an extra level 4 乾坤 strike.","effects":{"attack":500.0,"axe_sure_strike":4.0},"icon":preload("res://assets/items/crossgate/axes/ax024.png")},
 "weapon:polearm":{"name":"Spear","weapon":"polearm","icon":preload("res://assets/ui/crossgate/weapons/defaults/polearm.png")},
 "weapon:bow":{"name":"Bow","weapon":"bow","icon":preload("res://assets/ui/crossgate/weapons/defaults/bow.png")},
 "weapon:BW033":{"name":"BW033 · Lv10 Bow","weapon":"bow","level":10,"description":"ATK +500 · Attack speed +200% · 亂射影分身 Lv30, no cooldown.","effects":{"attack":500.0,"attack_speed":2.0,"barrage_shadows_max":1.0},"icon":preload("res://assets/items/crossgate/bows/bw033.png")},
 "weapon:staff":{"name":"Staff","weapon":"staff","icon":preload("res://assets/ui/crossgate/weapons/defaults/staff.png")},
 "weapon:unarmed":{"name":"Boxing Gloves","weapon":"unarmed","icon":preload("res://assets/ui/crossgate/weapons/defaults/boxing-gloves-red.png")},
 "weapon:boomerang":{"name":"Boomerang","weapon":"boomerang","description":"Curves out and returns to you. Hits each enemy once per throw.","icon":preload("res://assets/ui/crossgate/weapons/defaults/boomerang.png")},
 "weapon:water-dragon-boomerang":{"name":"水龍 Boomerang","weapon":"water-dragon-boomerang","description":"Custom 水龍 boomerang with ice impacts and the blue shockwave.","icon":preload("res://assets/characters/crossgate/shin/900050/boomerang/item.png")},
 "weapon:kunai":{"name":"Dagger","weapon":"kunai","icon":preload("res://assets/ui/crossgate/weapons/defaults/dagger.tres")},
 "weapon:beast-master":{"name":"Beast Master","weapon":"beast-master","description":"Left click throws a dagger for base damage. Press 1–5 to summon pets at enemies within 60 m and queue attacks. Press 6 to command the whole group.","icon":preload("res://assets/ui/crossgate/weapons/beast-master.png")},
 "accessory:22":{"name":"#22 · Red Range Bangle","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/22.png"),"description":"Attack range ×2. Multiplies with #23 for ×6.","effects":{"range":2.0}},
 "accessory:23":{"name":"#23 · Violet Range Bangle","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/23.png"),"description":"Attack range ×3. Multiplies with #22 for ×6.","effects":{"range":3.0}},
 "accessory:72":{"name":"#72 · Counter Charm","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/72.png"),"description":"Counterattack chance +35 percentage points, capped at 100%.","effects":{"counter_chance":35.0}},
 "accessory:78":{"name":"#78 · Vitality Charm","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/78.png"),"description":"Maximum health +1,000.","effects":{"health":1000.0}},
 "accessory:207":{"name":"#207 · 追月 Earrings","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/207.png"),"description":"追月 releases two additional waves per cast.","effects":{"moon_extra":2.0}},
 "accessory:217":{"name":"#217 · Fire Earrings","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/217.png"),"description":"Basic attacks become level 1 Fire magic. Replaces #241.","primary":"fire"},
 "accessory:231":{"name":"#231 · 乾坤 Earrings","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/231.png"),"description":"Each connected 乾坤 hit adds an explosion that damages nearby enemies.","effects":{"sure_explosion":1.0}},
 "accessory:241":{"name":"#241 · 亂射 Earrings","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/241.png"),"description":"Bow required: basic attacks become level 1 亂射 (3 arrows). Replaces #217.","primary":"random-shot"},
 "accessory:262":{"name":"#262 · Ice Earrings","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/262.png"),"description":"Each Ice effect hits ten times, repeating its original animation.","effects":{"ice_hits":10.0}},
 "accessory:263":{"name":"#263 · Wind Earrings","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/263.png"),"description":"Wind releases 10 extra projectiles that share selected targets and deal their own hits.","effects":{"wind_extra":10.0}},
 "accessory:21669":{"name":"#21669 · Shadow Vest","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/21669.png"),"description":"Manual Space dodges always leave a shadow that counterattacks automatically from where you dodged. Automatic dodges keep their normal counter chance.","effects":{"manual_dodge_shadow":1.0}},
 "accessory:21678":{"name":"#21678 · Evasion Vest","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/21678.png"),"description":"Dodge chance +100 percentage points (maximum 100%). Physical defense +100.","effects":{"dodge_chance":100.0,"defense":100.0}},
 "accessory:21817":{"name":"#21817 · Speed Shoes","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/21817.png"),"description":"Movement speed ×3 while equipped.","effects":{"movement_speed":3.0}},
 "accessory:21884":{"name":"#21884 · Backstep Boots","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/21884.png"),"description":"Tap Space to dodge backward, even without an enemy warning. Shift + Space still jumps.","effects":{"backstep":1.0}},
 "accessory:dash-boots":{"name":"#21903 · Dash Boots","category":"accessories","icon":preload("res://assets/ui/crossgate/accessories/21903.png"),"description":"Left-click a melee target to dash 50% faster using the run animation. Ranged attacks keep their normal firing range.","effects":{"attack_dash":1.0}}
}
# Launcher-only testing access; do not add these items to the saved collection.
static var test_all_weapons=OS.has_feature("all_weapons") or OS.get_cmdline_user_args().has("--all-weapons")
static var weapon_sets:Dictionary={}
const COLORS={
 "qi-red":{"name":"Red","color":Color("ff625e")},
 "qi-gold":{"name":"Gold","color":Color("ffd365")},
 "qi-jade":{"name":"Jade","color":Color("62e5a0")},
 "qi-violet":{"name":"Violet","color":Color("c18bff")},
 "qi-chrome":{"name":"Rainbow chrome","color":Color.WHITE}
}

static func _static_init():
 for id in Cosmetics.items():
  var item:Dictionary=Cosmetics.items()[id]
  ITEMS[id]={"name":item.name if "#" in item.name or not item.has("sprite") else item.name+" · #"+str(int(item.sprite)),"category":"cosmetics","icon":Cosmetics.icon(id),"description":item.get("description","Equipped appearance · "+str(item.kind))}
 ITEMS.make_read_only()

static func character_key(character:int)->String:return "character:%d"%character
static func pet_key(key:String)->String:return "pet:"+key
static func wearer(hero:Node)->String:
 var pet=hero.get("pet_key")
 return pet_key(pet) if pet is String else character_key(hero.character_id)

static func valid_wearer(key:Variant)->bool:
 if not key is String:return false
 if key.begins_with("character:"):
  var value=key.trim_prefix("character:")
  return value==str(int(value)) and Roster.is_crossgate_fighter(int(value))
 return key.begins_with("pet:") and Pets.skin(key.trim_prefix("pet:"))>=0

static func sanitized(value:Variant,category:String="character")->Dictionary:
 var result={}
 if not value is Dictionary:return result
 for owner in value:
  if not valid_wearer(owner) or not value[owner] is Dictionary:continue
  var slots={}
  var weapons=[]
  for slot in (LEGACY_SLOTS if category=="skill" else SLOTS):
   var id=value[owner].get(slot,"")
   if not id is String or not ITEMS.has(id):continue
   var item_category=ITEMS[id].get("category","character")
   if item_category not in (["character","accessories"] if category=="character" else [category]):continue
   if ITEMS[id].has("weapon"):
    if not owner.begins_with("character:") or slot not in WEAPON_SLOTS or id in weapons:continue
    var character=int(owner.trim_prefix("character:"))
    if not catalog().get(str(character),{}).values().any(func(routes):return routes.has(ITEMS[id].weapon)):continue
    weapons.append(id)
   elif category=="character" and slot not in ACCESSORY_SLOTS:continue
   if ITEMS[id].get("category","")=="accessories":
    if not owner.begins_with("character:") or id in slots.values():continue
    if ITEMS[id].has("primary") and slots.values().any(func(other):return ITEMS.get(other,{}).has("primary")):continue
   slots[slot]=id
  var active=value[owner].get("active_weapon","")
  if active is String and active in WEAPON_SLOTS and slots.has(active):slots.active_weapon=active
  if not slots.is_empty():result[owner]=slots
 return result

static func sanitized_unlocks(value:Variant)->Dictionary:
 var result={}
 if value is Dictionary:
  for owner in value:
   if valid_wearer(owner) and owner.begins_with("character:") and value[owner] is int and value[owner]>=1 and value[owner]<=WEAPON_SLOTS.size():result[owner]=value[owner]
 return result

# Historical sword save keys also hold collected axes; keep existing saves compatible.
static func sanitized_swords(value:Variant)->Array:
 return CHEST_WEAPONS.filter(func(id):return id in value) if value is Array else []

static func sanitized_accessory_drops(value:Variant)->Dictionary:
 var result={}
 if value is Dictionary:
  for id in ITEMS:
   if ITEMS[id].get("category","")!="accessories":continue
   var count_:Variant=value.get(id,0)
   if count_ is int and count_>0:result[id]=mini(count_,1000000)
 return result

static func sanitized_sword_upgrades(value:Variant,owned:Array)->Dictionary:
 var result={}
 if value is Dictionary:
  for id in CHEST_WEAPONS:
   var rank=value.get(id,0)
   if id in owned and rank is int and rank>0:result[id]=rank
 return result

static func item_data(id:String,settings:Dictionary)->Dictionary:
 var item:Dictionary=ITEMS.get(id,{}).duplicate()
 var collected:int= sanitized_accessory_drops(settings.get("accessory_drops",{})).get(id,0)
 if collected>0:item.description=str(item.get("description",""))+"\nCollected ×%d"%collected
 var rank=int(settings.get("sword_upgrades",{}).get(id,0)) if id in CHEST_WEAPONS else 0
 if rank<=0:return item
 item.effects=item.effects.duplicate()
 var base=float(item.effects.attack)
 item.effects.attack=roundf(base*(1.0+.1*rank))
 item.name+=" +%d"%rank
 item.description=str(item.description).replace("ATK +%d"%roundi(base),"ATK +%d"%roundi(item.effects.attack))
 return item

static func unlocked(owner:String,settings:Dictionary)->int:
 return int(sanitized_unlocks(settings.get("weapon_slot_unlocks",{})).get(owner,1)) if owner.begins_with("character:") else 0

static func slots_unlocked(loadouts:Dictionary,settings:Dictionary)->bool:
 for owner in loadouts:
  for slot in WEAPON_SLOTS:
   if loadouts[owner].has(slot) and int(slot)>unlocked(owner,settings):return false
 return true

static func migrated_gear(value:Variant,settings:Dictionary)->Dictionary:
 if not value is Dictionary:return {}
 var migrated=value.duplicate(true)
 for owner in migrated:
  if not valid_wearer(owner) or not migrated[owner] is Dictionary:continue
  if unlocked(owner,settings)>1:continue
  for slot in LEGACY_SLOTS:
   var id=migrated[owner].get(slot,"")
   if id is String and ITEMS.get(id,{}).has("weapon"):
    migrated[owner].erase(slot);migrated[owner]["1"]=id;break
 return sanitized(migrated)

static func sanitized_cosmetics(value:Variant)->Dictionary:
 var result={}
 if not value is Dictionary:return result
 for owner in value:
  if not valid_wearer(owner) or not value[owner] is Dictionary:continue
  var entry={}
  var id=value[owner].get("qi_color")
  if id is String and (id.is_empty() or COLORS.has(id)):entry.qi_color=id
  var saved=value[owner].get("slots")
  if saved is Dictionary:
   var slots={};var has_color=false
   for slot in COSMETIC_SLOTS:
    var item=saved.get(slot,"")
    if not item is String or item in slots.values():continue
    if COLORS.has(item):
     if has_color:continue
     has_color=true;entry.qi_color=item
    elif ITEMS.get(item,{}).get("category","")!="cosmetics" or not owner.begins_with("character:"):continue
    slots[slot]=item
   entry.slots=slots
   if not has_color:entry.qi_color=""
  if not entry.is_empty():result[owner]=entry
 return result

static func cosmetic_slots(loadouts:Dictionary,owner:String)->Dictionary:
 var entry:Dictionary=loadouts.get(owner,{})
 if entry.has("slots"):return entry.slots.duplicate()
 var id:String=entry.get("qi_color","")
 return {"2":id} if COLORS.has(id) else {}

static func migrated_cosmetics(value:Variant,legacy_gear:Variant)->Dictionary:
 var result=sanitized_cosmetics(value)
 if not legacy_gear is Dictionary:return result
 for owner in legacy_gear:
  if result.has(owner) or not valid_wearer(owner) or not legacy_gear[owner] is Dictionary:continue
  for slot in ["crystal"]+LEGACY_SLOTS:
   var id=legacy_gear[owner].get(slot,"")
   if id is String and COLORS.has(id):result[owner]={"qi_color":id};break
 return result

static func color(loadouts:Dictionary,owner:String)->Color:
 var id=loadouts.get(owner,{}).get("qi_color","")
 return COLORS[id].color if COLORS.has(id) else Color.WHITE

static func qi_color(hero:Node)->Color:
 return color(hero.game.settings.get("cosmetic_loadouts",{}),wearer(hero))

static func qi_chrome(hero:Node)->bool:
 return hero.game.settings.get("cosmetic_loadouts",{}).get(wearer(hero),{}).get("qi_color","")=="qi-chrome"

static func catalog()->Dictionary:
 if weapon_sets.is_empty():
  weapon_sets=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/weapons/catalog.json"))
  for character in weapon_sets:
   var skins:Dictionary=weapon_sets[character]
   for skin in skins:
    var routes:Dictionary=skins[skin]
    # Standard boomerang sets use the original bare-body throw at its source release frame.
    var throw_route:Dictionary=routes.get("kunai",routes.get("boomerang",{}))
    if throw_route.is_empty():
     var root="res://assets/characters/crossgate/weapons/beast_master/%s-%s/"%[character,skin]
     if FileAccess.file_exists(root+"motions.json"):throw_route={"root":root}
    if not throw_route.is_empty():
     var beast_master=throw_route.duplicate()
     beast_master.base_weapon="kunai"
     if not routes.has("kunai"):beast_master.projectile="maze_dagger"
     routes["beast-master"]=beast_master
    if not ["sword","polearm","axe"].all(func(weapon):return routes.has(weapon)):continue
    routes["three-weapon"]=routes.sword.duplicate()
    routes["three-weapon"].base_weapon="sword"
 return weapon_sets

static func allowed(character:int,settings:Dictionary)->Dictionary:
 return catalog().get(str(character),{}).get(str(Roster.selected_skin(character,settings)),{})

static func can_equip(owner:String,id:String,settings:Dictionary)->bool:
 if not ITEMS.has(id):return false
 if id in CHEST_WEAPONS and not test_all_weapons and id not in settings.get("chest_swords",[]):return false
 if ITEMS[id].get("category","")=="cosmetics":return owner.begins_with("character:") and valid_wearer(owner)
 if ITEMS[id].get("category","")=="accessories":return owner.begins_with("character:") and valid_wearer(owner)
 if not ITEMS[id].has("weapon"):return true
 return owner.begins_with("character:") and allowed(int(owner.trim_prefix("character:")),settings).has(ITEMS[id].weapon)

static func default_weapon(character:int,settings:Dictionary)->String:
 var profile:Dictionary=Roster.CROSSGATE[character]
 var fallback=int(profile.get("start_weapon",0))
 if profile.get("throwing",false):fallback=int(settings.get(profile.get("primary_setting",""),false))
 var saved:Variant=settings.get("skin_equipment",{}).get(Roster.loadout_key(character,settings),{}).get("weapon",fallback)
 var index=int(saved) if saved is int and saved>=0 else fallback
 var routes=allowed(character,settings)
 for weapon in routes:
  if routes[weapon].get("native",-1)==index:return weapon
 for weapon in routes:
  if routes[weapon].has("native"):return weapon
 return ""

static func equipped(loadouts:Dictionary,character:int)->String:
 var slots:Dictionary=loadouts.get(character_key(character),{})
 var active:String=slots.get("active_weapon","")
 if active in WEAPON_SLOTS and ITEMS.get(slots.get(active,""),{}).has("weapon"):return slots[active]
 for slot in WEAPON_SLOTS:
  var id=slots.get(slot,"")
  if ITEMS.has(id) and ITEMS[id].has("weapon"):return id
 return ""

static func carried_weapons(loadouts:Dictionary,character:int,settings:Dictionary)->Array:
 var owner=character_key(character);var slots:Dictionary=loadouts.get(owner,{})
 var result=[]
 for slot in WEAPON_SLOTS:
  var id=slots.get(slot,"")
  if int(slot)<=unlocked(owner,settings) and can_equip(owner,id,settings):
   var weapon:String=ITEMS[id].weapon
   result.append(allowed(character,settings)[weapon].get("base_weapon",weapon))
 if result.is_empty():result.append(default_weapon(character,settings))
 return result

static func skill_weapon_error(loadouts:Dictionary,spells:Dictionary,character:int,settings:Dictionary)->String:
 if not Roster.is_crossgate_fighter(character):return ""
 if equipped(loadouts,character)=="weapon:beast-master" and can_equip(character_key(character),"weapon:beast-master",settings):return ""
 var weapons=carried_weapons(loadouts,character,settings)
 var slots:Dictionary=spells.get(Roster.loadout_key(character,settings),spells.get(str(character),{}))
 for id in slots.values():
  var spec:Dictionary=Spells.all().get(id,{})
  if Spells.has_required_weapon(spec,weapons):continue
  var required:String=spec.get("required_weapon","")
  var weapon_name:String="a melee weapon" if required=="melee" else ITEMS["weapon:"+required].name
  return "Equip %s to use %s."%[weapon_name,spec.name]
 return ""

static func apply_model(visual:Node)->bool:
 var hero=visual.get_parent()
 if hero.get("pet_key") is String or (hero.ai_controlled and not hero.mirror_copy):return false
 var id=equipped(hero.game.settings.get("gear_loadouts",{}),visual.character)
 var weapon:String=ITEMS[id].weapon if ITEMS.has(id) else ""
 var route:Dictionary=allowed(visual.character,hero.game.settings).get(weapon,{})
 if route.is_empty():weapon=""
 if visual.gear_weapon!=weapon or visual.gear_route!=route:
  if hero.character_id==visual.character and hero.model==visual and is_instance_valid(hero.active_ability) and hero.active_ability.active:
   hero.active_ability.cancel(true);hero.active_ability.clear_shin_counter();hero.spell_loadout.interrupt()
 var changed=visual.apply_gear_weapon(weapon if not route.is_empty() else "",route)
 visual.refresh_cosmetics()
 return changed

static func bonuses(loadouts:Dictionary,owner:String,settings:Dictionary={})->Dictionary:
 var result={}
 var slots:Dictionary=loadouts.get(owner,{})
 var active=equipped(loadouts,int(owner.trim_prefix("character:"))) if owner.begins_with("character:") else ""
 if not settings.is_empty() and not can_equip(owner,active,settings):active=""
 for id in [active]+ACCESSORY_SLOTS.map(func(slot):return slots.get(slot,"")):
  var item:Dictionary=item_data(id,settings)
  for key in item.get("effects",{}):
   result[key]=float(result.get(key,1.0))*float(item.effects[key]) if key in ["range","movement_speed"] else float(result.get(key,0.0))+float(item.effects[key])
  if item.has("primary") and active!="weapon:beast-master":result.primary=item.primary
 return result

static func apply(hero:Node):
 var previous:Dictionary=hero.accessory_bonuses
 hero.accessory_bonuses=bonuses(hero.game.settings.get("gear_loadouts",{}),character_key(hero.character_id),hero.game.settings) if Roster.is_crossgate_fighter(hero.character_id) else {}
 hero.refresh_max_health()
 if not Roster.is_crossgate_fighter(hero.character_id):return
 var changed=apply_model(hero.model)
 if not changed and previous==hero.accessory_bonuses:return
 if previous!=hero.accessory_bonuses:
  if previous.get("manual_dodge_shadow",0)>0 and hero.accessory_bonuses.get("manual_dodge_shadow",0)<=0:
   hero.timed_dodge.reset();hero.active_ability.clear_shin_counter()
  hero.active_ability.cancel(true);hero.spell_loadout.interrupt()
 if changed:
  hero.active_ability.stop_primary_approach()
  hero.active_ability.primary_hold_target=null
 hero.active_ability.prepare_projectiles();hero.spell_loadout.prepare()

static func cycle(hero:Node)->bool:
 var loadouts:Dictionary=hero.game.settings.get("gear_loadouts",{})
 var current=equipped(loadouts,hero.character_id)
 if current.is_empty():
  if not hero.model.appearance.has("source_weapons"):return false
  current="weapon:"+hero.model.current_weapon()
  loadouts=loadouts.duplicate(true)
  var native_owner=character_key(hero.character_id)
  loadouts[native_owner]=loadouts.get(native_owner,{}).duplicate()
  loadouts[native_owner]["1"]=current
 if hero.active_ability.is_attacking() or hero.active_ability.blocks_movement():return true
 var owner=character_key(hero.character_id)
 var carried:Dictionary=loadouts.get(owner,{})
 var equipped_slots=WEAPON_SLOTS.filter(func(slot):return int(slot)<=unlocked(owner,hero.game.settings) and can_equip(owner,carried.get(slot,""),hero.game.settings))
 if equipped_slots.size()>1:
  var index=equipped_slots.find(carried.get("active_weapon",equipped_slots[0]))
  var selection=loadouts.duplicate(true);selection[owner].active_weapon=equipped_slots[(index+1)%equipped_slots.size()]
  if not hero.game.save_equipment_loadouts(selection,hero.game.settings.skill_item_loadouts,hero.game.settings.cosmetic_loadouts):hero.game.toast("Could not save weapon")
  return true
 var choices=allowed(hero.character_id,hero.game.settings).keys()
 if choices.size()<2:return true
 var next:String=choices[(choices.find(ITEMS[current].weapon)+1)%choices.size()]
 var draft=loadouts.duplicate(true);var slots:Dictionary=draft[character_key(hero.character_id)]
 for slot in WEAPON_SLOTS:
  if slots.get(slot,"")==current:slots[slot]="weapon:"+next;break
 if not hero.game.save_equipment_loadouts(draft,hero.game.settings.skill_item_loadouts,hero.game.settings.cosmetic_loadouts):hero.game.toast("Could not save weapon")
 return true
