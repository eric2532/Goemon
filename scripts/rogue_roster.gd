extends RefCounted
## Stable Sonic IDs for the ten authored Rogue classes. Combat data stays native.

const FIRST_ID = 3
const CLASS_IDS = ["pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
const DATA_PATH = "res://assets/rogue/data/classes.json"
static var _classes: Dictionary = {}
static var _portraits: Dictionary = {}

static func ids() -> Array[int]:
	var result: Array[int] = []
	for index in CLASS_IDS.size():
		result.append(FIRST_ID + index)
	return result

static func is_rogue(id: int) -> bool:
	return id >= FIRST_ID and id < FIRST_ID + CLASS_IDS.size()

static func class_id(id: int) -> String:
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
	return str(data(id).get("name", "Unknown"))

static func model_path(id: int) -> String:
	return "res://assets/models/characters/goemon_cosplay/%s.glb" % class_id(id)

static func portrait_path(id: int) -> String:
	return "res://assets/models/characters/goemon_cosplay/portraits/%s.png" % class_id(id)

static func portrait(id: int) -> Texture2D:
	if not is_rogue(id):
		return null
	if not _portraits.has(id):
		_portraits[id] = load(portrait_path(id))
	return _portraits[id] as Texture2D

static func icon_path(key: String) -> String:
	var path = "res://assets/rogue/icons/%s.svg" % key
	return path if ResourceLoader.exists(path) else "res://assets/rogue/icons/sword.svg"
