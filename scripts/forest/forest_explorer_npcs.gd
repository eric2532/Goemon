extends Node
## Casual conversations for the existing Falan citizen placements.
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const UniversityRegion=preload("res://scripts/forest/forest_university_region.gd")
const FalanDialogue=preload("res://assets/maps/falan/npc_dialogue.gd")
const Harbor=preload("res://scripts/forest/forest_east_harbor.gd")
var game
var map_signature:Array=[]
var actors:Array=[]
var hint:Label3D
var nearest:Dictionary={}
var selected:Dictionary={}
var talk_bags:Dictionary={}
var update_left=0.0
func _ready():name="ExplorerNPCs"
func _process(delta):
 if game.model==null or not game.playing:return
 Harbor.tick(game,delta)
 load("res://scripts/forest/forest_east_battles.gd").tick_legacy(game)
 load("res://scripts/forest/forest_east_region.gd").tick(game,delta)
 var signature=[game.model.get_instance_id(),game.model.falan_area,game.model.falan_floor,game.world.map_features.get_instance_id()]
 if map_signature!=signature:
  if game.army_runtime.configured_model!=game.model or game.army_runtime.navigation_revision!=game.model.navigation_revision:return
  map_signature=signature;prepare()
 for entry in actors:
  if not is_instance_valid(entry.node):continue
  var source:Dictionary=entry.node.get_meta("npc_record",{})
  if source.get("night_only",false):entry.node.visible=game.explorer_clock.night()
 if not available():return
 update_left-=delta
 if update_left>0:return
 update_left=.15;nearest={}
 var reach_squared=pow(5.0*game.model.falan_scale,2);var distance=reach_squared;var front_choice=false
 var forward=Vector3.FORWARD.rotated(Vector3.UP,game.camera_rig.yaw)
 for entry in actors:
  if entry.record.id.begins_with("source:") and entry.battle_aliases.any(func(id):return UniversityRegion.hidden_actor(game.get_tree(),id)):
   if is_instance_valid(entry.node):
    entry.node.hide()
    entry.node.set_meta("battle_hidden",true)
  elif is_instance_valid(entry.node) and entry.node.get_meta("battle_hidden",false):
   entry.node.show();entry.node.remove_meta("battle_hidden")
  if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree():continue
  var at:Vector3=entry.get("interaction_point",entry.node.global_position);var d=game.player.position.distance_squared_to(at)
  if d>=reach_squared:continue
  if entry.has("interaction_point") and d>pow(2.5*game.model.falan_scale,2):continue
  if entry.node.get_meta("elsa_return_stone",false) and d>pow(Tour.Elsa.INTERACT_RADIUS*game.model.falan_scale,2):continue
  var toward=at-game.player.position;toward.y=0
  var in_front=toward.normalized().dot(forward)>.15
  if not nearest.is_empty() and (front_choice and not in_front or front_choice==in_front and d>=distance):continue
  var eye=game.player.position+Vector3.UP*2.5;var sight=at+Vector3.UP*2.5
  if entry.get("source_cell_blocked",false) and not entry.has("interaction_point"):
   # Stop outside the occupied source cell, including diagonal approaches; other walls still occlude it.
   var sight_direction=(eye-sight).normalized()
   var exit_distance=1.5/maxf(.01,maxf(absf(sight_direction.x),absf(sight_direction.z)))+.12
   sight=sight.move_toward(eye,exit_distance*game.model.falan_scale)
  if eye.distance_squared_to(sight)>.001 and not game._ryo_clear_path(eye,sight):continue
  nearest=entry;distance=d;front_choice=in_front
 if is_instance_valid(hint):
  hint.visible=not nearest.is_empty()
  if hint.visible:hint.global_position=nearest.get("interaction_point",nearest.node.global_position)+Vector3.UP*(float(nearest.node.get_meta("npc_hint_height",4.0))*game.model.falan_scale);hint.text="F · "+nearest.record.name
