@static_unload
extends RefCounted

const ROOT="res://assets/characters/crossgate/falan_encounters/"
const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const BODY=AABB(Vector3(-.9,0,-.75),Vector3(1.8,3.42,1.5))
const TREE_BODY=AABB(Vector3(-1.35,0,-1.05),Vector3(2.7,5.32,2.1))
const STATS={"hp":3000.0,"speed":4.2,"damage":30.0,"range":3.4,"stride":1.75}
const FOOTPRINT=.85
const TREE_FOOTPRINT=1.18
const LEASH=14.0
const BAT=0
const GOBLIN=1
const BANDIT=2
const BEE=3
const TREE=4
const Data=preload("res://assets/maps/falan/map_encounter_data.gd")
const NAMES=Data.NAMES
const LEVELS=[1,2,4,3,5,3,15,15,20,20,20,10,10,16,20,20,8,10,10,19,19,16,17,20,3,17,17,8,17]
const HEALTH=[300.0,500.0,1200.0,800.0,2000.0]
const DAMAGE=[30.0,30.0,35.0,35.0,40.0]
const AREA_LEVELS={"west_lakes":2,"east_coast":2,"north_coast":4,"south_lakes":4}
static var manifest:Dictionary={}
static var sounds:Dictionary={}

static func tree(skin:int)->bool:return skin in [TREE,16]

static func area_levels(area:String,post:Vector4i)->int:
 # The joined East Gate map contains both starter and outer-coast posts.
 if area=="east_gate" and post.w>=1021 and post.w<=1027:return AREA_LEVELS.east_coast
 return AREA_LEVELS.get(area,0)

static func progression(skin:int,extra_levels:int)->Dictionary:
 var level:int=LEVELS[skin]+extra_levels
 return {"level":level,"hp":roundf((HEALTH[skin] if skin<HEALTH.size() else STATS.hp)*(1.0+.2*extra_levels)),
  "damage":roundf((DAMAGE[skin] if skin<DAMAGE.size() else STATS.damage)*(1.0+.1*extra_levels)),"xp_reward_tenths":Roles.level_xp_tenths(level)}

static func motions()->Dictionary:
 if manifest.is_empty():
  manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
  assert(manifest.variants.size()==NAMES.size() and NAMES.size()==Roles.SLIME_COLORS)
 return manifest

static func timelines()->PackedFloat32Array:return PackedFloat32Array(motions().timelines)

static func make_mesh()->QuadMesh:
 var data=motions()
 if sounds.is_empty():
  for id in data.sounds:
   var path:String=data.sounds[id]
   sounds[id]=load(path if path.begins_with("res://") else ROOT+path)
 return Sprites.make_mesh(ROOT,data,1.0,1.0)
