extends RefCounted
## Interpret the recovered event data with explicit commands and guarded dialogue choices.
const ITEMS="university_quest_items"
const SESSION="east_event_session"
const BLOCKERS="east_event_blockers"
const CHAT_KEYWORDS={
 "17034":{"text":"以军神之名开启海路","source_flag":"0"},
 "14039": {
  "text": "狩猎者",
  "source_flag": "0"
 },
 "14040": {
  "text": "挖掘者",
  "source_flag": "0"
 },
 "14041": {
  "text": "切砍者",
  "source_flag": "0"
 },
 "14905": {
  "text": "亚尔科尔...",
  "source_flag": "0"
 },
 "14912": {
  "text": "毒...",
  "source_flag": "0"
 },
 "14916": {
  "text": "心美...",
  "source_flag": "0"
 },
 "14917": {
  "text": "卡南...",
  "source_flag": "0"
 },
 "14950": {
  "text": "米内萨卡...",
  "source_flag": "0"
 },
 "14984": {
  "text": "陶欧...",
  "source_flag": "0"
 },
 "15005": {
  "text": "波罗尼亚...",
  "source_flag": "0"
 },
 "15731": {
  "text": "莫其...",
  "source_flag": "0"
 },
 "15735": {
  "text": "尤因...",
  "source_flag": "0"
 },
 "15800": {
  "text": "头目万岁",
  "source_flag": "0"
 },
 "20835": {
  "text": "心写镜...",
  "source_flag": "0"
 },
 "21901": {
  "text": "万物皆生自四元素终必毁灭",
  "source_flag": "1"
 },
 "21902": {
  "text": "地归地水归水火归火风归风",
  "source_flag": "1"
 },
 "206716": {
  "text": "犯人就是你！凯莉修女已经自白了！...",
  "source_flag": "1"
 },
 "206720": {
  "text": "看...",
  "source_flag": "0"
 },
 "206721": {
  "text": "听...",
  "source_flag": "0"
 },
 "206722": {
  "text": "写...",
  "source_flag": "0"
 },
 "206723": {
  "text": "敲...",
  "source_flag": "0"
 },
 "206724": {
  "text": "拿...",
  "source_flag": "0"
 },
 "206726": {
  "text": "汉克...",
  "source_flag": "0"
 },
 "206727": {
  "text": "温其斯...",
  "source_flag": "0"
 },
 "206728": {
  "text": "普林堤...",
  "source_flag": "0"
 },
 "206729": {
  "text": "坦格拉姆...",
  "source_flag": "0"
 },
 "206730": {
  "text": "幸运皇冠...",
  "source_flag": "0"
 },
 "206731": {
  "text": "斐斯医生...",
  "source_flag": "0"
 },
 "206732": {
  "text": "爱蜜莉...",
  "source_flag": "0"
 },
 "206733": {
  "text": "凯莉修女...",
  "source_flag": "0"
 },
 "206734": {
  "text": "诺那诺那...",
  "source_flag": "0"
 },
 "206735": {
  "text": "葛登...",
  "source_flag": "0"
 },
 "206736": {
  "text": "福兰克林...",
  "source_flag": "0"
 },
 "206737": {
  "text": "女人...",
  "source_flag": "0"
 },
 "206738": {
  "text": "安眠药...",
  "source_flag": "0"
 },
 "206739": {
  "text": "豪华客船...",
  "source_flag": "0"
 },
 "206740": {
  "text": "不在场证明...",
  "source_flag": "0"
 }
}
const CHAT_PROVENANCE={"path": "gmsv/data/msg.txt", "local_file": "res://assets/references/crossgate_tina/events/msg.txt", "sha256": "937a108a9e0015466dba64be6e2b45e7e28e8ca2a62c10cc9b4585bba4a8ffde", "git_blob": "97dfb06fbf371ec3d6d142de897f7b68a15cd059", "revision": "dd8690ed3df11e4eb5a038a54079a8f40d8e93b3"}
const ITEM_AGE_PROVENANCE={"script":"mayko_gm_1102585.txt","line":11,"sha256":"ff1ded845e41dac5374f132cb8017aa7364dd4027740ee90c527587d8bc599f9","git_blob":"b631d8d3847ca0b141645e6d81d9ef8de58c959f","source_comment":"12hr =60分*12hr","units":"completed wall-clock minutes"}
const VISUAL=["play_se","playse","message","systemmessage","setaction","changepal"]
static var population:Dictionary={}
static var actor_index:Dictionary={}
static var compiled:Dictionary={}
static var serial=0
static var usable_items:Dictionary={}

static func data()->Dictionary:
 if population.is_empty():
  population=load("res://scripts/forest/forest_east_region.gd").residents()
  for actor in population.actors:actor_index[str(actor.id)]=actor
 return population

static func regex(pattern:String,value:String)->RegExMatch:
 var expression=RegEx.new()
 if expression.compile(pattern)!=OK:return null
 return expression.search(value)

static func command(line:String)->String:
 var found=regex("(?i)^([a-z_][a-z0-9_]*)",line.strip_edges())
 if found==null:return ""
 var value=found.get_string(1).to_lower()
 return "endwindow" if regex("^endwindow[0-9]+$",value)!=null else value

