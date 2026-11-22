@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/black_prayer/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROOM=16508
const SLAIN="ruby_boss_slain"
const MEND=707
const FROST=708
const FROST_IMPACT=709
const HEAL=750
const RECOVER=751
const GROUP_RECOVER=752
const HOLY_SHIELD=753
const PHYSICAL_ABSORB=754
const MAGIC_ABSORB=755
const PHYSICAL_REFLECT=756
const MAGIC_REFLECT=757
const PHYSICAL_NULL=758
const MAGIC_NULL=759
const METEOR=760
const METEOR_IMPACT=761
const CONFUSION=762
const CONFUSED=763
const PHYSICAL_RETURN=764
const MAGIC_RETURN=765
const WARD_BLOCK=766
const RECOVER_TICK=767
const WARD_ACTIVE=768
const HEAL_EFFECT=769
const SPELL_NAMES={MEND:"強力補血魔法",HEAL:"補血魔法",RECOVER:"恢復魔法",GROUP_RECOVER:"強力恢復魔法",
 HOLY_SHIELD:"聖盾",PHYSICAL_ABSORB:"攻擊吸收",MAGIC_ABSORB:"魔法吸收",PHYSICAL_REFLECT:"攻擊反彈",
 MAGIC_REFLECT:"魔法反彈",PHYSICAL_NULL:"攻擊無效",MAGIC_NULL:"魔法無效",METEOR:"超強隕石魔法",
 FROST:"超強冰凍魔法",CONFUSION:"超強混亂魔法"}
static func spell_action(action:int)->bool:return SPELL_NAMES.has(action)
static func magic_attack(action:int)->bool:return action in [FROST,METEOR,CONFUSION,MAGIC_RETURN]

const KAZ_HEIGHT=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
const BODY=AABB(Vector3(-.92,0,-.84),Vector3(1.84,KAZ_HEIGHT+.6,1.68))
const ESCORT_BODY=AABB(Vector3(-.90,0,-.82),Vector3(1.80,KAZ_HEIGHT+.3,1.64))
const STATS={"hp":105.0,"speed":3.6,"damage":10.0,"range":4.3,"stride":1.65}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh
static var spell_art:Dictionary={}
static var spell_textures:Dictionary={}
static var spell_sounds:Dictionary={}

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

static func prepare_spells():
 if not spell_art.is_empty():return
 spell_art=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"spells/manifest.json"))
 for ref in spell_art.clips:spell_textures[ref]=load(spell_art.clips[ref].runtime_path)
 for cue in spell_art.sounds:spell_sounds[cue]=load(spell_art.sounds[cue].runtime_path)
