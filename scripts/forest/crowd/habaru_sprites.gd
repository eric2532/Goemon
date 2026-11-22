@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/habaru/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROOM=11004
const VENOA_SLAIN="venoa_bears_slain"
const VENOA_BOSS_NAME="Venoa Great Bear"
const GREEN_SLIME=2
const VENOA_BOSS_SKIN=3
const VENOA_BEAR_SKIN=4
const SLIME_SLAIN="habaru_slimes_slain"
const SLIME_CELLS={
 11003:[Vector2i(7,41),Vector2i(11,43),Vector2i(14,41),Vector2i(19,41),Vector2i(23,40),
  Vector2i(25,36),Vector2i(27,30),Vector2i(31,28),Vector2i(36,26),Vector2i(39,20),
  Vector2i(42,20),Vector2i(35,14),Vector2i(32,11),Vector2i(42,11)],
 11005:[Vector2i(21,43),Vector2i(22,45),Vector2i(17,40),Vector2i(21,36),Vector2i(24,33),
  Vector2i(26,29),Vector2i(23,25),Vector2i(27,21),Vector2i(21,17),Vector2i(16,13),
  Vector2i(22,12),Vector2i(28,7),Vector2i(34,7),Vector2i(38,9)],
}
const VENOA_BOSS_BODY=AABB(Vector3(-1.37,0,-1.15),Vector3(2.74,4.2,2.30))
const BODY=AABB(Vector3(-1.10,0,-.92),Vector3(2.20,3.35,1.84))
const CHAMBER_BODY=AABB(Vector3(-2.20,0,-1.84),Vector3(4.40,6.70,3.68))
const SLIME_BODY=AABB(Vector3(-1.13,0,-.94),Vector3(2.26,2.30,1.88))
const BOSS_NAME="熊弟 · 殺熊者歐茲那克"
const BOSS_HP=30000.0
const BOSS_DAMAGE=200.0
const ESCORT_HP=10000.0
const ESCORT_DAMAGE=87.0
const DOUBLE_EDGE=710
const BRACE=715
const COUNTER=716
const RESET=717
const STATS={"hp":105.0,"speed":3.8,"damage":12.0,"range":2.85,"stride":1.7}

static var manifest:Dictionary={}
static var sounds:Dictionary={}

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var source=PackedFloat32Array(motions().timelines)
 var bear=source.slice(8*28,16*28)
 for i in range(motions().variants.size(),Roles.SLIME_COLORS):source.append_array(bear)
 return source

static func make_mesh()->QuadMesh:
 var data=motions()
 if sounds.is_empty():
  for id in data.sounds:
   var path:String=data.sounds[id]
   sounds[id]=load(path if path.begins_with("res://") else ROOT+path)
 return Sprites.make_mesh(ROOT,data,1.0,1.0)
