extends RefCounted
## Stable Sonic IDs for the ten authored Rogue classes. Combat data stays native.

const FIRST_ID = 3
const MUSASHI_ID = 13
const ED_ID = 14
const BEN_ID = 15
const SASUKE_ID = 16
const YAE_ID = 17
const MASTER_CHIEF_ID = 18
const PLAYABLE_IDS = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18]
## Hide unused fighters in menus without changing stable gameplay/save IDs.
const HIDDEN_SELECTION_IDS = [2,3,4,6,12] # Edo, Pirate, Samurai, Mage, Master Thief.
const MUSASHI_PORTRAIT = "res://assets/characters/recovered_musashi/portrait.png"
const CLASS_IDS = ["pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
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

static func supports_gate_defender(id:int)->bool:
	return id in PLAYABLE_IDS and id not in [4,MASTER_CHIEF_ID]

static func class_id(id: int) -> String:
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
	if _classes.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Array:
			for entry in parsed:
				_classes[str(entry.id)] = entry
	var native_id = class_id(int(id)) if id is int else str(id)
	return _classes.get(native_id, {}).duplicate(true)

static func name_for(id: int) -> String:
	if id==MASTER_CHIEF_ID:return "Master Chief"
	if id==YAE_ID:return "Yae"
	if id==SASUKE_ID:return "Sasuke"
	if id==MUSASHI_ID:return "Musashi"
	if id==ED_ID:return "Ed"
	if id==BEN_ID:return "Ben"
	return str(data(id).get("name", "Unknown"))

static func model_path(id: int) -> String:
	return "res://assets/models/characters/goemon_cosplay/%s.glb" % class_id(id)

static func portrait_path(id: int) -> String:
	return "res://assets/models/characters/goemon_cosplay/portraits/%s.png" % class_id(id)

static func portrait(id: int) -> Texture2D:
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
