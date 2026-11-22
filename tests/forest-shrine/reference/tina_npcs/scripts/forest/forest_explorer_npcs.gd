extends Node
## Source NPCs share the dialogue/travel owners; quest state contains only serializable data.
const DATA="res://assets/maps/falan/tina/npcs.json"
const ATLAS=preload("res://assets/maps/falan/tina/npcs.png")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Dialogue=preload("res://scripts/forest/forest_dialogue.gd")
const FalanDialogue=preload("res://assets/maps/falan/npc_dialogue.gd")
const CAPACITY=20
var game
var data:Dictionary={}
var state:Dictionary={}
var map_signature:Array=[]
var actors:Array=[]
var hint:Label3D
var nearest:Dictionary={}
var selected:Dictionary={}
var textures:Dictionary={}
var talk_bags:Dictionary={}
var current_code:Array=[]
var pc=-1
var window_buttons:Array=[]
var update_left=0.0
var walk_distance=0.0
var last_position=Vector3.INF
var condition_pattern=RegEx.new()
var battle_ids:Dictionary={}
var battle_exit:Array=[]
var battle_floor=0
var battle_npc=0
var trap_latch=0
var mine_ids:Dictionary={}
var service_page_index=0
var service_choices:Array=[]
var service_title=""
var prayer=0
var prayer_left=0.0
var ward=0
var ward_left=0.0
var shop_pet=""
var shop_tech=0
var shop_slot=-1
var shop_previous_skill=""

func _ready():
 name="ExplorerNPCs"
 data=JSON.parse_string(FileAccess.get_file_as_string(DATA))
 assert(data.get("schema")==1,"Missing recovered Tina NPC data")
 condition_pattern.compile("^([a-z]+)\\s*(\\d+)?\\s*(==|!=|>=|<=|>|<)\\s*(-?\\d+)$")
 load_state(game.settings.get("explorer_quests",{}))
 game.army_runtime.unit_died.connect(enemy_died)

func load_state(value):
 state={"items":{},"durability":{},"created":{},"now":{},"done":{},"learned":{},"pet_training":{},"equipped":0,"elapsed":0.0,"board":[],"house":{}}
 if not value is Dictionary:return
 for field in ["items","durability","created","now","done","learned"]:
  if not value.get(field) is Dictionary:continue
  for key in value[field]:
   var number=value[field][key]
   if not key is String or not key.is_valid_int() or not (number is int or number is float) or not is_finite(float(number)) or number<0:continue
   if field in ["items","durability","created"] and not data.items.has(key):continue
   if field=="items" and (number<1 or number>999 or state.items.size()>=CAPACITY):continue
   state[field][key]=float(number) if field=="created" else int(number)
 if value.get("elapsed") is float or value.get("elapsed") is int:
  if is_finite(float(value.elapsed)) and value.elapsed>=0:state.elapsed=float(value.elapsed)
 if value.get("board") is Array:
  for message in value.board.slice(0,10):
   if message is String and not clean_message(message).is_empty():state.board.append(clean_message(message))
 if value.get("house") is Dictionary:
  var lease:Dictionary=value.house
  if data.houses.has(str(lease.get("id",""))) and (lease.get("until") is float or lease.get("until") is int) and is_finite(float(lease.until)):
   state.house={"id":str(lease.id),"until":clampf(float(lease.until),0,Time.get_unix_time_from_system()+70*86400)}
 for id in state.learned.keys():
  if not data.skills.has(id) or state.learned[id]!=1:state.learned.erase(id)
 var pets=preload("res://scripts/forest/pet_catalog.gd")
 if value.get("pet_training") is Dictionary:
  for key in value.pet_training:
   if not key is String or pets.skin(key)<0 or not value.pet_training[key] is Array:continue
   var learned=[]
   for id in value.pet_training[key].slice(0,10):
    if (id is int or id is float) and is_finite(float(id)) and float(id)==float(int(id)) and pets.TINA_TECH_IDS.has(int(id)) and int(id) not in learned:learned.append(int(id))
   if not learned.is_empty():state.pet_training[key]=learned
 var equipped=value.get("equipped",0)
 if (equipped is int or equipped is float) and count_item(int(equipped))>0:state.equipped=int(equipped)

func persist()->bool:
 game.settings.explorer_quests=state.duplicate(true)
 if game.save_settings()==OK:return true
 game.toast("無法儲存任務進度");return false

