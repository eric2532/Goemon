extends RefCounted
## Archived stone endpoints use the ordinary Explore interaction and area loader.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const OUTDOORS=[59500,59501,59510,59520]
const BATTLES="elsa_battles"
const INTERACT_RADIUS=4.5
const SLAIN="elsa_battle_slain"
static var transfers:Array=[]
static var ownership:Dictionary={}
static var room_masks:Dictionary={}

static func owned_cell(id:int,cell:Vector2i)->bool:
 if id==59721:
  var maps=load("res://scripts/forest/forest_original_maps.gd");var row:Dictionary=Art.data().maps.get(maps.path_for(id),{})
  if row.is_empty() or not Rect2i(Vector2i.ZERO,Vector2i(row.size[0],row.size[1])).has_point(cell):return false
  if not room_masks.has(id):room_masks[id]=Marshalls.base64_to_raw(row.walk).decompress((int(row.size[0])*int(row.size[1])+7)>>3,FileAccess.COMPRESSION_DEFLATE)
  var bits:PackedByteArray=room_masks[id]
  var index=cell.y*int(row.size[0])+cell.x
  return (bits[index>>3]&(1<<(index&7)))!=0
 if id in [59500,59501,59510,59511] or id<59500 or id>=59800:return true
 if ownership.is_empty():
  ownership=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/ownership.json"))
  # Disconnected Sylph rooms share59752 with an independently owned Elsa quest room.
  var regional=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_region/sylph_ownership.json"))
  for key_ in regional:
   if not ownership.has(key_):ownership[key_]=regional[key_];continue
   var addition:Dictionary=regional[key_];var bytes_:int=(int(addition.size[0])*int(addition.size[1])+7)>>3
   var existing=Marshalls.base64_to_raw(ownership[key_].open).decompress(bytes_,FileAccess.COMPRESSION_DEFLATE)
   var extra=Marshalls.base64_to_raw(addition.open).decompress(bytes_,FileAccess.COMPRESSION_DEFLATE)
   for i in bytes_:existing[i]|=extra[i]
   ownership[key_].open=Marshalls.raw_to_base64(existing.compress(FileAccess.COMPRESSION_DEFLATE));ownership[key_].bounds.append_array(addition.bounds)
 var key=str(id)
 if not ownership.has(key):return false
 var row:Dictionary=ownership[key];var size_=Vector2i(row.size[0],row.size[1])
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 if not room_masks.has(id):room_masks[id]=Marshalls.base64_to_raw(row.open).decompress((size_.x*size_.y+7)>>3,FileAccess.COMPRESSION_DEFLATE)
 var index=cell.y*size_.x+cell.x
 return (room_masks[id][index>>3]&(1<<(index&7)))!=0

static func visible_cell(id:int,cell:Vector2i)->bool:
 if id not in [59716,59752]:return true
 owned_cell(id,cell)
 for bounds in ownership[str(id)].bounds:
  if cell.x>=int(bounds[0]) and cell.y>=int(bounds[1]) and cell.x<int(bounds[2]) and cell.y<int(bounds[3]):return true
 return false

static func data()->Dictionary:return load("res://scripts/forest/crowd/elsa_region_sprites.gd").data()

static func event_links(id:int)->Array:
 if id<59500 or id>=59800:return []
 if transfers.is_empty():transfers=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/links.json"))
 var maps=load("res://scripts/forest/forest_original_maps.gd");var result=[];var seen={}
 for row in transfers:
  if int(row.source)!=id or row.kind!="event" or row.target==1500 or not maps.owns(int(row.target)):continue
  var key=[row.cell,row.target,row.landing]
  if seen.has(key):continue
  seen[key]=true
  var link=maps.door(maps.source_point(id,Vector2i(row.cell[0],row.cell[1])),int(row.target),maps.source_point(int(row.target),Vector2i(row.landing[0],row.landing[1])))
  if int(row.target)==59716 and int(row.landing[0])==166 and int(row.landing[1])==173:
   link.elsa_blocked=true;link.caption="通道（尚未開放）"
  link.elsa_event=true;link.source_proof=row.proof;result.append(link)
  if row.get("temple_return",false):link.elsa_stone="temple_return"
 for battle in data().battles:
  if int(battle.map)!=id:continue
  var levels=[]
  for choice in battle.groups:levels.append_array(data().battle_groups[choice[0]].details[0].level)
  var caption="E · "+str(battle.name)+" · Lv.%d–%d"%[levels.min(),levels.max()]
  result.append({"at":maps.source_point(id,Vector2i(battle.cell[0],battle.cell[1])),"to":"elsa_battle","caption":caption,"elsa_event":true,"elsa_battle":str(battle.key),"source_proof":battle.proof})
 return result

