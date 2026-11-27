extends RefCounted
## Regional quest/battle state, consumed by the existing NPC, travel and native army owners.
const Bank=preload("res://scripts/forest/crowd/university_region_sprites.gd")
const ITEMS="university_quest_items"
const BATTLES="university_battles"
const SLAIN="university_battle_slain"
const BOSSES={
 "sylph":{"map":59752,"cell":Vector2i(98,110),"encounter":308082,"win":[59752,130,143],"actors":["808112"]},
 "zombie":{"map":51031,"cell":Vector2i(281,370),"encounter":12023,"win":[],"actors":[]},
 "dijiro":{"map":-1,"cell":Vector2i.ZERO,"encounter":12024,"win":[15531,12,64],"actors":[]},
 "lizard":{"map":16520,"cell":Vector2i(10,3),"encounter":12009,"win":[402,318,136],"actors":[]},
 "altar":{"map":4501,"cell":Vector2i(10,9),"encounter":12012,"win":[4502,9,10],"actors":["6457"]},
 "ruby":{"map":20527,"cell":Vector2i(46,47),"encounter":10009,"win":[20530,45,47],"actors":["6464"]},
 "fribo":{"map":20414,"cell":Vector2i(27,11),"encounter":10006,"win":[20428,26,12],"actors":["6465"]},
 "doctor":{"map":15535,"cell":Vector2i(28,32),"encounter":12026,"win":[15535,28,11],"actors":["5251","5256","5257"]},
 "abyss":{"map":15539,"cell":Vector2i(20,8),"encounter":12027,"win":[],"actors":["5269"]},
 "azure":{"map":4409,"cell":Vector2i(58,43),"encounter":40314,"win":[32154,55,48],"actors":["1102643"]},
}

static func has_item(tree:SceneTree,key:String)->bool:return tree.get_meta(ITEMS,{}).get(key,false)
static func romance_eligible(tree:SceneTree)->bool:
 return has_item(tree,"source_item_40808") or has_item(tree,"source_item_40804") and has_item(tree,"source_item_40806")
static func specification(key:String,seed_:int)->Dictionary:
 if key.begins_with("sokia:"):return load("res://scripts/forest/forest_sokia_cape.gd").specification(key)
 if key.begins_with("east:"):return load("res://scripts/forest/forest_east_battles.gd").specification(key)
 var spec:Dictionary=BOSSES[key].duplicate()
 if key=="dijiro":
  var original=load("res://scripts/forest/forest_original_maps.gd");var dungeon=original.generated()
  var id:int=dungeon.floor_id("tunnel",dungeon.count("tunnel",seed_));var state=original.state(id,seed_)
  spec.map=id;spec.cell=Vector2i(((dungeon.landing(id,seed_,false)-state.origin)/3.).round())
 return spec
static func bank_for(key:String)->Script:
 if key.begins_with("sokia:"):return load("res://scripts/forest/forest_sokia_cape.gd")
 return load("res://scripts/forest/crowd/east_region_sprites.gd") if key.begins_with("east:") else Bank
static func item(tree:SceneTree,key:String,present:bool=true):
 var items:Dictionary=tree.get_meta(ITEMS,{})
 items[key]=present;tree.set_meta(ITEMS,items)

static func confirm(game,speaker:String,text:String,accept:Callable,decline:Callable=Callable()):
 var trigger=Label3D.new()
 game.show_boss_dialogue(speaker,[{"text":text,"portrait":null,"options":[["yes","是"],["cancel","否"]]}],trigger,game.close_boss_dialogue)
 trigger.free()
 game.dialogue.chosen.connect(func(answer:String):
  game.close_boss_dialogue()
  if answer=="yes":accept.call()
  elif decline.is_valid():decline.call())

static func eligible(tree:SceneTree,rank:int)->bool:
 var items:Dictionary=tree.get_meta(ITEMS,{})
 return bool(items.get("opener",false)) and int(items.get("job_rank",0))>=rank