func _process(delta):
 if game.model==null or not game.playing:return
 var signature=[game.model.get_instance_id(),game.model.falan_area,game.model.falan_floor,game.world.map_features.get_instance_id()]
 if map_signature!=signature:map_signature=signature;prepare()
 if game.paused or game.transitioning or game.ordinary_pause or game.model.phase!="wave":return
 if Tour.area(game.model).is_empty():return
 state.elapsed+=delta
 prayer_left=maxf(0,prayer_left-delta);ward_left=maxf(0,ward_left-delta)
 if prayer_left<=0:prayer=0
 if ward_left<=0:ward=0
 if house_door():return
 if state.equipped==18469 and count_item(18469)>0:
  if last_position.is_finite():walk_distance+=minf(1.5,last_position.distance_to(game.player.position))
  # shortcut: real-time movement supplies shackle wear; replace with native gear wear when shared durability exists.
  if walk_distance>=4.5:
   state.durability["18469"]=maxi(0,int(state.durability.get("18469",15))-1);walk_distance=fmod(walk_distance,4.5)
 last_position=game.player.position
 update_left-=delta
 if update_left>0:return
 update_left=.15;nearest={}
 var distance=pow(5.0*game.model.falan_scale,2)
 for entry in actors:
  if not is_instance_valid(entry.node) or not entry.node.is_visible_in_tree():continue
  var at:Vector3=entry.node.global_position
  var d=game.player.position.distance_squared_to(at)
  if entry.record.graphic==10400 and not entry.record.script.is_empty() and d<pow(1.25*game.model.falan_scale,2):
   if trap_latch!=int(entry.record.id):
    trap_latch=int(entry.record.id);selected=entry.record;start_script(selected.script);return
  if d>=distance or not game._ryo_clear_path(game.player.position+Vector3.UP*2.5,at+Vector3.UP*2.5):continue
  nearest=entry;distance=d
 if is_instance_valid(hint):
  hint.visible=not nearest.is_empty()
  if hint.visible:hint.global_position=nearest.node.global_position+Vector3.UP*(4.0*game.model.falan_scale);hint.text="F · "+nearest.record.name

func prepare():
 actors.clear();nearest={};last_position=Vector3.INF;trap_latch=0
 if is_instance_valid(hint):hint.get_parent().remove_child(hint);hint.queue_free()
 hint=null
 prayer=0;prayer_left=0;ward=0;ward_left=0
 if battle_floor!=game.model.falan_floor:battle_ids.clear();battle_exit.clear();battle_floor=0
 mine_ids.clear()
 var old=game.world.map_features.get_node_or_null("SourceTinaNPCs")
 if old!=null:old.get_parent().remove_child(old);old.queue_free()
 var area=str(game.model.falan_floor) if game.model.falan_area=="interior" else game.model.falan_area
 var citizens=game.world.map_features.find_child("OriginalFalanNPCs",true,false)
 if Tour.NPCS.AREAS.has(area) and citizens!=null:
  var rows:Array=Tour.NPCS.AREAS[area]
  for i in rows.size():
   var sprite:Sprite3D=citizens.get_child(i)
   actors.append({"node":sprite,"record":{"id":"falan:%s:%d"%[area,i],"name":rows[i][2],"type":"FalanCitizen","graphic":-1,"script":"","portrait":sprite.texture,"messages":FalanDialogue.lines_for(rows[i])}})
  add_hint(game.world.map_features)
 if game.model.falan_area!="interior":return
 var source=Maps.source_id(game.model.falan_floor)
 var rows=[];var records=[]
 for npc in data.npcs:
  if int(npc.floor)!=source or npc.graphic==0:continue
  if not Maps.crop(game.model.falan_floor).has_point(Vector2i(npc.cell[0],npc.cell[1])):continue
  var art:Dictionary=data.art[npc.token];var rect:Array=art.rect;var origin:Array=art.origin
  var at=Maps.source_point(game.model.falan_floor,Vector2i(npc.cell[0],npc.cell[1]))
  rows.append([at,Rect2(rect[0],rect[1],rect[2],rect[3]),npc.name,Vector2(origin[0]+rect[2]*.5,-origin[1]-rect[3]*.5)])
  records.append(npc)
 if rows.is_empty():return
 Tour.build_npcs(game.world.map_features,game.model,rows,ATLAS)
 var group=game.world.map_features.get_child(game.world.map_features.get_child_count()-1);group.name="SourceTinaNPCs"
 for i in records.size():
  var sprite=group.get_child(i);sprite.set_meta("source_npc_id",records[i].id);sprite.set_meta("source_cell",records[i].cell)
  if not records[i].rendered:sprite.modulate.a=0
  actors.append({"node":sprite,"record":records[i]})
 if not is_instance_valid(hint):add_hint(group)
 if source==32193:spawn_mine()

func add_hint(group:Node3D):
 hint=Label3D.new();hint.font=preload("res://scripts/forest/preparation_skin.gd").FONT;hint.font_size=36;hint.pixel_size=.014
 hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED;hint.hide();group.add_child(hint)

func available()->bool:
 return game.playing and not game.paused and not game.transitioning and not game.ordinary_pause and game.model.phase=="wave" and game.player.hp>0 and not Tour.area(game.model).is_empty()

func interact()->bool:
 if not available() or nearest.is_empty():return false
 selected=nearest.record
 match selected.type:
  "TownPeople","FalanCitizen":
   var key=selected.id if selected.type=="FalanCitizen" else str(int(selected.id))
   if talk_bags.get(key,[]).is_empty():talk_bags[key]=selected.messages.duplicate();talk_bags[key].shuffle()
   var message=talk_bags[key].pop_back()
   if selected.type=="FalanCitizen":show_text(message,[],true)
   else:show_message(str(int(message)),[],true)
  "Event","Windowman":start_script(selected.script)
  "Windowhealer","Windowhealer2":
   nurse_page()
  "Itemshop2":shop_page()
  "Techshop":shop_pet="";shop_tech=0;pet_shop_page()
  "Skillmaster":teacher_page()
  "Dengon":board_page()
  "HouseMaster":house_page()
  "Billboard":
   selected=data.npcs.filter(func(n):return int(n.id)==6377)[0];start_script(selected.script)
  "StandEnemy":begin_battle(selected.args)
  _:service_page(selected.name,[["cancel","返回"]])
 return true

