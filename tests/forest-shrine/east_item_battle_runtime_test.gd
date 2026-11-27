extends "res://tests/forest-shrine/east_region_review.gd"
const Events=preload("res://scripts/forest/forest_east_events.gd")
const Bank=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const Battles=preload("res://scripts/forest/forest_east_battles.gd")
const University=preload("res://scripts/forest/forest_university_region.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const ITEM_REPORT="res://build/Other Files/Asset Toolkit/East Gate Region/Quest Items/native-item-battle.json"
func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-item-battle-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 set_meta(University.ITEMS,{"source_item_18877":3,"source_item_birth_18877":Time.get_unix_time_from_system()-4000.*60.})
 Events.use_item(game,18877)
 check(is_instance_valid(game.dialogue),"Mature original herb asks through its source Window")
 if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("OK")
 for i in 3:await physics_frame
 check(int(get_meta(University.ITEMS).source_item_18877)==3 and University.active(self,game.model.falan_floor,game.model.falan_area).is_empty(),"An incompatible city bank holds the battle before consuming the item")
 check(get_meta("east_battle_blockers",{}).has("item:18877"),"Incompatible-bank blocker names the exact held item")
 var id=33100;var cell=Maps.safe_cell(id,Vector2i(25,25));var at=Maps.point(id,cell)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 10:await physics_frame
 check(Bank.owns_model(game.model),"Source33100 uses the compatible shared East bank")
 var keys=[]
 for repetition in 2:
  Events.use_item(game,18877)
  if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("OK")
  var key=""
  for i in 180:
   await physics_frame
   key=University.active(self,id,"interior")
   if not key.is_empty() and game.model.enemies.values().any(func(enemy):return enemy.get("university_battle","")==key):break
  check(not key.is_empty(),"Original held-item formation starts: "+str(repetition))
  if key.is_empty():break
  check(key not in keys,"Each repeated item use has its own completion state: "+str(repetition));keys.append(key)
  var spec=Battles.specification(key)
  check(spec.has("runtime_at") and spec.runtime_at.distance_to(at)<.3,"Held-item formation anchors to the actual player position: "+str(repetition))
  check(int(get_meta(University.ITEMS).source_item_18877)==2-repetition,"Only explicit source KillItem consumes one mature herb: "+str(repetition))
  var rows=game.model.enemies.values().filter(func(enemy):return enemy.get("university_battle","")==key)
  check(not rows.is_empty() and rows.all(func(enemy):return game.army_runtime.handles.has(enemy.id)),"Every held-item formation member reaches the existing native lifecycle: "+str(repetition))
  for i in 500:
   await physics_frame
   for enemy in game.model.enemies.values().filter(func(enemy):return enemy.get("university_battle","")==key):
    var handle:int=game.army_runtime.handles.get(enemy.id,0)
    if handle!=0:game.army_runtime.native.apply_hit(handle,{"amount":1000000000.,"provoke":false})
   if get_meta(University.BATTLES,{})[key].complete:break
  for i in 4:await physics_frame
  check(get_meta(University.BATTLES,{})[key].complete,"Native retirement completes the held-item formation: "+str(repetition))
 var file=FileAccess.open(ITEM_REPORT,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"battle_keys":keys,"scope":"Original mature-herb item script, guarded incompatible city bank, compatible source33100, held-item page preparation, actual native spawn/retirement and two successive consumptions. Injected mature items/native lethal hits verify integration, not acquisition or combat balance."},"  "));file.close()
 print("EAST_ITEM_BATTLE_RUNTIME_RESULT checks=",checks," failures=",errors)
 await finish()
