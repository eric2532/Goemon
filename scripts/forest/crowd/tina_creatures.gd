@static_unload
extends RefCounted
## Data binding only; native combat and the shared hound atlas renderer own these four source appearances.
const ROOT="res://assets/characters/crossgate/tina_flowers/"
const BODY=AABB(Vector3(-1,0,-1),Vector3(2,3.8,2))
const STATS={"hp":3000.0,"speed":3.5,"damage":30.0,"range":3.4,"stride":1.75}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh
static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest
static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 var stride=int(motions().get("timeline_stride",28))
 for i in range(5,29):result.append_array(result.slice(0,8*stride))
 return result
static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 for cue in motions().sounds:
  var stream=load("res://"+motions().sounds[cue].goemon_file)
  for skin in 29:sounds["%d:%s"%[skin,cue]]=stream
 mesh=preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.0,1.0)
 return mesh