static func source_text(text:String)->String:
 var quote="";var escaped=false
 for i in text.length():
  var c=text[i]
  if escaped:escaped=false;continue
  if c=="\\":escaped=true;continue
  if not quote.is_empty():
   if c==quote:quote=""
  elif c in ["\"","'"]:quote=c
  elif c=="#":return text.substr(0,i).strip_edges()
 return text.strip_edges()

static func item_data()->Dictionary:
 if usable_items.is_empty():usable_items=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/items.json"))
 return usable_items

static func begin_item_context(id:int,record:Dictionary,context:Dictionary)->Dictionary:
 var program:Dictionary=record.get("program",{}) if record.get("program") is Dictionary else {}
 var cell:Vector2i=context.get("cell",Vector2i.ZERO)
 var actor={"id":"item:"+str(id),"name":record.get("name","道具"),"script":record.get("argument",""),"source":int(context.get("source_map",context.get("floor",-1))),"cell":[cell.x,cell.y],"source_verified":context.has("source_map") or context.has("floor"),"cell_verified":context.has("cell"),"item_use":true,"source_line":int(record.get("source_itemset_line",0))}
 if context.has("runtime_at"):actor.runtime_at=context.runtime_at
 var session:Dictionary
 if item_count(context.get("items",{}),id)<=0 or record.get("function_code","")!="IuMs" or program.is_empty():
  session={"actor":actor,"initial":context.duplicate(true),"context":context.duplicate(true),"status":"running","queue":[],"committed":false}
  stop(session,"Original usable item is not held" if item_count(context.get("items",{}),id)<=0 else "Original held item has no verified IuMs use program",actor.source_line,"technical" if not program.is_empty() else "source")
 else:session=begin_context(actor,program,context)
 session.item_use=id;session.program=program
 return session

static func validate_item_held(session:Dictionary,current_items:Dictionary)->bool:
 if not session.has("item_use"):return true
 if item_count(current_items,int(session.item_use))>0:return true
 stop(session,"Original usable item is no longer held",int(session.get("line",0)));return false

static func take_item_commit(session:Dictionary,current_items:Dictionary)->Dictionary:
 if session.get("committed",false) or not validate_item_held(session,current_items):return {}
 return take_commit(session)

static func item_count(items:Dictionary,id:int)->int:
 return int(items.get("source_item_%d"%id,0))

static func set_item(items:Dictionary,id:int,count_:int,now:float=-1.0):
 var key="source_item_%d"%id
 var previous=item_count(items,id)
 if count_>0 and previous==0:items["source_item_birth_%d"%id]=Time.get_unix_time_from_system() if now<0 else now
 elif count_>previous:items["source_item_mixed_age_%d"%id]=true
 items[key]=maxi(0,count_)
 if count_<=0:
  for prefix in ["source_item_birth_","source_item_mixed_age_","source_item_leak_","source_item_stamp_","source_item_dur_"]:items.erase(prefix+str(id))

static func set_event(items:Dictionary,kind:String,id:int,value:int):
 items["source_%s_%d"%[kind.to_lower(),id]]=value

static func known(value:Variant)->Dictionary:return {"known":true,"value":value,"reason":""}
static func unknown(reason:String)->Dictionary:return {"known":false,"value":false,"reason":reason}

static func split_logic(text:String,separator:String)->Array:
 var depth=0;var start=0;var result=[];var i=0
 while i<text.length():
  if text[i]=="(":depth+=1
  elif text[i]==")":depth-=1
  if depth==0 and text.substr(i,separator.length())==separator:
   result.append(text.substr(start,i-start));i+=separator.length();start=i;continue
  i+=1
 result.append(text.substr(start))
 return result

static func source_value(context:Dictionary,key:String,id:String="")->Dictionary:
 var normalized=key.to_lower().trim_suffix("_")
 var items:Dictionary=context.get("items",{})
 var number_=int(id) if not id.is_empty() else 0
 if normalized=="item":return known(item_count(items,number_))
 if normalized in ["nowevent","endevent"]:return known(int(items.get("source_%s_%d"%[normalized,number_],0)))
 if normalized in ["leak0item","leak1item"]:
  if item_count(items,number_)==0:return known(0)
  var flag="source_item_leak_%d"%number_
  if not items.has(flag):return unknown("Original item leak flag is unavailable: "+str(number_))
  return known(item_count(items,number_) if int(items[flag])==int(normalized[4]) else 0)
 if normalized=="stampcount":return known(int(items.get("source_item_stamp_%d"%number_,0)))
 if normalized=="itemdur":
  var durability="source_item_dur_%d"%number_
  if item_count(items,number_)==1 and items.has(durability) and (items[durability] is int or items[durability] is float):return known(int(items[durability]))
 if normalized=="itemcreatetime":
  var birth="source_item_birth_%d"%number_
  if items.get("source_item_mixed_age_%d"%number_,false):return unknown("Original item stack contains different creation times: "+str(number_))
  if not items.has(birth) or item_count(items,number_)<=0:return unknown("Original item age is unavailable: "+str(number_))
  if not (items[birth] is int or items[birth] is float) or not is_finite(float(items[birth])) or float(items[birth])<=0:return unknown("Original item creation timestamp is unavailable: "+str(number_))
  return known(maxi(0,int((float(context.get("now",Time.get_unix_time_from_system()))-float(items[birth]))/60.)))
 if normalized in ["gold","level","group","nowtime","floor"]:
  if context.has(normalized):return known(context[normalized])
 if normalized in ["xpos","ypos"]:
  if context.has("cell"):return known(context.cell.x if normalized=="xpos" else context.cell.y)
 var external:Dictionary=context.get("external",{})
 var token=normalized+(":"+id if not id.is_empty() else "")
 if external.has(token) and (external[token] is int or external[token] is float or external[token] is bool):return known(external[token])
 return unknown("Original external state is unavailable: "+token)

