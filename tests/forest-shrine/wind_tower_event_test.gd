extends SceneTree
## Exact original predicates/branches; contexts simulate inventory without granting user items.
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/"
var checks=0
var failures=0
var results=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("WIND_EVENT_FAIL ",label)
func _initialize():run.call_deferred()
func context(items:Dictionary={},chat:Variant=null,bimage:Variant=null)->Dictionary:
 var ctx={"items":items.duplicate(true),"gold":5000,"level":100,"group":3,"seed":341,"external":{},"bags":{},"refills":{},"now":1000000.,"hp":100.,"max_hp":100.}
 if chat!=null:ctx.chat=chat
 if bimage!=null:ctx.external.bimage=bimage
 return ctx
func branch(id:String,ctx:Dictionary,answers:Array)->Dictionary:
 var actor:Dictionary=Region.source_actors[id];var payload=Region.wind_events()
 var state=Events.begin_context(actor,payload.scripts.get(actor.script,{}),ctx)
 for answer in answers:
  if state.status!="window":break
  Events.choose_context(state,answer)
 results.append({"actor":id,"chat":ctx.get("chat","<not-entered>"),"initial_items":ctx.items,"status":state.status,"destination":state.get("destination",[]),"items":state.context.items,"blocker":state.get("blocker",{})})
 return state
func run():
 var source=Region.wind_events();var residents=Region.residents();Events.data();Region.data()
 check(source.actors.size()==16,"All16source actors retained")
 for actor in source.actors:
  check(residents.actors.filter(func(a):return a.id==actor.id).size()==1 and Events.actor_index.has(actor.id),"Single existing NPC/event registry owns source actor "+actor.id)
  check(Region.source_actors[actor.id].cell==actor.cell and Region.source_actors[actor.id].raw==actor.raw,"Original source cell/raw record preserved "+actor.id)
 check(source.automatic.size()==2,"Only the two original StandEnemy actors use the automatic owner")
 check(Events.CHAT_KEYWORDS["17034"].text==source.messages["17034"],"Numeric keyword exactly matches source message text")
 for id in ["6267","6271"]:
  var no_item=branch(id,context({},source.messages["17034"]),["OK"])
  check(no_item.status=="done"and no_item.context.items.is_empty(),"Phrase alone grants no item or sea access "+id)
  var wrong=branch(id,context({"source_item_18575":1},"wrong"),["OK"])
  check(wrong.status=="done","Wrong phrase cannot open the sea "+id)
  var unspoken=branch(id,context({"source_item_18575":1}),[])
  check(unspoken.status=="blocked"and unspoken.blocker.reason=="Original chat response has not been entered","Existing held item still requires the spoken phrase "+id)
  var allowed=branch(id,context({"source_item_18575":1},source.messages["17034"]),["OK"])
  var expected=[0,302,103,24]if id=="6267"else[0,302,17,12]
  check(allowed.status=="warp"and allowed.destination==expected and allowed.context.group==1 and allowed.context.items=={"source_item_18575":1},"Exact held-item/phrase route and source LeaveGroup "+id)
 var circles={"6255":[[0,20309,51,42],[0,20308,51,35]],"6256":[[0,20309,51,34],[0,20308,51,40]],"6257":[[0,20305,44,63],[0,20304,54,63]],"6258":[[0,20305,56,63],[0,20304,46,63]],"6259":[[0,20304,50,32],[0,20302,50,25]],"6260":[[0,20304,50,23],[0,20302,50,29]],"6261":[[0,20309,37,78],[0,20308,37,68]],"6262":[[0,20309,37,66],[0,20308,37,76]],"6263":[[0,20308,50,30],[0,20305,50,24]]}
 for id in circles:
  for held in [false,true]:
   var items={"source_item_18566":1}if held else{}
   var result=branch(id,context(items,"R"),["YES","NEXT"])
   check(result.status=="warp"and result.destination==circles[id][0 if held else 1]and result.context.items==items,"Source item branch retains destination and inventory "+id+str(held))
  var declined=branch(id,context({},"R"),["NO"])
  check(declined.status=="done"and not declined.has("destination"),"Declining a source circle never warps "+id)
  var unknown=branch(id,context(),[])
  check(unknown.status=="blocked","Unentered R predicate is not silently assumed "+id)
 var unknown_image=branch("6272",context(),[])
 check(unknown_image.status=="blocked","Unknown transformation state remains guarded")
 var transformed=branch("6272",context({},null,101912),["OK"])
 check(transformed.status=="done"and not transformed.has("destination")and transformed.context.items.is_empty(),"Original Arcas transformation denies the postbattle service")
 var ordinary=branch("6272",context({},null,102488),["NEXT","NEXT","NEXT","NEXT","OK"])
 check(ordinary.status=="warp"and ordinary.destination==[0,1530,15,6]and ordinary.context.items.get("source_endevent_19",0)==1,"Known ordinary source appearance retains EndEvent19and original castle return")
 var flags={};Original.Art.load_sokia_wind()
 for id in Original.Art.SOKIA_WIND_IDS:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=row.sokia_visual_only;row.sokia_visual_only=false
 var manual=Region.manual_anchors([300],"sokia_coast")
 check(manual.size()==1 and manual[0].id=="6267"and manual[0].render_at==Region.source_point(300,Vector2i(461,404)),"Original invisible entry has one exact coastal F anchor")
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 var report={"checks":checks,"failures":failures,"cases":results,"R_original_input_semantics":"unverified; literal source predicate retained, no synthetic binding", "native_or_visual":false,"goal_complete":false}
 var file=FileAccess.open(OUT+"event-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("WIND_EVENT_CONTRACT ",checks," checks ",failures," failures ",results.size()," source branches")
 quit(1 if failures else 0)
