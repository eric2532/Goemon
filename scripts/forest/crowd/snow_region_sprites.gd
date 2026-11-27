@static_unload
extends RefCounted
## Data adapter for the existing native army renderer and combat clock.
const ROOT="res://assets/characters/crossgate/snow_region/"
const BODY=AABB(Vector3(-.9,0,-.75),Vector3(1.8,3.42,1.5))
const TREE_BODY=AABB(Vector3(-1.35,0,-1.05),Vector3(2.7,5.32,2.1))
const STATS=preload("res://scripts/forest/crowd/shalena_sprites.gd").STATS
const LEASH=preload("res://scripts/forest/crowd/shalena_sprites.gd").LEASH
const FOOTPRINT=.85
const TREE_FOOTPRINT=1.18
static var manifest:Dictionary={}
static var population:Dictionary={}
static var sounds:Dictionary={}
static var road_rows:Dictionary={}
static var zone_rows:Dictionary={}
static func data()->Dictionary:
 if population.is_empty():
  population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/snow_region/population.json"))
  for span in population.road_scope:road_rows[int(span[0])]=Vector2i(span[1],span[2])
  for zone in population.zones:
   var source=int(zone.map)
   if not zone_rows.has(source):zone_rows[source]=[]
   zone_rows[source].append(zone)
 return population
static func owns(floor_:int)->bool:return floor_ in [51031,51032,14000,14001,14002,15522]
static func in_scope(floor_:int,cell:Vector2i)->bool:
 if floor_!=51031:return owns(floor_)
 data()
 return road_rows.has(cell.y) and cell.x>=road_rows[cell.y].x and cell.x<=road_rows[cell.y].y
static func tree(skin:int)->bool:return skin in [7,8]
static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest
static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 var stride=32*8
 for i in range(data().species.size(),29):result.append_array(result.slice(0,stride))
 return result
static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:sounds[cue]=load(motions().sounds[cue] if motions().sounds[cue].begins_with("res://") else ROOT+motions().sounds[cue])
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.,1.)
static func zone_at(floor_:int,cell:Vector2i)->Dictionary:
 var source=preload("res://scripts/forest/forest_original_maps.gd").source_id(floor_)
 var result={}
 data()
 for zone in zone_rows.get(source,[]):
  var b:Array=zone.bounds
  if cell.x<b[0] or cell.x>b[2] or cell.y<b[1] or cell.y>b[3]:continue
  if result.is_empty() or int(zone.priority)>int(result.priority) or int(zone.priority)==int(result.priority) and int(zone.id)>int(result.id):result=zone
 return result
static func draw(bags:Dictionary,key,values:Array,rng:RandomNumberGenerator):
 if bags.get(key,[]).is_empty():bags[key]=preload("res://scripts/forest/crowd/shalena_sprites.gd").refill(values,rng)
 return bags[key].pop_back()
static func weighted(bags:Dictionary,key,values:Array,rng:RandomNumberGenerator):
 var tickets=[]
 for row in values:
  for i in int(row[1]):tickets.append(row[0])
 return draw(bags,key,tickets,rng)
static func group(zone:Dictionary,bags:Dictionary,rng:RandomNumberGenerator)->Array:
 var id=weighted(bags,"group:%s"%zone.id,zone.groups,rng)
 var source:Dictionary=data().groups[id];var members=[]
 if source.has("fixed"):return source.fixed.duplicate(true)
 for i in source.members.size():members.append([i,source.members[i][3]])
 # shortcut: uniform counts within the source maximum; replace when original count weights are verified.
 var count_=int(draw(bags,"count:%s"%zone.id,range(1,int(zone.maximum)+1),rng))
 var result=[]
 for i in count_:
  var member:Array=source.members[weighted(bags,"member:"+id,members,rng)]
  var level=int(draw(bags,"level:%s:%d"%[id,member[0]],range(int(member[1]),int(member[2])+1),rng))
  result.append([int(member[0]),level])
 return result