static func compare(a:Variant,operator:String,b:Variant)->bool:
 match operator:
  "==":return a==b
  "!=":return a!=b
  ">=":return a>=b
  "<=":return a<=b
  ">":return a>b
  "<":return a<b
 return false

static func condition(context:Dictionary,expression:String)->Dictionary:
 var text=source_text(expression)
 if text.is_empty():return known(true)
 if text.begins_with("(") and text.ends_with(")"):
  var inner=text.substr(1,text.length()-2)
  var depth=0;var whole=true
  for c in inner:
   if c=="(":depth+=1
   elif c==")":depth-=1
   if depth<0:whole=false;break
  if whole and depth==0:return condition(context,inner)
 var pieces=split_logic(text,"||")
 if pieces.size()>1:
  var missing=""
  for piece in pieces:
   var result=condition(context,piece)
   if result.known and result.value:return known(true)
   if not result.known:missing=result.reason
  return known(false) if missing.is_empty() else unknown(missing)
 pieces=split_logic(text,"&&")
 if pieces.size()>1:
  var missing=""
  for piece in pieces:
   var result=condition(context,piece)
   if result.known and not result.value:return known(false)
   if not result.known:missing=result.reason
  return known(true) if missing.is_empty() else unknown(missing)
 var atom=regex("(?i)^((?:leak[01]item)|[a-z_]+)\\s*([0-9]*)\\s*(==|!=|>=|<=|>|<)\\s*(-?[0-9]+|[a-z_$][a-z0-9_$]*)$",text)
 if atom==null:return unknown("Unsupported original condition: "+text)
 if atom.get_string(1).to_lower() in ["strcmpchat","strstrchat"]:
  var reference=atom.get_string(4);var word=reference
  if reference.is_valid_int():
   if not CHAT_KEYWORDS.has(reference):return unknown("Original chat keyword is not recorded: "+reference)
   word=CHAT_KEYWORDS[reference].text
  elif reference not in ["r","R"]:return unknown("Unsupported original chat comparison: "+reference)
  if atom.get_string(3) not in ["==","!="]:return unknown("Unsupported original chat comparison operator")
  if not context.has("chat"):return unknown("Original chat response has not been entered")
  # StrCmpChat compares the literal source bytes, including dots; StrStrChat alone accepts a substring.
  var matches=str(context.chat).contains(word) if atom.get_string(1).to_lower()=="strstrchat" else str(context.chat)==word
  return known(matches if atom.get_string(3)=="==" else not matches)
 var left=source_value(context,atom.get_string(1),atom.get_string(2))
 if not left.known:return left
 var right_text=atom.get_string(4)
 var right=known(int(right_text)) if right_text.is_valid_int() else source_value(context,right_text)
 if not right.known:return right
 return known(compare(left.value,atom.get_string(3),right.value))

