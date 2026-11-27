extends SceneTree
## Exact source branches; injected held items are fixture-only, never natural acquisition proof.
const Events=preload("res://scripts/forest/forest_east_events.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape access/"
var checks=0
var failures=0
var source:Dictionary
var branches=[]
func _initialize():run.call_deferred()
func check(value:bool,label_:String):
 checks+=1
 if not value:failures+=1;printerr("CAPE_ACCESS_FAIL "+label_)
func context(items:Dictionary={})->Dictionary:
 return {"items":items.duplicate(true),"gold":5000,"level":100,"group":1,"seed":571,"external":{},"bags":{},"refills":{},"now":1000000.,"hp":100.,"max_hp":100.}
func play(id:String,items:Dictionary={},expected_block:bool=false)->Dictionary:
 var actor:Dictionary=source.actors[id]
 var session=Events.begin_context(actor,source.scripts.get(actor.script,{}),context(items))
 var windows=[]
 for i in 40:
  if session.status!="window":break
  windows.append(session.pending.message)
  Events.choose_context(session,"NEXT" if "NEXT" in session.pending.choices else "YES" if "YES" in session.pending.choices else "OK")
 check((session.status=="blocked")==expected_block,"Supported versus unknown source branch "+id)
 branches.append({"actor":id,"fixture_items":items,"windows":windows,"status":session.status,"destination":session.get("destination",[]),"blocker":session.get("blocker",{})})
 return session
func run():
 source=JSON.parse_string(FileAccess.get_file_as_string(OUT+"Staged/events/data.json"))
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"Staged/catalog.json"))
 check(source.actors.size()==18,"All 18 scoped original actors are retained")
 check(catalog.maps.size()==5 and catalog.graphics.size()==15,"Five source layouts reuse old pages and add only 15 original graphics")
 var expected={15517:125,15520:8203,15524:32,15528:3,15529:9}
 for row:Dictionary in catalog.maps.values():
  var number=int(row.id);var cells=int(row.size[0])*int(row.size[1]);var before=Marshalls.base64_to_raw(row.raw).decompress(int(row.bytes),FileAccess.COMPRESSION_DEFLATE)
  var after=Marshalls.base64_to_raw(row.restored_raw).decompress(int(row.bytes),FileAccess.COMPRESSION_DEFLATE)
  check(row.sokia_visual_only,"New map remains review-only before camera validation "+str(number))
  check(int(row.source_completion.completed)==expected[number] and int(row.source_completion.preserved_client_variations)==0,"Pinned source completion count "+str(number))
  check(before.slice(20+cells*4)==after.slice(20+cells*4),"Every original flag remains unchanged "+str(number))
  var unchanged=true
  for i in cells:
   if before.decode_u16(20+(cells*2+i)*2)&0xc000:
    unchanged=unchanged and before.decode_u16(20+i*2)==after.decode_u16(20+i*2) and before.decode_u16(20+(cells+i)*2)==after.decode_u16(20+(cells+i)*2)
  check(unchanged,"Every recorded floor/object tuple remains unchanged "+str(number))
 for proof:Dictionary in source.source_provenance.values():
  check(FileAccess.get_sha256("res://assets/references/crossgate_sokia/events/"+proof.file)==proof.sha256,"Pinned original script bytes "+proof.file)
 var held={"source_item_18598":1}
 var exchange=play("5237",held)
 check(exchange.status=="done" and Events.item_count(exchange.context.items,18598)==0 and Events.item_count(exchange.context.items,18599)==1,"Fixture-only held 18598 exchanges for 18599 through original script")
 var repeated=play("5237",exchange.context.items)
 check(Events.item_count(repeated.context.items,18599)==1,"Source duplicate refusal keeps one existing 18599")
 var malformed=play("5237",{},true)
 check(malformed.status=="blocked" and malformed.context.items.is_empty() and int(malformed.blocker.line)==19,"Malformed original window_21069 stays guarded; no invented fight or grant")
 var denied=play("5239")
 check(not denied.has("destination"),"Missing 18599 never opens source guard 5239")
 var gate=play("5239",{"source_item_18599":1})
 check(gate.status=="warp" and gate.destination==[0,15524,16,19] and Events.item_count(gate.context.items,18599)==1,"Held-item source gate reaches exact 15524 landing without consuming it")
 var princess=play("5225")
 check(princess.status=="battle" and princess.battle.split("|",true)[9]=="12019","Missing 18599 preserves original princess fight")
 var palace=play("5225",{"source_item_18599":1})
 check(palace.status=="warp" and palace.destination==[0,15528,16,23],"Held-item princess dialogue reaches exact first hall")
 for id in ["5226","5227","5228"]:
  var hall=play(id,{"source_item_18599":1})
  check(hall.status=="warp" and hall.destination==[0,15529,15,16],"Original hall conversation reaches exact second hall "+id)
 for id in ["5240","5241","5242"]:
  var cape=play(id,{"source_item_18599":1})
  check(cape.status=="warp" and cape.destination==[0,15525,16,11],"Original second hall conversation reaches existing Cape gate "+id)
 var title=play("5235",{},true)
 check(title.status=="blocked" and not title.has("destination"),"Unknown PEquipItem condition stays guarded")
 var return_=play("5236")
 check(return_.status=="warp" and return_.destination==[0,100,174,171],"Original local return keeps source coordinates")
 var denied_lab=play("6117")
 check(not denied_lab.has("destination"),"No 18340 cannot pass laboratory guard")
 var lab=play("6117",{"source_item_18340":1})
 check(lab.status=="warp" and lab.destination==[0,15517,39,15],"Fixture-only source prerequisite opens exact forest path")
 check(not source.source_item_drop.execution_verified and not source.source_item_drop.production_grant_enabled and int(source.source_item_drop.raw_rate)==100,"Unverified raw 100 drop remains disabled metadata")
 var bank:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+source.bear_bank_provenance.path))
 check(FileAccess.get_sha256("res://"+source.bear_bank_provenance.path)==source.bear_bank_provenance.sha256 and int(bank.variants[135].id)==101010 and bank.variants[135].key=="original:2807","Existing companion 135 is exact Bear art, never Falan Tree skin 4")
 var file=FileAccess.open(OUT+"source-contract.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"branches":branches,"natural_acquisition_verified":false,"runtime_native_verified":false,"rendered_verified":false,"goal_complete":false,"fixture_qualification":"Held 18598/18599/18340 contexts test original branches only; no synthetic production grant or natural access proof.","events_sha256":FileAccess.get_sha256(OUT+"Staged/events/data.json"),"catalog_sha256":FileAccess.get_sha256(OUT+"Staged/catalog.json")},"  "));file.close()
 print("CAPE_ACCESS_CONTRACT checks=",checks," failures=",failures," branches=",branches.size())
 quit(1 if failures else 0)
