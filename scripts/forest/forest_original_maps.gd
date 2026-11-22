extends RefCounted
## Recovered geography belongs to the existing Falan exploration route.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Solids=preload("res://scripts/forest/forest_art.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Beast=preload("res://scripts/forest/forest_beast_maps.gd")
const SHALENA_SOUTH=51031
const SHALENA_NORTH=51032
const ALIASES={51001:15000,51002:15001,51003:15002,51004:4000,51005:4200,51006:4020,51007:4212,51008:402,
 51011:4300,51012:4400,51013:4313,51014:4410,51016:4411,51017:4400,
 51015:402,51018:4310,51019:4418,51020:4400,51021:4320,51022:4331,51023:4333,51024:402,
 SHALENA_SOUTH:400,SHALENA_NORTH:402}
const REVERSE={15000:51001,15001:51002,15002:51003,4000:51004,4200:51005,
 4020:51006,4212:51007,4300:51011,4400:51012,4313:51013,4410:51014,4411:51016,4310:51018,4418:51019,
 4320:51021,4331:51022,4333:51023,400:SHALENA_SOUTH,402:SHALENA_NORTH}
const OUTDOORS=[400,402,4000,4200,4201,4300,4400,15522,32181]
const GUARD_CELLS=preload("res://assets/maps/original_crossgate/maze_encounters.gd").SEALS
const NEXT_LANDINGS=[Vector2i(24,26),Vector2i(27,2),Vector2i(16,19),Vector2i(24,23),Vector2i(23,4)]
static var states:Dictionary={}

static func floor_number(id:int)->int:
 if id>=51025 and id<=51030:return (id-51024)*10
 var n=id-51100
 return n if n>0 and n<60 and n%10!=0 else 0

static func floor_id(n:int)->int:return 51024+n/10 if n%10==0 else 51100+n

static func source_id(id:int)->int:
 var n=floor_number(id)
 return 24008+n if n>0 else ALIASES.get(id,id)

static func path_for(id:int,seed_:int=0)->String:
 return Beast.template(id,seed_).path if Beast.owns(id) else "BlueCrossgate/map/0/%d.dat"%source_id(id)

static func owns(id:int)->bool:
 if id in [51009,51010] or Beast.owns(id):return true
 return (ALIASES.has(id) or id<700000) and Art.data().maps.has(path_for(id))

static func outdoor(id:int)->bool:return source_id(id) in OUTDOORS or id in [51009,51010]
static func cave(id:int)->bool:return owns(id) and not outdoor(id)

static func title(id:int)->String:
 if id==SHALENA_SOUTH:return "莎蓮娜 · 傑諾瓦與蒂娜道路"
 if id in [SHALENA_NORTH,51024]:return "莎蓮娜 · 阿巴尼斯雪原"
 if id in [51009,51010]:return "積雪的山路 · %dF"%(1 if id==51009 else 2)
 if Beast.owns(id):return "貝茲雷姆的迷宮 · %dF"%(id-Beast.FIRST+1)
 return Art.data().maps[path_for(id)].title

static func crop(id:int,seed_:int=0)->Rect2i:
 if id in [51009,51010]:return Rect2i(0,0,33,27)
 if source_id(id)==400:return Rect2i(110,240,510,240)
 if source_id(id)==402:return Rect2i(35,70,250,140)
 var row:Dictionary=Art.data().maps[path_for(id,seed_)]
 return Rect2i(Vector2i.ZERO,Vector2i(row.size[0],row.size[1]))

static func state(id:int,seed_:int=0)->Dictionary:
 var key=Vector2i(id,seed_ if id in [51009,51010] or Beast.owns(id) else 0)
 if states.has(key):return states[key]
 if Beast.owns(id):
  for stored:Vector2i in states.keys():
   if Beast.owns(stored.x) and stored.y!=seed_:states.erase(stored)
 if id in [51009,51010]:
  var snow=load("res://scripts/forest/forest_original_snow.gd").make(id,seed_)
  return snow
 var source=Art.raw_map(path_for(id,seed_));var full_width=source.decode_u32(12);var full_cells=full_width*source.decode_u32(16)
 var cut=crop(id,seed_);var size_=cut.size;var cells=size_.x*size_.y
 var raw=PackedByteArray();raw.resize(20+cells*6)
 for i in 20:raw[i]=source[i]
 raw.encode_u32(12,size_.x);raw.encode_u32(16,size_.y)
 var original=Art.data().maps[path_for(id,seed_)]
 var bits_full=Marshalls.base64_to_raw(original.walk).decompress((full_cells+7)>>3,FileAccess.COMPRESSION_DEFLATE)
 var bits=PackedByteArray();bits.resize((cells+7)>>3)
 for z in size_.y:
  for x in size_.x:
   var i=z*size_.x+x;var j=(z+cut.position.y)*full_width+x+cut.position.x
   for plane in 3:raw.encode_u16(20+(plane*cells+i)*2,source.decode_u16(20+(plane*full_cells+j)*2))
   if bits_full[j>>3]&(1<<(j&7)):bits[i>>3]|=1<<(i&7)
 var result={"size":size_,"origin":-Vector2(size_/2)*3.0,"raw":raw,"bits":bits,"seed":seed_}
 states[key]=result
 return result