func item_bag():
 if not available():return
 selected={"name":"任務物品","token":""}
 var text=""
 for id in state.items:
  if count_item(int(id))<=0:continue
  text+="%s ×%d"%[data.items[id].name,int(state.items[id])]
  if state.durability.has(id):text+=" · 耐久 %d"%int(state.durability[id])
  if int(state.equipped)==int(id):text+=" · 已裝備"
  text+="\n"
 var choices=[]
 for id in [18469,18465]:
  if count_item(id)>0:choices.append(["equip:%d"%id,"裝備 "+data.items[str(id)].name])
 choices.append(["skills","已學技能"])
 choices.append(["cancel","返回"])
 for route in [[32181,"亞斯提亞"],[32193,"往山的礦路"],[32183,"四方記憶"],[4200,"蒂娜村"]]:
  choices.insert(choices.size()-1,["travel:%d"%route[0],route[1]])
 service_page(text if not text.is_empty() else "沒有任務物品",choices)

func portrait()->Texture2D:
 if selected.has("portrait"):return selected.portrait
 var token:String=selected.get("token","")
 if token.is_empty():return null
 if not textures.has(token):
  var r:Array=data.art[token].rect;var texture=AtlasTexture.new();texture.atlas=ATLAS;texture.region=Rect2(r[0],r[1],r[2],r[3]);texture.filter_clip=true;textures[token]=texture
 return textures[token]

func show_text(text:String,choices:Array,end:bool):
 var chunks=[];var remaining=text.strip_edges()
 while remaining.length()>96:chunks.append(remaining.left(96));remaining=remaining.substr(96)
 chunks.append(remaining)
 var pages=[]
 for i in chunks.size():pages.append({"text":chunks[i],"portrait":portrait(),"options":choices if i==chunks.size()-1 else []})
 if not is_instance_valid(game.dialogue):
  var trigger=hint if is_instance_valid(hint) else Label3D.new()
  game.show_boss_dialogue(selected.name,pages,trigger,dialogue_next)
  game.dialogue.chosen.connect(choose)
  if trigger!=hint:trigger.free()
 else:game.dialogue.pages=pages;game.dialogue.page=0;game.dialogue.show_page()
 if end:pc=-1

func show_message(id:String,choices:Array=[],end:bool=false):
 assert(data.messages.has(id),"Unrecovered source message "+id)
 show_text(data.messages[id],choices,end)

func service_page(text:String,choices:Array):
 current_code=[];pc=-1;show_text(text,choices,true)

func dialogue_next():
 if pc<0:finish();return
 choose("next" if "next" in window_buttons else "ok")

func finish():
 if selected.get("type","")!="FalanCitizen":persist()
 if is_instance_valid(game.dialogue):game.close_boss_dialogue()
 current_code=[];pc=-1

func count_item(id:int)->int:return int(state.get("items",{}).get(str(id),0))

func give_item(id:int,count:int=1)->bool:
 var key=str(id)
 if not data.items.has(key) or count<1 or count_item(id)+count>999:return false
 if count_item(id)==0 and state.items.size()>=CAPACITY:return false
 state.items[key]=count_item(id)+count
 if not state.created.has(key):state.created[key]=state.elapsed
 if int(data.items[key].max_durability)>0:state.durability[key]=int(data.items[key].max_durability)
 return true

func kill_item(id:int,count:int=1)->bool:
 var key=str(id)
 if count<1 or count_item(id)<count:return false
 state.items[key]=count_item(id)-count
 if state.items[key]==0:
  state.items.erase(key);state.durability.erase(key);state.created.erase(key)
  if state.equipped==id:state.equipped=0
 return true

func value(name_:String,id:int)->float:
 match name_:
  "item":return count_item(id)
  "itemdur":return state.durability.get(str(id),0)
  "itemcreatetime":return floor((state.elapsed-float(state.created.get(str(id),state.elapsed)))/60.0)
  "equipitem":return state.equipped
  "itemspace":return CAPACITY-state.items.size()
  "nowevent":return state.now.get(str(id),0)
  "endevent":return state.done.get(str(id),0)
  "group":return 1
  "gold":return game.model.gold
  "level":return game.player.team_progression.level
  "job":return 0
  "nowtime":return 2 if game.explorer_clock.night() else 1
 push_error("Unsupported source condition "+name_);return -INF

func condition(expression:String)->bool:
 if expression.strip_edges().is_empty():return true
 for alternative in expression.to_lower().split("||"):
  var valid=true
  for term in alternative.split("&&"):
   var found=condition_pattern.search(term.strip_edges())
   assert(found!=null,"Unsupported source condition "+term)
   var left=value(found.get_string(1),int(found.get_string(2)));var right=float(found.get_string(4))
   match found.get_string(3):
    "==":valid=valid and left==right
    "!=":valid=valid and left!=right
    ">=":valid=valid and left>=right
    "<=":valid=valid and left<=right
    ">":valid=valid and left>right
    "<":valid=valid and left<right
  if valid:return true
 return false

