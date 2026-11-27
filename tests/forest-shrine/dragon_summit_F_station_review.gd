extends "res://tests/forest-shrine/dragon_summit_review.gd"
## Recheck the two original F stations that native self-query alone incorrectly accepted.
func _initialize():
 create_timer(600).timeout.connect(func():printerr("DRAGON_F_STATION_TIMEOUT");quit(1));run.call_deferred()
func run():
 root.size=Vector2i(1280,800);view_suffix="-source-open"
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-dragon-f-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var items:Dictionary=get_meta(Events.ITEMS,{}).duplicate(true);set_meta(Events.ITEMS,{})
 Original.Art.load_sokia_dragon_summit();var flags={}
 for map_ in [15569,15577]:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(map_)];flags[map_]=row.sokia_visual_only;row.sokia_visual_only=false
  await visit(map_);await interact_source("5320"if map_==15569 else"5338")
 for map_ in flags:Original.Art.data().maps[Original.path_for(map_)].sokia_visual_only=flags[map_]
 check(get_meta(Events.ITEMS,{}).is_empty(),"Source-open initial F grants no item")
 set_meta(Events.ITEMS,items);check(JSON.stringify(get_meta("falan_venture"))==saved,"Adventure preserved")
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered";var f=FileAccess.open(DRAGON_OUT+"source-open-F-"+mode+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":errors,"actors":npc_report.actors,"captures":server_report.captures,"goal_complete":false,"qualification":"Focused replacement evidence for two earlier source-closed fixture positions. Original map cells, source walk bits, ordinary5mF and native reachability remain unchanged."},"  "));f.close()
 print("DRAGON_F_STATION_RESULT checks=",checks," failures=",errors)
 game.army_runtime.finish_integration();game.queue_free()
 for i in 4:await process_frame
 quit(1 if errors else 0)
