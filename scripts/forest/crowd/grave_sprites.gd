@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/forest_grave/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROOM=47017
const ENTRY=47010
const SLAIN="grave_slain"
const EARTH_WARNING=704
const EARTH_IMPACT=705
const MAGIC_SEAL=706
const BODY=AABB(Vector3(-.94,0,-.78),Vector3(1.88,3.8,1.56))
const FINAL_BODY=AABB(Vector3(-1.20,0,-.93),Vector3(2.4,4.35,1.86))
const STATS={"hp":105.0,"speed":3.8,"damage":11.0,"range":2.85,"stride":1.75}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var data=motions()
 var source=PackedFloat32Array(data.timelines)
 var fallback=source.slice(0,8*28)
 for i in range(data.variants.size(),Roles.SLIME_COLORS):source.append_array(fallback)
 return source

static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 var data=motions()
 for cue in data.sounds:
  var path:String=data.sounds[cue]
  sounds[cue]=load(path if path.begins_with("res://") else ROOT+path)
 mesh=Sprites.make_mesh(ROOT,data,1.0,1.0)
 return mesh