func start_script(script:String):
 current_code=data.scripts[script];pc=0
 if current_code[0][0]=="label":execute(0);return
 for i in current_code.size():
  if current_code[i][0]=="block" and condition(current_code[i][1]):execute(i+1);return
 finish()

func choose(answer:String):
 if answer=="cancel":finish();return
 if answer.begins_with("petshop:"):pet_shop_action(answer);return
 if answer.begins_with("travel:"):
  var destination=int(answer.trim_prefix("travel:"))
  var cell:Vector2i={32181:Vector2i(94,66),32193:Vector2i(33,39),32183:Vector2i(26,33),4200:Vector2i(38,46)}[destination]
  finish();travel(destination,cell);return
 if answer.begins_with("equip:"):
  var item=int(answer.trim_prefix("equip:"))
  if count_item(item)>0:state.equipped=item
  finish();return
 if answer=="skills" or answer.begins_with("board:") or answer.begins_with("house:") or answer.begins_with("heal:") or answer.begins_with("learn:") or answer.begins_with("forget:") or answer.begins_with("cast:") or answer.begins_with("shop:") or answer.begins_with("page:"):
  service_action(answer);return
 if answer.begins_with("buy:") or answer.begins_with("sell:"):
  trade(answer);return
 if pc<0:finish();return
 # Windowman menu labels are explicit source jump targets.
 for i in current_code.size():
  if current_code[i][0]=="label" and current_code[i][1]==answer:execute(i+1);return
 var any_handlers=false
 for i in range(pc,current_code.size()):
  var op:String=current_code[i][0]
  if op in ["window","endwindow","endwind"] and not any_handlers:break
  if op in ["block","endblock","end"]:break
  if not op.begins_with("window_"):continue
  any_handlers=true
  if op=="window_"+answer and condition(current_code[i][1]):execute(i+1);return
 if any_handlers:finish()
 else:execute(pc)

func execute(start:int):
 var before=state.duplicate(true);var gold_before=game.model.gold
 for i in range(start,mini(start+512,current_code.size())):
  var op:String=current_code[i][0];var arg:String=current_code[i][1];pc=i+1
  if op in ["window","endwindow","endwind"]:
   var fields=arg.to_lower().split(",");var id=fields[0].strip_edges();window_buttons=Array(fields.slice(1))
   var choices=[]
   if "yes" in window_buttons:choices=[["yes","是"],["no","否"]]
   elif window_buttons.any(func(v):return str(v).begins_with("select[")):
    var labels=String(data.messages[id]).strip_edges().split("\n")
    for button in window_buttons:
     if str(button).begins_with("select["):
      var index=int(str(button).split("]")[0].trim_prefix("select["))-1
      choices.append([button,str(labels[maxi(0,labels.size()-3+index)]).strip_edges()])
    choices.append(["cancel","返回"])
   elif window_buttons.any(func(v):return str(v).begins_with("prev_")):
    choices=[[window_buttons.filter(func(v):return str(v).begins_with("prev_"))[0],"返回"],["cancel","關閉"]]
   if not persist():state=before;game.model.gold=gold_before;finish();return
   show_message(id,choices,op!="window");return
  if op in ["endblock","end","block"] or op.begins_with("window_"):finish();return
  if op in ["leavegroup","label"]:continue
  if op in ["giveitem","giveleak1item","killitem","setdur"]:
   var args=arg.split(",");var id=int(args[0]);var amount=int(args[1]) if args.size()>1 else 1
   var ok=true
   if op=="killitem":ok=kill_item(id,amount)
   elif op=="setdur":state.durability[str(id)]=amount
   else:ok=give_item(id,amount)
   if not ok:
    state=before;game.model.gold=gold_before;game.toast("任務物品不足或背包已滿");finish();return
  elif op in ["nowevent","endevent"]:
   var args=arg.replace("="," ").split(" ",false)
   state["now" if op=="nowevent" else "done"][args[0]]=int(args[-1])
  elif op=="addgold":
   var change=int(arg)
   if game.model.gold+change<0:state=before;game.model.gold=gold_before;finish();return
   game.model.gold+=change
  elif op=="warp":
   if not persist():state=before;game.model.gold=gold_before;finish();return
   var args=arg.split(",");var offset=0
   if args.size()>4:
    var key=selected.script+":"+str(i)
    if talk_bags.get(key,[]).is_empty():talk_bags[key]=[0,4];talk_bags[key].shuffle()
    offset=talk_bags[key].pop_back()
   var target=int(args[offset+1]);var cell=Vector2i(int(args[offset+2]),int(args[offset+3]))
   finish();travel(target,cell);return
  elif op=="encount":finish();begin_battle(arg);return
 finish()

func travel(floor_:int,cell:Vector2i):
 var id=Maps.runtime_id(floor_)
 if not Maps.owns(id) and not Tour.Indoor.Data.FLOORS.has(id):game.toast("來源目的地尚未恢復：%d"%floor_);return
 var at=Maps.source_point(id,cell) if Maps.owns(id) else Tour.Indoor.floor_info(id)[1]+Vector2(cell)*3.0
 game.transitioning=true;Tour.travel.call_deferred(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,at),"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO})