static func action(game,key:String)->bool:
 var tree:SceneTree=game.get_tree()
 if key.begins_with("ice:"):
  var event:Dictionary=preload("res://assets/maps/falan/university_region/ice_events.gd").EVENTS.get(key.trim_prefix("ice:"),{})
  if event.is_empty():return true
  if event.kind=="torch":
   if not has_item(tree,"torch") and not has_item(tree,"blue_torch"):item(tree,"torch");game.toast("獲得火把")
  elif event.kind=="flame":
   if not has_item(tree,"torch"):game.toast("需要火把");return true
   confirm(game,"蒼炎","用火把點燃蒼炎？",func():
    if not has_item(tree,"torch"):return
    item(tree,"torch",false);item(tree,"blue_torch");game.toast("獲得蒼炎的火把"))
  else:
   if not has_item(tree,"blue_torch"):game.toast("燭台需要蒼炎的火把");return true
   confirm(game,"燭台","用蒼炎融化冰雪？",func():
    if not has_item(tree,"blue_torch"):return
    item(tree,"blue_torch",false);item(tree,"torch")
    travel(game,int(event.target[0]),Vector2i(event.target[1],event.target[2])))
 elif key=="hall_ami":
  if has_item(tree,"source_item_40809"):game.toast("亞美正在魔法大學研究新的學科")
  elif has_item(tree,"source_item_40808"):
   item(tree,"source_item_40808",false);item(tree,"source_item_40809");game.toast("獲得愛神之淚")
  elif has_item(tree,"source_item_40804") and has_item(tree,"source_item_40806"):
   item(tree,"source_item_40804",false);item(tree,"source_item_40806",false);item(tree,"source_item_40807");game.toast("獲得亞美的卡片")
 elif key=="four_beast_memory":
  var unlocked=has_item(tree,"four_beast_memory_access")
  var gifts=["source_item_41146","source_item_41149","source_item_41151","source_item_41153"]
  if not unlocked and not gifts.all(func(gift):return has_item(tree,gift)):game.toast("需要四聖獸的信物");return true
  confirm(game,"無名之碑","閱讀四方守護聖獸的回憶？",func():
   if not has_item(tree,"four_beast_memory_access"):
    for gift in gifts:item(tree,gift,false)
    var items:Dictionary=tree.get_meta(ITEMS,{});items.four_beast_memory_access=true;items.source_item_41217=3;tree.set_meta(ITEMS,items)
   travel(game,32183,Vector2i(26,33)))
 elif key=="tina_child_return":
  if has_item(tree,"source_item_41174"):
   item(tree,"source_item_41174",false);item(tree,"source_item_41178");travel(game,4200,Vector2i(38,46))
  elif not has_item(tree,"source_item_41176"):
   confirm(game,"小遙","幫忙尋找失散的哥哥？",func():item(tree,"source_item_41176"))
  else:game.toast("小遙正在等待哥哥的消息")
 elif key=="azure_wall":
  confirm(game,"快要崩裂的牆壁","穿過牆壁？",func():travel(game,4403,Vector2i(31,38)))
 elif key=="azure_medicine":item(tree,"azure_medicine");game.toast("獲得小龍的藥")
 elif key=="doctor_researcher":
  if not has_item(tree,"doctor_talisman"):game.toast("帕席需要塔比歐的細胞");return true
  item(tree,"doctor_talisman",false);item(tree,"moon_hoe");game.toast("獲得月之鋤頭")
 elif key=="beast_key":
  if not eligible(tree,1):game.toast("需要「開啟者」與正式職業階級");return true
  item(tree,"beast_key");game.toast("獲得神官的鑰匙")
 elif key=="beast_entry":
  if not has_item(tree,"beast_key"):game.toast("先向傑諾瓦醫院的神官取得鑰匙");return true
  item(tree,"beast_key",false);travel(game,16510,Vector2i(25,20))
 elif key=="beast_grayson":
  if not has_item(tree,"beast_scale"):game.toast("葛雷森需要地龍的鱗片");return true
  item(tree,"beast_scale",false);travel(game,16511,Vector2i(26,65))
 elif key in ["beast_monk_room","beast_witch_room"]:
  var monk=key=="beast_monk_room";var job=int(tree.get_meta(ITEMS,{}).get("job_id",0))
  if job<(62 if monk else 132) or job>(67 if monk else 137):game.toast("守衛等待合資格的僧侶" if monk else "小愛等待合資格的巫師");return true
  confirm(game,"守衛" if monk else "巫師小愛","進入房間？",func():travel(game,16514 if monk else 16515,Vector2i(12,17) if monk else Vector2i(10,17)))
 elif key=="beast_witch_exit":
  confirm(game,"巫師吉娜","離開這個房間？",func():travel(game,16512,Vector2i(39,52)))
 elif key=="east_priest":
  if not eligible(tree,2):game.toast("需要「開啟者」與王宮階級");return true
  travel(game,14003,Vector2i(9,42))
 elif key=="cabin_return":
  confirm(game,"捷徑指引者","支付 1000G 返回莎蓮娜？",func():
   if not has_item(tree,"return_ticket") and not has_item(tree,"source_item_18448") and game.model.gold<1000:game.toast("金錢不足");return
   if has_item(tree,"return_ticket"):item(tree,"return_ticket",false)
   elif has_item(tree,"source_item_18448"):item(tree,"source_item_18448",false)
   else:game.model.gold-=1000
   travel(game,402,Vector2i(81,191)))
 elif key=="ice_entrance":
  if ["white_memory","black_memory","white_will","black_will","bewildered_will"].any(func(id):return has_item(tree,id)):game.toast("龍的記憶封住了道路");return true
  if not tree.get_meta(ITEMS,{}).get("dragon_trial",false):game.toast("尚未完成前往永久凍土的試煉");return true
  travel(game,15536,Vector2i(15,15))
 elif key=="abyss_approach":
  if ["white_memory","black_memory","white_will","black_will","bewildered_will"].any(func(id):return has_item(tree,id)):game.toast("龍的記憶封住了道路");return true
  if not tree.get_meta(ITEMS,{}).get("wind_tower",false):game.toast("凱歐斯威普等待風之塔的試煉完成");return true
  # Classic quest references corroborate Wind Tower here. The pinned script's EndEvent18/fishing tail is inconsistent.
  confirm(game,"凱歐斯威普","已經有所覺悟了嗎？",func():travel(game,15531,Vector2i(49,32),Vector2i.RIGHT))
 elif key in ["white_messenger","black_messenger"]:
  if not has_item(tree,"world_heart"):game.toast("龍的使者等待世界之心");return true
  var white=key=="white_messenger"
  confirm(game,"龍的使者","接受龍的記憶，返回召喚之間？",func():item(tree,"white_memory" if white else "black_memory");summon(game),func():
   travel(game,15522 if white else 15531,Vector2i(40,8) if white else Vector2i(46,28)))
 elif key=="doctor_ghoul":
  if ["doctor_badge","nurse_hat","doctor_necklace"].any(func(id):return has_item(tree,id)):travel(game,15531,Vector2i(29,51))
  else:
   confirm(game,"守門的食屍鬼","支付 30000G 購買項鍊並通過？",func():
    if game.model.gold<30000:travel(game,15535,Vector2i(44,15));return
    game.model.gold-=30000;item(tree,"doctor_necklace");travel(game,15531,Vector2i(29,51)),func():travel(game,15535,Vector2i(44,15)))
 elif key=="doctor_bars":travel(game,15531,Vector2i(22,35))
 elif key=="doctor_kick":travel(game,400,Vector2i(280,364))
 elif key=="ruby_reward":item(tree,"prison_flame");travel(game,20508,Vector2i(45,47))
 elif key=="lizard_hospital":
  if not has_item(tree,"casbar_letter"):game.toast("吉可穆特需要卡斯巴爾的推薦信");return true
  if not has_item(tree,"lizard_reward"):game.toast("吉可穆特需要團長的鎚子");return true
  item(tree,"casbar_letter",false);item(tree,"lizard_reward",false);item(tree,"captain_letter");game.toast("獲得吉可穆特的信")
 elif key=="altar_priest":travel(game,401,Vector2i(26,186))
 elif key=="prison_flag":travel(game,20001,Vector2i(26,32))
 elif key=="prison_complete":item(tree,"dragon_trial");summon(game)
 elif key=="music_secret":travel(game,4432,Vector2i(24,12))
 elif key=="book_research":
  if has_item(tree,"source_item_18488") or has_item(tree,"source_item_18565"):game.toast("奇夏爾正在等待書本的調查結果");return true
  confirm(game,"奇夏爾","前往研究室？",func():travel(game,4402,Vector2i(21,13)))
 elif key=="curse_password":
  confirm(game,"牆壁","念出暗語「咒術」，進入密道？",func():travel(game,15006,Vector2i(31,22)))
 elif key=="curse_master_entry":
  var job=int(tree.get_meta(ITEMS,{}).get("job_id",0))
  var qualified=(job>=80 and job<90) or has_item(tree,"source_item_18108")
  confirm(game,"卡克","進入方涅爾的房間？",func():travel(game,15012 if qualified else 15011,Vector2i(10,19)))
 elif key=="curse_recommendation":
  var job=int(tree.get_meta(ITEMS,{}).get("job_id",0))
  if job>=80 and job<90 and not has_item(tree,"source_item_18380"):
   confirm(game,"希索普","領取咒器？",func():item(tree,"source_item_18380"))
  elif has_item(tree,"source_item_18378"):
   confirm(game,"希索普","交出紫唸珠，換取咒術師推薦信？",func():
    item(tree,"source_item_18378",false);item(tree,"source_item_18380",false);item(tree,"source_item_18108");game.toast("獲得咒術師推薦信"))
  elif not has_item(tree,"source_item_18380"):
   confirm(game,"希索普","領取咒器？",func():item(tree,"source_item_18380"))
  else:game.toast("希索普正在等待紫唸珠")
 elif key=="beast_story":
  var job=int(tree.get_meta(ITEMS,{}).get("job_id",0))
  if (job>=11 and job<=167) or (job>=431 and job<=447) or (job>=1001 and job<=1007):
   item(tree,"beast_story");game.toast("聽完身世，獲得引導者的認可")
  else:game.toast("引導者等待合資格的旅人")
 elif key=="astia_entry":
  if not has_item(tree,"beast_story"):game.toast("神官等待獲得引導者認可的旅人");return true
  confirm(game,"阿斯提亞神官","通過參道前往阿斯提亞？",func():travel(game,14010,Vector2i(7,34)))
 elif key in ["abanis_teleport","jenova_teleport"]:
  var abanis=key=="abanis_teleport";var registered="abanis_teleport_registered" if abanis else "jenova_teleport_registered"
  if has_item(tree,"source_item_18441") or has_item(tree,"source_item_18440"):game.toast("攜帶的道具無法通過傳送");return true
  if not has_item(tree,registered):item(tree,registered);game.toast(("阿巴尼斯村" if abanis else "傑諾瓦鎮")+"傳送點已登記");return true
  confirm(game,"傳送石管理人","支付 375G 前往城堡啟程之間？",func():
   if has_item(tree,"source_item_18660"):pass
   elif has_item(tree,"source_item_18448"):item(tree,"source_item_18448",false)
   elif game.model.gold>=375:game.model.gold-=375
   else:game.toast("金錢不足");return
   hub_travel(game,1522,Vector2i(37,4) if abanis else Vector2i(15,4)))
 elif key=="decree_shanti":
  var decree=load("res://scripts/forest/forest_holy_decree.gd")
  if not decree.cleared(tree.get_meta("frostpass_slain",{}),decree.floor_id(60),game.model.seed_value):game.toast("雙王的封印尚未解除");return true
  travel(game,5014,Vector2i(8,6))
 elif key=="decree_shanti_return":travel(game,24074,Vector2i(20,26))
 elif key in ["decree_shanti_shop","decree_shanti_bonus_shop"]:
  confirm(game,"香蒂","花費 1000G 購買改造圖，並返回莎蓮娜？",func():
   if game.model.gold<1000:game.toast("金錢不足");return
   var choices=[["18641",60],["18642",60],["18643",60],["18644",160],["18645",160],["18646",160],["18647",210],["18648",50],["18649",50],["18650",50],["18651",50],["18652",50],["18653",1],["18654",1],["18655",1],["18656",1],["18657",1]]
   if key=="decree_shanti_bonus_shop":choices=[["623539",100],["623540",100],["623541",100],["623542",80],["623543",80],["623544",80],["623534",50],["623535",50],["623536",50],["623537",50],["18934",10],["18935",10],["18936",10],["18937",10],["18938",10]]
   var waves=game.model.waves;var bags:Dictionary=tree.get_meta("university_drop_bags",{});var reward=Bank.Snow.weighted(bags,"shanti-5014-"+key,choices,waves.rng);tree.set_meta("university_drop_bags",bags)
   var rewards:Dictionary=tree.get_meta("university_shanti_rewards",{});rewards[reward]=int(rewards.get(reward,0))+1;tree.set_meta("university_shanti_rewards",rewards)
   game.model.gold-=1000;game.toast("獲得改造圖？");travel(game,402,Vector2i(53,162)))
 elif key=="sylph_reward":
  if not tree.get_meta(BATTLES,{}).get("sylph",{}).get("complete",false):return true
  var items:Dictionary=tree.get_meta(ITEMS,{})
  if int(items.get("signed_stamps",0))==5:items.signed_stamps=6;tree.set_meta(ITEMS,items);game.toast("希爾弗蓋下第六個印記")
 else:return false
 return true

