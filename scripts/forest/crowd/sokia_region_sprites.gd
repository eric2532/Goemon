@static_unload
extends RefCounted
## Native mountain and Water Cave appearances use the existing sprite and army owners.
const ROOT="res://assets/characters/crossgate/sokia_region/"
const Base=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
const BODY=Base.BODY
const TREE_BODY=Base.TREE_BODY
const STATS=Base.STATS
const FOOTPRINT=Base.FOOTPRINT
const TREE_FOOTPRINT=Base.TREE_FOOTPRINT
const NAMES=["大地鼠","火焰鼠","土蜘蛛","火蜘蛛","地龍蜥","火龍蜥","紅蠍","血魔","謎之箱","守護者","最終決戰型牛鬼","巨狼","鬼靈","牛鬼公主","帝國兵的亡靈","帝國兵的亡靈","杰特","梅兹"]
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static func tree(_skin:int)->bool:return false
static func motions()->Dictionary:
 if manifest.is_empty():
  manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
  assert(manifest.variants.size()==NAMES.size(),"Missing native mountain appearances")
 return manifest
static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 for i in range(NAMES.size(),29):result.append_array(result.slice(0,int(motions().get("timeline_stride",32))*8))
 return result
static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:sounds[cue]=load(motions().sounds[cue] if motions().sounds[cue].begins_with("res://") else ROOT+motions().sounds[cue])
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.,1.)
