@static_unload
extends RefCounted

const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROOT="res://assets/characters/crossgate/slimes/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
# The tallest recovered hurt frame reaches above the slime's combat box.
const HURT_HEAD_HEIGHT=8.23*Roles.MAP_ENEMY_SCALE
static var manifest:Dictionary={}
static var sounds:Dictionary={}

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func make_mesh()->QuadMesh:
 var data=motions()
 if sounds.is_empty():
  for id in data.sounds:sounds[int(id)]=load("res://"+data.sounds[id].goemon_file)
 return Sprites.make_mesh(ROOT,data,Roles.SLIME_SCALE,1.0)
