extends SceneTree
## Pure event contracts: no native enemy bank, scene reconstruction or old roster.
const Events=preload("res://scripts/forest/forest_east_events.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/"
class HealthAbility:
 extends RefCounted
 var deaths=0
 func die():deaths+=1
class HealthPlayer:
 extends RefCounted
 var hp=100.0
 var max_hp=100.0
 var active_ability=HealthAbility.new()
class HealthGame:
 extends RefCounted
 var player=HealthPlayer.new()
 var defeats=0
 func defeat():defeats+=1

var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("EAST_EVENT_FAIL "+message)
func context(gold:int=600)->Dictionary:
 return {"items":{},"gold":gold,"level":30,"group":1,"nowtime":3,"cell":Vector2i(10,20),"seed":42,"external":{},"bags":{},"refills":{},"now":120000.0,"hp":100.0,"max_hp":100.0}
func program(lines:Array,guard:String="")->Dictionary:
 var rows=[]
 for i in lines.size():rows.append([i+1,lines[i]])
 return {"blocks":[{"condition":guard,"line":1,"lines":rows}]}
func begin(lines:Array,state:Dictionary={},guard:String="")->Dictionary:
 return Events.begin_context({"id":"test","script":"contract","name":"測試旅人"},program(lines,guard),context() if state.is_empty() else state)
func run():
 var paid=["Window 1,NEXT","Window 2,YES,NO","Window_YES Gold < 500","EndWindow 3","Window_YES Gold >= 500","AddGold -500","Warp 0,40006,84,55","Window_NO","EndWindow 4"]
 var session=begin(paid)
 check(session.status=="window" and session.context.gold==600,"First prompt does not charge or transfer")
 Events.choose_context(session,"NEXT")
 check(session.status=="window" and session.pending.message==2 and session.context.gold==600,"Next reaches the explicit payment confirmation")
 Events.choose_context(session,"YES")
 check(session.status=="warp" and session.destination==[0,40006,84,55],"Accepted source payment reaches its exact destination")
 var commit=Events.take_commit(session)
 check(commit.gold==100 and Events.take_commit(session).is_empty(),"Payment commits exactly once")
 Events.choose_context(session,"YES")
 check(session.context.gold==100,"A stale repeated confirmation cannot charge again")
 session=begin(paid);Events.choose_context(session,"NEXT");Events.choose_context(session,"NO");Events.choose_context(session,"OK")
 check(Events.take_commit(session).gold==600 and not session.has("destination"),"Declining preserves Gold and location")
 session=begin(paid,context(400));Events.choose_context(session,"NEXT");Events.choose_context(session,"YES")
 check(session.status=="window" and session.pending.message==3 and session.context.gold==400,"Insufficient Gold takes the original denial branch")
 session=begin(["Window 1,YES,NO","Window_YES Job >= 400","Warp 0,1,2,3","Window_YES","Warp 0,4,5,6","Window_NO"])
 Events.choose_context(session,"YES")
 check(session.status=="blocked" and Events.take_commit(session).is_empty() and not session.has("destination"),"Unknown career state blocks before a free fallback warp")
 session=begin(["Warp 0,1,2,3"],context(),"Item 999 >= 1")
 check(session.status=="done" and not session.has("destination"),"A denied top-level item gate never enters its block")
 session=begin(["AddGold -500","Warp 0,999999,1,2"])
 check(not Events.validate_destination(session,func(_source,_cell):return false) and Events.take_commit(session).is_empty(),"An unsupported destination cannot commit a payment or enter a SIMPLE room")
 check(Events.warp_phase("0|2000|1|2|15|",3) and not Events.warp_phase("0|2000|1|2|3|",3) and Events.warp_phase("0|2000|1|2|8|",3),"Original Warp phase bitmasks preserve night/day gates")
 var nested=["Window 1,YES,NO","Window_YES","Window 2,YES,NO","Window_YES","GiveItem 111,1","EndWindow 3","Window_NO","EndWindow 4","Window_NO","EndWindow 5"]
 session=begin(nested);Events.choose_context(session,"NO")
 check(session.status=="window" and session.pending.message==5,"Outer No binds to the outer Window")
 session=begin(nested);Events.choose_context(session,"YES");Events.choose_context(session,"NO")
 check(session.status=="window" and session.pending.message==4 and Events.item_count(session.context.items,111)==0,"Inner No cannot run inner Yes rewards")
 session=begin(nested);Events.choose_context(session,"YES");Events.choose_context(session,"YES")
 check(session.status=="window" and Events.take_commit(session).is_empty(),"Nested reward waits for its final acknowledgement")
 Events.choose_context(session,"OK")
 check(Events.item_count(Events.take_commit(session).items,111)==1,"Nested Yes commits one original reward")
 var state=context();state.items.source_item_50=1
 session=begin(["KillItem 50,1","GivePet 31","Warp 0,1,2,3"],state)
 check(session.status=="blocked" and Events.take_commit(session).is_empty() and Events.item_count(state.items,50)==1,"Unsupported gameplay cannot partially consume quest items")
 session=begin(["Encount 2|0,47018,27,15||0|||||0|25012|||||||||"],context())
 check(session.status=="battle" and not session.has("destination"),"Encount requests native battle without applying its victory warp")
 state=context();state.items.source_item_50=3
 session=begin(["KillItemAll 50","NowEvent31 = 1","EndEvent 32 = 1"],state)
 commit=Events.take_commit(session)
 check(Events.item_count(commit.items,50)==0 and Events.condition(commit,"NowEvent 31 == 1 && EndEvent32 == 1").value,"All-item consumption and compact source flags are preserved")
 session=begin(["GiveLeak1Item 51,1"]);commit=Events.take_commit(session)
 check(Events.condition(commit,"Leak1Item51 >= 1 && Leak0Item 51 == 0").value,"Leak flags survive item grant and condition parsing")
 check(Events.condition(context(),"Group == 1 && Level >= 30 && NowTime == 3 && XPos == 10 && YPos == 20").value,"Solo, level, time and source-coordinate gates use explicit state")
 check(Events.condition(context(),"Level < 10 && Job >= 400 || Group == 1").value,"Logical precedence permits a known true alternative")
 check(not Events.condition(context(),"Group != 1 || Job >= 400").known,"A relevant unknown condition remains blocked")
 state=context()
 for i in 4:
  session=begin(["GiveItem(111%3,222%1$2)"],state);state=Events.take_commit(session)
 check(Events.item_count(state.items,111)==3 and Events.item_count(state.items,222)==2,"Weighted rewards exhaust their source distribution before refilling")
 var chat=context();chat.chat="地归地水归水火归火风归风"
 check(Events.condition(chat,"StrCmpChat == 21902").value,"Verified literal elemental chant opens its source comparison")
 chat.chat="錯誤的咒文"
 check(not Events.condition(chat,"StrCmpChat == 21902").value,"An incorrect chant cannot open a source chat gate")
 chat.chat="心写镜..."
 check(Events.condition(chat,"StrCmpChat == 20835").value,"Trailing source dots are literal characters in an exact chat comparison")
 chat.chat="心写镜"
 check(not Events.condition(chat,"StrCmpChat == 20835").value,"Exact chat comparison never strips the source dots")
 chat.chat="前文心写镜...後文"
 check(Events.condition(chat,"StrStrChat == 20835").value and not Events.condition(chat,"StrCmpChat == 20835").value,"Only the distinct StrStrChat command permits a literal substring")
 check(FileAccess.get_sha256(Events.CHAT_PROVENANCE.local_file)==Events.CHAT_PROVENANCE.sha256,"Selected chat text retains its verified pinned source file")
 var health=HealthGame.new()
 session=begin(["SetLp -20","SetLp -20"])
 check(session.context.hp==60.0 and health.player.hp==100.0,"Repeated source HP setters stage cumulative -40 until the transaction commits")
 commit=Events.take_commit(session)
 check(Events.commit_health(health,commit) and health.player.hp==60.0 and health.defeats==0,"A source floor trap applies its exact stat reduction without a combat damage multiplier")
 session=begin(["SetLp -300"])
 check(not Events.commit_health(health,Events.take_commit(session)) and health.player.hp==0.0 and health.defeats==1 and health.player.active_ability.deaths==1,"A lethal source HP setter clamps zero and calls existing ability/death cleanup once")
 session=begin(["KillItemAll 50","SetLp -20","GivePet 31"],state)
 check(session.status=="blocked" and Events.take_commit(session).is_empty(),"A later unsupported gameplay command prevents HP and item commits together")
 var aging=context();aging.now=10000.0
 session=begin(["GiveItem 41066,1 ## original inline comment"],aging)
 aging=Events.take_commit(session);aging.now=10059.0
 check(Events.source_value(aging,"ItemCreateTime","41066").value==0,"Item age counts completed wall-clock minutes")
 aging.now=10060.0
 check(Events.condition(aging,"Item41066>0 && ItemCreateTime41066>=1 ##60seconds").value,"Pinned source minute contract opens at the exact elapsed minute")
 session=begin(["GiveItem 41066,1"],aging);aging=Events.take_commit(session)
 check(aging.items.source_item_birth_41066==10000.0,"Stacking an existing quest item preserves its first creation time")
 check(not Events.source_value(aging,"ItemCreateTime","41066").known and aging.items.source_item_mixed_age_41066,"New awards cannot inherit the maturity of a previously held cohort")
 aging.now=20000.0;session=begin(["KillItemAll 41066","GiveItem 41066,1"],aging);aging=Events.take_commit(session)
 check(aging.items.source_item_birth_41066==20000.0,"Fully consuming and reacquiring an item records the new staged creation time")
 check(Events.source_value(aging,"ItemCreateTime","41066").known and not aging.items.has("source_item_mixed_age_41066"),"Complete consumption clears the mixed-age gate for the next cohort")
 var old=context();old.items.source_item_41066=1
 check(not Events.source_value(old,"ItemCreateTime","41066").known,"An older persisted item without a creation timestamp remains explicitly blocked")
 check(Events.source_text('Window "literal#tag" ## comment')=='Window "literal#tag"',"Inline source comments preserve quoted hash characters")
 var data=Events.data()
 var eele:Dictionary=data.scripts.get("EV_rk_eele06.txt",{})
 session=Events.begin_context({"id":"actual-eele06","script":"EV_rk_eele06.txt"},eele,context())
 Events.choose_context(session,"YES");Events.choose_context(session,"OK")
 check(session.status=="warp" and session.destination==[0,11034,74,72],"Actual Earth entry reaches its original map despite an unreachable final duplicate handler")
 session=begin(["Window 1,OK","Window_OK","GiveItem 111,1","Window_OK","GiveItem 222,1"])
 Events.choose_context(session,"OK");commit=Events.take_commit(session)
 check(Events.item_count(commit.items,111)==1 and Events.item_count(commit.items,222)==0,"A retained dead duplicate cannot execute after the first unconditional handler")
 var common=context();common.external.job=300
 session=Events.begin_context({"id":"actual-habaru-common","script":"EV_ijk_6096.txt"},data.scripts["EV_ijk_6096.txt"],common)
 Events.choose_context(session,"OK");Events.choose_context(session,"YES")
 check(session.status=="warp" and session.destination==[0,11004,24,7] and session.context.gold==100,"Source shared choice handlers apply to the selected conditional dialogue branch")
 var age_source:Dictionary=data.scripts.get("mayko_gm_1102585.txt",{})
 check(age_source.get("sha256","")==Events.ITEM_AGE_PROVENANCE.sha256,"The item-minute interpretation is anchored to the exact pinned script")
 var original:Dictionary=data.scripts.get("EV_rk_jukai05.txt",{})
 check(not original.is_empty(),"Actual four-item quest script exists in the prepared source programs")
 if not original.is_empty():
  var denied=context()
  for id in [18973,18974,18975,18976]:denied.items["source_item_"+str(id)]=1
  var locked=Events.begin_context({"id":"actual-jukai-low-level","script":"EV_rk_jukai05.txt"},original,denied)
  check(locked.status=="window" and locked.pending.message==21887 and not locked.has("destination"),"Actual source Level<=74 denial remains enforced")
  state=context();state.level=75;state.external.itemspace=1
  for i in 7:state.external["checkitemcategory:"+str(i)]=0
  for id in [18973,18974,18975,18976]:state.items["source_item_"+str(id)]=1
  session=Events.begin_context({"id":"actual-jukai","script":"EV_rk_jukai05.txt"},original,state)
  for i in 3:Events.choose_context(session,"NEXT")
  Events.choose_context(session,"YES");Events.choose_context(session,"OK")
  check(session.status=="warp" and session.destination==[0,11032,7,9],"Actual multistep four-item quest reaches its source destination")
  commit=Events.take_commit(session)
  check(not commit.is_empty() and [18973,18974,18975,18976].all(func(id):return Events.item_count(commit.items,id)==0),"Actual source exchange consumes all four required items")
 var report=source_audit(data)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var file=FileAccess.open(OUT+"event-source-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 file=FileAccess.open(OUT+"event-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Pure source program parsing, guarded choices, quest-state transactions and weighted reward bags. No rendered dialogue or native battle test."},"  "));file.close()
 print("EAST_EVENT_CONTRACT_RESULT checks=",checks," failures=",failures," scripts=",data.scripts.size()," raw_commands=",report.raw_commands.size()," semantic_commands=",report.commands.size()," compile_blockers=",report.source_blockers.size()," unsupported_gameplay=",report.technical_blockers.size())
 quit(1 if failures else 0)

func source_audit(data:Dictionary)->Dictionary:
 var commands={};var raw_commands={};var source_blockers=[];var technical_blockers=[];var unsupported_conditions=[];var retained_handlers=[]
 var actors={}
 for actor in data.actors:
  if not actors.has(actor.script):actors[actor.script]=[]
  actors[actor.script].append({"id":actor.id,"map":actor.source,"cell":actor.cell,"type":actor.type})
 var supported=["window","endwindow","block","window_yes","window_no","window_ok","window_next","leavegroup","giveitem","giveleak0item","giveleak1item","killitem","killitemall","killleak0item","killleak1item","nowevent","endevent","addgold","setlp","setdur","addstampcount","warp","encount","endblock","if","endif"]+Events.VISUAL
 for name in data.scripts:
  var script:Dictionary=data.scripts[name]
  for block in Events.compile_script(script):
   for error in block.errors:source_blockers.append({"script":name,"line":error.line,"reason":error.reason,"actors":actors.get(name,[])})
   for handler in block.retained_handlers:retained_handlers.append({"script":name,"line":handler.line,"reason":handler.reason,"actors":actors.get(name,[])})
  for source in script.lines:
   var line=str(source[1]).strip_edges();var kind=Events.command(line)
   var raw=line.get_slice(" ",0).get_slice("\t",0)
   raw_commands[raw]=int(raw_commands.get(raw,0))+1
   if Events.regex("(?i)^(nowevent|endevent)\\s*[0-9]+\\s*=",line)!=null:kind="nowevent" if kind.begins_with("nowevent") else "endevent"
   commands[kind]=int(commands.get(kind,0))+1
   if kind not in supported and not line.ends_with(":"):
    var record={"script":name,"line":source[0],"command":line,"actors":actors.get(name,[]),"reason":"Gameplay command has no verified runtime contract","conditional_potential":true}
    if kind in ["winodw_ok","endwinodw"] or kind.is_empty():source_blockers.append(record)
    else:technical_blockers.append(record)
   var expression=""
   if kind in ["block","if"]:expression=line.substr(kind.length()).strip_edges()
   elif kind.begins_with("window_"):
    var handler=Events.regex("(?i)^window_[a-z0-9_\\[\\]]+\\s*(.*)$",line)
    if handler!=null:expression=handler.get_string(1)
   if expression.is_empty():continue
   for atom in Events.split_logic(expression.replace("(","").replace(")",""),"||"):
    for term in Events.split_logic(atom,"&&"):
     var audit_context=context();audit_context.chat=""
     var result=Events.condition(audit_context,term)
     if not result.known:unsupported_conditions.append({"script":name,"line":source[0],"condition":term.strip_edges(),"reason":result.reason,"actors":actors.get(name,[])})
 return {"scripts":data.scripts.size(),"raw_commands":raw_commands,"commands":commands,"source_blockers":source_blockers,"technical_blockers":technical_blockers,"unknown_external_conditions":unsupported_conditions,"retained_handlers":retained_handlers,"visual_only_commands":Events.VISUAL,"chat_keywords":Events.CHAT_KEYWORDS,"chat_provenance":Events.CHAT_PROVENANCE,"item_age_provenance":Events.ITEM_AGE_PROVENANCE,"limits":["Unknown career, skill, equipment, title, capacity and other external state blocks the affected actor; none authorizes a fallback warp. All verified source chat words use the existing text-entry control; StrCmpChat preserves every literal character including trailing dots, while only StrStrChat accepts a literal substring.","Item aging uses source-confirmed completed wall-clock minutes and staged first-created timestamps; persisted items without recorded birth time remain blocked.","Source dialogue wording is placeholder text. Event logic and its source line references remain separate from presentation.","SetObject, pet, recipe, title and login services require their existing gameplay contracts; they are not silently ignored."]}
