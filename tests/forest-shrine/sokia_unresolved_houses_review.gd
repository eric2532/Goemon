extends "res://tests/forest-shrine/sokia_region_review.gd"
## Current compatibility rooms only. Original destination IDs/art are unknown.
func run():
 phase="UnresolvedHouses";route={"seed":41829558,"stages":[],"limits":"Runtime proxy IDs are not original map IDs. No source comparison or 1:1 claim."}
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-proxies-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.set_process(false)
 for spec in [[3804,76,79],[3805,85,69],[3806,38,63]]:
  var id:int=spec[0];var info=Tour.Indoor.floor_info(id)
  stage={"key":"runtime-proxy-%d"%id,"title":"Unresolved Ghana residence at %d,%d"%[spec[1],spec[2]],"source":null,"area":"interior","floor":id,"original_id":"unknown","exterior_gate":[spec[1],spec[2]]}
  route.stages.append(stage)
  var point:Vector2=Tour.Indoor.safe_point(id,Vector2.ZERO);var cell=(point-info[1])/3.
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":point,"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  for i in 4:await process_frame
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();hide_canvas(game)
  check(game.model.falan_floor==id,"Preserved current compatibility residence "+str(id))
  await overhead(stage.key,Vector2(info[0])*.5,maxf(info[0].x,info[0].y)*3.+30.)
  await isometric(stage.key,cell,100.)
  await gameplay({"key":stage.key,"at":[cell.x,cell.y],"start":[cell.x,cell.y+1],"end":[cell.x,cell.y-1]})
  write_records()
 print("SOKIA_UNRESOLVED_HOUSES_RESULT captures=",records.size()," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