static func floor_info(id:int,seed_:int=0)->Array:
 var row=state(id,seed_)
 return [row.size,row.origin,row.bits.hex_encode()]

static func layout(id:int)->Dictionary:
 return {"format":"forest_shrine_map","schema":1,"title":title(id),"falan_area":"interior","falan_floor":id,"buildings":[],"trees":[],"deposits":[]}

static func point(id:int,cell:Vector2i,seed_:int=0)->Vector2:
 var origin=Vector2(-48,-39) if id in [51009,51010] else state(id,seed_).origin
 return origin+Vector2(cell)*3.0
static func source_point(id:int,cell:Vector2i)->Vector2:return point(id,cell-crop(id).position)

static func open(bits:PackedByteArray,size_:Vector2i,cell:Vector2i)->bool:
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 var i=cell.y*size_.x+cell.x
 return (bits[i>>3]&(1<<(i&7)))!=0

static func safe_cell(id:int,preferred:Vector2i,seed_:int=0)->Vector2i:
 var row=state(id,seed_);var best=Vector2i.ZERO;var distance=INF
 for z in row.size.y:
  for x in row.size.x:
   var c=Vector2i(x,z)
   if not open(row.bits,row.size,c):continue
   var d=Vector2(c-preferred).length_squared()
   if d<distance:best=c;distance=d
 return best

static func patrols(id:int,seed_:int,count_:int)->Array:
 var row=state(id,seed_);var candidates=[]
 for z in range(2,row.size.y-2):
  for x in range(2,row.size.x-2):
   var c=Vector2i(x,z)
   if [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return open(row.bits,row.size,c+d)):
    candidates.append(c)
 var result=[]
 for i in mini(count_,candidates.size()):result.append(candidates[(i*candidates.size()+candidates.size()/2)/count_])
 return result

static func runtime_id(source:int)->int:
 if source>=24009 and source<=24068:return floor_id(source-24008)
 return REVERSE.get(source,source)

static func door(at:Vector2,target:int,arrival:Vector2,caption:String="")->Dictionary:
 return {"at":at,"to":"freyja_door","floor":target,"arrival":arrival,"caption":title(target) if caption.is_empty() else caption,"door":true}