static func summon(game):
 # The summon room is an existing independently-owned hub, not part of the regional reconstruction.
 hub_travel(game,1530,Vector2i(15,6))

static func hub_travel(game,id:int,cell:Vector2i):
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 var indoor=tour.Indoor
 var at:Vector2=indoor.Data.FLOORS[id][1]+Vector2(cell)*3.
 tour.enter_link(game,"interior",{"to":"freyja_door","floor":id,"arrival":at,"yaw":0.},Vector2.ZERO)

static func landing_cell(map_:int,cell:Vector2i,past_marker:Vector2i,seed_:int)->Vector2i:
 var original=load("res://scripts/forest/forest_original_maps.gd")
 var id:int=original.runtime_id(map_)
 if past_marker!=Vector2i.ZERO:
  var state=original.state(id,seed_);var local=cell-original.crop(id).position
  var cells:int=state.size.x*state.size.y
  # Source 17644 is an invisible transfer barrier. Land just beyond it, never inside a collision cell.
  while Rect2i(Vector2i.ZERO,state.size).has_point(local) and not original.open(state.bits,state.size,local) and state.raw.decode_u16(20+(cells+local.y*state.size.x+local.x)*2)==17644:
   local+=past_marker;cell+=past_marker
 return cell

static func travel(game,map_:int,cell:Vector2i,past_marker:Vector2i=Vector2i.ZERO):
 var original=load("res://scripts/forest/forest_original_maps.gd")
 var id:int=original.runtime_id(map_)
 cell=landing_cell(map_,cell,past_marker,game.model.seed_value)
 var link:Dictionary=original.door(Vector2.ZERO,id,original.source_point(id,cell))
 load("res://scripts/forest/forest_falan_tour.gd").enter_link(game,"interior",link,Vector2.ZERO)

