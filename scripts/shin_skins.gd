extends RefCounted

const ROOT="res://assets/characters/crossgate/shin/"
const DEFAULT=100050
const SPECIAL_DEFAULT=106707
const HIDDEN_CLASSIC=[100053,100055]
static var regular:Dictionary={}
static var special:Dictionary={}
static var special_gallery:Dictionary={}

static func catalog(weapon:bool)->Dictionary:
	if regular.is_empty():
		var entries:Array=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"skins.json"))
		for entry in entries:
			var group=special if entry[3] else regular
			group[int(entry[0])]=[entry[1],Vector2(entry[2][0],entry[2][1])]
		regular.merge(preload("res://scripts/crossgate_special_skins.gd").CATALOG.get(37,{}))
		special.merge(preload("res://scripts/crossgate_special_skins.gd").CAST_CATALOG.get(38,{}))
	return special if weapon else regular

static func gallery(weapon:bool)->Dictionary:
	if not weapon:return catalog(false)
	if special_gallery.is_empty():
		special_gallery=catalog(true).duplicate()
		for id in HIDDEN_CLASSIC:special_gallery.erase(id)
	return special_gallery

static func valid_id(weapon:bool,value:Variant)->int:
	return int(value) if value is int and catalog(weapon).has(value) else (SPECIAL_DEFAULT if weapon else DEFAULT)

static func setting(weapon:bool)->String:
	return "shin_special_skin" if weapon else "shin_skin"

static func root(id:int)->String:
	return ROOT+"%d/"%id

static func portrait(id:int)->Texture2D:
	return load(root(id)+"portrait.png")
