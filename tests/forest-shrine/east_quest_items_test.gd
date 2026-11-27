extends "res://tests/forest-shrine/east_region_review.gd"
const Bag=preload("res://scripts/forest/forest_quest_items.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Quest Items/"
func run():
 var catalog:Dictionary=Events.item_data().items
 var rows=Bag.held({"source_item_41046":2,"source_item_18588":0,"source_item_birth_41046":1,"source_item_leak_41046":1,"source_item_999999":1,"event":true},catalog)
 check(rows.size()==2 and rows[0].id==41046 and rows[0].count==2 and rows[0].usable,"Quest bag lists held original quantities without birth/leak/event metadata")
 check(rows[1].id==999999 and not rows[1].usable,"Unknown held item is retained without inventing a use program")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-items-%d.cfg"%OS.get_process_id()
 root.size=Vector2i(1440,900);root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 set_meta(Bag.ITEMS,{"source_item_41046":1,"source_item_7":1})
 game.show_equipment_hub(true)
 for i in 3:await process_frame
 var hub=game.equipment_hub
 check(hub.find_child("QuestItemsButton",true,false)!=null,"Explore equipment offers the quest bag")
 hub.find_child("QuestItemsButton",true,false).pressed.emit()
 for i in 3:await process_frame
 var bag=hub.get_node("QuestItems")
 var use=bag.find_child("UseQuestItem41046",true,false)
 check(use!=null and not use.disabled,"Held original green feather is usable")
 check(bag.find_child("UseQuestItem7",true,false).disabled,"An original item without use behavior cannot invent a route")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(DEST+"quest-bag.png")==OK,"Captured the original item names, quantities and pictures")
 use.pressed.emit()
 for i in 12:await process_frame
 check(game.equipment_hub==null and not game.equipment_from_game,"Item use returns through the existing equipment owner")
 check(is_instance_valid(game.dialogue),"Original item script owns its YES/NO confirmation")
 check(int(get_meta(Bag.ITEMS).source_item_41046)==1,"Opening item dialogue does not consume the feather")
 if is_instance_valid(game.dialogue):
  game.dialogue.chosen.emit("YES")
  for i in 120:
   await physics_frame
   if not game.transitioning and Region.current_source(game.model,map_position())==32277:break
 check(Region.current_source(game.model,map_position())==32277,"Original green feather reaches source32277")
 check(int(get_meta(Bag.ITEMS,{}).get("source_item_41046",0))==0,"Explicit source KillItem consumes exactly one held feather")
 var file=FileAccess.open(DEST+"quest-bag-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"scope":"Quest bag metadata filtering, current held quantities, original icons, actual Equipment return, original item YES/NO ownership, explicit single-item consumption and source32277 landing. Fixture injects the held item; acquisition is verified separately."},"  "));file.close()
 print("EAST_QUEST_ITEMS_RESULT checks=",checks," failures=",errors)
 await finish()
