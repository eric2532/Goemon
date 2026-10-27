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
const WARCRAFT={31:{"id":"blademaster","name":"Blademaster","color":"#a2bf70","description":"LMB Sword combo · RMB Critical strike · 1 Bladestorm · 2 Wind Walk · 3 Mirror Image · Space Jump · C Evade. Equip shared skills with Q."},32:{"id":"demon-hunter","name":"Illidan","color":"#b195dc","description":"LMB Glaive combo / Demon bolt · RMB / 1 Metamorphosis · 2 Immolation · Space Jump · C Evade. Meta form: hold Space to fly, release to descend; Shift boosts. Equip shared skills with Q."}}
const PLAYABLE_IDS = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32]
## Hide unused fighters in menus without changing stable gameplay/save IDs.
const HIDDEN_SELECTION_IDS = [2,3,4,6,12,20,21,22,23,24,25,26] # Unused heroes and small enemies; bosses remain selectable.
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
static func is_enemy(id:int)->bool:return ENEMIES.has(id)

const DATA_PATH = "res://assets/rogue/data/classes.json"
static var _classes: Dictionary = {}
static var _portraits: Dictionary = {}
static var _selection_portraits: Dictionary = {}

static func selection_ids() -> Array[int]:
	var result: Array[int] = []
	for id in PLAYABLE_IDS:
		if id not in HIDDEN_SELECTION_IDS:result.append(id)
	return result

## Selection art has its own full-body framing. HUD portraits retain the stable
## face position used by the circular crop in forest_hud_portrait.gdshader.
static func selection_portrait_path(id: int) -> String:
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
