extends RefCounted
## Source quest data and trigger state; existing Ruby/native, dialogue and room owners do the work.
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const POST=16509
const STATE=&"black_prayer_source_battle"
const ROOT="res://assets/maps/falan/black_prayer/events/"
static var source:Dictionary={}
static var placements:Dictionary={}
static func data()->Dictionary:
 if source.is_empty():source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return source
static func palace_data(id:int)->Dictionary:return data().pre if id==Prayer.BOSS else data().post
static func palace_info(id:int)->Array:
 var row:Dictionary=palace_data(id)
 return [Vector2i(row.size[0],row.size[1]),Vector2(row.origin[0],row.origin[1]),row.walk]
static func palace_tiles(id:int,key:String)->PackedByteArray:
 return Marshalls.base64_to_raw(palace_data(id)[key]).decompress(50*50*2,FileAccess.COMPRESSION_DEFLATE)
static func palace_props(id:int)->Array:
 return palace_data(id).props.map(func(row):return [Vector2i(row[0],row[1]),int(row[2])])
static func post_info()->Array:return palace_info(POST)
static func post_tiles(key:String)->PackedByteArray:return palace_tiles(POST,key)
static func post_props()->Array:return palace_props(POST)
static func generated_npcs(seed_:int)->Dictionary:
 if placements.has(seed_):return placements[seed_]
 var candidates=[]
 for id:int in Prayer.FLOORS:
  for y in 4:
   for x in 4:
    var cell=Prayer.room_center(Vector2i(x,y))
    if Prayer.stairs(id,seed_).any(func(stair):return cell.distance_squared_to(stair)<9):continue
    candidates.append([id,cell])
 var rng=Prayer.rng_for(301,seed_+6303);var result={}
 # shortcut: source templates/refresh are known, original placement/count code is not; one of each per branch.
 for actor in ["6303","6304"]:
  result[actor]=candidates.pop_at(rng.randi_range(0,candidates.size()-1))
 placements.clear();placements[seed_]=result
 return result
static func prepare_run(game):
 var tree:SceneTree=game.get_tree();var state:Dictionary=tree.get_meta(STATE,{})
 var token=[game.get_instance_id(),game.model.seed_value]
 if not state.is_empty() and (state.get("run")!=token or not tree.has_meta(Ruby.SLAIN)):
  if state.get("run")!=token:tree.remove_meta(Ruby.SLAIN)
  tree.remove_meta(STATE)
static func active(game)->bool:
 prepare_run(game)
 var state:Dictionary=game.get_tree().get_meta(STATE,{})
 return state.get("active",false) and not state.get("complete",false)
static func actors(model)->Array:
 if model.falan_area!="interior":return []
 var result=[]
 for original in data().actors.values():
  var row:Dictionary=original.duplicate(true)
  if row.id=="6302":continue # Existing Southern route owns this exact source rock.
  if row.source==777:
   if model.falan_floor not in Prayer.FLOORS:continue
   var placed:Array=generated_npcs(model.seed_value)[row.id]
   if int(placed[0])!=model.falan_floor:continue
   row.runtime_floor=model.falan_floor;row.cell=[placed[1].x,placed[1].y]
   row.runtime_placement="Seeded current-room adaptation; raw source777/template_cell/refresh retained."
  elif int(row.source)!=model.falan_floor:continue
  if row.id=="81000" and is_instance_valid(model.army_runtime) and active(model.army_runtime.game):continue
  result.append(row)
 return result
static func replaces(model,at:Vector2)->bool:
 if model.falan_area!="interior":return false
 var origin:Vector2=load("res://scripts/forest/forest_falan_interior.gd").floor_info(model.falan_floor)[1]
 return actors(model).any(func(row):return (origin+Vector2(row.cell[0],row.cell[1])*3.).distance_squared_to(at)<.01)
