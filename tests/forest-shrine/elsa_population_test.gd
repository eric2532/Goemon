extends "res://tests/forest-shrine/original_maps_test.gd"
## Targeted native lifecycle checks; injected lethal hits do not establish playable combat balance.
const Elsa=preload("res://scripts/forest/forest_elsa_route.gd")
const Bank=preload("res://scripts/forest/crowd/elsa_region_sprites.gd")

func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-population.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 var local:Dictionary=Bank.data().battles.filter(func(b):return int(b.map)==59606)[0]
 var companion:Dictionary=Bank.data().battles.filter(func(b):return int(b.map)==59728)[0]
 var bishop:Dictionary=Bank.data().battles.filter(func(b):return int(b.map)==59716)[0]
 for spec in [local,companion,bishop,local]:
  var key:String=spec.key;var id:int=spec.map
  var cell=Original.safe_cell(id,Vector2i(spec.cell[0],spec.cell[1])+Vector2i.DOWN)
  Tour.travel(game,Original.layout(id),{"arrival":Original.point(id,cell),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  check(Elsa.open(game),"Original event entrance uses normal E interaction "+key)
  check(is_instance_valid(game.dialogue),"Event destination choices are reviewable "+key)
  game.dialogue.chosen.emit("cancel")
  for i in 2:await physics_frame
  Elsa.begin(game,key)
  for i in 12:await physics_frame
  var battle:Dictionary=get_meta(Elsa.BATTLES,{})[key]
  var enemies:Array=game.model.enemies.values().filter(func(enemy):return enemy.get("elsa_battle","")==key)
  check(not battle.members.is_empty(),"Original group contains members "+key)
  check(enemies.size()==battle.members.size(),"Native owner spawns the full original group "+key)
  for enemy in enemies:
   var handle:int=game.army_runtime.handles.get(enemy.id,0)
   check(handle>0,"Every encounter member has a native handle "+key)
   check(game.army_runtime.native.can_reach(game.player.position,enemy.pos,.45),"Original chamber connects encounter members "+key)
   for attempt in 16:
    if game.army_runtime.unit_state(handle).get("hp",0.)<=0.:break
    game.army_runtime.apply_hit(handle,{"amount":enemy.max_hp*4,"direction":Vector3.FORWARD})
  for i in 12:await physics_frame
  check(get_meta(Elsa.BATTLES,{})[key].complete,"Victory uses native death callbacks "+key)
  check(game.model.falan_floor==int(spec.win[0]),"Victory reaches the exact source post-fight room "+key)
  check(game.army_runtime.handles.is_empty(),"Post-fight room has no stale enemy handles "+key)
 print("ELSA_POPULATION_RESULT checks=",checks," failures=",failures)
 await finish()