func begin_battle(arguments:String):
 if not battle_ids.is_empty():return
 var fields=arguments.split("|")
 var arrival=fields[1].split(",")
 if arrival.size()<4:return
 battle_exit=[int(arrival[1]),int(arrival[2]),int(arrival[3])]
 battle_floor=game.model.falan_floor;battle_npc=int(selected.id)
 var appearance=int(selected.graphic)
 var pets=preload("res://scripts/forest/pet_catalog.gd")
 var at=game.model.world_point(Maps.source_point(battle_floor,Vector2i(selected.cell[0],selected.cell[1])))
 if appearance==101824:
  var role=game.EnemyRoles.GATEKEEPER_HOUND
  var enemy=game.model.waves.spawn_enemy(role,at)
  enemy.skin=pets.skin("original:2956");enemy.enemy_name=selected.name;enemy.boss=true;enemy.elite=true
  enemy.patrol_radius=12.0;enemy.footprint=.9
  # The source encounter 69087 is missing; reuse the current real-time boss profile with the exact source NPC appearance.
  game.model.waves.CaveProgression.apply(enemy,[selected.name,40,1200,true],game.EnemyRoles.stats(role));battle_ids[enemy.id]=true
 else:
  var formation:Array=data.battles.get(fields[9],[])
  assert(not formation.is_empty(),"Missing source battle "+arguments)
  for i in formation.size():
   var member:Dictionary=formation[i]
   var cell=Vector2i(selected.cell[0],selected.cell[1])+Vector2i((i%2)*3,(i/2)*3)
   var safe=Maps.safe_cell(battle_floor,cell)
   var enemy=game.model.waves.spawn_enemy(game.EnemyRoles.SLIME,game.model.world_point(Maps.point(battle_floor,safe)),-1,int(member.appearance)-110388)
   game.model.waves.CaveProgression.apply(enemy,[member.name,int(member.level),500,i==0],preload("res://scripts/forest/crowd/tina_creatures.gd").STATS)
   enemy.footprint=.85;enemy.patrol_radius=14.0;enemy.enemy_name=member.name;battle_ids[enemy.id]=true
 for actor in actors:
  if int(actor.record.id)==battle_npc:actor.node.hide()

func enemy_died(event:Dictionary):
 if int(event.get("team",-1))!=0:return
 var id=int(event.get("target_id",-1))
 if mine_ids.has(id):
  mine_ids.erase(id)
  # The source lists crystal drops; real-time combat awards one per death rather than a server battle-result roll.
  if give_item(41173):persist();game.toast("取得 "+data.items["41173"].name)
  return
 if not battle_ids.has(id):return
 battle_ids.erase(int(event.target_id))
 if not battle_ids.is_empty() or battle_floor!=game.model.falan_floor:return
 state.done[str(battle_npc)]=1
 var exit=battle_exit.duplicate();battle_exit.clear();battle_floor=0
 if not persist():return
 travel.call_deferred(exit[0],Vector2i(exit[1],exit[2]))

func spawn_mine():
 var candidates=Maps.patrols(game.model.falan_floor,game.model.seed_value,16)
 var pets=preload("res://scripts/forest/pet_catalog.gd")
 for i in candidates.size():
  var member:Dictionary=data.mine[i%data.mine.size()]
  var crab=int(member.appearance)==101631
  var role=game.EnemyRoles.SLIME if crab else game.EnemyRoles.GATEKEEPER_HOUND
  var enemy=game.model.waves.spawn_enemy(role,game.model.world_point(Maps.point(game.model.falan_floor,candidates[i])),-1,4 if crab else pets.skin("original:2923"))
  game.model.waves.CaveProgression.apply(enemy,[member.name,int(member.level),280,false],preload("res://scripts/forest/crowd/tina_creatures.gd").STATS if crab else game.EnemyRoles.stats(role))
  enemy.enemy_name=member.name;enemy.patrol_radius=9.0;enemy.footprint=.85;mine_ids[enemy.id]=true

func clean_message(text:String)->String:
 var result=""
 for c in text.strip_edges():
  if c.unicode_at(0)>=32 and c.unicode_at(0)!=127:result+=c
 return result.left(120)

func commit_service(before:Dictionary,gold:float)->bool:
 if persist():return true
 state=before;game.model.gold=gold;game.settings.explorer_quests=state.duplicate(true)
 return false

func nurse_page():
 var fee=ceili(maxf(0,game.player.max_mana-game.player.mana))
 var choices=[["heal:hp","恢復體力 · 免費"],["heal:mp","體力與魔力 · %d Gold"%fee]]
 if selected.type=="Windowhealer2":choices.append(["heal:status","治療異常 · 免費"])
 choices.append(["cancel","返回"]);service_page("請選擇需要的治療。",choices)

func pet_shop_page():
 var shop:Dictionary=data.pet_shops.get(str(int(selected.get("id",0))),{})
 if shop.is_empty():return
 var choices=[]
 for tech in shop.techniques:choices.append(["petshop:tech:%d"%int(tech.id),"%s · %d G"%[tech.name,tech.fee]])
 paged_service(data.messages[shop.messages[0]],choices)