func prepare():
 map_signature=[game.model.get_instance_id(),game.model.falan_area,game.model.falan_floor,game.world.map_features.get_instance_id()]
 actors.clear();nearest={}
 if is_instance_valid(hint):hint.get_parent().remove_child(hint);hint.queue_free()
 hint=null
 var joined=game.model.get_meta("joined_village") if game.model.has_meta("joined_village") else null
 var groups=game.world.map_features.find_children("OriginalFalanNPCs","Node3D",true,false).filter(func(n):return n.get_meta("npc_map_area","")==game.model.falan_area and n.get_meta("npc_map_floor",-1)==game.model.falan_floor or joined!=null and n.get_meta("npc_map_area","")==joined.falan_area)
 for citizens in groups:
  var source_area:String=citizens.get_meta("npc_map_area",game.model.falan_area)
  var area=str(game.model.falan_floor) if source_area=="interior" else source_area
  var rows:Array=Tour.NPCS.AREAS.get(area,[])
  var regional_villagers=rows.is_empty()
  if regional_villagers:rows=Tour.VillageNPCs.AREAS.get(area,[])
  for sprite in citizens.get_children():
   enroll(sprite)
  for i in mini(rows.size(),citizens.get_child_count()):
   var sprite:Sprite3D=citizens.get_child(i)
   if sprite.has_meta("npc_record"):continue
   actors.append({"node":sprite,"record":{"id":"falan:%s:%d"%[area,i],"name":rows[i][2],"type":"FalanCitizen","portrait":sprite.texture,"messages":["你好。這裡的詳細對話尚待恢復。"] if regional_villagers else FalanDialogue.lines_for(rows[i])}})
 if groups.is_empty():return
 # Original quest variants can share one waiting body; hide all its copies during the selected fight.
 var waiting={}
 for entry in actors:
  if not entry.record.id.begins_with("source:"):continue
  entry.battle_aliases=[entry.record.id.trim_prefix("source:")]
  var original:Dictionary=entry.node.get_meta("npc_record",{})
  if not original.has("source")or not original.has("cell")or not original.has("graphic"):continue
  var key="%s:%s:%s:%s"%[original.source,str(original.cell),original.graphic,original.name]
  waiting.get_or_add(key,[]).append(entry)
 for copies in waiting.values():
  var ids=copies.map(func(entry):return entry.record.id.trim_prefix("source:"))
  for entry in copies:entry.battle_aliases=ids
 prepare_interaction_points()
 hint=Label3D.new();hint.font=preload("res://scripts/forest/preparation_skin.gd").FONT;hint.font_size=36;hint.pixel_size=.014
 if Tour.SouthPopulation.owns(game.model):hint.pixel_size=.009
 hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED;hint.hide();game.world.map_features.add_child(hint)
func enroll(sprite):
 if sprite is Sprite3D:
  if not sprite.has_meta("npc_record"):return
  var row:Dictionary=sprite.get_meta("npc_record")
  if row.get("scenery_only",false) or row.get("messages",[]).is_empty() and not row.has("quest_action"):return
  actors.append({"node":sprite,"record":{"id":"source:"+row.id,"name":row.name,"type":row.type,"portrait":sprite.texture,"messages":row.messages}})
  var blocked:bool=row.get("source_cell_blocked",row.scenery)
  if Tour.Winter.Recovered.owns(game.model.falan_floor):
   var original=Tour.Winter.Recovered;var state=original.state(game.model.falan_floor,game.model.seed_value)
   var cell=Vector2i(row.cell[0],row.cell[1])-original.crop(game.model.falan_floor).position
   blocked=blocked or not original.open(state.bits,state.size,cell)
  actors.back().source_cell_blocked=blocked
  if row.has("quest_action"):actors.back().record.quest_action=row.quest_action
  if row.has("dialogue_owner"):actors.back().record.dialogue_owner=row.dialogue_owner

