@static_unload
extends RefCounted
## Existing bear bank plus the recovered native crab, using the shared army renderer.
const ROOT="res://assets/characters/crossgate/venoa_route/"
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const BODY=Habaru.BODY
const CHAMBER_BODY=Habaru.CHAMBER_BODY
const SLIME_BODY=Habaru.SLIME_BODY
const VENOA_BOSS_BODY=Habaru.VENOA_BOSS_BODY
const STATS=Habaru.STATS
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest
static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 for i in range(motions().variants.size(),29):result.append_array(result.slice(4*8*32,5*8*32))
 return result
static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:
   var path:String=motions().sounds[cue];sounds[cue]=load(path if path.begins_with("res://") else ROOT+path)
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.,1.)
