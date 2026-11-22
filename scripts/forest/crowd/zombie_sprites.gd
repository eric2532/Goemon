@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/zombie_cave/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROLE=Roles.SLIME
const FINAL=15505
const BOSS_NAME="Modified Zombie"
const HELLHOUND=3
const DRAIN=700
const CHARGE=701
const HEAL=702
const BLAST=703
const BODY=AABB(Vector3(-.90,0,-.75),Vector3(1.80,3.45,1.50))
const STATS={"hp":105.0,"speed":3.1,"damage":11.0,"range":2.85,"stride":1.55}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var source=PackedFloat32Array(motions().timelines)
 var zombie=source.slice(8*28,16*28)
 for i in range(motions().variants.size(),Roles.SLIME_COLORS):source.append_array(zombie)
 return source

static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 var data=motions()
 for id in data.sounds:
  var path:String=data.sounds[id]
  sounds[id]=load(path if path.begins_with("res://") else ROOT+path)
 mesh=Sprites.make_mesh(ROOT,data,1.0,1.0)
 return mesh