static func begin(game,key:String,poison_answer:int=-1,retry:bool=false)->bool:
 var tree:SceneTree=game.get_tree();var spec=specification(key,game.model.seed_value)
 var source=bank_for(key)
 var battles:Dictionary=tree.get_meta(BATTLES,{})
 var exploring=is_instance_valid(game.get("explore_access")) and game.explore_access.enabled()
 if exploring and tree.has_meta("university_victory"):game.toast("戰鬥結算中");return false
 if battles.get(key,{}).get("complete",false):
  if not exploring or not retry:return false
  var slain:Dictionary=tree.get_meta(SLAIN,{})
  for slot in range(int(battles[key].get("phase",0))*1000+battles[key].members.size()):slain.erase(slain_key(key,int(battles[key].map),slot))
  tree.set_meta(SLAIN,slain);battles.erase(key);tree.set_meta(BATTLES,battles)
 if battles.has(key):return true
 if not exploring and key=="doctor" and has_item(tree,"doctor_poison") and poison_answer<0:
  confirm(game,"黑暗醫生阿魯巴斯","使用畢克銀酸？",func():begin(game,key,1),func():begin(game,key,0));return true
 var chain_id:int=spec.encounter;var seen={}
 while chain_id>0 and not seen.has(chain_id):
  seen[chain_id]=true
  var chain:Dictionary=source.data().bosses[str(chain_id)]
  for group in chain.groups:
   for member in source.data().groups[group[0]].details:
    if source.data().species[member.species].bank=="unavailable":game.toast("原始戰鬥的攻擊時序尚待確認");return false
  chain_id=int(chain.next_encounter)
 if not exploring and key=="azure":
  if not has_item(tree,"azure_medicine"):game.toast("小龍需要的藥 · 先與小龍交談");return false
  # The source victory room is still unavailable; never trap a player after consuming the medicine.
  game.toast("青龍的試煉尚未開放");return false
 if not exploring and key=="abyss":
  if has_item(tree,"world_heart"):return false
  if not has_item(tree,"god_eye"):game.toast("壁畫需要神眼");return false
  item(tree,"god_eye",false)
 if not exploring and key=="sylph" and int(tree.get_meta(ITEMS,{}).get("signed_stamps",0))!=5:game.toast("希爾弗等待帶有五個印記的信");return false
 var encounter:int=12025 if not exploring and key=="doctor" and has_item(tree,"doctor_poison") and poison_answer==1 else int(spec.encounter)
 if key=="doctor" and encounter==12025:item(tree,"doctor_poison",false)
 phase(game,key,encounter,0)
 return true

