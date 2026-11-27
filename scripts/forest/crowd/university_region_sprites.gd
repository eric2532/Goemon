@static_unload
extends RefCounted
## Source encounter data for the shared native Explore owner; no separate simulation.
const ROOT="res://assets/characters/crossgate/university_region/"
const Snow=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
const BODY=Snow.BODY
const STATS=Snow.STATS
const FOOTPRINT=Snow.FOOTPRINT
const TREE_FOOTPRINT=Snow.TREE_FOOTPRINT
const BOSS_ROOMS=[4409,16520,4501,20527,20530,20414,15535,15539,59752]
static var population:Dictionary={}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var zone_rows:Dictionary={}

static func data()->Dictionary:
 if population.is_empty():
  population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_region/encounters.json"))
  for zone in population.zones:
   var id=int(zone.map)
   if not zone_rows.has(id):zone_rows[id]=[]
   zone_rows[id].append(zone)
 return population

static func owns(id:int)->bool:
 data()
 var source:int=load("res://scripts/forest/forest_original_maps.gd").source_id(id)
 if source in BOSS_ROOMS or zone_rows.has(source):return true
 var generated=load("res://scripts/forest/forest_original_maps.gd").generated()
 return generated.owns(id) and not generated.SPECS[generated.branch(id)].get("sokia",false)

static func tree(_skin:int)->bool:return false

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 for i in range(motions().variants.size(),29):result.append_array(result.slice(0,32*8))
 return result

static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:sounds[cue]=load(motions().sounds[cue] if motions().sounds[cue].begins_with("res://") else ROOT+motions().sounds[cue])
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.,1.)

static func zone_at(id:int,cell:Vector2i)->Dictionary:
 data()
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 var key:String=maps.generated().branch(id)
 if not key.is_empty():
  var zone:Dictionary=data().generated[key].duplicate()
  zone.id=id;zone.levels=maps.generated().SPECS[key].levels
  return zone
 var result={}
 for zone in zone_rows.get(maps.source_id(id),[]):
  var b:Array=zone.bounds
  if cell.x<b[0] or cell.y<b[1] or cell.x>b[2] or cell.y>b[3]:continue
  if result.is_empty() or int(zone.priority)>int(result.priority) or int(zone.priority)==int(result.priority) and int(zone.id)>int(result.id):result=zone
 return result

static func group(zone:Dictionary,bags:Dictionary,rng:RandomNumberGenerator)->Array:
 if zone.groups.is_empty() or int(zone.maximum)<=0:return []
 var id=Snow.weighted(bags,"university-group:%s"%zone.id,zone.groups,rng)
 var source:Dictionary=data().groups[id];var choices=[]
 for i in source.members.size():choices.append([i,source.members[i][3]])
 var count_=int(Snow.draw(bags,"university-count:%s"%zone.id,range(1,int(zone.maximum)+1),rng))
 var result=[]
 for i in count_:
  var member:Array=source.members[Snow.weighted(bags,"university-member:"+id,choices,rng)]
  var span:Array=zone.get("levels",[member[1],member[2]])
  var level=int(Snow.draw(bags,"university-level:%s:%s"%[zone.id,member[0]],range(int(span[0]),int(span[1])+1),rng))
  result.append([int(member[0]),level])
 return result

static func companion(index:int)->bool:return data().species[index].bank=="companion"

static func radius(index:int)->float:
 var species:Dictionary=data().species[index]
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 var box:AABB=dimensions.companion_body(int(species.skin)) if companion(index) else dimensions.body(load("res://scripts/forest/crowd/university_region_sprites.gd"),int(species.skin))
 return minf(box.size.x,box.size.z)*.5*preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE
