extends "res://tests/forest-shrine/sokia_cape_review.gd"
const PrayerBoxes=preload("res://scripts/forest/forest_black_prayer.gd")
const BOX_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Prayer chests/"
var box_report={"allocations":[],"floors":[],"limits":["Whole-branch quantity follows the pinned reference generator; original random placement and chest contents are not asserted.","Existing seeded maze, native navigation, loot rewards and opened-chest ledger remain the owners."]}
func _initialize():
 create_timer(600).timeout.connect(func():printerr("PRAYER_CHESTS_TIMEOUT");quit(1))
 run.call_deferred()
func allocation(seed_:int)->Array:
 return PrayerBoxes.FLOORS.map(func(id):return PrayerBoxes.box_count(id,seed_))
func data_checks():
 var generated=Original.generated()
 var baseline=JSON.parse_string(FileAccess.get_file_as_string(BOX_OUT+"cape-before.json"))
 for row in baseline.rows:
  var current=[]
  for n in range(1,11):current.append(generated.box_count(generated.floor_id(row.branch,n),int(row.seed)))
  check(current==row.counts.map(func(n):return int(n)),"Existing Cape allocation is exact after shared helper extraction: "+str(row.branch)+" seed"+str(row.seed))
 check(int(PrayerBoxes.source().source_config.box_amount)==4,"Pinned config301 has four whole-branch boxes")
 for seed_ in [41829558,1,303,9876,-5,2147483646]:
  var before=PrayerBoxes.FLOORS.map(func(id):return PrayerBoxes.walk_mask(id,seed_).hex_encode().sha256_text())
  var boxes=allocation(seed_)
  check(boxes.reduce(func(total,n):return total+n,0)==4,"Exactly four across six logical floors: seed"+str(seed_))
  check(allocation(seed_)==boxes,"Same seed reuses allocation without redrawing")
  check(generated.box_allocations.size()==1,"New seed releases obsolete branch allocations")
  check(PrayerBoxes.FLOORS.map(func(id):return PrayerBoxes.walk_mask(id,seed_).hex_encode().sha256_text())==before,"Chest selection preserves every existing walk bit")
  box_report.allocations.append({"seed":seed_,"counts":boxes})
 check(allocation(41829558)==box_report.allocations[0].counts,"Returning to an older seed regenerates the same allocation")
func enter_floor(id:int):
 var layout:Dictionary=Tour.Indoor.layout(id);layout.seed=41829558
 var warp=PrayerBoxes.stairs(id,41829558)
 Tour.travel(game,layout,{"arrival":PrayerBoxes.point(warp[0]+Vector2i.UP),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.model.waves.spawned=2
func run():
 data_checks()
 if "--counts-only" not in OS.get_cmdline_user_args():await world_checks()
 box_report.checks=checks;box_report.failures=errors;box_report.goal_complete=false
 var name_="allocation" if "--counts-only" in OS.get_cmdline_user_args() else "native-placement"
 var file=FileAccess.open(BOX_OUT+name_+".json",FileAccess.WRITE);file.store_string(JSON.stringify(box_report,"  "));file.close()
 print("PRAYER_CHESTS_RESULT checks=",checks," failures=",errors," floors=",box_report.floors.size())
 if is_instance_valid(game):game.queue_free();await process_frame
 quit(1 if errors else 0)
func world_checks():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-prayer-chests-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var slain=get_meta(PrayerBoxes.SLAIN,{}).duplicate(true)
 var total=0;var opened_floor=0;var opened_keys=[];var positions={}
 for id:int in PrayerBoxes.FLOORS:
  await enter_floor(id)
  var chests=game.exploration_loot.slots.filter(func(slot):return slot.active and slot.chest)
  var expected=PrayerBoxes.box_count(id,41829558);total+=chests.size()
  check(chests.size()==expected,"Existing loot owner realizes assigned count on floor"+str(id))
  var bits=PrayerBoxes.walk_mask(id,41829558);var exits=game.model.get_meta("falan_links",[])
  var valid=true;var keys=[];var rows=[]
  for slot in chests:
   var local:Vector3=slot.pos/game.model.falan_scale
   var at=Vector2(local.x,local.z);var cell=Vector2i(((at-PrayerBoxes.ORIGIN)/3.).round())
   valid=valid and Tour.Indoor.open_cell(bits,PrayerBoxes.SIZE,cell.x,cell.y)
   valid=valid and exits.all(func(link):return at.distance_squared_to(link.at)>=36)
   valid=valid and game.army_runtime.native.can_reach(game.player.position,slot.pos,.8)
   keys.append(slot.key);rows.append({"key":slot.key,"cell":[cell.x,cell.y],"position":str(slot.pos)})
  check(valid,"Every chest has source floor support, stair clearance and native reachability")
  positions[id]=keys
  box_report.floors.append({"floor":id,"expected":expected,"actual":chests.size(),"chests":rows})
  if opened_floor==0 and not chests.is_empty():
   opened_floor=id;opened_keys=keys.duplicate()
   for slot in chests:game.exploration_loot.consume_chest(slot)
 check(total==4,"Exactly four actual reachable chests across the whole branch")
 check(opened_floor!=0,"A source-allocated floor supports the opened-ledger reentry check")
 if opened_floor:
  var ledger=game.exploration_loot.opened_chests.duplicate(true)
  await enter_floor(opened_floor)
  check(game.exploration_loot.slots.filter(func(slot):return slot.active and slot.chest).is_empty(),"Travel back does not respawn consumed chests")
  check(game.exploration_loot.opened_chests==ledger and opened_keys.all(func(key):return ledger.has(key)),"Map changes preserve original opened-chest identities")
 check(get_meta(PrayerBoxes.SLAIN,{})==slain,"Chest preparation does not mutate the legacy death ledger")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Direct fixture travel preserves saved adventure data")
