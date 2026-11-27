extends RefCounted
## Regional random floors share the existing room graph, native terrain and travel owners.
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
static var SPECS:Dictionary=preload("res://assets/maps/falan/university_region/dungeon_specs.gd").SPECS.merged(preload("res://assets/maps/falan/east_region/dungeon_specs.gd").SPECS).merged(preload("res://assets/maps/falan/sokia/cape/dungeon_specs.gd").SPECS).merged(preload("res://assets/maps/falan/explore-dungeon-specs.gd").SPECS)

static var counts={}
static var sizes={}
static var entries={}
static var native_runs={}
static var box_allocations={}
static var east_seed:Variant=null
static var sokia_masks:Dictionary={}

static func prepare_east_seed(seed_:int):
 if east_seed==seed_:return
 east_seed=seed_
 box_allocations.clear()
 for cache in [counts,sizes,entries]:
  for token in cache.keys():
   if token is Vector2i and token.x>=2000000:cache.erase(token)

static func native_mountain(id:int)->bool:return branch(id)=="mountain"

static func template(id:int,seed_:int)->Dictionary:
 if not native_runs.has(seed_):
  native_runs.clear();var originals:Array=Winter.Recovered.Art.data().university_mountain_templates
  var rng=Winter.Maze.rng_for(SPECS.mountain.first,seed_);var run=[]
  while run.size()<int(SPECS.mountain.maximum):run.append_array(Winter.Maze.shuffled(originals,rng))
  native_runs[seed_]=run
 return native_runs[seed_][number(id)-1]

static func branch(id:int)->String:
 if id in [51009,51010]:return "mountain"
 for key in SPECS:
  var spec:Dictionary=SPECS[key]
  if id>=spec.first+(2 if key=="mountain" else 0) and id<spec.first+spec.maximum:return key
 return ""

static func owns(id:int)->bool:return not branch(id).is_empty()
static func legacy(id:int)->bool:return id in [51009,51010]
static func number(id:int)->int:return id-51008 if legacy(id) else id-SPECS[branch(id)].first+1
static func floor_id(key:String,n:int)->int:return 51008+n if key=="mountain" and n<=2 else int(SPECS[key].first)+n-1
static func encounter_levels(id:int,_seed_:int)->Array:
 var spec:Dictionary=SPECS[branch(id)]
 if not spec.get("sokia",false) or spec.get("source_levels_exact_interval",false):return spec.levels
 # Recovered CDungeonReader reference curve; original server generation remains unverified.
 var level=int(spec.levels[0])+floori(float(number(id)*(int(spec.levels[1])-int(spec.levels[0])))/int(spec.maximum))
 return [level,level]

static func box_count(id:int,seed_:int)->int:
 var key=branch(id);var spec:Dictionary=SPECS[key]
 if spec.get("box_amount_scope","")!="whole_branch_reference_generator":return int(spec.box_amount)
 prepare_east_seed(seed_)
 var token=Vector2i(spec.first,seed_)
 if not box_allocations.has(token):
  var candidates=[]
  for n in range(1,count(key,seed_)+1):
   var floor_:int=floor_id(key,n);var row:Dictionary=Winter.Recovered.state(floor_,seed_)
   for y in row.size.y:
    for x in row.size.x:
     var cell=Vector2i(x,y)
     if Winter.Recovered.open(row.bits,row.size,cell) and row.doors.all(func(door):return cell.distance_squared_to(door)>=4):candidates.append(floor_)
  allocate_boxes(token,candidates,int(spec.box_amount),Winter.Maze.rng_for(int(spec.first)+54,seed_))
 return int(box_allocations[token].get(id,0))

static func allocate_boxes(token:Vector2i,candidates:Array,amount:int,rng:RandomNumberGenerator):
 # Shared setup-only allocation: one ticket per eligible cell, drawn without replacement.
 assert(candidates.size()>=amount,"Source chest allocation needs enough unique adapted open cells")
 var selected=Winter.Maze.shuffled(candidates,rng);var allocation={}
 for i in amount:allocation[selected[i]]=int(allocation.get(selected[i],0))+1
 box_allocations[token]=allocation