static func phase(game,key:String,encounter:int,number:int):
 var tree:SceneTree=game.get_tree();var battles:Dictionary=tree.get_meta(BATTLES,{})
 var source=bank_for(key)
 var zone:Dictionary=source.data().bosses[str(encounter)]
 var waves=game.model.waves
 var group_id:String=Bank.Snow.weighted(waves.snow_bags,"regional-boss:"+key,zone.groups,waves.rng)
 var group:Dictionary=source.data().groups[group_id]
 var members=[]
 for i in group.details.size():
  var row:Dictionary=group.details[i]
  var count_=int(Bank.Snow.draw(waves.snow_bags,"regional-retinue:%s:%d"%[key,i],range(int(row.count[0]),int(row.count[1])+1),waves.rng))
  for n in count_:
   var member:Dictionary=row.duplicate();member.boss=i==0 and n==0 and key!="zombie";member.level=int(Bank.Snow.draw(waves.snow_bags,"regional-boss-level:%s:%d"%[key,i],range(int(row.level[0]),int(row.level[1])+1),waves.rng))
   members.append(member)
 battles[key]={"map":int(specification(key,game.model.seed_value).map),"members":members,"complete":false,"phase":number,"encounter":encounter,"advance":false};tree.set_meta(BATTLES,battles)
 if key.begins_with("east:") or key.begins_with("sokia:"):battles[key].area=specification(key,game.model.seed_value).area
 waves.spawned=0;game.toast(str(group.raw[0]))