static func compile_block(block:Dictionary)->Dictionary:
 var root=[];var stack=[{"kind":"root","body":root}];var errors=[];var windows=[];var retained=[]
 for source in block.lines:
  var line=source_text(str(source[1]));var number_=int(source[0])
  if line.is_empty() or line.begins_with("#"):continue
  var handler=regex("(?i)^window_([a-z0-9_\\[\\]]+)\\s*(.*)$",line)
  if handler!=null:
   var token=handler.get_string(1).to_upper();var found=-1;var duplicate=-1
   for i in range(stack.size()-1,0,-1):
    var frame:Dictionary=stack[i]
    if frame.kind!="window" or token not in frame.node.choices:continue
    var alternatives:Array=frame.node.handlers.get(token,[])
    if alternatives.any(func(branch):return branch.condition.is_empty()):
     if duplicate<0:duplicate=i
     continue
    found=i;break
   var branch={"condition":handler.get_string(2).strip_edges(),"body":[],"line":number_}
   if found<0 and duplicate>=0:
    found=duplicate;branch.unreachable=true
    retained.append({"line":number_,"reason":"Prior unconditional handler wins; duplicate is retained but unreachable"})
   if found<0:
    # Shared handlers may follow alternative dialogue windows from earlier conditional sibling branches.
    var targets=[]
    for previous in windows:
     if token in previous.choices and not previous.handlers.get(token,[]).any(func(alternative):return alternative.condition.is_empty()):targets.append(previous)
    if targets.is_empty():errors.append({"line":number_,"reason":"Unbound original Window handler: "+line});continue
    for target in targets:
     if not target.handlers.has(token):target.handlers[token]=[]
     target.handlers[token].append(branch)
    retained.append({"line":number_,"reason":"Shared handler retained for preceding conditional dialogue choices","windows":targets.map(func(target):return target.line)})
    stack.append({"kind":"shared_handler","body":branch.body});continue
   stack.resize(found+1)
   var frame:Dictionary=stack.back()
   if not frame.node.handlers.has(token):frame.node.handlers[token]=[]
   frame.node.handlers[token].append(branch);frame.body=branch.body
   continue
  var kind=command(line)
  if kind=="window":
   var spec=regex("(?i)^window\\s*([0-9]+)(?:\\s*,\\s*(.*))?$",line)
   if spec==null:errors.append({"line":number_,"reason":"Malformed original Window: "+line});continue
   var choices=[]
   for choice in spec.get_string(2).split(",",false):choices.append(choice.strip_edges().to_upper())
   if choices.is_empty():choices=["OK"]
   var node={"kind":"window","line":number_,"message":int(spec.get_string(1)),"choices":choices,"handlers":{},"body":[]}
   stack.back().body.append(node);windows.append(node);stack.append({"kind":"window","node":node,"body":node.body})
  elif kind=="if":
   var node={"kind":"if","condition":line.substr(2).strip_edges(),"line":number_,"body":[]}
   stack.back().body.append(node);stack.append({"kind":"if","node":node,"body":node.body})
  elif kind=="endif":
   var found=-1
   for i in range(stack.size()-1,0,-1):
    if stack[i].kind=="if":found=i;break
   if found<0:errors.append({"line":number_,"reason":"Unmatched original endif"})
   else:stack.resize(found)
  else:stack.back().body.append({"kind":"command","line":number_,"text":line})
 return {"body":root,"errors":errors,"retained_handlers":retained,"condition":block.get("condition",""),"line":block.get("line",0)}

static func compile_script(script:Dictionary)->Array:
 var result=[]
 for block in script.get("blocks",[]):result.append(compile_block(block))
 return result

static func stop(session:Dictionary,reason:String,line:int=0,category:String="technical"):
 if "not yet confirmed" in reason:category="source"
 session.status="blocked";session.blocker={"category":category,"actor":str(session.actor.get("id","")),"script":session.actor.get("script",""),"line":line,"reason":reason};session.queue=[]

static func begin_context(actor:Dictionary,script:Dictionary,context:Dictionary)->Dictionary:
 var session={"actor":actor,"initial":context.duplicate(true),"context":context.duplicate(true),"queue":[],"status":"running","pending":{},"committed":false,"blocker":{}}
 var key=script.get("sha256","")
 var blocks:Array
 if key.is_empty():blocks=compile_script(script)
 else:
  if not compiled.has(key):compiled[key]=compile_script(script)
  blocks=compiled[key]
 for block in blocks:
  var allowed=condition(session.context,str(block.condition))
  if not allowed.known:stop(session,allowed.reason,int(block.line));return session
  if not allowed.value:continue
  if not block.errors.is_empty():
   var error:Dictionary=block.errors[0];stop(session,error.reason,error.line,"source");return session
  session.queue=block.body.duplicate(true);step(session);return session
 session.status="done"
 return session

static func integers(text:String)->Array:
 var result=[];var expression=RegEx.new();expression.compile("-?[0-9]+")
 for found in expression.search_all(text):result.append(int(found.get_string()))
 return result

static func give_item(session:Dictionary,text:String,leak:int=-1)->bool:
 var args=regex("(?i)^give(?:leak[01])?item\\s*(.*)$",text).get_string(1).strip_edges()
 var id=0;var count_=1
 if args.begins_with("("):
  if not args.ends_with(")"):stop(session,"Malformed original weighted item award",session.line,"source");return false
  var choices=[]
  for option in args.substr(1,args.length()-2).split(",",false):
   var found=regex("^\\s*([0-9]+)%([0-9]+)(?:\\$([0-9]+))?\\s*$",option)
   if found==null:stop(session,"Unsupported original weighted item award: "+option,session.line);return false
   for weight in int(found.get_string(2)):choices.append([int(found.get_string(1)),int(found.get_string(3)) if not found.get_string(3).is_empty() else 1])
  if choices.is_empty():stop(session,"Original weighted award has no positive outcomes",session.line,"source");return false
  var key="%s:%s:%d"%[session.actor.get("id",""),session.actor.get("script",""),session.line]
  var bags:Dictionary=session.context.get("bags",{});var refills:Dictionary=session.context.get("refills",{})
  var bag:Array=bags.get(key,[])
  if bag.is_empty():
   bag=choices.duplicate(true);var rng=RandomNumberGenerator.new();rng.seed=int(session.context.get("seed",0))+hash(key)+int(refills.get(key,0));refills[key]=int(refills.get(key,0))+1
   for i in range(bag.size()-1,0,-1):
    var j=rng.randi_range(0,i);var swap=bag[i];bag[i]=bag[j];bag[j]=swap
  var draw:Array=bag.pop_back();id=draw[0];count_=draw[1];bags[key]=bag;session.context.bags=bags;session.context.refills=refills
 else:
  var values=integers(args)
  if values.is_empty():stop(session,"Missing original item identity",session.line,"source");return false
  id=values[0];count_=values[1] if values.size()>1 else 1
 if id<=0 or count_<=0:stop(session,"Invalid original item award",session.line,"source");return false
 var items:Dictionary=session.context.items
 set_item(items,id,item_count(items,id)+count_,float(session.context.get("now",-1.0)))
 if leak>=0:items["source_item_leak_%d"%id]=leak
 return true

