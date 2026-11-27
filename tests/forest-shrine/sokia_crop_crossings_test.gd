extends "res://tests/forest-shrine/sokia_house_crossing_test.gd"
const CROSSING_OUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/"
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("SOKIA_CROP_CROSSING_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-crops-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var records=[]
 var rows=JSON.parse_string(FileAccess.get_file_as_string(CROSSING_OUT+"source-crop-crossings.json"))
 for row in rows:
  var point=Vector2(row.cell[0],row.cell[1])*3.;var direction=Vector2(row.direction[0],row.direction[1])
  var frame=Tour.Regions.frame(row.area);var at=frame.inverse()*point
  var predicted=Tour.Regions.crossings(row.area,at-direction,at+direction)
  check(predicted.get("area","")==row.target,"Original map300 continues into overlapping crop: "+row.area)
  if not predicted.is_empty():check((Tour.Regions.frame(predicted.area)*predicted.arrival).distance_to(point+direction)<.001,"Crop continuation preserves the exact original source coordinate")
  Tour.travel(game,Tour.Regions.layout(row.area),{"arrival":at-direction*5.,"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(true);game.player.set_physics_process(true)
  for i in 4:await physics_frame
  var seen={}
  for link in game.model.get_meta("falan_links",[]):
   var key=str(link.at)+":"+str(link.get("site",0))+":"+str(link.get("to",""))
   check(not seen.has(key),"Overlapping crops do not duplicate an original port");seen[key]=true
  await walk_gate(at,direction)
  check(game.model.falan_area==row.target,"Normal forward movement crosses "+row.area+" → "+row.target)
  var source=Tour.Regions.frame(game.model.falan_area)*(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)/3.
  check(source.distance_to(Vector2(row.cell[0],row.cell[1]))<8.,"Actual continuation stays beside the original source crossing")
  records.append({"from":row.area,"to":game.model.falan_area,"source":str(source),"expected":row.cell})
 for area in load("res://scripts/forest/forest_sokia_scenery.gd").MASKS:
  var frame=Tour.Regions.frame(area)
  for gate in [[Vector2(274,294),Vector2.DOWN],[Vector2(294,325),Vector2.LEFT]]:
   var at=frame.inverse()*(gate[0]*3.)
   var crossing=Tour.Regions.crossings(area,at-gate[1],at+gate[1])
   check(crossing.get("area","")=="kili","Both original Kili gates remain available from every map300 alias")
 for gate in [[Vector2(274,294),Vector2.DOWN,Tour.Regions.KILI_GATE],[Vector2(294,325),Vector2.LEFT,Tour.Regions.KILI_EAST_GATE]]:
  var at=Tour.Regions.frame("sokia_coast").inverse()*(gate[0]*3.)
  Tour.travel(game,Tour.Regions.layout("sokia_coast"),{"arrival":at-gate[1]*8.,"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(true);game.player.set_physics_process(true)
  await walk_gate(at,gate[1]);check(game.model.falan_area=="kili","Normal movement enters Kili through original source gate "+str(gate[0]))
  if game.model.falan_area=="kili":
   await walk_gate(gate[2],-gate[1]);check(game.model.falan_area=="sokia_coast","Normal movement returns through the same Kili gate")
 for cell:Vector2i in Tour.Falken.ANCIENT_CELLS:
  var area="sokia_desert";var at=Tour.Regions.frame(area).inverse()*(Vector2(cell)*3.)
  Tour.travel(game,Tour.Regions.layout(area),{"arrival":at-Vector2(0,8),"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false)
  for i in 4:await physics_frame
  var gates=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("falken_route",false) and l.at.distance_to(at)<.01)
  check(gates.size()==1,"One source Falken crossing at "+str(cell))
  if gates.is_empty():continue
  check(gates[0].arrival.is_equal_approx(Tour.Falken.point(3300,Vector2i(20,28))),"Original ancient-person arrival retained")
  game.explorer_clock.load_hour(12)
  Tour.enter_link(game,area,gates[0],at)
  check(game.model.falan_area==area,"Ancient-person crossing remains closed by day")
  game.explorer_clock.load_hour(22)
  game.set_physics_process(true);game.player.set_physics_process(true)
  await walk_gate(at,Vector2.DOWN)
  check(game.model.falan_floor==3300,"Normal night movement enters the original Falken approach "+str(cell))
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Existing adventure data preserved")
 var file=FileAccess.open(CROSSING_OUT+"crop-crossing-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
 print("SOKIA_CROP_CROSSING_RESULT checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
