@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/pirate_cave/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROOM=16503
const MEMORIAL=16504
const SLAIN="captain_slain"
const BODY=AABB(Vector3(-.95,0,-.78),Vector3(1.9,3.45,1.56))
const STATS={"hp":105.0,"speed":3.8,"damage":11.0,"range":2.85,"stride":1.75}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var source=PackedFloat32Array(motions().timelines)
 var pirate=source.slice(16*28)
 for i in range(motions().variants.size(),Roles.SLIME_COLORS):source.append_array(pirate)
 return source

static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 var data=motions()
 for id in data.sounds:
  var path:String=data.sounds[id]
  sounds[id]=load(path if path.begins_with("res://") else ROOT+path)
 mesh=Sprites.make_mesh(ROOT,data,1.0,1.0)
 return mesh