func pet_shop_action(answer:String):
 var shop:Dictionary=data.pet_shops.get(str(int(selected.get("id",0))),{})
 if selected.get("type")!="Techshop" or shop.is_empty() or Maps.source_id(game.model.falan_floor)!=int(selected.floor):return
 var pets=preload("res://scripts/forest/pet_catalog.gd")
 var action=answer.get_slice(":",1);var text=answer.substr(("petshop:"+action+":").length())
 if action=="tech":
  if not text.is_valid_int() or not shop.techniques.any(func(t):return int(t.id)==int(text)):return
  shop_tech=int(text);shop_pet="";shop_slot=-1
  var choices=[]
  for key in pets.sanitized(game.settings.forest_pet_loadout):
   var level_=game.model.team_progression.pet_experience.get(key,{"level":1}).level
   choices.append(["petshop:pet:"+key,"%s · Lv%d"%[pets.display_name(pets.skin(key),game.settings.forest_pet_names).left(12),level_]])
  var tech:Dictionary=shop.techniques.filter(func(t):return int(t.id)==shop_tech)[0]
  var note=" · 只對有 MP 的目標有效" if shop_tech==634 else ""
  paged_service("%s · Lv%d · %d MP · %d Gold\n%s%s"%[tech.name,tech.required_level,tech.mp,tech.fee,data.messages[shop.messages[3 if not choices.is_empty() else 2]],note],choices);return
 var matches=shop.techniques.filter(func(t):return int(t.id)==shop_tech)
 if matches.is_empty():return
 var tech:Dictionary=matches[0]
 if action=="pet":
  if text not in pets.sanitized(game.settings.forest_pet_loadout):return
  shop_pet=text;shop_slot=-1
 if shop_pet not in pets.sanitized(game.settings.forest_pet_loadout):return
 var level_=game.model.team_progression.pet_experience.get(shop_pet,{"level":1}).level
 if level_<int(tech.required_level):game.toast("寵物需要 Lv%d"%int(tech.required_level));return
 var slots=pets.skill_slots(pets.sanitized_skills(game.settings.forest_pet_skills),shop_pet).duplicate()
 var id="pet/%d"%shop_tech
 if action=="pet":
  var choices=[]
  for slot in pets.MAX_SKILLS:choices.append(["petshop:slot:%d"%slot,"%d · %s"%[slot+1,pets.SKILLS.get(slots[slot],"空欄")]])
  paged_service(data.messages[shop.messages[4]],choices);return
 if action not in ["slot","confirm"] or not text.is_valid_int():return
 var slot=int(text)
 if slot<0 or slot>=pets.MAX_SKILLS:return
 if id in slots:game.toast("這隻寵物已學會此技能");return
 if action=="slot":
  shop_slot=slot
  shop_previous_skill=slots[slot]
  service_page("%s\n%s · %d Gold · %s"%[pets.display_name(pets.skin(shop_pet),game.settings.forest_pet_names),tech.name,tech.fee,"替換 "+pets.SKILLS.get(slots[slot],slots[slot]) if not slots[slot].is_empty() else "使用空欄 %d"%(slot+1)],[["petshop:confirm:%d"%slot,"確認學習"],["cancel","取消"]]);return
 if shop_slot!=slot:return
 if slots[slot]!=shop_previous_skill:shop_slot=-1;game.toast("技能已變更，請重新選擇技能欄");return
 if game.model.gold<int(tech.fee):game.toast(data.messages[shop.messages[1]]);return
 var before=state.duplicate(true);var gold=game.model.gold;var old_skills=game.settings.forest_pet_skills
 slots[slot]=id
 var skills=old_skills.duplicate(true);skills[shop_pet]=slots;game.settings.forest_pet_skills=pets.sanitized_skills(skills)
 var taught:Array=state.pet_training.get_or_add(shop_pet,[])
 if shop_tech not in taught:taught.append(shop_tech)
 game.model.gold-=int(tech.fee)
 if not commit_service(before,gold):game.settings.forest_pet_skills=old_skills;return
 game.army_runtime.reconcile_pet_loadout();game.forest_ui.sync()
 game.toast("學會 "+str(tech.name));shop_pet="";shop_tech=0;pet_shop_page()

func teacher_page():
 var fields=selected.args.split("|");var id=fields[0];var skill:Dictionary=data.skills[id]
 var choices=[]
 if state.learned.has(id):choices.append(["forget:"+id,"忘記 "+skill.name])
 else:choices.append(["learn:"+id,"學習 · %d Gold"%int(skill.fee)])
 choices.append(["cancel","返回"])
 service_page(data.messages[fields[1]].strip_edges()+"\n"+skill.name+" · "+data.messages[fields[3]].strip_edges(),choices)

func skills_page():
 var choices=[]
 for id in state.learned:
  if data.skills.has(id):choices.append(["cast:"+id,data.skills[id].name])
 selected={"name":"已學技能","token":""}
 paged_service("祈禱強化對應法術 20 秒；無效屏障抵擋一次對應攻擊。每次消耗 20 MP。",choices)

func paged_service(title:String,choices:Array,page:int=0):
 service_choices=choices;service_title=title;service_page_index=clampi(page,0,maxi(0,(choices.size()-1)/4))
 var buttons=choices.slice(service_page_index*4,service_page_index*4+4)
 if service_page_index>0:buttons.append(["page:%d"%(service_page_index-1),"上一頁"])
 if (service_page_index+1)*4<choices.size():buttons.append(["page:%d"%(service_page_index+1),"下一頁"])
 buttons.append(["cancel","返回"]);service_page(title,buttons)