static func links(id:int,seed_:int=0)->Array:
 var src=source_id(id);var result=[]
 for values in Art.data().warps:
  if id in [51009,51010] or int(values[0])!=src:continue
  if src==400 and int(values[3])==4300:continue
  var target=runtime_id(int(values[3]))
  if floor_number(id)==1 and target==24008:continue
  if not owns(target):continue
  var a=Vector2i(values[1],values[2]);var b=Vector2i(values[4],values[5])
  if not crop(id).has_point(a) or not crop(target).has_point(b):continue
  var arrival=source_point(target,b);var destination=state(target,seed_)
  var cell=b-crop(target).position
  if not open(destination.bits,destination.size,cell):
   var safe=safe_cell(target,cell,seed_)
   if Vector2(safe-cell).length()<=2.1:arrival=point(target,safe,seed_)
  result.append(door(source_point(id,a),target,arrival).merged({"source_arrival":source_point(target,b)}))
 if src in [400,4200,4201]:
  for values in Art.data().warps:
   if int(values[3])!=src or int(values[0]) not in [400,4200,4201,4206]:continue
   if Art.data().warps.any(func(w):return int(w[0])==src and int(w[1])==int(values[4]) and int(w[2])==int(values[5])):continue
   var a=Vector2i(values[4],values[5]);var b=Vector2i(values[1],values[2])
   if not crop(id).has_point(a):continue
   var target=runtime_id(int(values[0]))
   if not owns(target):continue
   var landing=safe_cell(target,b-crop(target).position)
   result.append(door(source_point(id,a),target,point(target,landing)))
 if id==51001:
  result.append({"at":source_point(id,Vector2i(22,33)),"to":"freyja_outside","area":"west_lakes","arrival":Vector2(33,-45),"caption":"芙蕾雅 · 法蘭西門","door":true})
 if id==16510:
  result.append(door(source_point(id,Vector2i(25,7)),Beast.FIRST,stair_landing(Beast.FIRST,seed_,true),"貝茲雷姆的迷宮"))
 if Beast.owns(id):
  var previous=16510 if id==Beast.FIRST else id-1
  var next=16511 if id==Beast.FIRST+Beast.COUNT-1 else id+1
  var back=source_point(16510,Vector2i(25,8)) if previous==16510 else stair_landing(previous,seed_,false)
  var ahead=source_point(16511,Vector2i(26,72)) if next==16511 else stair_landing(next,seed_,true)
  result=[door(point(id,Beast.stair(id,seed_,true),seed_),previous,back),door(point(id,Beast.stair(id,seed_,false),seed_),next,ahead)]
 if id==16511:
  result.append(door(source_point(id,Vector2i(26,72)),Beast.FIRST+Beast.COUNT-1,stair_landing(Beast.FIRST+Beast.COUNT-1,seed_,false)))
  # Quest dialogue is deferred; retain the event's exact transfer across the sealed vestibule.
  result.append(door(source_point(id,Vector2i(26,67)),id,source_point(id,Vector2i(26,65)),"神官葛雷森 · 通往靜謐之間"))
  result.append(door(source_point(id,Beast.BOSS_CELL),16512,source_point(16512,Vector2i(26,26)),"神獸的封印").merged({"beast_guardian":true}))
 if id==16512:
  result.append(door(source_point(id,Vector2i(13,52)),16514,source_point(16514,Vector2i(12,17)),"守衛 · 僧侶的房間"))
  result.append(door(source_point(id,Vector2i(40,52)),16515,source_point(16515,Vector2i(10,17)),"小愛 · 巫師的房間"))
 if id==16515:
  result.append(door(source_point(id,Vector2i(13,9)),16512,source_point(16512,Vector2i(39,52)),"巫師吉娜 · 離開房間"))
 if id==16513:
  # The stone occupies an isolated pedestal; interact from its original aisle.
  result.append(door(source_point(id,Vector2i(14,8)),SHALENA_SOUTH,source_point(SHALENA_SOUTH,Vector2i(136,336)),"魔法傳送石 · 返回莎蓮娜").merged({"source_gate":source_point(id,Vector2i(14,6))}))
 if src==402:
  result.append(door(source_point(id,Vector2i(84,193)),51009,point(51009,Vector2i(15,21),seed_),"積雪的山路"))
  result.append(door(source_point(id,Vector2i(54,162)),floor_id(1),source_point(floor_id(1),Vector2i(3,13)),"鼓動的石盤 · 詛咒迷宮").merged({"decree_needs_blade":true}))
 if id in [51009,51010]:
  var lower=point(id,Vector2i(15,23),seed_);var upper=point(id,Vector2i(25,2),seed_)
  if id==51009:
   result=[door(lower,SHALENA_NORTH,source_point(SHALENA_NORTH,Vector2i(84,194))),door(upper,51010,point(51010,Vector2i(25,4),seed_))]
  else:
   result=[door(upper,51009,point(51009,Vector2i(25,4),seed_)),door(lower,15522,source_point(15522,Vector2i(41,40))) ]
 if id==15522:result.append(door(source_point(id,Vector2i(41,40)),51010,point(51010,Vector2i(15,21),seed_)))
 if id==51021:
  result.append(door(source_point(id,Vector2i(9,4)),51022,source_point(51022,Vector2i(7,4)),"民家地下 · 時空石盤"))
 if id==51022:
  result.append(door(source_point(id,Vector2i(7,3)),51021,source_point(51021,Vector2i(9,5))))
  result.append(door(source_point(id,Vector2i(15,7)),51023,source_point(51023,Vector2i(15,8)),"連接時空的石盤"))
 if id==51023:
  result=[door(source_point(id,Vector2i(9,4)),51022,source_point(51022,Vector2i(15,8))),
   {"at":source_point(id,Vector2i(15,7)),"to":"decree_blade","caption":"取下刀刃的碎片","door":true}]
 var number=floor_number(id)
 if number>0 and number%10==0:
  var index=number/10-1
  var boss=source_point(id,GUARD_CELLS[index])
  var target=51011 if number==60 else floor_id(number+1)
  var arrival=source_point(target,Vector2i(37,70)) if number==60 else source_point(target,NEXT_LANDINGS[index])
  result.append(door(boss,target,arrival,"封印石 · 返回阿巴尼斯" if number==60 else "聖詔 · 下一層").merged({"decree_guardians":true}))
 if number==1:result.append(door(source_point(id,Vector2i(3,13)),SHALENA_NORTH,source_point(SHALENA_NORTH,Vector2i(55,162))))
 var accessible=[]
 for link in result:
  var cell=Vector2i(((link.at-state(id,seed_).origin)/3.0).round())
  if not open(state(id,seed_).bits,state(id,seed_).size,cell):
   var safe=safe_cell(id,cell,seed_)
   if Vector2(safe-cell).length()>2.1:continue
   link.source_gate=link.at
   link.at=point(id,safe,seed_)
  accessible.append(link)
 return accessible

