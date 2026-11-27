extends "res://tests/forest-shrine/east_event_contract_test.gd"
## Held source item programs use the same transaction and dialogue owner as NPC events.

func run():
 var catalog=Events.item_data();var items:Dictionary=catalog.items
 var green:Dictionary=items["41046"]
 var state=context();var session=Events.begin_item_context(41046,green,state)
 check(session.status=="blocked" and Events.take_item_commit(session,state.items).is_empty(),"An unheld feather cannot start a dialogue, grant a portal or commit")
 Events.set_item(state.items,41046,1,state.now)
 session=Events.begin_item_context(41046,green,state)
 check(session.status=="window" and session.pending.message==1110456 and Events.item_count(session.context.items,41046)==1,"A held green feather opens its exact source confirmation without early consumption")
 Events.choose_context(session,"NO")
 var commit=Events.take_item_commit(session,state.items)
 check(not commit.is_empty() and Events.item_count(commit.items,41046)==1 and not session.has("destination"),"Source No leaves the held feather and position unchanged")
 session=Events.begin_item_context(41046,green,state);Events.choose_context(session,"YES")
 check(session.status=="warp" and session.destination==[0,32277,36,55],"Green feather Yes stages the exact Babel destination")
 check(Events.item_count(state.items,41046)==1 and Events.item_count(session.context.items,41046)==0,"Only the source KillItem stages the one-feather cost")
 check(not Events.validate_destination(session,func(_source,_cell):return false) and Events.take_item_commit(session,state.items).is_empty() and Events.item_count(state.items,41046)==1,"An unsupported destination cannot consume the held feather")
 session=Events.begin_item_context(41046,green,state);Events.choose_context(session,"YES")
 check(Events.validate_destination(session,func(source,cell):return source==32277 and cell==Vector2i(36,55)),"Destination preflight uses the exact source map and cell")
 commit=Events.take_item_commit(session,state.items)
 check(Events.item_count(commit.items,41046)==0 and Events.take_item_commit(session,state.items).is_empty(),"The source feather cost commits exactly once")
 session=Events.begin_item_context(41046,green,state);Events.choose_context(session,"YES")
 check(not Events.validate_item_held(session,{}) and Events.take_item_commit(session,{}).is_empty(),"Losing the item during a dialogue prevents its later commit")
 # Source16365 is deliberately reusable: its program has no KillItem statement.
 var gate=context();Events.set_item(gate.items,16365,1,gate.now);gate.floor=33000;gate.cell=Vector2i(550,430)
 session=Events.begin_item_context(16365,items["16365"],gate);Events.choose_context(session,"NEXT");Events.choose_context(session,"OK")
 commit=Events.take_item_commit(session,gate.items)
 check(session.status=="warp" and session.destination==[0,37008,36,33] and Events.item_count(commit.items,16365)==1,"A source reusable key preserves its item and exact floor/rectangle gate")
 gate.erase("floor");session=Events.begin_item_context(16365,items["16365"],gate)
 check(session.status=="blocked" and Events.take_item_commit(session,gate.items).is_empty(),"Unknown Floor blocks the relevant source Floor predicate")
 gate.floor=33000;gate.cell=Vector2i(100,100);session=Events.begin_item_context(16365,items["16365"],gate)
 check(session.status=="window" and session.pending.message==22254 and not session.has("destination"),"Known wrong source coordinates take the original denial")
 var mirror=context();Events.set_item(mirror.items,18588,1,mirror.now);mirror.floor=100;mirror.cell=Vector2i(93,85)
 session=Events.begin_item_context(18588,items["18588"],mirror)
 check(session.status=="window" and session.pending.message==15355 and not session.has("destination"),"Map101 mirror item remains denied in ordinary Freyja100")
 mirror.erase("floor");session=Events.begin_item_context(18588,items["18588"],mirror)
 check(session.status=="blocked" and not session.has("destination"),"Unknown mirror-world identity never substitutes Floor101")
 var unknown=context();Events.set_item(unknown.items,41046,1,unknown.now)
 session=Events.begin_item_context(41046,green,unknown);Events.choose_context(session,"YES")
 check(session.status=="warp","Unknown source coordinates do not invent a restriction on the unrestricted green-feather program")
 var fresh=context();Events.set_item(fresh.items,18877,1,fresh.now)
 session=Events.begin_item_context(18877,items["18877"],fresh)
 check(session.status=="window" and session.pending.message==206117 and Events.item_count(session.context.items,18877)==1,"Native item-age denial reuses the source minute contract without consuming a fresh item")
 fresh.now+=2881*60;session=Events.begin_item_context(18877,items["18877"],fresh);Events.choose_context(session,"OK")
 check(session.status=="battle" and not session.has("destination") and Events.item_count(session.context.items,18877)==0,"A mature source item stages its native encounter and waits for the battle owner, without a victory warp")
 var charged=context();charged.external.itemspace=1;Events.set_item(charged.items,15702,1,charged.now)
 session=Events.begin_item_context(15702,items["15702"],charged)
 check(session.status=="blocked" and Events.take_item_commit(session,charged.items).is_empty(),"Unknown original durability never guesses a reusable item's remaining charges")
 charged.items.source_item_dur_15702=2
 session=Events.begin_item_context(15702,items["15702"],charged);Events.choose_context(session,"YES")
 commit=Events.take_item_commit(session,charged.items)
 check(not commit.is_empty() and commit.items.source_item_dur_15702==1 and Events.item_count(commit.items,15702)==1 and Events.item_count(commit.items,15217)==1,"Verified source durability decrements transactionally without inferred auto-consumption")
 var programs={};var actors=[]
 for id in items:
  var row:Dictionary=items[id]
  if not row.program is Dictionary:continue
  programs[row.argument]=row.program
  actors.append({"id":"item:"+id,"script":row.argument,"source":"current verified item-use context","cell":"current verified source grid","type":"IuMs"})
 var report=source_audit({"actors":actors,"scripts":programs})
 check(actors.size()==92 and programs.size()==92,"All92 verified source IuMs programs remain present in the inert program audit")
 check(catalog.missing_programs.is_empty(),"Every referenced current item-use source program is available")
 report["handler"]=catalog.handler;report["source_hashes"]=catalog.source_hashes;report["unknown_builtin_handlers"]=catalog.unknown_builtin_handlers
 report["runtime_battle_scope"]={"items":[18877,18878,18879,18880],"reason":"The existing East native sprite bank must own the current map; incompatible legacy/nonEast owners block the item encounter before consumption. No alternate enemies are substituted."}
 report["item_records"]=items.size();report["program_records"]=actors.size();report["context_rule"]="Floor and source cells are available only for verified original map frames; generated templates do not masquerade as a fixed source Floor. Unknown predicates block only when relevant."
 var file=FileAccess.open(OUT+"item-source-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 file=FileAccess.open(OUT+"item-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"programs":programs.size(),"items":items.size(),"scope":"Pure held-item source programs, dialogue branches, consumption transactions and context gates. Runtime UI/battle placement uses the shared game owners."},"  "));file.close()
 print("EAST_ITEM_CONTRACT_RESULT checks=",checks," failures=",failures," programs=",programs.size()," compile_blockers=",report.source_blockers.size()," unsupported_gameplay=",report.technical_blockers.size())
 quit(1 if failures else 0)