func shop_page(mode:String="",page:int=0):
 var shop:Dictionary=data.shops.get(str(int(selected.get("id",0))),{})
 if selected.get("type")!="Itemshop2" or shop.is_empty():return
 if mode.is_empty():
  var options=[]
  if int(shop.mode)&1:options.append(["shop:buy","購買物品"])
  if int(shop.mode)&2:options.append(["shop:sell","出售物品"])
  options.append(["cancel","返回"]);service_page(data.messages[shop.messages[0]],options);return
 if mode not in ["buy","sell"] or not (int(shop.mode)&(1 if mode=="buy" else 2)):return
 var choices=[];var rate=int(shop.buy_rate if mode=="buy" else shop.sell_rate)
 for id in (shop.stock if mode=="buy" else state.items.keys()):
  var item:Dictionary=data.items[str(int(id))]
  if mode=="sell" and (count_item(int(id))<=0 or item.price<=0 or not shop.accept_types.has(item.type)):continue
  var price=int(int(item.price)*rate/100.0)
  choices.append([mode+":"+str(int(id)),item.name+(" ×%d"%count_item(int(id)) if mode=="sell" else "")+" · %d Gold"%price])
 paged_service(data.messages[shop.messages[1 if mode=="buy" else 4]]+("\n沒有可出售的物品。" if choices.is_empty() else ""),choices,page)

func trade(answer:String):
 var shop:Dictionary=data.shops.get(str(int(selected.get("id",0))),{})
 if selected.get("type")!="Itemshop2" or shop.is_empty() or Maps.source_id(game.model.falan_floor)!=int(selected.floor):return
 var text=answer.get_slice(":",1)
 if not text.is_valid_int():return
 var id=int(text);var buying=answer.begins_with("buy:")
 if not (int(shop.mode)&(1 if buying else 2)) or not data.items.has(str(id)):return
 var item:Dictionary=data.items[str(id)]
 if (buying and not shop.stock.has(id)) or (not buying and (item.price<=0 or not shop.accept_types.has(item.type))):return
 var price=int(int(item.price)*int(shop.buy_rate if buying else shop.sell_rate)/100.0)
 var quantity=1
 if not buying:
  if answer.get_slice_count(":")==2:
   var owned=count_item(id)
   if owned<=0:return
   var options=[]
   var counts=[]
   for amount in [1,mini(5,owned),mini(10,owned),owned]:
    if amount in counts:continue
    counts.append(amount);options.append(["sell:%d:%d"%[id,amount],"出售 %d · %d Gold"%[amount,price*amount]])
   options.append(["shop:sell","返回"]);service_page("%s ×%d · 每件 %d Gold"%[item.name,owned,price],options);return
  var amount=answer.get_slice(":",2)
  if answer.get_slice_count(":")!=3 or not amount.is_valid_int():return
  quantity=int(amount)
  if quantity<1 or quantity>count_item(id) or quantity>999:return
  price*=quantity
 var before=state.duplicate(true);var gold=game.model.gold
 if buying:
  if gold<price:game.toast("Gold 不足");return
  if not give_item(id):game.toast("背包已滿");return
  game.model.gold-=price
 else:
  if not kill_item(id,quantity):game.toast("沒有可出售的物品");return
  game.model.gold+=price
 if not commit_service(before,gold):return
 game.toast(data.messages[shop.messages[5]])
 shop_page("buy" if buying else "sell",service_page_index)

func board_page():
 var text="本機留言板"
 for message in state.board:text+="\n"+message
 service_page(text,[["board:write","寫留言"],["board:clear","清除留言"],["cancel","返回"]])

func house_page():
 var id=selected.args.split("|")[4]
 var active=state.house.get("id","")==id and float(state.house.get("until",0))>Time.get_unix_time_from_system()
 var choices=[["house:rent","續租 · 500 Gold" if active else "租用 · 500 Gold"]]
 if active:choices.append(["house:enter","進入房屋"])
 choices.append(["cancel","返回"])
 service_page("租期 14 天 · 同時只能承租一間。"+("\n剩餘 %d 天"%ceili((float(state.house.until)-Time.get_unix_time_from_system())/86400.0) if active else ""),choices)

func house_door()->bool:
 var id:String=state.house.get("id","")
 if not data.houses.has(id):return false
 if game.model.falan_floor==1850:
  var row:Dictionary=data.houses[id]
  var at=game.model.world_point(Maps.source_point(1850,Vector2i(row.exit[0],row.exit[1])))
  if float(state.house.until)<=Time.get_unix_time_from_system() or game.player.position.distance_to(at)<1.25*game.model.falan_scale:
   var native:Array=row.raw;travel(4200,Vector2i(int(native[5]),int(native[6])));return true
 elif Maps.source_id(game.model.falan_floor)==4200 and float(state.house.until)>Time.get_unix_time_from_system():
  var notice=data.npcs.filter(func(n):return n.type=="HouseMaster" and n.args.split("|")[4]==id)
  if not notice.is_empty():
   var front=notice[0].cell;var cell=Vector2i(front[0]-2,front[1]-2) if id=="4803" else Vector2i(64,42) if id=="4805" else Vector2i(54,38)
   if game.player.position.distance_to(game.model.world_point(Maps.source_point(game.model.falan_floor,cell)))<1.25*game.model.falan_scale:
    var row:Dictionary=data.houses[id];travel(1850,Vector2i(row.entry[0],row.entry[1]));return true
 return false

