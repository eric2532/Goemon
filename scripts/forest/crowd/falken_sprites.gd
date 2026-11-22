@static_unload
extends RefCounted
const ROOT="res://assets/characters/crossgate/falken/"
const Route=preload("res://scripts/forest/forest_falken_route.gd")
const ROOM=Route.ROOM
const SLAIN=Route.SLAIN
const BODY=AABB(Vector3(-.92,0,-.84),Vector3(1.84,3.8,1.68))
const STATS={"hp":105.0,"speed":3.6,"damage":10.0,"range":4.3,"stride":1.65}
const PROFILES=[["法爾肯",50,1200,true],["骷髏戰士",35,450,false],["蜥蜴鬥士",35,450,false]]
const DRAIN=770
const DEATH=771
const SUMMON=772
const DRAIN_EFFECT=773
const DEATH_EFFECT=774
const SUMMON_EFFECT=775
const SPELL_NAMES={770:"吸血魔法",771:"即死魔法E1",772:"召喚",752:"強力恢復魔法",753:"聖盾",756:"攻擊反彈",757:"魔法反彈"}
static func spell_action(action:int)->bool:return SPELL_NAMES.has(action)
static func magic_attack(action:int)->bool:return action in [DRAIN,DEATH]
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh
static var spell_art:Dictionary={}
static var spell_textures={}
static var spell_sounds={}
static func prepare_spells():
 if not spell_art.is_empty():return
 spell_art=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"spells/manifest.json"))
 for ref in spell_art.clips:spell_textures[ref]=load(spell_art.clips[ref].runtime_path)
 for cue in spell_art.sounds:spell_sounds[cue]=load(spell_art.sounds[cue].runtime_path)
static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest
static func timelines()->PackedFloat32Array:
 var data=motions();var source=PackedFloat32Array(data.timelines)
 for i in range(data.variants.size(),29):source.append_array(source.slice(0,8*28))
 return source
static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 for cue in motions().sounds:
  var path:String=motions().sounds[cue]
  sounds[cue]=load(path if path.begins_with("res://") else ROOT+path)
 mesh=preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.0,1.0)
 return mesh