static func advance(game):
 var tree:SceneTree=game.get_tree();var key=active(tree,game.model.falan_floor,game.model.falan_area)
 if key.is_empty():return
 var battle:Dictionary=tree.get_meta(BATTLES,{})[key]
 if not battle.get("advance",false):return
 var zone:Dictionary=bank_for(key).data().bosses[str(int(battle.encounter))]
 # The first altar formation retreats after two deaths; retiring them awards no extra kills or XP.
 var runtime=game.army_runtime
 for enemy in game.model.enemies.values().filter(func(row):return row.get("university_battle","")==key):
  var handle:int=runtime.handles.get(enemy.id,0)
  if handle!=0:runtime.despawn(handle)
  game.model.enemies.erase(enemy.id)
 phase(game,key,int(zone.next_encounter),int(battle.phase)+1)

static func active(tree:SceneTree,id:int,area:String="")->String:
 for key in tree.get_meta(BATTLES,{}):
  if not area.is_empty() and tree.get_meta(BATTLES,{})[key].get("area",area)!=area:continue
  if int(tree.get_meta(BATTLES,{})[key].map)==id and not tree.get_meta(BATTLES,{})[key].complete:return key
 return ""

static func slain_key(key:String,map_:int,slot:int)->Variant:
 return "%s:%d"%[key,slot] if key.begins_with("east:") or key.begins_with("sokia:") else Vector2i(map_,slot)