static func rows(model)->Array:
 if model.falan_area!="interior":return []
 var result=[]
 var origin:Vector2=load("res://scripts/forest/forest_falan_interior.gd").floor_info(model.falan_floor,model.seed_value)[1]
 for row in actors(model):
  var g:Dictionary=data().art[row.token];var rect:Array=g.rect
  var offset=Vector2(float(g.origin[0])+float(rect[2])*.5,-float(g.origin[1])-float(rect[3])*.5)
  if g.has("body_foot"):
   offset.y=float(g.body_foot)-float(rect[3])*.5
   row.map_body_foot_row=g.body_foot;row.map_raw_origin=g.origin
  result.append([origin+Vector2(row.cell[0],row.cell[1])*3.,Rect2(rect[0],rect[1],rect[2],rect[3]),row.name,offset,row])
 return result
static func decorate(record:Dictionary):
 if str(record.get("id",""))!="6302":return
 for key in ["quest_action","script","source_line","dialogue_owner","unbounded_source_quest_items"]:record[key]=data().actors["6302"][key]
static func on_map(game,actor:Dictionary)->bool:
 var target:int=int(actor.get("runtime_floor",actor.source))
 return game.model.falan_area=="interior" and game.model.falan_floor==target
static func action(game,key:String)->bool:
 if not key.begins_with("black_prayer:"):return false
 var id=key.trim_prefix("black_prayer:");var actor:Dictionary=data().actors.get(id,{})
 if actor.is_empty():return true
 actor=actor.duplicate(true)
 if actor.source==777:
  var placed:Array=generated_npcs(game.model.seed_value)[id]
  if game.model.falan_floor!=int(placed[0]):return true
  actor.runtime_floor=int(placed[0]);actor.cell=[placed[1].x,placed[1].y]
 if not on_map(game,actor):return true
 return load("res://scripts/forest/forest_east_events.gd").source_actor(game,actor,data().scripts.get(actor.script,{}))
static func begin(game,actor:Dictionary,args:String)->bool:
 if str(actor.id)!="81000" or game.model.falan_floor!=Ruby.ROOM:return false
 var fields=args.split("|",true)
 if fields.size()<10 or fields[9]!="11007":return false
 prepare_run(game)
 var tree:SceneTree=game.get_tree()
 if active(game) and game.model.enemies.values().any(func(enemy):return enemy.has("ruby_slot")):return true
 if tree.get_meta(Ruby.SLAIN,{}).size()==10:tree.set_meta(Ruby.SLAIN,{})
 if not tree.has_meta(Ruby.SLAIN):tree.set_meta(Ruby.SLAIN,{})
 tree.set_meta(STATE,{"run":[game.get_instance_id(),game.model.seed_value],"active":true,"complete":false,"actor":"81000","encounter":11007,"group":11009,"raw":args})
 for sprite in game.world.map_features.find_children("*","Sprite3D",true,false):
  if sprite.get_meta("npc_record",{}).get("id","")=="81000":sprite.hide()
 game.model.waves.spawned=0
 return true
static func tag_member(enemy:Dictionary,slot:int):
 var id:String=data().boss.native_slots[slot]
 enemy.source_enemy=id;enemy.source_group="11009";enemy.source_encounter=11007;enemy.source_npc="81000"
 enemy.source_ai=data().boss.enemies[id][8]
static func victory(game)->bool:
 if not active(game):return false
 var tree:SceneTree=game.get_tree()
 if tree.get_meta(Ruby.SLAIN,{}).size()<10:return false
 if is_instance_valid(game.get("explore_access")) and game.explore_access.enabled():
  var completed:Dictionary=tree.get_meta(STATE);completed.complete=true;completed.active=false;tree.set_meta(STATE,completed)
  game.explore_access.scripted_victory("ruby_slot",Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale,"露比",[POST,24,12])
  return false
 var region=load("res://scripts/forest/forest_east_region.gd")
 if not region.can_travel_source(game,POST,Vector2i(24,12)):return false
 var state:Dictionary=tree.get_meta(STATE);state.complete=true;state.active=false;tree.set_meta(STATE,state)
 return region.travel_source(game,POST,Vector2i(24,12))