static func apply_command(session:Dictionary,text:String):
 text=source_text(text)
 var kind=command(text);var context:Dictionary=session.context;var items:Dictionary=context.items
 var assignment=regex("(?i)^(nowevent|endevent)\\s*([0-9]+)\\s*=\\s*(-?[0-9]+)$",text)
 if assignment!=null:set_event(items,assignment.get_string(1),int(assignment.get_string(2)),int(assignment.get_string(3)));return
 if kind=="leavegroup":session.context.group=1;return
 if kind in VISUAL:return
 if kind in ["giveitem","giveleak0item","giveleak1item"]:
  give_item(session,text,0 if kind=="giveleak0item" else 1 if kind=="giveleak1item" else -1);return
 if kind in ["killitem","killitemall","killleak0item","killleak1item"]:
  var values=integers(text)
  # Leak command names contain their own flag digit before the item arguments.
  if kind.begins_with("killleak"):values.pop_front()
  if values.is_empty():stop(session,"Missing original item consumption identity",session.line,"source");return
  var id:int=values[0];var amount:int=item_count(items,id) if kind=="killitemall" else values[1] if values.size()>1 else 1
  if kind.begins_with("killleak"):
   var expected=0 if kind=="killleak0item" else 1
   if not items.has("source_item_leak_%d"%id) or int(items["source_item_leak_%d"%id])!=expected:stop(session,"Original consumed item's leak flag is unavailable",session.line);return
  if amount<0 or item_count(items,id)<amount:stop(session,"Original item consumption lacks the required count",session.line);return
  set_item(items,id,item_count(items,id)-amount,float(context.get("now",-1.0)));return
 if kind=="setdur":
  var values=integers(text)
  if values.size()!=2:stop(session,"Original item durability setter lacks numeric operands",session.line);return
  var held=source_value(context,"itemdur",str(values[0]))
  if not held.known or item_count(items,values[0])!=1:stop(session,"Original item durability state is unavailable: "+str(values[0]),session.line);return
  items["source_item_dur_%d"%values[0]]=maxi(0,int(held.value)+values[1]);return
 if kind=="setlp":
  var setter=regex("(?i)^setlp\\s*([+-][0-9]+)$",text)
  if setter==null or not context.has("hp") or not context.has("max_hp"):
   stop(session,"Original HP setter requires a signed numeric delta and player health state",session.line);return
  context.hp=clampf(float(context.hp)+float(setter.get_string(1)),0.0,float(context.max_hp));context.health_changed=true;return
 if kind=="addgold":
  var values=integers(text)
  if values.size()!=1 or int(context.gold)+values[0]<0:stop(session,"Original payment lacks the required Gold",session.line);return
  context.gold=int(context.gold)+values[0];return
 if kind=="addstampcount":
  var values=integers(text)
  if values.is_empty() or item_count(items,values[0])<=0:stop(session,"Original stamp requires its held quest item",session.line);return
  var key="source_item_stamp_%d"%values[0];items[key]=int(items.get(key,0))+1;return
 if kind=="warp":
  var values=integers(text)
  if values.size()!=4 or values[0]!=0:stop(session,"Unsupported original warp coordinate contract",session.line);return
  session.status="warp";session.destination=values;session.queue=[];return
 if kind=="encount":session.status="battle";session.battle=regex("(?i)^encount\\s*(.*)$",text).get_string(1).strip_edges();session.queue=[];return
 if kind=="endwindow":
  var values=integers(text)
  session.status="window";session.pending={"kind":"window","line":session.line,"message":values[0] if not values.is_empty() else 0,"choices":["OK"],"handlers":{},"body":[],"terminal":true};return
 if kind=="endblock":session.status="done";session.queue=[];return
 stop(session,"Unsupported original gameplay command: "+text,session.line,"source" if kind in ["winodw_ok","endwinodw"] or kind.is_empty() else "technical")

static func step(session:Dictionary):
 var budget=2048
 while session.status=="running" and not session.queue.is_empty():
  budget-=1
  if budget<=0:stop(session,"Original event exceeded its bounded instruction budget");return
  var node:Dictionary=session.queue.pop_front();session.line=int(node.get("line",0))
  if node.kind=="window":session.status="window";session.pending=node;return
  if node.kind=="if":
   var allowed=condition(session.context,node.condition)
   if not allowed.known:stop(session,allowed.reason,session.line);return
   if allowed.value:session.queue=node.body.duplicate(true)+session.queue
  else:apply_command(session,node.text)
 if session.status=="running":session.status="done"

