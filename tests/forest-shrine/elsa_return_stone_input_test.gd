extends "res://tests/forest-shrine/elsa_map_review.gd"
## Actual F input uses the same free yes/no return travel without changing saves.

func press_interact():
 game.explorer_npcs.update_left=0.;game.explorer_npcs._process(.2)
 var event=InputEventKey.new();event.physical_keycode=KEY_F;event.keycode=KEY_F;event.pressed=true;Input.parse_input_event(event)
 await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
 for i in 3:await process_frame

func run():
 await setup_review_game()
 root.gui_disable_input=false
 var saved=FileAccess.get_file_as_bytes(game.settings_path)
 var cases=[[59530,Vector2i(79,55),59520,Vector2i(175,62)],
  [59530,Vector2i(59,93),59520,Vector2i(200,96)],
  [59530,Vector2i(81,133),59520,Vector2i(228,128)],
  [59520,Vector2i(141,104),1500,Vector2i(27,82)]]
 for row in cases:
  var id=int(row[0]);var at=Original.source_point(id,row[1])
  Tour.travel(game,Original.layout(id),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
  game.camera_rig.yaw=0.;game.model.gold=0;game.model.team_progression.level=1
  for i in 8:await physics_frame
  await press_interact()
  check(is_instance_valid(game.dialogue),"F at the original return NPC opens travel "+str(row[1]))
  if not is_instance_valid(game.dialogue):continue
  var options:Array=game.dialogue.pages[game.dialogue.page].options
  check(options==[["travel","是"],["cancel","否"]],"F opens the existing yes/no stone confirmation")
  game.dialogue.chosen.emit("cancel")
  for i in 3:await process_frame
  check(game.model.falan_floor==id,"Cancelling F travel keeps the original area")
  await press_interact()
  check(is_instance_valid(game.dialogue),"The normal F action can be repeated after cancelling")
  if not is_instance_valid(game.dialogue):continue
  game.dialogue.chosen.emit("travel")
  for i in 8:await physics_frame
  var expected=Elsa.castle_point(row[3]) if int(row[2])==1500 else Original.source_point(int(row[2]),row[3])
  var actual=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  check(Tour.area(game.model)=="castle" if int(row[2])==1500 else game.model.falan_floor==int(row[2]),"F return reaches its documented destination")
  check(actual.distance_to(expected)<.6,"F return keeps its exact source landing")
  check(game.model.gold==0 and game.model.team_progression.level==1,"F return stays free at level1")
 check(FileAccess.get_file_as_bytes(game.settings_path)==saved,"Return interactions preserve saved preference/home bytes")
 print("ELSA_RETURN_STONE_INPUT_RESULT checks=",checks," failures=",failures)
 await finish()
