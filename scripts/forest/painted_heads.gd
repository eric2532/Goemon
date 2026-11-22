extends RefCounted
const Roster=preload("res://scripts/rogue_roster.gd")
const ROOT="res://assets/ui/portraits/crossgate/"
static var routes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"model-heads.json"))
static var textures:Dictionary={}

static func portrait(character:int,settings:Dictionary)->Texture2D:
	var path:String=routes.get(Roster.loadout_key(character,settings),"")
	if path.is_empty():return null
	if not textures.has(path):textures[path]=load(ROOT+path)
	return textures[path]