static func choose_context(session:Dictionary,answer:String):
 if session.status!="window" or session.get("committed",false):return
 var token=answer.to_upper();var node:Dictionary=session.pending
 if token=="CANCEL" or token not in node.choices:session.status="cancelled";session.queue=[];return
 if node.get("terminal",false):session.status="done";session.queue=[];return
 var alternatives:Array=node.handlers.get(token,[])
 for branch in alternatives:
  var allowed=condition(session.context,branch.condition)
  if not allowed.known:stop(session,allowed.reason,branch.line);return
  if not allowed.value:continue
  session.queue=branch.body.duplicate(true)+session.queue;session.status="running";step(session);return
 if not alternatives.is_empty():session.status="done";session.queue=[];return
 session.queue=node.body.duplicate(true)+session.queue;session.status="running";step(session)

static func take_commit(session:Dictionary)->Dictionary:
 if session.get("committed",false) or session.status not in ["done","warp","battle"]:return {}
 session.committed=true
 return session.context

static func base_context(game)->Dictionary:
 var tree:SceneTree=game.get_tree();var external:Dictionary=tree.get_meta("east_source_external_state",{}).duplicate(true)
 var context={"items":tree.get_meta(ITEMS,{}).duplicate(true),"gold":int(game.model.gold),"level":int(game.model.team_progression.level),"group":1,"seed":int(game.model.seed_value),"external":external,"bags":tree.get_meta("east_event_bags",{}).duplicate(true),"refills":tree.get_meta("east_event_refills",{}).duplicate(true),"now":Time.get_unix_time_from_system(),"hp":float(game.player.hp),"max_hp":float(game.player.max_hp)}
 var hour:float=game.explorer_clock.hour
 context.nowtime=3 if game.explorer_clock.night() else 0 if hour<8 else 2 if hour>=16 else 1
 return context

static func source_context(game,context:Dictionary,source:int):
 var region=load("res://scripts/forest/forest_east_region.gd")
 var area:String=game.model.falan_area
 if source<=0:return
 context.source_map=source
 if source!=777:context.floor=source
 var p=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 if source==777:
  var maps=load("res://scripts/forest/forest_original_maps.gd")
  var prayer=load("res://scripts/forest/forest_black_prayer.gd")
  var state={"origin":prayer.ORIGIN} if game.model.falan_floor in prayer.FLOORS else maps.state(game.model.falan_floor,game.model.seed_value)
  context.cell=Vector2i(((p-state.origin)/3.).round())
 else:
  var origin:Vector2=region.source_point(source,Vector2i.ZERO,area)
  var x:Vector2=region.source_point(source,Vector2i.RIGHT,area)-origin;var y:Vector2=region.source_point(source,Vector2i.DOWN,area)-origin
  context.cell=Vector2i((Transform2D(x,y,origin).affine_inverse()*p).round())


static func game_context(game,actor:Dictionary)->Dictionary:
 var context=base_context(game);source_context(game,context,int(actor.source));return context

static func item_game_context(game)->Dictionary:
 var context=base_context(game)
 var region=load("res://scripts/forest/forest_east_region.gd")
 var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var source:int=region.current_source(game.model,at)
 var known={"city":1000,"il_village":2000,"alyut":2400}
 if source<=0 and known.has(game.model.falan_area):source=known[game.model.falan_area]
 source_context(game,context,source)
 context.runtime_at=[at.x,at.y]
 return context

static func use_item(game,id:int)->bool:
 var record:Dictionary=item_data().get("items",{}).get(str(id),{})
 var context=item_game_context(game)
 var session=begin_item_context(id,record,context)
 session.actor.runtime_at=context.runtime_at
 serial+=1;session.serial=serial
 game.set_meta(SESSION,session);show_state(game,session)
 return session.status!="blocked"

static func warp_phase(args:String,phase:int)->bool:
 var fields=args.split("|",true)
 return phase>=0 and phase<4 and fields.size()>4 and fields[4].is_valid_int() and bool(int(fields[4])&(1<<phase))

static func validate_destination(session:Dictionary,checker:Callable)->bool:
 if session.status!="warp" or int(session.destination[1])==0:return true
 var destination:Array=session.destination;var cell=Vector2i(destination[2],destination[3])
 if checker.call(int(destination[1]),cell):return true
 stop(session,"No owned original destination for source map %d at %s"%[destination[1],str(cell)],int(session.get("line",0)))
 return false

static func commit_health(game,context:Dictionary)->bool:
 if not context.get("health_changed",false):return true
 # SetLp changes the stat itself; combat armor, dodge and hit invulnerability do not alter an event setter.
 game.player.hp=clampf(float(context.hp),0.0,float(game.player.max_hp))
 if game.player.hp>0:return true
 if game.player.active_ability!=null:game.player.active_ability.die()
 game.defeat()
 return false