static func castle_point(cell:Vector2i)->Vector2:
 return Vector2(3*(cell.y-56),3*(41-cell.x))

static func stone_links(area:String,floor_:int)->Array:
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 if area=="castle":
  return [{"at":castle_point(Vector2i(28,88)),"to":"freyja_door","floor":59511,
   "arrival":maps.source_point(59511,Vector2i(19,19)),"caption":"E · 時光通道",
   "elsa_stone":"outbound","source_cell":Vector2i(28,88)}]
 if area=="interior" and floor_==59520:
  return [{"at":maps.source_point(59520,Vector2i(141,104)),"to":"castle",
   "arrival":castle_point(Vector2i(27,82)),"caption":"E · 傳送石 · 里謝里雅堡",
   "elsa_stone":"return","source_cell":Vector2i(141,104)}]
 return []

static func open(game)->bool:
 var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var nearby=[]
 for link in game.model.get_meta("falan_links",[]):
  if not (link.has("elsa_stone") or link.has("elsa_event")) or at.distance_squared_to(link.at)>INTERACT_RADIUS*INTERACT_RADIUS:continue
  if absf(game.player.position.y-game.model.world_height(at.x*game.model.falan_scale,at.y*game.model.falan_scale))>2.5*game.model.falan_scale:continue
  nearby.append(link)
 if nearby.is_empty():return false
 nearby.sort_custom(func(a,b):return at.distance_squared_to(a.at)<at.distance_squared_to(b.at))
 var closest:Dictionary=nearby[0]
 if closest.has("elsa_stone"):return interact(game,load("res://scripts/forest/forest_falan_tour.gd").area(game.model),closest,at)
 nearby=nearby.filter(func(link):return link.at==closest.at)
 var choices=[]
 for i in nearby.size():choices.append([str(i),str(nearby[i].caption)])
 choices.append(["cancel","離開"])
 var trigger=Label3D.new()
 game.show_boss_dialogue("區域旅行",[{"text":"前往何處？","portrait":null,"options":choices}],trigger,game.close_boss_dialogue);trigger.free()
 game.dialogue.chosen.connect(func(answer:String):
  game.close_boss_dialogue()
  if not answer.is_valid_int():return
  var link:Dictionary=nearby[int(answer)]
  if link.get("elsa_blocked",false):game.toast("此通道尚未開放");return
  if link.has("elsa_battle"):begin(game,str(link.elsa_battle));return
  var accepted=link.duplicate();accepted.erase("elsa_event");accepted.yaw=game.camera_rig.yaw
  var tour=load("res://scripts/forest/forest_falan_tour.gd");tour.enter_link(game,tour.area(game.model),accepted,at))
 return true

static func active(tree:SceneTree,id:int)->String:
 for key in tree.get_meta(BATTLES,{}):
  if int(data().battles[int(key)].map)==id and not tree.get_meta(BATTLES,{})[key].complete:return key
 return ""

static func begin(game,key:String):
 var tree:SceneTree=game.get_tree();var spec:Dictionary=data().battles[int(key)]
 if not active(tree,game.model.falan_floor).is_empty():return
 var bank=load("res://scripts/forest/crowd/elsa_region_sprites.gd");var waves=game.model.waves
 var gid=bank.Snow.weighted(waves.snow_bags,"elsa-battle:"+key,spec.groups,waves.rng)
 var group:Dictionary=data().battle_groups[gid];var members=[]
 for i in group.details.size():
  var row:Dictionary=group.details[i]
  var count_=int(bank.Snow.draw(waves.snow_bags,"elsa-retinue:%s:%d"%[key,i],range(int(row.count[0]),int(row.count[1])+1),waves.rng))
  for n in count_:
   var member:Dictionary=row.duplicate();member.boss=i==0
   member.level=int(bank.Snow.draw(waves.snow_bags,"elsa-boss-level:%s:%d"%[key,i],range(int(row.level[0]),int(row.level[1])+1),waves.rng));members.append(member)
 var battles:Dictionary=tree.get_meta(BATTLES,{})
 battles[key]={"members":members,"complete":false};tree.set_meta(BATTLES,battles)
 var slain:Dictionary=tree.get_meta(SLAIN,{})
 for slot in members.size():slain.erase(key+":"+str(slot))
 tree.set_meta(SLAIN,slain);waves.spawned=0;waves.snow_pending=[];game.toast(str(group.name))