func prepare_interaction_points():
 if game.model.falan_area!="interior" or not is_instance_valid(game.army_runtime) or game.army_runtime.native==null:return
 var maps=Tour.Winter.Recovered;var id:int=game.model.falan_floor
 var info=Tour.Indoor.floor_info(id,game.model.seed_value);var size_:Vector2i=info[0];var origin:Vector2=info[1]
 var bits:PackedByteArray=Tour.Indoor.walk_mask(id,size_,info[2].hex_decode(),game.model.seed_value)
 for entry in actors:
  var at=Vector2(entry.node.global_position.x,entry.node.global_position.z)/game.model.falan_scale
  var candidates=[]
  for y in range(-3,4):
   for x in range(-3,4):candidates.append(at+Vector2(x,y)*1.5)
  candidates.sort_custom(func(a,b):return a.distance_squared_to(at)<b.distance_squared_to(at))
  var ordinary=false;var proxy=Vector3.INF
  for p:Vector2 in candidates:
   var cell=Vector2i(((p-origin)/3.).round())
   if not maps.open(bits,size_,cell):continue
   var point=game.model.world_point(p,.15)
   if is_instance_valid(game.get("explore_access")) and not game.explore_access.body_clear(point):continue
   if not game.model.terrain.disk_clear(point/game.model.falan_scale,.55):continue
   var from=game.player.position;from.y=game.model.world_height(from.x,from.z)
   if not game.army_runtime.native.can_reach_ally(from,point,.55*game.model.falan_scale):continue
   var surface=Vector2i(-1,-1)
   if str(entry.record.id).trim_prefix("source:")=="5269"and id==15539:surface=Vector2i(20,8)
   if str(entry.record.id).trim_prefix("source:")=="1102643"and id==4409:surface=Vector2i(58,43)
   if not counter_segment(id,at,p,origin,size_,bits,surface):continue
   if point.distance_squared_to(entry.node.global_position)<pow(4.5*game.model.falan_scale,2) and game._ryo_clear_path(point+Vector3.UP*2.5*game.model.falan_scale,entry.node.global_position+Vector3.UP*2.5):ordinary=true;break
   if not proxy.is_finite():proxy=point
  if not ordinary and proxy.is_finite():entry.interaction_point=proxy

func counter_segment(id:int,from:Vector2,to:Vector2,origin:Vector2,size_:Vector2i,bits:PackedByteArray,surface:Vector2i=Vector2i(-1,-1))->bool:
 var maps=Tour.Winter.Recovered;var raw=PackedByteArray()
 if maps.owns(id):raw=maps.state(id,game.model.seed_value).raw
 var allowed=["counter","coast_counter","coast_display","civic_counter","table","fence","grille","railing","display_bench","display_cabinet"]
 var crossed={}
 for i in 17:
  var p=from.lerp(to,float(i)/16.);var cell=Vector2i(((p-origin)/3.).round())
  if maps.open(bits,size_,cell) or crossed.has(cell):continue
  if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
  crossed[cell]=true
  if crossed.size()>2:return false
  # These original mural/dragon triggers occupy their own blocked anchor cell.
  var fixture=cell==surface
  if not raw.is_empty():
   var serial=raw.decode_u16(20+(size_.x*size_.y+cell.y*size_.x+cell.x)*2)
   var art:Dictionary=maps.Art.data().graphics.get(str(serial),{})
   fixture=fixture or not art.is_empty() and maps.Forms.kind(serial,false,art) in allowed
  else:
   for row in Tour.Indoor.RoomArt.Coastal.Data.ROOMS.get(id,Tour.Indoor.RoomArt.Data.FIXTURES.get(id,[])):
    if Rect2i(row[0],row[1]).has_point(cell) and row[2] in allowed:fixture=true;break
  if not fixture:return false
 return true
func available()->bool:
 return game.playing and not game.paused and not game.transitioning and not game.ordinary_pause and game.model.phase=="wave" and game.player.hp>0 and not Tour.area(game.model).is_empty()
func interact()->bool:
 if not available() or nearest.is_empty():return false
 if nearest.node.get_meta("elsa_return_stone",false):return Tour.Elsa.open(game)
 selected=nearest.record
 if (selected.get("quest_action","").begins_with("east_event:")or selected.get("quest_action","").begins_with("black_prayer:")or selected.get("quest_action","").begins_with("sokia_server:")or selected.get("dialogue_owner","")in["sokia_cape_access","sokia_wind"]) and selected.type in ["Event","StandEnemy","HouseMaster","Warp","HouseWarp2"]:
  var action:String=selected.quest_action;selected={}
  if not load("res://scripts/forest/forest_east_events.gd").action(game,action):Tour.university_quest(game,action)
  return true
 var key=selected.id
 if talk_bags.get(key,[]).is_empty():talk_bags[key]=selected.messages.duplicate();talk_bags[key].shuffle()
 var pages=[{"text":talk_bags[key].pop_back().strip_edges(),"portrait":null,"options":[]}]
 game.show_boss_dialogue(selected.name,pages,hint,finish)
 return true
func finish():
 var action:String=selected.get("quest_action","");selected={}
 if is_instance_valid(game.dialogue):game.close_boss_dialogue()
 if not action.is_empty() and not Harbor.action(game,action) and not load("res://scripts/forest/forest_east_events.gd").action(game,action):Tour.university_quest(game,action)