static func stair_landing(id:int,seed_:int,up:bool)->Vector2:
 var row=state(id,seed_);var cell=Beast.stair(id,seed_,up)
 for direction in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
  if open(row.bits,row.size,cell+direction):return point(id,cell+direction,seed_)
 assert(false,"Source stair requires an open landing")
 return point(id,cell,seed_)

static func porch_floors(placements:Array,raw:PackedByteArray,size_:Vector2i)->Array:
 # shortcut: Fill only missing bay-house ground visually until original floor cells are recovered.
 var fills=[];var covered={};var cells=size_.x*size_.y
 for placement in placements:
  if placement[4]<cells or placement[3] not in [11407,11408]:continue
  var g:Dictionary=Art.data().graphics[str(placement[3])]
  for z in int(g.footprint[1]):
   for x in int(g.footprint[0]):
    var cell:Vector2i=placement[5]+Vector2i(x,-z)
    if cell.x<0 or cell.y<0 or cell.x>=size_.x or cell.y>=size_.y or covered.has(cell):continue
    var index=cell.y*size_.x+cell.x
    if raw.decode_u16(20+index*2)!=0:continue
    var best=INF;var serial=0
    for dy in range(-8,9):
     for dx in range(-8,9):
      var other=cell+Vector2i(dx,dy);var distance=dx*dx+dy*dy
      if distance>=best or other.x<0 or other.y<0 or other.x>=size_.x or other.y>=size_.y:continue
      var candidate=raw.decode_u16(20+(other.y*size_.x+other.x)*2)
      if candidate<1000 or candidate in range(5000,5009):continue
      var graphic:Dictionary=Art.data().graphics[str(candidate)]
      if graphic.family=="void" or int(graphic.footprint[0])!=1 or int(graphic.footprint[1])!=1:continue
      serial=candidate;best=distance
    if serial==0:continue
    covered[cell]=true;fills.append([0,0,Vector2.ZERO,serial,index,cell])
 return fills