static func show_state(game,session:Dictionary):
 if session.status=="blocked" and session.blocker.get("reason","")=="Original chat response has not been entered":session.status="chat"
 if session.status=="chat":
  var expected:int=session.serial
  var trigger=Label3D.new()
  game.show_boss_dialogue(session.actor.get("name","旅人"),[{"text":"你想說些什麼？","portrait":null,"options":[["OK","確定"],["CANCEL","返回"]],"entry":true}],trigger,func():respond(game,expected,"CANCEL"))
  trigger.free();game.dialogue.chosen.connect(func(answer:String):respond(game,expected,answer));return
 if session.status=="blocked":
  var all:Dictionary=game.get_tree().get_meta(BLOCKERS,{})
  var blocker:Dictionary=session.blocker;all[str(session.actor.id)]=blocker;game.get_tree().set_meta(BLOCKERS,all)
  game.toast("條件尚未達成。")
  return
 if session.status=="cancelled":return
 if session.actor.get("dialogue_owner","")=="black_prayer" and not load("res://scripts/forest/forest_black_prayer_events.gd").on_map(game,session.actor):
  stop(session,"Source actor map changed during the conversation");show_state(game,session);return
 if session.actor.get("dialogue_owner","")=="sokia_cape_access" and not load("res://scripts/forest/forest_sokia_cape.gd").on_map(game.model,session.actor):
  stop(session,"Source actor map changed during the conversation");show_state(game,session);return
 if session.actor.get("dialogue_owner","")=="sokia_server" and (game.model.falan_area!="interior"or game.model.falan_floor!=int(session.actor.source)):
  stop(session,"Source actor map changed during the conversation");show_state(game,session);return
 if session.actor.get("dialogue_owner","")=="explore_source" and game.model.get_instance_id()!=int(session.context.get("source_model",-1)):
  stop(session,"Source actor map changed during the conversation");show_state(game,session);return
 if session.actor.get("dialogue_owner","")=="sokia_wind" and not load("res://scripts/forest/forest_sokia_cape.gd").on_map(game.model,session.actor):
  stop(session,"Source actor map changed during the conversation");show_state(game,session);return
 if session.status=="window":
  var options=[]
  for token in session.pending.choices:
   var label="是" if token=="YES" else "否" if token=="NO" else "繼續" if token in ["OK","NEXT"] else "選項 "+str(options.size()+1)
   options.append([token,label])
  var expected:int=session.serial
  var trigger=Label3D.new()
  var text="要繼續嗎？" if "YES" in session.pending.choices else "請繼續聽我說。"
  if session.actor.get("dialogue_owner","")=="black_prayer":text=load("res://scripts/forest/forest_black_prayer_events.gd").data().messages.get(str(session.pending.message),text)
  elif session.actor.get("dialogue_owner","")=="sokia_cape_access":text=load("res://scripts/forest/forest_sokia_cape.gd").access().messages.get(str(session.pending.message),text)
  elif session.actor.get("dialogue_owner","")=="sokia_server":text=load("res://scripts/forest/forest_south_kili_population.gd").server_events(game.model.falan_floor).messages.get(str(session.pending.message),text)
  elif session.actor.get("dialogue_owner","")=="explore_source":text=load("res://scripts/forest/forest_explore_routes.gd").catalog.source_events.messages.get(str(session.pending.message),text)
  elif session.actor.get("dialogue_owner","")=="sokia_wind":text=load("res://scripts/forest/forest_east_region.gd").wind_events().messages.get(str(session.pending.message),text).replace("@c","").strip_edges()
  game.show_boss_dialogue(session.actor.get("name","旅人"),[{"text":text.strip_edges(),"portrait":null,"options":options}],trigger,func():respond(game,expected,"CANCEL"))
  trigger.free();game.dialogue.chosen.connect(func(answer:String):respond(game,expected,answer))
  return
 if session.status in ["done","warp","battle"] and not validate_item_held(session,game.get_tree().get_meta(ITEMS,{})):
  show_state(game,session);return
 if session.status=="warp":
  var region=load("res://scripts/forest/forest_sokia_cape.gd") if session.actor.get("dialogue_owner","")=="sokia_cape_access" else load("res://scripts/forest/forest_east_region.gd")
  if not validate_destination(session,func(source:int,cell:Vector2i):return region.can_travel_source(game,source,cell)):
   show_state(game,session);return
 if int(game.model.gold)!=int(session.initial.gold) or game.get_tree().get_meta(ITEMS,{})!=session.initial.items:
  stop(session,"Quest inventory changed during the source conversation");show_state(game,session);return
 if session.context.get("health_changed",false) and not is_equal_approx(float(game.player.hp),float(session.initial.hp)):
  stop(session,"Player health changed during the source conversation");show_state(game,session);return
 if session.status=="battle" and float(session.context.get("hp",1.0))>0:
  var owner:String=session.actor.get("battle_owner","")
  var battle_owner=load("res://scripts/forest/forest_black_prayer_events.gd") if owner=="black_prayer" else load("res://scripts/forest/forest_sokia_cape.gd") if owner=="sokia_cape" else load("res://scripts/forest/forest_east_battles.gd")
  if not battle_owner.begin(game,session.actor,session.battle):
   stop(session,"Native source encounter could not start",int(session.get("line",0)));show_state(game,session);return
 var commit=take_item_commit(session,game.get_tree().get_meta(ITEMS,{})) if session.has("item_use") else take_commit(session)
 if commit.is_empty():return
 game.get_tree().set_meta(ITEMS,commit.items);game.model.gold=int(commit.gold)
 game.get_tree().set_meta("east_event_bags",commit.get("bags",{}));game.get_tree().set_meta("east_event_refills",commit.get("refills",{}))
 if not commit_health(game,commit):return
 if session.status=="warp":
  var destination:Array=session.destination
  if int(destination[1])>0:
   var region=load("res://scripts/forest/forest_sokia_cape.gd") if session.actor.get("dialogue_owner","")=="sokia_cape_access" else load("res://scripts/forest/forest_east_region.gd")
   region.travel_source(game,int(destination[1]),Vector2i(destination[2],destination[3]))

