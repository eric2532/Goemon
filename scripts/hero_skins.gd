class_name HeroSkins
extends RefCounted

const DEFAULT_ID="original"
const CATALOG=[
	{"id":"original","name":"Goemon","subtitle":"The original adventurer","description":"Starburst hair, bold brows and the classic red-and-gold outfit.","asset":"characters/kai","display_scale":1.0},
	{"id":"ren","name":"Ren · Storm Rival","subtitle":"Chibi anime rival","description":"A cocky grin, swept cobalt hair and a white headband.","asset":"characters/ren_rival","display_scale":1.0},
]
const PARTS=["Skin","Hair_Normal","Hair_Gold"]
static var resources: Dictionary={}

static func valid_id(value: Variant)->String:
	for entry in CATALOG:
		if value==entry.id:return entry.id
	return DEFAULT_ID

static func mesh_parts(id: String)->Dictionary:
	id=valid_id(id)
	if not resources.has(id):
		var entry=CATALOG[1 if id=="ren" else 0]
		var source=GameAssets.instantiate_model(entry.asset)
		var parts={}
		for part in PARTS:
			var mesh=source.find_child(part,true,false) as MeshInstance3D
			assert(mesh!=null,"Skin is missing "+part)
			var geometry=mesh.mesh
			parts[part]={"mesh":geometry,"skin":mesh.skin}
		resources[id]=parts
		source.free()
	return resources[id]
