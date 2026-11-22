@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/undersea/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const SLAIN="undersea_slain"
const BOSS_NAME="熊哥 · 熱砂的歐茲尼克"
const QIGONG=711
const MEDITATION=712
const HAZE=713
const EVADE=714
const BOSS_HP=48000.0
const SOKIA=15003
const BOSS_AT=Vector2(24,12)
const ESCORTS=[
 [Vector2(15,12),1],[Vector2(33,12),1],[Vector2(18,21),2],[Vector2(36,6),2],
]
const PATROLS={
 15004:preload("res://assets/maps/falan/map_encounter_data.gd").UNDERSEA_POSTS[15004],
 15005:preload("res://assets/maps/falan/map_encounter_data.gd").UNDERSEA_POSTS[15005],
 15592:preload("res://assets/maps/falan/map_encounter_data.gd").UNDERSEA_POSTS[15592],
 15594:preload("res://assets/maps/falan/map_encounter_data.gd").UNDERSEA_POSTS[15594],
 SOKIA:[
  [Vector2(-72,75),1],[Vector2(57,-78),2],[Vector2(72,66),1],[Vector2(-60,-48),2],
  [Vector2(-3,30),1],[Vector2(63,-6),2],[Vector2(6,-39),1],[Vector2(-63,15),2],
  [Vector2(-24,72),1],[Vector2(39,39),2],[Vector2(-24,-63),1],[Vector2(45,-42),2],
  [Vector2(12,66),1],[Vector2(-51,48),2],[Vector2(15,-72),1],[Vector2(-30,6),2],
  [Vector2(3,-6),1],[Vector2(69,27),2],[Vector2(-39,-24),1],[Vector2(-81,42),2],
  [Vector2(33,-15),1],[Vector2(42,66),2],[Vector2(69,-54),1],[Vector2(-51,-72),2],
  [Vector2(-18,-36),1],[Vector2(-48,72),2],[Vector2(-9,54),1],[Vector2(72,-27),2],
  [Vector2(-42,27),1],[Vector2(39,-63),2],[Vector2(-51,-6),1],[Vector2(-3,-60),2],
  [Vector2(-9,9),1],[Vector2(9,45),2],[Vector2(27,54),1],[Vector2(51,-24),2],
  [Vector2(-30,54),1],[Vector2(-42,-45),2],[Vector2(-69,57),1],[Vector2(30,-33),2],
 ],
 15593:[
  [Vector2(-141,-33),1],[Vector2(141,27),2],[Vector2(6,-30),1],[Vector2(-60,12),2],
  [Vector2(78,-12),1],[Vector2(27,27),2],[Vector2(-117,24),1],[Vector2(-75,-36),2],
  [Vector2(-24,33),1],[Vector2(-27,-9),2],[Vector2(105,15),1],[Vector2(42,-6),2],
  [Vector2(-87,-6),1],[Vector2(6,3),2],[Vector2(-132,-3),1],[Vector2(135,0),2],
  [Vector2(-60,-15),1],[Vector2(-93,18),2],[Vector2(54,-27),1],[Vector2(-36,12),2],
  [Vector2(99,-6),1],[Vector2(-15,-27),2],[Vector2(120,30),1],[Vector2(42,15),2],
  [Vector2(15,-15),1],[Vector2(-117,6),2],[Vector2(-87,-24),1],[Vector2(-48,24),2],
  [Vector2(60,-12),1],[Vector2(-21,6),2],[Vector2(12,18),1],[Vector2(-138,-18),2],
  [Vector2(69,0),1],[Vector2(-72,-21),2],[Vector2(-66,-3),1],[Vector2(-6,-36),2],
  [Vector2(-84,9),1],[Vector2(-102,27),2],[Vector2(45,-18),1],[Vector2(90,-15),2],
  [Vector2(-15,-12),1],[Vector2(108,3),2],[Vector2(-129,9),1],[Vector2(-24,18),2],
  [Vector2(-36,27),1],[Vector2(-48,12),2],[Vector2(-66,-30),1],[Vector2(-129,-24),2],
 ],
}
const BODY=AABB(Vector3(-.92,0,-.74),Vector3(1.84,3.22,1.48))
const BOSS_BODY=AABB(Vector3(-1.12,0,-.87),Vector3(2.24,4.2,1.74))
const STATS={"hp":120.0,"speed":3.85,"damage":12.0,"range":3.25,"stride":1.75}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var source=PackedFloat32Array(motions().timelines)
 var lizard=source.slice(16*28)
 for i in range(motions().variants.size(),Roles.SLIME_COLORS):source.append_array(lizard)
 return source

static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 var data=motions()
 for id in data.sounds:
  var path:String=data.sounds[id]
  sounds[id]=load(path if path.begins_with("res://") else ROOT+path)
 mesh=Sprites.make_mesh(ROOT,data,1.0,1.0)
 return mesh
