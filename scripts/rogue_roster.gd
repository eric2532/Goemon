extends RefCounted
## Stable Sonic IDs for the ten authored Rogue classes. Combat data stays native.

const FIRST_ID = 3
const MUSASHI_ID = 13
const ED_ID = 14
const BEN_ID = 15
const SASUKE_ID = 16
const YAE_ID = 17
const MASTER_CHIEF_ID = 18
const SONIC_ID = 19
const KOJIRO_ID = 28
const KAZI_ID = 34
const RUBY_ID = 35
const MAZE_ID = 36
enum MazeWeapon {KATANA, KUNAI, FIST}
const SHIN_ID = 37
const SHIN_SPECIAL_ID = 38
const SAIZO_ID = 39
const BOG_ID = 40
# ID 41 is retired; preserve its saved character/audio identity.
const EMILIA_ID = 42
const LANCELOT_ID = 43
const PETE_ID = 44
const GRACE_ID = 45
const REI_ID = 46
const CEDI_ID = 47
const BEI_ID = 48
const MOE_ID = 49
const AMI_ID = 50
const KUMAGO_ID = 51
const BAU_ID = 52
const EL_ID = 53
const GEN_ID = 54
const SARAH_ID = 55
const FourCastSkins=preload("res://scripts/crossgate_four_cast_skins.gd")
const CastSkins=preload("res://scripts/crossgate_cast_skins.gd")
const SpecialSkins=preload("res://scripts/crossgate_special_skins.gd")
static var skin_catalogs:Dictionary={}
const ShinSkins=preload("res://scripts/shin_skins.gd")
const SaizoSkins=preload("res://scripts/saizo_skins.gd")
const RUBY={
	"id":"uru","root":"ruby",
	"skins":{0:["Original"]},"skin_default":0,"skin_setting":"ruby_skin","portrait_origin":Vector2(-34,-82),"weapon":"staff",
	"strike":"staff","magic":"ruby","audio":RUBY_ID,
	"name":"Uru","color":"#ffad79","description":"LMB / RMB Original staff combo · 1–5 Blue Cross Gate spells · Space Timed Dodge."
}
const EMILIA={
	"id":"emilia","root":"fighters/emilia","body_pixels":80.0,"weapon":"staff",
	"skins":{
		120387:["Emilia + Puck"],120388:["Emilia"],
		106275:["Original Brown / Purple"],106281:["Original Black / Red"],
		106287:["Original Red / Green"],106293:["Original Gold / Pink"],
		100774:["Dark Ayame"],105430:["Snow Ayame"],105824:["Pink-haired Ayame"],
		105830:["Blonde Ayame"],105837:["Magenta Hair / Black"],106625:["Blonde / Dark Green"],
		111669:["Brown Hair / White"],120322:["Sakura Ayame"],120484:["Fragrant Ayame"],
		120490:["Green Hair / White"],100224:["Blue-haired Ayame"],100230:["Silver-haired Ayame"],
	},"skin_default":120387,"skin_setting":"emilia_skin","portrait_origin":Vector2(-64,-128),
	"strike":"staff","magic":"ruby","audio":RUBY_ID,"role":"Staff caster",
	"name":"Emilia","color":"#d6b9f1","description":RUBY.description
}
const KAZI={
	"id":"kazi","root":"kazi",
	"strike":"cuts","magic":"kazi","combo":true,"kagerou":true,"audio":KAZI_ID,
	"name":"Kaz","color":"#c48aff","description":"LMB / RMB Blade attack · 2 連擊 · 6 陽炎 · WASD Move · Shift Sprint · Space Timed Dodge · Q Shared skills."
}
const MAZE={
	"id":"maze","root":"maze","motion_root":"kazi",
	"kunai_count":2,"kunai_size":.85*.85,
	"strike":"cuts","throwing":true,"kagerou":true,"audio":MAZE_ID,"primary_setting":"maze_primary_kunai",
	"name":"Maze","color":"#dbadff","description":"LMB / RMB Katana or nearest-enemy dagger throw · 3 Mirror Image · 6 陽炎 · Space Timed Dodge."
}
const SAIZO={
	"id":"saizo","root":SaizoSkins.ROOT,"body_pixels":90.0,
	"skins":SaizoSkins.CATALOG,"skin_default":SaizoSkins.DEFAULT,"skin_setting":"saizo_skin","portrait_origin":SaizoSkins.PORTRAIT_ORIGIN,
	"strike":"cuts","throwing":true,"kagerou":true,"audio":MAZE_ID,"primary_setting":"saizo_primary_kunai",
	"name":"Saizo","color":"#9fdbe3","description":MAZE.description
}
const BOG={
	"id":"bog","root":"fighters/bog","body_pixels":94.0,"weapon":"axe",
	"skins":{100625:["Gray hair / black"],100942:["Dark hair / black"]},"skin_default":100625,"skin_setting":"bog_skin","portrait_origin":Vector2(-19,-86),
	"strike":"timed","weapon_skills":true,"audio":BOG_ID,
	"name":"Bog","color":"#c4ad79","description":"LMB / RMB Axe attack · 1 乾坤 · 2 連擊 · 3 召喚穴熊 · 4 明鏡止水 · Space Timed Dodge."
}
const SHIN={
	37:{"id":"shin","skin_set":"regular",
		"strike":"timed","weapon_skills":true,"start_weapon":1,"audio":SHIN_ID,
		"name":"Shin","color":"#79b6ef","description":"LMB / RMB Basic strike · 1 乾坤 / 諸刃 · 2 連擊 / 反擊 · Polearm 3 一石二鳥 · 4 明鏡止水 · Space Timed Dodge."},
	38:{"id":"shin-special","skin_set":"special",
		"strike":"timed","weapon_effects":true,"audio":SHIN_SPECIAL_ID,
		"name":"Shin Special","color":"#f3ba66","description":"LMB / RMB Basic strike · Space Timed Dodge."}
}
const LANCELOT={
	"id":"lancelot","root":"fighters/lancelot","body_pixels":87.0,"weapon":"bow",
	"skins":{106125:["White / Silver"],106131:["Gold / Purple"],106137:["Black / Red"],106143:["Blue / Brown"],106550:["Silver / Green"],105206:["Black Lancelot"],105212:["Emerald / Black"],105907:["Mint / Blue"]},
	"skin_default":106125,"skin_setting":"lancelot_skin","portrait_origin":Vector2(-55,-79),
	"strike":"bow","kagerou":true,"audio":KAZI_ID,"role":"Archer · auto-aim",
	"name":"Lancelot","color":"#c5d6ba","description":"LMB / RMB Auto-aim bow · 1 亂射 · 2 乾坤 · 5 Five barrage shadows (30s) · 6 陽炎 · Space Timed Dodge · Q Shared skills."
}
const PETE={"id":"pete","name":"Pete","root":"fighters/pete","skins":CastSkins.PETE,"skin_default":106025,"skin_setting":"pete_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#e9b867","description":"Original Cross Gate attacks · Q Equipment and shared skills · Space Timed Dodge."}
const GRACE={"id":"grace","name":"Grace","root":"fighters/grace","skins":CastSkins.GRACE,"skin_default":106375,"skin_setting":"grace_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#b4d4ac","description":PETE.description}
const REI={"id":"rei","name":"Rei","root":"fighters/rei","skins":CastSkins.REI,"skin_default":105350,"skin_setting":"rei_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#85c7a1","description":PETE.description}
const CEDI={"id":"cedi","name":"Cedi","root":"fighters/cedi","skins":CastSkins.CEDI,"skin_default":106000,"skin_setting":"cedi_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#83bbdf","description":PETE.description}
const BEI={"id":"bei","name":"Bei","root":"fighters/bei","skins":SpecialSkins.CAST_CATALOG[BEI_ID],"skin_default":105125,"skin_setting":"bei_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#a9bed4","description":PETE.description}
const MOE={"id":"moe","name":"Moe","root":"fighters/moe","skins":SpecialSkins.CAST_CATALOG[MOE_ID],"skin_default":105275,"skin_setting":"moe_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#d7a1d5","description":PETE.description}
const AMI={"id":"ami","name":"Ami","root":"fighters/ami","skins":SpecialSkins.CAST_CATALOG[AMI_ID],"skin_default":105300,"skin_setting":"ami_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#f5b962","description":PETE.description}
const KUMAGO={"id":"kumago","name":"熊哥","root":"fighters/kumago","skins":SpecialSkins.CAST_CATALOG[KUMAGO_ID],"skin_default":100800,"skin_setting":"kumago_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#e7654e","description":"Original Cross Gate fists and weapons · Q Equipment and shared skills · Space Timed Dodge."}
const BAU={"id":"bau","name":"Bau","root":"fighters/bau","skins":FourCastSkins.BAU,"skin_default":105000,"skin_setting":"bau_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#8db759","description":PETE.description}
const EL={"id":"el","name":"El","root":"fighters/el","skins":FourCastSkins.EL,"skin_default":105400,"skin_setting":"el_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#6ca887","description":PETE.description}
const GEN={"id":"gen","name":"Gen","root":"fighters/gen","skins":FourCastSkins.GEN,"skin_default":105100,"skin_setting":"gen_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#d38a68","description":PETE.description}
const SARAH={"id":"sarah","name":"Sarah","root":"fighters/sarah","skins":FourCastSkins.SARAH,"skin_default":106250,"skin_setting":"sarah_skin","portrait_origin":Vector2.ZERO,"strike":"timed","weapon_skills":true,"audio":SHIN_ID,"color":"#e3bd81","description":PETE.description}
const CROSSGATE={RUBY_ID:RUBY,KAZI_ID:KAZI,MAZE_ID:MAZE,SHIN_ID:SHIN[SHIN_ID],SHIN_SPECIAL_ID:SHIN[SHIN_SPECIAL_ID],SAIZO_ID:SAIZO,BOG_ID:BOG,EMILIA_ID:EMILIA,LANCELOT_ID:LANCELOT,PETE_ID:PETE,GRACE_ID:GRACE,REI_ID:REI,CEDI_ID:CEDI,BEI_ID:BEI,MOE_ID:MOE,AMI_ID:AMI,KUMAGO_ID:KUMAGO,BAU_ID:BAU,EL_ID:EL,GEN_ID:GEN,SARAH_ID:SARAH}
const KAZI_PORTRAIT="res://assets/characters/crossgate/kazi/portrait-front.png"
const WARCRAFT={33:{"id":"mountain-king","name":"Mountain King","color":"#278dff","description":"LMB Hammer and axe · RMB / 1 Storm Bolt · 2 Thunder Clap · 3 Avatar · 4 Taunt / War Cry · Passive Bash. WASD Move · Shift Sprint · Space Jump · C Evade · Q Shared skills."},31:{"id":"blademaster","name":"Blademaster","color":"#a2bf70","description":"LMB Sword combo · RMB Critical strike · 1 Bladestorm · 2 Wind Walk · 3 Mirror Image · Space Jump · C Evade. Equip shared skills with Q."},32:{"id":"demon-hunter","name":"Illidan","color":"#b195dc","description":"LMB Glaive combo / Demon bolt · RMB / 1 Metamorphosis · 2 Immolation · Space Jump · C Evade. Meta form: hold Space to fly, release to descend; Shift boosts. Equip shared skills with Q."}}
static var PLAYABLE_IDS = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33]+CROSSGATE.keys()
const MUSASHI_PORTRAIT = "res://assets/characters/recovered_musashi/portrait.png"
const CLASS_IDS = ["pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
const ENEMIES={
 30:{"role":18,"id":"dark-lumina-3","name":"Dark Lumina 3","color":"#9680ed","description":"1 Wind · 2 Water · 3 Fire · 4 Earth · 5 Sky. LMB Kojiro’s Wind wave → two energy blades, all piercing; click for each. Hold Space to fly, release to descend; Shift boosts."},
	29:{"role":17,"id":"dark-lumina-2","name":"Dark Lumina 2","color":"#a9d670","description":"LMB Claw grab · RMB/2 Jump stomp · 1 Paired fireballs · 3 Spin attack. In the air, RMB/2 stomps down into energy waves."},
	20:{"role":0,"id":"red-soldier","name":"Red Soldier","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	21:{"role":1,"id":"blue-gunner","name":"Blue Gunner","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	22:{"role":3,"id":"green-spearman","name":"Green Spearman","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	23:{"role":6,"id":"vambee","name":"Vambee","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	24:{"role":9,"id":"haya-wolf","name":"Haya Wolf","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	25:{"role":14,"id":"vambee-torso","name":"Vambee Torso","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	26:{"role":16,"id":"slow-guy","name":"Slow Guy","color":"#b9d5c5","description":"LMB / RMB Original attack · 1–5 Equipped skills · C Evade · Space Jump."},
	27:{"role":4,"id":"skullpion","name":"Skullpion","color":"#b9d5c5","description":"Hold LMB Sand beam · RMB Jump stomp · 1 Fast tail sweep · 2 Fast poison drill (nearest enemy) · Space Fast leap. 3 Jump stomp · 4 Hold sand beam · Q Equip skills. Full boss size."},
}
static func crossgate_profile(id:int)->Dictionary:return CROSSGATE.get(id,{})
static func uses_crossgate_spells(id:int)->bool:return crossgate_profile(id).has("magic")
static func is_crossgate_fighter(id:int)->bool:return CROSSGATE.has(id)
static func is_shin(id:int)->bool:return crossgate_profile(id).has("skin_set")
static func has_variant_skins(id:int)->bool:return crossgate_profile(id).has("skins")
static func valid_skin(character:int,value:Variant)->int:
	var profile=CROSSGATE[character]
	return int(value) if value is int and skin_catalog(character).has(value) else int(profile.skin_default)
static func skin_root(character:int,skin:int)->String:
	if character==RUBY_ID and skin==0:return "res://assets/characters/crossgate/ruby/"
	# Old Bau lookups still resolve after correcting these skins' ownership.
	if character==BAU_ID and skin in FourCastSkins.BAU_HIDDEN:character=GEN_ID
	return "res://assets/characters/crossgate/%s/%d/"%[CROSSGATE[character].root,skin]
static func skin_portrait(character:int,skin:int)->Texture2D:return load(skin_root(character,skin)+"portrait.png")
static func skin_portrait_origin(character:int,skin:int)->Vector2:
	var entry:Array=skin_catalog(character)[skin]
	return entry[1] if entry.size()>1 and entry[1] is Vector2 else CROSSGATE[character].portrait_origin
static func skin_catalog(character:int)->Dictionary:
	if character==KAZI_ID:return preload("res://scripts/kaz_skins.gd").CATALOG
	if is_shin(character):return ShinSkins.gallery(character==SHIN_SPECIAL_ID)
	if not skin_catalogs.has(character):
		skin_catalogs[character]=crossgate_profile(character).get("skins",{}).merged(SpecialSkins.CATALOG.get(character,{})).merged(SpecialSkins.URU_CATALOG if character==RUBY_ID else {})
	return skin_catalogs[character]
static func skin_setting(character:int)->String:
	if character==KAZI_ID:return "kaz_skin"
	if is_shin(character):return ShinSkins.setting(character==SHIN_SPECIAL_ID)
	return crossgate_profile(character).get("skin_setting","")
static func selected_skin(character:int,settings:Dictionary)->int:
	if is_shin(character):return ShinSkins.valid_id(character==SHIN_SPECIAL_ID,settings.get(skin_setting(character)))
	var catalog=skin_catalog(character)
	if catalog.is_empty():return 0
	var fallback=int(catalog.keys()[0])
	var id:Variant=settings.get(skin_setting(character),fallback)
	return int(id) if id is int and catalog.has(id) else fallback
static func loadout_key(character:int,settings:Dictionary)->String:
	if character==RUBY_ID and selected_skin(character,settings)==0:return str(character)
	return "%d:%d"%[character,selected_skin(character,settings)] if not skin_catalog(character).is_empty() else str(character)
static func valid_loadout_key(value:Variant)->bool:
	var parts=str(value).split(":")
	if parts.size()>2 or parts[0]!=str(int(parts[0])) or int(parts[0]) not in PLAYABLE_IDS:return false
	if parts.size()==1:return true
	var character=int(parts[0]);var skin=int(parts[1])
	return parts[1]==str(skin) and (skin_catalog(character).has(skin) or (character==SHIN_SPECIAL_ID and skin in ShinSkins.HIDDEN_CLASSIC) or (character==BAU_ID and skin in FourCastSkins.BAU_HIDDEN))
static func has_kagerou(id:int)->bool:return crossgate_profile(id).get("kagerou",false)
static func has_crossgate_throws(id:int)->bool:return crossgate_profile(id).get("throwing",false)
static func is_crossgate_archer(id:int)->bool:return crossgate_profile(id).get("strike","")=="bow"
static func is_enemy(id:int)->bool:return ENEMIES.has(id)

const DATA_PATH = "res://assets/rogue/data/classes.json"
static var _classes: Dictionary = {}
static var _portraits: Dictionary = {}
static var _selection_portraits: Dictionary = {}

static func selection_ids() -> Array[int]:
	var result:Array[int]=[]
	result.assign(CROSSGATE.keys())
	result.erase(MAZE_ID)
	return result

static func gallery_id(character:int)->int:
	return KAZI_ID if character==MAZE_ID else character

static func skin_character(character:int,settings:Dictionary)->int:
	if gallery_id(character)!=KAZI_ID:return character
	return MAZE_ID if selected_skin(KAZI_ID,settings)==preload("res://scripts/kaz_skins.gd").MAZE else KAZI_ID

static func sound_ids() -> Array[int]:
	var result: Array[int] = []
	result.assign(CROSSGATE.keys())
	return result

## Selection art has its own full-body framing. HUD portraits retain the stable
## face position used by the circular crop in forest_hud_portrait.gdshader.
static func selection_portrait_path(id: int) -> String:
	if is_shin(id):return ShinSkins.root(ShinSkins.valid_id(CROSSGATE[id].skin_set=="special",null))+"portrait.png"
	if has_variant_skins(id):return skin_root(id,CROSSGATE[id].skin_default)+"portrait.png"
	if id==KAZI_ID:return KAZI_PORTRAIT
	if is_crossgate_fighter(id):return "res://assets/characters/crossgate/%s/portrait.png"%CROSSGATE[id].root
	if WARCRAFT.has(id):return "res://assets/characters/warcraft/%s/portrait.png"%class_id(id)
	if id==KOJIRO_ID:return "res://assets/characters/recovered_kojiro/portrait.png"
	if is_enemy(id):return "res://assets/characters/playable_enemies/%s.png"%class_id(id)
	if id==SONIC_ID:return "res://assets/characters/recovered_sonic/portrait.png"
	if id==MASTER_CHIEF_ID:return "res://assets/characters/master_chief/portrait.png"
	if id==YAE_ID:return "res://assets/characters/recovered_yae/portrait.png"
	if id==SASUKE_ID:return "res://assets/characters/recovered_sasuke/portrait.png"
	if id==MUSASHI_ID:return MUSASHI_PORTRAIT
	if id in [ED_ID,BEN_ID]:return "res://assets/characters/recovered_leaders/%s/portrait.png"%class_id(id)
	var key = "goemon" if id == 1 else ("edo" if id == 2 else class_id(id))
	return "res://assets/models/characters/selection_portraits/%s.png" % key

static func selection_portrait(id: int) -> Texture2D:
	if id not in PLAYABLE_IDS:return null
	if not _selection_portraits.has(id):
		_selection_portraits[id] = load(selection_portrait_path(id))
	return _selection_portraits[id] as Texture2D

static func ids() -> Array[int]:
	var result: Array[int] = []
	for index in CLASS_IDS.size():
		result.append(FIRST_ID + index)
	return result

static func is_rogue(id: int) -> bool:
	return id >= FIRST_ID and id < FIRST_ID + CLASS_IDS.size()

static func class_id(id: int) -> String:
	if is_crossgate_fighter(id):return CROSSGATE[id].id
	if WARCRAFT.has(id):return WARCRAFT[id].id
	if id==KOJIRO_ID:return "kojiro"
	if is_enemy(id):return ENEMIES[id].id
	if id==SONIC_ID:return "sonic"
	if id==MASTER_CHIEF_ID:return "master-chief"
	if id==YAE_ID:return "yae"
	if id==SASUKE_ID:return "sasuke"
	if id==MUSASHI_ID:return "musashi"
	if id==ED_ID:return "ed"
	if id==BEN_ID:return "ben"
	return CLASS_IDS[id - FIRST_ID] if is_rogue(id) else ""

static func hero_id(native_id: String) -> int:
	var index = CLASS_IDS.find(native_id)
	return FIRST_ID + index if index >= 0 else -1

static func data(id: Variant) -> Dictionary:
	if id is int and is_crossgate_fighter(id):return CROSSGATE[id].duplicate()
	if id is String:
		for fighter in CROSSGATE.values():
			if id==fighter.id:return fighter.duplicate()
	if id is int and WARCRAFT.has(id):return WARCRAFT[id].duplicate()
	if (id is int and id==KOJIRO_ID) or (id is String and id=="kojiro"):return {"id":"kojiro","name":"Kojiro","color":"#d999e6","description":"Musashi’s rival. Original sword and aerial cuts, homing shots, sword wave and four-part wind attack."}
	if id is int and is_enemy(id):return ENEMIES[id].duplicate()
	if _classes.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Array:
			for entry in parsed:
				_classes[str(entry.id)] = entry
	var native_id = class_id(int(id)) if id is int else str(id)
	return _classes.get(native_id, {}).duplicate(true)

static func name_for(id: int) -> String:
	if is_crossgate_fighter(id):return CROSSGATE[id].name
	if WARCRAFT.has(id):return WARCRAFT[id].name
	if id==KOJIRO_ID:return "Kojiro"
	if is_enemy(id):return ENEMIES[id].name
	if id==SONIC_ID:return "Sonic"
	if id==MASTER_CHIEF_ID:return "Master Chief"
	if id==YAE_ID:return "Yae"
	if id==SASUKE_ID:return "Sasuke"
	if id==MUSASHI_ID:return "Musashi"
	if id==ED_ID:return "Ed"
	if id==BEN_ID:return "Ben"
	return str(data(id).get("name", "Unknown"))

static func model_path(id: int) -> String:
	return GameAssets.model_path("res://assets/models/characters/goemon_cosplay/%s.glb" % class_id(id))

static func portrait_path(id: int) -> String:
	return "res://assets/models/characters/goemon_cosplay/portraits/%s.png" % class_id(id)

static func portrait(id: int) -> Texture2D:
	if is_crossgate_fighter(id):
		return selection_portrait(id)
	if WARCRAFT.has(id):
		if not _portraits.has(id):_portraits[id]=load("res://assets/characters/warcraft/%s/hud_portrait.png"%class_id(id))
		return _portraits[id] as Texture2D
	if id==KOJIRO_ID:
		if not _portraits.has(id):_portraits[id]=load("res://assets/characters/recovered_kojiro/hud_portrait.png")
		return _portraits[id] as Texture2D
	if is_enemy(id):return selection_portrait(id)
	if id==SONIC_ID:
		if not _portraits.has(id):_portraits[id]=load("res://assets/characters/recovered_sonic/hud_portrait.png")
		return _portraits[id] as Texture2D
	if id==MASTER_CHIEF_ID:
		if not _portraits.has(id):_portraits[id]=load("res://assets/characters/master_chief/hud_portrait.png")
		return _portraits[id] as Texture2D
	if id==YAE_ID:
		if not _portraits.has(id):_portraits[id]=load("res://assets/characters/recovered_yae/hud_portrait.png")
		return _portraits[id] as Texture2D
	if id==SASUKE_ID:
		if not _portraits.has(id):_portraits[id]=load("res://assets/characters/recovered_sasuke/hud_portrait.png")
		return _portraits[id] as Texture2D
	if id in [MUSASHI_ID,ED_ID,BEN_ID,SASUKE_ID]:return selection_portrait(id)
	if not is_rogue(id):
		return null
	if not _portraits.has(id):
		_portraits[id] = load(portrait_path(id))
	return _portraits[id] as Texture2D

static func icon_path(key: String) -> String:
	var path = "res://assets/rogue/icons/%s.svg" % key
	return path if ResourceLoader.exists(path) else "res://assets/rogue/icons/sword.svg"