static func entry_cell(key:String,seed_:int)->Vector2i:
 var spec:Dictionary=SPECS[key]
 if spec.get("east",false):prepare_east_seed(seed_)
 if key!="tunnel" and not spec.get("east",false):return Vector2i(spec.entry[1],spec.entry[2])
 var token:Variant=Vector2i(spec.first,seed_) if spec.get("east",false) else seed_
 if entries.has(token):return entries[token]
 if spec.entry[0]==100:return Vector2i(spec.entry[1],spec.entry[2])
 if spec.entry[0]==300:
  var bounds:Array=spec.entry_rect;var candidates=[]
  for y in range(int(bounds[1]),int(bounds[3])+1):
   for x in range(int(bounds[0]),int(bounds[2])+1):
    var cell=Vector2i(x,y)
    if sokia_open(cell) and [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP].any(func(step):return sokia_open(cell+step)):candidates.append(cell)
  assert(not candidates.is_empty(),"Source Desert Temple rectangle needs a walkable field entrance")
  entries[token]=Winter.Maze.shuffled(candidates,Winter.Maze.rng_for(spec.first,seed_))[0]
  return entries[token]
 var original=Winter.Recovered;var id:int=original.runtime_id(spec.entry[0]);var row=original.state(id,seed_)
 var bounds:Array=spec.entry_rect;var candidates=[]
 for y in range(mini(int(bounds[1]),int(bounds[3])),maxi(int(bounds[1]),int(bounds[3]))+1):
  for x in range(mini(int(bounds[0]),int(bounds[2])),maxi(int(bounds[0]),int(bounds[2]))+1):
   var cell=Vector2i(x,y)-original.crop(id).position
   if original.open(row.bits,row.size,cell) and [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP].any(func(step):return original.open(row.bits,row.size,cell+step)):candidates.append(Vector2i(x,y))
 assert(not candidates.is_empty(),"The original random tunnel rectangle needs recorded approach ground")
 entries[token]=Winter.Maze.shuffled(candidates,Winter.Maze.rng_for(spec.first,seed_))[0]
 return entries[token]

static func set_entry_cell(key:String,seed_:int,cell:Vector2i):
 prepare_east_seed(seed_)
 entries[Vector2i(SPECS[key].first,seed_)]=cell

static func entry_return_cell(key:String,seed_:int)->Vector2i:
 var spec:Dictionary=SPECS[key];var cell=entry_cell(key,seed_)
 if int(spec.entry[0])==100:return cell+Vector2i.DOWN
 if int(spec.entry[0])==300:
  for step in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
   if sokia_open(cell+step):return cell+step
  assert(false,"Sokia dungeon entrance needs an adjacent dry return cell")
 var original=Winter.Recovered;var id:int=original.runtime_id(spec.entry[0]);var row=original.state(id,seed_)
 for step in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
  if original.open(row.bits,row.size,cell+step-original.crop(id).position):return cell+step
 assert(false,"The original dungeon entrance needs a recorded adjacent return cell")
 return cell

