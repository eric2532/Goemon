@static_unload
extends RefCounted
## Original appearances and encounter membership; the existing patrol/native owners simulate them.
const ROOT="res://assets/characters/crossgate/shalena/"
const Data=preload("res://assets/maps/falan/tina/encounters.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const BODY=AABB(Vector3(-.9,0,-.75),Vector3(1.8,3.42,1.5))
const TREE_BODY=AABB(Vector3(-1.35,0,-1.05),Vector3(2.7,5.32,2.1))
const STATS={"hp":3000.0,"speed":4.2,"damage":30.0,"range":3.4,"stride":1.75}
const FOOTPRINT=.85
const TREE_FOOTPRINT=1.18
const LEASH=14.0
static var manifest:Dictionary={}
static var sounds:Dictionary={}
static func owns(floor_:int)->bool:return Maps.source_id(floor_) in [400,402,4201]
static func tree(skin:int)->bool:return skin in [7,8]
static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest
static func timelines()->PackedFloat32Array:
 var result=PackedFloat32Array(motions().timelines)
 for i in range(Data.SPECIES.size(),29):result.append_array(result.slice(0,8*32))
 return result
static func make_mesh()->QuadMesh:
 if sounds.is_empty():
  for cue in motions().sounds:
   var path:String=motions().sounds[cue];sounds[cue]=load(path if path.begins_with("res://") else ROOT+path)
 return preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,motions(),1.0,1.0)

static func zone_at(floor_:int,cell:Vector2i)->int:
 var source=Maps.source_id(floor_);var best=-1;var area=INF
 for id in Data.ZONES:
  var zone:Array=Data.ZONES[id]
  if zone[0]!=source or not zone[1].has_point(cell):continue
  var size_:int=zone[1].size.x*zone[1].size.y
  if size_<area or size_==area and id>best:best=id;area=size_
 return best

static func refill(values:Array,rng:RandomNumberGenerator)->Array:
 var bag=values.duplicate()
 for i in range(bag.size()-1,0,-1):
  var other=rng.randi_range(0,i);var value=bag[i];bag[i]=bag[other];bag[other]=value
 return bag

static func posts(floor_:int,seed_:int)->Array:
 var row=Maps.state(floor_,seed_);var crop=Maps.crop(floor_);var candidates=[]
 var gates=Maps.links(floor_,seed_).map(func(link):return link.at)
 var step=6 if floor_==4201 else 10
 for y in range(3,row.size.y-3,step):
  for x in range(3,row.size.x-3,step):
   var cell=Vector2i(x,y);var zone=zone_at(floor_,cell+crop.position)
   if zone<0:continue
   if not [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return Maps.open(row.bits,row.size,cell+d)):continue
   var point=Maps.point(floor_,cell,seed_)
   if gates.any(func(at):return point.distance_squared_to(at)<81):continue
   candidates.append([point,zone])
 var result=[];var bags={};var levels={};var rng=RandomNumberGenerator.new();rng.seed=seed_+floor_*7919
 var count_=mini(64 if floor_==4201 else 192,candidates.size())
 for i in count_:
  var candidate:Array=candidates[i*candidates.size()/count_];var zone:int=candidate[1]
  if not bags.has(zone) or bags[zone].is_empty():
   var tickets=[]
   for choice in Data.ZONES[zone][2].size():
    for ticket in Data.ZONES[zone][2][choice][3]:tickets.append(choice)
   bags[zone]=refill(tickets,rng)
  var choice:int=bags[zone].pop_back();var member:Array=Data.ZONES[zone][2][choice]
  var token=Vector2i(zone,choice)
  if not levels.has(token) or levels[token].is_empty():levels[token]=refill(range(member[1],member[2]+1),rng)
  result.append([Vector4i(candidate[0].x,candidate[0].y,member[0],zone),levels[token].pop_back()])
 return result