static func respond(game,expected:int,answer:String):
 var session:Dictionary=game.get_meta(SESSION,{})
 if session.is_empty() or int(session.serial)!=expected or session.status not in ["window","chat"]:return
 var was_chat:bool=session.status=="chat"
 var words:String=game.dialogue.entry.text if was_chat and is_instance_valid(game.dialogue) else ""
 # Invalidate the old signal before closing its dialogue or creating the next one.
 serial+=1;session.serial=serial
 if is_instance_valid(game.dialogue):game.close_boss_dialogue()
 if was_chat:
  if answer.to_upper()=="CANCEL":session.status="cancelled";game.set_meta(SESSION,session);return
  var context:Dictionary=session.initial.duplicate(true);context.chat=words
  var item_id:int=int(session.get("item_use",0));var original:Dictionary=session.get("program",population.scripts.get(session.actor.script,{}))
  session=begin_item_context(item_id,item_data().items.get(str(item_id),{}),context) if item_id>0 else begin_context(session.actor,original,context)
  session.serial=serial
 else:
  if session.actor.get("dialogue_owner","")in["black_prayer","sokia_server","explore_source"]:session.context.now=Time.get_unix_time_from_system()
  choose_context(session,answer)
 game.set_meta(SESSION,session);show_state(game,session)

static func action(game,key:String)->bool:
 if key.begins_with("sokia_server:"):
  var source:Dictionary=load("res://scripts/forest/forest_south_kili_population.gd").server_events(game.model.falan_floor)
  var actor:Dictionary=source.actors.get(key.trim_prefix("sokia_server:"),{})
  if actor.is_empty()or game.model.falan_area!="interior"or game.model.falan_floor!=int(actor.source):return true
  return source_actor(game,actor,source.scripts.get(actor.script,{}))
 if not key.begins_with("east_event:"):return false
 data()
 var id=key.trim_prefix("east_event:");var actor:Dictionary=actor_index.get(id,{})
 if actor.is_empty():return true
 return source_actor(game,actor)

static func source_actor(game,actor:Dictionary,original_script:Dictionary={})->bool:
 data()
 if actor.get("dialogue_owner","")=="sokia_wind" and not load("res://scripts/forest/forest_sokia_cape.gd").on_map(game.model,actor):return true
 var id=str(actor.id)
 var all:Dictionary=game.get_tree().get_meta(BLOCKERS,{});all.erase(id);game.get_tree().set_meta(BLOCKERS,all)
 var kind=str(actor.type).to_lower()
 if kind not in ["event","watchevent","watchex","standenemy","housemaster","warp","housewarp2"]:return true
 var context=game_context(game,actor)
 if actor.get("dialogue_owner","")=="explore_source":context.source_model=game.model.get_instance_id()
 if actor.get("dialogue_owner","")=="sokia_wind" and not context.external.has("bimage") and "appearance"in game.player.model and game.player.model.appearance.has("id"):
  context.external.bimage=int(game.player.model.appearance.id)
 if actor.get("unbounded_source_quest_items",false):context.external.itemspace=1
 if int(actor.get("source_have_item_equality",0))==18419:context.external.haveitem=18419 if item_count(context.items,18419)>0 else 0
 var script:Dictionary
 if kind=="standenemy":script={"blocks":[{"condition":"","line":actor.source_line,"lines":[[actor.source_line,"Encount "+actor.script]]}]}
 elif kind=="warp":
  var fields=actor.script.split("|",true)
  if fields.size()<=4 or not fields[4].is_valid_int():
   var blocked={"actor":actor,"status":"running","queue":[]};stop(blocked,"Original Warp has no verified day-phase mask",int(actor.source_line),"source");show_state(game,blocked);return true
  if not warp_phase(actor.script,int(context.nowtime)):game.toast("現在還不能通過。");return true
  script={"blocks":[{"condition":"","line":actor.source_line,"lines":[[actor.source_line,"Warp "+",".join(fields.slice(0,4))]]}]}
 else:script=original_script if not original_script.is_empty() else population.scripts.get(actor.script,{})
 if script.is_empty():
  var session={"actor":actor,"status":"running","queue":[]};stop(session,"Original event payload has no supported script or landing",int(actor.source_line),"source");show_state(game,session);return true
 var session=begin_context(actor,script,context);serial+=1;session.serial=serial
 if not original_script.is_empty():session.program=original_script
 game.set_meta(SESSION,session);show_state(game,session)
 return true