static func build(root:Node3D,id:int,seed_:int=0)->Array[AABB]:
 var row=state(id,seed_);var size_:Vector2i=row.size;var origin:Vector2=row.origin
 var art=Art.new();art.load_map(path_for(id,seed_) if id not in [51009,51010] else "generated:snow",row.raw,size_)
 var surfaces={};var groups={};var trees={};var shrubs=[];var flowers=[];var cells=size_.x*size_.y;var total=0
 var snow=id in [51009,51010]
 var frost=load("res://scripts/forest/forest_frostpass_art.gd") if snow else null
 var winter=load("res://scripts/forest/forest_frostpass.gd") if snow else null
 var source_count=art.placements.size()
 var cliff_mass=source_id(id) in Forms.Cliffs.MAPS
 var porch_fills=porch_floors(art.placements,row.raw,size_)
 art.placements.append_array(porch_fills)
 var cut_floor={}
 for placement in art.placements:
  if placement[4]<cells or placement[3] not in Forms.CUT_FLOOR:continue
  var g:Dictionary=Art.data().graphics[str(placement[3])]
  for z in maxi(1,int(g.footprint[1])):
   for x in maxi(1,int(g.footprint[0])):cut_floor[placement[5]+Vector2i(x,-z)]=true
 for placement in art.placements:
  var serial:int=placement[3];var g:Dictionary=Art.data().graphics[str(serial)]
  var cell:Vector2i=placement[5];var pos=Vector3(origin.x+cell.x*3,0,origin.y+cell.y*3)
  if source_id(id)==400 and (serial==10011 or placement[4]<cells and serial>=1600 and serial<=1692):continue
  if placement[4]<cells and cut_floor.has(cell):continue
  var family=Forms.kind(serial,placement[4]<cells,g)
  if cliff_mass and family=="rock" and Forms.Cliffs.continuous(serial):
   total+=1;continue
  if family in ["detail_aquatic","detail_boat"] and row.raw.decode_u16(20+(cell.y*size_.x+cell.x)*2) in range(5000,5009):pos.y=-2.1
  if family=="void":continue
  if family=="flowers":
   flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.65),pos));total+=1
   continue
  if serial==10604:
   var index=root.get_child_count()
   Civic.build(root,Vector3.ZERO,[1092,"falan_townhouse",0,Vector2.ZERO,Vector3.ONE])
   var model:Node3D=root.get_child(index)
   var w=maxi(1,int(g.footprint[0]))*3.0;var d=maxi(1,int(g.footprint[1]))*3.0
   var height=Forms.source_height(g)
   model.position=pos+Vector3((w-3)*.5,0,(3-d)*.5);model.rotation.y=0
   model.scale=Vector3(w/17.9,height/15.5,d/14.35)
   model.name="RecoveredUniversityGuild_10604";total+=1
   continue
  if family=="tree":
   var evergreen=serial in range(10050,10074) or (serial in range(11600,11622))
   var tree_source=10058 if evergreen else 10088
   var snowy=source_id(id) in [402,4300,4400,15522] or id in [51009,51010] or serial>=11600
   var key=Vector2i(tree_source,int(snowy))
   if not trees.has(key):trees[key]=[]
   if snow:
    for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if not open(row.bits,size_,cell+step):continue
     var edge=Vector2(pos.x,pos.z)+Vector2(step)*1.5
     pos.y=frost.wall_column(edge,winter.LEVELS.keys().find(id),row.bits)[8].y-.6
     break
   var height=clampf(float(-g.origin[1])*.031,2.0,12.0)
   trees[key].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*height/8.5),pos))
   continue
  if family=="planter":
   var high=maxf(.35,Forms.source_height(g)*.68)
   shrubs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.75,.40,.75)),pos+Vector3.UP*high*.72))
  var native_cliff=family=="rock" and (Forms.Cliffs.owns(serial) or serial in Forms.CaveEntrance.IDS)
  var texture=art.textures[int(g.page)] if family in ["floor","water","detail_flat_panel"] or native_cliff else Art.solid_texture(int(g.page))
  if family=="rock" and not native_cliff or family=="wall" and serial in Forms.WALLS:texture=Art.surface_texture(int(g.surfaces[0]))
  var mesh=Forms.mesh(serial,family,g,texture)
  if family in ["floor","water","detail_flat_panel"]:
   var page=int(g.page)
   if not surfaces.has(page):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[page]=tool
   var arrays=mesh.surface_get_arrays(0)
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    surfaces[page].set_uv(arrays[Mesh.ARRAY_TEX_UV][i]);surfaces[page].set_normal(arrays[Mesh.ARRAY_NORMAL][i]);surfaces[page].add_vertex(pos+arrays[Mesh.ARRAY_VERTEX][i])
  else:
   if not groups.has(serial):groups[serial]=[mesh,[]]
   groups[serial][1].append(Transform3D(Basis.IDENTITY,pos))
  total+=1
 if cliff_mass:Forms.Cliffs.build(root,art.placements,size_,row.bits,origin)
 for page in surfaces:
  var mesh=surfaces[page].commit()
  if mesh!=null:Geo.mesh(root,mesh,Vector3.ZERO,Forms.Source.material(art.textures[page])).name="RecoveredShalenaGround"
 for serial in groups:
  var chunks={};var span=Forms.Boxes.CHUNK_SIZE
  for pose:Transform3D in groups[serial][1]:
   var chunk=Vector2i(floori(pose.origin.x/span),floori(pose.origin.z/span))
   if not chunks.has(chunk):chunks[chunk]=[]
   chunks[chunk].append(pose)
  for chunk in chunks:
   var node=MultiMeshInstance3D.new();node.name="RecoveredShalenaSolid_%d_%d_%d"%[serial,chunk.x,chunk.y]
   node.position=Vector3(chunk.x*span,0,chunk.y*span);node.set_meta("source_graphic",serial)
   node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=groups[serial][0];node.multimesh.instance_count=chunks[chunk].size()
   for i in chunks[chunk].size():
    var pose:Transform3D=chunks[chunk][i];pose.origin-=node.position
    node.multimesh.set_instance_transform(i,pose)
   root.add_child(node)
 Meadow.batch(root,"leafy_shrub",shrubs,true)
 Meadow.batch(root,"flowers_ivory",flowers,true)
 for key:Vector2i in trees:
  if key.y==1:load("res://scripts/forest/forest_frostpass_art.gd").snowy_grove(root,trees[key],key.x,"RecoveredShalenaTrees")
  else:Meadow.batch(root,Meadow.crossgate_tree(key.x),trees[key],true)
 if source_id(id)==400:
  var at=source_point(id,Vector2i(135,333))
  load("res://scripts/forest/forest_beast_castle.gd").build(root,Vector3(at.x,0,at.y))
 if id==16513:
  var at=source_point(id,Vector2i(14,6))
  var stone=load("res://scripts/forest/forest_travel_stone_art.gd").crystal(root,Vector3(at.x,0,at.y))
  stone.name="BeastReturnStone";stone.set_meta("source_appearance",103011)
 root.set_meta("recovered_source_map",source_id(id));root.set_meta("recovered_source_placements",source_count);root.set_meta("recovered_solid_placements",total)
 root.set_meta("recovered_source_path",path_for(id,seed_) if not snow else "generated:snow")
 root.set_meta("recovered_floor_openings",cut_floor.keys())
 root.set_meta("recovered_porch_floor_patches",porch_fills.map(func(p):return [p[5],p[3]]))
 var center=origin+(Vector2(size_)-Vector2.ONE)*1.5
 if snow:
  var bed=Node3D.new();bed.name="RecoveredSnowBed";root.add_child(bed)
  var boxes=Forms.Boxes.new();var material=load("res://scripts/forest/forest_stone_fort.gd").material(Color("deebf2"),false)
  for z in size_.y:
   var start=-1
   for x in range(size_.x+1):
    if x<size_.x and not cut_floor.has(Vector2i(x,z)):
     if start<0:start=x
     continue
    if start<0:continue
    boxes.add(Vector3(origin.x+(start+x-1)*1.5,-.13,origin.y+z*3),Vector3((x-start)*3,.20,3),material);start=-1
  boxes.build(bed)
  frost.cave_walls(root,id,row.bits)
  frost.cave_mass(root,id,row.bits,winter.snow_maze(id,seed_).rocks)
 var ground=Solids.solid(root,Vector3(center.x,-1,center.y),Vector3(size_.x*3,2,size_.y*3),1,"stone")
 ground.set_meta("original_map_ground",true);ground.name="RecoveredShalenaPhysicalGround"
 if id in [51022,51023]:
  var at=source_point(id,Vector2i(15,7));var p=Vector3(at.x,0,at.y)
  load("res://scripts/forest/forest_holy_decree_art.gd").stone_disc(root,at,Color("61c5cc"),false)
  if id==51023 and not root.get_tree().get_meta("holy_decree_blade",false):Geo.box(root,p+Vector3.UP,Vector3(.3,.96,.13),Geo.mat("e3b779")).name="DecreeBladeFragment"
 return boundaries(root,row.bits,size_,origin)

static func boundaries(root:Node3D,bits:PackedByteArray,size_:Vector2i,origin:Vector2)->Array[AABB]:
 var walls:Array[AABB]=[]
 for along_x in [true,false]:
  var rows=size_.y if along_x else size_.x;var columns=size_.x if along_x else size_.y
  for row in range(rows+1):
   var start=-1
   for column in range(columns+1):
    var edge=false
    if column<columns:
     var a=Vector2i(column,row-1) if along_x else Vector2i(row-1,column)
     var b=Vector2i(column,row) if along_x else Vector2i(row,column)
     edge=open(bits,size_,a)!=open(bits,size_,b)
    if edge and start<0:start=column
    if edge or start<0:continue
    var p=origin+(Vector2((start+column-1)*1.5,row*3-1.5) if along_x else Vector2(row*3-1.5,(start+column-1)*1.5))
    var extent=Vector3((column-start)*3,8.5,.04) if along_x else Vector3(.04,8.5,(column-start)*3)
    var center=Vector3(p.x,4.25,p.y)
    Solids.solid(root,center,extent,1,"stone").name="RecoveredShalenaBoundary_%d"%walls.size()
    walls.append(AABB(center-extent*.5,extent));start=-1
 return walls
