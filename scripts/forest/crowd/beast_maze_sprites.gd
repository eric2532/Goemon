@static_unload
extends RefCounted
## The missing original bomb joins the existing cave sprite batch; other appearances are shared pets.
const ROOT="res://assets/characters/crossgate/beast_maze/"
const KEYS=["original:2906"]
const BODY=AABB(Vector3(-.6,0,-.5),Vector3(1.2,1.9,1.0))
const STATS={"hp":3000.0,"speed":4.5,"damage":60.0,"range":3.4,"stride":1.75}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var mesh:QuadMesh

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 for i in range(KEYS.size(),29):result.append_array(result.slice(0,8*28))
 return result

static func make_mesh()->QuadMesh:
 if mesh!=null:return mesh
 for cue in motions().sounds:
  var path:String=motions().sounds[cue]
  sounds[cue]=load(path if path.begins_with("res://") else ROOT+path)
 mesh=preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.0,1.0)
 return mesh
