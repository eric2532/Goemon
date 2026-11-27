extends SceneTree
## Pure source branches and exact data; live F/native/return verification is separate.
const Source=preload("res://scripts/forest/forest_black_prayer_events.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/"
var checks=0
var failures=0
var branches=[]
class MapScope extends RefCounted:
 var model={"falan_area":"interior","falan_floor":16508}
func _initialize():
 create_timer(120).timeout.connect(func():printerr("BLACK_PRAYER_EVENT_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("BLACK_PRAYER_EVENT_FAIL "+label_)
func context(items:Dictionary={},group_:int=1)->Dictionary:
 return {"items":items.duplicate(true),"gold":5000,"level":100,"group":group_,"seed":341,"external":{},"bags":{},"refills":{},"now":1000000.,"hp":100.,"max_hp":100.}
func play(id:String,ctx:Dictionary,answers:Array=[],adapt:bool=true)->Dictionary:
 var actor:Dictionary=Source.data().actors[id];var copy=ctx.duplicate(true)
 if adapt:
  copy.external.itemspace=1
  if actor.has("source_have_item_equality"):copy.external.haveitem=18419 if Events.item_count(copy.items,18419)>0 else 0
 var session=Events.begin_context(actor,Source.data().scripts.get(actor.script,{}),copy)
 var windows=[];var remaining=answers.duplicate()
 for i in 40:
  if session.status!="window":break
  windows.append(session.pending.message)
  var answer=remaining.pop_front() if not remaining.is_empty() else "NEXT" if "NEXT" in session.pending.choices else "OK"
  Events.choose_context(session,answer)
 check(session.status!="blocked","Strict source program parses its supported branch "+id+" "+str(session.get("blocker",{})))
 branches.append({"actor":id,"windows":windows,"status":session.status,"destination":session.get("destination",[]),"items":session.context.items})
 return session
func run():
 var staged="--staged" in OS.get_cmdline_user_args()
 if staged:Source.source=JSON.parse_string(FileAccess.get_file_as_string(OUT+"Staged/data.json"))
 var data:Dictionary=Source.data()
 var scope=MapScope.new()
 check(Source.on_map(scope,data.actors["6305"]),"Source guard is owned only by its original current map")
 check(not Source.on_map(scope,data.actors["6309"]),"Post-victory actor cannot execute from the pre-battle map")
 var template:Dictionary=data.actors["6303"].duplicate(true);template.runtime_floor=30102
 check(not Source.on_map(scope,template),"Generated NPC cannot execute outside its selected runtime floor")
 var unknown=Events.begin_context(data.actors["6300"],data.scripts[data.actors["6300"].script],context())
 check(unknown.status=="blocked" and "haveitem" in unknown.blocker.reason,"Unknown pure HaveItem remains guarded")
 var start=play("6300",context(),["YES","YES","NEXT","YES","OK"])
 check(start.status=="done" and Events.item_count(start.context.items,18419)==1,"Natural source6300 grants only confirmed letter18419")
 var repeat=play("6300",start.context)
 check(Events.item_count(repeat.context.items,18419)==1,"Held source letter cannot duplicate")
 var candle=play("6301",start.context,["YES","NEXT","OK","OK"])
 check(Events.item_count(candle.context.items,18419)==0 and Events.item_count(candle.context.items,18420)==1,"Source6301 exchanges letter for candle")
 check(candle.context.items.get("source_nowevent_3")==1 and float(candle.context.items.get("source_item_birth_18420",0))==1000000.,"Original quest flag and candle creation time are recorded")
 var rock=play("6302",candle.context,["YES"])
 check(rock.status=="warp" and rock.destination==[0,16507,7,4],"Candle/solo source rock reaches original entrance cell")
 var no_candle=play("6302",context())
 check(not no_candle.has("destination"),"No candle never opens original rock entrance")
 var grouped=candle.context.duplicate(true);grouped.group=2
 var denied=play("6302",grouped,["YES","OK"])
 check(not denied.has("destination"),"Source rock retains solo denial")
 var proof=play("6303",candle.context,["OK","YES","OK"])
 check(Events.item_count(proof.context.items,18421)==1 and Events.item_count(proof.context.items,18420)==1,"Natural source6303 supplies proof18421 while retaining candle")
 var proof_repeat=play("6303",proof.context)
 check(Events.item_count(proof_repeat.context.items,18421)==1,"Existing proof denies a duplicate grant")
 var without_capacity=candle.context.duplicate(true);without_capacity.external.erase("itemspace")
 var capacity=Events.begin_context(data.actors["6303"],data.scripts[data.actors["6303"].script],without_capacity)
 check(capacity.status=="blocked" and "itemspace" in capacity.blocker.reason,"Pure unknown capacity is never silently unlimited")
 var gate=play("6305",proof.context,["YES"])
 check(gate.status=="warp" and gate.destination==[0,16508,24,29] and Events.item_count(gate.context.items,18421)==0,"Source guard consumes proof and crosses the original barrier")
 var no_proof=play("6305",candle.context)
 check(not no_proof.has("destination"),"No proof cannot pass the source guard")
 grouped=proof.context.duplicate(true);grouped.group=2
 denied=play("6305",grouped)
 check(not denied.has("destination") and Events.item_count(denied.context.items,18421)==1,"Grouped denial does not consume proof")
 var renewed=play("6303",gate.context,["OK","NO","OK"])
 check(Events.item_count(renewed.context.items,18421)==1,"Source acquisition remains usable after the guard consumes proof")
 for id in ["6308","6309"]:
  var fresh=play(id,candle.context,["NEXT","OK"])
  check(fresh.status=="warp" and fresh.destination==[0,3351 if id=="6308" else 3354,8,8],"Fresh candle uses exact source reward return "+id)
  check(Events.item_count(fresh.context.items,18420)==0 and fresh.context.items.get("source_endevent_3")==1,"Fresh return consumes candle and commits EndEvent3 "+id)
  var old=candle.context.duplicate(true);old.now+=61.*60.
  var expired=play(id,old,["OK"])
  check(expired.status=="warp" and expired.destination==[0,3350,7,6] and Events.item_count(expired.context.items,18420)==0,"Expired candle uses source house return "+id)
  var absent=play(id,context(),["OK"])
  check(absent.status=="warp" and absent.destination==[0,3350,7,6],"Absent candle still uses source house return "+id)
  var group_return=play(id,context({},2),["OK"])
  check(not group_return.has("destination"),"Post-victory source return remains solo "+id)
 var shanti=play("6927",context())
 check(shanti.status=="warp" and shanti.destination==[0,5011,8,6],"Original optional Shanti room return")
 var back=play("6928",context())
 check(back.status=="warp" and back.destination==[0,16509,32,13],"Shanti room returns to the exact original post-palace cell")
 for id in ["6310","6311"]:
  var reward=play(id,context(),["YES"])
  check(reward.status=="warp" and reward.destination==[0,3352,5,9],"Both source reward-room exits reach original research room "+id)
 var paid=play("6917",context(),["NEXT","NEXT","NEXT","YES","YES","OK"])
 check(paid.status=="warp" and paid.destination==[0,3350,7,6] and paid.context.gold==4000,"Paid source Shanti branch spends1000 and returns to original house")
 var npc_variants={}
 for seed_ in 32:
  var placed:Dictionary=Source.generated_npcs(seed_);check(placed.size()==2 and placed["6303"]!=placed["6304"],"One of each adapted NPC uses distinct seeded stations")
  for id in placed:
   var at:Array=placed[id];var floor_:int=at[0];var cell:Vector2i=at[1]
   var bits=Source.Prayer.walk_mask(floor_,seed_)
   var index=cell.y*Source.Prayer.SIZE.x+cell.x
   check(floor_ in Source.Prayer.FLOORS and (bits[index>>3]&(1<<(index&7)))!=0,"Adapted dynamic actor uses existing source-floor native ground")
   check(Source.Prayer.stairs(floor_,seed_).all(func(stair):return cell.distance_squared_to(stair)>=9),"Dynamic actor keeps existing stairs clear")
   npc_variants[var_to_str(at)]=true
 check(npc_variants.size()>2,"Different run seeds vary adapted dynamic NPC placement")
 var post:Dictionary=data.post;var raw=Marshalls.base64_to_raw(post.raw).decompress(15020,FileAccess.COMPRESSION_DEFLATE)
 var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(raw)
 check(digest.finish().hex_encode()==post.raw_sha256 and raw.decode_u32(12)==50 and raw.decode_u32(16)==50,"Post-victory layout preserves the exact client/source hybrid bytes")
 check(post.completion.completed==571 and post.completion.preserved_client_variations==0 and post.completion.layout_complete,"All571uncached cells recover from the source; recorded client cells remain exact")
 digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(raw.slice(10020))
 check(digest.finish().hex_encode()==post.client_flags_sha256,"Every original client flag remains exact after source completion")
 var expected_props=[];var prop_owner=preload("res://assets/maps/falan/ruby_room_props.gd")
 for i in 2500:
  var serial=raw.decode_u16(20+(2500+i)*2)
  if prop_owner.GRAPHICS.has(serial):expected_props.append([Vector2i(i%50,i/50),serial])
 check(Source.post_tiles("floor_tiles").size()==5000 and Source.post_tiles("wall_tiles").size()==5000 and Source.post_props()==expected_props,"Post-palace reuses existing original art at every exact source anchor")
 var pre:Dictionary=data.pre;var pre_raw=Marshalls.base64_to_raw(pre.raw).decompress(15020,FileAccess.COMPRESSION_DEFLATE)
 digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(pre_raw)
 check(digest.finish().hex_encode()==pre.raw_sha256,"Pre-battle16508 preserves its own pinned source/client hybrid bytes")
 check(pre.completion.completed==253 and pre.completion.recorded==2247 and pre.completion.preserved_client_variations==0,"All253uncached16508cells recover without changing recorded client variants")
 digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(pre_raw.slice(10020))
 check(digest.finish().hex_encode()==pre.client_flags_sha256,"Every16508client flag remains exact")
 check(pre.walk_preservation.recorded_changes==0 and pre.walk_preservation.old_open_lost==0 and pre.walk_preservation.added_open==68,"Western source completion adds68open cells with no old recorded/native navigation loss")
 var interior=load("res://scripts/forest/forest_falan_interior.gd");var art=interior.RoomArt
 check(interior.floor_info(16508)[2]==pre.walk and art.floor_tiles(16508,Vector2i(50,50))==Source.palace_tiles(16508,"floor_tiles") and art.wall_tiles(16508,Vector2i(50,50))==Source.palace_tiles(16508,"wall_tiles"),"Existing interior owner consumes complete16508ground/navigation/wall data")
 check(Source.palace_props(16508)==prop_owner.PLACEMENTS[16508],"All old16508source prop anchors remain exact")
 var file=FileAccess.open(OUT+("contract-staged.json" if staged else "contract.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"branches":branches,"dynamic_npc_placement":"explicit seeded adaptation; original count/refresh/floor selection unverified","source_hashes":data.source_hashes,"goal_complete":false},"  "));file.close()
 print("BLACK_PRAYER_EVENT_RESULT checks=",checks," failures=",failures," branches=",branches.size())
 quit(1 if failures else 0)
