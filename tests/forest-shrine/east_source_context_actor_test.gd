extends SceneTree
## Original overlapping field actors: source state-machine proof, not a scene-support claim.
const Events=preload("res://scripts/forest/forest_east_events.gd")
const Context=preload("res://scripts/forest/forest_east_source_context_review.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT=Context.ROOT+"field-actor-contracts.json"
var checks=0
var failures=[]
var cases=[]
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func state()->Dictionary:
 return {"items":{},"gold":600,"level":30,"group":1,"nowtime":1,"source_map":100,"floor":100,"cell":Vector2i(532,33),"seed":42,"external":{},"bags":{},"refills":{},"now":120000.0,"hp":100.0,"max_hp":100.0}
func actor(data:Dictionary,id:String)->Dictionary:
 for row:Dictionary in data.actors:
  if str(row.id)==id:return row
 return {}
func expect_prompt(who:Dictionary,script:Dictionary,context:Dictionary,message:int,label:String)->Dictionary:
 var initial=context.duplicate(true);var session=Events.begin_context(who,script,context)
 check(session.status=="window" and int(session.pending.get("message",-1))==message,label+" selects original first-match prompt")
 check(Events.take_commit(session).is_empty() and context==initial,label+" waits for acknowledgement and preserves caller state")
 Events.choose_context(session,"OK");var commit=Events.take_commit(session)
 check(not commit.is_empty() and session.status=="done" and not session.has("destination"),label+" completes without an invented transfer")
 check(Events.take_commit(session).is_empty(),label+" commits once")
 cases.append({"actor":who.id,"label":label,"message":message,"items_before":initial.items,"items_after":commit.get("items",{})})
 return commit
func run():
 var paths=["scripts/forest/forest_east_events.gd","assets/maps/falan/east_region/population.json","scripts/forest/forest_east_source_context_review.gd",String(Context.ROOT+"field100-restore.json").trim_prefix("res://"),String(Context.ROOT+"100.dat").trim_prefix("res://"),"assets/references/crossgate_tina/events/msg.txt","tests/forest-shrine/east_source_context_actor_test.gd"]
 var before=Fresh.snapshot(paths);var data=Events.data();var checkpoint=actor(data,"305082");var resident=actor(data,"305092")
 check(int(checkpoint.get("source",-1))==100 and Vector2i(int(checkpoint.cell[0]),int(checkpoint.cell[1]))==Vector2i(532,33) and checkpoint.get("script")=="EV_mag_305082.txt","Checkpoint remains original source100 actor at532,33")
 check(int(resident.get("source",-1))==100 and Vector2i(int(resident.cell[0]),int(resident.cell[1]))==Vector2i(533,33) and resident.get("script")=="EV_mag_305092.txt","Resident remains original source100 actor at533,33")
 var program:Dictionary=data.scripts[checkpoint.script];var resident_program:Dictionary=data.scripts[resident.script]
 check(program.sha256=="0c0b4a1e00797b05ce9c45daa1108f30306ce0ce0c3dbaafca0b49c55058660a","Checkpoint program retains pinned source SHA")
 check(resident_program.sha256=="f40367b2f28f9df6fb28855c55342fd70989c8429cb70eb45506886370c9698b","Resident program retains pinned source SHA")
 check(FileAccess.get_sha256(Events.CHAT_PROVENANCE.local_file)==Events.CHAT_PROVENANCE.sha256 and Events.CHAT_KEYWORDS.has("15735"),"Checkpoint password is available from verified original message bytes")
 var field=Context.field_restore_data();var bits=Marshalls.base64_to_raw(field.native_walk_bits)
 for at in [Vector2i(532,33),Vector2i(533,33),Vector2i(549,43)]:
  var index=at.y*int(field.size[0])+at.x
  check(bool(bits[index>>3]&(1<<(index&7))),"Original field walk bit is open at actor/automatic-entrance cell "+str(at))
 var commit=expect_prompt(checkpoint,program,state(),15695,"No checkpoint quest item")
 check(commit.items.is_empty(),"No-item checkpoint dialogue grants no free quest progress")
 for id in [18907,18909,18910,18911,18912,18913,18914,18915,18916]:
  var context=state();context.items["source_item_"+str(id)]=1
  commit=expect_prompt(checkpoint,program,context,15696,"Held other checkpoint stage "+str(id))
  check(commit.items==context.items,"Other checkpoint stage remains untouched "+str(id))
 var correct=state();correct.items.source_item_18908=1;correct.chat=Events.CHAT_KEYWORDS["15735"].text
 commit=expect_prompt(checkpoint,program,correct,15693,"Exact original checkpoint response")
 check(Events.item_count(commit.items,18908)==0 and Events.item_count(commit.items,18909)==1,"Exact response exchanges only18908 for18909")
 var wrong=state();wrong.items.source_item_18908=1;wrong.chat="unverified response"
 commit=expect_prompt(checkpoint,program,wrong,15694,"Incorrect checkpoint response")
 check(commit.items==wrong.items,"Wrong response retains the original checkpoint item")
 var omitted=state();omitted.items.source_item_18908=1
 var session=Events.begin_context(checkpoint,program,omitted)
 check(session.status=="blocked" and str(session.blocker.reason)=="Original chat response has not been entered" and Events.take_commit(session).is_empty(),"An unentered response cannot bypass the original chat gate")
 var finished=correct.duplicate(true);finished.items.source_item_18917=1
 commit=expect_prompt(checkpoint,program,finished,15677,"Finished quest takes the first source block")
 check(commit.items==finished.items,"First-match completed branch suppresses the otherwise-valid exchange")
 for source_items in [{},{"source_item_18908":1},{"source_item_18917":1}]:
  var context=state();context.cell=Vector2i(533,33);context.items=source_items.duplicate(true)
  commit=expect_prompt(resident,resident_program,context,15734,"Resident dialogue with held state "+str(source_items))
  check(commit.items==context.items and commit.gold==context.gold,"Resident invents neither reward nor fare")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Actor contract sources remained current")
 var report={"checks":checks,"failures":failures,"cases":cases,"source_hashes":before,"source_changed_during_run":changed,"scope":"Pure original305082/305092 event programs, first-match quest/password behavior and original100 walk bits. This does not verify actual NPC placement, rendered dialogue, Native support, approach paths or manual interaction; those remain pending the concrete Host100 scene."}
 var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_SOURCE_CONTEXT_ACTORS checks=",checks," failures=",failures.size()," cases=",cases.size())
 quit(failures.size())