static func defeated(tree:SceneTree,enemy:Dictionary):
 var key:String=enemy.elsa_battle;var slain:Dictionary=tree.get_meta(SLAIN,{})
 slain[key+":"+str(enemy.elsa_slot)]=true;tree.set_meta(SLAIN,slain)
 var battles:Dictionary=tree.get_meta(BATTLES,{})
 for i in battles[key].members.size():
  if not slain.has(key+":"+str(i)):return
 battles[key].complete=true;tree.set_meta(BATTLES,battles);tree.set_meta("elsa_victory",key)

static func victory(game)->bool:
 var tree:SceneTree=game.get_tree()
 if not tree.has_meta("elsa_victory"):return false
 var key:String=tree.get_meta("elsa_victory");tree.remove_meta("elsa_victory")
 var spec:Dictionary=data().battles[int(key)]
 if int(spec.map)!=game.model.falan_floor:return false
 if is_instance_valid(game.get("explore_access")) and game.explore_access.enabled():
  game.explore_access.scripted_victory("elsa:"+key,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale,str(spec.name),spec.win)
  return false
 var maps=load("res://scripts/forest/forest_original_maps.gd");var win:Array=spec.win
 if win.is_empty():game.toast("戰鬥勝利");return false
 var link:Dictionary=maps.door(Vector2.ZERO,int(win[0]),maps.source_point(int(win[0]),Vector2i(win[1],win[2])))
 link.yaw=game.camera_rig.yaw
 load("res://scripts/forest/forest_falan_tour.gd").enter_link(game,"interior",link,Vector2.ZERO)
 return true

static func room_returns(id:int,existing:Array,regional:bool=false)->Array:
 if not regional and (id<59500 or id>=59800):return []
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 var source:Dictionary=Art.data().maps[maps.path_for(id)]
 var state:Dictionary=maps.state(id);var result=[]
 for warp in Art.data().warps:
  if int(warp[3])!=maps.source_id(id) or not maps.owns(maps.runtime_id(int(warp[0]))):continue
  var cell=Vector2i(warp[4],warp[5]);var target:int=maps.runtime_id(warp[0]);var landing=Vector2i(warp[1],warp[2])
  if id==59530 and cell in [Vector2i(79,55),Vector2i(59,93),Vector2i(81,133)]:continue # These returns belong to their corroborated stone scripts.
  if not source.warp_cells.any(func(c):return Vector2i(c[0],c[1])==cell):continue
  var at:Vector2=maps.source_point(id,cell)
  if existing.any(func(link):return link.at==at) or result.any(func(link):return link.at==at):continue
  var destination:Dictionary=maps.state(target)
  if not maps.open(state.bits,state.size,cell-maps.crop(id).position) or not maps.open(destination.bits,destination.size,landing-maps.crop(target).position):continue
  # A recorded reverse warp tile and its matching inbound edge establish the doorway pair.
  result.append(maps.door(at,target,maps.source_point(target,landing)).merged({"paired_return":true,"paired_reference":warp}))
 return result

static func interact(game,current:String,link:Dictionary,at:Vector2)->bool:
 var trigger=Label3D.new()
 var text="返回艾爾莎島？" if link.elsa_stone=="temple_return" else "穿越時間的通道？" if link.elsa_stone=="outbound" else "穿越時間的裂縫，返回古老的城都？"
 game.show_boss_dialogue("傳送石" if link.elsa_stone=="temple_return" else "時光傳送",[{"text":text,"portrait":null,"options":[["travel","是"],["cancel","否"]]}],trigger,game.close_boss_dialogue)
 trigger.free()
 game.dialogue.chosen.connect(func(answer:String):
  game.close_boss_dialogue()
  if answer!="travel":return
  var accepted=link.duplicate();accepted.erase("elsa_stone")
  accepted.erase("elsa_event")
  accepted.yaw=game.camera_rig.yaw
  accepted.velocity=Vector3.ZERO
  load("res://scripts/forest/forest_falan_tour.gd").enter_link(game,current,accepted,at))
 return true
