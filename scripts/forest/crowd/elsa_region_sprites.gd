@static_unload
extends RefCounted
## Source data for the existing Explore encounter owner and native sprite renderer.
const ROOT="res://assets/characters/crossgate/elsa_region/"
const Snow=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
const BODY=Snow.BODY
const TREE_BODY=Snow.TREE_BODY
const STATS=Snow.STATS
const FOOTPRINT=Snow.FOOTPRINT
const TREE_FOOTPRINT=Snow.TREE_FOOTPRINT
static var population:Dictionary={}
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static var zone_rows:Dictionary={}

static func data()->Dictionary:
 if population.is_empty():
  population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/population.json"))
  for zone in population.zones:
   var id=int(zone.map)
   if not zone_rows.has(id):zone_rows[id]=[]
   zone_rows[id].append(zone)
 return population

static func owns(id:int)->bool:
 if id<59500 or id>=59800:return false
 data()
 return zone_rows.has(id) or data().battles.any(func(battle):return int(battle.map)==id)

static func tree(_skin:int)->bool:return false

static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest

static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 for i in range(data().species.size(),29):result.append_array(result.slice(0,32*8))
 return result

static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:sounds[cue]=load(motions().sounds[cue] if motions().sounds[cue].begins_with("res://") else ROOT+motions().sounds[cue])
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.,1.)

static func zone_at(id:int,cell:Vector2i)->Dictionary:
 data()
 var result={}
 for zone in zone_rows.get(id,[]):
  var b:Array=zone.bounds
  if cell.x<b[0] or cell.y<b[1] or cell.x>b[2] or cell.y>b[3]:continue
  if result.is_empty() or int(zone.priority)>int(result.priority) or int(zone.priority)==int(result.priority) and int(zone.id)>int(result.id):result=zone
 return result

static func group(zone:Dictionary,bags:Dictionary,rng:RandomNumberGenerator)->Array:
 if zone.groups.is_empty() or int(zone.maximum)<=0:return []
 var id=Snow.weighted(bags,"elsa-group:%s"%zone.id,zone.groups,rng)
 var record:Dictionary=data().groups[id];var choices=[]
 for i in record.members.size():choices.append([i,record.members[i][3]])
 # shortcut: retain the existing Explore count adaptation until the source count-column semantics are verified.
 var count_=int(Snow.draw(bags,"elsa-count:%s"%zone.id,range(1,int(zone.maximum)+1),rng))
 var result=[]
 for i in count_:
  var member:Array=record.members[Snow.weighted(bags,"elsa-member:"+id,choices,rng)]
  var level=int(Snow.draw(bags,"elsa-level:%s:%s"%[id,member[0]],range(int(member[1]),int(member[2])+1),rng))
  result.append([int(member[0]),level])
 return result