static func hidden_actor(tree:SceneTree,id:String)->bool:
 for key in tree.get_meta(BATTLES,{}):
  var actors:Array=specification(key,0).get("actors",[]) if key.begins_with("east:") or key.begins_with("sokia:") else BOSSES[key].actors
  if not tree.get_meta(BATTLES,{})[key].complete and id in actors:return true
 return false

static func defeated(tree:SceneTree,enemy:Dictionary):
 var key:String=enemy.university_battle;var slot:int=enemy.university_slot
 var slain:Dictionary=tree.get_meta(SLAIN,{})
 var battles:Dictionary=tree.get_meta(BATTLES,{})
 var battle:Dictionary=battles[key]
 slain[slain_key(key,int(battle.map),slot)]=true;tree.set_meta(SLAIN,slain)
 var offset=int(battle.phase)*1000
 if slot<offset:return
 var deaths=0
 for i in battle.members.size():
  if slain.has(slain_key(key,int(battle.map),offset+i)):deaths+=1
 if deaths<battle.members.size() and not(key=="altar" and int(battle.phase)==0 and deaths>=2):return
 var zone:Dictionary=bank_for(key).data().bosses[str(int(battle.encounter))]
 var waves=tree.current_scene.model.waves
 if int(zone.next_encounter)>0 and bool(Bank.Snow.draw(waves.snow_bags,"next:"+key,range(100).map(func(i):return i<int(zone.next_probability)),waves.rng)):
  battles[key].advance=true;tree.set_meta(BATTLES,battles);return
 battles[key].complete=true;tree.set_meta(BATTLES,battles)
 if key=="abyss":item(tree,"world_heart")
 if key=="lizard":item(tree,"lizard_reward")
 if key=="ruby":item(tree,"gluttony_book")
 if key=="zombie":item(tree,"doctor_talisman")
 tree.set_meta("university_victory",key)

static func victory(game)->bool:
 var tree:SceneTree=game.get_tree()
 if not tree.has_meta("university_victory"):return false
 var key:String=tree.get_meta("university_victory");tree.remove_meta("university_victory")
 var spec=specification(key,game.model.seed_value)
 if int(spec.map)!=game.model.falan_floor:return false
 if is_instance_valid(game.get("explore_access")) and game.explore_access.enabled():
  var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  game.explore_access.scripted_victory("regional:"+key,at,"Boss",spec.win)
  return false
 if key.begins_with("sokia:"):return load("res://scripts/forest/forest_sokia_cape.gd").victory(game,key,spec)
 if key.begins_with("east:"):return load("res://scripts/forest/forest_east_battles.gd").victory(game,key,spec)
 if key=="lizard":game.toast("獲得團長的鎚子")
 if not spec.win.is_empty():travel(game,int(spec.win[0]),Vector2i(spec.win[1],spec.win[2]));return true
 game.toast("獲得世界之心" if key=="abyss" else "獲得塔比歐的細胞");return false