static func sokia_open(cell:Vector2i)->bool:
 var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 for area in ["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]:
  if not sokia_masks.has(area):
   var terrain=load("res://scripts/forest/forest_freyja_terrain.gd").new();terrain.variant=area
   sokia_masks[area]={"image":terrain.mask_image(),"origin":terrain.mask_origin()}
  var row:Dictionary=sokia_masks[area];var at:Vector2=regions.frame(area).inverse()*(Vector2(cell)*3.)
  var pixel=Vector2i(((at-row.origin)/3.).round())
  if not Rect2i(Vector2i.ZERO,row.image.get_size()).has_point(pixel):continue
  var color:Color=row.image.get_pixelv(pixel)
  if color.a>=.5 and color.r<.5 and color.b<.98 and not regions.Sokia.Data.BLOCKS[area].any(func(rect):return rect.has_point(cell)):return true
 return false

static func count(key:String,seed_:int)->int:
 if SPECS[key].get("range_bags",SPECS[key].get("east",false)):prepare_east_seed(seed_)
 var token=Vector2i(SPECS[key].first,seed_)
 if not counts.has(token):
  var spec:Dictionary=SPECS[key]
  counts[token]=Winter.Maze.shuffled(range(spec.minimum,spec.maximum+1),Winter.Maze.rng_for(spec.first,seed_))[0]
 return counts[token]

static func dimensions(id:int,seed_:int)->Vector2i:
 if native_mountain(id):return Vector2i(template(id,seed_).size[0],template(id,seed_).size[1])
 if SPECS[branch(id)].get("range_bags",SPECS[branch(id)].get("east",false)):prepare_east_seed(seed_)
 var token=Vector2i(id,seed_)
 if sizes.has(token):return sizes[token]
 var spec:Dictionary=SPECS[branch(id)];var rng=Winter.Maze.rng_for(id,seed_)
 if spec.get("range_bags",spec.get("east",false)):
  var width_bag=[];var height_bag=[]
  rng=Winter.Maze.rng_for(spec.first,seed_)
  for n in int(spec.maximum):
   if width_bag.is_empty():width_bag=Winter.Maze.shuffled(range(spec.size[0],spec.size[1]+1),rng)
   if height_bag.is_empty():height_bag=Winter.Maze.shuffled(range(spec.size[2],spec.size[3]+1),rng)
   sizes[Vector2i(spec.first+n,seed_)]=Vector2i(width_bag.pop_back(),height_bag.pop_back())
  return sizes[token]
 var size_=Vector2i(Winter.Maze.shuffled(range(spec.size[0],spec.size[1]+1),rng)[0],Winter.Maze.shuffled(range(spec.size[2],spec.size[3]+1),rng)[0])
 sizes[token]=size_
 return size_

static func doors(id:int,seed_:int)->Array:
 if native_mountain(id):
  var native:Dictionary=template(id,seed_)
  return [Vector2i(native.up[0],native.up[1]),Vector2i(native.down[0],native.down[1])]
 var size_=dimensions(id,seed_)
 return [Vector2i(3,size_.y-4),Vector2i(size_.x-4,3)]

static func stair_serials(id:int,seed_:int)->Array:
 var key=branch(id);var spec:Dictionary=SPECS[key];var result:Array=spec.stairs.duplicate()
 if spec.get("range_bags",spec.get("east",false)):
  if number(id)==1:result[0]=spec.source_entrance_graphics[0]
  if number(id)==count(key,seed_):result[1]=spec.source_entrance_graphics[1]
 return result

static func make(id:int,seed_:int)->Dictionary:
 var spec:Dictionary=SPECS[branch(id)];var size_=dimensions(id,seed_);var gates=doors(id,seed_)
 if native_mountain(id):
  var native:Dictionary=template(id,seed_);var art=Winter.Recovered.Art;var original:Dictionary=art.data().maps[native.path]
  return {"seed":seed_,"raw":art.raw_map(native.path),"bits":Marshalls.base64_to_raw(original.walk).decompress((size_.x*size_.y+7)>>3,FileAccess.COMPRESSION_DEFLATE),"size":size_,"origin":-Vector2(size_/2)*3.,"rocks":[],"doors":gates,"frozen":true,"branch":"mountain","native_template":true,"native_path":native.path,"source_sha256":native.sha256}
 var maze=Winter.grid_maze(id,seed_,size_,gates,Winter.SNOW_PATROLS)
 var cells=size_.x*size_.y;var raw=PackedByteArray();raw.resize(20+cells*6)
 raw[0]=77;raw[1]=65;raw[2]=80;raw[3]=1;raw.encode_u32(12,size_.x);raw.encode_u32(16,size_.y)
 var rng=Winter.Maze.rng_for(id,seed_);var ground_bag=[];var tree_bag=[]
 var mountain=branch(id)=="mountain";var scientist=branch(id)=="scientist"
 var outdoors:bool=spec.get("outdoor",false);var forest_choices=[]
 if outdoors:
  for decoration in spec.source_decorations:
   if decoration[0] not in range(10050,10100) and decoration[0] not in range(11600,11631) and decoration[0] not in range(15067,15082) and decoration[0] not in range(15012,15021):continue
   for weight in maxi(0,int(decoration[1])):forest_choices.append(decoration[0])
 var ground_choices=load("res://scripts/forest/forest_original_snow.gd").GROUND if mountain else [spec.ground]
 for z in size_.y:
  for x in size_.x:
   var cell=Vector2i(x,z);var index=z*size_.x+x
   var opened=Winter.Recovered.open(maze.bits,size_,cell);var tree=0
   if mountain and not opened and [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].any(func(step):return Winter.Recovered.open(maze.bits,size_,cell+step)):
    if tree_bag.is_empty():tree_bag=Winter.Maze.shuffled([0,0,0,11622,11623,11624],rng)
    tree=tree_bag.pop_back()
   if scientist and not opened and [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].any(func(step):return Winter.Recovered.open(maze.bits,size_,cell+step)):tree=17088
   if outdoors and not forest_choices.is_empty() and not opened and [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].any(func(step):return Winter.Recovered.open(maze.bits,size_,cell+step)):
    if tree_bag.is_empty():tree_bag=Winter.Maze.shuffled(forest_choices,rng)
    tree=tree_bag.pop_back()
   if opened or tree!=0 or outdoors:
    if ground_bag.is_empty():ground_bag=Winter.Maze.shuffled(ground_choices,rng)
    raw.encode_u16(20+index*2,ground_bag.pop_back())
   raw.encode_u16(20+(cells+index)*2,tree);raw.encode_u16(20+(2*cells+index)*2,0xc000)
 var source_stairs=stair_serials(id,seed_)
 for i in 2:
  # Animated actor 103012 belongs to the travel marker, not the 16-bit static layer.
  raw.encode_u16(20+(cells+gates[i].y*size_.x+gates[i].x)*2,source_stairs[i] if source_stairs[i]<65536 else 0)
 return {"seed":seed_,"raw":raw,"bits":maze.bits,"size":size_,"origin":-Vector2(size_/2)*3.0,"rocks":maze.rocks,"doors":gates,"frozen":spec.frozen,"branch":branch(id),"source_stairs":source_stairs,"blocked_end":spec.get("blocked_end","")}

static func landing(id:int,seed_:int,entry:bool)->Vector2:
 var original=Winter.Recovered;var gates=doors(id,seed_)
 return original.interior_stair_landing(id,gates[0 if entry else 1],gates[1 if entry else 0],seed_)

static func links(id:int,seed_:int)->Array:
 var original=Winter.Recovered;var key=branch(id);var spec:Dictionary=SPECS[key];var n=number(id)
 var previous=original.runtime_id(spec.entry[0]) if n==1 else floor_id(key,n-1)
 var at_end=n==count(key,seed_);var gates=doors(id,seed_)
 var source_stairs=stair_serials(id,seed_)
 var back_link:Dictionary
 if n==1:
  if spec.entry[0] in [100,300]:
   back_link={"at":original.point(id,gates[0],seed_),"to":"east_source","east_source_return":{"map":int(spec.entry[0]),"cell":entry_return_cell(key,seed_)},"caption":"索奇亞" if spec.entry[0]==300 else "芙蕾雅","door":true,"walk_in":true}
  else:
   var approach=entry_return_cell(key,seed_)-original.crop(previous).position
   var safe=original.safe_cell(previous,approach,seed_)
   assert(Vector2(safe-approach).length()<=2.1,"Dungeon return must remain beside its source entrance")
   back_link=original.door(original.point(id,gates[0],seed_),previous,original.point(previous,safe,seed_))
 else:back_link=original.door(original.point(id,gates[0],seed_),previous,landing(previous,seed_,false))
 back_link.diamond=source_stairs[0]==103012
 if at_end and spec.end.is_empty():return [back_link]
 var next=original.runtime_id(spec.end[0]) if at_end else floor_id(key,n+1)
 var ahead=original.source_point(next,Vector2i(spec.end[1],spec.end[2])) if at_end else landing(next,seed_,true)
 var forward:Dictionary=original.door(original.point(id,gates[1],seed_),next,ahead)
 forward.diamond=source_stairs[1]==103012
 if key=="tunnel" and n==count(key,seed_):forward["region_battle"]="dijiro"
 return [back_link,forward]