func service_action(answer:String):
 if answer=="skills":skills_page();return
 if answer.begins_with("page:"):paged_service(service_title,service_choices,int(answer.trim_prefix("page:")));return
 if answer.begins_with("shop:") and selected.get("type")=="Itemshop2":shop_page(answer.trim_prefix("shop:"));return
 if answer=="board:write" and selected.get("type")=="Dengon":
  service_page("本機留言 · 免費",[["board:post","張貼"],["cancel","返回"]])
  game.dialogue.pages[-1].entry=true;game.dialogue.show_page();game.dialogue.entry.grab_focus();return
 if answer=="board:clear" and selected.get("type")=="Dengon":
  service_page("清除這台電腦保存的所有留言？",[["board:erase","清除"],["cancel","取消"]]);return
 var before=state.duplicate(true);var gold=game.model.gold
 if answer.begins_with("heal:") and selected.get("type") in ["Windowhealer","Windowhealer2"]:
  var option=answer.trim_prefix("heal:")
  if option not in ["hp","mp","status"] or option=="status" and selected.type!="Windowhealer2":return
  var fee=ceili(maxf(0,game.player.max_mana-game.player.mana)) if option=="mp" else 0
  if gold<fee:game.toast("Gold 不足");return
  game.model.gold-=fee
  if not commit_service(before,gold):return
  if option in ["hp","mp"]:game.player.hp=game.player.max_hp
  if option=="mp":game.player.mana=game.player.max_mana
  if option=="status":game.player.clear_cursed_afflictions()
 elif answer.begins_with("learn:") or answer.begins_with("forget:"):
  var id=answer.split(":")[1]
  if selected.get("type")!="Skillmaster" or selected.args.split("|")[0]!=id or not data.skills.has(id):return
  if answer.begins_with("learn:"):
   if state.learned.has(id):return
   var fee=int(data.skills[id].fee)
   if gold<fee:game.toast("Gold 不足");return
   state.learned[id]=1;game.model.gold-=fee
  else:
   if not state.learned.has(id):return
   state.learned.erase(id)
  if not commit_service(before,gold):return
  teacher_page();return
 elif answer.begins_with("cast:"):
  var id=answer.trim_prefix("cast:")
  if not state.learned.has(id) or not data.skills.has(id):return
  if game.player.mana<20:game.toast("魔力不足");return
  if int(id)==54 and (prayer==0 or prayer_left<=0):game.toast("請先施放祈禱");return
  if game.player.spell_loadout.magic_seal_left>0:game.toast("魔法封印中");return
  game.player.mana-=20
  if int(id) in [59,60]:ward=int(id);ward_left=20
  elif int(id)==54:
   prayer={50:53,53:50,51:52,52:51}.get(prayer,0)
  else:prayer=int(id);prayer_left=20
  game.burst(game.player.position+Vector3.UP,Color("7bccff"),12)
 elif answer in ["board:post","board:erase"] and selected.get("type")=="Dengon":
  if answer=="board:post":
   var text=clean_message(game.dialogue.entry.text)
   if text.is_empty():return
   state.board.push_front(text);state.board=state.board.slice(0,10)
  else:state.board.clear()
  if not commit_service(before,gold):return
  board_page();return
 elif answer in ["house:rent","house:enter"] and selected.get("type")=="HouseMaster":
  var id=selected.args.split("|")[4]
  if not data.houses.has(id):return
  var now=Time.get_unix_time_from_system()
  if answer=="house:rent":
   if gold<500:game.toast("Gold 不足");return
   var until=maxf(now,float(state.house.get("until",0))) if state.house.get("id")==id else now
   if until+14*86400>now+70*86400:game.toast("租期上限為 70 天");return
   state.house={"id":id,"until":until+14*86400};game.model.gold-=500
   if not commit_service(before,gold):return
   house_page();return
  if state.house.get("id")!=id or float(state.house.get("until",0))<=now:return
  var row:Dictionary=data.houses[id];finish();travel(1850,Vector2i(row.entry[0],row.entry[1]));return
 else:return
 finish()

func incoming_damage(amount:float,magical:bool)->float:
 if game.model==null or Tour.area(game.model).is_empty() or amount<=0:return amount
 if ward_left>0 and ward==(60 if magical else 59):
  ward=0;ward_left=0;game.burst(game.player.position+Vector3.UP,Color("7bccff"),8);return 0
 return amount

func magic_multiplier(hero:Node)->float:
 if hero!=game.player or prayer_left<=0 or Tour.area(game.model).is_empty():return 1.0
 var id:String=hero.spell_loadout.casting_id
 if hero.spell_loadout.current!=null:id=hero.spell_loadout.current.spec.id
 var element={"meteor":50,"ice":51,"fire":52,"wind":53}.get(id.get_slice("/",1),0)
 # shortcut: single-rank Explorer prayers affect matching player spells; full server elemental affinities are not available.
 return 1.2 if element==prayer else 1.0
